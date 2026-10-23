//! 边下边播：后台线程把 HTTP 响应写进缓存文件，解码器从同一个文件读取，
//! 读到尚未下载的位置时阻塞等待。下载完成后文件即为离线缓存。

use std::fs::{self, File, OpenOptions};
use std::io::{self, Read, Seek, SeekFrom, Write};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::{Arc, Condvar, Mutex};
use std::time::Duration;

use symphonia::core::io::MediaSource;

#[derive(Default)]
struct Progress {
    downloaded: AtomicU64,
    /// 0 表示未知
    total: AtomicU64,
    done: AtomicBool,
    cancelled: AtomicBool,
    error: Mutex<Option<String>>,
    lock: Mutex<()>,
    cv: Condvar,
}

impl Progress {
    fn notify(&self) {
        let _g = self.lock.lock().unwrap();
        self.cv.notify_all();
    }
}

/// 取消下载的句柄；Drop 时自动取消。
pub struct DownloadHandle(Arc<Progress>);

impl DownloadHandle {
    /// (已下载字节, 总字节；未知为 0)
    pub fn progress(&self) -> (u64, u64) {
        (
            self.0.downloaded.load(Ordering::Relaxed),
            self.0.total.load(Ordering::Relaxed),
        )
    }
}

impl Drop for DownloadHandle {
    fn drop(&mut self) {
        self.0.cancelled.store(true, Ordering::Relaxed);
        self.0.notify();
    }
}

pub struct StreamingSource {
    progress: Arc<Progress>,
    file: File,
    pos: u64,
}

impl StreamingSource {
    /// 开始下载 `url` 到 `cache_path`（先写 `.part`，完成后改名）。
    pub fn open(url: &str, cache_path: &Path) -> io::Result<(Self, DownloadHandle)> {
        if let Some(dir) = cache_path.parent() {
            fs::create_dir_all(dir)?;
        }
        let part = part_path(cache_path);
        let writer = OpenOptions::new()
            .create(true)
            .write(true)
            .truncate(true)
            .open(&part)?;
        let reader = File::open(&part)?;
        let progress = Arc::new(Progress::default());

        let p = progress.clone();
        let url = url.to_owned();
        let final_path = cache_path.to_owned();
        std::thread::Builder::new()
            .name("ncm-download".into())
            .spawn(move || {
                let res = download(&url, writer, &p);
                match res {
                    Ok(()) => {
                        // Windows 上被打开的文件无法改名，失败就保留 .part，下次重新下载
                        let _ = fs::rename(&part, &final_path);
                    }
                    Err(e) => {
                        let _ = fs::remove_file(&part);
                        if !p.cancelled.load(Ordering::Relaxed) {
                            tracing::warn!("download failed: {e}");
                        }
                        *p.error.lock().unwrap() = Some(e.to_string());
                    }
                }
                p.done.store(true, Ordering::Release);
                p.notify();
            })?;

        Ok((
            Self {
                progress: progress.clone(),
                file: reader,
                pos: 0,
            },
            DownloadHandle(progress),
        ))
    }
}

fn part_path(p: &Path) -> PathBuf {
    let mut s = p.as_os_str().to_owned();
    s.push(".part");
    PathBuf::from(s)
}

fn download(url: &str, mut out: File, p: &Progress) -> io::Result<()> {
    let client = crate::http_client();
    let mut resp = client
        .get(url)
        .send()
        .and_then(|r| r.error_for_status())
        .map_err(io::Error::other)?;
    if let Some(len) = resp.content_length() {
        p.total.store(len, Ordering::Relaxed);
    }
    let mut buf = vec![0u8; 64 * 1024];
    loop {
        if p.cancelled.load(Ordering::Relaxed) {
            return Err(io::Error::new(io::ErrorKind::Interrupted, "cancelled"));
        }
        let n = resp.read(&mut buf)?;
        if n == 0 {
            break;
        }
        out.write_all(&buf[..n])?;
        p.downloaded.fetch_add(n as u64, Ordering::Release);
        p.notify();
    }
    out.flush()?;
    let got = p.downloaded.load(Ordering::Relaxed);
    let total = p.total.load(Ordering::Relaxed);
    if total != 0 && got != total {
        return Err(io::Error::new(
            io::ErrorKind::UnexpectedEof,
            format!("got {got} of {total} bytes"),
        ));
    }
    p.total.store(got, Ordering::Relaxed);
    Ok(())
}

impl Read for StreamingSource {
    fn read(&mut self, buf: &mut [u8]) -> io::Result<usize> {
        if buf.is_empty() {
            return Ok(0);
        }
        let p = &self.progress;
        loop {
            let avail = p.downloaded.load(Ordering::Acquire);
            if self.pos < avail {
                let want = buf.len().min((avail - self.pos) as usize);
                self.file.seek(SeekFrom::Start(self.pos))?;
                let n = self.file.read(&mut buf[..want])?;
                self.pos += n as u64;
                return Ok(n);
            }
            if p.done.load(Ordering::Acquire) {
                if let Some(e) = p.error.lock().unwrap().clone() {
                    return Err(io::Error::other(e));
                }
                return Ok(0);
            }
            if p.cancelled.load(Ordering::Relaxed) {
                return Err(io::Error::new(io::ErrorKind::Interrupted, "cancelled"));
            }
            let g = p.lock.lock().unwrap();
            let _ = p.cv.wait_timeout(g, Duration::from_millis(50)).unwrap();
        }
    }
}

impl Seek for StreamingSource {
    fn seek(&mut self, pos: SeekFrom) -> io::Result<u64> {
        let total = self.progress.total.load(Ordering::Relaxed);
        let new = match pos {
            SeekFrom::Start(n) => n as i64,
            SeekFrom::Current(d) => self.pos as i64 + d,
            SeekFrom::End(d) => {
                if total == 0 {
                    return Err(io::Error::new(io::ErrorKind::Unsupported, "length unknown"));
                }
                total as i64 + d
            }
        };
        if new < 0 {
            return Err(io::Error::new(
                io::ErrorKind::InvalidInput,
                "seek before start",
            ));
        }
        self.pos = new as u64;
        Ok(self.pos)
    }
}

impl MediaSource for StreamingSource {
    fn is_seekable(&self) -> bool {
        true
    }

    fn byte_len(&self) -> Option<u64> {
        Some(self.progress.total.load(Ordering::Relaxed)).filter(|&n| n > 0)
    }
}

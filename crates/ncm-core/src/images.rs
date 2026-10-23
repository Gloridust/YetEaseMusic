//! 磁盘缓存：图片按 URL 的 MD5 分片存放；音频与图片目录都有容量上限，超出后按修改时间淘汰最旧的。

use std::path::{Path, PathBuf};
use std::time::SystemTime;

use md5::{Digest, Md5};

/// 图片缓存上限（音频缓存上限在设置里，可调）
pub const IMAGE_LIMIT: u64 = 500 << 20;

pub fn path_for(dir: &Path, url: &str) -> PathBuf {
    let key = hex::encode(Md5::digest(url.as_bytes()));
    dir.join(&key[..2]).join(key)
}

/// 递归收集目录下的缓存文件（跳过下载中的 `.part` / `.tmp`）
fn collect(dir: &Path, out: &mut Vec<(PathBuf, u64, SystemTime)>) {
    let Ok(rd) = std::fs::read_dir(dir) else {
        return;
    };
    for e in rd.flatten() {
        let p = e.path();
        let Ok(m) = e.metadata() else { continue };
        if m.is_dir() {
            collect(&p, out);
        } else if m.is_file() {
            let ext = p.extension().and_then(|x| x.to_str()).unwrap_or_default();
            if ext != "part" && ext != "tmp" {
                out.push((p, m.len(), m.modified().unwrap_or(SystemTime::UNIX_EPOCH)));
            }
        }
    }
}

/// 目录占用的字节数
pub fn usage(dir: &Path) -> u64 {
    let mut files = Vec::new();
    collect(dir, &mut files);
    files.iter().map(|f| f.1).sum()
}

/// 超过 `limit` 时淘汰最旧的文件，降到上限的 80%。返回淘汰的字节数。在阻塞线程里调用。
pub fn prune(dir: &Path, limit: u64) -> u64 {
    let mut files = Vec::new();
    collect(dir, &mut files);
    let mut total: u64 = files.iter().map(|f| f.1).sum();
    if total <= limit {
        return 0;
    }
    let target = limit / 5 * 4;
    files.sort_by_key(|f| f.2);
    let mut freed = 0;
    for (p, len, _) in files {
        if total <= target {
            break;
        }
        // Linux 上删除正在播放的文件不影响已打开的句柄
        if std::fs::remove_file(&p).is_ok() {
            total -= len;
            freed += len;
        }
    }
    freed
}

/// 清空目录下的全部缓存文件（保留下载中的临时文件）
pub fn clear(dir: &Path) -> u64 {
    let mut files = Vec::new();
    collect(dir, &mut files);
    files
        .iter()
        .filter(|f| std::fs::remove_file(&f.0).is_ok())
        .map(|f| f.1)
        .sum()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn stable_sharded_path() {
        let p = path_for(
            Path::new("/c"),
            "https://p1.music.126.net/x.jpg?param=96y96",
        );
        assert!(p.to_string_lossy().starts_with("/c/"));
        assert_eq!(
            p,
            path_for(
                Path::new("/c"),
                "https://p1.music.126.net/x.jpg?param=96y96"
            )
        );
        assert_eq!(p.parent().unwrap().file_name().unwrap().len(), 2);
    }

    #[test]
    fn prunes_oldest_first() {
        let dir = std::env::temp_dir().join(format!("ncm-prune-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(dir.join("ab")).unwrap();
        for (i, name) in ["old", "mid", "new"].iter().enumerate() {
            let p = dir.join("ab").join(name);
            std::fs::write(&p, vec![0u8; 100]).unwrap();
            let t = SystemTime::UNIX_EPOCH + std::time::Duration::from_secs(1_000 + i as u64 * 100);
            std::fs::File::options()
                .write(true)
                .open(&p)
                .unwrap()
                .set_modified(t)
                .unwrap();
        }
        std::fs::write(dir.join("x.part"), vec![0u8; 1000]).unwrap();
        assert_eq!(usage(&dir), 300, ".part 不计入");
        assert_eq!(prune(&dir, 250), 100);
        assert!(!dir.join("ab/old").exists());
        assert!(dir.join("ab/new").exists());
        assert!(dir.join("x.part").exists());
        std::fs::remove_dir_all(&dir).unwrap();
    }
}

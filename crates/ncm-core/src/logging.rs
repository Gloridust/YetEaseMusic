//! 日志：按天滚动写到 `<data>/logs/`，保留最近 7 天；导出时抹掉登录凭据。

use std::path::{Path, PathBuf};
use std::sync::OnceLock;

use tracing_appender::rolling::{RollingFileAppender, Rotation};
use tracing_subscriber::EnvFilter;
use tracing_subscriber::fmt::writer::MakeWriterExt;

static GUARD: OnceLock<tracing_appender::non_blocking::WorkerGuard> = OnceLock::new();

pub fn log_dir(data_dir: &Path) -> PathBuf {
    data_dir.join("logs")
}

/// 初始化全局日志：文件（info 及以上，本项目 crate 为 debug）+ 标准错误（warn 及以上）。
/// 只生效一次；`RUST_LOG` 可以覆盖过滤规则。
pub fn init(data_dir: &Path) {
    if GUARD.get().is_some() {
        return;
    }
    let dir = log_dir(data_dir);
    let _ = std::fs::create_dir_all(&dir);
    let appender = RollingFileAppender::builder()
        .rotation(Rotation::DAILY)
        .filename_prefix("yetease")
        .filename_suffix("log")
        .max_log_files(7)
        .build(&dir);
    let filter = EnvFilter::try_from_default_env().unwrap_or_else(|_| {
        EnvFilter::new("info,ncm_api=debug,ncm_core=debug,ncm_player=debug,rust_lib_app=debug")
    });
    let Ok(appender) = appender else {
        let _ = tracing_subscriber::fmt()
            .with_env_filter(filter)
            .with_writer(std::io::stderr)
            .try_init();
        return;
    };
    let (file, guard) = tracing_appender::non_blocking(appender);
    let _ = GUARD.set(guard);
    let writer = file.and(std::io::stderr.with_max_level(tracing::Level::WARN));
    let _ = tracing_subscriber::fmt()
        .with_env_filter(filter)
        .with_ansi(false)
        .with_writer(writer)
        .try_init();
    // 后台线程（播放引擎等）的 panic 默认只打到标准错误，安卓上看不到；同时写进日志
    let default_hook = std::panic::take_hook();
    std::panic::set_hook(Box::new(move |info| {
        let thread = std::thread::current();
        tracing::error!(thread = thread.name().unwrap_or("?"), "panic: {info}");
        default_hook(info);
    }));
    tracing::info!(
        version = env!("CARGO_PKG_VERSION"),
        os = std::env::consts::OS,
        arch = std::env::consts::ARCH,
        "logging started"
    );
}

/// 抹掉日志里可能出现的登录凭据与设备指纹
pub fn redact(text: &str) -> String {
    const KEYS: &[&str] = &[
        "MUSIC_U",
        "MUSIC_A",
        "__csrf",
        "MUSIC_R_U",
        "deviceId",
        "_ntes_nuid",
        "NMTID",
        "WNMCID",
    ];
    let mut out = String::with_capacity(text.len());
    for line in text.lines() {
        let mut l = line.to_owned();
        for k in KEYS {
            let mut from = 0;
            while let Some(i) = l[from..].find(k) {
                let start = from + i + k.len();
                // 只处理 `KEY=值` / `"KEY":"值"` 这类紧跟分隔符的情况
                let rest = &l[start..];
                let sep = rest
                    .chars()
                    .take_while(|c| matches!(c, '=' | ':' | '"' | ' '))
                    .count();
                if sep == 0 {
                    from = start;
                    continue;
                }
                let vstart = start + sep;
                let vlen = l[vstart..]
                    .chars()
                    .take_while(|c| !matches!(c, ';' | '"' | ',' | ' ' | '&' | '}'))
                    .map(char::len_utf8)
                    .sum::<usize>();
                l.replace_range(vstart..vstart + vlen, "***");
                from = vstart + 3;
            }
        }
        out.push_str(&l);
        out.push('\n');
    }
    out
}

/// 把最近的日志合成一份可直接附到 Issue 的文本（已脱敏），写到 `dest_dir`，返回文件路径
pub fn export(data_dir: &Path, dest_dir: &Path, header: &str) -> std::io::Result<PathBuf> {
    let dir = log_dir(data_dir);
    let mut files: Vec<PathBuf> = std::fs::read_dir(&dir)?
        .flatten()
        .map(|e| e.path())
        .filter(|p| {
            p.file_name()
                .and_then(|n| n.to_str())
                .is_some_and(|n| n.starts_with("yetease"))
        })
        .collect();
    files.sort();
    let mut body = String::new();
    for f in files.iter().rev().take(3).rev() {
        body.push_str(&format!(
            "===== {} =====\n",
            f.file_name().unwrap_or_default().to_string_lossy()
        ));
        body.push_str(&std::fs::read_to_string(f).unwrap_or_default());
    }
    // 只保留最后 2 MB，避免文件太大不便上传
    const MAX: usize = 2 << 20;
    if body.len() > MAX {
        let mut cut = body.len() - MAX;
        while !body.is_char_boundary(cut) {
            cut += 1;
        }
        body = body[cut..].to_owned();
    }
    std::fs::create_dir_all(dest_dir)?;
    let stamp = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    let path = dest_dir.join(format!("yetease-log-{stamp}.txt"));
    std::fs::write(&path, format!("{header}\n\n{}", redact(&body)))?;
    Ok(path)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn redacts_credentials() {
        let r = redact(
            "cookie MUSIC_U=abcdef123; os=pc\n{\"__csrf\":\"xyz\",\"a\":1}\nMUSIC_Ufoo stays",
        );
        assert!(!r.contains("abcdef123"));
        assert!(!r.contains("xyz"));
        assert!(r.contains("os=pc"));
        assert!(r.contains("MUSIC_Ufoo stays"));
    }
}

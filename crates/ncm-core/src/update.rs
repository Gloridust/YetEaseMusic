//! 应用内更新：查 GitHub Releases，按当前的安装方式挑安装包，下载并校验 SHA256，再替换安装。
//!
//! 安装方式决定怎么更新：
//! - deb：`pkexec apt-get install` 装新包（弹系统授权框），装完重启
//! - AppImage：下载新文件覆盖当前的 AppImage，重启
//! - 压缩包（装在 ~/.local/opt）：解压后运行包里的 install.sh，重启
//! - Windows 安装版：退出后静默运行新安装程序，装完自动重新打开
//! - macOS：下载 dmg 并打开，由用户拖进「应用程序」
//! - 安卓：下载 apk，由界面层调起系统安装器
//! - Flatpak、Windows 免安装版、开发构建：只能打开发布页手动更新

use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};

use futures_util::StreamExt;
use serde::Deserialize;
use sha2::{Digest, Sha256};
use tokio::io::AsyncWriteExt;

use crate::{Error, Result, http_client};

const REPO: &str = "Gloridust/YetEaseMusic";

pub fn releases_page() -> String {
    format!("https://github.com/{REPO}/releases")
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum InstallKind {
    Deb,
    /// 当前运行的 AppImage 文件
    AppImage(PathBuf),
    /// 用发布包里的 install.sh 装到 ~/.local/opt 的
    Tarball,
    Flatpak,
    WindowsSetup,
    WindowsPortable,
    MacOs,
    Android,
    /// 源码构建等无法自动更新的情况
    Dev,
}

impl InstallKind {
    /// 能否在应用内完成下载与安装（macOS 只到打开 dmg 为止，也算）
    pub fn can_self_update(&self) -> bool {
        !matches!(self, Self::Flatpak | Self::WindowsPortable | Self::Dev)
    }
}

/// 判断当前程序是怎么装的
pub fn install_kind() -> InstallKind {
    detect()
}

#[cfg(target_os = "android")]
fn detect() -> InstallKind {
    InstallKind::Android
}

#[cfg(target_os = "macos")]
fn detect() -> InstallKind {
    InstallKind::MacOs
}

#[cfg(windows)]
fn detect() -> InstallKind {
    // Inno Setup 装的版本旁边有卸载程序
    match current_exe().parent() {
        Some(dir) if dir.join("unins000.exe").exists() => InstallKind::WindowsSetup,
        _ => InstallKind::WindowsPortable,
    }
}

#[cfg(target_os = "linux")]
fn detect() -> InstallKind {
    if std::env::var_os("FLATPAK_ID").is_some() {
        return InstallKind::Flatpak;
    }
    if let Some(p) = std::env::var_os("APPIMAGE") {
        return InstallKind::AppImage(PathBuf::from(p));
    }
    let exe = current_exe();
    if exe.starts_with("/opt/yetease-music")
        && Path::new("/var/lib/dpkg/info/yetease-music.list").exists()
    {
        return InstallKind::Deb;
    }
    if let Some(dirs) = directories::BaseDirs::new()
        && exe.starts_with(dirs.home_dir().join(".local/opt/yetease-music"))
    {
        return InstallKind::Tarball;
    }
    InstallKind::Dev
}

#[cfg(not(any(
    target_os = "android",
    target_os = "macos",
    target_os = "linux",
    windows
)))]
fn detect() -> InstallKind {
    InstallKind::Dev
}

/// 当前可执行文件。Linux 上文件被新版替换后 /proc/self/exe 会带上 " (deleted)"，去掉它
pub fn current_exe() -> PathBuf {
    let p = std::env::current_exe().unwrap_or_default();
    match p.to_str().and_then(|s| s.strip_suffix(" (deleted)")) {
        Some(s) => PathBuf::from(s),
        None => p,
    }
}

#[derive(Debug, Clone)]
pub struct Release {
    pub version: String,
    /// 发布日期 YYYY-MM-DD
    pub date: String,
    /// 发布说明（Markdown）
    pub body: String,
    pub url: String,
    pub assets: Vec<Asset>,
}

#[derive(Debug, Clone)]
pub struct Asset {
    pub name: String,
    pub url: String,
    pub size: u64,
}

#[derive(Deserialize)]
struct GhRelease {
    tag_name: String,
    #[serde(default)]
    body: Option<String>,
    html_url: String,
    #[serde(default)]
    published_at: Option<String>,
    draft: bool,
    prerelease: bool,
    #[serde(default)]
    assets: Vec<GhAsset>,
}

#[derive(Deserialize)]
struct GhAsset {
    name: String,
    browser_download_url: String,
    size: u64,
}

/// 最近的正式版本，新的在前
pub async fn fetch_releases() -> Result<Vec<Release>> {
    let resp = http_client()
        .get(format!(
            "https://api.github.com/repos/{REPO}/releases?per_page=20"
        ))
        .header("Accept", "application/vnd.github+json")
        .timeout(std::time::Duration::from_secs(20))
        .send()
        .await?;
    if !resp.status().is_success() {
        return Err(Error::Other(format!("GitHub 返回 {}", resp.status())));
    }
    let list: Vec<GhRelease> = resp.json().await?;
    let mut out: Vec<Release> = list
        .into_iter()
        .filter(|r| !r.draft && !r.prerelease)
        .filter_map(|r| {
            let version = r.tag_name.trim_start_matches('v').to_owned();
            parse_version(&version)?;
            Some(Release {
                version,
                date: r
                    .published_at
                    .unwrap_or_default()
                    .chars()
                    .take(10)
                    .collect(),
                body: r.body.unwrap_or_default().replace("\r\n", "\n"),
                url: r.html_url,
                assets: r
                    .assets
                    .into_iter()
                    .map(|a| Asset {
                        name: a.name,
                        url: a.browser_download_url,
                        size: a.size,
                    })
                    .collect(),
            })
        })
        .collect();
    out.sort_by_key(|r| std::cmp::Reverse(parse_version(&r.version)));
    Ok(out)
}

/// "0.2.7" / "0.2.7-dev.3" → (0, 2, 7)
pub fn parse_version(s: &str) -> Option<(u64, u64, u64)> {
    let core = s.trim_start_matches('v').split(['-', '+']).next()?;
    let mut it = core.split('.').map(|p| p.parse::<u64>().ok());
    let v = (it.next()??, it.next()??, it.next().unwrap_or(Some(0))?);
    Some(v)
}

pub fn is_newer(candidate: &str, current: &str) -> bool {
    match (parse_version(candidate), parse_version(current)) {
        (Some(a), Some(b)) => a > b,
        _ => false,
    }
}

/// 按安装方式挑对应的安装包
pub fn pick_asset<'a>(kind: &InstallKind, release: &'a Release) -> Option<&'a Asset> {
    let v = &release.version;
    let names: Vec<String> = match kind {
        InstallKind::Deb => vec![format!("yetease-music_{v}_amd64.deb")],
        InstallKind::AppImage(_) => vec![format!("yetease-music-{v}-x86_64.AppImage")],
        InstallKind::Tarball => vec![format!("yetease-music-{v}-linux-x86_64.tar.gz")],
        InstallKind::WindowsSetup => vec![format!("yetease-music-{v}-windows-x64-setup.exe")],
        InstallKind::MacOs => vec![format!("yetease-music-{v}-macos-universal.dmg")],
        InstallKind::Android => {
            let abi = match std::env::consts::ARCH {
                "aarch64" => Some("arm64-v8a"),
                "arm" => Some("armeabi-v7a"),
                "x86_64" => Some("x86_64"),
                _ => None,
            };
            abi.map(|a| format!("yetease-music-{v}-android-{a}.apk"))
                .into_iter()
                .chain([format!("yetease-music-{v}-android-universal.apk")])
                .collect()
        }
        InstallKind::Flatpak | InstallKind::WindowsPortable | InstallKind::Dev => vec![],
    };
    names
        .iter()
        .find_map(|n| release.assets.iter().find(|a| &a.name == n))
}

/// 下载进度，界面轮询读取
#[derive(Default)]
pub struct Progress {
    pub received: AtomicU64,
    pub total: AtomicU64,
    pub cancel: AtomicBool,
}

/// 下载安装包到 `dir`，有 SHA256SUMS 时校验。返回文件路径
pub async fn download(
    release: &Release,
    asset: &Asset,
    dir: &Path,
    progress: &Progress,
) -> Result<PathBuf> {
    progress.received.store(0, Ordering::Relaxed);
    progress.total.store(asset.size, Ordering::Relaxed);
    progress.cancel.store(false, Ordering::Relaxed);
    tokio::fs::create_dir_all(dir).await?;
    let dest = dir.join(&asset.name);
    let part = dir.join(format!("{}.part", asset.name));

    let expected = match release.assets.iter().find(|a| a.name == "SHA256SUMS") {
        Some(sums) => {
            let text = http_client()
                .get(&sums.url)
                .send()
                .await?
                .error_for_status()?
                .text()
                .await?;
            text.lines().find_map(|l| {
                let (hash, name) = l.split_once(char::is_whitespace)?;
                (name.trim().trim_start_matches('*') == asset.name)
                    .then(|| hash.to_ascii_lowercase())
            })
        }
        None => None,
    };

    let resp = http_client()
        .get(&asset.url)
        .send()
        .await?
        .error_for_status()?;
    if let Some(len) = resp.content_length() {
        progress.total.store(len, Ordering::Relaxed);
    }
    let mut file = tokio::fs::File::create(&part).await?;
    let mut hasher = Sha256::new();
    let mut stream = resp.bytes_stream();
    while let Some(chunk) = stream.next().await {
        if progress.cancel.load(Ordering::Relaxed) {
            drop(file);
            let _ = tokio::fs::remove_file(&part).await;
            return Err(Error::Other("已取消".into()));
        }
        let chunk = chunk?;
        hasher.update(&chunk);
        file.write_all(&chunk).await?;
        progress
            .received
            .fetch_add(chunk.len() as u64, Ordering::Relaxed);
    }
    file.flush().await?;
    drop(file);

    if let Some(expected) = expected {
        let actual = hex::encode(hasher.finalize());
        if actual != expected {
            let _ = tokio::fs::remove_file(&part).await;
            return Err(Error::Other(
                "安装包校验失败（SHA256 不一致），请重试".into(),
            ));
        }
    }
    tokio::fs::rename(&part, &dest).await?;
    Ok(dest)
}

/// 安装完成后界面层该做什么
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Applied {
    /// 已替换好，退出并重新打开这个程序
    Restart(PathBuf),
    /// 安装程序会在本程序退出后接手，界面层直接退出
    Quit,
    /// 已打开安装包，等用户自己完成（macOS 的 dmg）
    Opened,
}

/// 安装下载好的包（会阻塞，调用方放到后台线程）
pub fn apply(kind: &InstallKind, file: &Path) -> Result<Applied> {
    match kind {
        #[cfg(target_os = "linux")]
        InstallKind::Deb => {
            let exe = current_exe();
            let out = std::process::Command::new("pkexec")
                .args(["apt-get", "install", "-y", "--allow-downgrades"])
                .arg(file)
                .output()
                .map_err(|e| {
                    Error::Other(format!(
                        "无法调用 pkexec（{e}），请手动安装 {}",
                        file.display()
                    ))
                })?;
            match out.status.code() {
                Some(0) => Ok(Applied::Restart(exe)),
                // 126：用户关掉了授权框；127：没有授权（比如没有可用的授权代理）
                Some(126) => Err(Error::Other("没有获得管理员授权，更新已取消".into())),
                Some(127) => Err(Error::Other(format!("无法获得管理员授权：{}", tail(&out.stderr)))),
                _ => Err(Error::Other(format!("安装失败：{}", tail(&out.stderr)))),
            }
        }
        #[cfg(unix)]
        InstallKind::AppImage(target) => {
            use std::os::unix::fs::PermissionsExt;
            // 先复制到同目录再改名，保证替换是原子的（下载目录可能在另一个文件系统上）
            let tmp = target.with_file_name(format!(
                ".{}.new",
                target
                    .file_name()
                    .and_then(|n| n.to_str())
                    .unwrap_or("yetease-music.AppImage")
            ));
            std::fs::copy(file, &tmp)?;
            std::fs::set_permissions(&tmp, std::fs::Permissions::from_mode(0o755))?;
            std::fs::rename(&tmp, target)?;
            let _ = std::fs::remove_file(file);
            Ok(Applied::Restart(target.clone()))
        }
        #[cfg(target_os = "linux")]
        InstallKind::Tarball => {
            let work = file.with_extension("extract");
            let _ = std::fs::remove_dir_all(&work);
            std::fs::create_dir_all(&work)?;
            run_ok(
                std::process::Command::new("tar")
                    .arg("-xzf")
                    .arg(file)
                    .arg("-C")
                    .arg(&work),
                "解压失败",
            )?;
            let pkg = std::fs::read_dir(&work)?
                .filter_map(|e| e.ok().map(|e| e.path()))
                .find(|p| p.join("install.sh").is_file())
                .ok_or_else(|| Error::Other("安装包里没有 install.sh".into()))?;
            run_ok(
                std::process::Command::new("bash").arg(pkg.join("install.sh")),
                "安装失败",
            )?;
            let _ = std::fs::remove_dir_all(&work);
            let _ = std::fs::remove_file(file);
            let home = directories::BaseDirs::new()
                .map(|d| d.home_dir().to_path_buf())
                .ok_or_else(|| Error::Other("找不到用户目录".into()))?;
            Ok(Applied::Restart(
                home.join(".local/opt/yetease-music/yetease-music"),
            ))
        }
        #[cfg(windows)]
        InstallKind::WindowsSetup => {
            // 等本程序退出后静默安装，装完重新打开。路径直接写进脚本，避免命令行引号问题；
            // 脚本是 UTF-8，先 chcp 65001，否则中文用户名的路径会按 GBK 读成乱码
            let exe = current_exe();
            let script = file.with_extension("cmd");
            let body = format!(
                "@echo off\r\nchcp 65001 >nul\r\nping -n 4 127.0.0.1 >nul\r\n\"{}\" /SILENT /SUPPRESSMSGBOXES /NORESTART\r\nstart \"\" \"{}\"\r\n",
                file.display(),
                exe.display()
            );
            std::fs::write(&script, body)?;
            use std::os::windows::process::CommandExt;
            // 不弹黑色命令行窗口；子进程在本程序退出后继续运行
            const CREATE_NO_WINDOW: u32 = 0x0800_0000;
            std::process::Command::new(&script)
                .creation_flags(CREATE_NO_WINDOW)
                .spawn()?;
            Ok(Applied::Quit)
        }
        #[cfg(target_os = "macos")]
        InstallKind::MacOs => {
            run_ok(
                std::process::Command::new("open").arg(file),
                "无法打开安装包",
            )?;
            Ok(Applied::Opened)
        }
        _ => {
            let _ = file;
            Err(Error::Other(
                "当前安装方式不支持应用内更新，请到发布页下载".into(),
            ))
        }
    }
}

/// 稍等片刻再启动新程序（等当前进程退出、释放单实例锁）
pub fn relaunch(exe: &Path) -> Result<()> {
    #[cfg(unix)]
    {
        std::process::Command::new("sh")
            .args(["-c", "sleep 1.5; exec \"$0\" >/dev/null 2>&1"])
            .arg(exe)
            .stdin(std::process::Stdio::null())
            .stdout(std::process::Stdio::null())
            .stderr(std::process::Stdio::null())
            .spawn()?;
    }
    #[cfg(not(unix))]
    std::process::Command::new(exe).spawn()?;
    Ok(())
}

#[cfg(any(target_os = "linux", target_os = "macos"))]
fn run_ok(cmd: &mut std::process::Command, what: &str) -> Result<()> {
    let out = cmd.output()?;
    if out.status.success() {
        Ok(())
    } else {
        Err(Error::Other(format!("{what}：{}", tail(&out.stderr))))
    }
}

/// 命令输出的最后几行，用于错误提示
#[cfg(any(target_os = "linux", target_os = "macos"))]
fn tail(bytes: &[u8]) -> String {
    let s = String::from_utf8_lossy(bytes);
    let lines: Vec<&str> = s.lines().filter(|l| !l.trim().is_empty()).collect();
    lines[lines.len().saturating_sub(3)..].join("\n")
}

#[cfg(test)]
mod tests {
    use super::*;

    fn release(v: &str, names: &[&str]) -> Release {
        Release {
            version: v.into(),
            date: String::new(),
            body: String::new(),
            url: String::new(),
            assets: names
                .iter()
                .map(|n| Asset {
                    name: (*n).into(),
                    url: format!("https://x/{n}"),
                    size: 1,
                })
                .collect(),
        }
    }

    #[test]
    fn versions() {
        assert_eq!(parse_version("v0.2.7"), Some((0, 2, 7)));
        assert_eq!(parse_version("0.2.7-dev.12"), Some((0, 2, 7)));
        assert_eq!(parse_version("1.0"), Some((1, 0, 0)));
        assert_eq!(parse_version("abc"), None);
        assert!(is_newer("0.2.10", "0.2.9"));
        assert!(is_newer("0.3.0", "0.2.99"));
        assert!(!is_newer("0.2.7", "0.2.7"));
        assert!(!is_newer("0.2.6", "0.2.7"));
    }

    #[test]
    fn picks_asset_for_install_kind() {
        let r = release(
            "0.2.8",
            &[
                "SHA256SUMS",
                "yetease-music_0.2.8_amd64.deb",
                "yetease-music-0.2.8-x86_64.AppImage",
                "yetease-music-0.2.8-x86_64.AppImage.zsync",
                "yetease-music-0.2.8-linux-x86_64.tar.gz",
                "yetease-cli-0.2.8-linux-x86_64.tar.gz",
                "yetease-music-0.2.8-windows-x64-setup.exe",
                "yetease-music-0.2.8-macos-universal.dmg",
                "yetease-music-0.2.8-android-universal.apk",
            ],
        );
        let name = |k: InstallKind| pick_asset(&k, &r).map(|a| a.name.clone());
        assert_eq!(
            name(InstallKind::Deb).as_deref(),
            Some("yetease-music_0.2.8_amd64.deb")
        );
        assert_eq!(
            name(InstallKind::AppImage("/x".into())).as_deref(),
            Some("yetease-music-0.2.8-x86_64.AppImage")
        );
        assert_eq!(
            name(InstallKind::Tarball).as_deref(),
            Some("yetease-music-0.2.8-linux-x86_64.tar.gz")
        );
        assert_eq!(
            name(InstallKind::WindowsSetup).as_deref(),
            Some("yetease-music-0.2.8-windows-x64-setup.exe")
        );
        assert_eq!(
            name(InstallKind::MacOs).as_deref(),
            Some("yetease-music-0.2.8-macos-universal.dmg")
        );
        // 没有当前架构的 apk 时退回通用包
        assert_eq!(
            name(InstallKind::Android).as_deref(),
            Some("yetease-music-0.2.8-android-universal.apk")
        );
        assert_eq!(name(InstallKind::Flatpak), None);
        assert_eq!(name(InstallKind::Dev), None);
    }

    /// 联网实测：拉取最新发布，下载 AppImage 并校验 SHA256，再替换一个假的 AppImage。
    /// `cargo test -p ncm-core --lib update::tests::e2e_appimage -- --ignored`
    #[cfg(target_os = "linux")]
    #[tokio::test]
    #[ignore]
    async fn e2e_appimage() {
        use std::os::unix::fs::PermissionsExt;
        let releases = fetch_releases().await.expect("fetch releases");
        let r = &releases[0];
        let dir = std::env::temp_dir().join(format!("yetease-update-test-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let target = dir.join("YetEase.AppImage");
        std::fs::write(&target, b"old").unwrap();
        let kind = InstallKind::AppImage(target.clone());
        let asset = pick_asset(&kind, r).expect("AppImage asset");
        let progress = Progress::default();
        let file = download(r, asset, &dir.join("dl"), &progress).await.expect("download");
        assert_eq!(progress.received.load(Ordering::Relaxed), asset.size);
        assert_eq!(apply(&kind, &file).unwrap(), Applied::Restart(target.clone()));
        let meta = std::fs::metadata(&target).unwrap();
        assert_eq!(meta.len(), asset.size);
        assert_ne!(meta.permissions().mode() & 0o111, 0);
        assert!(!file.exists());
        std::fs::remove_dir_all(&dir).unwrap();
    }
}

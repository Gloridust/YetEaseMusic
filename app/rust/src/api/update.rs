//! 应用内更新：检查新版本、下载并安装。逻辑在 ncm_core::update，这里只做转换和保存检查结果。

use std::sync::atomic::Ordering;
use std::sync::{Mutex, OnceLock};

use flutter_rust_bridge::frb;
use ncm_core::update::{self, InstallKind, Progress, Release};

use crate::state::{core, run};

/// 更新方式，界面据此决定按钮文案和流程
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum UpdateMethod {
    /// 下载后自动安装并重启（deb / AppImage / 压缩包 / Windows 安装版）
    Install,
    /// macOS：下载后打开 dmg，由用户拖进「应用程序」
    OpenDmg,
    /// 安卓：下载后调起系统安装器
    Apk,
    /// Flatpak：由 Flatpak 负责更新
    Flatpak,
    /// 免安装版、源码构建：打开发布页手动下载
    Manual,
}

#[derive(Debug, Clone)]
pub struct ReleaseNote {
    pub version: String,
    /// YYYY-MM-DD
    pub date: String,
    /// Markdown
    pub body: String,
}

#[derive(Debug, Clone)]
pub struct UpdateInfo {
    pub current_version: String,
    pub latest_version: String,
    pub has_update: bool,
    /// 比当前版本新的各版本说明，新的在前；已是最新时为最新版本自己的说明
    pub notes: Vec<ReleaseNote>,
    pub page_url: String,
    pub method: UpdateMethod,
    /// 安装包大小（字节），没有对应安装包时为 0
    pub download_size: i64,
}

#[derive(Debug, Clone)]
pub struct DownloadProgress {
    pub received: i64,
    pub total: i64,
}

/// 最近一次检查拿到的最新版本，下载时用
static LATEST: Mutex<Option<Release>> = Mutex::new(None);

fn progress() -> &'static Progress {
    static P: OnceLock<Progress> = OnceLock::new();
    P.get_or_init(Progress::default)
}

fn method_for(kind: &InstallKind) -> UpdateMethod {
    match kind {
        InstallKind::Deb
        | InstallKind::AppImage(_)
        | InstallKind::Tarball
        | InstallKind::WindowsSetup => UpdateMethod::Install,
        InstallKind::MacOs => UpdateMethod::OpenDmg,
        InstallKind::Android => UpdateMethod::Apk,
        InstallKind::Flatpak => UpdateMethod::Flatpak,
        InstallKind::WindowsPortable | InstallKind::Dev => UpdateMethod::Manual,
    }
}

pub async fn check_update() -> anyhow::Result<UpdateInfo> {
    let releases = run(async { Ok(update::fetch_releases().await?) }).await?;
    // 开发用：YETEASE_PRETEND_VERSION=0.2.5 假装是旧版本，用来调试更新流程
    let current = std::env::var("YETEASE_PRETEND_VERSION")
        .unwrap_or_else(|_| env!("CARGO_PKG_VERSION").to_owned());
    let latest = releases
        .first()
        .cloned()
        .ok_or_else(|| anyhow::anyhow!("还没有发布任何版本"))?;
    let has_update = update::is_newer(&latest.version, &current);
    let note = |r: &Release| ReleaseNote {
        version: r.version.clone(),
        date: r.date.clone(),
        body: r.body.clone(),
    };
    let notes = if has_update {
        releases
            .iter()
            .filter(|r| update::is_newer(&r.version, &current))
            .map(note)
            .collect()
    } else {
        vec![note(&latest)]
    };
    let kind = update::install_kind();
    let asset = update::pick_asset(&kind, &latest);
    // 有安装方式但这个版本缺对应的安装包时，退回手动下载
    let method = match (method_for(&kind), asset) {
        (UpdateMethod::Flatpak | UpdateMethod::Manual, _) => method_for(&kind),
        (_, None) => UpdateMethod::Manual,
        (m, Some(_)) => m,
    };
    let info = UpdateInfo {
        current_version: current,
        latest_version: latest.version.clone(),
        has_update,
        notes,
        page_url: latest.url.clone(),
        method,
        download_size: asset.map_or(0, |a| a.size as i64),
    };
    *LATEST.lock().unwrap() = Some(latest);
    Ok(info)
}

/// 把最新版本的安装包下载到 `dir`（并校验），返回文件路径。进度用 [`update_download_progress`] 读
pub async fn download_update(dir: String) -> anyhow::Result<String> {
    let release = LATEST
        .lock()
        .unwrap()
        .clone()
        .ok_or_else(|| anyhow::anyhow!("请先检查更新"))?;
    run(async move {
        let kind = update::install_kind();
        let asset = update::pick_asset(&kind, &release)
            .ok_or_else(|| anyhow::anyhow!("没有适合当前安装方式的安装包"))?;
        let path =
            update::download(&release, asset, std::path::Path::new(&dir), progress()).await?;
        Ok(path.to_string_lossy().into_owned())
    })
    .await
}

#[frb(sync)]
pub fn update_download_progress() -> DownloadProgress {
    let p = progress();
    DownloadProgress {
        received: p.received.load(Ordering::Relaxed) as i64,
        total: p.total.load(Ordering::Relaxed) as i64,
    }
}

#[frb(sync)]
pub fn cancel_update_download() {
    progress().cancel.store(true, Ordering::Relaxed);
}

/// 安装下载好的包。返回 true 表示界面应立即退出（新版本会自动重新打开）；
/// false 表示已打开安装包（macOS），由用户自己完成
pub async fn install_update(path: String) -> anyhow::Result<bool> {
    let applied = tokio::task::spawn_blocking(move || {
        update::apply(&update::install_kind(), std::path::Path::new(&path))
    })
    .await??;
    Ok(match applied {
        update::Applied::Restart(exe) => {
            update::relaunch(&exe)?;
            true
        }
        update::Applied::Quit => true,
        update::Applied::Opened => false,
    })
}

pub fn set_auto_check_update(enable: bool) -> anyhow::Result<()> {
    core()?.update_settings(|s| s.auto_check_update = enable);
    Ok(())
}

/// 自动检查时不再提示这个版本
pub fn skip_update_version(version: String) -> anyhow::Result<()> {
    core()?.update_settings(|s| s.skipped_version = version);
    Ok(())
}

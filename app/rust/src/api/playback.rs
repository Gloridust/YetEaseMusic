//! 初始化、事件流、播放控制、设置。

use flutter_rust_bridge::frb;
use ncm_core::ncm_player::PlayerEvent;
use ncm_core::{Core, CoreEvent, Paths};

use crate::api::types::*;
use crate::frb_generated::StreamSink;
use crate::state::{self, core, lookup, remember, rt, run};

#[frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

/// 启动核心。目录传 None 时用平台默认（Linux: ~/.local/share、~/.cache）。
pub async fn bootstrap(data_dir: Option<String>, cache_dir: Option<String>) -> anyhow::Result<()> {
    if state::CORE.get().is_some() {
        return Ok(());
    }
    run(async move {
        // 两个目录都由界面层给出时（安卓 / iOS 没有桌面标准目录）直接使用，不再查询标准目录
        let paths = match (data_dir, cache_dir) {
            (Some(d), Some(c)) => Paths {
                data_dir: d.into(),
                cache_dir: c.into(),
            },
            (d, c) => {
                let mut paths = Paths::platform_default()?;
                if let Some(d) = d {
                    paths.data_dir = d.into();
                }
                if let Some(c) = c {
                    paths.cache_dir = c.into();
                }
                paths
            }
        };
        ncm_core::logging::init(&paths.data_dir);
        let c = Core::new(paths)?;
        let _ = state::CORE.set(c);
        Ok(())
    })
    .await
}

/// 订阅播放器与核心事件，整个应用生命周期内只需调用一次。
pub fn events(sink: StreamSink<UiEvent>) -> anyhow::Result<()> {
    let c = core()?;
    let mut rx = c.subscribe();
    rt().spawn(async move {
        loop {
            let ev = match rx.recv().await {
                Ok(e) => e,
                Err(tokio::sync::broadcast::error::RecvError::Lagged(_)) => continue,
                Err(_) => break,
            };
            let ui = match ev {
                CoreEvent::Player(PlayerEvent::State(s)) => UiEvent::State(s.into()),
                CoreEvent::Player(PlayerEvent::Position {
                    position_ms,
                    duration_ms,
                    buffered,
                }) => UiEvent::Position {
                    position_ms: position_ms as i64,
                    duration_ms: duration_ms as i64,
                    buffered,
                },
                CoreEvent::Player(PlayerEvent::Error(e)) => UiEvent::Error(e),
                CoreEvent::Player(_) => continue,
                CoreEvent::TrackChanged(s) => UiEvent::TrackChanged(s.as_ref().map(Into::into)),
                CoreEvent::QueueChanged => UiEvent::QueueChanged,
                CoreEvent::SettingsChanged => UiEvent::SettingsChanged,
                CoreEvent::DownloadsChanged => UiEvent::DownloadsChanged,
                CoreEvent::Raise => UiEvent::Raise,
                CoreEvent::Notice(n) => UiEvent::Notice(n),
            };
            if sink.add(ui).is_err() {
                break;
            }
        }
    });
    Ok(())
}

pub fn snapshot() -> anyhow::Result<PlayerSnapshot> {
    let c = core()?;
    let q = c.queue();
    let p = c.player();
    Ok(PlayerSnapshot {
        state: p.state().into(),
        position_ms: p.position_ms() as i64,
        duration_ms: p.duration_ms() as i64,
        volume: p.volume(),
        mode: q.mode.into(),
        current: q.current_song().map(Into::into),
        queue: q.songs.iter().map(Into::into).collect(),
        queue_index: q.current.map(|i| i as i32),
    })
}

/// 用一组歌（之前列表接口返回过的 id）替换队列并从 `index` 开始播放
pub async fn play_songs(ids: Vec<i64>, index: i32) -> anyhow::Result<()> {
    run(async move {
        let c = core()?;
        let ids: Vec<u64> = ids.into_iter().map(|i| i as u64).collect();
        let (_, missing) = lookup(&ids);
        if !missing.is_empty() {
            remember(&c.api().song_detail(&missing).await?);
        }
        let (songs, _) = lookup(&ids);
        c.play_list(songs, index.max(0) as usize).await;
        Ok(())
    })
    .await
}

pub async fn play_index(index: i32) -> anyhow::Result<()> {
    run(async move {
        core()?.play_index(index.max(0) as usize).await;
        Ok(())
    })
    .await
}

/// 下一首播放
pub async fn enqueue_next(id: i64) -> anyhow::Result<()> {
    run(async move {
        let c = core()?;
        let (mut found, missing) = lookup(&[id as u64]);
        if !missing.is_empty() {
            let s = c.api().song_detail(&missing).await?;
            remember(&s);
            found = s;
        }
        if let Some(s) = found.pop() {
            c.enqueue_next(s);
        }
        Ok(())
    })
    .await
}

pub fn toggle() -> anyhow::Result<()> {
    core()?.player().toggle();
    Ok(())
}

pub fn pause() -> anyhow::Result<()> {
    core()?.player().pause();
    Ok(())
}

pub fn resume() -> anyhow::Result<()> {
    core()?.player().play();
    Ok(())
}

pub async fn next() -> anyhow::Result<()> {
    run(async move {
        core()?.next().await;
        Ok(())
    })
    .await
}

pub async fn previous() -> anyhow::Result<()> {
    run(async move {
        core()?.prev().await;
        Ok(())
    })
    .await
}

pub fn seek(position_ms: i64) -> anyhow::Result<()> {
    core()?.player().seek(position_ms.max(0) as u64);
    Ok(())
}

#[frb(sync)]
pub fn position_ms() -> i64 {
    core().map(|c| c.player().position_ms() as i64).unwrap_or(0)
}

pub fn set_volume(volume: f32) -> anyhow::Result<()> {
    core()?.update_settings(|s| s.volume = volume.clamp(0.0, 1.0));
    Ok(())
}

pub fn set_mode(mode: PlayOrder) -> anyhow::Result<()> {
    core()?.update_settings(|s| s.play_mode = mode.into());
    Ok(())
}

pub fn get_settings() -> anyhow::Result<AppSettings> {
    let s = core()?.settings();
    Ok(AppSettings {
        quality: s.quality.into(),
        volume: s.volume,
        mode: s.play_mode.into(),
        use_cn_ip: s.use_cn_ip,
        cn_ip: s.cn_ip,
        ui_scale: s.ui_scale,
        theme: ThemePref::parse(&s.theme),
    })
}

pub fn set_quality(quality: AudioQuality) -> anyhow::Result<()> {
    core()?.update_settings(|s| s.quality = quality.into());
    Ok(())
}

pub fn set_cn_ip(enabled: bool, ip: Option<String>) -> anyhow::Result<()> {
    core()?.update_settings(|s| {
        s.use_cn_ip = enabled;
        if let Some(ip) = ip.filter(|i| !i.trim().is_empty()) {
            s.cn_ip = ip.trim().to_owned();
        }
    });
    Ok(())
}

/// 外观偏好：界面缩放（0.7 ~ 1.5）与主题
pub fn set_appearance(ui_scale: f32, theme: ThemePref) -> anyhow::Result<()> {
    core()?.update_settings(|s| {
        s.ui_scale = ui_scale.clamp(0.7, 1.5);
        s.theme = theme.as_str().into();
    });
    Ok(())
}

pub async fn lyrics(song_id: i64) -> anyhow::Result<Vec<LyricItem>> {
    run(async move {
        Ok(core()?
            .lyrics(song_id as u64)
            .await?
            .into_iter()
            .map(Into::into)
            .collect())
    })
    .await
}

/// 启用系统媒体控制。Linux 上内核已自动启用；Windows 需要传窗口句柄（HWND），macOS 传 None。
pub fn enable_media_controls(hwnd: Option<i64>) -> anyhow::Result<bool> {
    #[cfg(not(target_os = "android"))]
    {
        let c = core()?;
        let _g = rt().enter();
        return Ok(c.enable_media_controls(hwnd.map(|h| h as usize)));
    }
    #[cfg(target_os = "android")]
    {
        let _ = hwnd;
        Ok(false)
    }
}

/// Dart 侧的日志（未捕获异常等）写进同一份日志文件
#[frb(sync)]
pub fn log_message(level: String, message: String) {
    match level.as_str() {
        "error" => tracing::error!(target: "dart", "{message}"),
        "warn" => tracing::warn!(target: "dart", "{message}"),
        _ => tracing::info!(target: "dart", "{message}"),
    }
}

/// 导出脱敏日志到「下载」目录（取不到时放数据目录），返回文件路径
pub fn export_logs(extra: String) -> anyhow::Result<String> {
    let c = core()?;
    let dest = directories::UserDirs::new()
        .and_then(|u| u.download_dir().map(|d| d.to_path_buf()))
        .unwrap_or_else(|| c.paths().data_dir.clone());
    Ok(c.export_logs(&dest, &extra)?.to_string_lossy().into_owned())
}

pub fn log_dir() -> anyhow::Result<String> {
    Ok(ncm_core::logging::log_dir(&core()?.paths().data_dir)
        .to_string_lossy()
        .into_owned())
}

#[frb(sync)]
pub fn app_version() -> String {
    env!("CARGO_PKG_VERSION").to_owned()
}

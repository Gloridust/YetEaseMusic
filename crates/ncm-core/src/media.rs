//! 系统媒体控制：Linux MPRIS（媒体键、GNOME 顶栏 / 锁屏控件）、Windows SMTC、macOS 正在播放。
//!
//! `MediaControls` 不一定是 `Send`，所以放在独立线程里持有；核心通过通道推送元数据与播放状态，
//! 系统发来的控制事件经 `on_event` 回调交给核心处理。

use std::sync::mpsc::{Receiver, Sender, channel};
use std::time::Duration;

use souvlaki::{
    MediaControlEvent, MediaControls, MediaMetadata, MediaPlayback, MediaPosition, PlatformConfig,
};

/// 核心关心的控制事件
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum MediaAction {
    Play,
    Pause,
    Toggle,
    Next,
    Previous,
    Stop,
    /// 绝对位置（毫秒）
    SeekTo(u64),
    /// 相对跳转（毫秒，可为负）
    SeekBy(i64),
    Volume(f32),
    /// 请求把窗口带到前台
    Raise,
    /// 退出程序（托盘菜单）
    Quit,
}

pub enum Update {
    Metadata {
        title: String,
        artist: String,
        album: String,
        cover_url: Option<String>,
        duration_ms: u64,
    },
    Playback {
        playing: bool,
        stopped: bool,
        position_ms: u64,
    },
    Volume(f32),
}

pub struct MediaHandle {
    tx: Sender<Update>,
}

impl MediaHandle {
    pub fn update(&self, u: Update) {
        let _ = self.tx.send(u);
    }
}

/// 启动媒体控制线程。`hwnd` 只在 Windows 上需要（Flutter 窗口句柄）。
pub fn start(
    hwnd: Option<*mut std::ffi::c_void>,
    on_event: impl Fn(MediaAction) + Send + 'static,
) -> Option<MediaHandle> {
    let (tx, rx) = channel::<Update>();
    let hwnd_addr = hwnd.map(|p| p as usize);
    let (ready_tx, ready_rx) = channel::<bool>();
    std::thread::Builder::new()
        .name("ncm-media".into())
        .spawn(move || run(hwnd_addr, rx, ready_tx, on_event))
        .ok()?;
    match ready_rx.recv_timeout(Duration::from_secs(5)) {
        Ok(true) => Some(MediaHandle { tx }),
        _ => None,
    }
}

fn run(
    hwnd_addr: Option<usize>,
    rx: Receiver<Update>,
    ready: Sender<bool>,
    on_event: impl Fn(MediaAction) + Send + 'static,
) {
    let config = PlatformConfig {
        dbus_name: "yetease",
        display_name: "YetEase Music",
        hwnd: hwnd_addr.map(|a| a as *mut std::ffi::c_void),
    };
    let mut controls = match MediaControls::new(config) {
        Ok(c) => c,
        Err(e) => {
            tracing::warn!("media controls unavailable: {e:?}");
            let _ = ready.send(false);
            return;
        }
    };
    let attached = controls.attach(move |e: MediaControlEvent| {
        let action = match e {
            MediaControlEvent::Play => MediaAction::Play,
            MediaControlEvent::Pause => MediaAction::Pause,
            MediaControlEvent::Toggle => MediaAction::Toggle,
            MediaControlEvent::Next => MediaAction::Next,
            MediaControlEvent::Previous => MediaAction::Previous,
            MediaControlEvent::Stop => MediaAction::Stop,
            MediaControlEvent::Seek(d) => MediaAction::SeekBy(signed(d, 10_000)),
            MediaControlEvent::SeekBy(d, by) => {
                MediaAction::SeekBy(signed(d, by.as_millis() as i64))
            }
            MediaControlEvent::SetPosition(MediaPosition(p)) => {
                MediaAction::SeekTo(p.as_millis() as u64)
            }
            MediaControlEvent::SetVolume(v) => MediaAction::Volume(v.clamp(0.0, 1.0) as f32),
            MediaControlEvent::Raise => MediaAction::Raise,
            _ => return,
        };
        on_event(action);
    });
    if let Err(e) = attached {
        tracing::warn!("media controls attach failed: {e:?}");
        let _ = ready.send(false);
        return;
    }
    let _ = ready.send(true);

    while let Ok(u) = rx.recv() {
        let r = match u {
            Update::Metadata {
                title,
                artist,
                album,
                cover_url,
                duration_ms,
            } => controls.set_metadata(MediaMetadata {
                title: Some(&title),
                artist: Some(&artist),
                album: Some(&album),
                cover_url: cover_url.as_deref(),
                duration: (duration_ms > 0).then(|| Duration::from_millis(duration_ms)),
            }),
            Update::Playback {
                playing,
                stopped,
                position_ms,
            } => {
                let progress = Some(MediaPosition(Duration::from_millis(position_ms)));
                controls.set_playback(if stopped {
                    MediaPlayback::Stopped
                } else if playing {
                    MediaPlayback::Playing { progress }
                } else {
                    MediaPlayback::Paused { progress }
                })
            }
            Update::Volume(v) => set_volume(&mut controls, v),
        };
        if let Err(e) = r {
            tracing::debug!("media controls update failed: {e:?}");
        }
    }
}

#[cfg(target_os = "linux")]
fn set_volume(c: &mut MediaControls, v: f32) -> Result<(), souvlaki::Error> {
    c.set_volume(v as f64)
}

#[cfg(not(target_os = "linux"))]
fn set_volume(_: &mut MediaControls, _: f32) -> Result<(), souvlaki::Error> {
    Ok(())
}

fn signed(d: souvlaki::SeekDirection, ms: i64) -> i64 {
    match d {
        souvlaki::SeekDirection::Forward => ms,
        souvlaki::SeekDirection::Backward => -ms,
    }
}

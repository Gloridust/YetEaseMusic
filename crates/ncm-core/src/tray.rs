//! 系统托盘：关闭主窗口后留在托盘里继续播放。
//!
//! - Linux：StatusNotifierItem（KDE、Xfce、Cinnamon、装了 AppIndicator 扩展的 GNOME 等）。走 D-Bus，
//!   不依赖 libappindicator，Flatpak 里只需要 `--talk-name=org.kde.StatusNotifierWatcher`。
//!   桌面没有托盘宿主（例如未装扩展的 GNOME）时 `start` 返回 `None`，界面据此决定关窗即退出。
//! - Windows：通知区域图标，放在独立线程里跑消息循环。
//! - 其他平台返回 `None`；macOS 关窗后由程序坞图标唤回，不需要托盘。
//!
//! 菜单事件统一转成 [`MediaAction`]，由核心处理（播放控制直接执行，显示窗口 / 退出交给界面）。

use crate::media::MediaAction;

/// 菜单与点击事件的回调
pub type OnEvent = std::sync::Arc<dyn Fn(MediaAction) + Send + Sync>;

pub struct TrayHandle {
    inner: imp::Handle,
}

impl TrayHandle {
    /// 更新悬停提示与菜单里的播放 / 暂停文字
    pub fn update(&self, song: Option<String>, playing: bool) {
        self.inner.update(song, playing);
    }
}

/// 启动托盘。`icon_png` 是托盘图标（建议 64×64 的 PNG）。
pub async fn start(icon_png: &'static [u8], on_event: OnEvent) -> Option<TrayHandle> {
    let inner = imp::start(icon_png, on_event).await?;
    Some(TrayHandle { inner })
}

const APP_NAME: &str = "YetEase Music";

fn tooltip(song: &Option<String>) -> String {
    match song {
        Some(s) => format!("{APP_NAME} · {s}"),
        None => APP_NAME.to_owned(),
    }
}

fn play_label(playing: bool) -> &'static str {
    if playing { "暂停" } else { "播放" }
}

/// PNG → 每像素 RGBA 四字节
fn decode_rgba(png_bytes: &[u8]) -> Option<(u32, u32, Vec<u8>)> {
    let mut decoder = png::Decoder::new(std::io::Cursor::new(png_bytes));
    decoder.set_transformations(png::Transformations::EXPAND | png::Transformations::ALPHA);
    let mut reader = decoder.read_info().ok()?;
    let mut buf = vec![0; reader.output_buffer_size()?];
    let info = reader.next_frame(&mut buf).ok()?;
    buf.truncate(info.buffer_size());
    let rgba = match info.color_type {
        png::ColorType::Rgba => buf,
        png::ColorType::GrayscaleAlpha => buf.chunks_exact(2).flat_map(|p| [p[0], p[0], p[0], p[1]]).collect(),
        _ => return None,
    };
    Some((info.width, info.height, rgba))
}

#[cfg(target_os = "linux")]
mod imp {
    use super::*;
    use ksni::TrayMethods;
    use ksni::menu::{MenuItem, StandardItem};

    struct Tray {
        icon: Vec<ksni::Icon>,
        song: Option<String>,
        playing: bool,
        on_event: OnEvent,
    }

    impl Tray {
        fn item(label: &str, action: MediaAction) -> MenuItem<Self> {
            StandardItem {
                label: label.into(),
                activate: Box::new(move |t: &mut Self| (t.on_event)(action)),
                ..Default::default()
            }
            .into()
        }
    }

    impl ksni::Tray for Tray {
        fn id(&self) -> String {
            "io.github.gloridust.YetEaseMusic".into()
        }

        fn title(&self) -> String {
            APP_NAME.into()
        }

        fn icon_pixmap(&self) -> Vec<ksni::Icon> {
            self.icon.clone()
        }

        fn tool_tip(&self) -> ksni::ToolTip {
            ksni::ToolTip {
                title: tooltip(&self.song),
                ..Default::default()
            }
        }

        // 左键单击托盘图标：显示主窗口
        fn activate(&mut self, _x: i32, _y: i32) {
            (self.on_event)(MediaAction::Raise);
        }

        fn menu(&self) -> Vec<MenuItem<Self>> {
            vec![
                Self::item("显示主窗口", MediaAction::Raise),
                MenuItem::Separator,
                Self::item(play_label(self.playing), MediaAction::Toggle),
                Self::item("上一首", MediaAction::Previous),
                Self::item("下一首", MediaAction::Next),
                MenuItem::Separator,
                Self::item("退出", MediaAction::Quit),
            ]
        }
    }

    pub struct Handle(ksni::Handle<Tray>);

    impl Handle {
        pub fn update(&self, song: Option<String>, playing: bool) {
            let h = self.0.clone();
            tokio::spawn(async move {
                h.update(|t| {
                    t.song = song;
                    t.playing = playing;
                })
                .await;
            });
        }
    }

    pub async fn start(icon_png: &'static [u8], on_event: OnEvent) -> Option<Handle> {
        // StatusNotifierItem 的图标是 ARGB32、网络字节序
        let icon = decode_rgba(icon_png)
            .map(|(w, h, rgba)| {
                let data = rgba.chunks_exact(4).flat_map(|p| [p[3], p[0], p[1], p[2]]).collect();
                vec![ksni::Icon { width: w as i32, height: h as i32, data }]
            })
            .unwrap_or_default();
        let tray = Tray {
            icon,
            song: None,
            playing: false,
            on_event,
        };
        match tray.spawn().await {
            Ok(h) => Some(Handle(h)),
            Err(e) => {
                tracing::info!("system tray unavailable: {e}");
                None
            }
        }
    }
}

#[cfg(windows)]
mod imp {
    use super::*;
    use std::sync::mpsc::{Sender, channel};
    use std::time::Duration;
    use tray_icon::menu::{Menu, MenuEvent, MenuItem, PredefinedMenuItem};
    use tray_icon::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent};
    use windows_sys::Win32::UI::WindowsAndMessaging::{DispatchMessageW, MSG, PM_REMOVE, PeekMessageW, TranslateMessage};

    pub struct Handle(Sender<(Option<String>, bool)>);

    impl Handle {
        pub fn update(&self, song: Option<String>, playing: bool) {
            let _ = self.0.send((song, playing));
        }
    }

    pub async fn start(icon_png: &'static [u8], on_event: OnEvent) -> Option<Handle> {
        let (tx, rx) = channel::<(Option<String>, bool)>();
        let (ready_tx, ready_rx) = tokio::sync::oneshot::channel::<bool>();
        // 托盘图标属于创建它的线程，该线程必须一直处理窗口消息
        std::thread::Builder::new()
            .name("ncm-tray".into())
            .spawn(move || {
                let show = MenuItem::new("显示主窗口", true, None);
                let toggle = MenuItem::new(play_label(false), true, None);
                let prev = MenuItem::new("上一首", true, None);
                let next = MenuItem::new("下一首", true, None);
                let quit = MenuItem::new("退出", true, None);
                let menu = Menu::new();
                let sep1 = PredefinedMenuItem::separator();
                let sep2 = PredefinedMenuItem::separator();
                let built = menu.append_items(&[&show, &sep1, &toggle, &prev, &next, &sep2, &quit]);
                let icon = decode_rgba(icon_png).and_then(|(w, h, rgba)| tray_icon::Icon::from_rgba(rgba, w, h).ok());
                let tray = built.ok().and_then(|_| {
                    let mut b = TrayIconBuilder::new().with_menu(Box::new(menu)).with_tooltip(APP_NAME);
                    if let Some(icon) = icon {
                        b = b.with_icon(icon);
                    }
                    b.build().ok()
                });
                let Some(tray) = tray else {
                    let _ = ready_tx.send(false);
                    return;
                };

                let ids = [
                    (show.id().clone(), MediaAction::Raise),
                    (toggle.id().clone(), MediaAction::Toggle),
                    (prev.id().clone(), MediaAction::Previous),
                    (next.id().clone(), MediaAction::Next),
                    (quit.id().clone(), MediaAction::Quit),
                ];
                let on_menu = on_event.clone();
                MenuEvent::set_event_handler(Some(move |e: MenuEvent| {
                    if let Some((_, a)) = ids.iter().find(|(id, _)| *id == e.id) {
                        on_menu(*a);
                    }
                }));
                // 左键单击托盘图标：显示主窗口
                TrayIconEvent::set_event_handler(Some(move |e: TrayIconEvent| {
                    if let TrayIconEvent::Click {
                        button: MouseButton::Left,
                        button_state: MouseButtonState::Up,
                        ..
                    } = e
                    {
                        on_event(MediaAction::Raise);
                    }
                }));
                let _ = ready_tx.send(true);

                loop {
                    // SAFETY: 标准的 Win32 消息泵，MSG 由系统填充
                    unsafe {
                        let mut msg: MSG = std::mem::zeroed();
                        while PeekMessageW(&mut msg, std::ptr::null_mut(), 0, 0, PM_REMOVE) != 0 {
                            TranslateMessage(&msg);
                            DispatchMessageW(&msg);
                        }
                    }
                    match rx.recv_timeout(Duration::from_millis(50)) {
                        Ok((song, playing)) => {
                            let _ = tray.set_tooltip(Some(tooltip(&song)));
                            toggle.set_text(play_label(playing));
                        }
                        Err(std::sync::mpsc::RecvTimeoutError::Timeout) => {}
                        Err(std::sync::mpsc::RecvTimeoutError::Disconnected) => break,
                    }
                }
            })
            .ok()?;
        ready_rx.await.ok().filter(|ok| *ok).map(|_| Handle(tx))
    }
}

#[cfg(not(any(target_os = "linux", windows)))]
mod imp {
    use super::*;

    pub struct Handle;

    impl Handle {
        pub fn update(&self, _song: Option<String>, _playing: bool) {}
    }

    pub async fn start(_icon_png: &'static [u8], _on_event: OnEvent) -> Option<Handle> {
        let _ = (tooltip, play_label, decode_rgba);
        None
    }
}

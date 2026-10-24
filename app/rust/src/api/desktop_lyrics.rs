//! 桌面歌词：主程序开一个只监听 127.0.0.1 的端口，按行推送 JSON；
//! 歌词窗口（同一个程序以 `--desktop-lyrics --port=N` 启动）连上来接收，并可回传播放控制命令。
//!
//! 消息格式（每行一个 JSON）：
//! - 主 → 窗口：`{"k":"track","title":…,"artist":…,"lines":[LyricLine…]}`、`{"k":"pos","ms":…,"playing":…}`
//! - 窗口 → 主：`{"k":"cmd","cmd":"toggle"|"next"|"prev"}`

use std::sync::{Mutex, OnceLock};

use ncm_core::ncm_player::PlaybackState;
use ncm_core::{CoreEvent, LyricLine};
use serde::{Deserialize, Serialize};
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::net::{TcpListener, TcpStream};
use tokio::sync::{broadcast, mpsc};

use crate::api::types::LyricItem;
use crate::frb_generated::StreamSink;
use crate::state::{core, rt};

#[derive(Serialize, Deserialize, Clone)]
#[serde(tag = "k", rename_all = "lowercase")]
enum Msg {
    Track {
        title: String,
        artist: String,
        lines: Vec<LyricLine>,
    },
    Pos {
        ms: u64,
        playing: bool,
    },
    Cmd {
        cmd: String,
    },
}

static SERVER_PORT: OnceLock<u16> = OnceLock::new();

/// 主程序调用：启动（或复用）歌词推送服务，返回端口
pub async fn desktop_lyrics_serve() -> anyhow::Result<i32> {
    if let Some(p) = SERVER_PORT.get() {
        return Ok(*p as i32);
    }
    let port = rt()
        .spawn(async move {
            let listener = TcpListener::bind("127.0.0.1:0").await?;
            let port = listener.local_addr()?.port();
            let (tx, _) = broadcast::channel::<String>(64);
            let current = std::sync::Arc::new(Mutex::new(None::<String>));
            tokio::spawn(publisher(tx.clone(), current.clone()));
            tokio::spawn(async move {
                while let Ok((sock, _)) = listener.accept().await {
                    tokio::spawn(serve_client(sock, tx.subscribe(), current.clone()));
                }
            });
            anyhow::Ok(port)
        })
        .await??;
    let _ = SERVER_PORT.set(port);
    Ok(port as i32)
}

/// 订阅核心事件：换歌时取歌词并广播，播放中每 120ms 广播一次进度
async fn publisher(tx: broadcast::Sender<String>, current: std::sync::Arc<Mutex<Option<String>>>) {
    let Ok(c) = core() else { return };
    let mut events = c.subscribe();
    let send_track = |c: std::sync::Arc<ncm_core::Core>,
                      tx: broadcast::Sender<String>,
                      current: std::sync::Arc<Mutex<Option<String>>>| async move {
        let Some(song) = c.current_song() else { return };
        let lines = c.lyrics(song.id).await.unwrap_or_default();
        let msg = serde_json::to_string(&Msg::Track {
            title: song.name.clone(),
            artist: song.artist_names(),
            lines,
        })
        .unwrap_or_default();
        // 歌词取回来时可能已经换了下一首，以当前歌曲为准
        if c.current_song().map(|s| s.id) == Some(song.id) {
            *current.lock().unwrap() = Some(msg.clone());
            let _ = tx.send(msg);
        }
    };
    send_track(c.clone(), tx.clone(), current.clone()).await;
    let mut tick = tokio::time::interval(std::time::Duration::from_millis(120));
    loop {
        tokio::select! {
            ev = events.recv() => match ev {
                Ok(CoreEvent::TrackChanged(_)) => {
                    tokio::spawn(send_track(c.clone(), tx.clone(), current.clone()));
                }
                Err(broadcast::error::RecvError::Closed) => return,
                _ => {}
            },
            _ = tick.tick() => {
                if tx.receiver_count() == 0 {
                    continue;
                }
                let p = c.player();
                let msg = Msg::Pos { ms: p.position_ms(), playing: p.state() == PlaybackState::Playing };
                let _ = tx.send(serde_json::to_string(&msg).unwrap_or_default());
            }
        }
    }
}

async fn serve_client(
    sock: TcpStream,
    mut rx: broadcast::Receiver<String>,
    current: std::sync::Arc<Mutex<Option<String>>>,
) {
    let (r, mut w) = sock.into_split();
    let first = current.lock().unwrap().clone();
    if let Some(m) = first
        && w.write_all(format!("{m}\n").as_bytes()).await.is_err()
    {
        return;
    }
    // 读取窗口发来的控制命令
    tokio::spawn(async move {
        let mut lines = BufReader::new(r).lines();
        while let Ok(Some(l)) = lines.next_line().await {
            let Ok(Msg::Cmd { cmd }) = serde_json::from_str::<Msg>(&l) else {
                continue;
            };
            let Ok(c) = core() else { break };
            match cmd.as_str() {
                "toggle" => c.player().toggle(),
                "next" => c.next().await,
                "prev" => c.prev().await,
                _ => {}
            }
        }
    });
    loop {
        match rx.recv().await {
            Ok(m) => {
                if w.write_all(format!("{m}\n").as_bytes()).await.is_err() {
                    return;
                }
            }
            Err(broadcast::error::RecvError::Lagged(_)) => continue,
            Err(_) => return,
        }
    }
}

// ---------- 歌词窗口一侧 ----------

#[derive(Debug, Clone)]
pub enum DesktopLyricsEvent {
    Track {
        title: String,
        artist: String,
        lines: Vec<LyricItem>,
    },
    Position {
        ms: i64,
        playing: bool,
    },
    /// 主程序已退出
    Closed,
}

static CMD_TX: OnceLock<mpsc::UnboundedSender<String>> = OnceLock::new();

/// 歌词窗口调用：连接主程序，事件通过流推给 Dart
pub fn desktop_lyrics_connect(
    port: i32,
    sink: StreamSink<DesktopLyricsEvent>,
) -> anyhow::Result<()> {
    let (cmd_tx, mut cmd_rx) = mpsc::unbounded_channel::<String>();
    let _ = CMD_TX.set(cmd_tx);
    rt().spawn(async move {
        let Ok(sock) = TcpStream::connect(("127.0.0.1", port as u16)).await else {
            let _ = sink.add(DesktopLyricsEvent::Closed);
            return;
        };
        let (r, mut w) = sock.into_split();
        tokio::spawn(async move {
            while let Some(cmd) = cmd_rx.recv().await {
                let line = serde_json::to_string(&Msg::Cmd { cmd }).unwrap_or_default();
                if w.write_all(format!("{line}\n").as_bytes()).await.is_err() {
                    break;
                }
            }
        });
        let mut lines = BufReader::new(r).lines();
        while let Ok(Some(l)) = lines.next_line().await {
            let ev = match serde_json::from_str::<Msg>(&l) {
                Ok(Msg::Track {
                    title,
                    artist,
                    lines,
                }) => DesktopLyricsEvent::Track {
                    title,
                    artist,
                    lines: lines.into_iter().map(Into::into).collect(),
                },
                Ok(Msg::Pos { ms, playing }) => DesktopLyricsEvent::Position {
                    ms: ms as i64,
                    playing,
                },
                _ => continue,
            };
            if sink.add(ev).is_err() {
                return;
            }
        }
        let _ = sink.add(DesktopLyricsEvent::Closed);
    });
    Ok(())
}

/// 歌词窗口发送控制命令：toggle / next / prev
pub fn desktop_lyrics_command(cmd: String) {
    if let Some(tx) = CMD_TX.get() {
        let _ = tx.send(cmd);
    }
}

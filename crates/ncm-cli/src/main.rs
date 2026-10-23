//! YetEaseMusic 命令行：与桌面端共用 ncm-core，不依赖 Flutter。

use std::io::Write;
use std::time::Duration;

use anyhow::{Context, Result, bail};
use clap::{Parser, Subcommand};
use ncm_core::ncm_api::{QrStatus, Quality, Song, qr_login_url};
use ncm_core::ncm_player::{PlaybackState, PlayerEvent};
use ncm_core::{Core, CoreEvent, Paths};
use qrcode::QrCode;
use qrcode::render::unicode;

#[derive(Parser)]
#[command(name = "yetease", version, about = "网易云音乐第三方客户端（命令行）")]
struct Cli {
    #[command(subcommand)]
    cmd: Cmd,
}

#[derive(Subcommand)]
enum Cmd {
    /// 扫码登录
    Login,
    /// 退出登录
    Logout,
    /// 当前账号
    Whoami,
    /// 搜索单曲
    Search {
        keywords: Vec<String>,
        #[arg(short, long, default_value_t = 20)]
        limit: u32,
    },
    /// 播放：参数是歌曲 id 或搜索关键词（播放第一个结果）
    Play {
        query: Vec<String>,
        /// standard / higher / exhigh / lossless / hires
        #[arg(short, long)]
        quality: Option<String>,
        #[arg(short, long)]
        volume: Option<f32>,
    },
    /// 我的歌单
    Playlists,
    /// 查看歌单；加 --play 从头播放
    Playlist {
        id: u64,
        #[arg(long)]
        play: bool,
    },
    /// 每日推荐（需登录）；加 --play 播放
    Daily {
        #[arg(long)]
        play: bool,
    },
    /// 打印歌词
    Lyrics { id: u64 },
}

#[tokio::main]
async fn main() -> Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(tracing_subscriber::EnvFilter::from_default_env())
        .with_writer(std::io::stderr)
        .init();
    let cli = Cli::parse();
    let core = Core::new(Paths::platform_default()?)?;
    let api = core.api();

    match cli.cmd {
        Cmd::Login => login(&core).await?,
        Cmd::Logout => {
            core.logout().await?;
            println!("已退出登录");
        }
        Cmd::Whoami => match api.account().await? {
            Some(a) => println!("{}（uid {}，vipType {}）", a.nickname, a.user_id, a.vip_type),
            None => println!("未登录"),
        },
        Cmd::Search { keywords, limit } => {
            let (songs, total) = api.search_songs(&keywords.join(" "), limit, 0).await?;
            println!("共 {total} 条");
            print_songs(&songs);
        }
        Cmd::Play { query, quality, volume } => {
            if let Some(q) = quality {
                let q = parse_quality(&q)?;
                core.update_settings(|s| s.quality = q);
            }
            if let Some(v) = volume {
                core.update_settings(|s| s.volume = v);
            }
            let q = query.join(" ");
            let songs = match q.parse::<u64>() {
                Ok(id) => api.song_detail(&[id]).await?,
                Err(_) => api.search_songs(&q, 1, 0).await?.0,
            };
            if songs.is_empty() {
                bail!("没找到：{q}");
            }
            play(&core, songs, 0).await?;
        }
        Cmd::Playlists => {
            let acc = api.account().await?.context("请先 `yetease login`")?;
            for p in api.user_playlists(acc.user_id, 1000, 0).await? {
                let tag = if p.subscribed { "收藏" } else { "创建" };
                println!("{:>12}  [{tag}] {}（{} 首）", p.id, p.name, p.track_count);
            }
        }
        Cmd::Playlist { id, play: do_play } => {
            let d = api.playlist_detail(id).await?;
            println!("{}（{} 首）", d.summary.name, d.tracks.len());
            if do_play {
                play(&core, d.tracks, 0).await?;
            } else {
                print_songs(&d.tracks);
            }
        }
        Cmd::Daily { play: do_play } => {
            let songs = api.daily_songs().await?;
            if do_play {
                play(&core, songs, 0).await?;
            } else {
                print_songs(&songs);
            }
        }
        Cmd::Lyrics { id } => {
            for l in core.lyrics(id).await? {
                let t = l.time_ms / 1000;
                match l.translation {
                    Some(tr) => println!("[{:02}:{:02}] {}  ／ {tr}", t / 60, t % 60, l.text),
                    None => println!("[{:02}:{:02}] {}", t / 60, t % 60, l.text),
                }
            }
        }
    }
    Ok(())
}

fn parse_quality(s: &str) -> Result<Quality> {
    Ok(match s {
        "standard" => Quality::Standard,
        "higher" => Quality::Higher,
        "exhigh" => Quality::ExHigh,
        "lossless" => Quality::Lossless,
        "hires" => Quality::HiRes,
        _ => bail!("未知音质：{s}"),
    })
}

fn print_songs(songs: &[Song]) {
    for (i, s) in songs.iter().enumerate() {
        let vip = if s.fee == 1 { " [VIP]" } else { "" };
        println!(
            "{:>3}. {:>11}  {} - {}  {}{vip}",
            i + 1,
            s.id,
            s.name,
            s.artist_names(),
            fmt_ms(s.duration_ms)
        );
    }
}

fn fmt_ms(ms: u64) -> String {
    let s = ms / 1000;
    format!("{:02}:{:02}", s / 60, s % 60)
}

async fn login(core: &Core) -> Result<()> {
    let api = core.api();
    loop {
        let key = api.qr_key().await?;
        let code = QrCode::new(qr_login_url(&key))?;
        let img = code
            .render::<unicode::Dense1x2>()
            .dark_color(unicode::Dense1x2::Light)
            .light_color(unicode::Dense1x2::Dark)
            .build();
        println!("{img}\n用网易云音乐 App 扫码登录");
        loop {
            tokio::time::sleep(Duration::from_secs(2)).await;
            match core.qr_check(&key).await? {
                QrStatus::Waiting => {}
                QrStatus::Scanned { nickname, .. } => println!("{nickname} 已扫码，请在手机上确认"),
                QrStatus::Authorized => {
                    let who = api.account().await?.map(|a| a.nickname).unwrap_or_default();
                    println!("登录成功：{who}");
                    return Ok(());
                }
                QrStatus::Expired => {
                    println!("二维码已过期，重新生成");
                    break;
                }
                QrStatus::Other { code, message } => bail!("登录失败 {code}: {message}"),
            }
        }
    }
}

/// 播放一组歌直到全部结束或 Ctrl+C
async fn play(core: &std::sync::Arc<Core>, songs: Vec<Song>, index: usize) -> Result<()> {
    let mut rx = core.subscribe();
    core.play_list(songs, index).await;
    let mut title = core.current_song().map(|s| format!("{} - {}", s.name, s.artist_names())).unwrap_or_default();
    loop {
        tokio::select! {
            _ = tokio::signal::ctrl_c() => {
                core.player().stop();
                println!();
                return Ok(());
            }
            ev = rx.recv() => {
                let Ok(ev) = ev else { continue };
                match ev {
                    CoreEvent::TrackChanged(Some(s)) => {
                        title = format!("{} - {}", s.name, s.artist_names());
                        println!();
                    }
                    CoreEvent::Notice(n) => println!("\n{n}"),
                    CoreEvent::Player(PlayerEvent::Position { position_ms, duration_ms, buffered }) => {
                        print!("\r▶ {title}  {} / {}  缓冲 {:>3.0}%   ", fmt_ms(position_ms), fmt_ms(duration_ms), buffered * 100.0);
                        let _ = std::io::stdout().flush();
                    }
                    CoreEvent::Player(PlayerEvent::Error(e)) => println!("\n播放出错：{e}"),
                    CoreEvent::Player(PlayerEvent::State(PlaybackState::Stopped)) => {
                        // 自动切歌时会短暂经过 Stopped；稍等确认确实没有下一首
                        tokio::time::sleep(Duration::from_millis(1500)).await;
                        if core.player().state() == PlaybackState::Stopped {
                            println!();
                            return Ok(());
                        }
                    }
                    _ => {}
                }
            }
        }
    }
}

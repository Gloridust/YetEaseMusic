//! 音频引擎：symphonia 解码 + cpal 输出 + 边下边播缓存。
//!
//! 所有解码与输出都在独立线程里进行；[`Player`] 只是发命令的句柄，可以随意 clone。
//! 状态变化通过 [`PlayerEvent`] 通道推出，进度也可以随时用 [`Player::position_ms`] 读取。

mod output;
mod source;

use std::path::PathBuf;
use std::sync::atomic::Ordering;
use std::sync::{Arc, Mutex, OnceLock};
use std::time::{Duration, Instant};

use crossbeam_channel::{Receiver, RecvTimeoutError, Sender, TryRecvError, unbounded};
use symphonia::core::codecs::CodecParameters;
use symphonia::core::codecs::audio::{AudioDecoder, AudioDecoderOptions};
use symphonia::core::errors::Error as SymError;
use symphonia::core::formats::probe::Hint;
use symphonia::core::formats::{FormatOptions, FormatReader, SeekMode, SeekTo, TrackType};
use symphonia::core::io::{MediaSource, MediaSourceStream};
use symphonia::core::meta::MetadataOptions;
use symphonia::core::units::{Time, TimeBase, Timestamp};

use output::{Output, Shared};
pub use source::DownloadHandle;
use source::StreamingSource;

#[derive(Debug, thiserror::Error)]
pub enum Error {
    #[error("audio output: {0}")]
    Output(String),
    #[error("decode: {0}")]
    Decode(String),
    #[error("io: {0}")]
    Io(#[from] std::io::Error),
}

#[derive(Debug, Clone)]
pub enum Source {
    /// 网络地址；`cache_path` 下载完成后即为离线缓存
    Url {
        url: String,
        cache_path: PathBuf,
    },
    File(PathBuf),
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PlaybackState {
    Stopped,
    Loading,
    Playing,
    Paused,
}

#[derive(Debug, Clone, PartialEq)]
pub enum PlayerEvent {
    State(PlaybackState),
    /// 新曲目解码就绪
    Loaded {
        duration_ms: u64,
        sample_rate: u32,
        channels: u16,
    },
    Position {
        position_ms: u64,
        duration_ms: u64,
        buffered: f32,
    },
    /// 当前曲目自然播完
    Ended,
    Error(String),
}

enum Cmd {
    Load {
        source: Source,
        autoplay: bool,
        start_ms: u64,
    },
    Play,
    Pause,
    Stop,
    Seek(u64),
}

/// 与 UI 共享的只读状态
#[derive(Default)]
struct Status {
    state: Mutex<Option<PlaybackState>>,
    base_ms: std::sync::atomic::AtomicU64,
    rate: std::sync::atomic::AtomicU32,
    duration_ms: std::sync::atomic::AtomicU64,
}

#[derive(Clone)]
pub struct Player {
    tx: Sender<Cmd>,
    shared: Arc<Shared>,
    status: Arc<Status>,
}

impl Player {
    pub fn new() -> (Self, Receiver<PlayerEvent>) {
        let (tx, rx) = unbounded();
        let (ev_tx, ev_rx) = unbounded();
        let shared = Shared::new(1.0);
        let status = Arc::new(Status::default());
        let (s, st) = (shared.clone(), status.clone());
        std::thread::Builder::new()
            .name("ncm-player".into())
            .spawn(move || Engine::new(rx, ev_tx, s, st).run())
            .expect("spawn player thread");
        (Self { tx, shared, status }, ev_rx)
    }

    pub fn load(&self, source: Source, autoplay: bool) {
        self.load_at(source, autoplay, 0);
    }

    /// 从 `start_ms` 开始播放（恢复上次进度用）
    pub fn load_at(&self, source: Source, autoplay: bool, start_ms: u64) {
        let _ = self.tx.send(Cmd::Load {
            source,
            autoplay,
            start_ms,
        });
    }

    pub fn play(&self) {
        let _ = self.tx.send(Cmd::Play);
    }

    pub fn pause(&self) {
        let _ = self.tx.send(Cmd::Pause);
    }

    pub fn toggle(&self) {
        match self.state() {
            PlaybackState::Playing => self.pause(),
            _ => self.play(),
        }
    }

    pub fn stop(&self) {
        let _ = self.tx.send(Cmd::Stop);
    }

    pub fn seek(&self, ms: u64) {
        let _ = self.tx.send(Cmd::Seek(ms));
    }

    /// 0.0 ~ 1.0，内部按平方曲线映射，听感更线性
    pub fn set_volume(&self, v: f32) {
        let v = v.clamp(0.0, 1.0);
        self.shared
            .volume
            .store((v * v).to_bits(), Ordering::Relaxed);
    }

    pub fn volume(&self) -> f32 {
        f32::from_bits(self.shared.volume.load(Ordering::Relaxed)).sqrt()
    }

    pub fn state(&self) -> PlaybackState {
        self.status
            .state
            .lock()
            .unwrap()
            .unwrap_or(PlaybackState::Stopped)
    }

    pub fn position_ms(&self) -> u64 {
        position_ms(&self.shared, &self.status)
    }

    pub fn duration_ms(&self) -> u64 {
        self.status.duration_ms.load(Ordering::Relaxed)
    }
}

fn position_ms(shared: &Shared, status: &Status) -> u64 {
    let rate = status.rate.load(Ordering::Relaxed) as u64;
    let frames = shared.played_frames.load(Ordering::Relaxed);
    let base = status.base_ms.load(Ordering::Relaxed);
    if rate == 0 {
        base
    } else {
        base + frames * 1000 / rate
    }
}

/// 下载用的共享 HTTP 客户端
pub(crate) fn http_client() -> &'static reqwest::blocking::Client {
    static C: OnceLock<reqwest::blocking::Client> = OnceLock::new();
    C.get_or_init(|| {
        let _ = rustls::crypto::ring::default_provider().install_default();
        let builder = reqwest::blocking::Client::builder();
        #[cfg(target_os = "android")]
        let builder = builder.tls_backend_preconfigured(android_tls());
        builder
            .connect_timeout(Duration::from_secs(10))
            .user_agent("Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36")
            .build()
            .expect("http client")
    })
}

struct Track {
    reader: Box<dyn FormatReader>,
    decoder: Box<dyn AudioDecoder>,
    track_id: u32,
    #[allow(dead_code)]
    time_base: Option<TimeBase>,
    sample_rate: u32,
    channels: u16,
    duration_ms: u64,
    /// 跳转后丢弃此时间戳之前的样本，实现精确跳转
    skip_until: Timestamp,
    eof: bool,
    _download: Option<DownloadHandle>,
}

struct Engine {
    rx: Receiver<Cmd>,
    ev: Sender<PlayerEvent>,
    shared: Arc<Shared>,
    status: Arc<Status>,
    output: Option<Output>,
    track: Option<Track>,
    state: PlaybackState,
    /// 当前解码块中尚未写入输出的样本
    pending: Vec<f32>,
    pending_off: usize,
    last_tick: Instant,
}

impl Engine {
    fn new(
        rx: Receiver<Cmd>,
        ev: Sender<PlayerEvent>,
        shared: Arc<Shared>,
        status: Arc<Status>,
    ) -> Self {
        Self {
            rx,
            ev,
            shared,
            status,
            output: None,
            track: None,
            state: PlaybackState::Stopped,
            pending: Vec::new(),
            pending_off: 0,
            last_tick: Instant::now(),
        }
    }

    fn emit(&self, e: PlayerEvent) {
        let _ = self.ev.send(e);
    }

    fn set_state(&mut self, s: PlaybackState) {
        if self.state != s {
            self.state = s;
            *self.status.state.lock().unwrap() = Some(s);
            self.shared
                .paused
                .store(s != PlaybackState::Playing, Ordering::Relaxed);
            self.emit(PlayerEvent::State(s));
        }
    }

    fn run(mut self) {
        loop {
            // 播放中只非阻塞地取命令；其余状态阻塞等待
            let cmd = if self.state == PlaybackState::Playing {
                match self.rx.try_recv() {
                    Ok(c) => Some(c),
                    Err(TryRecvError::Empty) => None,
                    Err(TryRecvError::Disconnected) => return,
                }
            } else {
                match self.rx.recv_timeout(Duration::from_millis(250)) {
                    Ok(c) => Some(c),
                    Err(RecvTimeoutError::Timeout) => None,
                    Err(RecvTimeoutError::Disconnected) => return,
                }
            };
            if let Some(cmd) = cmd {
                self.handle(cmd);
                continue;
            }
            if self.state == PlaybackState::Playing {
                self.pump();
            }
        }
    }

    fn handle(&mut self, cmd: Cmd) {
        match cmd {
            Cmd::Load {
                source,
                autoplay,
                start_ms,
            } => {
                self.track = None;
                self.flush_output();
                self.set_state(PlaybackState::Loading);
                self.status.base_ms.store(0, Ordering::Relaxed);
                match open_track(source) {
                    Ok(t) => {
                        self.status
                            .duration_ms
                            .store(t.duration_ms, Ordering::Relaxed);
                        let (rate, ch, dur) = (t.sample_rate, t.channels, t.duration_ms);
                        self.track = Some(t);
                        if let Err(e) = self.ensure_output(rate, ch) {
                            self.fail(e.to_string());
                            return;
                        }
                        self.emit(PlayerEvent::Loaded {
                            duration_ms: dur,
                            sample_rate: rate,
                            channels: ch,
                        });
                        if start_ms > 0 {
                            self.seek(start_ms);
                        }
                        self.set_state(if autoplay {
                            PlaybackState::Playing
                        } else {
                            PlaybackState::Paused
                        });
                        self.tick(true);
                    }
                    Err(e) => self.fail(e.to_string()),
                }
            }
            Cmd::Play => {
                if self.track.is_some() {
                    self.set_state(PlaybackState::Playing);
                }
            }
            Cmd::Pause => {
                if self.track.is_some() {
                    self.set_state(PlaybackState::Paused);
                    self.tick(true);
                }
            }
            Cmd::Stop => {
                self.track = None;
                self.flush_output();
                self.status.base_ms.store(0, Ordering::Relaxed);
                self.status.duration_ms.store(0, Ordering::Relaxed);
                self.set_state(PlaybackState::Stopped);
            }
            Cmd::Seek(ms) => {
                self.seek(ms);
                self.tick(true);
            }
        }
    }

    fn fail(&mut self, msg: String) {
        tracing::warn!("player error: {msg}");
        self.track = None;
        self.set_state(PlaybackState::Stopped);
        self.emit(PlayerEvent::Error(msg));
    }

    fn ensure_output(&mut self, rate: u32, channels: u16) -> Result<(), Error> {
        let reuse = self
            .output
            .as_ref()
            .is_some_and(|o| o.sample_rate == rate && o.channels == channels);
        if !reuse {
            self.output = None;
            self.output = Some(Output::open(rate, channels, self.shared.clone())?);
        }
        self.status.rate.store(rate, Ordering::Relaxed);
        self.shared.played_frames.store(0, Ordering::Relaxed);
        Ok(())
    }

    /// 清空输出缓冲与待写样本，并等回调确认，避免旧样本漏出来
    fn flush_output(&mut self) {
        self.pending.clear();
        self.pending_off = 0;
        let req = self.shared.flush_req.fetch_add(1, Ordering::AcqRel) + 1;
        if self.output.is_some() && !self.shared.paused.load(Ordering::Relaxed) {
            let t0 = Instant::now();
            while self.shared.flush_ack.load(Ordering::Acquire) < req
                && t0.elapsed() < Duration::from_millis(200)
            {
                std::thread::sleep(Duration::from_millis(1));
            }
        }
        self.shared.played_frames.store(0, Ordering::Relaxed);
    }

    fn seek(&mut self, ms: u64) {
        let Some(t) = self.track.as_mut() else { return };
        let ms = ms.min(t.duration_ms.saturating_sub(500));
        let res = t.reader.seek(
            SeekMode::Accurate,
            SeekTo::Time {
                time: Time::from_millis_u64(ms),
                track_id: Some(t.track_id),
            },
        );
        match res {
            Ok(seeked) => {
                t.decoder.reset();
                t.skip_until = seeked.required_ts;
                t.eof = false;
                self.flush_output();
                self.status.base_ms.store(ms, Ordering::Relaxed);
            }
            Err(e) => tracing::warn!("seek failed: {e}"),
        }
    }

    fn tick(&mut self, force: bool) {
        if force || self.last_tick.elapsed() >= Duration::from_millis(200) {
            self.last_tick = Instant::now();
            let buffered = self
                .track
                .as_ref()
                .and_then(|t| t._download.as_ref())
                .map(|d| {
                    let (got, total) = d.progress();
                    if total == 0 {
                        0.0
                    } else {
                        got as f32 / total as f32
                    }
                })
                .unwrap_or(1.0);
            self.emit(PlayerEvent::Position {
                position_ms: position_ms(&self.shared, &self.status),
                duration_ms: self.status.duration_ms.load(Ordering::Relaxed),
                buffered,
            });
        }
    }

    /// 解码并喂给输出；输出满了就小睡，期间仍能及时响应命令
    fn pump(&mut self) {
        self.tick(false);
        if self.pending_off < self.pending.len() {
            let out = self.output.as_mut().expect("output exists while playing");
            let n = out.write(&self.pending[self.pending_off..]);
            self.pending_off += n;
            if n == 0 {
                std::thread::sleep(Duration::from_millis(5));
            }
            return;
        }
        let Some(t) = self.track.as_mut() else {
            self.set_state(PlaybackState::Stopped);
            return;
        };
        if t.eof {
            // 等缓冲播完再报告结束
            if self.output.as_ref().is_none_or(|o| o.queued() == 0) {
                self.tick(true);
                self.track = None;
                self.set_state(PlaybackState::Stopped);
                self.emit(PlayerEvent::Ended);
            } else {
                std::thread::sleep(Duration::from_millis(10));
            }
            return;
        }
        match next_samples(t, &mut self.pending) {
            Ok(true) => self.pending_off = 0,
            Ok(false) => t.eof = true,
            Err(e) => self.fail(e),
        }
    }
}

/// 解出下一段样本放进 `buf`（交错 f32）。返回 false 表示到达结尾。
fn next_samples(t: &mut Track, buf: &mut Vec<f32>) -> Result<bool, String> {
    loop {
        let packet = match t.reader.next_packet() {
            Ok(Some(p)) => p,
            Ok(None) => return Ok(false),
            Err(SymError::IoError(e)) if e.kind() == std::io::ErrorKind::UnexpectedEof => {
                return Ok(false);
            }
            Err(SymError::ResetRequired) => return Ok(false),
            Err(e) => return Err(e.to_string()),
        };
        if packet.track_id != t.track_id {
            continue;
        }
        match t.decoder.decode(&packet) {
            Ok(decoded) => {
                let frames = decoded.frames();
                if frames == 0 {
                    continue;
                }
                buf.clear();
                decoded.copy_to_vec_interleaved(buf);
                // 精确跳转：丢掉目标位置之前的部分
                if packet.pts < t.skip_until {
                    let behind = (t.skip_until.get() - packet.pts.get()) as usize;
                    if behind >= frames {
                        continue;
                    }
                    buf.drain(..behind * t.channels as usize);
                }
                return Ok(true);
            }
            Err(SymError::DecodeError(e)) => {
                tracing::debug!("decode error (skipped): {e}");
                continue;
            }
            Err(e) => return Err(e.to_string()),
        }
    }
}

fn open_track(source: Source) -> Result<Track, Error> {
    let (ms, download, ext): (Box<dyn MediaSource>, Option<DownloadHandle>, Option<String>) =
        match source {
            Source::File(p) => {
                let ext = p.extension().map(|e| e.to_string_lossy().into_owned());
                (Box::new(std::fs::File::open(p)?), None, ext)
            }
            Source::Url { url, cache_path } => {
                let ext = cache_path
                    .extension()
                    .map(|e| e.to_string_lossy().into_owned());
                if cache_path.is_file() {
                    (Box::new(std::fs::File::open(&cache_path)?), None, ext)
                } else {
                    let (s, h) = StreamingSource::open(&url, &cache_path)?;
                    (Box::new(s), Some(h), ext)
                }
            }
        };
    let mut hint = Hint::new();
    if let Some(ext) = &ext {
        hint.with_extension(ext);
    }
    let mss = MediaSourceStream::new(ms, Default::default());
    let reader = symphonia::default::get_probe()
        .probe(
            &hint,
            mss,
            FormatOptions::default(),
            MetadataOptions::default(),
        )
        .map_err(|e| Error::Decode(format!("probe: {e}")))?;
    let track = reader
        .default_track(TrackType::Audio)
        .ok_or_else(|| Error::Decode("no audio track".into()))?;
    let Some(CodecParameters::Audio(params)) = track.codec_params.as_ref() else {
        return Err(Error::Decode("not an audio track".into()));
    };
    let decoder = symphonia::default::get_codecs()
        .make_audio_decoder(params, &AudioDecoderOptions::default())
        .map_err(|e| Error::Decode(format!("decoder: {e}")))?;
    let sample_rate = params
        .sample_rate
        .ok_or_else(|| Error::Decode("unknown sample rate".into()))?;
    let channels = params
        .channels
        .as_ref()
        .map(|c| c.count() as u16)
        .ok_or_else(|| Error::Decode("unknown channel layout".into()))?;
    let time_base = track.time_base;
    let duration_ms = match (track.duration, time_base) {
        (Some(d), Some(tb)) => tb
            .calc_time(Timestamp::from(d.get() as i64))
            .map(|t| t.as_millis() as u64)
            .unwrap_or(0),
        _ => track
            .num_frames
            .map(|n| n * 1000 / sample_rate as u64)
            .unwrap_or(0),
    };
    Ok(Track {
        track_id: track.id,
        time_base,
        reader,
        decoder,
        sample_rate,
        channels,
        duration_ms,
        skip_until: Timestamp::ZERO,
        eof: false,
        _download: download,
    })
}

/// 安卓上 rustls-platform-verifier 需要先经 JNI 初始化，否则所有 HTTPS 请求都会 panic。
/// 这里改用内置的 webpki 根证书，并设好 HTTP/2 的 ALPN。
#[cfg(target_os = "android")]
pub(crate) fn android_tls() -> rustls::ClientConfig {
    let mut roots = rustls::RootCertStore::empty();
    roots.extend(webpki_roots::TLS_SERVER_ROOTS.iter().cloned());
    let mut cfg = rustls::ClientConfig::builder_with_provider(std::sync::Arc::new(
        rustls::crypto::ring::default_provider(),
    ))
    .with_safe_default_protocol_versions()
    .expect("rustls protocol versions")
    .with_root_certificates(roots)
    .with_no_client_auth();
    cfg.alpn_protocols = vec![b"h2".to_vec(), b"http/1.1".to_vec()];
    cfg
}

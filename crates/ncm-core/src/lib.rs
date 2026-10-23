//! 业务核心：把协议层、播放器、队列和本地存储粘在一起。各端（Flutter / CLI）共用这一层。

pub mod lyrics;
pub mod queue;

use std::path::PathBuf;
use std::sync::{Arc, Mutex, Weak};

use ncm_api::{Client, Quality, Session, Song};
use ncm_player::{PlaybackState, Player, PlayerEvent, Source};
use serde::{Deserialize, Serialize};
use tokio::sync::broadcast;

pub use lyrics::LyricLine;
pub use ncm_api;
pub use ncm_player;
pub use queue::{PlayMode, Queue};

#[derive(Debug, thiserror::Error)]
pub enum Error {
    #[error(transparent)]
    Api(#[from] ncm_api::Error),
    #[error("io: {0}")]
    Io(#[from] std::io::Error),
    #[error("{0}")]
    Other(String),
}

pub type Result<T> = std::result::Result<T, Error>;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(default)]
pub struct Settings {
    pub quality: Quality,
    pub volume: f32,
    pub play_mode: PlayMode,
    /// 出口在海外时伪装国内 IP，绕开地区版权限制
    pub use_cn_ip: bool,
    pub cn_ip: String,
}

impl Default for Settings {
    fn default() -> Self {
        Self {
            quality: Quality::ExHigh,
            volume: 0.8,
            play_mode: PlayMode::Sequential,
            use_cn_ip: true,
            cn_ip: random_cn_ip(),
        }
    }
}

/// 已实测网易云认作国内的 /16 网段（电信、联通、移动各几段）。
const CN_PREFIXES: &[&str] = &[
    "116.25", "113.88", "14.153", "183.14", "61.140", "59.36", "120.229", "121.35", "218.17",
    "125.88", "111.206", "123.125",
];

pub fn random_cn_ip() -> String {
    let p = CN_PREFIXES[rand::random_range(0..CN_PREFIXES.len())];
    format!(
        "{p}.{}.{}",
        rand::random_range(1..=254),
        rand::random_range(1..=254)
    )
}

#[derive(Debug, Clone)]
pub struct Paths {
    pub data_dir: PathBuf,
    pub cache_dir: PathBuf,
}

impl Paths {
    pub fn platform_default() -> Result<Self> {
        let d = directories::ProjectDirs::from("io.github", "Gloridust", "YetEaseMusic")
            .ok_or_else(|| Error::Other("cannot resolve home directory".into()))?;
        Ok(Self {
            data_dir: d.data_dir().to_owned(),
            cache_dir: d.cache_dir().to_owned(),
        })
    }

    fn session_file(&self) -> PathBuf {
        self.data_dir.join("session.json")
    }

    fn settings_file(&self) -> PathBuf {
        self.data_dir.join("settings.json")
    }
}

#[derive(Debug, Clone)]
pub enum CoreEvent {
    Player(PlayerEvent),
    TrackChanged(Option<Song>),
    QueueChanged,
    SettingsChanged,
    /// 面向用户的提示，比如"该歌曲暂无版权"
    Notice(String),
}

pub struct Core {
    api: Client,
    player: Player,
    paths: Paths,
    settings: Mutex<Settings>,
    queue: Mutex<Queue>,
    events: broadcast::Sender<CoreEvent>,
    /// 连续播放失败计数，防止整张歌单都放不了时死循环
    failures: Mutex<usize>,
}

impl Core {
    /// 必须在 tokio 运行时里调用。
    pub fn new(paths: Paths) -> Result<Arc<Self>> {
        std::fs::create_dir_all(&paths.data_dir)?;
        std::fs::create_dir_all(&paths.cache_dir)?;
        let session: Session = read_json(&paths.session_file()).unwrap_or_default();
        let settings: Settings = read_json(&paths.settings_file()).unwrap_or_default();
        let api = Client::new(session)?;
        api.set_real_ip(settings.use_cn_ip.then(|| settings.cn_ip.clone()));
        let (player, player_rx) = Player::new();
        player.set_volume(settings.volume);
        let (events, _) = broadcast::channel(256);
        let mut queue = Queue::default();
        queue.set_mode(settings.play_mode);
        let core = Arc::new(Self {
            api,
            player,
            paths,
            settings: Mutex::new(settings),
            queue: Mutex::new(queue),
            events,
            failures: Mutex::new(0),
        });
        core.save_settings();
        core.save_session();

        // 播放器事件桥：转发给订阅者，并在曲目结束时自动切歌
        let (tx, mut rx) = tokio::sync::mpsc::unbounded_channel();
        std::thread::Builder::new()
            .name("ncm-core-events".into())
            .spawn(move || {
                while let Ok(e) = player_rx.recv() {
                    if tx.send(e).is_err() {
                        break;
                    }
                }
            })?;
        let weak: Weak<Self> = Arc::downgrade(&core);
        tokio::spawn(async move {
            while let Some(e) = rx.recv().await {
                let Some(core) = weak.upgrade() else { break };
                if matches!(e, PlayerEvent::Ended) {
                    let next = core.queue.lock().unwrap().after_end();
                    if let Some(i) = next {
                        let c = core.clone();
                        tokio::spawn(async move { c.play_index(i).await });
                    }
                }
                if matches!(e, PlayerEvent::State(PlaybackState::Playing)) {
                    *core.failures.lock().unwrap() = 0;
                }
                let _ = core.events.send(CoreEvent::Player(e));
            }
        });
        Ok(core)
    }

    pub fn subscribe(&self) -> broadcast::Receiver<CoreEvent> {
        self.events.subscribe()
    }

    pub fn api(&self) -> &Client {
        &self.api
    }

    pub fn player(&self) -> &Player {
        &self.player
    }

    pub fn paths(&self) -> &Paths {
        &self.paths
    }

    fn emit(&self, e: CoreEvent) {
        let _ = self.events.send(e);
    }

    // ---------- 持久化 ----------

    pub fn save_session(&self) {
        let path = self.paths.session_file();
        if let Err(e) = write_json(&path, &self.api.session()) {
            tracing::warn!("save session: {e}");
        }
        restrict_permissions(&path);
    }

    pub fn settings(&self) -> Settings {
        self.settings.lock().unwrap().clone()
    }

    pub fn update_settings(&self, f: impl FnOnce(&mut Settings)) {
        let s = {
            let mut s = self.settings.lock().unwrap();
            f(&mut s);
            s.clone()
        };
        self.api.set_real_ip(s.use_cn_ip.then(|| s.cn_ip.clone()));
        self.player.set_volume(s.volume);
        self.queue.lock().unwrap().set_mode(s.play_mode);
        self.save_settings();
        self.emit(CoreEvent::SettingsChanged);
    }

    fn save_settings(&self) {
        let s = self.settings.lock().unwrap().clone();
        if let Err(e) = write_json(&self.paths.settings_file(), &s) {
            tracing::warn!("save settings: {e}");
        }
    }

    // ---------- 登录 ----------

    /// 轮询一次扫码状态；授权成功时自动保存会话。
    pub async fn qr_check(&self, key: &str) -> Result<ncm_api::QrStatus> {
        let st = self.api.qr_check(key).await?;
        if st == ncm_api::QrStatus::Authorized {
            self.save_session();
        }
        Ok(st)
    }

    pub async fn logout(&self) -> Result<()> {
        let r = self.api.logout().await;
        self.save_session();
        r.map_err(Into::into)
    }

    // ---------- 播放 ----------

    pub fn queue(&self) -> Queue {
        self.queue.lock().unwrap().clone()
    }

    pub fn current_song(&self) -> Option<Song> {
        self.queue.lock().unwrap().current_song().cloned()
    }

    /// 用一组歌替换队列并从 `index` 开始播放
    pub async fn play_list(&self, songs: Vec<Song>, index: usize) {
        self.queue.lock().unwrap().replace(songs, index);
        self.emit(CoreEvent::QueueChanged);
        self.play_index(index).await;
    }

    pub fn enqueue_next(&self, song: Song) {
        self.queue.lock().unwrap().play_next(song);
        self.emit(CoreEvent::QueueChanged);
    }

    pub async fn next(&self) {
        let i = self.queue.lock().unwrap().next();
        if let Some(i) = i {
            self.play_index(i).await;
        }
    }

    pub async fn prev(&self) {
        // 播放超过 3 秒时"上一首"回到开头，和主流播放器一致
        if self.player.position_ms() > 3000 {
            self.player.seek(0);
            return;
        }
        let i = self.queue.lock().unwrap().prev();
        if let Some(i) = i {
            self.play_index(i).await;
        }
    }

    pub async fn play_index(&self, index: usize) {
        let song = {
            let mut q = self.queue.lock().unwrap();
            if index >= q.songs.len() {
                return;
            }
            q.current = Some(index);
            q.songs[index].clone()
        };
        self.emit(CoreEvent::TrackChanged(Some(song.clone())));
        if let Err(msg) = self.start(&song).await {
            self.emit(CoreEvent::Notice(format!(
                "《{}》无法播放：{msg}",
                song.name
            )));
            let (skip, len) = {
                let mut f = self.failures.lock().unwrap();
                *f += 1;
                (*f, self.queue.lock().unwrap().songs.len())
            };
            if skip < len.min(5) {
                Box::pin(self.next()).await;
            } else {
                self.player.stop();
            }
        }
    }

    async fn start(&self, song: &Song) -> std::result::Result<(), String> {
        let quality = self.settings.lock().unwrap().quality;
        let url = self
            .api
            .song_url(song.id, quality)
            .await
            .map_err(|e| e.to_string())?;
        let Some(link) = url.url.filter(|u| !u.is_empty()) else {
            return Err(if song.fee == 1 {
                "需要会员".into()
            } else {
                "暂无版权".into()
            });
        };
        if url.free_trial.as_ref().is_some_and(|v| !v.is_null()) {
            self.emit(CoreEvent::Notice(format!("《{}》为试听片段", song.name)));
        }
        let ext = url.format.as_deref().unwrap_or("mp3").to_ascii_lowercase();
        let level = url.level.as_deref().unwrap_or(quality.level());
        let cache_path = self
            .paths
            .cache_dir
            .join("audio")
            .join(format!("{}-{level}.{ext}", song.id));
        self.player.load(
            Source::Url {
                url: link,
                cache_path,
            },
            true,
        );
        Ok(())
    }

    pub async fn lyrics(&self, song_id: u64) -> Result<Vec<LyricLine>> {
        let l = self.api.lyrics(song_id).await?;
        Ok(lyrics::merge(&l.lrc, &l.translation))
    }
}

fn read_json<T: serde::de::DeserializeOwned>(path: &PathBuf) -> Option<T> {
    serde_json::from_slice(&std::fs::read(path).ok()?).ok()
}

fn write_json<T: Serialize>(path: &PathBuf, v: &T) -> std::io::Result<()> {
    let tmp = path.with_extension("tmp");
    std::fs::write(&tmp, serde_json::to_vec_pretty(v)?)?;
    std::fs::rename(tmp, path)
}

/// 会话文件里有登录凭据，只给当前用户读写
fn restrict_permissions(path: &PathBuf) {
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let _ = std::fs::set_permissions(path, std::fs::Permissions::from_mode(0o600));
    }
    #[cfg(not(unix))]
    let _ = path;
}

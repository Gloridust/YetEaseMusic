//! 业务核心：把协议层、播放器、队列和本地存储粘在一起。各端（Flutter / CLI）共用这一层。

pub mod images;
pub mod library;
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
    /// 界面整体缩放（1.0 为默认尺寸）
    pub ui_scale: f32,
    /// "system" / "light" / "dark"
    pub theme: String,
    /// 本地音乐扫描的目录
    pub local_dirs: Vec<String>,
    /// 下载目录
    pub download_dir: String,
    /// 音乐缓存上限（MB），超出后自动淘汰最旧的
    pub cache_limit_mb: u32,
}

impl Default for Settings {
    fn default() -> Self {
        Self {
            quality: Quality::ExHigh,
            volume: 0.8,
            play_mode: PlayMode::Sequential,
            use_cn_ip: true,
            cn_ip: random_cn_ip(),
            ui_scale: 1.0,
            theme: "system".into(),
            local_dirs: vec![music_dir().to_string_lossy().into_owned()],
            download_dir: music_dir().join("YetEase").to_string_lossy().into_owned(),
            cache_limit_mb: 2048,
        }
    }
}

/// 系统的「音乐」目录，取不到时用 ~/Music
fn music_dir() -> PathBuf {
    directories::UserDirs::new()
        .and_then(|u| {
            u.audio_dir()
                .map(PathBuf::from)
                .or_else(|| Some(u.home_dir().join("Music")))
        })
        .unwrap_or_else(|| PathBuf::from("Music"))
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

    fn downloads_file(&self) -> PathBuf {
        self.data_dir.join("downloads.json")
    }
}

#[derive(Debug, Clone)]
pub enum CoreEvent {
    Player(PlayerEvent),
    TrackChanged(Option<Song>),
    QueueChanged,
    SettingsChanged,
    /// 下载列表或某个下载任务的进度变了
    DownloadsChanged,
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
    /// 本地音乐：id → 文件
    local: Mutex<library::LocalIndex>,
    downloads: Mutex<library::Downloads>,
    /// 进行中的下载：id → (歌曲, 进度 0~1)
    downloading: Mutex<std::collections::HashMap<u64, (Song, f32)>>,
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
            local: Mutex::new(Default::default()),
            downloads: Mutex::new(Default::default()),
            downloading: Mutex::new(Default::default()),
        });
        core.prune_caches();
        {
            let mut d: library::Downloads =
                read_json(&core.paths.downloads_file()).unwrap_or_default();
            d.prune();
            *core.downloads.lock().unwrap() = d;
        }
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
        if let Some(path) = self.local_path(song.id) {
            self.player.load(Source::File(path), true);
            return Ok(());
        }
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
        // 每次开始新歌顺带检查一次缓存容量（扫描目录很便宜）
        self.prune_caches();
        Ok(())
    }

    /// 本地文件或已下载文件的路径
    fn local_path(&self, id: u64) -> Option<PathBuf> {
        if library::is_local(id) {
            return self.local.lock().unwrap().get(&id).cloned();
        }
        self.downloads
            .lock()
            .unwrap()
            .find(id)
            .map(|e| e.path.clone())
    }

    // ---------- 本地音乐 ----------

    /// 扫描设置里的本地音乐目录（耗时操作，在阻塞线程池里执行）
    pub async fn scan_local(&self) -> Vec<Song> {
        let dirs: Vec<PathBuf> = self
            .settings()
            .local_dirs
            .iter()
            .map(PathBuf::from)
            .collect();
        let cover_dir = self.paths.cache_dir.join("covers");
        let found = tokio::task::spawn_blocking(move || library::scan(&dirs, &cover_dir))
            .await
            .unwrap_or_default();
        let mut idx = self.local.lock().unwrap();
        idx.clear();
        found
            .into_iter()
            .map(|(song, path)| {
                idx.insert(song.id, path);
                song
            })
            .collect()
    }

    // ---------- 下载 ----------

    pub fn downloads(&self) -> Vec<library::DownloadEntry> {
        self.downloads.lock().unwrap().entries.clone()
    }

    /// 进行中的下载 (歌曲, 进度)
    pub fn downloading(&self) -> Vec<(Song, f32)> {
        self.downloading.lock().unwrap().values().cloned().collect()
    }

    pub fn is_downloaded(&self, id: u64) -> bool {
        self.downloads.lock().unwrap().find(id).is_some()
    }

    /// 下载一首歌到下载目录，写入标签与封面。已在下载中则直接返回。
    pub async fn download(&self, song: Song) -> Result<PathBuf> {
        if library::is_local(song.id) {
            return Err(Error::Other("本地歌曲无需下载".into()));
        }
        {
            let mut d = self.downloading.lock().unwrap();
            if d.contains_key(&song.id) {
                return Err(Error::Other("已在下载中".into()));
            }
            d.insert(song.id, (song.clone(), 0.0));
        }
        self.emit(CoreEvent::DownloadsChanged);
        let r = self.download_inner(&song).await;
        self.downloading.lock().unwrap().remove(&song.id);
        self.emit(CoreEvent::DownloadsChanged);
        match &r {
            Ok(_) => self.emit(CoreEvent::Notice(format!("《{}》下载完成", song.name))),
            Err(e) => self.emit(CoreEvent::Notice(format!("《{}》下载失败：{e}", song.name))),
        }
        r
    }

    async fn download_inner(&self, song: &Song) -> Result<PathBuf> {
        use futures_util::StreamExt;
        use tokio::io::AsyncWriteExt;

        let quality = self.settings.lock().unwrap().quality;
        let url = self.api.song_url(song.id, quality).await?;
        if url.free_trial.as_ref().is_some_and(|v| !v.is_null()) {
            return Err(Error::Other("只能试听，无法下载完整歌曲".into()));
        }
        let link = url.url.filter(|u| !u.is_empty()).ok_or_else(|| {
            Error::Other(if song.fee == 1 {
                "需要会员".into()
            } else {
                "暂无版权".into()
            })
        })?;
        let ext = url.format.as_deref().unwrap_or("mp3").to_ascii_lowercase();
        let dir = PathBuf::from(self.settings().download_dir);
        tokio::fs::create_dir_all(&dir).await?;
        let base = library::safe_file_name(&format!("{} - {}", song.artist_names(), song.name));
        let path = dir.join(format!("{base}.{ext}"));
        let part = dir.join(format!("{base}.{ext}.part"));

        let http = http_client();
        let resp = http
            .get(&link)
            .send()
            .await
            .map_err(|e| Error::Other(e.to_string()))?;
        let total = resp.content_length().unwrap_or(url.size).max(1);
        let mut file = tokio::fs::File::create(&part).await?;
        let mut stream = resp.bytes_stream();
        let mut got = 0u64;
        let mut last = 0.0f32;
        while let Some(chunk) = stream.next().await {
            let chunk = chunk.map_err(|e| Error::Other(e.to_string()))?;
            file.write_all(&chunk).await?;
            got += chunk.len() as u64;
            let p = (got as f32 / total as f32).min(1.0);
            if p - last >= 0.02 {
                last = p;
                if let Some(e) = self.downloading.lock().unwrap().get_mut(&song.id) {
                    e.1 = p;
                }
                self.emit(CoreEvent::DownloadsChanged);
            }
        }
        file.flush().await?;
        drop(file);
        tokio::fs::rename(&part, &path).await?;

        // 封面与标签写失败不影响下载本身
        let cover = match song.album.pic_url.as_deref() {
            Some(u) => match http
                .get(format!(
                    "{}?param=800y800",
                    u.replace("http://", "https://")
                ))
                .send()
                .await
            {
                Ok(r) => r.bytes().await.ok().map(|b| b.to_vec()),
                Err(_) => None,
            },
            None => None,
        };
        let (p2, s2) = (path.clone(), song.clone());
        let _ =
            tokio::task::spawn_blocking(move || library::write_tags(&p2, &s2, cover.as_deref()))
                .await;

        let entry = library::DownloadEntry {
            song: song.clone(),
            size: tokio::fs::metadata(&path)
                .await
                .map(|m| m.len())
                .unwrap_or(got),
            path: path.clone(),
            time: std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .map(|d| d.as_secs())
                .unwrap_or(0),
            level: url.level.unwrap_or_default(),
        };
        self.downloads.lock().unwrap().upsert(entry);
        self.save_downloads();
        Ok(path)
    }

    /// 删除下载（连同文件）
    pub fn delete_download(&self, id: u64) -> Result<()> {
        let path = {
            let mut d = self.downloads.lock().unwrap();
            let p = d.find(id).map(|e| e.path.clone());
            d.entries.retain(|e| e.song.id != id);
            p
        };
        if let Some(p) = path {
            std::fs::remove_file(p)?;
        }
        self.save_downloads();
        self.emit(CoreEvent::DownloadsChanged);
        Ok(())
    }

    fn save_downloads(&self) {
        let d = self.downloads.lock().unwrap();
        if let Err(e) = write_json(&self.paths.downloads_file(), &*d) {
            tracing::warn!("save downloads: {e}");
        }
    }

    // ---------- 缓存管理 ----------

    fn audio_cache_dir(&self) -> PathBuf {
        self.paths.cache_dir.join("audio")
    }

    fn image_cache_dir(&self) -> PathBuf {
        self.paths.cache_dir.join("images")
    }

    /// 后台检查音乐与图片缓存是否超限
    pub fn prune_caches(&self) {
        let audio = (
            self.audio_cache_dir(),
            self.settings().cache_limit_mb as u64 * (1 << 20),
        );
        let image = (self.image_cache_dir(), images::IMAGE_LIMIT);
        tokio::task::spawn_blocking(move || {
            for (dir, limit) in [audio, image] {
                let freed = images::prune(&dir, limit);
                if freed > 0 {
                    tracing::info!("cache pruned {} MB in {}", freed >> 20, dir.display());
                }
            }
        });
    }

    /// (音乐缓存字节, 图片缓存字节)
    pub async fn cache_usage(&self) -> (u64, u64) {
        let (a, i) = (self.audio_cache_dir(), self.image_cache_dir());
        tokio::task::spawn_blocking(move || (images::usage(&a), images::usage(&i)))
            .await
            .unwrap_or_default()
    }

    /// 清除缓存：`audio` 为 true 清音乐缓存，否则清图片缓存。返回释放的字节数
    pub async fn clear_cache(&self, audio: bool) -> u64 {
        let dir = if audio {
            self.audio_cache_dir()
        } else {
            self.image_cache_dir()
        };
        tokio::task::spawn_blocking(move || images::clear(&dir))
            .await
            .unwrap_or_default()
    }

    // ---------- 图片缓存 ----------

    /// 取图片字节：命中磁盘缓存直接读，否则下载后写入缓存
    pub async fn image(&self, url: &str) -> Result<Vec<u8>> {
        let path = images::path_for(&self.image_cache_dir(), url);
        if let Ok(b) = tokio::fs::read(&path).await {
            return Ok(b);
        }
        let resp = http_client()
            .get(url)
            .send()
            .await
            .and_then(|r| r.error_for_status())
            .map_err(|e| Error::Other(e.to_string()))?;
        let bytes = resp
            .bytes()
            .await
            .map_err(|e| Error::Other(e.to_string()))?
            .to_vec();
        if let Some(dir) = path.parent() {
            tokio::fs::create_dir_all(dir).await?;
            // 先写临时文件再改名，避免并发读到半截文件
            let tmp = path.with_extension("tmp");
            if tokio::fs::write(&tmp, &bytes).await.is_ok() {
                let _ = tokio::fs::rename(&tmp, &path).await;
            }
        }
        Ok(bytes)
    }

    pub async fn lyrics(&self, song_id: u64) -> Result<Vec<LyricLine>> {
        let l = self.api.lyrics(song_id).await?;
        Ok(lyrics::merge(&l.lrc, &l.translation))
    }
}

fn http_client() -> &'static reqwest::Client {
    static C: std::sync::OnceLock<reqwest::Client> = std::sync::OnceLock::new();
    C.get_or_init(|| {
        let _ = rustls::crypto::ring::default_provider().install_default();
        reqwest::Client::builder()
            .connect_timeout(std::time::Duration::from_secs(10))
            .user_agent("Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36")
            .build()
            .expect("http client")
    })
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

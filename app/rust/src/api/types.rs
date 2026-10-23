//! 传给 Dart 的数据结构。id 用 i64（Dart int），时长用毫秒。

use ncm_core::ncm_api::{self as api};
use ncm_core::ncm_player::PlaybackState;
use ncm_core::{LyricLine, PlayMode};

#[derive(Debug, Clone)]
pub struct SongItem {
    pub id: i64,
    pub name: String,
    /// 别名 / 译名
    pub subtitle: Option<String>,
    pub artists: Vec<ArtistItem>,
    pub album_id: i64,
    pub album_name: String,
    pub cover_url: Option<String>,
    pub duration_ms: i64,
    pub vip: bool,
    /// 本地文件（不能红心、评论、加入在线歌单）
    pub local: bool,
}

#[derive(Debug, Clone)]
pub struct ArtistItem {
    pub id: i64,
    pub name: String,
}

impl From<&api::Song> for SongItem {
    fn from(s: &api::Song) -> Self {
        Self {
            id: s.id as i64,
            name: s.name.clone(),
            subtitle: s.alias.first().cloned().filter(|a| !a.is_empty()),
            artists: s
                .artists
                .iter()
                .map(|a| ArtistItem {
                    id: a.id as i64,
                    name: a.name.clone(),
                })
                .collect(),
            album_id: s.album.id as i64,
            album_name: s.album.name.clone(),
            cover_url: s.album.pic_url.clone(),
            duration_ms: s.duration_ms as i64,
            vip: s.fee == 1,
            local: ncm_core::library::is_local(s.id),
        }
    }
}

#[derive(Debug, Clone)]
pub struct PlaylistItem {
    pub id: i64,
    pub name: String,
    pub cover_url: Option<String>,
    pub track_count: i64,
    pub play_count: i64,
    pub creator_name: Option<String>,
    pub creator_id: i64,
    pub subscribed: bool,
    /// 5 为"我喜欢的音乐"
    pub special_type: i32,
}

impl From<&api::PlaylistSummary> for PlaylistItem {
    fn from(p: &api::PlaylistSummary) -> Self {
        Self {
            id: p.id as i64,
            name: p.name.clone(),
            cover_url: p.cover_url.clone(),
            track_count: p.track_count as i64,
            play_count: p.play_count as i64,
            creator_name: p.creator.as_ref().map(|c| c.nickname.clone()),
            creator_id: p.creator.as_ref().map_or(0, |c| c.user_id as i64),
            subscribed: p.subscribed,
            special_type: p.special_type,
        }
    }
}

#[derive(Debug, Clone)]
pub struct PlaylistDetailInfo {
    pub summary: PlaylistItem,
    pub description: Option<String>,
    pub tracks: Vec<SongItem>,
}

#[derive(Debug, Clone)]
pub struct AccountInfo {
    pub user_id: i64,
    pub nickname: String,
    pub avatar_url: Option<String>,
    pub vip_type: i32,
}

#[derive(Debug, Clone)]
pub enum QrState {
    Expired,
    Waiting,
    Scanned {
        nickname: String,
        avatar_url: Option<String>,
    },
    Authorized,
    Failed {
        message: String,
    },
}

#[derive(Debug, Clone)]
pub struct LyricItem {
    pub time_ms: i64,
    pub text: String,
    pub translation: Option<String>,
}

impl From<LyricLine> for LyricItem {
    fn from(l: LyricLine) -> Self {
        Self {
            time_ms: l.time_ms as i64,
            text: l.text,
            translation: l.translation,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PlayerState {
    Stopped,
    Loading,
    Playing,
    Paused,
}

impl From<PlaybackState> for PlayerState {
    fn from(s: PlaybackState) -> Self {
        match s {
            PlaybackState::Stopped => Self::Stopped,
            PlaybackState::Loading => Self::Loading,
            PlaybackState::Playing => Self::Playing,
            PlaybackState::Paused => Self::Paused,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PlayOrder {
    Sequential,
    RepeatAll,
    RepeatOne,
    Shuffle,
}

impl From<PlayMode> for PlayOrder {
    fn from(m: PlayMode) -> Self {
        match m {
            PlayMode::Sequential => Self::Sequential,
            PlayMode::RepeatAll => Self::RepeatAll,
            PlayMode::RepeatOne => Self::RepeatOne,
            PlayMode::Shuffle => Self::Shuffle,
        }
    }
}

impl From<PlayOrder> for PlayMode {
    fn from(m: PlayOrder) -> Self {
        match m {
            PlayOrder::Sequential => Self::Sequential,
            PlayOrder::RepeatAll => Self::RepeatAll,
            PlayOrder::RepeatOne => Self::RepeatOne,
            PlayOrder::Shuffle => Self::Shuffle,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AudioQuality {
    Standard,
    Higher,
    ExHigh,
    Lossless,
    HiRes,
}

impl From<api::Quality> for AudioQuality {
    fn from(q: api::Quality) -> Self {
        match q {
            api::Quality::Standard => Self::Standard,
            api::Quality::Higher => Self::Higher,
            api::Quality::ExHigh => Self::ExHigh,
            api::Quality::Lossless => Self::Lossless,
            api::Quality::HiRes => Self::HiRes,
        }
    }
}

impl From<AudioQuality> for api::Quality {
    fn from(q: AudioQuality) -> Self {
        match q {
            AudioQuality::Standard => Self::Standard,
            AudioQuality::Higher => Self::Higher,
            AudioQuality::ExHigh => Self::ExHigh,
            AudioQuality::Lossless => Self::Lossless,
            AudioQuality::HiRes => Self::HiRes,
        }
    }
}

#[derive(Debug, Clone)]
pub struct AppSettings {
    pub quality: AudioQuality,
    pub volume: f32,
    pub mode: PlayOrder,
    pub use_cn_ip: bool,
    pub cn_ip: String,
    pub ui_scale: f32,
    pub theme: ThemePref,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ThemePref {
    System,
    Light,
    Dark,
}

impl ThemePref {
    pub(crate) fn parse(s: &str) -> Self {
        match s {
            "light" => Self::Light,
            "dark" => Self::Dark,
            _ => Self::System,
        }
    }

    pub(crate) fn as_str(self) -> &'static str {
        match self {
            Self::System => "system",
            Self::Light => "light",
            Self::Dark => "dark",
        }
    }
}

/// 播放器全量快照（UI 启动或重连时用）
#[derive(Debug, Clone)]
pub struct PlayerSnapshot {
    pub state: PlayerState,
    pub position_ms: i64,
    pub duration_ms: i64,
    pub volume: f32,
    pub mode: PlayOrder,
    pub current: Option<SongItem>,
    pub queue: Vec<SongItem>,
    pub queue_index: Option<i32>,
}

#[derive(Debug, Clone)]
pub enum UiEvent {
    State(PlayerState),
    Position {
        position_ms: i64,
        duration_ms: i64,
        buffered: f32,
    },
    TrackChanged(Option<SongItem>),
    QueueChanged,
    SettingsChanged,
    DownloadsChanged,
    Notice(String),
    Error(String),
}

#[derive(Debug, Clone)]
pub struct LikeCountInfo {
    pub count: i64,
    /// 形如 "100w+"
    pub text: String,
}

#[derive(Debug, Clone)]
pub struct CommentItem {
    pub id: i64,
    pub content: String,
    pub user_name: String,
    pub user_avatar: Option<String>,
    pub liked_count: i64,
    pub time_ms: i64,
    pub time_text: Option<String>,
}

impl From<&api::Comment> for CommentItem {
    fn from(c: &api::Comment) -> Self {
        Self {
            id: c.id as i64,
            content: c.content.clone(),
            user_name: c
                .user
                .as_ref()
                .map(|u| u.nickname.clone())
                .unwrap_or_default(),
            user_avatar: c.user.as_ref().and_then(|u| u.avatar_url.clone()),
            liked_count: c.liked_count as i64,
            time_ms: c.time as i64,
            time_text: c.time_str.clone(),
        }
    }
}

#[derive(Debug, Clone)]
pub struct CommentsInfo {
    pub total: i64,
    pub hot: Vec<CommentItem>,
    pub latest: Vec<CommentItem>,
    pub more: bool,
}

#[derive(Debug, Clone)]
pub struct RecentItem {
    pub song: SongItem,
    pub play_time_ms: i64,
}

#[derive(Debug, Clone)]
pub struct RadioItem {
    pub id: i64,
    pub name: String,
    pub cover_url: Option<String>,
    pub dj_name: String,
    pub program_count: i64,
    pub desc: Option<String>,
    pub sub_count: i64,
}

impl From<&api::Radio> for RadioItem {
    fn from(r: &api::Radio) -> Self {
        Self {
            id: r.id as i64,
            name: r.name.clone(),
            cover_url: r.pic_url.clone(),
            dj_name: r
                .dj
                .as_ref()
                .map(|d| d.nickname.clone())
                .unwrap_or_default(),
            program_count: r.program_count as i64,
            desc: r.desc.clone().filter(|d| !d.trim().is_empty()),
            sub_count: r.sub_count as i64,
        }
    }
}

#[derive(Debug, Clone)]
pub struct FollowItem {
    pub user_id: i64,
    pub nickname: String,
    pub avatar_url: Option<String>,
    pub signature: Option<String>,
    pub followers: i64,
}

impl From<&api::FollowedUser> for FollowItem {
    fn from(u: &api::FollowedUser) -> Self {
        Self {
            user_id: u.user_id as i64,
            nickname: u.nickname.clone(),
            avatar_url: u.avatar_url.clone(),
            signature: u.signature.clone().filter(|s| !s.trim().is_empty()),
            followers: u.followeds as i64,
        }
    }
}

#[derive(Debug, Clone)]
pub struct DownloadItem {
    pub song: SongItem,
    pub path: String,
    pub size: i64,
    pub time_sec: i64,
    pub level: String,
}

#[derive(Debug, Clone)]
pub struct DownloadingItem {
    pub song: SongItem,
    pub progress: f32,
}

#[derive(Debug, Clone)]
pub struct StorageSettings {
    pub local_dirs: Vec<String>,
    pub download_dir: String,
}

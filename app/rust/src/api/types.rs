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
    Notice(String),
    Error(String),
}

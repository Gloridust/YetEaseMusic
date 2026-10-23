//! 对外暴露的精简数据模型。字段名用 Rust 风格，反序列化时映射网易云原始字段。

use serde::{Deserialize, Deserializer, Serialize};

/// 显式 null 也按默认值处理（`#[serde(default)]` 只管字段缺失）。
fn nn<'de, D: Deserializer<'de>, T: Default + Deserialize<'de>>(d: D) -> Result<T, D::Error> {
    Ok(Option::<T>::deserialize(d)?.unwrap_or_default())
}

/// 网易云的数字字段时而是整数、时而是浮点或字符串，统一宽松解析。
fn num<'de, D: Deserializer<'de>>(d: D) -> Result<u64, D::Error> {
    let v = serde_json::Value::deserialize(d)?;
    Ok(match v {
        serde_json::Value::Number(n) => n.as_u64().or_else(|| n.as_f64().map(|f| f.max(0.0) as u64)).unwrap_or(0),
        serde_json::Value::String(s) => s.parse::<f64>().map(|f| f.max(0.0) as u64).unwrap_or(0),
        _ => 0,
    })
}

#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq)]
pub struct ArtistRef {
    #[serde(default, deserialize_with = "num")]
    pub id: u64,
    #[serde(default, deserialize_with = "nn")]
    pub name: String,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq)]
pub struct AlbumRef {
    #[serde(default, deserialize_with = "num")]
    pub id: u64,
    #[serde(default, deserialize_with = "nn")]
    pub name: String,
    #[serde(default, rename = "picUrl")]
    pub pic_url: Option<String>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq)]
pub struct Song {
    pub id: u64,
    #[serde(default, deserialize_with = "nn")]
    pub name: String,
    #[serde(default, deserialize_with = "nn", rename = "ar", alias = "artists")]
    pub artists: Vec<ArtistRef>,
    #[serde(default, deserialize_with = "nn", rename = "al", alias = "album")]
    pub album: AlbumRef,
    /// 毫秒
    #[serde(default, deserialize_with = "num", rename = "dt", alias = "duration")]
    pub duration_ms: u64,
    /// 0/8 免费，1 VIP，4 单曲购买
    #[serde(default, deserialize_with = "nn")]
    pub fee: i32,
    /// 副标题（翻译名 / 别名）
    #[serde(default, deserialize_with = "nn", rename = "alia", alias = "alias")]
    pub alias: Vec<String>,
}

impl Song {
    pub fn artist_names(&self) -> String {
        self.artists
            .iter()
            .map(|a| a.name.as_str())
            .collect::<Vec<_>>()
            .join(" / ")
    }
}

#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq)]
pub struct UserRef {
    #[serde(default, deserialize_with = "num", rename = "userId")]
    pub user_id: u64,
    #[serde(default, deserialize_with = "nn")]
    pub nickname: String,
    #[serde(default, rename = "avatarUrl")]
    pub avatar_url: Option<String>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq)]
pub struct PlaylistSummary {
    pub id: u64,
    #[serde(default, deserialize_with = "nn")]
    pub name: String,
    #[serde(default, rename = "coverImgUrl", alias = "picUrl")]
    pub cover_url: Option<String>,
    #[serde(default, deserialize_with = "num", rename = "trackCount")]
    pub track_count: u64,
    #[serde(default, deserialize_with = "num", rename = "playCount")]
    pub play_count: u64,
    #[serde(default)]
    pub creator: Option<UserRef>,
    /// true 表示是收藏的别人的歌单
    #[serde(default, deserialize_with = "nn")]
    pub subscribed: bool,
    #[serde(default, deserialize_with = "nn", rename = "specialType")]
    pub special_type: i32,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq)]
pub struct PlaylistDetail {
    pub summary: PlaylistSummary,
    pub description: Option<String>,
    pub tracks: Vec<Song>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum Quality {
    Standard,
    Higher,
    ExHigh,
    Lossless,
    HiRes,
}

impl Quality {
    pub fn level(self) -> &'static str {
        match self {
            Quality::Standard => "standard",
            Quality::Higher => "higher",
            Quality::ExHigh => "exhigh",
            Quality::Lossless => "lossless",
            Quality::HiRes => "hires",
        }
    }
}

#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq)]
pub struct SongUrl {
    pub id: u64,
    pub url: Option<String>,
    #[serde(default, deserialize_with = "num")]
    pub br: u64,
    #[serde(default, deserialize_with = "num")]
    pub size: u64,
    #[serde(default, rename = "type")]
    pub format: Option<String>,
    #[serde(default)]
    pub level: Option<String>,
    /// 非空表示只能试听片段
    #[serde(default, rename = "freeTrialInfo")]
    pub free_trial: Option<serde_json::Value>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq)]
pub struct Lyrics {
    /// 原文 LRC
    pub lrc: String,
    /// 翻译 LRC
    pub translation: String,
    /// 罗马音 LRC
    pub romaji: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum QrStatus {
    Expired,
    Waiting,
    /// 已扫码，待手机确认
    Scanned { nickname: String, avatar_url: Option<String> },
    Authorized,
    Other { code: i64, message: String },
}

#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq)]
pub struct Account {
    pub user_id: u64,
    pub nickname: String,
    pub avatar_url: Option<String>,
    pub vip_type: i32,
}

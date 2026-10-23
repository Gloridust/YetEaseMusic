//! 业务接口。每个方法注明对应 api-enhanced 的模块名，方便协议变更时对照。

use serde::de::DeserializeOwned;
use serde_json::{Value, json};

use crate::client::{Client, Crypto};
use crate::error::{Error, Result};
use crate::models::*;

fn field<T: DeserializeOwned>(v: &Value, path: &[&str]) -> Result<T> {
    let mut cur = v;
    for p in path {
        cur = cur
            .get(*p)
            .ok_or_else(|| Error::Decode(format!("missing field `{}`", path.join("."))))?;
    }
    Ok(serde_json::from_value(cur.clone())?)
}

fn opt_str(v: &Value, path: &[&str]) -> String {
    let mut cur = v;
    for p in path {
        match cur.get(*p) {
            Some(n) => cur = n,
            None => return String::new(),
        }
    }
    cur.as_str().unwrap_or_default().to_owned()
}

impl Client {
    /// 匿名注册，拿到游客 `MUSIC_A`（未登录时部分接口需要）。`register_anonimous`
    pub async fn register_anonymous(&self) -> Result<()> {
        let device_id = self.session().cookies.get("deviceId").cloned().unwrap_or_default();
        let username = crate::crypto::encode_device_id(&device_id);
        self.request("/api/register/anonimous", json!({ "username": username }), Crypto::Weapi)
            .await?;
        Ok(())
    }

    // ---------- 登录 ----------

    /// `login_qr_key`：返回 unikey。二维码内容为 [`qr_login_url`]。
    pub async fn qr_key(&self) -> Result<String> {
        let v = self
            .request("/api/login/qrcode/unikey", json!({ "type": 3 }), Crypto::Eapi)
            .await?;
        field(&v, &["unikey"])
    }

    /// `login_qr_check`：轮询扫码状态。返回 Authorized 时会话里已带上 MUSIC_U。
    pub async fn qr_check(&self, key: &str) -> Result<QrStatus> {
        let v = self
            .request(
                "/api/login/qrcode/client/login",
                json!({ "key": key, "type": 3 }),
                Crypto::Eapi,
            )
            .await?;
        let code = v.get("code").and_then(Value::as_i64).unwrap_or_default();
        Ok(match code {
            800 => QrStatus::Expired,
            801 => QrStatus::Waiting,
            802 => QrStatus::Scanned {
                nickname: opt_str(&v, &["nickname"]),
                avatar_url: Some(opt_str(&v, &["avatarUrl"])).filter(|s| !s.is_empty()),
            },
            803 => QrStatus::Authorized,
            _ => QrStatus::Other { code, message: opt_str(&v, &["message"]) },
        })
    }

    /// `login_status`：当前账号；未登录或游客返回 None。
    pub async fn account(&self) -> Result<Option<Account>> {
        let v = self
            .request("/api/w/nuser/account/get", json!({}), Crypto::Weapi)
            .await?;
        let Some(profile) = v.get("profile").filter(|p| !p.is_null()) else {
            return Ok(None);
        };
        Ok(Some(Account {
            user_id: profile.get("userId").and_then(Value::as_u64).unwrap_or_default(),
            nickname: opt_str(profile, &["nickname"]),
            avatar_url: Some(opt_str(profile, &["avatarUrl"])).filter(|s| !s.is_empty()),
            vip_type: profile.get("vipType").and_then(Value::as_i64).unwrap_or_default() as i32,
        }))
    }

    /// `logout`
    pub async fn logout(&self) -> Result<()> {
        let r = self.request("/api/logout", json!({}), Crypto::Eapi).await;
        self.clear_login();
        r.map(|_| ())
    }

    // ---------- 发现 ----------

    /// `cloudsearch`：单曲搜索。返回 (歌曲, 总数)。
    pub async fn search_songs(&self, keywords: &str, limit: u32, offset: u32) -> Result<(Vec<Song>, u64)> {
        let v = self
            .request(
                "/api/cloudsearch/pc",
                json!({ "s": keywords, "type": 1, "limit": limit, "offset": offset, "total": true }),
                Crypto::Eapi,
            )
            .await?;
        let songs = field(&v, &["result", "songs"]).unwrap_or_default();
        let total = v["result"]["songCount"].as_u64().unwrap_or_default();
        Ok((songs, total))
    }

    /// `personalized`：推荐歌单（游客也可用）。
    pub async fn recommend_playlists(&self, limit: u32) -> Result<Vec<PlaylistSummary>> {
        let v = self
            .request(
                "/api/personalized/playlist",
                json!({ "limit": limit, "total": true, "n": 1000 }),
                Crypto::Weapi,
            )
            .await?;
        field(&v, &["result"])
    }

    /// `recommend_songs`：每日推荐（需登录）。
    pub async fn daily_songs(&self) -> Result<Vec<Song>> {
        let v = self
            .request("/api/v3/discovery/recommend/songs", json!({}), Crypto::Weapi)
            .await?;
        field(&v, &["data", "dailySongs"])
    }

    // ---------- 歌单 ----------

    /// `user_playlist`：用户创建与收藏的歌单。
    pub async fn user_playlists(&self, uid: u64, limit: u32, offset: u32) -> Result<Vec<PlaylistSummary>> {
        let v = self
            .request(
                "/api/user/playlist",
                json!({ "uid": uid, "limit": limit, "offset": offset, "includeVideo": true }),
                Crypto::Weapi,
            )
            .await?;
        field(&v, &["playlist"])
    }

    /// `playlist_detail` + `song_detail`：歌单信息与完整曲目。
    pub async fn playlist_detail(&self, id: u64) -> Result<PlaylistDetail> {
        let v = self
            .request("/api/v6/playlist/detail", json!({ "id": id, "n": 100000, "s": 8 }), Crypto::Eapi)
            .await?;
        let pl = &v["playlist"];
        let summary: PlaylistSummary = serde_json::from_value(pl.clone())?;
        let ids: Vec<u64> = pl["trackIds"]
            .as_array()
            .map(|a| a.iter().filter_map(|t| t["id"].as_u64()).collect())
            .unwrap_or_default();
        let inline: Vec<Song> = serde_json::from_value(pl["tracks"].clone()).unwrap_or_default();
        // tracks 可能被截断，以 trackIds 为准补全
        let tracks = if inline.len() >= ids.len() {
            inline
        } else {
            self.song_detail(&ids).await?
        };
        Ok(PlaylistDetail {
            summary,
            description: pl["description"].as_str().map(str::to_owned),
            tracks,
        })
    }

    /// `song_detail`：批量获取歌曲信息，自动按 500 首分批。
    pub async fn song_detail(&self, ids: &[u64]) -> Result<Vec<Song>> {
        let mut out = Vec::with_capacity(ids.len());
        for chunk in ids.chunks(500) {
            let c = serde_json::to_string(
                &chunk.iter().map(|id| json!({ "id": id })).collect::<Vec<_>>(),
            )?;
            let v = self
                .request("/api/v3/song/detail", json!({ "c": c }), Crypto::Weapi)
                .await?;
            out.extend(field::<Vec<Song>>(&v, &["songs"])?);
        }
        Ok(out)
    }

    /// `likelist`：喜欢的歌曲 id。
    pub async fn liked_song_ids(&self, uid: u64) -> Result<Vec<u64>> {
        let v = self
            .request("/api/song/like/get", json!({ "uid": uid }), Crypto::Eapi)
            .await?;
        field(&v, &["ids"])
    }

    /// `like`：红心 / 取消红心。
    pub async fn like_song(&self, id: u64, like: bool) -> Result<()> {
        self.request(
            "/api/radio/like",
            json!({ "alg": "itembased", "trackId": id, "like": like, "time": "3" }),
            Crypto::Weapi,
        )
        .await?;
        Ok(())
    }

    // ---------- 播放 ----------

    /// `song_url_v1`：播放地址。
    pub async fn song_url(&self, id: u64, quality: Quality) -> Result<SongUrl> {
        let v = self
            .request(
                "/api/song/enhance/player/url/v1",
                json!({ "ids": format!("[{id}]"), "level": quality.level(), "encodeType": "flac" }),
                Crypto::Eapi,
            )
            .await?;
        let mut list: Vec<SongUrl> = field(&v, &["data"])?;
        list.pop().ok_or_else(|| Error::Decode("empty song url list".into()))
    }

    /// `lyric`：歌词、翻译、罗马音。
    pub async fn lyrics(&self, id: u64) -> Result<Lyrics> {
        let v = self
            .request(
                "/api/song/lyric",
                json!({ "id": id, "tv": -1, "lv": -1, "rv": -1, "kv": -1, "_nmclfl": 1 }),
                Crypto::Eapi,
            )
            .await?;
        Ok(Lyrics {
            lrc: opt_str(&v, &["lrc", "lyric"]),
            translation: opt_str(&v, &["tlyric", "lyric"]),
            romaji: opt_str(&v, &["romalrc", "lyric"]),
        })
    }
}

/// 扫码登录二维码的内容。
pub fn qr_login_url(key: &str) -> String {
    format!("https://music.163.com/login?codekey={key}")
}

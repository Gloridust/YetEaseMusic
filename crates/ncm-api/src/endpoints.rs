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
        let device_id = self
            .session()
            .cookies
            .get("deviceId")
            .cloned()
            .unwrap_or_default();
        let username = crate::crypto::encode_device_id(&device_id);
        self.request(
            "/api/register/anonimous",
            json!({ "username": username }),
            Crypto::Weapi,
        )
        .await?;
        Ok(())
    }

    // ---------- 登录 ----------

    /// `login_qr_key`：返回 unikey。二维码内容为 [`qr_login_url`]。
    pub async fn qr_key(&self) -> Result<String> {
        let v = self
            .request(
                "/api/login/qrcode/unikey",
                json!({ "type": 3 }),
                Crypto::Eapi,
            )
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
            _ => QrStatus::Other {
                code,
                message: opt_str(&v, &["message"]),
            },
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
            user_id: profile
                .get("userId")
                .and_then(Value::as_u64)
                .unwrap_or_default(),
            nickname: opt_str(profile, &["nickname"]),
            avatar_url: Some(opt_str(profile, &["avatarUrl"])).filter(|s| !s.is_empty()),
            vip_type: profile
                .get("vipType")
                .and_then(Value::as_i64)
                .unwrap_or_default() as i32,
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
    pub async fn search_songs(
        &self,
        keywords: &str,
        limit: u32,
        offset: u32,
    ) -> Result<(Vec<Song>, u64)> {
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
            .request(
                "/api/v3/discovery/recommend/songs",
                json!({}),
                Crypto::Weapi,
            )
            .await?;
        field(&v, &["data", "dailySongs"])
    }

    // ---------- 歌单 ----------

    /// `user_playlist`：用户创建与收藏的歌单。
    pub async fn user_playlists(
        &self,
        uid: u64,
        limit: u32,
        offset: u32,
    ) -> Result<Vec<PlaylistSummary>> {
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
            .request(
                "/api/v6/playlist/detail",
                json!({ "id": id, "n": 100000, "s": 8 }),
                Crypto::Eapi,
            )
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
                &chunk
                    .iter()
                    .map(|id| json!({ "id": id }))
                    .collect::<Vec<_>>(),
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
        list.pop()
            .ok_or_else(|| Error::Decode("empty song url list".into()))
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

impl Client {
    // ---------- 歌曲社交信息 ----------

    /// `song_red_count`：红心数
    pub async fn song_like_count(&self, id: u64) -> Result<LikeCount> {
        let v = self
            .request("/api/song/red/count", json!({ "songId": id }), Crypto::Eapi)
            .await?;
        field(&v, &["data"])
    }

    /// `comment_music`：歌曲评论。`before` 为上一页最后一条的时间戳（翻页用，首页传 0）。
    pub async fn song_comments(
        &self,
        id: u64,
        limit: u32,
        offset: u32,
        before: u64,
    ) -> Result<Comments> {
        let v = self
            .request(
                &format!("/api/v1/resource/comments/R_SO_4_{id}"),
                json!({ "rid": id, "limit": limit, "offset": offset, "beforeTime": before }),
                Crypto::Weapi,
            )
            .await?;
        Ok(Comments {
            total: v["total"].as_u64().unwrap_or_default(),
            hot: serde_json::from_value(v["hotComments"].clone()).unwrap_or_default(),
            latest: serde_json::from_value(v["comments"].clone()).unwrap_or_default(),
            more: v["more"].as_bool().unwrap_or_default(),
        })
    }

    // ---------- 我的音乐 ----------

    /// `record_recent_song`：最近播放（云端记录，与手机端同步）
    pub async fn recent_songs(&self, limit: u32) -> Result<Vec<PlayRecord>> {
        let v = self
            .request(
                "/api/play-record/song/list",
                json!({ "limit": limit }),
                Crypto::Weapi,
            )
            .await?;
        Ok(v["data"]["list"]
            .as_array()
            .map(|list| {
                list.iter()
                    .filter_map(|r| {
                        Some(PlayRecord {
                            song: serde_json::from_value(r["data"].clone()).ok()?,
                            play_time: r["playTime"].as_u64().unwrap_or_default(),
                        })
                    })
                    .collect()
            })
            .unwrap_or_default())
    }

    /// `user_follows`：关注的人
    pub async fn follows(
        &self,
        uid: u64,
        offset: u32,
        limit: u32,
    ) -> Result<(Vec<FollowedUser>, bool)> {
        let v = self
            .request(
                &format!("/api/user/getfollows/{uid}"),
                json!({ "offset": offset, "limit": limit, "order": true }),
                Crypto::Weapi,
            )
            .await?;
        Ok((
            field(&v, &["follow"]).unwrap_or_default(),
            v["more"].as_bool().unwrap_or_default(),
        ))
    }

    /// `playlist_create`：新建歌单，返回歌单信息
    pub async fn create_playlist(&self, name: &str, private: bool) -> Result<PlaylistSummary> {
        let v = self
            .request(
                "/api/playlist/create",
                json!({ "name": name, "privacy": if private { "10" } else { "0" }, "type": "NORMAL" }),
                Crypto::Weapi,
            )
            .await?;
        field(&v, &["playlist"])
    }

    /// `playlist_tracks`：向歌单添加或移除歌曲
    pub async fn playlist_tracks(
        &self,
        playlist_id: u64,
        song_ids: &[u64],
        add: bool,
    ) -> Result<()> {
        let ids = serde_json::to_string(song_ids)?;
        let data = json!({ "op": if add { "add" } else { "del" }, "pid": playlist_id, "trackIds": ids, "imme": "true" });
        match self
            .request("/api/playlist/manipulate/tracks", data, Crypto::Eapi)
            .await
        {
            // api-enhanced 的经验：512 时把 id 重复一遍再提交即可
            Err(Error::Api { code: 512, .. }) => {
                let doubled: Vec<u64> = song_ids.iter().chain(song_ids).copied().collect();
                let data = json!({ "op": if add { "add" } else { "del" }, "pid": playlist_id, "trackIds": serde_json::to_string(&doubled)?, "imme": "true" });
                self.request("/api/playlist/manipulate/tracks", data, Crypto::Eapi)
                    .await?;
                Ok(())
            }
            r => r.map(|_| ()),
        }
    }

    /// `playmode_intelligence_list`：心动模式。以 `seed` 为起点，从「我喜欢」歌单生成推荐序列。
    pub async fn intelligence_list(&self, seed: u64, liked_playlist_id: u64) -> Result<Vec<Song>> {
        let v = self
            .request(
                "/api/playmode/intelligence/list",
                json!({ "songId": seed, "type": "fromPlayOne", "playlistId": liked_playlist_id, "startMusicId": seed, "count": 1 }),
                Crypto::Eapi,
            )
            .await?;
        Ok(v["data"]
            .as_array()
            .map(|a| {
                a.iter()
                    .filter_map(|x| serde_json::from_value(x["songInfo"].clone()).ok())
                    .collect()
            })
            .unwrap_or_default())
    }

    // ---------- 播客 ----------

    /// `dj_sublist`：我订阅的播客
    pub async fn subscribed_radios(&self) -> Result<Vec<Radio>> {
        let v = self
            .request(
                "/api/djradio/get/subed",
                json!({ "limit": 100, "offset": 0, "total": true }),
                Crypto::Weapi,
            )
            .await?;
        Ok(field(&v, &["djRadios"]).unwrap_or_default())
    }

    /// `dj_personalize_recommend`：推荐播客
    pub async fn recommend_radios(&self, limit: u32) -> Result<Vec<Radio>> {
        let v = self
            .request(
                "/api/djradio/personalize/rcmd",
                json!({ "limit": limit }),
                Crypto::Weapi,
            )
            .await?;
        Ok(field(&v, &["data"]).unwrap_or_default())
    }

    /// `dj_program`：播客的节目，转换成可直接播放的歌曲。返回 (节目, 总数)。
    pub async fn radio_programs(
        &self,
        radio_id: u64,
        offset: u32,
        limit: u32,
    ) -> Result<(Vec<Song>, u64)> {
        let v = self
            .request(
                "/api/dj/program/byradio",
                json!({ "radioId": radio_id, "limit": limit, "offset": offset, "asc": false }),
                Crypto::Weapi,
            )
            .await?;
        let songs = v["programs"]
            .as_array()
            .map(|list| list.iter().filter_map(program_to_song).collect())
            .unwrap_or_default();
        Ok((songs, v["count"].as_u64().unwrap_or_default()))
    }
}

/// 节目本身不是歌曲，但它的 `mainSong` 可以直接取播放地址
fn program_to_song(p: &Value) -> Option<Song> {
    let id = p["mainSong"]["id"].as_u64().filter(|&i| i > 0)?;
    Some(Song {
        id,
        name: p["name"].as_str().unwrap_or_default().to_owned(),
        artists: vec![ArtistRef {
            id: 0,
            name: p["dj"]["nickname"].as_str().unwrap_or_default().to_owned(),
        }],
        album: AlbumRef {
            id: p["radio"]["id"].as_u64().unwrap_or_default(),
            name: p["radio"]["name"].as_str().unwrap_or_default().to_owned(),
            pic_url: p["coverUrl"].as_str().map(str::to_owned),
        },
        duration_ms: p["duration"].as_u64().unwrap_or_default(),
        fee: 0,
        alias: vec![],
    })
}

/// 扫码登录二维码的内容。
pub fn qr_login_url(key: &str) -> String {
    format!("https://music.163.com/login?codekey={key}")
}

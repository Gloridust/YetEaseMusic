//! 账号、发现、歌单、搜索。

use ncm_core::ncm_api::{QrStatus, qr_login_url};

use crate::api::types::*;
use crate::state::{core, lookup, remember, run};

fn songs(list: &[ncm_core::ncm_api::Song]) -> Vec<SongItem> {
    remember(list);
    list.iter().map(Into::into).collect()
}

pub async fn account() -> anyhow::Result<Option<AccountInfo>> {
    run(async move {
        Ok(core()?.api().account().await?.map(|a| AccountInfo {
            user_id: a.user_id as i64,
            nickname: a.nickname,
            avatar_url: a.avatar_url,
            vip_type: a.vip_type,
        }))
    })
    .await
}

/// 返回 (key, 二维码内容)
pub async fn qr_create() -> anyhow::Result<(String, String)> {
    run(async move {
        let key = core()?.api().qr_key().await?;
        let url = qr_login_url(&key);
        Ok((key, url))
    })
    .await
}

pub async fn qr_check(key: String) -> anyhow::Result<QrState> {
    run(async move {
        Ok(match core()?.qr_check(&key).await? {
            QrStatus::Expired => QrState::Expired,
            QrStatus::Waiting => QrState::Waiting,
            QrStatus::Scanned {
                nickname,
                avatar_url,
            } => QrState::Scanned {
                nickname,
                avatar_url,
            },
            QrStatus::Authorized => QrState::Authorized,
            QrStatus::Other { code, message } => QrState::Failed {
                message: format!("{code} {message}"),
            },
        })
    })
    .await
}

pub async fn logout() -> anyhow::Result<()> {
    run(async move { Ok(core()?.logout().await?) }).await
}

pub async fn search_songs(
    keywords: String,
    offset: i32,
    limit: i32,
) -> anyhow::Result<(Vec<SongItem>, i64)> {
    run(async move {
        let (list, total) = core()?
            .api()
            .search_songs(&keywords, limit.max(1) as u32, offset.max(0) as u32)
            .await?;
        Ok((songs(&list), total as i64))
    })
    .await
}

pub async fn recommend_playlists(limit: i32) -> anyhow::Result<Vec<PlaylistItem>> {
    run(async move {
        let list = core()?
            .api()
            .recommend_playlists(limit.max(1) as u32)
            .await?;
        Ok(list.iter().map(Into::into).collect())
    })
    .await
}

pub async fn daily_songs() -> anyhow::Result<Vec<SongItem>> {
    run(async move { Ok(songs(&core()?.api().daily_songs().await?)) }).await
}

pub async fn user_playlists(user_id: i64) -> anyhow::Result<Vec<PlaylistItem>> {
    run(async move {
        let list = core()?
            .api()
            .user_playlists(user_id as u64, 1000, 0)
            .await?;
        Ok(list.iter().map(Into::into).collect())
    })
    .await
}

pub async fn playlist_detail(id: i64) -> anyhow::Result<PlaylistDetailInfo> {
    run(async move {
        let d = core()?.api().playlist_detail(id as u64).await?;
        Ok(PlaylistDetailInfo {
            summary: (&d.summary).into(),
            description: d.description,
            tracks: songs(&d.tracks),
        })
    })
    .await
}

pub async fn liked_song_ids(user_id: i64) -> anyhow::Result<Vec<i64>> {
    run(async move {
        Ok(core()?
            .api()
            .liked_song_ids(user_id as u64)
            .await?
            .into_iter()
            .map(|i| i as i64)
            .collect())
    })
    .await
}

pub async fn like_song(id: i64, like: bool) -> anyhow::Result<()> {
    run(async move { Ok(core()?.api().like_song(id as u64, like).await?) }).await
}

// ---------- 歌曲社交信息 ----------

pub async fn song_like_count(id: i64) -> anyhow::Result<LikeCountInfo> {
    run(async move {
        let c = core()?.api().song_like_count(id as u64).await?;
        Ok(LikeCountInfo {
            count: c.count as i64,
            text: c.count_desc.unwrap_or_else(|| c.count.to_string()),
        })
    })
    .await
}

/// 歌曲评论。`before_ms` 翻页时传上一页最后一条评论的时间。
pub async fn song_comments(id: i64, offset: i32, before_ms: i64) -> anyhow::Result<CommentsInfo> {
    run(async move {
        let c = core()?
            .api()
            .song_comments(id as u64, 30, offset.max(0) as u32, before_ms.max(0) as u64)
            .await?;
        Ok(CommentsInfo {
            total: c.total as i64,
            hot: c.hot.iter().map(Into::into).collect(),
            latest: c.latest.iter().map(Into::into).collect(),
            more: c.more,
        })
    })
    .await
}

// ---------- 我的音乐 ----------

pub async fn recent_songs() -> anyhow::Result<Vec<RecentItem>> {
    run(async move {
        let list = core()?.api().recent_songs(300).await?;
        remember(&list.iter().map(|r| r.song.clone()).collect::<Vec<_>>());
        Ok(list
            .iter()
            .map(|r| RecentItem {
                song: (&r.song).into(),
                play_time_ms: r.play_time as i64,
            })
            .collect())
    })
    .await
}

pub async fn follows(user_id: i64, offset: i32) -> anyhow::Result<(Vec<FollowItem>, bool)> {
    run(async move {
        let (list, more) = core()?
            .api()
            .follows(user_id as u64, offset.max(0) as u32, 60)
            .await?;
        Ok((list.iter().map(Into::into).collect(), more))
    })
    .await
}

pub async fn create_playlist(name: String, private: bool) -> anyhow::Result<PlaylistItem> {
    run(async move { Ok((&core()?.api().create_playlist(&name, private).await?).into()) }).await
}

pub async fn add_to_playlist(playlist_id: i64, song_ids: Vec<i64>) -> anyhow::Result<()> {
    run(async move {
        let ids: Vec<u64> = song_ids.into_iter().map(|i| i as u64).collect();
        Ok(core()?
            .api()
            .playlist_tracks(playlist_id as u64, &ids, true)
            .await?)
    })
    .await
}

pub async fn remove_from_playlist(playlist_id: i64, song_ids: Vec<i64>) -> anyhow::Result<()> {
    run(async move {
        let ids: Vec<u64> = song_ids.into_iter().map(|i| i as u64).collect();
        Ok(core()?
            .api()
            .playlist_tracks(playlist_id as u64, &ids, false)
            .await?)
    })
    .await
}

// ---------- 播客 ----------

pub async fn subscribed_radios() -> anyhow::Result<Vec<RadioItem>> {
    run(async move {
        Ok(core()?
            .api()
            .subscribed_radios()
            .await?
            .iter()
            .map(Into::into)
            .collect())
    })
    .await
}

pub async fn recommend_radios(limit: i32) -> anyhow::Result<Vec<RadioItem>> {
    run(async move {
        Ok(core()?
            .api()
            .recommend_radios(limit.max(1) as u32)
            .await?
            .iter()
            .map(Into::into)
            .collect())
    })
    .await
}

/// 返回 (节目, 总数)
pub async fn radio_programs(radio_id: i64, offset: i32) -> anyhow::Result<(Vec<SongItem>, i64)> {
    run(async move {
        let (list, total) = core()?
            .api()
            .radio_programs(radio_id as u64, offset.max(0) as u32, 100)
            .await?;
        Ok((songs(&list), total as i64))
    })
    .await
}

// ---------- 本地音乐与下载 ----------

pub async fn scan_local_music() -> anyhow::Result<Vec<SongItem>> {
    run(async move { Ok(songs(&core()?.scan_local().await)) }).await
}

pub fn downloads() -> anyhow::Result<Vec<DownloadItem>> {
    let list = core()?.downloads();
    remember(&list.iter().map(|e| e.song.clone()).collect::<Vec<_>>());
    Ok(list
        .iter()
        .map(|e| DownloadItem {
            song: (&e.song).into(),
            path: e.path.to_string_lossy().into_owned(),
            size: e.size as i64,
            time_sec: e.time as i64,
            level: e.level.clone(),
        })
        .collect())
}

pub fn downloading() -> anyhow::Result<Vec<DownloadingItem>> {
    Ok(core()?
        .downloading()
        .iter()
        .map(|(s, p)| DownloadingItem {
            song: s.into(),
            progress: *p,
        })
        .collect())
}

/// 后台下载，立即返回；进度通过 `UiEvent::DownloadsChanged` 通知
pub async fn download_songs(ids: Vec<i64>) -> anyhow::Result<()> {
    run(async move {
        let c = core()?;
        let ids: Vec<u64> = ids.into_iter().map(|i| i as u64).collect();
        let (_, missing) = lookup(&ids);
        if !missing.is_empty() {
            remember(&c.api().song_detail(&missing).await?);
        }
        let (list, _) = lookup(&ids);
        for s in list {
            if c.is_downloaded(s.id) {
                continue;
            }
            let c = c.clone();
            // 逐首串行下载，避免同时打开太多连接
            let _ = c.download(s).await;
        }
        Ok(())
    })
    .await
}

pub fn delete_download(id: i64) -> anyhow::Result<()> {
    Ok(core()?.delete_download(id as u64)?)
}

pub fn get_storage_settings() -> anyhow::Result<StorageSettings> {
    let s = core()?.settings();
    Ok(StorageSettings {
        local_dirs: s.local_dirs,
        download_dir: s.download_dir,
    })
}

pub fn set_storage_settings(local_dirs: Vec<String>, download_dir: String) -> anyhow::Result<()> {
    core()?.update_settings(|s| {
        s.local_dirs = local_dirs
            .into_iter()
            .filter(|d| !d.trim().is_empty())
            .collect();
        if !download_dir.trim().is_empty() {
            s.download_dir = download_dir;
        }
    });
    Ok(())
}

/// 心动模式：从「我喜欢」里挑一首作起点（当前歌曲是红心歌曲时优先用它），生成推荐序列并开始播放
pub async fn heartbeat_mode(liked_playlist_id: i64, liked_ids: Vec<i64>) -> anyhow::Result<()> {
    run(async move {
        let c = core()?;
        let current = c.current_song().map(|s| s.id as i64);
        let seed = match current.filter(|id| liked_ids.contains(id)) {
            Some(id) => id,
            None if !liked_ids.is_empty() => liked_ids[rand_index(liked_ids.len())],
            None => anyhow::bail!("「我喜欢的音乐」还是空的"),
        } as u64;
        let mut list = c.api().song_detail(&[seed]).await?;
        list.extend(
            c.api()
                .intelligence_list(seed, liked_playlist_id as u64)
                .await?,
        );
        remember(&list);
        c.play_list(list, 0).await;
        Ok(())
    })
    .await
}

fn rand_index(n: usize) -> usize {
    use std::time::{SystemTime, UNIX_EPOCH};
    let t = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.subsec_nanos())
        .unwrap_or(0);
    t as usize % n
}

// ---------- 图片 ----------

/// 带磁盘缓存的图片下载，Dart 侧的 `RustImage` 用它取字节
pub async fn image_bytes(url: String) -> anyhow::Result<Vec<u8>> {
    run(async move { Ok(core()?.image(&url).await?) }).await
}

// ---------- 缓存 ----------

pub async fn cache_info() -> anyhow::Result<CacheInfo> {
    run(async move {
        let c = core()?;
        let (a, i) = c.cache_usage().await;
        Ok(CacheInfo {
            audio_bytes: a as i64,
            image_bytes: i as i64,
            audio_limit_mb: c.settings().cache_limit_mb as i32,
        })
    })
    .await
}

/// 清除缓存，返回释放的字节数。`audio` 为 false 时清图片缓存
pub async fn clear_cache(audio: bool) -> anyhow::Result<i64> {
    run(async move { Ok(core()?.clear_cache(audio).await as i64) }).await
}

/// 设置音乐缓存上限（MB），立即按新上限清理一次
pub fn set_cache_limit(mb: i32) -> anyhow::Result<()> {
    let c = core()?;
    c.update_settings(|s| s.cache_limit_mb = mb.clamp(256, 102_400) as u32);
    c.prune_caches();
    Ok(())
}

// ---------- 专辑 / 歌手 / 排行榜 / 歌单广场 / 搜索 ----------

pub async fn album_detail(id: i64) -> anyhow::Result<AlbumPageInfo> {
    run(async move {
        let d = core()?.api().album(id as u64).await?;
        Ok(AlbumPageInfo {
            album: (&d.album).into(),
            songs: songs(&d.songs),
        })
    })
    .await
}

pub async fn artist_detail(id: i64) -> anyhow::Result<ArtistPageInfo> {
    run(async move {
        let d = core()?.api().artist(id as u64).await?;
        Ok(ArtistPageInfo {
            artist: (&d.artist).into(),
            hot_songs: songs(&d.hot_songs),
        })
    })
    .await
}

/// 返回 (专辑, 是否还有更多)
pub async fn artist_albums(id: i64, offset: i32) -> anyhow::Result<(Vec<AlbumCard>, bool)> {
    run(async move {
        let (list, more) = core()?
            .api()
            .artist_albums(id as u64, offset.max(0) as u32, 60)
            .await?;
        Ok((list.iter().map(Into::into).collect(), more))
    })
    .await
}

pub async fn toplists() -> anyhow::Result<Vec<PlaylistItem>> {
    run(async move {
        Ok(core()?
            .api()
            .toplists()
            .await?
            .iter()
            .map(Into::into)
            .collect())
    })
    .await
}

/// 歌单广场。返回 (歌单, 总数)
pub async fn top_playlists(
    category: String,
    offset: i32,
) -> anyhow::Result<(Vec<PlaylistItem>, i64)> {
    run(async move {
        let (list, total) = core()?
            .api()
            .top_playlists(&category, "hot", offset.max(0) as u32, 50)
            .await?;
        Ok((list.iter().map(Into::into).collect(), total as i64))
    })
    .await
}

pub async fn playlist_categories() -> anyhow::Result<Vec<CategoryItem>> {
    run(async move {
        Ok(core()?
            .api()
            .playlist_categories()
            .await?
            .into_iter()
            .map(|c| CategoryItem {
                name: c.name,
                group: c.group,
                hot: c.hot,
            })
            .collect())
    })
    .await
}

pub async fn similar_songs(id: i64) -> anyhow::Result<Vec<SongItem>> {
    run(async move { Ok(songs(&core()?.api().similar_songs(id as u64).await?)) }).await
}

pub async fn search_playlists(
    keywords: String,
    offset: i32,
) -> anyhow::Result<(Vec<PlaylistItem>, i64)> {
    run(async move {
        let (list, total) = core()?
            .api()
            .search_playlists(&keywords, offset.max(0) as u32, 40)
            .await?;
        Ok((list.iter().map(Into::into).collect(), total as i64))
    })
    .await
}

pub async fn search_albums(keywords: String, offset: i32) -> anyhow::Result<(Vec<AlbumCard>, i64)> {
    run(async move {
        let (list, total) = core()?
            .api()
            .search_albums(&keywords, offset.max(0) as u32, 40)
            .await?;
        Ok((list.iter().map(Into::into).collect(), total as i64))
    })
    .await
}

pub async fn search_artists(
    keywords: String,
    offset: i32,
) -> anyhow::Result<(Vec<ArtistCard>, i64)> {
    run(async move {
        let (list, total) = core()?
            .api()
            .search_artists(&keywords, offset.max(0) as u32, 40)
            .await?;
        Ok((list.iter().map(Into::into).collect(), total as i64))
    })
    .await
}

// ---------- 收藏 ----------

pub async fn album_subscribed(id: i64) -> anyhow::Result<bool> {
    run(async move { Ok(core()?.api().album_subscribed(id as u64).await?) }).await
}

pub async fn set_album_subscribed(id: i64, enable: bool) -> anyhow::Result<()> {
    run(async move {
        Ok(core()?
            .api()
            .set_album_subscribed(id as u64, enable)
            .await?)
    })
    .await
}

pub async fn set_artist_followed(id: i64, enable: bool) -> anyhow::Result<()> {
    run(async move { Ok(core()?.api().set_artist_followed(id as u64, enable).await?) }).await
}

pub async fn set_playlist_subscribed(id: i64, enable: bool) -> anyhow::Result<()> {
    run(async move {
        Ok(core()?
            .api()
            .set_playlist_subscribed(id as u64, enable)
            .await?)
    })
    .await
}

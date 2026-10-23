//! 账号、发现、歌单、搜索。

use ncm_core::ncm_api::{QrStatus, qr_login_url};

use crate::api::types::*;
use crate::state::{core, remember, run};

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

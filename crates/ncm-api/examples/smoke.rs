//! 不登录的联网冒烟测试：cargo run -p ncm-api --example smoke
use ncm_api::{Client, Quality, Session};

#[tokio::main]
async fn main() -> ncm_api::Result<()> {
    let c = Client::new(Session::default())?;
    match c.register_anonymous().await {
        Ok(()) => println!("anonymous: MUSIC_A={}", c.session().cookies.contains_key("MUSIC_A")),
        Err(e) => println!("anonymous register failed: {e}"),
    }
    let (songs, total) = c.search_songs("晴天 周杰伦", 5, 0).await?;
    println!("search total={total}");
    for s in &songs {
        println!("  {} {} - {} fee={}", s.id, s.name, s.artist_names(), s.fee);
    }
    let pls = c.recommend_playlists(3).await?;
    for p in &pls {
        println!("playlist {} {} ({} tracks)", p.id, p.name, p.track_count);
    }
    if let Some(p) = pls.first() {
        let d = c.playlist_detail(p.id).await?;
        println!("detail: {} tracks loaded", d.tracks.len());
    }
    // 一首免费歌：Free Loop
    for id in [1_330_348_068u64, songs.first().map(|s| s.id).unwrap_or(0)] {
        match c.song_url(id, Quality::Lossless).await {
            Ok(u) => println!("url {id}: {:?} br={} type={:?} trial={}", u.url.as_deref().map(|s| &s[..s.len().min(60)]), u.br, u.format, u.free_trial.as_ref().is_some_and(|v| !v.is_null())),
            Err(e) => println!("url {id} error: {e}"),
        }
    }
    let l = c.lyrics(songs.first().map(|s| s.id).unwrap_or(186016)).await?;
    println!("lyric lines={} tlyric={}", l.lrc.lines().count(), !l.translation.is_empty());
    let key = c.qr_key().await?;
    println!("qr key ok: {}", ncm_api::qr_login_url(&key));
    println!("qr status: {:?}", c.qr_check(&key).await?);
    println!("account: {:?}", c.account().await?);
    Ok(())
}

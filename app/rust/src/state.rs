//! FFI 层的全局状态：自建 tokio 运行时 + 核心实例 + 歌曲缓存。不对 Dart 暴露。

use std::collections::HashMap;
use std::future::Future;
use std::sync::{Arc, Mutex, OnceLock};

use ncm_core::Core;
use ncm_core::ncm_api::Song;

pub(crate) fn rt() -> &'static tokio::runtime::Runtime {
    static RT: OnceLock<tokio::runtime::Runtime> = OnceLock::new();
    RT.get_or_init(|| {
        tokio::runtime::Builder::new_multi_thread()
            .worker_threads(4)
            .thread_name("ncm-rt")
            .enable_all()
            .build()
            .expect("tokio runtime")
    })
}

/// 在自建运行时里跑异步任务。frb 的执行器不保证是 tokio，核心层又依赖 tokio。
pub(crate) async fn run<T, F>(f: F) -> anyhow::Result<T>
where
    T: Send + 'static,
    F: Future<Output = anyhow::Result<T>> + Send + 'static,
{
    rt().spawn(f).await?
}

pub(crate) static CORE: OnceLock<Arc<Core>> = OnceLock::new();

pub(crate) fn core() -> anyhow::Result<Arc<Core>> {
    CORE.get()
        .cloned()
        .ok_or_else(|| anyhow::anyhow!("core not initialized; call bootstrap() first"))
}

/// 列表接口返回过的歌曲都记在这里，Dart 侧播放时只传 id。
static SONGS: OnceLock<Mutex<HashMap<u64, Song>>> = OnceLock::new();

pub(crate) fn remember(songs: &[Song]) {
    let mut m = SONGS.get_or_init(Default::default).lock().unwrap();
    for s in songs {
        m.insert(s.id, s.clone());
    }
}

pub(crate) fn lookup(ids: &[u64]) -> (Vec<Song>, Vec<u64>) {
    let m = SONGS.get_or_init(Default::default).lock().unwrap();
    let mut found = Vec::new();
    let mut missing = Vec::new();
    for id in ids {
        match m.get(id) {
            Some(s) => found.push(s.clone()),
            None => missing.push(*id),
        }
    }
    (found, missing)
}

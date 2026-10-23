//! 本地音乐与下载管理。
//!
//! 本地文件也表示成 [`Song`]，id 置上 [`LOCAL_BIT`] 以和网易云的歌曲 id 区分（网易云 id 远小于 2^60）。

use std::collections::HashMap;
use std::hash::{Hash, Hasher};
use std::io::Cursor;
use std::path::{Path, PathBuf};

use lofty::config::WriteOptions;
use lofty::file::{AudioFile, TaggedFileExt};
use lofty::picture::{Picture, PictureType};
use lofty::tag::{Accessor, Tag};
use ncm_api::{AlbumRef, ArtistRef, Song};
use serde::{Deserialize, Serialize};

pub const LOCAL_BIT: u64 = 1 << 60;

pub fn is_local(id: u64) -> bool {
    id & LOCAL_BIT != 0
}

const AUDIO_EXTS: &[&str] = &[
    "mp3", "flac", "m4a", "aac", "ogg", "oga", "opus", "wav", "aiff", "ape", "wv",
];

fn local_id(path: &Path) -> u64 {
    let mut h = std::collections::hash_map::DefaultHasher::new();
    path.hash(&mut h);
    LOCAL_BIT | (h.finish() & (LOCAL_BIT - 1))
}

/// 递归扫描目录里的音频文件，读取标签。封面提取到 `cover_dir`，`pic_url` 填本地路径。
pub fn scan(dirs: &[PathBuf], cover_dir: &Path) -> Vec<(Song, PathBuf)> {
    let mut files = Vec::new();
    for d in dirs {
        walk(d, &mut files, 0);
    }
    let _ = std::fs::create_dir_all(cover_dir);
    let mut out: Vec<(Song, PathBuf)> = files
        .into_iter()
        .map(|p| (read_song(&p, cover_dir), p))
        .collect();
    out.sort_by(|a, b| a.0.name.to_lowercase().cmp(&b.0.name.to_lowercase()));
    out
}

fn walk(dir: &Path, out: &mut Vec<PathBuf>, depth: usize) {
    if depth > 12 {
        return;
    }
    let Ok(rd) = std::fs::read_dir(dir) else {
        return;
    };
    for e in rd.flatten() {
        let p = e.path();
        let hidden = p
            .file_name()
            .and_then(|n| n.to_str())
            .is_some_and(|n| n.starts_with('.'));
        if hidden {
            continue;
        }
        match e.file_type() {
            Ok(t) if t.is_dir() => walk(&p, out, depth + 1),
            Ok(t) if t.is_file() => {
                let ext = p
                    .extension()
                    .and_then(|x| x.to_str())
                    .map(str::to_ascii_lowercase);
                if ext.is_some_and(|x| AUDIO_EXTS.contains(&x.as_str())) {
                    out.push(p);
                }
            }
            _ => {}
        }
    }
}

/// 读标签；没有标签时按「歌手 - 标题」解析文件名
pub fn read_song(path: &Path, cover_dir: &Path) -> Song {
    let id = local_id(path);
    let stem = path
        .file_stem()
        .and_then(|s| s.to_str())
        .unwrap_or_default()
        .to_owned();
    let (mut artist, mut title) = match stem.split_once(" - ") {
        Some((a, t)) => (a.trim().to_owned(), t.trim().to_owned()),
        None => (String::new(), stem.clone()),
    };
    let mut album = String::new();
    let mut duration_ms = 0;
    let mut pic_url = None;
    if let Ok(f) = lofty::read_from_path(path) {
        duration_ms = f.properties().duration().as_millis() as u64;
        if let Some(tag) = f.primary_tag().or_else(|| f.first_tag()) {
            if let Some(t) = tag.title().filter(|t| !t.trim().is_empty()) {
                title = t.into_owned();
            }
            if let Some(a) = tag.artist().filter(|a| !a.trim().is_empty()) {
                artist = a.into_owned();
            }
            if let Some(a) = tag.album() {
                album = a.into_owned();
            }
            if let Some(pic) = tag.pictures().first() {
                let cover = cover_dir.join(format!("{id:x}.img"));
                if cover.exists() || std::fs::write(&cover, pic.data()).is_ok() {
                    pic_url = Some(cover.to_string_lossy().into_owned());
                }
            }
        }
    }
    Song {
        id,
        name: title,
        artists: artist
            .split(['/', '、', ';'])
            .map(str::trim)
            .filter(|a| !a.is_empty())
            .map(|a| ArtistRef {
                id: 0,
                name: a.to_owned(),
            })
            .collect(),
        album: AlbumRef {
            id: 0,
            name: album,
            pic_url,
        },
        duration_ms,
        fee: 0,
        alias: vec![],
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DownloadEntry {
    pub song: Song,
    pub path: PathBuf,
    pub size: u64,
    /// 秒级时间戳
    pub time: u64,
    pub level: String,
}

/// 下载记录，持久化在数据目录的 `downloads.json`
#[derive(Debug, Default, Serialize, Deserialize)]
pub struct Downloads {
    pub entries: Vec<DownloadEntry>,
}

impl Downloads {
    /// 去掉文件已被删除的条目
    pub fn prune(&mut self) {
        self.entries.retain(|e| e.path.is_file());
    }

    pub fn find(&self, id: u64) -> Option<&DownloadEntry> {
        self.entries
            .iter()
            .find(|e| e.song.id == id && e.path.is_file())
    }

    pub fn upsert(&mut self, e: DownloadEntry) {
        self.entries.retain(|x| x.song.id != e.song.id);
        self.entries.insert(0, e);
    }
}

/// 文件名里不能出现的字符
pub fn safe_file_name(s: &str) -> String {
    let s: String = s
        .chars()
        .map(|c| {
            if matches!(c, '/' | '\\' | ':' | '*' | '?' | '"' | '<' | '>' | '|') || c.is_control() {
                '_'
            } else {
                c
            }
        })
        .collect();
    let s = s.trim().trim_matches('.');
    s.chars().take(120).collect()
}

/// 给下载好的文件写入标题、歌手、专辑与封面
pub fn write_tags(path: &Path, song: &Song, cover: Option<&[u8]>) -> Result<(), String> {
    let mut f = lofty::read_from_path(path).map_err(|e| e.to_string())?;
    let tag_type = f.primary_tag_type();
    if f.primary_tag().is_none() {
        f.insert_tag(Tag::new(tag_type));
    }
    let tag = f.primary_tag_mut().ok_or("no tag")?;
    tag.set_title(song.name.clone());
    tag.set_artist(song.artist_names());
    tag.set_album(song.album.name.clone());
    if let Some(bytes) = cover
        && let Ok(mut pic) = Picture::from_reader(&mut Cursor::new(bytes))
    {
        pic.set_pic_type(PictureType::CoverFront);
        tag.push_picture(pic);
    }
    f.save_to_path(path, WriteOptions::default())
        .map_err(|e| e.to_string())
}

/// 播放路径表：本地 id → 文件
pub type LocalIndex = HashMap<u64, PathBuf>;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn local_ids_are_tagged() {
        let id = local_id(Path::new("/music/a.flac"));
        assert!(is_local(id));
        assert!(!is_local(3986241));
        assert!(id < (1 << 61), "必须能放进 Dart 的 int");
    }

    #[test]
    fn sanitizes_names() {
        assert_eq!(safe_file_name("AC/DC: Back?"), "AC_DC_ Back_");
    }
}

//! 播放队列与播放模式。

use ncm_api::Song;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
pub enum PlayMode {
    #[default]
    Sequential,
    RepeatAll,
    RepeatOne,
    Shuffle,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct Queue {
    pub songs: Vec<Song>,
    /// 当前曲目在 `songs` 里的下标
    pub current: Option<usize>,
    pub mode: PlayMode,
    /// 随机模式下的播放顺序（`songs` 的下标）
    order: Vec<usize>,
}

impl Queue {
    pub fn replace(&mut self, songs: Vec<Song>, start: usize) {
        self.songs = songs;
        self.current = (!self.songs.is_empty()).then(|| start.min(self.songs.len() - 1));
        self.reshuffle();
    }

    pub fn current_song(&self) -> Option<&Song> {
        self.current.and_then(|i| self.songs.get(i))
    }

    pub fn set_mode(&mut self, mode: PlayMode) {
        self.mode = mode;
        self.reshuffle();
    }

    /// 插到当前曲目之后
    pub fn play_next(&mut self, song: Song) {
        let at = self.current.map_or(0, |i| i + 1);
        self.songs.retain(|s| s.id != song.id);
        let at = at.min(self.songs.len());
        self.songs.insert(at, song);
        self.reshuffle();
    }

    fn reshuffle(&mut self) {
        let n = self.songs.len();
        self.order = (0..n).collect();
        if self.mode == PlayMode::Shuffle && n > 1 {
            // Fisher-Yates，当前曲目放在最前
            for i in (1..n).rev() {
                let j = rand::random_range(0..=i);
                self.order.swap(i, j);
            }
            if let Some(c) = self.current
                && let Some(pos) = self.order.iter().position(|&x| x == c)
            {
                self.order.swap(0, pos);
            }
        }
    }

    fn step(&self, forward: bool, wrap: bool) -> Option<usize> {
        let n = self.songs.len();
        let cur = self.current?;
        let pos = self.order.iter().position(|&x| x == cur)?;
        let next = if forward {
            if pos + 1 < n { Some(pos + 1) } else if wrap { Some(0) } else { None }
        } else if pos > 0 {
            Some(pos - 1)
        } else if wrap {
            Some(n - 1)
        } else {
            None
        };
        next.map(|p| self.order[p])
    }

    /// 曲目自然结束后的下一首
    pub fn after_end(&self) -> Option<usize> {
        match self.mode {
            PlayMode::RepeatOne => self.current,
            PlayMode::Sequential => self.step(true, false),
            PlayMode::RepeatAll | PlayMode::Shuffle => self.step(true, true),
        }
    }

    /// 用户点"下一首"（单曲循环时也切到下一首）
    pub fn next(&self) -> Option<usize> {
        self.step(true, true)
    }

    pub fn prev(&self) -> Option<usize> {
        self.step(false, true)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn songs(n: u64) -> Vec<Song> {
        (1..=n).map(|id| Song { id, ..Default::default() }).collect()
    }

    #[test]
    fn sequential_stops_at_end() {
        let mut q = Queue::default();
        q.replace(songs(3), 2);
        assert_eq!(q.after_end(), None);
        assert_eq!(q.next(), Some(0));
    }

    #[test]
    fn shuffle_visits_all() {
        let mut q = Queue::default();
        q.replace(songs(10), 3);
        q.set_mode(PlayMode::Shuffle);
        let mut seen = vec![3];
        for _ in 0..9 {
            q.current = q.after_end();
            seen.push(q.current.unwrap());
        }
        seen.sort();
        assert_eq!(seen, (0..10).collect::<Vec<_>>());
    }
}

//! LRC 解析，合并原文与翻译。

use ncm_api::LyricWord;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct LyricLine {
    pub time_ms: u64,
    /// 行时长（逐字歌词才有，普通 LRC 为 0）
    pub duration_ms: u64,
    pub text: String,
    pub translation: Option<String>,
    /// 逐字时间轴；为空表示只有行级时间
    pub words: Vec<LyricWord>,
}

/// 解析一段 LRC，返回按时间排序的 (时间, 文本)。忽略 `[ar:]` 等标签和网易云的 JSON 元信息行。
pub fn parse_lrc(src: &str) -> Vec<(u64, String)> {
    let mut out = Vec::new();
    for line in src.lines() {
        let mut rest = line.trim();
        let mut times = Vec::new();
        while let Some(body) = rest.strip_prefix('[') {
            let Some(end) = body.find(']') else { break };
            if let Some(t) = parse_time(&body[..end]) {
                times.push(t);
            }
            rest = &body[end + 1..];
        }
        let text = rest.trim();
        for t in times {
            out.push((t, text.to_owned()));
        }
    }
    out.sort_by_key(|(t, _)| *t);
    out
}

fn parse_time(tag: &str) -> Option<u64> {
    let (m, s) = tag.split_once(':')?;
    let m: u64 = m.trim().parse().ok()?;
    let (sec, frac) = match s.split_once(['.', ':']) {
        Some((a, b)) => (a, b),
        None => (s, "0"),
    };
    let sec: u64 = sec.trim().parse().ok()?;
    let frac = frac.trim();
    if frac.is_empty() || !frac.bytes().all(|b| b.is_ascii_digit()) {
        return None;
    }
    // .5 → 500ms, .50 → 500ms, .500 → 500ms
    let ms = match frac.len() {
        1 => frac.parse::<u64>().ok()? * 100,
        2 => frac.parse::<u64>().ok()? * 10,
        _ => frac[..3].parse::<u64>().ok()?,
    };
    Some(m * 60_000 + sec * 1000 + ms)
}

/// 合并原文与翻译：翻译按相同时间戳挂到原文行上。空行保留（用作间奏）。
pub fn merge(lrc: &str, translation: &str) -> Vec<LyricLine> {
    let trans = parse_lrc(translation);
    parse_lrc(lrc)
        .into_iter()
        .map(|(time_ms, text)| {
            let translation = trans
                .iter()
                .find(|(t, s)| *t == time_ms && !s.is_empty())
                .map(|(_, s)| s.clone());
            LyricLine {
                time_ms,
                duration_ms: 0,
                text,
                translation,
                words: vec![],
            }
        })
        .collect()
}

/// 解析网易云逐字歌词：`[行起始,行时长](字起始,字时长,0)字(字起始,字时长,0)字…`
/// 以 `{` 开头的 JSON 元信息行（作词作曲等）跳过。
pub fn parse_yrc(src: &str) -> Vec<(u64, u64, Vec<LyricWord>)> {
    let mut out = Vec::new();
    for line in src.lines() {
        let Some(rest) = line.trim().strip_prefix('[') else {
            continue;
        };
        let Some(end) = rest.find(']') else { continue };
        let mut head = rest[..end].split(',');
        let (Some(Ok(start)), Some(Ok(dur))) = (
            head.next().map(str::parse::<u64>),
            head.next().map(str::parse::<u64>),
        ) else {
            continue;
        };
        let mut words = Vec::new();
        let mut body = &rest[end + 1..];
        while let Some(b) = body.strip_prefix('(') {
            let Some(close) = b.find(')') else { break };
            let mut nums = b[..close].split(',').map(|x| x.trim().parse::<u64>());
            let (Some(Ok(ws)), Some(Ok(wd))) = (nums.next(), nums.next()) else {
                break;
            };
            let after = &b[close + 1..];
            let next = after.find('(').unwrap_or(after.len());
            words.push(LyricWord {
                start_ms: ws,
                duration_ms: wd,
                text: after[..next].to_owned(),
            });
            body = &after[next..];
        }
        if !words.is_empty() {
            out.push((start, dur, words));
        }
    }
    out.sort_by_key(|l| l.0);
    out
}

/// 合并逐字歌词与翻译；没有逐字歌词时回落到普通 LRC
pub fn merge_all(lrc: &str, translation: &str, yrc: &str, yrc_translation: &str) -> Vec<LyricLine> {
    let lines = parse_yrc(yrc);
    if lines.is_empty() {
        return merge(lrc, translation);
    }
    let trans_src = if yrc_translation.trim().is_empty() {
        translation
    } else {
        yrc_translation
    };
    let trans = parse_lrc(trans_src);
    lines
        .into_iter()
        .map(|(time_ms, duration_ms, words)| {
            let text: String = words
                .iter()
                .map(|w| w.text.as_str())
                .collect::<String>()
                .trim()
                .to_owned();
            // 翻译的时间戳与逐字行起点一致（允许 ±50ms 误差）
            let translation = trans
                .iter()
                .find(|(t, s)| t.abs_diff(time_ms) <= 50 && !s.is_empty())
                .map(|(_, s)| s.clone());
            LyricLine {
                time_ms,
                duration_ms,
                text,
                translation,
                words,
            }
        })
        .collect()
}

/// 当前应高亮的行下标
pub fn current_line(lines: &[LyricLine], position_ms: u64) -> Option<usize> {
    match lines.partition_point(|l| l.time_ms <= position_ms) {
        0 => None,
        n => Some(n - 1),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_multi_tags_and_fractions() {
        let src = "[ti:x]\n[00:01.5][01:00.25]a\n[00:02.123]b\n{\"t\":0}";
        assert_eq!(
            parse_lrc(src),
            vec![(1500, "a".into()), (2123, "b".into()), (60250, "a".into())]
        );
    }

    #[test]
    fn parses_yrc() {
        let y = "{\"t\":0,\"c\":[]}\n[2790,5910](2790,540,0)When (3330,240,0)I (3570,360,0)was\n[8940,5490](8940,840,0)Waiting";
        let l = merge_all("", "", y, "[00:02.790]我还年轻的时候");
        assert_eq!(l.len(), 2);
        assert_eq!(l[0].text, "When I was");
        assert_eq!(l[0].duration_ms, 5910);
        assert_eq!(
            l[0].words[1],
            LyricWord {
                start_ms: 3330,
                duration_ms: 240,
                text: "I ".into()
            }
        );
        assert_eq!(l[0].translation.as_deref(), Some("我还年轻的时候"));
        assert_eq!(l[1].translation, None);
    }

    #[test]
    fn merges_translation() {
        let l = merge("[00:01.00]hello\n[00:02.00]world", "[00:01.00]你好");
        assert_eq!(l[0].translation.as_deref(), Some("你好"));
        assert_eq!(l[1].translation, None);
        assert_eq!(current_line(&l, 1500), Some(0));
        assert_eq!(current_line(&l, 500), None);
    }
}

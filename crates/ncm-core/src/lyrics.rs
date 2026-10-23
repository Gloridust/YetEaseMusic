//! LRC 解析，合并原文与翻译。

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct LyricLine {
    pub time_ms: u64,
    pub text: String,
    pub translation: Option<String>,
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
                text,
                translation,
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
    fn merges_translation() {
        let l = merge("[00:01.00]hello\n[00:02.00]world", "[00:01.00]你好");
        assert_eq!(l[0].translation.as_deref(), Some("你好"));
        assert_eq!(l[1].translation, None);
        assert_eq!(current_line(&l, 1500), Some(0));
        assert_eq!(current_line(&l, 500), None);
    }
}

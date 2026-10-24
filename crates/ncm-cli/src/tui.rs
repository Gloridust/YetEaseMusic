//! 终端界面：`yetease tui`。
//!
//! 左栏导航（每日推荐 / 推荐歌单 / 我的歌单 / 搜索结果 / 播放列表），右侧歌曲或歌单列表，
//! 底部是当前歌曲、进度条与当前歌词。键位见 [`HELP`]。

use std::sync::Arc;
use std::time::Duration;

use ncm_core::ncm_api::{PlaylistSummary, Song};
use ncm_core::ncm_player::PlaybackState;
use ncm_core::{Core, LyricLine, PlayMode};
use ratatui::crossterm::event::{self, Event, KeyCode, KeyEvent, KeyEventKind, KeyModifiers};
use ratatui::layout::{Constraint, Layout, Rect};
use ratatui::style::{Color, Modifier, Style, Stylize};
use ratatui::text::{Line, Span};
use ratatui::widgets::{
    Block, BorderType, Borders, Clear, Gauge, List, ListItem, ListState, Paragraph, Wrap,
};
use ratatui::{DefaultTerminal, Frame};
use tokio::sync::mpsc;

const RED: Color = Color::Rgb(236, 65, 65);
const DIM: Color = Color::Rgb(140, 140, 150);

const HELP: &str = "↑↓/jk 移动  Enter 播放/打开  Tab 切换焦点  / 搜索  空格 暂停  n/p 下/上一首  ←→ 快退/快进  +/- 音量  m 播放模式  l 歌词  ? 帮助  q 退出";

#[derive(Clone, Copy, PartialEq, Eq)]
enum Section {
    Daily,
    Recommend,
    Mine,
    Search,
    Queue,
}

const SECTIONS: [(Section, &str); 5] = [
    (Section::Daily, "每日推荐"),
    (Section::Recommend, "推荐歌单"),
    (Section::Mine, "我的歌单"),
    (Section::Search, "搜索结果"),
    (Section::Queue, "播放列表"),
];

/// 右侧内容
enum Content {
    Loading(String),
    Songs {
        title: String,
        songs: Vec<Song>,
    },
    Playlists {
        title: String,
        lists: Vec<PlaylistSummary>,
    },
    Message(String),
}

/// 后台任务回传给界面的结果
enum Loaded {
    Content(Content),
    Lyrics(u64, Vec<LyricLine>),
    Notice(String),
}

struct App {
    core: Arc<Core>,
    section: usize,
    focus_right: bool,
    content: Content,
    list: ListState,
    /// 打开歌单前的内容，Esc 返回
    back: Option<(Content, usize)>,
    searching: Option<String>,
    show_lyrics: bool,
    show_help: bool,
    lyrics: (u64, Vec<LyricLine>),
    notice: Option<(String, std::time::Instant)>,
    tx: mpsc::UnboundedSender<Loaded>,
}

pub async fn run(core: Arc<Core>) -> anyhow::Result<()> {
    let mut terminal = ratatui::init();
    let r = event_loop(&mut terminal, core).await;
    ratatui::restore();
    r
}

async fn event_loop(terminal: &mut DefaultTerminal, core: Arc<Core>) -> anyhow::Result<()> {
    let (tx, mut rx) = mpsc::unbounded_channel();
    let mut events = core.subscribe();
    let mut app = App {
        core,
        section: 0,
        focus_right: false,
        content: Content::Loading("加载中…".into()),
        list: ListState::default().with_selected(Some(0)),
        back: None,
        searching: None,
        show_lyrics: false,
        show_help: false,
        lyrics: (0, vec![]),
        notice: None,
        tx,
    };
    app.open_section();
    loop {
        // 核心事件：换歌时取歌词、提示信息
        while let Ok(e) = events.try_recv() {
            match e {
                ncm_core::CoreEvent::TrackChanged(Some(s)) => app.load_lyrics(s.id),
                ncm_core::CoreEvent::Notice(n) => app.notify(n),
                _ => {}
            }
        }
        while let Ok(l) = rx.try_recv() {
            match l {
                Loaded::Content(c) => {
                    app.content = c;
                    app.list.select(Some(0));
                }
                Loaded::Lyrics(id, lines) => app.lyrics = (id, lines),
                Loaded::Notice(n) => app.notify(n),
            }
        }
        terminal.draw(|f| app.draw(f))?;
        if event::poll(Duration::from_millis(120))?
            && let Event::Key(k) = event::read()?
            && k.kind == KeyEventKind::Press
            && !app.on_key(k).await
        {
            app.core.player().stop();
            return Ok(());
        }
    }
}

impl App {
    fn notify(&mut self, s: impl Into<String>) {
        self.notice = Some((s.into(), std::time::Instant::now()));
    }

    fn spawn<F>(&self, f: F)
    where
        F: std::future::Future<Output = Loaded> + Send + 'static,
    {
        let tx = self.tx.clone();
        tokio::spawn(async move {
            let _ = tx.send(f.await);
        });
    }

    fn load_lyrics(&self, id: u64) {
        let c = self.core.clone();
        self.spawn(async move { Loaded::Lyrics(id, c.lyrics(id).await.unwrap_or_default()) });
    }

    fn open_section(&mut self) {
        self.back = None;
        let c = self.core.clone();
        let (sec, _) = SECTIONS[self.section];
        match sec {
            Section::Daily => {
                self.content = Content::Loading("加载每日推荐…".into());
                self.spawn(async move {
                    match c.api().daily_songs().await {
                        Ok(songs) => Loaded::Content(Content::Songs {
                            title: "每日推荐".into(),
                            songs,
                        }),
                        Err(e) => Loaded::Content(Content::Message(format!(
                            "每日推荐需要登录（yetease login）：{e}"
                        ))),
                    }
                });
            }
            Section::Recommend => {
                self.content = Content::Loading("加载推荐歌单…".into());
                self.spawn(async move {
                    match c.api().recommend_playlists(30).await {
                        Ok(lists) => Loaded::Content(Content::Playlists {
                            title: "推荐歌单".into(),
                            lists,
                        }),
                        Err(e) => Loaded::Content(Content::Message(format!("加载失败：{e}"))),
                    }
                });
            }
            Section::Mine => {
                self.content = Content::Loading("加载我的歌单…".into());
                self.spawn(async move {
                    let acc = match c.api().account().await {
                        Ok(Some(a)) => a,
                        _ => {
                            return Loaded::Content(Content::Message(
                                "请先在终端运行 yetease login 扫码登录".into(),
                            ));
                        }
                    };
                    match c.api().user_playlists(acc.user_id, 1000, 0).await {
                        Ok(lists) => Loaded::Content(Content::Playlists {
                            title: format!("{} 的歌单", acc.nickname),
                            lists,
                        }),
                        Err(e) => Loaded::Content(Content::Message(format!("加载失败：{e}"))),
                    }
                });
            }
            Section::Search => {
                if !matches!(self.content, Content::Songs { ref title, .. } if title.starts_with("搜索"))
                {
                    self.content = Content::Message("按 / 输入关键词搜索".into());
                }
            }
            Section::Queue => {
                let q = self.core.queue();
                self.content = Content::Songs {
                    title: "播放列表".into(),
                    songs: q.songs,
                };
                self.list.select(q.current.or(Some(0)));
            }
        }
        if !matches!(sec, Section::Queue) {
            self.list.select(Some(0));
        }
    }

    fn search(&mut self, kw: String) {
        if kw.trim().is_empty() {
            return;
        }
        self.section = 3;
        self.focus_right = true;
        self.back = None;
        self.content = Content::Loading(format!("搜索「{kw}」…"));
        let c = self.core.clone();
        self.spawn(async move {
            match c.api().search_songs(&kw, 100, 0).await {
                Ok((songs, total)) => Loaded::Content(Content::Songs {
                    title: format!("搜索「{kw}」· {total} 首"),
                    songs,
                }),
                Err(e) => Loaded::Content(Content::Message(format!("搜索失败：{e}"))),
            }
        });
    }

    fn rows(&self) -> usize {
        match &self.content {
            Content::Songs { songs, .. } => songs.len(),
            Content::Playlists { lists, .. } => lists.len(),
            _ => 0,
        }
    }

    /// 返回 false 表示退出
    async fn on_key(&mut self, k: KeyEvent) -> bool {
        // 搜索输入框
        if let Some(buf) = self.searching.as_mut() {
            match k.code {
                KeyCode::Esc => self.searching = None,
                KeyCode::Enter => {
                    let kw = std::mem::take(buf);
                    self.searching = None;
                    self.search(kw);
                }
                KeyCode::Backspace => {
                    buf.pop();
                }
                KeyCode::Char(c) => buf.push(c),
                _ => {}
            }
            return true;
        }
        if self.show_help {
            self.show_help = false;
            return true;
        }
        let p = self.core.player();
        match k.code {
            KeyCode::Char('q') => return false,
            KeyCode::Char('c') if k.modifiers.contains(KeyModifiers::CONTROL) => return false,
            KeyCode::Char('?') => self.show_help = true,
            KeyCode::Char('/') => self.searching = Some(String::new()),
            KeyCode::Char(' ') => p.toggle(),
            KeyCode::Char('n') => self.core.next().await,
            KeyCode::Char('p') => self.core.prev().await,
            KeyCode::Char('l') => self.show_lyrics = !self.show_lyrics,
            KeyCode::Left => p.seek(p.position_ms().saturating_sub(5000)),
            KeyCode::Right => p.seek(p.position_ms() + 5000),
            KeyCode::Char('+') | KeyCode::Char('=') => {
                let v = (p.volume() + 0.05).min(1.0);
                self.core.update_settings(|s| s.volume = v);
            }
            KeyCode::Char('-') => {
                let v = (p.volume() - 0.05).max(0.0);
                self.core.update_settings(|s| s.volume = v);
            }
            KeyCode::Char('m') => {
                let next = match self.core.settings().play_mode {
                    PlayMode::Sequential => PlayMode::RepeatAll,
                    PlayMode::RepeatAll => PlayMode::RepeatOne,
                    PlayMode::RepeatOne => PlayMode::Shuffle,
                    PlayMode::Shuffle => PlayMode::Sequential,
                };
                self.core.update_settings(|s| s.play_mode = next);
                self.notify(format!("播放模式：{}", mode_name(next)));
            }
            KeyCode::Tab => self.focus_right = !self.focus_right,
            KeyCode::Esc | KeyCode::Backspace => {
                if let Some((c, sel)) = self.back.take() {
                    self.content = c;
                    self.list.select(Some(sel));
                } else {
                    self.focus_right = false;
                }
            }
            KeyCode::Up | KeyCode::Char('k') => self.move_by(-1),
            KeyCode::Down | KeyCode::Char('j') => self.move_by(1),
            KeyCode::PageUp => self.move_by(-10),
            KeyCode::PageDown => self.move_by(10),
            KeyCode::Enter => self.activate().await,
            _ => {}
        }
        true
    }

    fn move_by(&mut self, d: i32) {
        if self.focus_right {
            let n = self.rows();
            if n == 0 {
                return;
            }
            let cur = self.list.selected().unwrap_or(0) as i32;
            self.list
                .select(Some((cur + d).clamp(0, n as i32 - 1) as usize));
        } else {
            self.section = (self.section as i32 + d).clamp(0, SECTIONS.len() as i32 - 1) as usize;
            self.open_section();
        }
    }

    async fn activate(&mut self) {
        if !self.focus_right {
            self.focus_right = true;
            return;
        }
        let sel = self.list.selected().unwrap_or(0);
        match &self.content {
            Content::Songs { songs, .. } if sel < songs.len() => {
                let in_queue = SECTIONS[self.section].0 == Section::Queue;
                if in_queue {
                    self.core.play_index(sel).await;
                } else {
                    self.core.play_list(songs.clone(), sel).await;
                }
            }
            Content::Playlists { lists, .. } if sel < lists.len() => {
                let pl = lists[sel].clone();
                let old = std::mem::replace(
                    &mut self.content,
                    Content::Loading(format!("加载「{}」…", pl.name)),
                );
                self.back = Some((old, sel));
                let c = self.core.clone();
                self.spawn(async move {
                    match c.api().playlist_detail(pl.id).await {
                        Ok(d) => Loaded::Content(Content::Songs {
                            title: format!("{}（Esc 返回）", pl.name),
                            songs: d.tracks,
                        }),
                        Err(e) => Loaded::Notice(format!("歌单加载失败：{e}")),
                    }
                });
            }
            _ => {}
        }
    }

    // ---------- 绘制 ----------

    fn draw(&mut self, f: &mut Frame) {
        let [main, bar] =
            Layout::vertical([Constraint::Min(5), Constraint::Length(5)]).areas(f.area());
        let [nav, right] =
            Layout::horizontal([Constraint::Length(16), Constraint::Min(20)]).areas(main);
        self.draw_nav(f, nav);
        if self.show_lyrics {
            self.draw_lyrics(f, right);
        } else {
            self.draw_content(f, right);
        }
        self.draw_bar(f, bar);
        if let Some(buf) = &self.searching {
            let area = centered(f.area(), 50, 3);
            f.render_widget(Clear, area);
            f.render_widget(
                Paragraph::new(format!("{buf}▏"))
                    .block(block(" 搜索（Enter 确认，Esc 取消） ", true)),
                area,
            );
        }
        if self.show_help {
            let area = centered(f.area(), 40, HELP.split("  ").count() as u16 + 2);
            f.render_widget(Clear, area);
            f.render_widget(
                Paragraph::new(HELP.split("  ").map(Line::from).collect::<Vec<_>>())
                    .block(block(" 键位（任意键关闭） ", true)),
                area,
            );
        }
    }

    fn draw_nav(&self, f: &mut Frame, area: Rect) {
        let items: Vec<ListItem> = SECTIONS
            .iter()
            .enumerate()
            .map(|(i, (_, name))| {
                let st = if i == self.section {
                    Style::new().fg(RED).bold()
                } else {
                    Style::new()
                };
                ListItem::new(format!(" {name}")).style(st)
            })
            .collect();
        f.render_widget(
            List::new(items).block(block(" YetEase ", !self.focus_right)),
            area,
        );
    }

    fn draw_content(&mut self, f: &mut Frame, area: Rect) {
        let playing = self.core.current_song().map(|s| s.id);
        match &self.content {
            Content::Loading(s) | Content::Message(s) => {
                f.render_widget(
                    Paragraph::new(s.as_str())
                        .fg(DIM)
                        .wrap(Wrap { trim: true })
                        .block(block("", self.focus_right)),
                    area,
                );
            }
            Content::Songs { title, songs } => {
                let w = area.width.saturating_sub(4) as usize;
                let items: Vec<ListItem> = songs
                    .iter()
                    .enumerate()
                    .map(|(i, s)| {
                        let mark = if Some(s.id) == playing { "♪" } else { " " };
                        let time = fmt(s.duration_ms);
                        let name_w = w.saturating_sub(time.len() + 6);
                        let text = truncate(&format!("{} - {}", s.name, s.artist_names()), name_w);
                        let pad = name_w.saturating_sub(display_width(&text));
                        let vip = if s.fee == 1 { "V" } else { " " };
                        let style = if Some(s.id) == playing {
                            Style::new().fg(RED)
                        } else {
                            Style::new()
                        };
                        ListItem::new(Line::from(vec![
                            Span::raw(format!("{mark}{:>3} ", i + 1)).fg(DIM),
                            Span::styled(text, style),
                            Span::raw(" ".repeat(pad)),
                            Span::raw(format!("{vip} {time}")).fg(DIM),
                        ]))
                    })
                    .collect();
                let list = List::new(items)
                    .block(block(format!(" {title} "), self.focus_right))
                    .highlight_style(
                        Style::new()
                            .bg(Color::Rgb(50, 50, 60))
                            .add_modifier(Modifier::BOLD),
                    );
                f.render_stateful_widget(list, area, &mut self.list);
            }
            Content::Playlists { title, lists } => {
                let items: Vec<ListItem> = lists
                    .iter()
                    .map(|p| ListItem::new(format!(" {}  ({} 首)", p.name, p.track_count)))
                    .collect();
                let list = List::new(items)
                    .block(block(format!(" {title} "), self.focus_right))
                    .highlight_style(
                        Style::new()
                            .bg(Color::Rgb(50, 50, 60))
                            .add_modifier(Modifier::BOLD),
                    );
                f.render_stateful_widget(list, area, &mut self.list);
            }
        }
    }

    fn draw_lyrics(&self, f: &mut Frame, area: Rect) {
        let pos = self.core.player().position_ms();
        let lines = &self.lyrics.1;
        let cur = ncm_core::lyrics::current_line(lines, pos + 200).unwrap_or(0);
        let h = area.height.saturating_sub(2) as usize;
        let start = cur.saturating_sub(h / 2);
        let text: Vec<Line> = lines
            .iter()
            .enumerate()
            .skip(start)
            .take(h)
            .map(|(i, l)| {
                let t = match &l.translation {
                    Some(tr) => format!("{}  {}", l.text, tr),
                    None => l.text.clone(),
                };
                if i == cur {
                    Line::from(t).fg(RED).bold().centered()
                } else {
                    Line::from(t).fg(DIM).centered()
                }
            })
            .collect();
        let body = if lines.is_empty() {
            vec![Line::from("暂无歌词").fg(DIM).centered()]
        } else {
            text
        };
        f.render_widget(
            Paragraph::new(body).block(block(" 歌词（l 返回列表） ", true)),
            area,
        );
    }

    fn draw_bar(&mut self, f: &mut Frame, area: Rect) {
        let core = &self.core;
        let p = core.player();
        let song = core.current_song();
        let state = match p.state() {
            PlaybackState::Playing => "▶",
            PlaybackState::Paused => "⏸",
            PlaybackState::Loading => "…",
            PlaybackState::Stopped => "■",
        };
        let (pos, dur) = (p.position_ms(), p.duration_ms().max(1));
        let title = song
            .as_ref()
            .map(|s| format!("{state} {} - {}", s.name, s.artist_names()))
            .unwrap_or_else(|| "未在播放  按 ? 查看键位".into());
        let lyric = song
            .as_ref()
            .filter(|s| s.id == self.lyrics.0)
            .and_then(|_| {
                ncm_core::lyrics::current_line(&self.lyrics.1, pos + 200)
                    .map(|i| self.lyrics.1[i].text.clone())
            })
            .unwrap_or_default();
        let notice = self
            .notice
            .as_ref()
            .filter(|(_, t)| t.elapsed() < Duration::from_secs(4))
            .map(|(s, _)| s.clone());
        let s = core.settings();
        let info = format!(
            "{} / {}   音量 {:.0}%   {}",
            fmt(pos),
            fmt(dur),
            p.volume() * 100.0,
            mode_name(s.play_mode)
        );
        let block = block("", false);
        let inner = block.inner(area);
        f.render_widget(block, area);
        let [l1, l2, l3] = Layout::vertical([
            Constraint::Length(1),
            Constraint::Length(1),
            Constraint::Length(1),
        ])
        .areas(inner);
        f.render_widget(
            Paragraph::new(Line::from(vec![
                Span::raw(title).bold(),
                Span::raw("   "),
                Span::raw(info).fg(DIM),
            ])),
            l1,
        );
        f.render_widget(
            Gauge::default()
                .gauge_style(Style::new().fg(RED).bg(Color::Rgb(45, 45, 52)))
                .ratio((pos as f64 / dur as f64).clamp(0.0, 1.0))
                .label(""),
            l2,
        );
        let bottom = notice.unwrap_or(lyric);
        f.render_widget(Paragraph::new(bottom).fg(DIM).centered(), l3);
    }
}

fn block(title: impl Into<String>, focused: bool) -> Block<'static> {
    Block::new()
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(if focused {
            Style::new().fg(RED)
        } else {
            Style::new().fg(Color::Rgb(70, 70, 80))
        })
        .title(title.into())
}

fn centered(area: Rect, w: u16, h: u16) -> Rect {
    let w = w.min(area.width);
    let h = h.min(area.height);
    Rect::new(
        area.x + (area.width - w) / 2,
        area.y + (area.height - h) / 2,
        w,
        h,
    )
}

fn mode_name(m: PlayMode) -> &'static str {
    match m {
        PlayMode::Sequential => "顺序播放",
        PlayMode::RepeatAll => "列表循环",
        PlayMode::RepeatOne => "单曲循环",
        PlayMode::Shuffle => "随机播放",
    }
}

fn fmt(ms: u64) -> String {
    let s = ms / 1000;
    format!("{:02}:{:02}", s / 60, s % 60)
}

/// 终端显示宽度：中日韩字符占两格
fn display_width(s: &str) -> usize {
    s.chars()
        .map(|c| {
            if (c as u32) >= 0x1100 && !c.is_ascii() {
                2
            } else {
                1
            }
        })
        .sum()
}

fn truncate(s: &str, w: usize) -> String {
    let mut out = String::new();
    let mut used = 0;
    for c in s.chars() {
        let cw = if (c as u32) >= 0x1100 && !c.is_ascii() {
            2
        } else {
            1
        };
        if used + cw > w.saturating_sub(1) {
            out.push('…');
            return out;
        }
        used += cw;
        out.push(c);
    }
    out
}

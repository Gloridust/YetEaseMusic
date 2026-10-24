import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../src/rust/api/playback.dart' as pb;
import '../src/rust/api/types.dart';
import '../state.dart';
import '../theme.dart';
import 'pages/album_page.dart';
import 'pages/settings_page.dart';
import 'song_actions.dart';
import 'shell.dart';
import 'song_list.dart';
import 'widgets.dart';

/// 底部播放栏，布局对齐官方客户端：
/// 左：旋转小唱片 + 歌名歌手 + 红心数 / 评论数；中：模式 · 上一首 · 播放 · 下一首 · 播放列表；
/// 右：音质 · 收藏到歌单 · 音量 · 更多。`dark` 用在播放页里。
class PlayerBar extends StatelessWidget {
  const PlayerBar({super.key, this.dark = false, required this.onQueue});

  final bool dark;
  final VoidCallback onQueue;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final app = AppState.I;
    final fg = dark ? Colors.white : p.textPrimary;
    final fg2 = dark ? Colors.white60 : p.textSecondary;
    return Container(
      height: Tokens.playerBarHeight + 4,
      color: dark ? Colors.transparent : p.surface,
      child: Column(
        children: [
          ProgressLine(dark: dark),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                final narrow = c.maxWidth < 760;
                return Row(
                  children: [
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 3,
                      child: ValueListenableBuilder(
                        valueListenable: app.current,
                        builder: (context, song, _) => song == null
                            ? _IdleInfo(dark: dark, fg: fg, fg2: fg2, narrow: narrow)
                            : _NowPlayingInfo(song: song, dark: dark, fg: fg, fg2: fg2, narrow: narrow),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!narrow) ...[
                          ValueListenableBuilder(
                            valueListenable: app.mode,
                            builder: (context, m, _) =>
                                IconBtn(_modeIcon(m), tooltip: _modeLabel(m), color: fg2, onTap: app.cycleMode),
                          ),
                          const SizedBox(width: 12),
                        ],
                        IconBtn(
                          Icons.skip_previous_rounded,
                          size: 26,
                          box: 38,
                          color: fg,
                          tooltip: '上一首',
                          onTap: pb.previous,
                        ),
                        const SizedBox(width: 14),
                        _PlayButton(dark: dark),
                        const SizedBox(width: 14),
                        IconBtn(Icons.skip_next_rounded, size: 26, box: 38, color: fg, tooltip: '下一首', onTap: pb.next),
                        if (!narrow) ...[
                          const SizedBox(width: 12),
                          IconBtn(Icons.queue_music_rounded, color: fg2, tooltip: '播放列表', onTap: onQueue),
                        ],
                      ],
                    ),
                    Expanded(
                      flex: narrow ? 1 : 3,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (!narrow) ...[
                            if (c.maxWidth > 1000) ...[_TimeLabel(color: fg2), const SizedBox(width: 10)],
                            _QualityBadge(color: fg2),
                            const SizedBox(width: 6),
                            ValueListenableBuilder(
                              valueListenable: app.current,
                              builder: (context, s, _) => IconBtn(
                                Icons.library_add_outlined,
                                color: fg2,
                                tooltip: '收藏到歌单',
                                onTap: s == null || s.local ? null : () => showCollectDialog(context, [s]),
                              ),
                            ),
                            if (isDesktop) _LyricsToggle(color: fg2),
                            _VolumeButton(color: fg2),
                            Builder(
                              builder: (context) => IconBtn(
                                Icons.more_horiz_rounded,
                                color: fg2,
                                tooltip: '更多',
                                onTap: () {
                                  final s = app.current.value;
                                  if (s == null) return;
                                  final box = context.findRenderObject() as RenderBox;
                                  final pos = box.localToGlobal(Offset(0, -8));
                                  showSongMenu(context, pos, [s], 0);
                                },
                              ),
                            ),
                          ] else
                            IconBtn(Icons.queue_music_rounded, color: fg2, onTap: onQueue),
                          const SizedBox(width: 16),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 左侧：没有歌曲时的占位，避免播放栏左半边整块空白
class _IdleInfo extends StatelessWidget {
  const _IdleInfo({required this.dark, required this.fg, required this.fg2, required this.narrow});

  final bool dark;
  final Color fg, fg2;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: dark ? Colors.white.withValues(alpha: 0.08) : p.hover,
            borderRadius: BorderRadius.circular(Tokens.radiusM),
          ),
          child: Icon(Icons.music_note_rounded, size: 22, color: dark ? Colors.white38 : p.textTertiary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '未在播放',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: fg, fontWeight: FontWeight.w500),
              ),
              if (!narrow) ...[
                const SizedBox(height: 3),
                Text(
                  '选择一首歌开始播放',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: fg2),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// 左侧：转动的小唱片 + 歌名 / 歌手 + 红心数 / 评论数
class _NowPlayingInfo extends StatelessWidget {
  const _NowPlayingInfo({
    required this.song,
    required this.dark,
    required this.fg,
    required this.fg2,
    required this.narrow,
  });

  final SongItem song;
  final bool dark;
  final Color fg, fg2;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    final app = AppState.I;
    return Row(
      children: [
        if (!dark) ...[
          Hover(
            onTap: () => app.nowPlayingOpen.value = true,
            builder: (_, h) => Tooltip(
              message: '打开播放页',
              child: MiniDisc(url: song.coverUrl, size: 54, hovered: h),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Flexible(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                song.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15, color: fg, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              ArtistLinks(
                artists: song.artists,
                style: TextStyle(fontSize: 12.5, color: fg2),
              ),
            ],
          ),
        ),
        if (!song.local && !narrow) ...[
          const SizedBox(width: 10),
          ValueListenableBuilder(
            valueListenable: app.likeCountText,
            builder: (context, t, _) => _Counted(
              count: t,
              child: LikeButton(song: song, size: 20, color: fg2),
            ),
          ),
          ValueListenableBuilder(
            valueListenable: app.commentCountText,
            builder: (context, t, _) => _Counted(
              count: t,
              child: IconBtn(
                Icons.chat_bubble_outline_rounded,
                size: 19,
                color: fg2,
                tooltip: '评论',
                onTap: () => openComments(song),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// 图标右上角的小号计数（官方的 100w+ / 1w+ 样式）
class _Counted extends StatelessWidget {
  const _Counted({required this.count, required this.child});

  final String? count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = count;
    return Padding(
      padding: EdgeInsets.only(right: c == null || c.isEmpty ? 0 : 18),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          if (c != null && c.isNotEmpty)
            Positioned(
              left: 24,
              top: 1,
              child: Text(
                c,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: context.palette.textSecondary,
                  height: 1,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 小唱片：黑胶圆环中嵌封面，播放时缓慢转动
class MiniDisc extends StatefulWidget {
  const MiniDisc({super.key, required this.url, this.size = 54, this.hovered = false});

  final String? url;
  final double size;
  final bool hovered;

  @override
  State<MiniDisc> createState() => _MiniDiscState();
}

class _MiniDiscState extends State<MiniDisc> with SingleTickerProviderStateMixin {
  late final _spin = AnimationController(vsync: this, duration: const Duration(seconds: 20));

  @override
  void initState() {
    super.initState();
    AppState.I.playerState.addListener(_sync);
    _sync();
  }

  void _sync() => AppState.I.isPlaying ? _spin.repeat() : _spin.stop();

  @override
  void dispose() {
    AppState.I.playerState.removeListener(_sync);
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox.square(
      dimension: s,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RotationTransition(
            turns: _spin,
            child: ClipOval(
              child: Container(
                width: s,
                height: s,
                color: const Color(0xFF1B1B1D),
                alignment: Alignment.center,
                child: ClipOval(
                  child: Cover(url: widget.url, size: s * 0.66, radius: 0),
                ),
              ),
            ),
          ),
          AnimatedOpacity(
            opacity: widget.hovered ? 1 : 0,
            duration: const Duration(milliseconds: 120),
            child: ClipOval(
              child: Container(
                width: s,
                height: s,
                color: Colors.black45,
                child: const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white, size: 28),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 音质标签，点击切换默认音质
class _QualityBadge extends StatelessWidget {
  const _QualityBadge({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ValueListenableBuilder(
      valueListenable: AppState.I.settings,
      builder: (context, s, _) {
        if (s == null) return const SizedBox.shrink();
        return PopupMenuButton<AudioQuality>(
          tooltip: '音质',
          color: p.surface,
          position: PopupMenuPosition.over,
          offset: const Offset(0, -220),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tokens.radiusM)),
          onSelected: (q) => pb.setQuality(quality: q),
          itemBuilder: (_) => [
            for (final q in AudioQuality.values.reversed)
              PopupMenuItem(
                value: q,
                height: 38,
                child: Row(
                  children: [
                    Text(qualityLabel(q), style: TextStyle(color: q == s.quality ? Tokens.accent : p.textPrimary)),
                    const Spacer(),
                    if (q == s.quality) const Icon(Icons.check_rounded, size: 16, color: Tokens.accent),
                  ],
                ),
              ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                border: Border.all(color: color, width: 1.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                qualityLabel(s.quality),
                style: TextStyle(fontSize: 11.5, color: color, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 「词」：开关桌面歌词，开启时高亮
class _LyricsToggle extends StatelessWidget {
  const _LyricsToggle({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: AppState.I.desktopLyrics,
      builder: (context, on, _) => Tooltip(
        message: on ? '关闭桌面歌词' : '打开桌面歌词',
        child: Hover(
          onTap: AppState.I.toggleDesktopLyrics,
          builder: (_, h) => Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: h ? color.withValues(alpha: 0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(Tokens.radiusS),
            ),
            child: Text(
              '词',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: on ? Tokens.accent : color),
            ),
          ),
        ),
      ),
    );
  }
}

/// 音量：点图标弹出竖向滑块；滚轮直接调节
class _VolumeButton extends StatelessWidget {
  const _VolumeButton({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final app = AppState.I;
    final p = context.palette;
    return ValueListenableBuilder(
      valueListenable: app.volume,
      builder: (context, v, _) => Listener(
        onPointerSignal: (e) {
          if (e is PointerScrollEvent) app.setVolume((v - e.scrollDelta.dy / 1000).clamp(0.0, 1.0));
        },
        child: MenuAnchor(
          style: MenuStyle(
            backgroundColor: WidgetStatePropertyAll(p.surface),
            shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tokens.radiusM))),
          ),
          alignmentOffset: const Offset(-8, -190),
          menuChildren: [
            SizedBox(
              width: 48,
              height: 170,
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  ValueListenableBuilder(
                    valueListenable: app.volume,
                    builder: (context, vol, _) =>
                        Text('${(vol * 100).round()}', style: TextStyle(fontSize: 12, color: p.textSecondary)),
                  ),
                  Expanded(
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          overlayShape: SliderComponentShape.noOverlay,
                          activeTrackColor: Tokens.accent,
                          inactiveTrackColor: p.divider,
                          thumbColor: Tokens.accent,
                        ),
                        child: ValueListenableBuilder(
                          valueListenable: app.volume,
                          builder: (context, vol, _) => Slider(value: vol, onChanged: app.setVolume),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ],
          builder: (context, ctl, _) => IconBtn(
            v == 0 ? Icons.volume_off_outlined : (v < 0.5 ? Icons.volume_down_outlined : Icons.volume_up_outlined),
            color: color,
            tooltip: '音量',
            onTap: () => ctl.isOpen ? ctl.close() : ctl.open(),
          ),
        ),
      ),
    );
  }
}

IconData _modeIcon(PlayOrder m) => switch (m) {
  PlayOrder.sequential => Icons.trending_flat_rounded,
  PlayOrder.repeatAll => Icons.repeat_rounded,
  PlayOrder.repeatOne => Icons.repeat_one_rounded,
  PlayOrder.shuffle => Icons.shuffle_rounded,
};

String _modeLabel(PlayOrder m) => switch (m) {
  PlayOrder.sequential => '顺序播放',
  PlayOrder.repeatAll => '列表循环',
  PlayOrder.repeatOne => '单曲循环',
  PlayOrder.shuffle => '随机播放',
};

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    final app = AppState.I;
    return ValueListenableBuilder(
      valueListenable: app.playerState,
      builder: (context, st, _) => Hover(
        onTap: pb.toggle,
        builder: (_, h) => AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: dark
                ? Colors.white.withValues(alpha: h ? 0.22 : 0.14)
                : (h ? const Color(0xFFE0303F) : Tokens.accent),
            shape: BoxShape.circle,
          ),
          child: st == PlayerState.loading
              ? const Padding(
                  padding: EdgeInsets.all(15),
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                )
              : Icon(
                  st == PlayerState.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 26,
                ),
        ),
      ),
    );
  }
}

class _TimeLabel extends StatelessWidget {
  const _TimeLabel({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final app = AppState.I;
    return ListenableBuilder(
      listenable: Listenable.merge([app.position, app.duration]),
      builder: (context, _) => Text(
        '${formatMs(app.position.value)} / ${formatMs(app.duration.value)}',
        style: TextStyle(fontSize: 12, color: color, fontFeatures: const [FontFeature.tabularFigures()]),
      ),
    );
  }
}

/// 播放栏顶部的细进度条：悬停变粗，可点击或拖动跳转
class ProgressLine extends StatefulWidget {
  const ProgressLine({super.key, this.dark = false});

  final bool dark;

  @override
  State<ProgressLine> createState() => _ProgressLineState();
}

class _ProgressLineState extends State<ProgressLine> {
  bool _hover = false;
  double? _drag;

  void _seekTo(double frac) {
    final d = AppState.I.duration.value;
    if (d > 0) pb.seek(positionMs: (frac.clamp(0.0, 1.0) * d).round());
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.I;
    final p = context.palette;
    return LayoutBuilder(
      builder: (context, c) {
        double frac(Offset local) => (local.dx / c.maxWidth).clamp(0.0, 1.0);
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => _seekTo(frac(d.localPosition)),
            onHorizontalDragStart: (d) => setState(() => _drag = frac(d.localPosition)),
            onHorizontalDragUpdate: (d) => setState(() => _drag = frac(d.localPosition)),
            onHorizontalDragEnd: (_) {
              if (_drag != null) _seekTo(_drag!);
              setState(() => _drag = null);
            },
            child: SizedBox(
              height: 4,
              child: OverflowBox(
                maxHeight: 12,
                alignment: Alignment.topCenter,
                child: ListenableBuilder(
                  listenable: Listenable.merge([app.position, app.duration, app.buffered]),
                  builder: (context, _) {
                    final d = app.duration.value;
                    final played = _drag ?? (d == 0 ? 0.0 : (app.position.value / d).clamp(0.0, 1.0));
                    final h = _hover || _drag != null ? 5.0 : 3.0;
                    // 三层：底轨 < 已缓冲 < 已播放，深浅主题各自保证层次分明
                    final track = widget.dark ? Colors.white.withValues(alpha: 0.10) : p.divider;
                    final buffered = widget.dark
                        ? Colors.white.withValues(alpha: 0.22)
                        : p.textTertiary.withValues(alpha: 0.35);
                    return SizedBox(
                      height: 12,
                      child: Stack(
                        children: [
                          AnimatedContainer(duration: const Duration(milliseconds: 120), height: h, color: track),
                          FractionallySizedBox(
                            widthFactor: app.buffered.value.clamp(0.0, 1.0),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              height: h,
                              color: buffered,
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: played,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              height: h,
                              color: widget.dark ? Colors.white : Tokens.accent,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

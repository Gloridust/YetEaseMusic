import 'package:flutter/material.dart';

import '../src/rust/api/playback.dart' as pb;
import '../src/rust/api/types.dart';
import '../state.dart';
import '../theme.dart';
import 'pages/settings_page.dart';
import 'song_list.dart';
import 'widgets.dart';

/// 底部播放栏。`dark` 用在播放页里（背景是深色封面渐变）。
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
                    const SizedBox(width: 20),
                    // 左：当前歌曲
                    Expanded(
                      flex: 3,
                      child: ValueListenableBuilder(
                        valueListenable: app.current,
                        builder: (context, song, _) {
                          if (song == null) return const SizedBox.shrink();
                          return Row(
                            children: [
                              if (!dark)
                                Hover(
                                  onTap: () => app.nowPlayingOpen.value = true,
                                  builder: (_, h) => Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Cover(url: song.coverUrl, size: 52, radius: Tokens.radiusM),
                                      AnimatedOpacity(
                                        opacity: h ? 1 : 0,
                                        duration: const Duration(milliseconds: 120),
                                        child: Container(
                                          width: 52,
                                          height: 52,
                                          decoration: BoxDecoration(
                                            color: Colors.black38,
                                            borderRadius: BorderRadius.circular(Tokens.radiusM),
                                          ),
                                          child: const Icon(
                                            Icons.keyboard_arrow_up_rounded,
                                            color: Colors.white,
                                            size: 30,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (!dark) const SizedBox(width: 14),
                              Flexible(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      song.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 16, color: fg, fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      song.artists.map((a) => a.name).join(' / '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 13, color: fg2),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              LikeButton(song: song, size: 22, color: fg2),
                            ],
                          );
                        },
                      ),
                    ),
                    // 中：控制
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
                          size: 30,
                          box: 44,
                          color: fg,
                          tooltip: '上一首',
                          onTap: pb.previous,
                        ),
                        const SizedBox(width: 14),
                        _PlayButton(dark: dark),
                        const SizedBox(width: 14),
                        IconBtn(Icons.skip_next_rounded, size: 30, box: 44, color: fg, tooltip: '下一首', onTap: pb.next),
                        if (!narrow) ...[
                          const SizedBox(width: 12),
                          IconBtn(Icons.queue_music_rounded, color: fg2, tooltip: '播放列表', onTap: onQueue),
                        ],
                      ],
                    ),
                    // 右：音质 / 时间 / 音量
                    Expanded(
                      flex: 3,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (!narrow) ...[
                            _TimeLabel(color: fg2),
                            const SizedBox(width: 16),
                            ValueListenableBuilder(
                              valueListenable: app.settings,
                              builder: (context, s, _) => s == null
                                  ? const SizedBox.shrink()
                                  : Tooltip(
                                      message: '默认音质（可在设置中修改）',
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: fg2, width: 1.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          qualityLabel(s.quality),
                                          style: TextStyle(fontSize: 12, color: fg2, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 8),
                            _VolumeControl(color: fg2),
                          ] else
                            IconBtn(Icons.queue_music_rounded, color: fg2, onTap: onQueue),
                          const SizedBox(width: 20),
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
          width: 50,
          height: 50,
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
                  size: 30,
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

class _VolumeControl extends StatelessWidget {
  const _VolumeControl({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final app = AppState.I;
    return ValueListenableBuilder(
      valueListenable: app.volume,
      builder: (context, v, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconBtn(
            v == 0 ? Icons.volume_off_rounded : (v < 0.5 ? Icons.volume_down_rounded : Icons.volume_up_rounded),
            color: color,
            tooltip: '静音',
            onTap: () => app.setVolume(v == 0 ? 0.6 : 0),
          ),
          SizedBox(
            width: 96,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape: SliderComponentShape.noOverlay,
                activeTrackColor: Tokens.accent,
                inactiveTrackColor: color.withValues(alpha: 0.25),
                thumbColor: Tokens.accent,
              ),
              child: Slider(value: v, onChanged: app.setVolume),
            ),
          ),
        ],
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
                    final track = widget.dark ? Colors.white12 : p.divider;
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
                              color: track.withValues(alpha: 0.9),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: played,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              height: h,
                              color: widget.dark ? Colors.white70 : Tokens.accent,
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

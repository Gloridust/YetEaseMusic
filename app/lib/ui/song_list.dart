import 'package:flutter/material.dart';

import '../src/rust/api/types.dart';
import '../state.dart';
import '../theme.dart';
import 'pages/album_page.dart';
import 'song_actions.dart';
import 'widgets.dart';

const _rowHeight = 54.0;

/// 列表表头：# / 标题 / 专辑 / 喜欢 / 时长
class SongListHeader extends StatelessWidget {
  const SongListHeader({super.key, this.lastLabel = '时长'});

  /// 最后一列的标题（最近播放页显示「播放时间」）
  final String lastLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final style = TextStyle(color: p.textTertiary, fontSize: 13);
    return Container(
      height: 36,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.divider)),
      ),
      child: _Columns(
        index: Text('#', style: style, textAlign: TextAlign.center),
        title: Text('标题', style: style),
        album: Text('专辑', style: style),
        like: Text('喜欢', style: style, textAlign: TextAlign.center),
        duration: Text(lastLabel, style: style),
      ),
    );
  }
}

/// 列宽在这里统一定义，表头与行保持对齐；窄屏时隐藏专辑列
class _Columns extends StatelessWidget {
  const _Columns({
    required this.index,
    required this.title,
    required this.album,
    required this.like,
    required this.duration,
  });

  final Widget index, title, album, like, duration;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth > 640;
        return Row(
          children: [
            SizedBox(width: 46, child: index),
            Expanded(flex: 5, child: title),
            if (wide) ...[const SizedBox(width: 16), Expanded(flex: 3, child: album)],
            SizedBox(width: 56, child: like),
            SizedBox(width: 72, child: duration),
          ],
        );
      },
    );
  }
}

class SliverSongList extends StatelessWidget {
  const SliverSongList({super.key, required this.songs, this.lastColumn});

  final List<SongItem> songs;

  /// 替换最后一列（默认显示时长）
  final List<String>? lastColumn;

  @override
  Widget build(BuildContext context) {
    return SliverFixedExtentList(
      itemExtent: _rowHeight,
      delegate: SliverChildBuilderDelegate(
        (context, i) => SongRow(songs: songs, index: i, lastText: lastColumn?[i]),
        childCount: songs.length,
      ),
    );
  }
}

class SongRow extends StatelessWidget {
  const SongRow({super.key, required this.songs, required this.index, this.lastText});

  final List<SongItem> songs;
  final int index;
  final String? lastText;

  SongItem get song => songs[index];

  void _play() => AppState.I.playSongs(songs, index);

  void _menu(BuildContext context, Offset at) => showSongMenu(context, at, songs, index);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final app = AppState.I;
    // 触屏设备单击即播放，桌面端双击播放
    final touch = Theme.of(context).platform == TargetPlatform.android;
    return ValueListenableBuilder(
      valueListenable: app.current,
      builder: (context, cur, _) {
        final playing = cur?.id == song.id;
        final titleColor = playing ? Tokens.accent : p.textPrimary;
        return GestureDetector(
          onSecondaryTapDown: (d) => _menu(context, d.globalPosition),
          onLongPressStart: (d) => _menu(context, d.globalPosition),
          child: Hover(
            onTap: touch ? _play : null,
            onDoubleTap: touch ? null : _play,
            builder: (context, h) => AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              decoration: BoxDecoration(
                color: h ? p.hover.withValues(alpha: 0.7) : Colors.transparent,
                borderRadius: BorderRadius.circular(Tokens.radiusM),
              ),
              child: _Columns(
                index: Center(
                  child: playing
                      ? const _PlayingBars()
                      : h
                      ? IconBtn(Icons.play_arrow_rounded, onTap: _play, size: 20, box: 28)
                      : Text(
                          (index + 1).toString().padLeft(2, '0'),
                          style: TextStyle(
                            color: p.textTertiary,
                            fontSize: 13,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                ),
                title: Row(
                  children: [
                    Cover(url: song.coverUrl, size: 38, radius: Tokens.radiusS),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: song.name,
                                  style: TextStyle(color: titleColor, fontSize: 14),
                                ),
                                if (song.subtitle != null)
                                  TextSpan(
                                    text: '  ${song.subtitle}',
                                    style: TextStyle(color: p.textTertiary, fontSize: 13),
                                  ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              if (song.vip) const Tag('VIP'),
                              Flexible(
                                child: ArtistLinks(
                                  artists: song.artists,
                                  style: TextStyle(color: playing ? Tokens.accent : p.textSecondary, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                album: Align(
                  alignment: Alignment.centerLeft,
                  child: LinkText(
                    song.albumName,
                    style: TextStyle(color: p.textSecondary, fontSize: 13),
                    onTap: song.local || song.albumId <= 0 ? null : () => openAlbum(song.albumId),
                  ),
                ),
                like: Center(child: LikeButton(song: song)),
                duration: Text(
                  lastText ?? formatMs(song.durationMs),
                  style: TextStyle(color: p.textTertiary, fontSize: 13),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class LikeButton extends StatelessWidget {
  const LikeButton({super.key, required this.song, this.size = 20, this.color});

  final SongItem song;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (song.local) return SizedBox(width: size + 12);
    return ValueListenableBuilder(
      valueListenable: AppState.I.likedIds,
      builder: (context, liked, _) {
        final on = liked.contains(song.id);
        return IconBtn(
          on ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          size: size,
          box: size + 12,
          color: on ? Tokens.accent : color,
          tooltip: on ? '取消喜欢' : '喜欢',
          onTap: () => AppState.I.toggleLike(song),
        );
      },
    );
  }
}

/// 正在播放的跳动音柱
class _PlayingBars extends StatefulWidget {
  const _PlayingBars();

  @override
  State<_PlayingBars> createState() => _PlayingBarsState();
}

class _PlayingBarsState extends State<_PlayingBars> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    AppState.I.playerState.addListener(_sync);
    _sync();
  }

  void _sync() => AppState.I.isPlaying ? _c.repeat() : _c.stop();

  @override
  void dispose() {
    AppState.I.playerState.removeListener(_sync);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final phase in [0.0, 0.4, 0.75])
            Container(
              width: 3,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              height: 5 + 11 * (0.5 + 0.5 * _wave(_c.value + phase)),
              decoration: BoxDecoration(color: Tokens.accent, borderRadius: BorderRadius.circular(1.5)),
            ),
        ],
      ),
    );
  }

  double _wave(double t) {
    final x = (t % 1.0) * 2 - 1;
    return 1 - 2 * x.abs();
  }
}

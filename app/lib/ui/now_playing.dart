import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../src/rust/api/playback.dart' as pb;
import '../src/rust/api/types.dart';
import '../state.dart';
import '../theme.dart';
import 'player_bar.dart';
import 'shell.dart';
import 'widgets.dart';

/// 全屏播放页：封面取色的深色渐变背景 + 黑胶唱片 + 滚动歌词
class NowPlaying extends StatelessWidget {
  const NowPlaying({super.key, required this.onQueue});

  final VoidCallback onQueue;

  @override
  Widget build(BuildContext context) {
    final app = AppState.I;
    return ValueListenableBuilder(
      valueListenable: app.current,
      builder: (context, song, _) => _Backdrop(
        url: song?.coverUrl,
        child: Column(
          children: [
            WindowDragArea(
              child: SizedBox(
                height: 72,
                child: Row(
                  children: [
                    const SizedBox(width: 24),
                    IconBtn(
                      Icons.keyboard_arrow_down_rounded,
                      size: 30,
                      color: Colors.white70,
                      tooltip: '收起',
                      onTap: () => app.nowPlayingOpen.value = false,
                    ),
                    const Spacer(),
                    if (isDesktop) const WindowButtons(color: Colors.white70),
                    const SizedBox(width: 16),
                  ],
                ),
              ),
            ),
            Expanded(
              child: song == null
                  ? const Center(
                      child: Text('没有正在播放的歌曲', style: TextStyle(color: Colors.white54, fontSize: 16)),
                    )
                  : LayoutBuilder(
                      builder: (context, c) {
                        final wide = c.maxWidth > 900;
                        final disc = math
                            .min(c.maxHeight * 0.78, wide ? c.maxWidth * 0.36 : c.maxWidth * 0.7)
                            .clamp(200.0, 560.0);
                        if (!wide) {
                          return Column(
                            children: [
                              Expanded(
                                flex: 5,
                                child: Center(
                                  child: Vinyl(song: song, size: disc * 0.8),
                                ),
                              ),
                              _SongInfo(song: song),
                              Expanded(flex: 4, child: LyricsView(songId: song.id)),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: Center(
                                child: Vinyl(song: song, size: disc),
                              ),
                            ),
                            Expanded(
                              flex: 5,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 72, top: 24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _SongInfo(song: song),
                                    const SizedBox(height: 28),
                                    Expanded(child: LyricsView(songId: song.id)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
            PlayerBar(dark: true, onQueue: onQueue),
          ],
        ),
      ),
    );
  }
}

class _SongInfo extends StatelessWidget {
  const _SongInfo({required this.song});

  final SongItem song;

  @override
  Widget build(BuildContext context) {
    const meta = TextStyle(color: Colors.white60, fontSize: 14);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          song.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700, height: 1.25),
        ),
        if (song.subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            song.subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white54, fontSize: 15),
          ),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 24,
          runSpacing: 4,
          children: [
            Text('专辑：${song.albumName}', style: meta),
            Text('歌手：${song.artists.map((a) => a.name).join(' / ')}', style: meta),
          ],
        ),
      ],
    );
  }
}

/// 背景：从封面取主色压暗做渐变，叠一层大半径模糊的封面
class _Backdrop extends StatefulWidget {
  const _Backdrop({required this.url, required this.child});

  final String? url;
  final Widget child;

  @override
  State<_Backdrop> createState() => _BackdropState();
}

class _BackdropState extends State<_Backdrop> {
  Color _base = const Color(0xFF26323A);

  @override
  void initState() {
    super.initState();
    _extract();
  }

  @override
  void didUpdateWidget(covariant _Backdrop old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) _extract();
  }

  Future<void> _extract() async {
    final src = sizedImage(widget.url, 64);
    if (src == null) return;
    try {
      final scheme = await ColorScheme.fromImageProvider(provider: NetworkImage(src), brightness: Brightness.dark);
      final hsl = HSLColor.fromColor(scheme.primaryContainer);
      final c = hsl
          .withLightness(hsl.lightness.clamp(0.16, 0.24))
          .withSaturation(hsl.saturation.clamp(0.0, 0.45))
          .toColor();
      if (mounted) setState(() => _base = c);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final cover = sizedImage(widget.url, 128);
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: _base),
      duration: const Duration(milliseconds: 800),
      builder: (context, c, child) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [c!, Color.lerp(c, Colors.black, 0.55)!],
          ),
        ),
        child: child,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (cover != null)
            Opacity(
              opacity: 0.28,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 90, sigmaY: 90, tileMode: TileMode.decal),
                child: Image.network(
                  cover,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          widget.child,
        ],
      ),
    );
  }
}

/// 黑胶唱片 + 唱臂。播放时唱片旋转、唱臂落下
class Vinyl extends StatefulWidget {
  const Vinyl({super.key, required this.song, required this.size});

  final SongItem song;
  final double size;

  @override
  State<Vinyl> createState() => _VinylState();
}

class _VinylState extends State<Vinyl> with SingleTickerProviderStateMixin {
  late final _spin = AnimationController(vsync: this, duration: const Duration(seconds: 24));

  @override
  void initState() {
    super.initState();
    AppState.I.playerState.addListener(_sync);
    AppState.I.nowPlayingOpen.addListener(_sync);
    _sync();
  }

  // 播放页收起时停掉动画，不白耗 GPU
  void _sync() => AppState.I.isPlaying && AppState.I.nowPlayingOpen.value ? _spin.repeat() : _spin.stop();

  @override
  void dispose() {
    AppState.I.playerState.removeListener(_sync);
    AppState.I.nowPlayingOpen.removeListener(_sync);
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s * 1.1,
      height: s * 1.25,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: s * 0.05,
            top: s * 0.25,
            // Impeller 的 GLES 后端画"圆形 + 渐变/阴影"装饰时会退化成方块，所以一律用 ClipOval 裁剪
            child: ClipOval(
              child: Container(
                width: s,
                height: s,
                color: Colors.white.withValues(alpha: 0.08),
                padding: EdgeInsets.all(s * 0.035),
                child: ClipOval(
                  child: RotationTransition(
                    turns: _spin,
                    child: CustomPaint(
                      painter: _GroovePainter(),
                      child: Center(
                        child: ClipOval(
                          child: Cover(url: widget.song.coverUrl, size: s * 0.62, radius: 0),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 唱臂支点在唱片左上方
          Positioned(
            left: s * 0.05 + s * 0.5 - s * 0.03,
            top: 0,
            child: ValueListenableBuilder(
              valueListenable: AppState.I.playerState,
              builder: (context, st, _) => AnimatedRotation(
                turns: st == PlayerState.playing ? 0 : -0.07,
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeInOutCubic,
                alignment: Alignment.topLeft,
                child: CustomPaint(size: Size(s * 0.35, s * 0.55), painter: _ArmPainter()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroovePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF1A1A1A), Color(0xFF0D0D0D), Color(0xFF222222)],
          stops: [0.0, 0.85, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = Colors.white.withValues(alpha: 0.05);
    for (var rr = r * 0.66; rr < r * 0.97; rr += r * 0.022) {
      canvas.drawCircle(c, rr, groove);
    }
    // 反光
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = SweepGradient(
          colors: [
            Colors.transparent,
            Colors.white.withValues(alpha: 0.07),
            Colors.transparent,
            Colors.white.withValues(alpha: 0.05),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ArmPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final pivot = Offset(w * 0.09, w * 0.09);
    final arm = Paint()
      ..color = const Color(0xFFE8E8E8)
      ..strokeWidth = w * 0.045
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(pivot.dx, pivot.dy)
      ..lineTo(pivot.dx + w * 0.02, h * 0.5)
      ..quadraticBezierTo(pivot.dx + w * 0.05, h * 0.68, w * 0.62, h * 0.86);
    canvas.drawPath(path, arm);
    // 唱头
    canvas.save();
    canvas.translate(w * 0.66, h * 0.88);
    canvas.rotate(-0.6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: w * 0.2, height: w * 0.13),
        Radius.circular(w * 0.03),
      ),
      Paint()..color = const Color(0xFFF5F5F5),
    );
    canvas.restore();
    // 支点
    canvas.drawCircle(pivot, w * 0.09, Paint()..color = const Color(0xFFDDDDDD));
    canvas.drawCircle(pivot, w * 0.04, Paint()..color = const Color(0xFFAAAAAA));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 逐行滚动歌词，点击某行跳转
class LyricsView extends StatefulWidget {
  const LyricsView({super.key, required this.songId});

  final int songId;

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  List<LyricItem>? _lines;
  Object? _error;
  int _current = -1;
  List<GlobalKey> _keys = const [];
  final _scroll = ScrollController();
  DateTime _userScrolledAt = DateTime(0);

  @override
  void initState() {
    super.initState();
    _load();
    AppState.I.position.addListener(_onPosition);
  }

  @override
  void didUpdateWidget(covariant LyricsView old) {
    super.didUpdateWidget(old);
    if (old.songId != widget.songId) _load();
  }

  @override
  void dispose() {
    AppState.I.position.removeListener(_onPosition);
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _lines = null;
      _error = null;
      _current = -1;
    });
    final id = widget.songId;
    try {
      final l = (await pb.lyrics(songId: id)).where((x) => x.text.trim().isNotEmpty).toList();
      if (!mounted || id != widget.songId) return;
      setState(() {
        _lines = l;
        _keys = List.generate(l.length, (_) => GlobalKey());
      });
      if (_scroll.hasClients) _scroll.jumpTo(0);
      _onPosition();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _onPosition() {
    final l = _lines;
    if (l == null || l.isEmpty) return;
    final pos = AppState.I.position.value + 300; // 略微提前，视觉上更跟手
    var i = l.lastIndexWhere((x) => x.timeMs <= pos);
    if (i == _current) return;
    setState(() => _current = i);
    // 用户刚手动滚过就暂不自动跟随
    if (DateTime.now().difference(_userScrolledAt) < const Duration(seconds: 3)) return;
    if (i < 0) i = 0;
    final ctx = _keys[i].currentContext;
    if (ctx != null && AppState.I.nowPlayingOpen.value) {
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.4,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return const _LyricHint('歌词加载失败');
    final l = _lines;
    if (l == null) return const SizedBox.shrink();
    if (l.isEmpty) return const _LyricHint('纯音乐，请欣赏');
    return ShaderMask(
      shaderCallback: (r) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
        stops: [0, 0.12, 0.85, 1],
      ).createShader(r),
      blendMode: BlendMode.dstIn,
      child: NotificationListener<UserScrollNotification>(
        onNotification: (_) {
          _userScrolledAt = DateTime.now();
          return false;
        },
        child: SingleChildScrollView(
          controller: _scroll,
          padding: EdgeInsets.symmetric(vertical: MediaQuery.sizeOf(context).height * 0.2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (var i = 0; i < l.length; i++) _line(i, l[i])],
          ),
        ),
      ),
    );
  }

  Widget _line(int i, LyricItem line) {
    final active = i == _current;
    return Hover(
      key: _keys[i],
      onTap: () => pb.seek(positionMs: line.timeMs),
      builder: (_, h) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: h ? Colors.white.withValues(alpha: 0.06) : Colors.transparent,
          borderRadius: BorderRadius.circular(Tokens.radiusM),
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
          style: TextStyle(
            color: active ? Colors.white : Colors.white.withValues(alpha: 0.38),
            fontSize: active ? 26 : 21,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            height: 1.35,
            fontFamilyFallback: Theme.of(context).textTheme.bodyMedium?.fontFamilyFallback,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(line.text),
              if (line.translation != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    line.translation!,
                    style: TextStyle(fontSize: active ? 17 : 15, fontWeight: FontWeight.w400),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LyricHint extends StatelessWidget {
  const _LyricHint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(text, style: const TextStyle(color: Colors.white54, fontSize: 18)),
  );
}

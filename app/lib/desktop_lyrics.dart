import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:window_manager/window_manager.dart';

import 'src/rust/api/desktop_lyrics.dart' as dl;
import 'src/rust/api/types.dart';
import 'src/rust/frb_generated.dart';
import 'theme.dart';

/// 桌面歌词窗口的入口：主程序以 `--desktop-lyrics --port=N` 启动本程序时走这里。
Future<void> runDesktopLyrics(List<String> args) async {
  final port = int.tryParse(args.firstWhere((a) => a.startsWith('--port='), orElse: () => '--port=0').substring(7));
  await RustLib.init();
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      size: Size(880, 150),
      minimumSize: Size(360, 110),
      backgroundColor: Colors.transparent,
      skipTaskbar: true,
      alwaysOnTop: true,
      titleBarStyle: TitleBarStyle.hidden,
      title: '桌面歌词',
    ),
    () async {
      await windowManager.setAsFrameless();
      await windowManager.setAlignment(Alignment.bottomCenter);
      await windowManager.show();
    },
  );
  runApp(_LyricsApp(port: port ?? 0));
  _maybeShot();
}

final _shotKey = GlobalKey();

/// 开发用：继承了 YETEASE_TOUR 时，7 秒后截一张歌词窗口的图
Future<void> _maybeShot() async {
  final dir = Platform.environment['YETEASE_TOUR'];
  if (dir == null) return;
  await Future.delayed(const Duration(seconds: 7));
  final b = _shotKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (b == null) return;
  final img = await b.toImage(pixelRatio: 1.5);
  final png = await img.toByteData(format: ui.ImageByteFormat.png);
  await File('$dir/desktop-lyrics.png').writeAsBytes(png!.buffer.asUint8List());
}

class _LyricsApp extends StatelessWidget {
  const _LyricsApp({required this.port});

  final int port;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.dark).copyWith(scaffoldBackgroundColor: Colors.transparent),
      color: Colors.transparent,
      builder: (context, child) {
        // 桌面歌词有自己的字号设置，窗口大小也按它计算，不再叠加系统文字缩放
        final mq = MediaQuery.of(context);
        return MediaQuery(data: mq.copyWith(textScaler: TextScaler.noScaling), child: child!);
      },
      // 必须包一层 Material，否则文字没有默认样式（会显示黄色下划线和等宽字体）
      home: RepaintBoundary(
        key: _shotKey,
        child: Material(
          type: MaterialType.transparency,
          child: _LyricsWindow(port: port),
        ),
      ),
    );
  }
}

class _LyricsWindow extends StatefulWidget {
  const _LyricsWindow({required this.port});

  final int port;

  @override
  State<_LyricsWindow> createState() => _LyricsWindowState();
}

class _LyricsWindowState extends State<_LyricsWindow> with SingleTickerProviderStateMixin {
  List<LyricItem> _lines = const [];
  String _title = '';
  int _posMs = 0;
  bool _playing = false;
  DateTime _posAt = DateTime.now();
  bool _hover = false;
  bool _locked = false;
  double _fontSize = 30;
  late final Ticker _ticker = createTicker((_) => setState(() {}));

  @override
  void initState() {
    super.initState();
    dl.desktopLyricsConnect(port: widget.port).listen((e) {
      switch (e) {
        case dl.DesktopLyricsEvent_Track(:final title, :final artist, :final lines):
          setState(() {
            _lines = lines;
            _title = '$title - $artist';
          });
        case dl.DesktopLyricsEvent_Position(:final ms, :final playing):
          _posMs = ms;
          _playing = playing;
          _posAt = DateTime.now();
        case dl.DesktopLyricsEvent_Closed():
          exit(0);
      }
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  /// 主程序每 120ms 推一次进度，中间按流逝时间插值，逐字高亮才顺滑
  int get _now => _playing ? _posMs + DateTime.now().difference(_posAt).inMilliseconds : _posMs;

  @override
  Widget build(BuildContext context) {
    final now = _now;
    final idx = _lines.lastIndexWhere((l) => l.timeMs <= now + 200);
    final cur = idx >= 0 ? _lines[idx] : null;
    final second = cur?.translation ?? (idx + 1 < _lines.length ? _lines[idx + 1].text : null);
    final showChrome = _hover && !_locked;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: _locked ? null : (_) => windowManager.startDragging(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: showChrome ? Colors.black.withValues(alpha: 0.45) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
          child: Column(
            children: [
              SizedBox(height: 30, child: _hover ? _toolbar() : const SizedBox.shrink()),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _KaraokeText(
                      line: cur,
                      fallback: _title.isEmpty ? '网易云音乐Yet' : _title,
                      nowMs: now,
                      fontSize: _fontSize,
                    ),
                    if (second != null && second.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: _Outlined(
                          second,
                          fontSize: _fontSize * 0.62,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolbar() {
    Widget btn(IconData i, String tip, VoidCallback onTap) => Tooltip(
      message: tip,
      child: InkResponse(
        onTap: onTap,
        radius: 16,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(i, size: 18, color: Colors.white70),
        ),
      ),
    );
    if (_locked) {
      return Center(child: btn(Icons.lock_rounded, '解锁', () => setState(() => _locked = false)));
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        btn(Icons.skip_previous_rounded, '上一首', () => dl.desktopLyricsCommand(cmd: 'prev')),
        btn(
          _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
          '播放 / 暂停',
          () => dl.desktopLyricsCommand(cmd: 'toggle'),
        ),
        btn(Icons.skip_next_rounded, '下一首', () => dl.desktopLyricsCommand(cmd: 'next')),
        const SizedBox(width: 12),
        btn(Icons.text_decrease_rounded, '字号减小', () => setState(() => _fontSize = (_fontSize - 2).clamp(18, 56))),
        btn(Icons.text_increase_rounded, '字号增大', () => setState(() => _fontSize = (_fontSize + 2).clamp(18, 56))),
        btn(Icons.lock_open_rounded, '锁定（隐藏控件、不可拖动）', () => setState(() => _locked = true)),
        const SizedBox(width: 12),
        btn(Icons.close_rounded, '关闭桌面歌词', () => exit(0)),
      ],
    );
  }
}

/// 带描边的文字：在任何壁纸上都看得清
class _Outlined extends StatelessWidget {
  const _Outlined(this.text, {required this.fontSize, this.color = Colors.white});

  final String text;
  final double fontSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700, height: 1.25);
    return Stack(
      children: [
        Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: base.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = fontSize / 9
              ..color = Colors.black.withValues(alpha: 0.55),
          ),
        ),
        Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: base.copyWith(color: color),
        ),
      ],
    );
  }
}

/// 当前行：有逐字时间轴时按字从左到右填充品牌红，否则整行按行进度填充
class _KaraokeText extends StatelessWidget {
  const _KaraokeText({required this.line, required this.fallback, required this.nowMs, required this.fontSize});

  final LyricItem? line;
  final String fallback;
  final int nowMs;
  final double fontSize;

  double _progress(LyricItem l) {
    if (l.words.isEmpty) {
      if (l.durationMs <= 0) return 1;
      return ((nowMs - l.timeMs) / l.durationMs).clamp(0.0, 1.0);
    }
    // 按字数累计：已唱完的字 + 当前字的部分
    var done = 0.0;
    for (final w in l.words) {
      if (nowMs >= w.startMs + w.durationMs) {
        done += w.text.length;
      } else if (nowMs > w.startMs && w.durationMs > 0) {
        done += w.text.length * (nowMs - w.startMs) / w.durationMs;
        break;
      } else {
        break;
      }
    }
    final total = l.words.fold<int>(0, (a, w) => a + w.text.length);
    return total == 0 ? 1 : (done / total).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final l = line;
    if (l == null) return _Outlined(fallback, fontSize: fontSize * 0.8);
    final f = _progress(l);
    return Stack(
      children: [
        _Outlined(l.text, fontSize: fontSize),
        ClipRect(
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: f,
            child: _Outlined(l.text, fontSize: fontSize, color: const Color(0xFFFF4E5B)),
          ),
        ),
      ],
    );
  }
}

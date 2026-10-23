import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:window_manager/window_manager.dart';

import 'src/rust/api/library.dart' as lib;
import 'state.dart';
import 'ui/brand.dart';
import 'ui/login_dialog.dart';
import 'ui/nav.dart';
import 'ui/pages/downloads_page.dart';
import 'ui/pages/follows_page.dart';
import 'ui/pages/home_page.dart';
import 'ui/pages/local_page.dart';
import 'ui/pages/podcast_page.dart';
import 'ui/pages/recent_page.dart';
import 'ui/pages/playlist_page.dart';
import 'ui/pages/search_page.dart';
import 'ui/pages/settings_page.dart';

/// 开发用：设置 YETEASE_TOUR=<输出目录> 后自动走一遍主要页面并截图（界面回归检查、README 配图）。
final tourBoundary = GlobalKey();

/// 开发用：设置 YETEASE_EXPORT_ICONS=<目录> 后把应用图标导出成各尺寸 PNG 并退出
Future<void> maybeExportIcons() async {
  final dir = Platform.environment['YETEASE_EXPORT_ICONS'];
  if (dir == null) return;
  for (final size in const [16, 24, 32, 48, 64, 72, 96, 128, 144, 192, 256, 512, 1024]) {
    final rec = ui.PictureRecorder();
    const LogoPainter().paint(Canvas(rec), Size.square(size.toDouble()));
    final img = await rec.endRecording().toImage(size, size);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    await File('$dir/icon-$size.png').writeAsBytes(png!.buffer.asUint8List());
  }
  debugPrint('icons exported');
  exit(0);
}

Future<void> maybeRunTour() async {
  final dir = Platform.environment['YETEASE_TOUR'];
  if (dir == null) return;
  Future<void> wait(num s) => Future.delayed(Duration(milliseconds: (s * 1000).round()));
  Future<void> shot(String name) async {
    await WidgetsBinding.instance.endOfFrame;
    final b = tourBoundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: double.tryParse(Platform.environment['YETEASE_TOUR_DPR'] ?? '') ?? 1);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    await File('$dir/$name.png').writeAsBytes(png!.buffer.asUint8List());
    debugPrint('tour: $name');
  }

  final app = AppState.I;
  // 只巡览侧边栏各页面（不播放），用于检查新页面
  if (Platform.environment['YETEASE_TOUR_PAGES'] != null) {
    await wait(5);
    await shot('p-home');
    for (final (name, page) in [
      ('podcast', const PodcastPage()),
      ('follows', const FollowsPage()),
      ('recent', const RecentPage()),
      ('downloads', const DownloadsPage()),
      ('local', const LocalMusicPage()),
    ]) {
      Nav.root(name, page);
      await wait(6);
      await shot('p-$name');
    }
    debugPrint('tour: done');
    return;
  }
  final vol = app.volume.value;
  final theme = app.themeMode.value;
  app.themeMode.value = ThemeMode.light;
  app.setVolume(0.08);
  await wait(6);
  await shot('home');

  final lists = await lib.recommendPlaylists(limit: 6);
  Nav.push('playlist:${lists[1].id}', PlaylistPage(id: lists[1].id));
  await wait(15);
  await shot('playlist');

  Nav.push('search:陈奕迅', const SearchPage(keywords: '陈奕迅'));
  await wait(5);
  await shot('search');

  final (songs, _) = await lib.searchSongs(
    keywords: Platform.environment['YETEASE_TOUR_SONG'] ?? '晴天',
    offset: 0,
    limit: 1,
  );
  await app.playSongs(songs, 0);
  await wait(14);
  app.nowPlayingOpen.value = true;
  await wait(5);
  await shot('now-playing');
  app.nowPlayingOpen.value = false;
  await wait(1);

  app.themeMode.value = ThemeMode.dark;
  Nav.back();
  await wait(3);
  await shot('playlist-dark');
  app.themeMode.value = ThemeMode.light;

  Nav.root('settings', const SettingsPage());
  await wait(2);
  await shot('settings');

  // 窄窗口（接近手机 / 车机竖屏）下的自适应布局
  Nav.root('home', const HomePage());
  final size = await windowManager.getSize();
  final maximized = await windowManager.isMaximized();
  if (maximized) await windowManager.unmaximize();
  await windowManager.setSize(const Size(440, 720));
  await wait(8);
  await shot('compact');
  await windowManager.setSize(size);
  if (maximized) await windowManager.maximize();
  await wait(1);

  showLoginDialog(Nav.key.currentContext!);
  await wait(3);
  await shot('login');
  Nav.key.currentState?.pop();

  app.themeMode.value = theme;
  app.setVolume(vol);
  await app.pauseIfPlaying();
  debugPrint('tour: done');
}

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:window_manager/window_manager.dart';

import 'src/rust/api/library.dart' as lib;
import 'state.dart';
import 'ui/login_dialog.dart';
import 'ui/nav.dart';
import 'ui/pages/home_page.dart';
import 'ui/pages/playlist_page.dart';
import 'ui/pages/search_page.dart';
import 'ui/pages/settings_page.dart';

/// 开发用：设置 YETEASE_TOUR=<输出目录> 后自动走一遍主要页面并截图（界面回归检查、README 配图）。
final tourBoundary = GlobalKey();

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

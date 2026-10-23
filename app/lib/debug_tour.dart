import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'src/rust/api/library.dart' as lib;
import 'src/rust/api/playback.dart' as pb;
import 'state.dart';
import 'ui/nav.dart';
import 'ui/pages/search_page.dart';
import 'ui/pages/settings_page.dart';

/// 开发用：设置 YETEASE_TOUR=<输出目录> 后自动走一遍主要页面并截图，用于界面回归检查。
final tourBoundary = GlobalKey();

Future<void> maybeRunTour() async {
  final dir = Platform.environment['YETEASE_TOUR'];
  if (dir == null) return;
  Future<void> wait(int s) => Future.delayed(Duration(seconds: s));
  Future<void> shot(String name) async {
    await WidgetsBinding.instance.endOfFrame;
    final b = tourBoundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: 1);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    await File('$dir/$name.png').writeAsBytes(png!.buffer.asUint8List());
    final snap = await pb.snapshot();
    final st = await pb.getSettings();
    debugPrint('tour: $name ui=${AppState.I.volume.value} player=${snap.volume} settings=${st.volume}');
  }

  final app = AppState.I;
  final vol = app.volume.value;
  app.setVolume(0.08);
  await wait(6);
  await shot('1-home');
  Nav.push('search:周杰伦', const SearchPage(keywords: '周杰伦'));
  await wait(5);
  await shot('2-search');
  final (songs, _) = await lib.searchSongs(keywords: '晴天 周杰伦', offset: 0, limit: 5);
  await app.playSongs(songs, 0);
  await wait(8);
  await shot('3-playing');
  app.nowPlayingOpen.value = true;
  await wait(4);
  await shot('4-now-playing');
  app.nowPlayingOpen.value = false;
  Nav.root('settings', const SettingsPage());
  await wait(2);
  await shot('5-settings');
  app.themeMode.value = ThemeMode.dark;
  Nav.back();
  await wait(2);
  await shot('6-dark');
  app.themeMode.value = ThemeMode.light;
  app.setVolume(vol);
  await app.pauseIfPlaying();
  debugPrint('tour: done');
}

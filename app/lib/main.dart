import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart' show Int64List;
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

import 'android_media.dart';
import 'debug_tour.dart';
import 'desktop_lyrics.dart';
import 'src/rust/api/playback.dart' as pb;
import 'src/rust/frb_generated.dart';
import 'state.dart';
import 'theme.dart';
import 'ui/brand.dart';
import 'ui/shell.dart';
import 'ui/ui_scaled.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  // 安卓的启动参数经 initialRoute 传入（见 MainActivity.getInitialRoute）
  final route = PlatformDispatcher.instance.defaultRouteName;
  if (args.isEmpty && route.startsWith('/?')) args = Uri.parse(route).queryParametersAll['arg'] ?? const [];
  // 桌面歌词是同一个程序的另一个进程，只显示歌词，不启动播放内核
  if (args.contains('--desktop-lyrics')) return runDesktopLyrics(args);
  await maybeExportIcons();
  await RustLib.init();
  // 未捕获的异常写进日志文件，方便导出反馈
  FlutterError.onError = (d) {
    FlutterError.presentError(d);
    pb.logMessage(level: 'error', message: '${d.exceptionAsString()}\n${d.stack}');
  };
  PlatformDispatcher.instance.onError = (e, st) {
    pb.logMessage(level: 'error', message: '$e\n$st');
    return false;
  };
  // 开发用：YETEASE_DATA_DIR 指向独立目录即可得到一个全新的未登录环境
  var dataDir = Platform.environment['YETEASE_DATA_DIR'];
  String? cacheDir = dataDir == null ? null : '$dataDir/cache';
  // 移动端没有桌面那套标准目录，由系统提供应用私有目录
  if (Platform.isAndroid || Platform.isIOS) {
    dataDir ??= (await getApplicationSupportDirectory()).path;
    cacheDir ??= (await getApplicationCacheDirectory()).path;
  }
  await pb.bootstrap(dataDir: dataDir, cacheDir: cacheDir);

  if (isDesktop) {
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      WindowOptions(
        size: Size(1280, 840),
        minimumSize: Size(420, 560),
        center: true,
        title: kAppName,
        titleBarStyle: TitleBarStyle.hidden,
      ),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }

  await AppState.I.start();
  if (Platform.isAndroid) await initAndroidMedia();
  // 测试用：--autoplay=<歌曲 id> 启动后直接播放（安卓经 Intent 的 yetease_args 传入）
  final autoplay = args.where((a) => a.startsWith('--autoplay=')).map((a) => int.tryParse(a.substring(11))).firstOrNull;
  if (autoplay != null) {
    pb.playSongs(ids: Int64List.fromList([autoplay]), index: 0).ignore();
  }
  if (isDesktop) {
    // 媒体控件里点击「打开播放器」时把窗口带到前台
    AppState.I.raiseRequests.addListener(() async {
      await windowManager.show();
      await windowManager.focus();
    });
    // 关闭窗口时按设置留在托盘（macOS 留在程序坞）继续播放，否则退出
    await windowManager.setPreventClose(true);
    windowManager.addListener(_CloseToTray());
    AppState.I.quitRequests.addListener(quitApp);
    pb.enableTray().then((ok) => AppState.I.trayAvailable.value = ok).ignore();
    // Linux 的 MPRIS 由内核自动启用；Windows 需要窗口句柄，macOS 不需要
    if (Platform.isWindows) {
      pb.enableMediaControls(hwnd: await windowManager.getId()).ignore();
    } else if (Platform.isMacOS) {
      pb.enableMediaControls().ignore();
    }
  }
  runApp(const YetEaseApp());
  maybeRunTour();
}

/// 真正退出：先关掉桌面歌词进程，再销毁主窗口
Future<void> quitApp() async {
  AppState.I.stopDesktopLyrics();
  await windowManager.setPreventClose(false);
  await windowManager.destroy();
}

class _CloseToTray with WindowListener {
  @override
  void onWindowClose() async {
    final app = AppState.I;
    final canHide = app.trayAvailable.value || Platform.isMacOS;
    if (canHide && (app.settings.value?.closeToTray ?? true)) {
      await windowManager.hide();
    } else {
      await quitApp();
    }
  }
}

class YetEaseApp extends StatelessWidget {
  const YetEaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppState.I;
    return ListenableBuilder(
      listenable: Listenable.merge([app.themeMode, app.uiScale]),
      builder: (context, _) => MaterialApp(
        title: kAppName,
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: app.themeMode.value,
        shortcuts: {
          ...WidgetsApp.defaultShortcuts,
          const SingleActivator(LogicalKeyboardKey.space): const _ToggleIntent(),
        },
        actions: {
          ...WidgetsApp.defaultActions,
          _ToggleIntent: CallbackAction<_ToggleIntent>(onInvoke: (_) => pb.toggle()),
        },
        // 缩放包在 Navigator 外层，弹窗、抽屉、提示条也一起缩放
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            // 限制系统文字缩放，避免 4K@200% + 200% 文字时字号叠成 4 倍
            data: isDesktop ? mq.copyWith(textScaler: clampDesktopTextScaler(mq.textScaler)) : mq,
            child: RepaintBoundary(
              key: tourBoundary,
              child: UiScaled(scale: app.uiScale.value, child: child!),
            ),
          );
        },
        initialRoute: '/',
        home: const Shell(),
      ),
    );
  }
}

/// 空格键播放/暂停（输入框聚焦时由输入框自己处理空格）
class _ToggleIntent extends Intent {
  const _ToggleIntent();
}

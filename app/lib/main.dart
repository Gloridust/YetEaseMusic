import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

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
  if (isDesktop) {
    // 媒体控件里点击「打开播放器」时把窗口带到前台
    AppState.I.raiseRequests.addListener(() async {
      await windowManager.show();
      await windowManager.focus();
    });
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
        builder: (context, child) => RepaintBoundary(
          key: tourBoundary,
          child: UiScaled(scale: app.uiScale.value, child: child!),
        ),
        home: const Shell(),
      ),
    );
  }
}

/// 空格键播放/暂停（输入框聚焦时由输入框自己处理空格）
class _ToggleIntent extends Intent {
  const _ToggleIntent();
}

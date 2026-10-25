import 'dart:io';

import 'package:flutter/services.dart';

/// 安卓上由 MainActivity 处理的系统调用
const _channel = MethodChannel('yetease/system');

/// 用系统默认程序打开网址或目录
Future<void> openExternal(String target) async {
  if (Platform.isAndroid) {
    await _channel.invokeMethod('openUrl', target);
    return;
  }
  final cmd = Platform.isWindows ? 'explorer' : (Platform.isMacOS ? 'open' : 'xdg-open');
  await Process.run(cmd, [target]);
}

/// 安卓：调起系统安装器安装 apk。还没允许本应用安装应用时会先打开对应的设置页，返回 false
Future<bool> installApk(String path) async => await _channel.invokeMethod<bool>('installApk', path) ?? false;

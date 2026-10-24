import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 侧栏宽度这类纯界面偏好。和播放设置分开存，避免为了一个宽度动 Rust 设置结构。
class SidebarPrefs {
  static const _name = 'sidebar.json';

  static Future<double?> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final value = jsonDecode(await file.readAsString());
      final width = (value as Map)['width'];
      return width is num ? width.toDouble() : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(double width) async {
    try {
      final file = await _file();
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode({'width': width}));
    } catch (_) {
      // 存不下就算了，不打断交互
    }
  }

  static Future<File> _file() async {
    // 截图巡览/测试会用 YETEASE_DATA_DIR 隔离数据；普通桌面则跟着应用数据目录走
    final env = Platform.environment['YETEASE_DATA_DIR'];
    final dir = env != null && env.isNotEmpty ? Directory(env) : await getApplicationSupportDirectory();
    return File('${dir.path}/$_name');
  }
}

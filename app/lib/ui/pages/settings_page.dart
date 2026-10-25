import 'dart:io';

import 'package:flutter/material.dart';

import '../../src/rust/api/library.dart' as lib;
import '../../src/rust/api/playback.dart' as pb;
import '../../src/rust/api/types.dart';
import '../../state.dart';
import '../../theme.dart';
import '../login_dialog.dart';
import '../shell.dart' show isDesktop;
import '../widgets.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppState.I;
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 12, 32, 40),
      children: [
        const Text('设置', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
        const SizedBox(height: 24),
        _Section(
          title: '账号',
          child: ValueListenableBuilder(
            valueListenable: app.account,
            builder: (context, acc, _) => acc == null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Hint('登录后可同步歌单、红心与每日推荐。登录凭据只保存在本机。'),
                      const SizedBox(height: 12),
                      PillButton(label: '立即登录', primary: true, onTap: () => showLoginDialog(context)),
                    ],
                  )
                : Row(
                    children: [
                      ClipOval(child: Cover(url: acc.avatarUrl, size: 48, radius: 24)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(acc.nickname, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                      PillButton(label: '退出登录', onTap: app.logout),
                    ],
                  ),
          ),
        ),
        _Section(
          title: '音质',
          child: ValueListenableBuilder(
            valueListenable: app.settings,
            builder: (context, s, _) => s == null
                ? const SizedBox.shrink()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Hint('在线播放的默认音质。超出账号权益时自动降级。'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final q in AudioQuality.values)
                            _Choice(
                              label: qualityLabel(q),
                              selected: s.quality == q,
                              onTap: () => pb.setQuality(quality: q),
                            ),
                        ],
                      ),
                    ],
                  ),
          ),
        ),
        _Section(
          title: '网络',
          child: ValueListenableBuilder(
            valueListenable: app.settings,
            builder: (context, s, _) => s == null
                ? const SizedBox.shrink()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Check(
                        label: '海外网络模式',
                        value: s.useCnIp,
                        onChanged: (v) => pb.setCnIp(enabled: v),
                      ),
                      const SizedBox(height: 6),
                      _Hint('出口 IP 在海外（使用全局代理）时，网易云会以版权地区为由拒绝播放。开启后请求附带国内 IP 标头（当前：${s.cnIp}）。'),
                    ],
                  ),
          ),
        ),
        const _Section(title: '存储', child: _StorageSection()),
        if (isDesktop)
          _Section(
            title: '窗口',
            child: ListenableBuilder(
              listenable: Listenable.merge([app.settings, app.trayAvailable]),
              builder: (context, _) {
                final s = app.settings.value;
                if (s == null) return const SizedBox.shrink();
                final hint = Platform.isMacOS
                    ? '开启后关闭窗口仍在后台播放，点程序坞图标重新打开。'
                    : app.trayAvailable.value
                    ? '开启后关闭窗口仍在后台播放，点托盘图标或从托盘菜单重新打开、退出。'
                    : '当前桌面没有系统托盘（GNOME 需要安装 AppIndicator 扩展），关闭窗口会直接退出。';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Check(
                      label: Platform.isMacOS ? '关闭窗口后继续播放' : '关闭窗口时最小化到托盘',
                      value: s.closeToTray,
                      onChanged: (v) => pb.setCloseToTray(enable: v),
                    ),
                    const SizedBox(height: 6),
                    _Hint(hint),
                  ],
                );
              },
            ),
          ),
        _Section(
          title: '外观',
          child: ListenableBuilder(
            listenable: Listenable.merge([app.themeMode, app.uiScale]),
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Hint('主题'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final (mode, label) in [
                      (ThemeMode.system, '跟随系统'),
                      (ThemeMode.light, '浅色'),
                      (ThemeMode.dark, '深色'),
                    ])
                      _Choice(
                        label: label,
                        selected: app.themeMode.value == mode,
                        onTap: () => app.setAppearance(theme: mode),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                const _Hint('界面缩放（在系统缩放与系统文字大小的基础上再调整）'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final v in const [0.8, 0.9, 1.0, 1.1, 1.25])
                      _Choice(
                        label: '${(v * 100).round()}%',
                        selected: (app.uiScale.value - v).abs() < 0.01,
                        onTap: () => app.setAppearance(scale: v),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const _Section(title: '反馈', child: _FeedbackSection()),
        _Section(
          title: '关于',
          child: _Hint('YetEase Music ${pb.appVersion()} · 开源的网易云音乐第三方客户端。\n直连网易云官方接口，不依赖任何第三方服务器，没有广告。'),
        ),
      ],
    );
  }
}

String qualityLabel(AudioQuality q) => switch (q) {
  AudioQuality.standard => '标准',
  AudioQuality.higher => '较高',
  AudioQuality.exHigh => '极高',
  AudioQuality.lossless => '无损',
  AudioQuality.hiRes => 'Hi-Res',
};

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: p.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: TextStyle(color: context.palette.textSecondary, fontSize: 14, height: 1.6));
}

class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Hover(
      onTap: onTap,
      builder: (_, h) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Tokens.accentSoft : (h ? p.hoverStrong : p.field),
          border: Border.all(color: selected ? Tokens.accent : Colors.transparent),
          borderRadius: BorderRadius.circular(Tokens.radiusM),
        ),
        child: Text(label, style: TextStyle(color: selected ? Tokens.accent : p.textPrimary, fontSize: 14)),
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Hover(
      onTap: () => onChanged(!value),
      builder: (_, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: value,
            onChanged: (v) => onChanged(v ?? false),
            activeColor: Tokens.accent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          Text(label, style: const TextStyle(fontSize: 15)),
        ],
      ),
    );
  }
}

/// 存储：音乐缓存（可设上限）、图片缓存、下载目录
class _StorageSection extends StatefulWidget {
  const _StorageSection();

  @override
  State<_StorageSection> createState() => _StorageSectionState();
}

class _StorageSectionState extends State<_StorageSection> {
  CacheInfo? _info;
  String? _downloadDir;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final info = await lib.cacheInfo();
    final storage = await lib.getStorageSettings();
    if (mounted) {
      setState(() {
        _info = info;
        _downloadDir = storage.downloadDir;
      });
    }
  }

  Future<void> _clear(bool audio) async {
    final freed = await lib.clearCache(audio: audio);
    AppState.I.notify('已清除 ${_fmt(freed)}');
    if (!audio) PaintingBinding.instance.imageCache.clear();
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final i = _info;
    if (i == null) return const SizedBox(height: 40);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Row(
          label: '音乐缓存',
          value: '${_fmt(i.audioBytes)} / ${_fmt(i.audioLimitMb * 1024 * 1024)}',
          onClear: () => _clear(true),
        ),
        const SizedBox(height: 8),
        const _Hint('边听边缓存，再听不费流量。超过上限后自动删除最久没用过的歌曲。'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final mb in const [1024, 2048, 5120, 10240])
              _Choice(
                label: '${mb ~/ 1024} GB',
                selected: i.audioLimitMb == mb,
                onTap: () async {
                  await lib.setCacheLimit(mb: mb);
                  _refresh();
                },
              ),
          ],
        ),
        const SizedBox(height: 18),
        _Row(label: '图片缓存', value: '${_fmt(i.imageBytes)} / 500 MB', onClear: () => _clear(false)),
        const SizedBox(height: 18),
        _Hint('下载目录：${_downloadDir ?? ''}（已下载的歌曲不属于缓存，不会被自动清理）'),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, required this.onClear});

  final String label;
  final String value;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 14))),
        Text(value, style: TextStyle(fontSize: 14, color: p.textSecondary)),
        const SizedBox(width: 16),
        PillButton(label: '清除', onTap: onClear),
      ],
    );
  }
}

String _fmt(int bytes) {
  if (bytes >= 1 << 30) return '${(bytes / (1 << 30)).toStringAsFixed(1)} GB';
  if (bytes >= 1 << 20) return '${(bytes / (1 << 20)).toStringAsFixed(0)} MB';
  return '${(bytes / 1024).toStringAsFixed(0)} KB';
}

/// 反馈：导出脱敏日志，附到 GitHub Issue
class _FeedbackSection extends StatelessWidget {
  const _FeedbackSection();

  Future<void> _export() async {
    try {
      final path = await pb.exportLogs(extra: '');
      AppState.I.notify('日志已导出到 $path');
      _reveal(File(path).parent.path);
    } catch (e) {
      AppState.I.notify('导出失败：$e');
    }
  }

  static void _reveal(String dir) {
    final cmd = Platform.isWindows ? 'explorer' : (Platform.isMacOS ? 'open' : 'xdg-open');
    Process.run(cmd, [dir]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Hint('遇到问题时导出日志，附在 GitHub Issue 里。导出的日志已自动抹掉登录凭据。'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            PillButton(label: '导出日志', icon: Icons.ios_share_rounded, primary: true, onTap: _export),
            PillButton(label: '打开日志目录', icon: Icons.folder_open_rounded, onTap: () async => _reveal(await pb.logDir())),
            PillButton(
              label: '提交 Issue',
              icon: Icons.bug_report_outlined,
              onTap: () => _reveal('https://github.com/Gloridust/YetEaseMusic/issues/new'),
            ),
          ],
        ),
      ],
    );
  }
}

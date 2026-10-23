import 'package:flutter/material.dart';

import '../../src/rust/api/playback.dart' as pb;
import '../../src/rust/api/types.dart';
import '../../state.dart';
import '../../theme.dart';
import '../login_dialog.dart';
import '../widgets.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppState.I;
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 12, 32, 40),
      children: [
        const Text('设置', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
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
        _Section(
          title: '外观',
          child: ValueListenableBuilder(
            valueListenable: app.themeMode,
            builder: (context, m, _) => Wrap(
              spacing: 10,
              children: [
                for (final (mode, label) in [
                  (ThemeMode.system, '跟随系统'),
                  (ThemeMode.light, '浅色'),
                  (ThemeMode.dark, '深色'),
                ])
                  _Choice(label: label, selected: m == mode, onTap: () => app.themeMode.value = mode),
              ],
            ),
          ),
        ),
        const _Section(title: '关于', child: _Hint('YetEase Music · 开源的网易云音乐第三方客户端。\n直连网易云官方接口，不依赖任何第三方服务器，没有广告。')),
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
            width: 140,
            child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
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
          color: selected ? Tokens.accentSoft : (h ? p.hover : p.field),
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

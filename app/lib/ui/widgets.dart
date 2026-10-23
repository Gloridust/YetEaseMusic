import 'package:flutter/material.dart';

import '../state.dart';
import '../theme.dart';

/// 圆角封面，加载中/失败时显示占位
class Cover extends StatelessWidget {
  const Cover({super.key, required this.url, required this.size, this.radius = Tokens.radiusM, this.icon});

  final String? url;
  final double size;
  final double radius;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final px = (size * dpr).round().clamp(40, 1024);
    final src = sizedImage(url, px);
    final placeholder = Container(
      color: p.hover,
      alignment: Alignment.center,
      child: Icon(icon ?? Icons.music_note_rounded, color: p.textTertiary, size: size * 0.4),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox.square(
        dimension: size,
        child: src == null
            ? placeholder
            : Image.network(
                src,
                fit: BoxFit.cover,
                cacheWidth: px,
                gaplessPlayback: true,
                frameBuilder: (_, child, frame, sync) => sync
                    ? child
                    : AnimatedOpacity(
                        opacity: frame == null ? 0 : 1,
                        duration: const Duration(milliseconds: 220),
                        child: child,
                      ),
                errorBuilder: (_, _, _) => placeholder,
              ),
      ),
    );
  }
}

/// 悬停状态构建器（桌面端大量用到）
class Hover extends StatefulWidget {
  const Hover({super.key, required this.builder, this.onTap, this.cursor = SystemMouseCursors.click, this.onDoubleTap});

  final Widget Function(BuildContext, bool hovered) builder;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final MouseCursor cursor;

  @override
  State<Hover> createState() => _HoverState();
}

class _HoverState extends State<Hover> {
  bool _h = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap == null && widget.onDoubleTap == null ? MouseCursor.defer : widget.cursor,
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        child: widget.builder(context, _h),
      ),
    );
  }
}

class IconBtn extends StatelessWidget {
  const IconBtn(this.icon, {super.key, this.onTap, this.size = 20, this.color, this.tooltip, this.box = 32});

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final double box;
  final Color? color;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final btn = Hover(
      onTap: onTap,
      builder: (_, h) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: box,
        height: box,
        decoration: BoxDecoration(
          color: h ? p.hover : Colors.transparent,
          borderRadius: BorderRadius.circular(Tokens.radiusS),
        ),
        child: Icon(icon, size: size, color: color ?? (h ? p.textPrimary : p.textSecondary)),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

class PillButton extends StatelessWidget {
  const PillButton({super.key, required this.label, this.icon, this.onTap, this.primary = false});

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Hover(
      onTap: onTap,
      builder: (_, h) {
        final bg = primary ? (h ? const Color(0xFFE0303F) : Tokens.accent) : (h ? p.hover : p.field);
        final fg = primary ? Colors.white : p.textPrimary;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Tokens.radiusM)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 20, color: fg), const SizedBox(width: 6)],
              Text(
                label,
                style: TextStyle(color: fg, fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 小标签：VIP / 试听 / 无损
class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.color = Tokens.accent});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.7), width: 0.8),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(text, style: TextStyle(fontSize: 10, color: color, height: 1.3)),
    );
  }
}

/// 加载 / 出错 / 空状态的统一外壳
class AsyncView<T> extends StatelessWidget {
  const AsyncView({super.key, required this.future, required this.builder, this.onRetry});

  final Future<T> future;
  final Widget Function(BuildContext, T) builder;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snap) {
        if (snap.hasError) {
          return EmptyState(
            icon: Icons.wifi_off_rounded,
            text: '加载失败：${snap.error}',
            action: onRetry == null ? null : PillButton(label: '重试', onTap: onRetry),
          );
        }
        if (!snap.hasData) {
          return const Center(
            child: SizedBox.square(
              dimension: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: Tokens.accent),
            ),
          );
        }
        return builder(context, snap.data as T);
      },
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.text, this.icon = Icons.album_outlined, this.action});

  final String text;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: p.textTertiary.withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: p.textTertiary, fontSize: 14, letterSpacing: 2),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

/// 页面内的下划线标签栏（单曲 / 歌单 …）
class UnderlineTabs extends StatelessWidget {
  const UnderlineTabs({super.key, required this.tabs, required this.index, required this.onChanged});

  final List<String> tabs;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        for (var i = 0; i < tabs.length; i++)
          Padding(
            padding: const EdgeInsets.only(right: 36),
            child: Hover(
              onTap: () => onChanged(i),
              builder: (_, h) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tabs[i],
                    style: TextStyle(
                      fontSize: i == index ? 20 : 18,
                      fontWeight: i == index ? FontWeight.w700 : FontWeight.w400,
                      color: i == index ? p.textPrimary : (h ? p.textPrimary : p.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 6),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: i == index ? 18 : 0,
                    height: 3,
                    decoration: BoxDecoration(color: Tokens.accent, borderRadius: BorderRadius.circular(2)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// 页面统一的大标题行
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.subtitle, this.actions = const []});

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          if (subtitle != null) ...[
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(subtitle!, style: TextStyle(color: p.textTertiary, fontSize: 13)),
            ),
          ],
          const Spacer(),
          for (final (i, a) in actions.indexed) ...[if (i > 0) const SizedBox(width: 10), a],
        ],
      ),
    );
  }
}

/// 未登录时页面的占位
class LoginRequired extends StatelessWidget {
  const LoginRequired({super.key, required this.text, required this.onLogin});

  final String text;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.lock_outline_rounded,
    text: text,
    action: PillButton(label: '立即登录', primary: true, onTap: onLogin),
  );
}

/// 账号变化时自动刷新内容的页面基类
mixin AccountAware<T extends StatefulWidget> on State<T> {
  void onAccountChanged();

  @override
  void initState() {
    super.initState();
    AppState.I.account.addListener(onAccountChanged);
  }

  @override
  void dispose() {
    AppState.I.account.removeListener(onAccountChanged);
    super.dispose();
  }
}

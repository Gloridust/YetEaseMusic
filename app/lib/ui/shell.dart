import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../state.dart';
import '../theme.dart';
import 'login_dialog.dart';
import 'nav.dart';
import 'now_playing.dart';
import 'pages/home_page.dart';
import 'pages/search_page.dart';
import 'pages/settings_page.dart';
import 'player_bar.dart';
import 'queue_panel.dart';
import 'sidebar.dart';
import 'widgets.dart';

bool get isDesktop => Platform.isLinux || Platform.isWindows || Platform.isMacOS;

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  final _scaffold = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    AppState.I.notices.listen((msg) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 3)));
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return LayoutBuilder(
      builder: (context, c) {
        final compact = c.maxWidth < 760;
        return Scaffold(
          key: _scaffold,
          backgroundColor: p.background,
          drawer: compact
              ? Drawer(width: Tokens.sidebarWidth, backgroundColor: p.sidebar, child: const Sidebar())
              : null,
          endDrawer: const QueuePanel(),
          body: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        if (!compact) const SizedBox(width: Tokens.sidebarWidth, child: Sidebar()),
                        Expanded(
                          child: Column(
                            children: [
                              TopBar(onMenu: compact ? () => _scaffold.currentState?.openDrawer() : null),
                              Expanded(
                                child: ClipRect(
                                  child: Navigator(
                                    key: Nav.key,
                                    observers: [NavObserver()],
                                    onGenerateRoute: (_) => PageRouteBuilder(
                                      settings: const RouteSettings(name: 'home'),
                                      pageBuilder: (_, _, _) => const HomePage(),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  PlayerBar(onQueue: () => _scaffold.currentState?.openEndDrawer()),
                ],
              ),
              // 播放页从底部滑入，盖住整个窗口
              ValueListenableBuilder(
                valueListenable: AppState.I.nowPlayingOpen,
                builder: (context, open, _) => AnimatedSlide(
                  offset: open ? Offset.zero : const Offset(0, 1),
                  duration: const Duration(milliseconds: 380),
                  curve: open ? Curves.easeOutCubic : Curves.easeInCubic,
                  child: IgnorePointer(
                    ignoring: !open,
                    child: AnimatedOpacity(
                      opacity: open ? 1 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: NowPlaying(onQueue: () => _scaffold.currentState?.openEndDrawer()),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 标题栏区域可拖动窗口、双击最大化（仅桌面端）
class DragArea extends StatelessWidget {
  const DragArea({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!isDesktop) return child;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => windowManager.startDragging(),
      onDoubleTap: () async =>
          await windowManager.isMaximized() ? windowManager.unmaximize() : windowManager.maximize(),
      child: child,
    );
  }
}

class TopBar extends StatefulWidget {
  const TopBar({super.key, this.onMenu});

  final VoidCallback? onMenu;

  @override
  State<TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<TopBar> {
  final _search = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit(String v) {
    final k = v.trim();
    if (k.isEmpty) return;
    Nav.push('search:$k', SearchPage(keywords: k));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final app = AppState.I;
    final narrow = MediaQuery.sizeOf(context).width < 600;
    return DragArea(
      child: SizedBox(
        height: Tokens.topBarHeight + 8,
        child: Row(
          children: [
            const SizedBox(width: 20),
            if (widget.onMenu != null) ...[IconBtn(Icons.menu_rounded, onTap: widget.onMenu), const SizedBox(width: 8)],
            ValueListenableBuilder(
              valueListenable: Nav.canPop,
              builder: (context, can, _) =>
                  _OutlinedIcon(icon: Icons.chevron_left_rounded, onTap: can ? Nav.back : null),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: SizedBox(
                    height: 34,
                    child: TextField(
                      controller: _search,
                      focusNode: _focus,
                      onSubmitted: _submit,
                      textInputAction: TextInputAction.search,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: '搜索音乐、歌手、歌单',
                        hintStyle: TextStyle(color: p.textTertiary, fontSize: 13),
                        prefixIcon: Icon(Icons.search_rounded, size: 18, color: p.textTertiary),
                        filled: true,
                        fillColor: p.surface,
                        contentPadding: EdgeInsets.zero,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(Tokens.radiusM),
                          borderSide: BorderSide(color: p.divider),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(Tokens.radiusM),
                          borderSide: BorderSide(color: Tokens.accent.withValues(alpha: 0.5)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            ValueListenableBuilder(
              valueListenable: app.account,
              builder: (context, acc, _) => Hover(
                onTap: acc == null ? () => showLoginDialog(context) : () => Nav.root('settings', const SettingsPage()),
                builder: (_, h) => Row(
                  children: [
                    acc?.avatarUrl != null
                        ? ClipOval(child: Cover(url: acc!.avatarUrl, size: 28, radius: 14))
                        : CircleAvatar(
                            radius: 14,
                            backgroundColor: p.hover,
                            child: Icon(Icons.person_rounded, size: 20, color: p.textTertiary),
                          ),
                    if (!narrow) ...[
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 140),
                        child: Text(
                          acc?.nickname ?? '未登录',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: h ? p.textPrimary : p.textSecondary),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            IconBtn(Icons.settings_outlined, tooltip: '设置', onTap: () => Nav.root('settings', const SettingsPage())),
            if (isDesktop) ...[
              Container(width: 1, height: 18, margin: const EdgeInsets.symmetric(horizontal: 10), color: p.divider),
              const WindowButtons(),
            ],
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}

class _OutlinedIcon extends StatelessWidget {
  const _OutlinedIcon({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Hover(
      onTap: onTap,
      builder: (_, h) => Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: h && onTap != null ? p.hover : p.surface,
          border: Border.all(color: p.divider),
          borderRadius: BorderRadius.circular(Tokens.radiusM),
        ),
        child: Icon(icon, color: onTap == null ? p.textTertiary : p.textPrimary),
      ),
    );
  }
}

class WindowButtons extends StatelessWidget {
  const WindowButtons({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconBtn(Icons.remove_rounded, color: color, onTap: windowManager.minimize, tooltip: '最小化'),
        IconBtn(
          Icons.crop_square_rounded,
          size: 18,
          color: color,
          tooltip: '最大化',
          onTap: () async => await windowManager.isMaximized() ? windowManager.unmaximize() : windowManager.maximize(),
        ),
        IconBtn(Icons.close_rounded, color: color, onTap: windowManager.close, tooltip: '关闭'),
      ],
    );
  }
}

/// 给播放页等需要拖动窗口的地方复用
class WindowDragArea extends StatelessWidget {
  const WindowDragArea({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DragArea(child: child);
}

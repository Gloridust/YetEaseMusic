import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../src/rust/api/types.dart';
import '../state.dart';
import '../theme.dart';
import 'login_dialog.dart';
import 'nav.dart';
import 'now_playing.dart';
import 'pages/home_page.dart';
import 'pages/playlist_page.dart';
import 'pages/search_page.dart';
import 'pages/settings_page.dart';
import 'player_bar.dart';
import 'queue_panel.dart';
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

class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final app = AppState.I;
    return Container(
      color: p.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DragArea(
            child: SizedBox(
              height: Tokens.topBarHeight + 8,
              child: Row(
                children: [
                  const SizedBox(width: 24),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(color: Tokens.accent, shape: BoxShape.circle),
                    child: const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'YetEase',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, letterSpacing: 0.3),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: app.myPlaylists,
              builder: (context, lists, _) {
                final liked = lists.where((l) => l.specialType == 5).firstOrNull;
                final mine = lists.where((l) => l.specialType != 5 && !l.subscribed).toList();
                final subs = lists.where((l) => l.subscribed).toList();
                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  children: [
                    const SizedBox(height: 8),
                    _NavItem(icon: Icons.music_note_rounded, label: '推荐', route: 'home', page: () => const HomePage()),
                    ValueListenableBuilder(
                      valueListenable: app.account,
                      builder: (context, acc, _) => acc == null
                          ? const SizedBox.shrink()
                          : _NavItem(
                              icon: Icons.today_rounded,
                              label: '每日推荐',
                              route: 'daily',
                              page: () => const PlaylistPage.daily(),
                            ),
                    ),
                    const _Divider(),
                    if (liked != null)
                      _NavItem(
                        icon: Icons.favorite_rounded,
                        label: '我喜欢的音乐',
                        route: 'playlist:${liked.id}',
                        page: () => PlaylistPage(id: liked.id),
                      )
                    else
                      _NavItem(
                        icon: Icons.favorite_rounded,
                        label: '我喜欢的音乐',
                        route: 'liked-login',
                        onTap: () => showLoginDialog(context),
                      ),
                    if (mine.isNotEmpty) ...[
                      const _Divider(),
                      _GroupTitle('创建的歌单 ${mine.length}'),
                      for (final l in mine) _PlaylistItem(item: l),
                    ],
                    if (subs.isNotEmpty) ...[
                      const _Divider(),
                      _GroupTitle('收藏的歌单 ${subs.length}'),
                      for (final l in subs) _PlaylistItem(item: l),
                    ],
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
    child: Divider(height: 1, color: context.palette.divider),
  );
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
    child: Text(
      text,
      style: TextStyle(color: context.palette.textTertiary, fontSize: 13, fontWeight: FontWeight.w600),
    ),
  );
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.route, this.page, this.onTap});

  final IconData icon;
  final String label;
  final String route;
  final Widget Function()? page;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ValueListenableBuilder(
      valueListenable: Nav.location,
      builder: (context, loc, _) {
        final sel = loc == route;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Hover(
            onTap: () {
              if (onTap != null) return onTap!();
              Scaffold.maybeOf(context)?.closeDrawer();
              Nav.root(route, page!());
            },
            builder: (_, h) => AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: sel ? Tokens.accent : (h ? p.hover : Colors.transparent),
                borderRadius: BorderRadius.circular(Tokens.radiusM),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 21, color: sel ? Colors.white : p.textSecondary),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      color: sel ? Colors.white : p.textPrimary,
                      fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PlaylistItem extends StatelessWidget {
  const _PlaylistItem({required this.item});

  final PlaylistItem item;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final route = 'playlist:${item.id}';
    return ValueListenableBuilder(
      valueListenable: Nav.location,
      builder: (context, loc, _) {
        final sel = loc == route;
        return Hover(
          onTap: () {
            Scaffold.maybeOf(context)?.closeDrawer();
            Nav.root(route, PlaylistPage(id: item.id));
          },
          builder: (_, h) => Container(
            height: 44,
            margin: const EdgeInsets.symmetric(vertical: 1),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: sel ? Tokens.accentSoft : (h ? p.hover : Colors.transparent),
              borderRadius: BorderRadius.circular(Tokens.radiusM),
            ),
            child: Row(
              children: [
                Cover(url: item.coverUrl, size: 30, radius: Tokens.radiusS),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: sel ? Tokens.accent : p.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 标题栏区域可拖动窗口、双击最大化（仅桌面端）
class _DragArea extends StatelessWidget {
  const _DragArea({required this.child});

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
    return _DragArea(
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
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _search,
                    focusNode: _focus,
                    onSubmitted: _submit,
                    textInputAction: TextInputAction.search,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: '搜索音乐、歌手、歌单',
                      hintStyle: TextStyle(color: p.textTertiary, fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded, size: 20, color: p.textTertiary),
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
            const Spacer(),
            ValueListenableBuilder(
              valueListenable: app.account,
              builder: (context, acc, _) => Hover(
                onTap: acc == null ? () => showLoginDialog(context) : () => Nav.root('settings', const SettingsPage()),
                builder: (_, h) => Row(
                  children: [
                    acc?.avatarUrl != null
                        ? ClipOval(child: Cover(url: acc!.avatarUrl, size: 32, radius: 16))
                        : CircleAvatar(
                            radius: 16,
                            backgroundColor: p.hover,
                            child: Icon(Icons.person_rounded, size: 20, color: p.textTertiary),
                          ),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 140),
                      child: Text(
                        acc?.nickname ?? '未登录',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, color: h ? p.textPrimary : p.textSecondary),
                      ),
                    ),
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
        width: 40,
        height: 40,
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
  Widget build(BuildContext context) => _DragArea(child: child);
}

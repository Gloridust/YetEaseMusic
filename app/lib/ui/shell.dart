import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../src/rust/api/playback.dart' as pb;
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

class _ShellState extends State<Shell> with WindowListener {
  final _scaffold = GlobalKey<ScaffoldState>();
  // 设置在界面显示之前已经读好，首帧就是保存的宽度
  double _sidebarWidth = (AppState.I.settings.value?.sidebarWidth ?? Tokens.sidebarWidth)
      .clamp(Tokens.sidebarMinWidth, Tokens.sidebarMaxWidth)
      .toDouble();

  /// 最大化 / 全屏时窗口贴着屏幕边缘，不需要描边
  bool _edgeToEdge = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isLinux) {
      windowManager.addListener(this);
      _syncWindowState();
    }
    AppState.I.notices.listen((msg) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(msg),
            duration: const Duration(seconds: 3),
            // SnackBar 默认贴底，会盖住播放条中间的按钮；抬到播放条上方
            margin: const EdgeInsets.only(bottom: Tokens.playerBarHeight + 12),
          ),
        );
    });
  }

  @override
  void dispose() {
    if (Platform.isLinux) windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _syncWindowState() async {
    final edge = await windowManager.isMaximized() || await windowManager.isFullScreen();
    if (mounted && edge != _edgeToEdge) setState(() => _edgeToEdge = edge);
  }

  @override
  void onWindowMaximize() => _syncWindowState();
  @override
  void onWindowUnmaximize() => _syncWindowState();
  @override
  void onWindowEnterFullScreen() => _syncWindowState();
  @override
  void onWindowLeaveFullScreen() => _syncWindowState();

  void _setSidebarWidth(double width) {
    setState(() => _sidebarWidth = width.clamp(Tokens.sidebarMinWidth, Tokens.sidebarMaxWidth).toDouble());
  }

  void _saveSidebarWidth() => pb.setSidebarWidth(width: _sidebarWidth).ignore();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return LayoutBuilder(
      builder: (context, c) {
        final compact = c.maxWidth < 760;
        // 窗口变窄时把侧栏收回来，给内容留至少 480 的逻辑宽度
        final maxSidebarWidth = (c.maxWidth - 480).clamp(Tokens.sidebarMinWidth, Tokens.sidebarMaxWidth).toDouble();
        final sidebarWidth = _sidebarWidth.clamp(Tokens.sidebarMinWidth, maxSidebarWidth).toDouble();
        final drawerWidth = _sidebarWidth.clamp(220.0, 320.0).toDouble();
        // 无边框窗口：如果贴着另一块白色窗口，底部会糊成一片。Linux 上加一圈内描边
        final borderColor = Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.14)
            : p.textTertiary.withValues(alpha: 0.45);
        return Scaffold(
          key: _scaffold,
          backgroundColor: p.background,
          drawer: compact ? Drawer(width: drawerWidth, backgroundColor: p.sidebar, child: const Sidebar()) : null,
          endDrawer: const QueuePanel(),
          body: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!compact) ...[
                          SizedBox(width: sidebarWidth, child: const Sidebar()),
                          _SidebarResizeHandle(
                            width: sidebarWidth,
                            maxWidth: maxSidebarWidth,
                            onChanged: _setSidebarWidth,
                            onDone: _saveSidebarWidth,
                            onReset: () {
                              _setSidebarWidth(Tokens.sidebarWidth);
                              _saveSidebarWidth();
                            },
                          ),
                        ],
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
                    // 收起后播放页仍挂在树上（保留歌词滚动位置），停掉里面的动画，免得看不见时还每帧重画
                    child: TickerMode(
                      enabled: open,
                      child: AnimatedOpacity(
                        opacity: open ? 1 : 0,
                        duration: const Duration(milliseconds: 300),
                        child: NowPlaying(onQueue: () => _scaffold.currentState?.openEndDrawer()),
                      ),
                    ),
                  ),
                ),
              ),
              if (Platform.isLinux && !_edgeToEdge)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(border: Border.all(color: borderColor)),
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

/// 侧栏右缘的拖动条：拖动改宽度，双击恢复默认值。
class _SidebarResizeHandle extends StatefulWidget {
  const _SidebarResizeHandle({
    required this.width,
    required this.maxWidth,
    required this.onChanged,
    required this.onDone,
    required this.onReset,
  });

  final double width;
  final double maxWidth;
  final ValueChanged<double> onChanged;
  final VoidCallback onDone;
  final VoidCallback onReset;

  @override
  State<_SidebarResizeHandle> createState() => _SidebarResizeHandleState();
}

class _SidebarResizeHandleState extends State<_SidebarResizeHandle> {
  bool _hover = false;
  bool _dragging = false;
  double _dragWidth = 0;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final active = _hover || _dragging;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) {
          _dragWidth = widget.width;
          setState(() => _dragging = true);
        },
        onHorizontalDragUpdate: (d) {
          _dragWidth = (_dragWidth + d.delta.dx).clamp(Tokens.sidebarMinWidth, widget.maxWidth).toDouble();
          widget.onChanged(_dragWidth);
        },
        onHorizontalDragEnd: (_) {
          setState(() => _dragging = false);
          widget.onDone();
        },
        onHorizontalDragCancel: () {
          setState(() => _dragging = false);
          widget.onDone();
        },
        onDoubleTap: widget.onReset,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 8,
          decoration: BoxDecoration(
            color: p.sidebar,
            border: Border(
              right: BorderSide(color: active ? Tokens.accent : p.divider, width: active ? 2 : 1),
            ),
          ),
        ),
      ),
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
                  constraints: const BoxConstraints(maxWidth: 258),
                  // 淡淡的粉—紫—蓝渐变底 + 细边框
                  child: ListenableBuilder(
                    listenable: _focus,
                    builder: (context, _) => Container(
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.centerRight,
                          end: Alignment.centerLeft,
                          colors: [Color(0x14F574BA), Color(0x14BD8CFF), Color(0x144E8CEA)],
                          stops: [0.07, 0.49, 0.99],
                        ),
                        border: Border.all(
                          color: _focus.hasFocus ? Tokens.accent.withValues(alpha: 0.4) : p.hoverStrong,
                        ),
                        borderRadius: BorderRadius.circular(Tokens.radiusM),
                      ),
                      child: TextField(
                        controller: _search,
                        focusNode: _focus,
                        onSubmitted: _submit,
                        textInputAction: TextInputAction.search,
                        style: TextStyle(fontSize: 14, color: p.textPrimary),
                        cursorColor: p.textPrimary,
                        decoration: InputDecoration(
                          hintText: '搜索音乐、歌手、歌单',
                          hintStyle: TextStyle(color: p.textPrimary.withValues(alpha: 0.4), fontSize: 14),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(left: 16, right: 8),
                            child: Icon(Icons.search_rounded, size: 18, color: p.textPrimary.withValues(alpha: 0.4)),
                          ),
                          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                          isCollapsed: true,
                          contentPadding: const EdgeInsets.only(right: 12, top: 9, bottom: 9),
                          border: InputBorder.none,
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
        width: 28,
        height: 36,
        decoration: BoxDecoration(
          color: h && onTap != null ? p.hover : null,
          border: Border.all(color: p.hoverStrong),
          borderRadius: BorderRadius.circular(Tokens.radiusM),
        ),
        child: Icon(icon, size: 20, color: onTap == null ? p.textTertiary : p.textPrimary.withValues(alpha: 0.8)),
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

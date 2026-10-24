import 'package:flutter/material.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart' show Int64List;

import '../src/rust/api/library.dart' as lib;
import '../src/rust/api/types.dart';
import '../state.dart';
import '../theme.dart';
import 'brand.dart';
import 'heartbeat_icon.dart';
import 'login_dialog.dart';
import 'nav.dart';
import 'pages/downloads_page.dart';
import 'pages/follows_page.dart';
import 'pages/home_page.dart';
import 'pages/local_page.dart';
import 'pages/playlist_page.dart';
import 'pages/podcast_page.dart';
import 'pages/recent_page.dart';
import 'shell.dart';
import 'widgets.dart';

/// 左侧导航：与官方客户端同样的分组与顺序
class Sidebar extends StatefulWidget {
  const Sidebar({super.key});

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  bool _mineOpen = true;
  bool _subsOpen = true;

  /// 需要登录的入口：未登录时弹出登录框
  VoidCallback? _needLogin(BuildContext context) =>
      AppState.I.account.value == null ? () => showLoginDialog(context) : null;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final app = AppState.I;
    return Container(
      color: p.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DragArea(
            child: SizedBox(
              height: Tokens.topBarHeight + 8,
              child: Row(
                children: [
                  const SizedBox(width: 22),
                  const AppLogo(size: 30),
                  const SizedBox(width: 10),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        kAppName,
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.textPrimary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: Listenable.merge([app.myPlaylists, app.account]),
              builder: (context, _) {
                final lists = app.myPlaylists.value;
                final liked = lists.where((l) => l.specialType == 5).firstOrNull;
                final mine = lists.where((l) => l.specialType != 5 && !l.subscribed).toList();
                final subs = lists.where((l) => l.subscribed).toList();
                final loggedIn = app.account.value != null;
                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  children: [
                    const SizedBox(height: 6),
                    NavItem(
                      icon: Icons.library_music_rounded,
                      label: '精选',
                      route: 'home',
                      page: () => const HomePage(),
                    ),
                    NavItem(
                      icon: Icons.podcasts_rounded,
                      label: '播客',
                      route: 'podcast',
                      page: () => const PodcastPage(),
                    ),
                    NavItem(
                      icon: Icons.chat_bubble_rounded,
                      label: '关注',
                      route: 'follows',
                      page: () => const FollowsPage(),
                      onTap: _needLogin(context),
                    ),
                    const _Divider(),
                    NavItem(
                      icon: Icons.favorite_rounded,
                      label: '我喜欢的音乐',
                      route: liked == null ? 'liked' : 'playlist:${liked.id}',
                      page: liked == null ? null : () => PlaylistPage(id: liked.id),
                      onTap: liked == null ? () => showLoginDialog(context) : null,
                      trailing: liked == null ? null : _HeartbeatButton(likedId: liked.id),
                    ),
                    NavItem(
                      icon: Icons.access_time_filled_rounded,
                      label: '最近播放',
                      route: 'recent',
                      page: () => const RecentPage(),
                      onTap: _needLogin(context),
                    ),
                    NavItem(
                      icon: Icons.download_for_offline_rounded,
                      label: '下载管理',
                      route: 'downloads',
                      page: () => const DownloadsPage(),
                    ),
                    NavItem(
                      icon: Icons.folder_rounded,
                      label: '本地音乐',
                      route: 'local',
                      page: () => const LocalMusicPage(),
                    ),
                    const _Divider(),
                    _GroupHeader(
                      title: '创建的歌单 ${loggedIn ? mine.length : 0}',
                      open: _mineOpen,
                      onToggle: () => setState(() => _mineOpen = !_mineOpen),
                      onAdd: loggedIn ? () => showCreatePlaylistDialog(context) : () => showLoginDialog(context),
                    ),
                    if (_mineOpen)
                      for (final l in mine) PlaylistNavItem(item: l),
                    if (subs.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _GroupHeader(
                        title: '收藏的歌单 ${subs.length}',
                        open: _subsOpen,
                        onToggle: () => setState(() => _subsOpen = !_subsOpen),
                      ),
                      if (_subsOpen)
                        for (final l in subs) PlaylistNavItem(item: l),
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

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.title, required this.open, required this.onToggle, this.onAdd});

  final String title;
  final bool open;
  final VoidCallback onToggle;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Hover(
      onTap: onToggle,
      builder: (_, h) => SizedBox(
        height: 34,
        child: Row(
          children: [
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(color: p.textTertiary, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 2),
            AnimatedRotation(
              turns: open ? 0 : -0.25,
              duration: const Duration(milliseconds: 160),
              child: Icon(Icons.expand_more_rounded, size: 16, color: h ? p.textSecondary : p.textTertiary),
            ),
            const Spacer(),
            if (onAdd != null) IconBtn(Icons.add_rounded, size: 18, box: 26, tooltip: '新建歌单', onTap: onAdd),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

class NavItem extends StatelessWidget {
  const NavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.route,
    this.page,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String route;
  final Widget Function()? page;

  /// 设置后点击时执行它而不是导航（比如未登录时弹出登录框）
  final VoidCallback? onTap;
  final Widget? trailing;

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
              height: 40,
              padding: const EdgeInsets.only(left: 14, right: 6),
              decoration: BoxDecoration(
                color: sel ? Tokens.accent : (h ? p.hover : Colors.transparent),
                borderRadius: BorderRadius.circular(Tokens.radiusM),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 19, color: sel ? Colors.white : p.textSecondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: sel ? Colors.white : p.textPrimary,
                        fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (trailing != null)
                    IconTheme(
                      data: IconThemeData(color: sel ? Colors.white : p.textTertiary),
                      child: trailing!,
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

/// 心动模式：以红心歌曲为起点智能推荐
class _HeartbeatButton extends StatelessWidget {
  const _HeartbeatButton({required this.likedId});

  final int likedId;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '心动模式',
      child: Hover(
        onTap: () async {
          try {
            await lib.heartbeatMode(
              likedPlaylistId: likedId,
              likedIds: Int64List.fromList(AppState.I.likedIds.value.toList()),
            );
            AppState.I.notify('已开启心动模式');
          } catch (e) {
            AppState.I.notify('心动模式开启失败：$e');
          }
        },
        builder: (context, h) => Padding(
          padding: const EdgeInsets.all(6),
          child: HeartbeatIcon(size: 18, color: h ? Tokens.accent : (IconTheme.of(context).color ?? Tokens.accent)),
        ),
      ),
    );
  }
}

class PlaylistNavItem extends StatelessWidget {
  const PlaylistNavItem({super.key, required this.item});

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
            height: 38,
            margin: const EdgeInsets.symmetric(vertical: 1),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: sel ? Tokens.accentSoft : (h ? p.hover : Colors.transparent),
              borderRadius: BorderRadius.circular(Tokens.radiusM),
            ),
            child: Row(
              children: [
                Cover(url: item.coverUrl, size: 26, radius: Tokens.radiusS),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: sel ? Tokens.accent : p.textPrimary),
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

/// 新建歌单
Future<void> showCreatePlaylistDialog(BuildContext context) async {
  final name = TextEditingController();
  var private = false;
  final created = await showDialog<PlaylistItem>(
    context: context,
    builder: (context) {
      final p = context.palette;
      return StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: p.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tokens.radiusL)),
          child: SizedBox(
            width: 380,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('新建歌单', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 18),
                  TextField(
                    controller: name,
                    autofocus: true,
                    maxLength: 40,
                    decoration: InputDecoration(
                      hintText: '输入歌单标题',
                      filled: true,
                      fillColor: p.field,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(Tokens.radiusM),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Checkbox(
                        value: private,
                        activeColor: Tokens.accent,
                        onChanged: (v) => setState(() => private = v ?? false),
                      ),
                      const Text('设为隐私歌单'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      PillButton(label: '取消', onTap: () => Navigator.of(context).pop()),
                      const SizedBox(width: 10),
                      PillButton(
                        label: '创建',
                        primary: true,
                        onTap: () async {
                          final n = name.text.trim();
                          if (n.isEmpty) return;
                          try {
                            final pl = await lib.createPlaylist(name: n, private: private);
                            if (context.mounted) Navigator.of(context).pop(pl);
                          } catch (e) {
                            AppState.I.notify('创建失败：$e');
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
  if (created != null) {
    await AppState.I.refreshAccount();
    AppState.I.notify('已创建歌单「${created.name}」');
  }
}

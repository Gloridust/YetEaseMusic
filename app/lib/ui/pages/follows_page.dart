import 'package:flutter/material.dart';

import '../../src/rust/api/library.dart' as lib;
import '../../src/rust/api/types.dart';
import '../../state.dart';
import '../../theme.dart';
import '../login_dialog.dart';
import '../nav.dart';
import '../widgets.dart';
import 'home_page.dart';

/// 关注：我关注的人，点进去看 TA 的歌单
class FollowsPage extends StatefulWidget {
  const FollowsPage({super.key});

  @override
  State<FollowsPage> createState() => _FollowsPageState();
}

class _FollowsPageState extends State<FollowsPage> with AccountAware {
  late Future<List<FollowItem>> _future = _load();

  Future<List<FollowItem>> _load() async {
    final acc = AppState.I.account.value;
    if (acc == null) return [];
    final all = <FollowItem>[];
    var more = true;
    // 关注列表一般不长，一次性取完（最多 600 人）
    while (more && all.length < 600) {
      final (list, m) = await lib.follows(userId: acc.userId, offset: all.length);
      all.addAll(list);
      more = m && list.isNotEmpty;
    }
    return all;
  }

  @override
  void onAccountChanged() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    if (AppState.I.account.value == null) {
      return LoginRequired(text: '登录后查看你关注的人', onLogin: () => showLoginDialog(context));
    }
    final p = context.palette;
    return AsyncView<List<FollowItem>>(
      future: _future,
      onRetry: onAccountChanged,
      builder: (context, list) => CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: PageHeader(title: '关注', subtitle: '${list.length} 人'),
          ),
          if (list.isEmpty)
            const SliverFillRemaining(hasScrollBody: false, child: EmptyState(text: '还没有关注任何人'))
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 340,
                  mainAxisExtent: 76,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 8,
                ),
                delegate: SliverChildBuilderDelegate((context, i) {
                  final u = list[i];
                  return Hover(
                    onTap: () => Nav.push('user:${u.userId}', UserPage(user: u)),
                    builder: (_, h) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: h ? p.hover : p.surface,
                        borderRadius: BorderRadius.circular(Tokens.radiusM),
                      ),
                      child: Row(
                        children: [
                          ClipOval(
                            child: Cover(url: u.avatarUrl, size: 48, radius: 0, icon: Icons.person_rounded),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  u.nickname,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  u.signature ?? '粉丝 ${formatCount(u.followers)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12, color: p.textTertiary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }, childCount: list.length),
              ),
            ),
        ],
      ),
    );
  }
}

/// 用户主页：创建与收藏的歌单
class UserPage extends StatefulWidget {
  const UserPage({super.key, required this.user});

  final FollowItem user;

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  late final Future<List<PlaylistItem>> _future = lib.userPlaylists(userId: widget.user.userId);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final u = widget.user;
    return AsyncView<List<PlaylistItem>>(
      future: _future,
      builder: (context, lists) {
        final own = lists.where((l) => l.creatorId == u.userId).toList();
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 20),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    ClipOval(
                      child: Cover(url: u.avatarUrl, size: 96, radius: 0, icon: Icons.person_rounded),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(u.nickname, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Text(
                            '粉丝 ${formatCount(u.followers)}',
                            style: TextStyle(color: p.textSecondary, fontSize: 13),
                          ),
                          if (u.signature != null) ...[
                            const SizedBox(height: 6),
                            Text(u.signature!, maxLines: 2, style: TextStyle(color: p.textTertiary, fontSize: 13)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 12),
              sliver: SliverToBoxAdapter(
                child: Text('创建的歌单 ${own.length}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 190,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 20,
                  childAspectRatio: 0.74,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) => PlaylistCard(item: own[i]),
                  childCount: own.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

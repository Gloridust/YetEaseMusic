import 'package:flutter/material.dart';

import '../../src/rust/api/library.dart' as lib;
import '../../src/rust/api/types.dart';
import '../../state.dart';
import '../login_dialog.dart';
import '../song_list.dart';
import '../widgets.dart';

/// 最近播放：网易云云端记录，与手机端同步
class RecentPage extends StatefulWidget {
  const RecentPage({super.key});

  @override
  State<RecentPage> createState() => _RecentPageState();
}

class _RecentPageState extends State<RecentPage> with AccountAware {
  late Future<List<RecentItem>> _future = lib.recentSongs();

  @override
  void onAccountChanged() => setState(() => _future = lib.recentSongs());

  @override
  Widget build(BuildContext context) {
    if (AppState.I.account.value == null) {
      return LoginRequired(text: '登录后查看最近播放（与手机端同步）', onLogin: () => showLoginDialog(context));
    }
    return AsyncView<List<RecentItem>>(
      future: _future,
      onRetry: onAccountChanged,
      builder: (context, list) {
        final songs = list.map((r) => r.song).toList();
        final now = DateTime.now();
        final times = list.map((r) => _ago(now, DateTime.fromMillisecondsSinceEpoch(r.playTimeMs))).toList();
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: PageHeader(
                title: '最近播放',
                subtitle: '${songs.length} 首',
                actions: [
                  PillButton(
                    label: '播放全部',
                    icon: Icons.play_arrow_rounded,
                    primary: true,
                    onTap: songs.isEmpty ? null : () => AppState.I.playSongs(songs, 0),
                  ),
                ],
              ),
            ),
            if (songs.isEmpty)
              const SliverFillRemaining(hasScrollBody: false, child: EmptyState(text: '最近没有播放记录'))
            else ...[
              const SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 28),
                sliver: SliverToBoxAdapter(child: SongListHeader(lastLabel: '播放时间')),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(28, 4, 28, 28),
                sliver: SliverSongList(songs: songs, lastColumn: times),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// 与官方一致的相对时间：刚刚 / N分钟前 / N小时前 / 昨天 / M月D日
String _ago(DateTime now, DateTime t) {
  final d = now.difference(t);
  if (d.inMinutes < 1) return '刚刚';
  if (d.inHours < 1) return '${d.inMinutes}分钟前';
  if (d.inHours < 24 && now.day == t.day) return '${d.inHours}小时前';
  final yesterday = now.subtract(const Duration(days: 1));
  if (t.year == yesterday.year && t.month == yesterday.month && t.day == yesterday.day) return '昨天';
  if (t.year == now.year) return '${t.month}月${t.day}日';
  return '${t.year}/${t.month}/${t.day}';
}

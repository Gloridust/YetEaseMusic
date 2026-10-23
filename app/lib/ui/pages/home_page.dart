import 'package:flutter/material.dart';

import '../../src/rust/api/library.dart' as lib;
import '../../src/rust/api/types.dart';
import '../../state.dart';
import '../../theme.dart';
import '../nav.dart';
import '../widgets.dart';
import 'playlist_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<PlaylistItem>> _future = lib.recommendPlaylists(limit: 30);

  @override
  Widget build(BuildContext context) {
    return AsyncView<List<PlaylistItem>>(
      future: _future,
      onRetry: () => setState(() => _future = lib.recommendPlaylists(limit: 30)),
      builder: (context, list) => CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(28, 4, 28, 0),
            sliver: SliverToBoxAdapter(
              child: ValueListenableBuilder(
                valueListenable: AppState.I.account,
                builder: (context, acc, _) => acc == null ? const SizedBox.shrink() : const _DailyCard(),
              ),
            ),
          ),
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(28, 20, 28, 14),
            sliver: SliverToBoxAdapter(child: _SectionTitle('推荐歌单')),
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
                (context, i) => PlaylistCard(item: list[i]),
                childCount: list.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700));
}

/// 每日推荐入口
class _DailyCard extends StatelessWidget {
  const _DailyCard();

  @override
  Widget build(BuildContext context) {
    final day = DateTime.now().day;
    return Hover(
      onTap: () => Nav.push('daily', const PlaylistPage.daily()),
      builder: (context, h) => AnimatedScale(
        scale: h ? 1.005 : 1,
        duration: const Duration(milliseconds: 160),
        child: Container(
          height: 112,
          padding: const EdgeInsets.symmetric(horizontal: 28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Tokens.radiusL),
            gradient: const LinearGradient(
              colors: [Color(0xFFFF7A6B), Tokens.accent, Color(0xFFB8336A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 68,
                height: 68,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(Tokens.radiusL),
                ),
                child: Text(
                  '$day',
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 24),
              const Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '每日推荐',
                      style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 6),
                    Text('根据你的音乐口味生成，每天 6:00 更新', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 42),
            ],
          ),
        ),
      ),
    );
  }
}

class PlaylistCard extends StatelessWidget {
  const PlaylistCard({super.key, required this.item});

  final PlaylistItem item;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Hover(
      onTap: () => Nav.push('playlist:${item.id}', PlaylistPage(id: item.id)),
      builder: (context, h) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, c) => Stack(
              children: [
                AnimatedScale(
                  scale: h ? 1.03 : 1,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: Cover(url: item.coverUrl, size: c.maxWidth, radius: Tokens.radiusL),
                ),
                if (item.playCount > 0)
                  Positioned(
                    right: 10,
                    top: 8,
                    child: Row(
                      children: [
                        const Icon(Icons.headphones_rounded, size: 14, color: Colors.white),
                        const SizedBox(width: 3),
                        Text(
                          formatCount(item.playCount),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            shadows: [Shadow(blurRadius: 6, color: Colors.black45)],
                          ),
                        ),
                      ],
                    ),
                  ),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: AnimatedOpacity(
                    opacity: h ? 1 : 0,
                    duration: const Duration(milliseconds: 160),
                    child: Hover(
                      onTap: () async {
                        final d = await lib.playlistDetail(id: item.id);
                        await AppState.I.playSongs(d.tracks, 0);
                      },
                      builder: (_, _) => Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          shape: BoxShape.circle,
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
                        ),
                        child: const Icon(Icons.play_arrow_rounded, color: Tokens.accent, size: 24),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            item.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, height: 1.4, color: p.textPrimary),
          ),
        ],
      ),
    );
  }
}

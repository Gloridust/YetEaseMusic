import 'package:flutter/material.dart';

import '../../src/rust/api/library.dart' as lib;
import '../../src/rust/api/types.dart';
import '../../state.dart';
import '../../theme.dart';
import '../nav.dart';
import '../widgets.dart';
import 'playlist_page.dart';

class _Featured extends StatefulWidget {
  const _Featured();

  @override
  State<_Featured> createState() => _FeaturedState();
}

class _FeaturedState extends State<_Featured> {
  late Future<List<PlaylistItem>> _future = lib.recommendPlaylists(limit: 30);

  @override
  Widget build(BuildContext context) {
    return AsyncView<List<PlaylistItem>>(
      future: _future,
      onRetry: () => setState(() => _future = lib.recommendPlaylists(limit: 30)),
      builder: (context, list) => CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Tokens.pageGutter, 4, Tokens.pageGutter, 0),
            sliver: SliverToBoxAdapter(
              child: ValueListenableBuilder(
                valueListenable: AppState.I.account,
                builder: (context, acc, _) => acc == null ? const SizedBox.shrink() : const _DailyCard(),
              ),
            ),
          ),
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(Tokens.pageGutter, 20, Tokens.pageGutter, 14),
            sliver: SliverToBoxAdapter(child: _SectionTitle('推荐歌单')),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Tokens.pageGutter, 0, Tokens.pageGutter, Tokens.pageGutter),
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
  Widget build(BuildContext context) => Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600));
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
          padding: const EdgeInsets.symmetric(horizontal: Tokens.pageGutter),
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
                CardCover(url: item.coverUrl, size: c.maxWidth, hovered: h),
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
                    duration: const Duration(milliseconds: 200),
                    curve: Tokens.easeInOut,
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

/// 精选首页：精选 / 歌单广场 / 排行榜，与官方客户端的顶部标签一致
class HomePage extends StatefulWidget {
  const HomePage({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late int _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Tokens.pageGutter, 4, Tokens.pageGutter, 8),
          child: UnderlineTabs(
            tabs: const ['精选', '歌单广场', '排行榜'],
            index: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
        ),
        Expanded(
          child: IndexedStack(index: _tab, children: const [_Featured(), _PlaylistSquare(), _Toplists()]),
        ),
      ],
    );
  }
}

/// 歌单广场：热门分类 + 无限滚动
class _PlaylistSquare extends StatefulWidget {
  const _PlaylistSquare();

  @override
  State<_PlaylistSquare> createState() => _PlaylistSquareState();
}

class _PlaylistSquareState extends State<_PlaylistSquare> {
  List<String> _cats = const ['全部'];
  String _cat = '全部';
  final List<PlaylistItem> _lists = [];
  int _total = 0;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    lib
        .playlistCategories()
        .then((c) {
          if (!mounted) return;
          setState(() => _cats = ['全部', ...c.where((x) => x.hot).map((x) => x.name)]);
        })
        .catchError((_) {});
    _more();
  }

  Future<void> _more() async {
    if (_loading || (_total > 0 && _lists.length >= _total)) return;
    setState(() => _loading = true);
    final cat = _cat;
    try {
      final (list, total) = await lib.topPlaylists(category: cat, offset: _lists.length);
      if (!mounted || cat != _cat) return;
      setState(() {
        _lists.addAll(list);
        _total = list.isEmpty ? _lists.length : total;
      });
    } catch (e) {
      AppState.I.notify('加载失败：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _select(String c) {
    setState(() {
      _cat = c;
      _lists.clear();
      _total = 0;
      _loading = false;
    });
    _more();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 600) _more();
        return false;
      },
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Tokens.pageGutter, 8, Tokens.pageGutter, 16),
            sliver: SliverToBoxAdapter(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in _cats)
                    Hover(
                      onTap: () => _select(c),
                      builder: (_, h) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: c == _cat ? Tokens.accentSoft : (h ? p.hoverStrong : p.field),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          c,
                          style: TextStyle(fontSize: 13, color: c == _cat ? Tokens.accent : p.textSecondary),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Tokens.pageGutter, 0, Tokens.pageGutter, 12),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 190,
                mainAxisSpacing: 20,
                crossAxisSpacing: 20,
                childAspectRatio: 0.74,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => PlaylistCard(item: _lists[i]),
                childCount: _lists.length,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 56,
              child: Center(
                child: _loading
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Tokens.accent),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 排行榜：官方榜单
class _Toplists extends StatefulWidget {
  const _Toplists();

  @override
  State<_Toplists> createState() => _ToplistsState();
}

class _ToplistsState extends State<_Toplists> {
  late Future<List<PlaylistItem>> _future = lib.toplists();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AsyncView<List<PlaylistItem>>(
      future: _future,
      onRetry: () => setState(() => _future = lib.toplists()),
      builder: (context, list) => CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Tokens.pageGutter, 8, Tokens.pageGutter, Tokens.pageGutter),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 190,
                mainAxisSpacing: 20,
                crossAxisSpacing: 20,
                childAspectRatio: 0.78,
              ),
              delegate: SliverChildBuilderDelegate((context, i) {
                final t = list[i];
                return Hover(
                  onTap: () => Nav.push('playlist:${t.id}', PlaylistPage(id: t.id)),
                  builder: (_, h) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutBuilder(
                        builder: (context, c) => Stack(
                          children: [
                            CardCover(url: t.coverUrl, size: c.maxWidth, hovered: h),
                            if (t.updateFrequency != null)
                              Positioned(
                                left: 8,
                                bottom: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black45,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    t.updateFrequency!,
                                    style: const TextStyle(color: Colors.white, fontSize: 11),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        t.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: p.textPrimary),
                      ),
                    ],
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

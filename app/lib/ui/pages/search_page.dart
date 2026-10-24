import 'package:flutter/material.dart';

import '../../src/rust/api/library.dart' as lib;
import '../../src/rust/api/types.dart';
import '../../state.dart';
import '../../theme.dart';
import '../song_list.dart';
import '../widgets.dart';
import 'album_page.dart';
import 'home_page.dart';

/// 搜索结果：单曲 / 歌单 / 专辑 / 歌手
class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.keywords, this.initialTab = 0});

  final String keywords;
  final int initialTab;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late int _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final k = widget.keywords;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 4, 28, 4),
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: '搜索 ',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                TextSpan(
                  text: k,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Tokens.accent),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 8),
          child: UnderlineTabs(
            tabs: const ['单曲', '歌单', '专辑', '歌手'],
            index: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _tab,
            children: [
              _Paged<SongItem>(
                key: ValueKey('s$k'),
                load: (offset) => lib.searchSongs(keywords: k, offset: offset, limit: 50),
                header: (items) => PillButton(
                  label: '播放全部',
                  icon: Icons.play_arrow_rounded,
                  primary: true,
                  onTap: () => AppState.I.playSongs(items, 0),
                ),
                sliver: (items) => [
                  const SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: 28),
                    sliver: SliverToBoxAdapter(child: SongListHeader()),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(28, 4, 28, 0),
                    sliver: SliverSongList(songs: items),
                  ),
                ],
              ),
              _Paged<PlaylistItem>(
                key: ValueKey('p$k'),
                load: (offset) => lib.searchPlaylists(keywords: k, offset: offset),
                sliver: (items) => [
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 190,
                        mainAxisSpacing: 20,
                        crossAxisSpacing: 20,
                        childAspectRatio: 0.74,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => PlaylistCard(item: items[i]),
                        childCount: items.length,
                      ),
                    ),
                  ),
                ],
              ),
              _Paged<AlbumCard>(
                key: ValueKey('a$k'),
                load: (offset) => lib.searchAlbums(keywords: k, offset: offset),
                sliver: (items) => [
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    sliver: AlbumGrid(albums: items),
                  ),
                ],
              ),
              _Paged<ArtistCard>(
                key: ValueKey('r$k'),
                load: (offset) => lib.searchArtists(keywords: k, offset: offset),
                sliver: (items) => [
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 160,
                        mainAxisSpacing: 18,
                        crossAxisSpacing: 20,
                        childAspectRatio: 0.82,
                      ),
                      delegate: SliverChildBuilderDelegate((context, i) {
                        final a = items[i];
                        return Hover(
                          onTap: () => openArtist(a.id),
                          builder: (_, h) => Column(
                            children: [
                              LayoutBuilder(
                                builder: (context, c) => AnimatedScale(
                                  scale: h ? 1.04 : 1,
                                  duration: const Duration(milliseconds: 200),
                                  child: ClipOval(
                                    child: Cover(
                                      url: a.coverUrl,
                                      size: c.maxWidth,
                                      radius: 0,
                                      icon: Icons.person_rounded,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                a.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        );
                      }, childCount: items.length),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 分页加载的结果列表：滚到底部附近自动加载下一页
class _Paged<T> extends StatefulWidget {
  const _Paged({super.key, required this.load, required this.sliver, this.header});

  final Future<(List<T>, int)> Function(int offset) load;
  final List<Widget> Function(List<T> items) sliver;
  final Widget Function(List<T> items)? header;

  @override
  State<_Paged<T>> createState() => _PagedState<T>();
}

class _PagedState<T> extends State<_Paged<T>> {
  final List<T> _items = [];
  int _total = 0;
  bool _loading = false;
  bool _done = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _more();
  }

  Future<void> _more() async {
    if (_loading || _done) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final (list, total) = await widget.load(_items.length);
      setState(() {
        _items.addAll(list);
        _total = total;
        _done = list.isEmpty || _items.length >= total;
      });
    } catch (e) {
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (_items.isEmpty) {
      if (_error != null) {
        return EmptyState(
          icon: Icons.wifi_off_rounded,
          text: '搜索失败：$_error',
          action: PillButton(label: '重试', onTap: _more),
        );
      }
      if (_loading) return const Center(child: CircularProgressIndicator(strokeWidth: 2.5, color: Tokens.accent));
      return const EmptyState(icon: Icons.search_off_rounded, text: '没有找到相关结果');
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 600) _more();
        return false;
      },
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(28, 4, 28, 12),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Text('找到 $_total 个结果', style: TextStyle(color: p.textTertiary, fontSize: 13)),
                  const Spacer(),
                  if (widget.header != null) widget.header!(_items),
                ],
              ),
            ),
          ),
          ...widget.sliver(_items),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 64,
              child: Center(
                child: _loading
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Tokens.accent),
                      )
                    : _done
                    ? Text('没有更多了', style: TextStyle(color: p.textTertiary, fontSize: 13))
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

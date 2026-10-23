import 'package:flutter/material.dart';

import '../../src/rust/api/library.dart' as lib;
import '../../src/rust/api/types.dart';
import '../../state.dart';
import '../../theme.dart';
import '../song_list.dart';
import '../widgets.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.keywords});

  final String keywords;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static const _pageSize = 50;
  final List<SongItem> _songs = [];
  int _total = 0;
  bool _loading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _more();
  }

  Future<void> _more() async {
    if (_loading || (_total > 0 && _songs.length >= _total)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final (list, total) = await lib.searchSongs(keywords: widget.keywords, offset: _songs.length, limit: _pageSize);
      setState(() {
        _songs.addAll(list);
        _total = list.isEmpty ? _songs.length : total;
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
    if (_songs.isEmpty) {
      if (_error != null) {
        return EmptyState(
          icon: Icons.wifi_off_rounded,
          text: '搜索失败：$_error',
          action: PillButton(label: '重试', onTap: _more),
        );
      }
      if (_loading) return const Center(child: CircularProgressIndicator(strokeWidth: 2.5, color: Tokens.accent));
      return EmptyState(icon: Icons.search_off_rounded, text: '没有找到「${widget.keywords}」相关的歌曲');
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 600) _more();
        return false;
      },
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(32, 12, 32, 16),
            sliver: SliverToBoxAdapter(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(
                          text: '搜索 ',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                        ),
                        TextSpan(
                          text: widget.keywords,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Tokens.accent),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text('找到 $_total 首单曲', style: TextStyle(color: p.textTertiary, fontSize: 13)),
                  ),
                  const Spacer(),
                  PillButton(
                    label: '播放全部',
                    icon: Icons.play_arrow_rounded,
                    primary: true,
                    onTap: () => AppState.I.playSongs(_songs, 0),
                  ),
                ],
              ),
            ),
          ),
          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            sliver: SliverToBoxAdapter(child: SongListHeader()),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(32, 6, 32, 0),
            sliver: SliverSongList(songs: _songs),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 64,
              child: Center(
                child: _loading
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Tokens.accent),
                      )
                    : _songs.length >= _total
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

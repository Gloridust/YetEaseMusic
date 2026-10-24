import 'package:flutter/material.dart';

import '../../src/rust/api/library.dart' as lib;
import '../../src/rust/api/types.dart';
import '../../state.dart';
import '../../theme.dart';
import '../song_list.dart';
import '../song_actions.dart';
import '../widgets.dart';
import 'album_page.dart';

/// 歌单详情；`daily` 为 true 时展示每日推荐
class PlaylistPage extends StatefulWidget {
  const PlaylistPage({super.key, required this.id}) : daily = false;
  const PlaylistPage.daily({super.key}) : id = 0, daily = true;

  final int id;
  final bool daily;

  @override
  State<PlaylistPage> createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  late Future<PlaylistDetailInfo> _future = _load();
  String _filter = '';

  Future<PlaylistDetailInfo> _load() async {
    if (!widget.daily) return lib.playlistDetail(id: widget.id);
    final songs = await lib.dailySongs();
    final now = DateTime.now();
    return PlaylistDetailInfo(
      summary: PlaylistItem(
        id: 0,
        name: '每日推荐',
        coverUrl: songs.isEmpty ? null : songs.first.coverUrl,
        trackCount: songs.length,
        playCount: 0,
        creatorName: '${now.month}月${now.day}日 · 根据你的口味生成',
        creatorId: 0,
        subscribed: false,
        specialType: 0,
      ),
      tracks: songs,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AsyncView<PlaylistDetailInfo>(
      future: _future,
      onRetry: () => setState(() => _future = _load()),
      builder: (context, d) {
        final q = _filter.trim().toLowerCase();
        final tracks = q.isEmpty
            ? d.tracks
            : d.tracks
                  .where(
                    (s) =>
                        s.name.toLowerCase().contains(q) ||
                        s.albumName.toLowerCase().contains(q) ||
                        s.artists.any((a) => a.name.toLowerCase().contains(q)),
                  )
                  .toList();
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 16),
              sliver: SliverToBoxAdapter(
                child: _Header(d: d, onFilter: (v) => setState(() => _filter = v)),
              ),
            ),
            if (tracks.isEmpty)
              SliverFillRemaining(hasScrollBody: false, child: EmptyState(text: q.isEmpty ? '空空如也' : '没有匹配的歌曲'))
            else ...[
              const SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 28),
                sliver: SliverToBoxAdapter(child: SongListHeader()),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(28, 4, 28, 28),
                sliver: SliverSongList(songs: tracks),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.d, required this.onFilter});

  final PlaylistDetailInfo d;
  final ValueChanged<String> onFilter;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = d.summary;
    final liked = s.specialType == 5;
    return LayoutBuilder(
      builder: (context, c) {
        final coverSize = c.maxWidth > 700 ? 176.0 : 128.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                liked
                    ? Container(
                        width: coverSize,
                        height: coverSize,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(Tokens.radiusL),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF6B7A), Tokens.accent],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Icon(Icons.favorite_rounded, color: Colors.white, size: coverSize * 0.42),
                      )
                    : Cover(url: s.coverUrl, size: coverSize, radius: Tokens.radiusL),
                const SizedBox(width: 28),
                Expanded(
                  child: SizedBox(
                    height: coverSize,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Text(
                          s.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700, height: 1.25),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          [
                            if (s.creatorName != null) s.creatorName!,
                            if (s.trackCount > 0) '${d.tracks.length} 首',
                            if (s.playCount > 0) '播放 ${formatCount(s.playCount)}',
                          ].join('  ·  '),
                          style: TextStyle(color: p.textSecondary, fontSize: 13),
                        ),
                        if (d.description != null && d.description!.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            d.description!.trim(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: p.textTertiary, fontSize: 13, height: 1.5),
                          ),
                        ],
                        const Spacer(),
                        Row(
                          children: [
                            PillButton(
                              label: '播放全部',
                              icon: Icons.play_arrow_rounded,
                              primary: true,
                              onTap: d.tracks.isEmpty ? null : () => AppState.I.playSongs(d.tracks, 0),
                            ),
                            const SizedBox(width: 12),
                            PillButton(
                              label: '随机播放',
                              icon: Icons.shuffle_rounded,
                              onTap: d.tracks.isEmpty
                                  ? null
                                  : () {
                                      final list = [...d.tracks]..shuffle();
                                      AppState.I.playSongs(list, 0);
                                    },
                            ),
                            const SizedBox(width: 10),
                            PillButton(
                              label: '下载全部',
                              icon: Icons.download_outlined,
                              onTap: d.tracks.isEmpty ? null : () => downloadSongs(d.tracks),
                            ),
                            // 别人的歌单才显示收藏（自己创建的、每日推荐不显示）
                            if (s.id > 0 && s.creatorId != AppState.I.account.value?.userId) ...[
                              const SizedBox(width: 10),
                              SubscribeButton(
                                initial: Future.value(s.subscribed),
                                onChange: (on) => lib.setPlaylistSubscribed(id: s.id, enable: on),
                                confirmOff: '网易云要求人机验证，第三方客户端无法重新收藏歌单。取消后如需恢复，只能在手机 App 中重新收藏。',
                              ),
                            ],
                            const Spacer(),
                            _FilterField(onChanged: onFilter),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _FilterField extends StatelessWidget {
  const _FilterField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      width: 180,
      height: 32,
      child: TextField(
        onChanged: onChanged,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: '搜索歌单内歌曲',
          hintStyle: TextStyle(color: p.textTertiary, fontSize: 13),
          prefixIcon: Icon(Icons.search_rounded, size: 18, color: p.textTertiary),
          filled: true,
          fillColor: p.field,
          isDense: true,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
        ),
      ),
    );
  }
}

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../src/rust/api/library.dart' as lib;
import '../../src/rust/api/types.dart';
import '../../state.dart';
import '../../theme.dart';
import '../login_dialog.dart';
import '../nav.dart';
import '../song_actions.dart';
import '../song_list.dart';
import '../widgets.dart';

/// 打开专辑页
void openAlbum(int id) {
  if (id <= 0) return;
  AppState.I.nowPlayingOpen.value = false;
  Nav.push('album:$id', AlbumPage(id: id));
}

class AlbumPage extends StatefulWidget {
  const AlbumPage({super.key, required this.id});

  final int id;

  @override
  State<AlbumPage> createState() => _AlbumPageState();
}

class _AlbumPageState extends State<AlbumPage> {
  late Future<AlbumPageInfo> _future = lib.albumDetail(id: widget.id);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AsyncView<AlbumPageInfo>(
      future: _future,
      onRetry: () => setState(() => _future = lib.albumDetail(id: widget.id)),
      builder: (context, d) {
        final a = d.album;
        final date = a.publishTimeMs > 0 ? DateTime.fromMillisecondsSinceEpoch(a.publishTimeMs) : null;
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(Tokens.pageGutter, 8, Tokens.pageGutter, 16),
              sliver: SliverToBoxAdapter(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 专辑封面右侧露出一截唱片，和官方专辑页的样式一致
                    SizedBox(
                      width: 208,
                      height: 176,
                      child: Stack(
                        children: [
                          Positioned(
                            left: 44,
                            top: 8,
                            child: ClipOval(child: Container(width: 160, height: 160, color: const Color(0xFF1B1B1D))),
                          ),
                          Cover(url: a.coverUrl, size: 176, radius: Tokens.radiusL),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: SizedBox(
                        height: 176,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Tag('专辑'),
                            const SizedBox(height: 6),
                            Text(
                              a.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 16,
                              children: [
                                LinkText(
                                  '歌手：${a.artistName}',
                                  onTap: a.artistId > 0 ? () => openArtist(a.artistId) : null,
                                ),
                                if (date != null)
                                  Text(
                                    '发行：${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                                    style: TextStyle(color: p.textSecondary, fontSize: 13),
                                  ),
                                if (a.company != null)
                                  Text('${a.company}', style: TextStyle(color: p.textTertiary, fontSize: 13)),
                              ],
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                PillButton(
                                  label: '播放全部',
                                  icon: Icons.play_arrow_rounded,
                                  primary: true,
                                  onTap: d.songs.isEmpty ? null : () => AppState.I.playSongs(d.songs, 0),
                                ),
                                const SizedBox(width: 10),
                                PillButton(
                                  label: '下载',
                                  icon: Icons.download_outlined,
                                  onTap: d.songs.isEmpty ? null : () => downloadSongs(d.songs),
                                ),
                                const SizedBox(width: 10),
                                SubscribeButton(
                                  initial: AppState.I.account.value == null
                                      ? Future.value(false)
                                      : lib.albumSubscribed(id: a.id),
                                  onChange: (on) => lib.setAlbumSubscribed(id: a.id, enable: on),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: Tokens.pageGutter),
              sliver: SliverToBoxAdapter(child: SongListHeader()),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(Tokens.pageGutter, 4, Tokens.pageGutter, 16),
              sliver: SliverSongList(songs: d.songs),
            ),
            if (a.description != null)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(Tokens.pageGutter, 8, Tokens.pageGutter, 32),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('专辑介绍', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text(a.description!, style: TextStyle(color: p.textSecondary, fontSize: 13, height: 1.7)),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// 打开歌手页
void openArtist(int id) {
  if (id <= 0) return;
  AppState.I.nowPlayingOpen.value = false;
  Nav.push('artist:$id', ArtistPage(id: id));
}

class ArtistPage extends StatefulWidget {
  const ArtistPage({super.key, required this.id});

  final int id;

  @override
  State<ArtistPage> createState() => _ArtistPageState();
}

class _ArtistPageState extends State<ArtistPage> {
  late Future<ArtistPageInfo> _future = lib.artistDetail(id: widget.id);
  int _tab = 0;
  final List<AlbumCard> _albums = [];
  bool _albumsMore = true;
  bool _albumsLoading = false;

  Future<void> _loadAlbums() async {
    if (_albumsLoading || !_albumsMore) return;
    setState(() => _albumsLoading = true);
    try {
      final (list, more) = await lib.artistAlbums(id: widget.id, offset: _albums.length);
      setState(() {
        _albums.addAll(list);
        _albumsMore = more && list.isNotEmpty;
      });
    } catch (e) {
      AppState.I.notify('专辑加载失败：$e');
    } finally {
      if (mounted) setState(() => _albumsLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AsyncView<ArtistPageInfo>(
      future: _future,
      onRetry: () => setState(() => _future = lib.artistDetail(id: widget.id)),
      builder: (context, d) {
        final a = d.artist;
        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (_tab == 1 && n.metrics.extentAfter < 500) _loadAlbums();
            return false;
          },
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(Tokens.pageGutter, 8, Tokens.pageGutter, 16),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Cover(url: a.coverUrl, size: 176, radius: Tokens.radiusL, icon: Icons.person_rounded),
                      const SizedBox(width: 24),
                      Expanded(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 176),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Tag('歌手'),
                              const SizedBox(height: 6),
                              Text(a.name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
                              if (a.alias.isNotEmpty)
                                Text(a.alias.join(' / '), style: TextStyle(color: p.textTertiary, fontSize: 13)),
                              const SizedBox(height: 8),
                              Text(
                                '单曲 ${a.songCount}  ·  专辑 ${a.albumCount}',
                                style: TextStyle(color: p.textSecondary, fontSize: 13),
                              ),
                              if (a.brief != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  a.brief!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: p.textTertiary, fontSize: 13, height: 1.5),
                                ),
                              ],
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  PillButton(
                                    label: '播放热门歌曲',
                                    icon: Icons.play_arrow_rounded,
                                    primary: true,
                                    onTap: d.hotSongs.isEmpty ? null : () => AppState.I.playSongs(d.hotSongs, 0),
                                  ),
                                  const SizedBox(width: 10),
                                  SubscribeButton(
                                    initial: Future.value(a.followed),
                                    labels: const ('关注', '已关注'),
                                    onChange: (on) => lib.setArtistFollowed(id: a.id, enable: on),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(Tokens.pageGutter, 0, Tokens.pageGutter, 12),
                sliver: SliverToBoxAdapter(
                  child: UnderlineTabs(
                    tabs: const ['热门 50 首', '专辑'],
                    index: _tab,
                    onChanged: (i) {
                      setState(() => _tab = i);
                      if (i == 1 && _albums.isEmpty) _loadAlbums();
                    },
                  ),
                ),
              ),
              if (_tab == 0) ...[
                const SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: Tokens.pageGutter),
                  sliver: SliverToBoxAdapter(child: SongListHeader()),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(Tokens.pageGutter, 4, Tokens.pageGutter, Tokens.pageGutter),
                  sliver: SliverSongList(songs: d.hotSongs),
                ),
              ] else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(Tokens.pageGutter, 4, Tokens.pageGutter, Tokens.pageGutter),
                  sliver: AlbumGrid(albums: _albums),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// 专辑网格（歌手页、搜索页共用）
class AlbumGrid extends StatelessWidget {
  const AlbumGrid({super.key, required this.albums});

  final List<AlbumCard> albums;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        mainAxisSpacing: 18,
        crossAxisSpacing: 20,
        childAspectRatio: 0.72,
      ),
      delegate: SliverChildBuilderDelegate((context, i) {
        final a = albums[i];
        final year = a.publishTimeMs > 0 ? DateTime.fromMillisecondsSinceEpoch(a.publishTimeMs).year : null;
        return Hover(
          onTap: () => openAlbum(a.id),
          builder: (_, h) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, c) => AnimatedScale(
                  scale: h ? 1.03 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: Cover(url: a.coverUrl, size: c.maxWidth, radius: Tokens.radiusL, icon: Icons.album_rounded),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                a.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
              Text(
                [a.artistName, if (year != null) '$year'].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: p.textTertiary),
              ),
            ],
          ),
        );
      }, childCount: albums.length),
    );
  }
}

/// 可点击的文字（悬停变色加下划线）
class LinkText extends StatelessWidget {
  const LinkText(this.text, {super.key, this.onTap, this.style});

  final String text;
  final VoidCallback? onTap;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final base = style ?? TextStyle(color: p.textSecondary, fontSize: 13);
    if (onTap == null) return Text(text, style: base, maxLines: 1, overflow: TextOverflow.ellipsis);
    return Hover(
      onTap: onTap,
      builder: (_, h) => Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: base.copyWith(
          color: h ? (base.color == Colors.white60 ? Colors.white : Tokens.accent) : base.color,
          decoration: h ? TextDecoration.underline : null,
          decorationColor: base.color,
        ),
      ),
    );
  }
}

/// 歌手名列表，每个名字单独可点；放不下时整体省略（合唱歌曲可能有几十位歌手）
class ArtistLinks extends StatefulWidget {
  const ArtistLinks({super.key, required this.artists, this.style});

  final List<ArtistItem> artists;
  final TextStyle? style;

  @override
  State<ArtistLinks> createState() => _ArtistLinksState();
}

class _ArtistLinksState extends State<ArtistLinks> {
  final List<TapGestureRecognizer> _taps = [];
  int? _hover;

  @override
  void dispose() {
    for (final t in _taps) {
      t.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final t in _taps) {
      t.dispose();
    }
    _taps.clear();
    final base = widget.style ?? TextStyle(color: context.palette.textSecondary, fontSize: 13);
    final hoverColor = base.color == Colors.white60 ? Colors.white : Tokens.accent;
    final spans = <InlineSpan>[];
    for (var i = 0; i < widget.artists.length; i++) {
      final a = widget.artists[i];
      if (i > 0) spans.add(const TextSpan(text: ' / '));
      if (a.id <= 0) {
        spans.add(TextSpan(text: a.name));
        continue;
      }
      final tap = TapGestureRecognizer()..onTap = () => openArtist(a.id);
      _taps.add(tap);
      spans.add(
        TextSpan(
          text: a.name,
          recognizer: tap,
          mouseCursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = i),
          onExit: (_) => setState(() => _hover = null),
          style: _hover == i
              ? TextStyle(color: hoverColor, decoration: TextDecoration.underline, decorationColor: hoverColor)
              : null,
        ),
      );
    }
    return Text.rich(
      TextSpan(style: base, children: spans),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// 收藏 / 关注按钮：乐观更新，失败时回滚并提示
class SubscribeButton extends StatefulWidget {
  const SubscribeButton({
    super.key,
    required this.initial,
    required this.onChange,
    this.labels = const ('收藏', '已收藏'),
    this.confirmOff,
  });

  final Future<bool> initial;
  final Future<void> Function(bool on) onChange;
  final (String, String) labels;

  /// 设置后，取消前先弹窗确认（比如取消收藏歌单后无法在本客户端重新收藏）
  final String? confirmOff;

  @override
  State<SubscribeButton> createState() => _SubscribeButtonState();
}

class _SubscribeButtonState extends State<SubscribeButton> {
  bool? _on;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    widget.initial
        .then((v) {
          if (mounted) setState(() => _on = v);
        })
        .catchError((_) {
          if (mounted) setState(() => _on = false);
        });
  }

  Future<void> _toggle() async {
    if (AppState.I.account.value == null) {
      await showLoginDialog(context);
      return;
    }
    final before = _on ?? false;
    if (before && widget.confirmOff != null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('取消${widget.labels.$1}？'),
          content: Text(widget.confirmOff!),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('再想想')),
            TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('仍然取消')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() {
      _on = !before;
      _busy = true;
    });
    try {
      await widget.onChange(!before);
      AppState.I.notify(!before ? '已${widget.labels.$1}' : '已取消${widget.labels.$1}');
    } catch (e) {
      if (mounted) setState(() => _on = before);
      AppState.I.notify('${widget.labels.$1}失败：${friendlyError(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final on = _on ?? false;
    return PillButton(
      label: on ? widget.labels.$2 : widget.labels.$1,
      icon: on ? Icons.check_rounded : Icons.add_rounded,
      onTap: _on == null || _busy ? null : _toggle,
    );
  }
}

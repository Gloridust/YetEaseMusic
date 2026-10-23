import 'package:flutter/material.dart';

import '../../src/rust/api/library.dart' as lib;
import '../../src/rust/api/types.dart';
import '../../state.dart';
import '../../theme.dart';
import '../nav.dart';
import '../song_list.dart';
import '../widgets.dart';

/// 播客：我订阅的 + 为你推荐
class PodcastPage extends StatefulWidget {
  const PodcastPage({super.key});

  @override
  State<PodcastPage> createState() => _PodcastPageState();
}

class _PodcastPageState extends State<PodcastPage> with AccountAware {
  late Future<(List<RadioItem>, List<RadioItem>)> _future = _load();

  Future<(List<RadioItem>, List<RadioItem>)> _load() async {
    final rec = lib.recommendRadios(limit: 18);
    final mine = AppState.I.account.value == null
        ? Future.value(<RadioItem>[])
        : lib.subscribedRadios().catchError((_) => <RadioItem>[]);
    return (await mine, await rec);
  }

  @override
  void onAccountChanged() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return AsyncView<(List<RadioItem>, List<RadioItem>)>(
      future: _future,
      onRetry: onAccountChanged,
      builder: (context, data) {
        final (mine, rec) = data;
        return CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: PageHeader(title: '播客')),
            if (mine.isNotEmpty) ...[const _Title('我的订阅'), _RadioGrid(mine)],
            const _Title('为你推荐'),
            _RadioGrid(rec),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ],
        );
      },
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => SliverPadding(
    padding: const EdgeInsets.fromLTRB(28, 4, 28, 12),
    sliver: SliverToBoxAdapter(
      child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
    ),
  );
}

class _RadioGrid extends StatelessWidget {
  const _RadioGrid(this.items);

  final List<RadioItem> items;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 20),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 180,
          mainAxisSpacing: 18,
          crossAxisSpacing: 20,
          childAspectRatio: 0.7,
        ),
        delegate: SliverChildBuilderDelegate((context, i) {
          final r = items[i];
          return Hover(
            onTap: () => Nav.push('radio:${r.id}', RadioPage(radio: r)),
            builder: (_, h) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, c) => AnimatedScale(
                    scale: h ? 1.03 : 1,
                    duration: const Duration(milliseconds: 200),
                    child: Cover(
                      url: r.coverUrl,
                      size: c.maxWidth,
                      radius: Tokens.radiusL,
                      icon: Icons.podcasts_rounded,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  r.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 2),
                Text(
                  r.djName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: p.textTertiary),
                ),
              ],
            ),
          );
        }, childCount: items.length),
      ),
    );
  }
}

/// 单个播客：节目列表，节目可直接播放
class RadioPage extends StatefulWidget {
  const RadioPage({super.key, required this.radio});

  final RadioItem radio;

  @override
  State<RadioPage> createState() => _RadioPageState();
}

class _RadioPageState extends State<RadioPage> {
  late final Future<(List<SongItem>, int)> _future = lib.radioPrograms(radioId: widget.radio.id, offset: 0);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final r = widget.radio;
    return AsyncView<(List<SongItem>, int)>(
      future: _future,
      builder: (context, data) {
        final (programs, total) = data;
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 16),
              sliver: SliverToBoxAdapter(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Cover(url: r.coverUrl, size: 160, radius: Tokens.radiusL, icon: Icons.podcasts_rounded),
                    const SizedBox(width: 24),
                    Expanded(
                      child: SizedBox(
                        height: 160,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.name,
                              maxLines: 2,
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${r.djName}  ·  $total 期  ·  ${formatCount(r.subCount)} 人订阅',
                              style: TextStyle(color: p.textSecondary, fontSize: 13),
                            ),
                            if (r.desc != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                r.desc!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: p.textTertiary, fontSize: 13),
                              ),
                            ],
                            const Spacer(),
                            PillButton(
                              label: '播放全部',
                              icon: Icons.play_arrow_rounded,
                              primary: true,
                              onTap: programs.isEmpty ? null : () => AppState.I.playSongs(programs, 0),
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
              padding: EdgeInsets.symmetric(horizontal: 28),
              sliver: SliverToBoxAdapter(child: SongListHeader()),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(28, 4, 28, 28),
              sliver: SliverSongList(songs: programs),
            ),
          ],
        );
      },
    );
  }
}

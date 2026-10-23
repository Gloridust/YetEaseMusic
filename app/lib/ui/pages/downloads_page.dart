import 'dart:io';

import 'package:flutter/material.dart';

import '../../src/rust/api/library.dart' as lib;
import '../../src/rust/api/types.dart';
import '../../state.dart';
import '../../theme.dart';
import '../song_list.dart';
import '../widgets.dart';

/// 下载管理：已下载 / 下载中
class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ValueListenableBuilder(
      valueListenable: AppState.I.downloadsTick,
      builder: (context, _, _) {
        final done = lib.downloads();
        final running = lib.downloading();
        return FutureBuilder(
          future: Future.wait([done, running]),
          builder: (context, snap) {
            final list = (snap.data?[0] as List<DownloadItem>?) ?? const <DownloadItem>[];
            final active = (snap.data?[1] as List<DownloadingItem>?) ?? const <DownloadingItem>[];
            final songs = list.map((d) => d.song).toList();
            final total = list.fold<int>(0, (a, d) => a + d.size);
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: PageHeader(
                    title: '下载管理',
                    actions: [
                      if (_tab == 0 && songs.isNotEmpty)
                        PillButton(
                          label: '播放全部',
                          icon: Icons.play_arrow_rounded,
                          primary: true,
                          onTap: () => AppState.I.playSongs(songs, 0),
                        ),
                      PillButton(label: '打开目录', icon: Icons.folder_open_rounded, onTap: _openDir),
                    ],
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 12),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        UnderlineTabs(
                          tabs: ['已下载 ${list.length}', '下载中 ${active.length}'],
                          index: _tab,
                          onChanged: (i) => setState(() => _tab = i),
                        ),
                        const Spacer(),
                        if (_tab == 0 && list.isNotEmpty)
                          Text('共 ${_size(total)}', style: TextStyle(color: p.textTertiary, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
                if (_tab == 0) ...[
                  if (list.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(icon: Icons.download_rounded, text: '还没有下载的歌曲\n在歌曲上点右键即可下载'),
                    )
                  else ...[
                    const SliverPadding(
                      padding: EdgeInsets.symmetric(horizontal: 28),
                      sliver: SliverToBoxAdapter(child: SongListHeader(lastLabel: '大小')),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(28, 4, 28, 28),
                      sliver: SliverSongList(songs: songs, lastColumn: list.map((d) => _size(d.size)).toList()),
                    ),
                  ],
                ] else if (active.isEmpty)
                  const SliverFillRemaining(hasScrollBody: false, child: EmptyState(text: '没有进行中的下载'))
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                    sliver: SliverList.builder(
                      itemCount: active.length,
                      itemBuilder: (context, i) => _ProgressRow(item: active[i]),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openDir() async {
    final dir = (await lib.getStorageSettings()).downloadDir;
    await Directory(dir).create(recursive: true);
    final cmd = Platform.isWindows ? 'explorer' : (Platform.isMacOS ? 'open' : 'xdg-open');
    await Process.run(cmd, [dir]);
  }
}

String _size(int bytes) {
  if (bytes >= 1 << 30) return '${(bytes / (1 << 30)).toStringAsFixed(1)} GB';
  if (bytes >= 1 << 20) return '${(bytes / (1 << 20)).toStringAsFixed(1)} MB';
  return '${(bytes / 1024).toStringAsFixed(0)} KB';
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.item});

  final DownloadingItem item;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = item.song;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Cover(url: s.coverUrl, size: 40, radius: Tokens.radiusS),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${s.name} - ${s.artists.map((a) => a.name).join(' / ')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: item.progress,
                    minHeight: 4,
                    color: Tokens.accent,
                    backgroundColor: p.divider,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 48,
            child: Text('${(item.progress * 100).round()}%', style: TextStyle(color: p.textTertiary, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

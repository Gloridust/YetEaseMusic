import 'package:flutter/material.dart';

import '../../src/rust/api/library.dart' as lib;
import '../../src/rust/api/types.dart';
import '../../state.dart';
import '../../theme.dart';
import '../song_list.dart';
import '../widgets.dart';

/// 本地音乐：扫描设置里的目录，标签与封面从文件读取
class LocalMusicPage extends StatefulWidget {
  const LocalMusicPage({super.key});

  /// 扫描结果在应用生命周期内缓存，避免每次进入都重新扫描
  static List<SongItem>? _cache;

  @override
  State<LocalMusicPage> createState() => _LocalMusicPageState();
}

class _LocalMusicPageState extends State<LocalMusicPage> {
  late Future<List<SongItem>> _future = _scan(force: false);
  String _filter = '';

  Future<List<SongItem>> _scan({required bool force}) async {
    if (!force && LocalMusicPage._cache != null) return LocalMusicPage._cache!;
    final list = await lib.scanLocalMusic();
    LocalMusicPage._cache = list;
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return AsyncView<List<SongItem>>(
      future: _future,
      onRetry: () => setState(() => _future = _scan(force: true)),
      builder: (context, all) {
        final q = _filter.trim().toLowerCase();
        final songs = q.isEmpty
            ? all
            : all
                  .where(
                    (s) =>
                        s.name.toLowerCase().contains(q) ||
                        s.albumName.toLowerCase().contains(q) ||
                        s.artists.any((a) => a.name.toLowerCase().contains(q)),
                  )
                  .toList();
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: PageHeader(
                title: '本地音乐',
                subtitle: '${all.length} 首',
                actions: [
                  if (all.isNotEmpty)
                    PillButton(
                      label: '播放全部',
                      icon: Icons.play_arrow_rounded,
                      primary: true,
                      onTap: () => AppState.I.playSongs(songs, 0),
                    ),
                  PillButton(
                    label: '重新扫描',
                    icon: Icons.refresh_rounded,
                    onTap: () => setState(() => _future = _scan(force: true)),
                  ),
                  PillButton(label: '选择目录', icon: Icons.folder_rounded, onTap: _editDirs),
                ],
              ),
            ),
            if (all.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.folder_off_rounded,
                  text: '没有找到本地音乐\n支持 mp3 / flac / m4a / ogg / wav 等格式',
                  action: PillButton(label: '选择目录', primary: true, onTap: _editDirs),
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 8),
                sliver: SliverToBoxAdapter(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: 200,
                      height: 32,
                      child: TextField(
                        onChanged: (v) => setState(() => _filter = v),
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: '搜索本地音乐',
                          prefixIcon: const Icon(Icons.search_rounded, size: 18),
                          filled: true,
                          fillColor: context.palette.field,
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 28),
                sliver: SliverToBoxAdapter(child: SongListHeader()),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(28, 4, 28, 28),
                sliver: SliverSongList(songs: songs),
              ),
            ],
          ],
        );
      },
    );
  }

  /// 编辑扫描目录：每行一个路径
  Future<void> _editDirs() async {
    final cur = await lib.getStorageSettings();
    if (!mounted) return;
    final ctl = TextEditingController(text: cur.localDirs.join('\n'));
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        final p = context.palette;
        return Dialog(
          backgroundColor: p.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tokens.radiusL)),
          child: SizedBox(
            width: 480,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('本地音乐目录', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text('每行一个目录，会递归扫描子目录', style: TextStyle(color: p.textSecondary, fontSize: 13)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: ctl,
                    minLines: 3,
                    maxLines: 8,
                    style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: p.field,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(Tokens.radiusM),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      PillButton(label: '取消', onTap: () => Navigator.of(context).pop(false)),
                      const SizedBox(width: 10),
                      PillButton(label: '保存并扫描', primary: true, onTap: () => Navigator.of(context).pop(true)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (ok != true) return;
    final dirs = ctl.text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    await lib.setStorageSettings(localDirs: dirs, downloadDir: cur.downloadDir);
    setState(() => _future = _scan(force: true));
  }
}

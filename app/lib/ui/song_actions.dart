import 'package:flutter/material.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart' show Int64List;
import 'package:flutter/services.dart';

import '../src/rust/api/library.dart' as lib;
import '../src/rust/api/playback.dart' as pb;
import '../src/rust/api/types.dart';
import '../state.dart';
import '../theme.dart';
import 'login_dialog.dart';
import 'nav.dart';
import 'pages/comments_page.dart';
import 'sidebar.dart';
import 'widgets.dart';

/// 歌曲右键菜单。列表行与播放栏「更多」共用。
Future<void> showSongMenu(BuildContext context, Offset globalPos, List<SongItem> songs, int index) async {
  final song = songs[index];
  final p = context.palette;
  // 界面缩放时 Overlay 处在缩放后的坐标系里，需要把全局坐标换算过去
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final at = overlay.globalToLocal(globalPos);
  PopupMenuItem<String> item(String v, IconData icon, String label) => PopupMenuItem(
    value: v,
    height: 38,
    child: Row(
      children: [
        Icon(icon, size: 18, color: p.textSecondary),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontSize: 14)),
      ],
    ),
  );
  final r = await showMenu<String>(
    context: context,
    position: RelativeRect.fromLTRB(at.dx, at.dy, overlay.size.width - at.dx, overlay.size.height - at.dy),
    color: p.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tokens.radiusM)),
    items: [
      item('play', Icons.play_circle_outline_rounded, '播放'),
      item('next', Icons.playlist_play_rounded, '下一首播放'),
      if (!song.local) ...[
        const PopupMenuDivider(height: 8),
        item('collect', Icons.library_add_outlined, '收藏到歌单'),
        item('download', Icons.download_outlined, '下载'),
        item('comments', Icons.chat_bubble_outline_rounded, '查看评论'),
        item('link', Icons.link_rounded, '复制歌曲链接'),
      ],
    ],
  );
  if (!context.mounted) return;
  switch (r) {
    case 'play':
      AppState.I.playSongs(songs, index);
    case 'next':
      await pb.enqueueNext(id: song.id);
      AppState.I.notify('已添加到下一首播放');
    case 'collect':
      await showCollectDialog(context, [song]);
    case 'download':
      downloadSongs([song]);
    case 'comments':
      openComments(song);
    case 'link':
      await Clipboard.setData(ClipboardData(text: 'https://music.163.com/song?id=${song.id}'));
      AppState.I.notify('链接已复制');
  }
}

void openComments(SongItem song) {
  AppState.I.nowPlayingOpen.value = false;
  Nav.push('comments:${song.id}', CommentsPage(song: song));
}

void downloadSongs(List<SongItem> songs) {
  final online = songs.where((s) => !s.local).toList();
  if (online.isEmpty) return;
  AppState.I.notify(online.length == 1 ? '开始下载《${online.first.name}》' : '开始下载 ${online.length} 首歌曲');
  lib.downloadSongs(ids: Int64List.fromList(online.map((s) => s.id).toList())).catchError((e) {
    AppState.I.notify('下载失败：$e');
  });
}

/// 收藏到歌单：列出自己创建的歌单（含「我喜欢的音乐」），也可以新建
Future<void> showCollectDialog(BuildContext context, List<SongItem> songs) async {
  final app = AppState.I;
  if (app.account.value == null) {
    await showLoginDialog(context);
    return;
  }
  final mine = app.myPlaylists.value.where((l) => !l.subscribed).toList();
  final picked = await showDialog<PlaylistItem>(
    context: context,
    builder: (context) {
      final p = context.palette;
      return Dialog(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tokens.radiusL)),
        child: SizedBox(
          width: 400,
          height: 520,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 12, 8),
                child: Row(
                  children: [
                    Text(
                      '收藏到歌单',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.textPrimary),
                    ),
                    const Spacer(),
                    IconBtn(Icons.close_rounded, onTap: () => Navigator.of(context).pop()),
                  ],
                ),
              ),
              Hover(
                onTap: () async {
                  Navigator.of(context).pop();
                  await showCreatePlaylistDialog(context);
                },
                builder: (_, h) => Container(
                  height: 56,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: h ? p.hover : Colors.transparent,
                    borderRadius: BorderRadius.circular(Tokens.radiusM),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(Tokens.radiusS)),
                        child: Icon(Icons.add_rounded, color: p.textSecondary),
                      ),
                      const SizedBox(width: 12),
                      const Text('新建歌单', style: TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  children: [
                    for (final l in mine)
                      Hover(
                        onTap: () => Navigator.of(context).pop(l),
                        builder: (_, h) => Container(
                          height: 56,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: h ? p.hover : Colors.transparent,
                            borderRadius: BorderRadius.circular(Tokens.radiusM),
                          ),
                          child: Row(
                            children: [
                              Cover(url: l.coverUrl, size: 40, radius: Tokens.radiusS),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l.specialType == 5 ? '我喜欢的音乐' : l.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    Text('${l.trackCount} 首', style: TextStyle(fontSize: 12, color: p.textTertiary)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  if (picked == null) return;
  try {
    await lib.addToPlaylist(playlistId: picked.id, songIds: Int64List.fromList(songs.map((s) => s.id).toList()));
    if (picked.specialType == 5) {
      app.likedIds.value = {...app.likedIds.value, ...songs.map((s) => s.id)};
    }
    app.notify('已收藏到「${picked.specialType == 5 ? '我喜欢的音乐' : picked.name}」');
    app.refreshAccount();
  } catch (e) {
    app.notify('收藏失败：$e');
  }
}

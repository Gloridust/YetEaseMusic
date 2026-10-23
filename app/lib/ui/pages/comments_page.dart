import 'package:flutter/material.dart';

import '../../src/rust/api/library.dart' as lib;
import '../../src/rust/api/types.dart';
import '../../theme.dart';
import '../widgets.dart';

/// 歌曲评论：精彩评论 + 最新评论（滚动加载）
class CommentsPage extends StatefulWidget {
  const CommentsPage({super.key, required this.song});

  final SongItem song;

  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  List<CommentItem> _hot = [];
  final List<CommentItem> _latest = [];
  int _total = 0;
  bool _more = true;
  bool _loading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading || !_more) return;
    setState(() => _loading = true);
    try {
      final before = _latest.isEmpty ? 0 : _latest.last.timeMs;
      final c = await lib.songComments(id: widget.song.id, offset: _latest.length, beforeMs: before);
      setState(() {
        if (_latest.isEmpty) _hot = c.hot;
        _latest.addAll(c.latest);
        _total = c.total;
        _more = c.more && c.latest.isNotEmpty;
        _error = null;
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
    final s = widget.song;
    if (_latest.isEmpty && _hot.isEmpty) {
      if (_error != null) {
        return EmptyState(
          icon: Icons.wifi_off_rounded,
          text: '评论加载失败：$_error',
          action: PillButton(label: '重试', onTap: _load),
        );
      }
      if (_loading) return const Center(child: CircularProgressIndicator(strokeWidth: 2.5, color: Tokens.accent));
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 500) _load();
        return false;
      },
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(28, 8, 28, 16),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Cover(url: s.coverUrl, size: 64),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(
                          s.artists.map((a) => a.name).join(' / '),
                          style: TextStyle(color: p.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Text('共 ${formatCount(_total)} 条评论', style: TextStyle(color: p.textTertiary, fontSize: 13)),
                ],
              ),
            ),
          ),
          if (_hot.isNotEmpty) ...[
            const _SectionTitle('精彩评论'),
            SliverList.builder(itemCount: _hot.length, itemBuilder: (_, i) => _CommentTile(_hot[i])),
          ],
          const _SectionTitle('最新评论'),
          SliverList.builder(itemCount: _latest.length, itemBuilder: (_, i) => _CommentTile(_latest[i])),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 64,
              child: Center(
                child: _loading
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Tokens.accent),
                      )
                    : Text(_more ? '' : '没有更多了', style: TextStyle(color: p.textTertiary, fontSize: 13)),
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
  Widget build(BuildContext context) => SliverPadding(
    padding: const EdgeInsets.fromLTRB(28, 12, 28, 4),
    sliver: SliverToBoxAdapter(
      child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
    ),
  );
}

class _CommentTile extends StatelessWidget {
  const _CommentTile(this.c);

  final CommentItem c;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 28),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipOval(
            child: Cover(url: c.userAvatar, size: 36, radius: 0, icon: Icons.person_rounded),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.userName, style: const TextStyle(fontSize: 13, color: Color(0xFF4A86C5))),
                const SizedBox(height: 4),
                SelectableText(c.content, style: TextStyle(fontSize: 14, height: 1.55, color: p.textPrimary)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(c.timeText ?? '', style: TextStyle(fontSize: 12, color: p.textTertiary)),
                    const Spacer(),
                    Icon(Icons.thumb_up_alt_outlined, size: 14, color: p.textTertiary),
                    const SizedBox(width: 4),
                    Text(
                      c.likedCount > 0 ? formatCount(c.likedCount) : '',
                      style: TextStyle(fontSize: 12, color: p.textTertiary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

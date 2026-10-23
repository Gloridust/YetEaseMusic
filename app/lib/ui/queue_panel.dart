import 'package:flutter/material.dart';

import '../src/rust/api/playback.dart' as pb;
import '../state.dart';
import '../theme.dart';
import 'widgets.dart';

/// 右侧抽屉：当前播放队列
class QueuePanel extends StatelessWidget {
  const QueuePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final app = AppState.I;
    return Drawer(
      width: 380,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(left: Radius.circular(Tokens.radiusL))),
      child: ListenableBuilder(
        listenable: Listenable.merge([app.queue, app.queueIndex]),
        builder: (context, _) {
          final q = app.queue.value;
          final cur = app.queueIndex.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                child: Row(
                  children: [
                    const Text('播放列表', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    Text('${q.length}', style: TextStyle(color: p.textTertiary)),
                  ],
                ),
              ),
              Divider(height: 1, color: p.divider),
              Expanded(
                child: q.isEmpty
                    ? const EmptyState(text: '播放列表是空的', icon: Icons.queue_music_rounded)
                    : ListView.builder(
                        itemCount: q.length,
                        itemExtent: 56,
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                        itemBuilder: (context, i) {
                          final s = q[i];
                          final playing = i == cur;
                          return Hover(
                            onDoubleTap: () => pb.playIndex(index: i),
                            onTap: Theme.of(context).platform == TargetPlatform.android
                                ? () => pb.playIndex(index: i)
                                : null,
                            builder: (_, h) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: playing ? Tokens.accentSoft : (h ? p.hover : Colors.transparent),
                                borderRadius: BorderRadius.circular(Tokens.radiusM),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          s.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: playing ? Tokens.accent : p.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          s.artists.map((a) => a.name).join(' / '),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: playing ? Tokens.accent.withValues(alpha: 0.8) : p.textTertiary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(formatMs(s.durationMs), style: TextStyle(fontSize: 12, color: p.textTertiary)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

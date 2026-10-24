import 'package:audio_service/audio_service.dart';

import 'src/rust/api/playback.dart' as pb;
import 'src/rust/api/types.dart';
import 'state.dart';
import 'theme.dart';

/// Android 媒体会话：把 Rust 播放器的状态同步给系统（通知栏、锁屏、蓝牙与方向盘按键），
/// 系统发来的控制命令转回 Rust。前台服务同时保证切到后台后继续播放。
Future<void> initAndroidMedia() async {
  final handler = await AudioService.init(
    builder: _RustAudioHandler.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'io.github.gloridust.yetease.playback',
      androidNotificationChannelName: '播放控制',
      // 暂停时也保持前台服务，避免 Android 12+ 后台无法重新启动前台服务
      androidStopForegroundOnPause: false,
      androidNotificationIcon: 'mipmap/ic_launcher',
    ),
  );
  handler._bind();
}

class _RustAudioHandler extends BaseAudioHandler with SeekHandler {
  void _bind() {
    final app = AppState.I;
    void syncItem() {
      final s = app.current.value;
      if (s == null) return;
      mediaItem.add(
        MediaItem(
          id: '${s.id}',
          title: s.name,
          artist: s.artists.map((a) => a.name).join(' / '),
          album: s.albumName,
          duration: Duration(milliseconds: app.duration.value > 0 ? app.duration.value : s.durationMs),
          artUri: switch (sizedImage(s.coverUrl, 512)) {
            final u? when !u.startsWith('/') => Uri.parse(u),
            final u? => Uri.file(u),
            null => null,
          },
        ),
      );
    }

    void syncState() {
      final st = app.playerState.value;
      final playing = st == PlayerState.playing;
      playbackState.add(
        playbackState.value.copyWith(
          controls: [
            MediaControl.skipToPrevious,
            playing ? MediaControl.pause : MediaControl.play,
            MediaControl.skipToNext,
          ],
          systemActions: const {MediaAction.seek, MediaAction.seekForward, MediaAction.seekBackward},
          androidCompactActionIndices: const [0, 1, 2],
          processingState: switch (st) {
            PlayerState.loading => AudioProcessingState.loading,
            PlayerState.stopped => app.current.value == null ? AudioProcessingState.idle : AudioProcessingState.ready,
            _ => AudioProcessingState.ready,
          },
          playing: playing,
          updatePosition: Duration(milliseconds: app.position.value),
          speed: 1.0,
        ),
      );
    }

    app.current.addListener(syncItem);
    app.duration.addListener(syncItem);
    app.playerState.addListener(syncState);
    // 位置只在跳转后同步，平时系统按 speed 自行推算
    var last = 0;
    app.position.addListener(() {
      final p = app.position.value;
      if ((p - last).abs() > 2000) syncState();
      last = p;
    });
    syncItem();
    syncState();
  }

  @override
  Future<void> play() => pb.resume();

  @override
  Future<void> pause() => pb.pause();

  @override
  Future<void> stop() => pb.pause();

  @override
  Future<void> skipToNext() => pb.next();

  @override
  Future<void> skipToPrevious() => pb.previous();

  @override
  Future<void> seek(Duration position) => pb.seek(positionMs: position.inMilliseconds);
}

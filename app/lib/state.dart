import 'dart:async';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart' show Int64List;

import 'package:flutter/material.dart';

import 'src/rust/api/library.dart' as lib;
import 'src/rust/api/playback.dart' as pb;
import 'src/rust/api/types.dart';

/// 全局界面状态。数据源都在 Rust，这里只是把事件变成可监听的值。
class AppState {
  AppState._();
  static final AppState I = AppState._();

  // 账号
  final account = ValueNotifier<AccountInfo?>(null);
  final myPlaylists = ValueNotifier<List<PlaylistItem>>(const []);
  final likedIds = ValueNotifier<Set<int>>(const {});

  // 播放
  final playerState = ValueNotifier(PlayerState.stopped);
  final position = ValueNotifier(0);
  final duration = ValueNotifier(0);
  final buffered = ValueNotifier(0.0);
  final current = ValueNotifier<SongItem?>(null);
  final queue = ValueNotifier<List<SongItem>>(const []);
  final queueIndex = ValueNotifier<int?>(null);
  final mode = ValueNotifier(PlayOrder.sequential);
  final volume = ValueNotifier(0.8);
  final settings = ValueNotifier<AppSettings?>(null);

  /// 当前歌曲的红心数与评论数（官方样式的 "100w+" / "1w+"）
  final likeCountText = ValueNotifier<String?>(null);
  final commentCountText = ValueNotifier<String?>(null);

  /// 系统媒体控件请求显示窗口时自增
  final raiseRequests = ValueNotifier(0);

  /// 下载列表或进度变化时自增，下载页据此刷新
  final downloadsTick = ValueNotifier(0);

  // 界面
  final nowPlayingOpen = ValueNotifier(false);
  final themeMode = ValueNotifier(ThemeMode.system);
  final uiScale = ValueNotifier(1.0);
  final _notices = StreamController<String>.broadcast();
  Stream<String> get notices => _notices.stream;

  bool get isPlaying => playerState.value == PlayerState.playing;

  Future<void> start() async {
    pb.events().listen(_onEvent);
    await _syncSnapshot();
    _applySettings(await pb.getSettings());
    await refreshAccount();
  }

  void notify(String msg) => _notices.add(msg);

  void _onEvent(UiEvent e) {
    switch (e) {
      case UiEvent_State(:final field0):
        playerState.value = field0;
      case UiEvent_Position(:final positionMs, :final durationMs, buffered: final b):
        position.value = positionMs;
        if (durationMs > 0) duration.value = durationMs;
        buffered.value = b;
      case UiEvent_TrackChanged(:final field0):
        current.value = field0;
        _loadCounts(field0);
        position.value = 0;
        duration.value = field0?.durationMs ?? 0;
        _syncSnapshot();
      case UiEvent_QueueChanged():
        _syncSnapshot();
      case UiEvent_SettingsChanged():
        pb.getSettings().then(_applySettings);
      case UiEvent_DownloadsChanged():
        downloadsTick.value++;
      case UiEvent_Raise():
        raiseRequests.value++;
      case UiEvent_Notice(:final field0):
        notify(field0);
      case UiEvent_Error(:final field0):
        notify('播放出错：$field0');
    }
  }

  void _applySettings(AppSettings s) {
    settings.value = s;
    mode.value = s.mode;
    volume.value = s.volume;
    uiScale.value = s.uiScale;
    themeMode.value = switch (s.theme) {
      ThemePref.light => ThemeMode.light,
      ThemePref.dark => ThemeMode.dark,
      ThemePref.system => ThemeMode.system,
    };
  }

  /// 修改外观偏好（立即生效并持久化）
  void setAppearance({double? scale, ThemeMode? theme}) {
    if (scale != null) uiScale.value = scale;
    if (theme != null) themeMode.value = theme;
    pb.setAppearance(
      uiScale: uiScale.value,
      theme: switch (themeMode.value) {
        ThemeMode.light => ThemePref.light,
        ThemeMode.dark => ThemePref.dark,
        ThemeMode.system => ThemePref.system,
      },
    );
  }

  Future<void> _loadCounts(SongItem? s) async {
    likeCountText.value = null;
    commentCountText.value = null;
    if (s == null || s.local) return;
    final id = s.id;
    lib
        .songLikeCount(id: id)
        .then((c) {
          if (current.value?.id == id) likeCountText.value = c.text;
        })
        .catchError((_) {});
    lib
        .songComments(id: id, offset: 0, beforeMs: 0)
        .then((c) {
          if (current.value?.id == id) commentCountText.value = shortCount(c.total);
        })
        .catchError((_) {});
  }

  Future<void> _syncSnapshot() async {
    final s = await pb.snapshot();
    playerState.value = s.state;
    current.value = s.current;
    queue.value = s.queue;
    queueIndex.value = s.queueIndex;
    mode.value = s.mode;
    volume.value = s.volume;
    if (s.durationMs > 0) duration.value = s.durationMs;
  }

  Future<void> refreshAccount() async {
    try {
      final a = await lib.account();
      account.value = a;
      if (a == null) {
        myPlaylists.value = const [];
        likedIds.value = const {};
        return;
      }
      final results = await Future.wait([lib.userPlaylists(userId: a.userId), lib.likedSongIds(userId: a.userId)]);
      myPlaylists.value = results[0] as List<PlaylistItem>;
      likedIds.value = (results[1] as Int64List).inner.toSet();
    } catch (e) {
      debugPrint('refreshAccount: $e');
    }
  }

  Future<void> logout() async {
    await lib.logout();
    await refreshAccount();
  }

  // ---------- 播放控制 ----------

  Future<void> playSongs(List<SongItem> songs, int index) async {
    if (songs.isEmpty) return;
    await pb.playSongs(ids: Int64List.fromList(songs.map((s) => s.id).toList()), index: index);
  }

  Future<void> toggleLike(SongItem s) async {
    if (account.value == null) {
      notify('登录后才能收藏歌曲');
      return;
    }
    final before = likedIds.value;
    final liked = before.contains(s.id);
    likedIds.value = liked ? ({...before}..remove(s.id)) : {...before, s.id};
    try {
      await lib.likeSong(id: s.id, like: !liked);
    } catch (e) {
      likedIds.value = before;
      notify('操作失败：$e');
    }
  }

  void cycleMode() {
    const order = [PlayOrder.sequential, PlayOrder.repeatAll, PlayOrder.repeatOne, PlayOrder.shuffle];
    final m = order[(order.indexOf(mode.value) + 1) % order.length];
    mode.value = m;
    pb.setMode(mode: m);
  }

  Future<void> pauseIfPlaying() async {
    if (isPlaying) await pb.pause();
  }

  void setVolume(double v) {
    volume.value = v;
    pb.setVolume(volume: v);
  }
}

/// 官方客户端的计数写法：999+ / 1w+ / 10w+ / 100w+
String shortCount(int n) {
  if (n >= 1000000) return '100w+';
  if (n >= 100000) return '10w+';
  if (n >= 10000) return '1w+';
  if (n >= 1000) return '999+';
  return n > 0 ? '$n' : '';
}

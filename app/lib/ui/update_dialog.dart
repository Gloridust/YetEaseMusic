import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../main.dart' show quitApp;
import '../src/rust/api/update.dart' as up;
import '../state.dart';
import '../system.dart';
import '../theme.dart';
import 'nav.dart';
import 'widgets.dart';

bool _checking = false;

/// 检查更新。`manual` 为 false 时是启动时的自动检查：出错不提示，没有新版本或已跳过的版本也不打扰
Future<void> checkForUpdates({bool manual = true}) async {
  if (_checking) return;
  _checking = true;
  try {
    if (manual) AppState.I.notify('正在检查更新…');
    final info = await up.checkUpdate();
    if (!manual && (!info.hasUpdate || info.latestVersion == AppState.I.settings.value?.skippedVersion)) return;
    final context = Nav.key.currentContext;
    if (context == null || !context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => UpdateDialog(info: info, automatic: !manual),
    );
  } catch (e) {
    if (manual) AppState.I.notify('检查更新失败：$e');
  } finally {
    _checking = false;
  }
}

enum _Stage { idle, downloading, installing, opened, failed }

class UpdateDialog extends StatefulWidget {
  const UpdateDialog({super.key, required this.info, this.automatic = false});

  final up.UpdateInfo info;

  /// 启动时自动弹出的（多一个「跳过此版本」）
  final bool automatic;

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  _Stage _stage = _Stage.idle;
  String? _error;
  double? _progress;
  Timer? _poll;

  up.UpdateInfo get info => widget.info;

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _stage = _Stage.downloading;
      _error = null;
      _progress = null;
    });
    _poll = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final p = up.updateDownloadProgress();
      if (mounted && p.total > 0) setState(() => _progress = p.received / p.total);
    });
    try {
      final dir = Directory('${(await getTemporaryDirectory()).path}/yetease-update');
      final path = await up.downloadUpdate(dir: dir.path);
      _poll?.cancel();
      if (!mounted) return;
      setState(() => _stage = _Stage.installing);
      if (info.method == up.UpdateMethod.apk) {
        final started = await installApk(path);
        if (!mounted) return;
        if (started) {
          Navigator.of(context).pop();
        } else {
          // 跳到了「允许安装未知应用」的设置页，回来后再点一次
          setState(() {
            _stage = _Stage.failed;
            _error = '请在打开的设置页里允许本应用安装应用，然后再点一次「下载并安装」';
          });
        }
        return;
      }
      final quit = await up.installUpdate(path: path);
      if (quit) {
        await quitApp();
      } else if (mounted) {
        setState(() => _stage = _Stage.opened);
      }
    } catch (e) {
      _poll?.cancel();
      if (!mounted) return;
      final msg = e.toString();
      if (msg.contains('已取消')) {
        setState(() => _stage = _Stage.idle);
      } else {
        setState(() {
          _stage = _Stage.failed;
          _error = msg;
        });
      }
    }
  }

  String get _primaryLabel => switch (info.method) {
    up.UpdateMethod.install => '立即更新',
    up.UpdateMethod.openDmg => '下载更新',
    up.UpdateMethod.apk => '下载并安装',
    up.UpdateMethod.flatpak || up.UpdateMethod.manual => '前往下载',
  };

  /// 安装方式的说明，显示在按钮上方
  String? get _methodHint => switch (info.method) {
    up.UpdateMethod.install when Platform.isLinux => '会下载新版本并替换当前安装，可能需要输入密码授权，完成后自动重新打开。',
    up.UpdateMethod.install => '会下载并安装新版本，完成后自动重新打开。',
    up.UpdateMethod.openDmg => '下载完成后会打开安装包，把 YetEase Music 拖进「应用程序」替换旧版本即可。',
    up.UpdateMethod.apk => '如果系统提示与已安装的应用冲突（早期版本每次发布的签名不同），需要先卸载旧版再安装。',
    up.UpdateMethod.flatpak => '通过 Flatpak 安装的版本请运行 flatpak update，或在软件商店里更新。',
    up.UpdateMethod.manual => '当前安装方式不支持应用内更新，请到发布页下载对应的安装包。',
  };

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final size = MediaQuery.sizeOf(context);
    final busy = _stage == _Stage.downloading || _stage == _Stage.installing;
    return Dialog(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tokens.radiusL)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 480, maxHeight: (size.height * 0.8).clamp(320, 640)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                info.hasUpdate ? '发现新版本 ${info.latestVersion}' : '已是最新版本',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                info.hasUpdate
                    ? '当前版本 ${info.currentVersion}${info.downloadSize > 0 ? ' · 安装包 ${_mb(info.downloadSize)}' : ''}'
                    : '当前版本 ${info.currentVersion}，以下是这个版本的更新内容',
                style: TextStyle(fontSize: 13, color: p.textSecondary),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: Container(
                  decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(Tokens.radiusM)),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: ReleaseNotesView(notes: info.notes),
                  ),
                ),
              ),
              if (info.hasUpdate) ...[
                const SizedBox(height: 14),
                if (_stage == _Stage.downloading || _stage == _Stage.installing) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: _stage == _Stage.installing ? null : _progress,
                      minHeight: 4,
                      color: Tokens.accent,
                      backgroundColor: p.hoverStrong,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _stage == _Stage.installing
                        ? '正在安装…'
                        : '正在下载${_progress == null ? '…' : ' ${(_progress! * 100).toStringAsFixed(0)}%'}',
                    style: TextStyle(fontSize: 13, color: p.textSecondary),
                  ),
                ] else if (_stage == _Stage.failed)
                  Text(_error ?? '更新失败', style: const TextStyle(fontSize: 13, color: Tokens.accent))
                else if (_stage == _Stage.opened)
                  Text(
                    '已打开安装包。把 YetEase Music 拖进「应用程序」替换旧版本，然后退出并重新打开本应用。',
                    style: TextStyle(fontSize: 13, color: p.textSecondary, height: 1.5),
                  )
                else if (_methodHint != null)
                  Text(_methodHint!, style: TextStyle(fontSize: 13, color: p.textSecondary, height: 1.5)),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  if (info.hasUpdate && widget.automatic && !busy)
                    _TextButton(
                      label: '跳过此版本',
                      onTap: () {
                        up.skipUpdateVersion(version: info.latestVersion);
                        Navigator.of(context).pop();
                      },
                    ),
                  const Spacer(),
                  if (busy)
                    PillButton(label: '取消', onTap: _stage == _Stage.downloading ? up.cancelUpdateDownload : null)
                  else ...[
                    PillButton(label: info.hasUpdate ? '稍后' : '关闭', onTap: () => Navigator.of(context).pop()),
                    if (info.hasUpdate) ...[
                      const SizedBox(width: 10),
                      if (_stage == _Stage.opened)
                        PillButton(label: '退出应用', primary: true, onTap: quitApp)
                      else
                        PillButton(
                          label: _stage == _Stage.failed ? '重试' : _primaryLabel,
                          primary: true,
                          onTap: switch (info.method) {
                            up.UpdateMethod.flatpak || up.UpdateMethod.manual => () => openExternal(info.pageUrl),
                            _ => _start,
                          },
                        ),
                    ],
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _mb(int bytes) => '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}

class _TextButton extends StatelessWidget {
  const _TextButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Hover(
      onTap: onTap,
      builder: (_, h) => Text(label, style: TextStyle(fontSize: 13, color: h ? p.textPrimary : p.textSecondary)),
    );
  }
}

/// 发布说明：只渲染用得到的 Markdown 子集（标题、列表、粗体、行内代码、链接文字）。
/// 每个版本的「下载」一节和分隔线后的英文说明不显示
class ReleaseNotesView extends StatelessWidget {
  const ReleaseNotesView({super.key, required this.notes});

  final List<up.ReleaseNote> notes;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final children = <Widget>[];
    for (final (i, n) in notes.indexed) {
      if (notes.length > 1) {
        children.add(
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 18, bottom: 6),
            child: Text(
              '${n.version}${n.date.isEmpty ? '' : ' · ${n.date}'}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        );
      }
      children.addAll(_render(n.body, p));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  static List<Widget> _render(String body, Palette p) {
    final out = <Widget>[];
    var skipping = false;
    for (final raw in body.split('\n')) {
      final line = raw.trimRight();
      if (line.trim() == '---') break;
      final heading = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(line);
      if (heading != null) {
        final title = heading.group(2)!.trim();
        skipping = title == '下载' || title.toLowerCase() == 'download';
        if (!skipping) {
          out.add(
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: Text.rich(_inline(title, p), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          );
        }
        continue;
      }
      if (skipping || line.trim().isEmpty || line.trimLeft().startsWith('|')) continue;
      final bullet = RegExp(r'^(\s*)[-*]\s+(.*)$').firstMatch(line);
      if (bullet != null) {
        final indent = bullet.group(1)!.length ~/ 2;
        out.add(
          Padding(
            padding: EdgeInsets.only(left: indent * 16.0, top: 3, bottom: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 14,
                  child: Text(indent == 0 ? '•' : '◦', style: TextStyle(color: p.textSecondary, height: 1.6)),
                ),
                Expanded(
                  child: Text.rich(_inline(bullet.group(2)!, p), style: const TextStyle(fontSize: 13, height: 1.6)),
                ),
              ],
            ),
          ),
        );
        continue;
      }
      out.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Text.rich(_inline(line.trim(), p), style: const TextStyle(fontSize: 13, height: 1.6)),
        ),
      );
    }
    return out;
  }

  /// **粗体**、`代码`、[文字](链接) → 文字
  static TextSpan _inline(String text, Palette p) {
    final spans = <InlineSpan>[];
    final re = RegExp(r'\*\*(.+?)\*\*|`([^`]+)`|\[([^\]]+)\]\([^)]*\)');
    var last = 0;
    for (final m in re.allMatches(text)) {
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
      if (m.group(1) != null) {
        spans.add(
          TextSpan(
            text: m.group(1),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        );
      } else if (m.group(2) != null) {
        spans.add(
          TextSpan(
            text: m.group(2),
            style: TextStyle(backgroundColor: p.hoverStrong),
          ),
        );
      } else {
        spans.add(TextSpan(text: m.group(3)));
      }
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return TextSpan(children: spans);
  }
}

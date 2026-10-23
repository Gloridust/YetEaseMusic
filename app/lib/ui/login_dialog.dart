import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../src/rust/api/library.dart' as lib;
import '../src/rust/api/types.dart';
import '../state.dart';
import '../theme.dart';
import 'widgets.dart';

Future<void> showLoginDialog(BuildContext context) {
  return showDialog(context: context, barrierColor: Colors.black38, builder: (_) => const _LoginDialog());
}

class _LoginDialog extends StatefulWidget {
  const _LoginDialog();

  @override
  State<_LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<_LoginDialog> {
  String? _key;
  String? _qr;
  String _status = '正在生成二维码…';
  String? _avatar;
  Timer? _timer;
  bool _checking = false;

  /// 二维码已失效（过期 / 失败 / 生成失败），需要用户点击刷新
  bool _dead = false;

  @override
  void initState() {
    super.initState();
    _create();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _create() async {
    _timer?.cancel();
    setState(() {
      _qr = null;
      _avatar = null;
      _dead = false;
      _status = '正在生成二维码…';
    });
    try {
      final (key, url) = await lib.qrCreate();
      if (!mounted) return;
      setState(() {
        _key = key;
        _qr = url;
        _status = '打开网易云音乐 App 扫码登录';
      });
      _timer = Timer.periodic(const Duration(seconds: 2), (_) => _check());
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = '生成失败：$e';
          _dead = true;
        });
      }
    }
  }

  Future<void> _check() async {
    if (_checking || _key == null) return;
    _checking = true;
    try {
      final st = await lib.qrCheck(key: _key!);
      if (!mounted) return;
      switch (st) {
        case QrState_Waiting():
          break;
        case QrState_Scanned(:final nickname, :final avatarUrl):
          setState(() {
            _status = '$nickname，请在手机上确认登录';
            _avatar = avatarUrl;
          });
        case QrState_Authorized():
          _timer?.cancel();
          setState(() => _status = '登录成功');
          await AppState.I.refreshAccount();
          if (mounted) Navigator.of(context).pop();
          AppState.I.notify('欢迎回来，${AppState.I.account.value?.nickname ?? ''}');
        case QrState_Expired():
          _timer?.cancel();
          setState(() {
            _status = '二维码已过期，请刷新后重新扫码';
            _dead = true;
          });
        case QrState_Failed(:final message):
          _timer?.cancel();
          setState(() {
            _status = '登录失败：$message';
            _dead = true;
          });
      }
    } catch (e) {
      debugPrint('qr check: $e');
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Dialog(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tokens.radiusL)),
      child: SizedBox(
        width: 360,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconBtn(Icons.close_rounded, onTap: () => Navigator.of(context).pop()),
              ),
              const Text('扫码登录', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 24),
              SizedBox.square(
                dimension: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Opacity(
                      opacity: _dead ? 0.15 : 1,
                      child: _avatar != null
                          ? ClipOval(child: Cover(url: _avatar, size: 120, radius: 60))
                          : _qr == null
                          ? (_dead
                                ? const SizedBox.shrink()
                                : const CircularProgressIndicator(strokeWidth: 2.5, color: Tokens.accent))
                          : QrImageView(data: _qr!, size: 200, padding: EdgeInsets.zero, backgroundColor: Colors.white),
                    ),
                    if (_dead) PillButton(label: '刷新二维码', icon: Icons.refresh_rounded, primary: true, onTap: _create),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _status,
                textAlign: TextAlign.center,
                style: TextStyle(color: p.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                '登录信息只保存在本机，不经过任何第三方服务器',
                textAlign: TextAlign.center,
                style: TextStyle(color: p.textTertiary, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

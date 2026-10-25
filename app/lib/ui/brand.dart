import 'dart:io';

import 'package:flutter/material.dart';

/// 应用显示名：中文系统显示「网易云音乐Yet」，其他语言显示 "YetEase Music"
final String kAppName = Platform.localeName.toLowerCase().startsWith('zh') ? '网易云音乐Yet' : 'YetEase Music';

/// 品牌色：与网易云的红保持同一色系
const kBrandRed = Color(0xFFEC4141);

/// 应用图标：扁平的红色圆角方形 + 白色蜗牛线条（外圈是壳，触须分叉成 Y）。
/// 图形与 tools/icons/generate.sh 一致；改动时两处一起改，再运行该脚本重新生成各平台图标。
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: const LogoPainter());
}

class LogoPainter extends CustomPainter {
  const LogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(w * 0.2)), Paint()..color = kBrandRed);

    // 图形按 0–100 的坐标画，缩放后放在中心（与生成脚本里主体 88、图形缩放 0.96 的比例相同）
    canvas.save();
    canvas.translate(w / 2, w / 2);
    canvas.scale(w / 100 * 0.96 / 0.88);
    canvas.translate(-49, -51.5);
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      // 侧栏里只有 30 左右，线条比大图标略粗才清楚
      ..strokeWidth = w <= 40 ? 8.5 : 7.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    const deg = 3.141592653589793 / 180;
    // 壳：右上方留出缺口，触须从缺口伸出
    canvas.drawArc(Rect.fromCircle(center: const Offset(48, 55), radius: 27), -35 * deg, 275 * deg, false, stroke);
    canvas.drawCircle(const Offset(48.5, 57), 10.5, stroke);
    // 颈部向上，在顶端分叉成 Y 字形的两根触须
    final antennae = Path()
      ..moveTo(59, 57)
      ..lineTo(59, 35)
      ..cubicTo(57, 28, 51, 22, 46, 17)
      ..moveTo(59, 35)
      ..cubicTo(61, 28, 67, 22, 72, 17);
    canvas.drawPath(antennae, stroke);
    final dot = Paint()..color = Colors.white;
    final r = stroke.strokeWidth * 0.667;
    canvas.drawCircle(const Offset(46, 17), r, dot);
    canvas.drawCircle(const Offset(72, 17), r, dot);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

import 'dart:io';

import 'package:flutter/material.dart';

/// 应用显示名：中文系统显示「网易云音乐Yet」，其他语言显示 "YetEase Music"
final String kAppName = Platform.localeName.toLowerCase().startsWith('zh') ? '网易云音乐Yet' : 'YetEase Music';

/// 品牌色：与网易云的红保持同一色系
const kBrandRed = Color(0xFFEC4141);
const kBrandRedDeep = Color(0xFFD72D3C);

/// 应用图标：红色圆底 + 白色螺旋音符（外圈开口圆弧、内圈符头、穿出缺口向右卷起的符干）。
/// 图形与 doc/logo.svg 一致；改动时两处一起改。
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
    final s = size.width / 100;
    final rect = Offset.zero & size;
    // 底：偏左上的径向渐变，让红色有体积感
    canvas.drawOval(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.45),
          radius: 1.05,
          colors: [Color(0xFFFF6A6A), kBrandRed, kBrandRedDeep],
          stops: [0.0, 0.55, 1.0],
        ).createShader(rect),
    );

    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7.2 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    const deg = 3.141592653589793 / 180;
    // 外圈：右上方留出缺口，符干从缺口穿出
    canvas.drawArc(
      Rect.fromCircle(center: Offset(48 * s, 55 * s), radius: 27 * s),
      -40 * deg,
      300 * deg,
      false,
      stroke,
    );
    // 内圈符头
    canvas.drawCircle(Offset(48.5 * s, 57 * s), 10.5 * s, stroke);
    // 符干：从内圈右缘向上，穿过外圈缺口后向右卷起
    final stem = Path()
      ..moveTo(59 * s, 57 * s)
      ..lineTo(59 * s, 24 * s)
      ..cubicTo(59 * s, 17 * s, 66 * s, 15 * s, 71 * s, 18.5 * s)
      ..cubicTo(74.5 * s, 21 * s, 75.5 * s, 25 * s, 74.5 * s, 28.5 * s);
    canvas.drawPath(stem, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

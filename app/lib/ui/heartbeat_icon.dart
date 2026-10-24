import 'package:flutter/material.dart';

/// 心动模式：心形轮廓 + 中间一条心电图。
/// Material 自带的 `monitor_heart` 实际画的是显示器，和官方的心形图标差很远。
class HeartbeatIcon extends StatelessWidget {
  const HeartbeatIcon({super.key, required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.favorite_border_rounded, size: size, color: color),
          CustomPaint(
            size: Size.square(size),
            painter: _PulsePainter(color: color, strokeWidth: size * 0.1),
          ),
        ],
      ),
    );
  }
}

class _PulsePainter extends CustomPainter {
  const _PulsePainter({required this.color, required this.strokeWidth});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(w * 0.20, h * 0.50)
      ..lineTo(w * 0.34, h * 0.50)
      ..lineTo(w * 0.42, h * 0.36)
      ..lineTo(w * 0.55, h * 0.64)
      ..lineTo(w * 0.65, h * 0.44)
      ..lineTo(w * 0.72, h * 0.50)
      ..lineTo(w * 0.80, h * 0.50);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PulsePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

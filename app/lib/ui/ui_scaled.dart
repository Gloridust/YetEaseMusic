import 'package:flutter/widgets.dart';

/// 整体缩放界面：按 1/scale 的逻辑尺寸布局，再整体放大/缩小绘制。
/// 同步调整 devicePixelRatio，图片按实际像素解码，文字也保持清晰。
class UiScaled extends StatelessWidget {
  const UiScaled({super.key, required this.scale, required this.child});

  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if ((scale - 1).abs() < 0.001) return child;
    final mq = MediaQuery.of(context);
    return LayoutBuilder(
      builder: (context, c) {
        final size = Size(c.maxWidth / scale, c.maxHeight / scale);
        return MediaQuery(
          data: mq.copyWith(
            size: size,
            devicePixelRatio: mq.devicePixelRatio * scale,
            padding: mq.padding / scale,
            viewPadding: mq.viewPadding / scale,
            viewInsets: mq.viewInsets / scale,
          ),
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.topLeft,
            child: OverflowBox(
              alignment: Alignment.topLeft,
              minWidth: size.width,
              maxWidth: size.width,
              minHeight: size.height,
              maxHeight: size.height,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

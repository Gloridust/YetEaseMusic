import 'package:flutter/widgets.dart';

/// 桌面端系统文字缩放的上限。
///
/// Linux 的 Flutter 引擎会把 GNOME 的 `text-scaling-factor` 叠加到显示器缩放上：
/// 4K@200% 再遇到 200% 文字缩放时，字号会变成 4 倍，而侧栏、顶栏仍按逻辑尺寸
/// 排版，文字就会被裁掉。需要更大的界面时，用应用内的「界面缩放」。
const double kMaxDesktopTextScale = 1.25;

TextScaler clampDesktopTextScaler(TextScaler scaler) =>
    scaler.clamp(minScaleFactor: 0.8, maxScaleFactor: kMaxDesktopTextScale);

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

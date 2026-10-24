import 'dart:io';

import 'package:flutter/widgets.dart';

/// 把系统的「文字大小」折算成整体界面缩放的倍数。
///
/// 侧栏、顶栏、播放栏、列表行这些尺寸是按设计稿写死的，只放大文字会装不下而被裁切
/// （比如 4K@200% 再加 200% 文字缩放，字号是 4 倍）。所以不单独放大文字，而是让整个
/// 界面按同一比例放大：字号如用户所愿，组件跟着变大，逻辑宽度不够时自动切到紧凑布局。
/// 安卓的文字缩放可能是非线性的，取正文字号（14）处的倍数。
double systemTextScale(TextScaler scaler) {
  final override = double.tryParse(Platform.environment['YETEASE_TEXT_SCALE'] ?? '');
  if (override != null && override > 0) return override;
  final s = scaler.scale(14) / 14;
  return s.isFinite && s > 0 ? s : 1.0;
}

/// 整体缩放界面：按 1/scale 的逻辑尺寸布局，再整体放大/缩小绘制。
/// 同步调整 devicePixelRatio，图片按实际像素解码，文字也保持清晰。
class UiScaled extends StatelessWidget {
  const UiScaled({super.key, required this.scale, required this.child});

  final double scale;
  final Widget child;

  /// 放大后至少保留的逻辑尺寸。窗口太小时少放大一些，避免顶栏、播放栏挤不下
  static const minLogicalWidth = 360.0;
  static const minLogicalHeight = 480.0;

  @override
  Widget build(BuildContext context) {
    if ((scale - 1).abs() < 0.001) return child;
    final mq = MediaQuery.of(context);
    return LayoutBuilder(
      builder: (context, c) {
        final fit = [c.maxWidth / minLogicalWidth, c.maxHeight / minLogicalHeight].reduce((a, b) => a < b ? a : b);
        // 只限制放大；缩小（scale < 1）和本来就放得下的情况不受影响
        final scale = this.scale > 1 ? this.scale.clamp(1.0, fit < 1 ? 1.0 : fit).toDouble() : this.scale;
        if ((scale - 1).abs() < 0.001) return child;
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

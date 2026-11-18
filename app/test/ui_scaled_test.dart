// 整体缩放后四个角都要点得到（#21）：缩小（scale < 1）时右侧和底部曾经收不到点击，
// 安卓上系统字号偏小、或设置里选了 80% / 90% 都会触发
import 'package:app/ui/ui_scaled.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final scale in const [0.8, 0.9, 1.25]) {
    testWidgets('scale=$scale 时四个角的按钮都能点到', (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(412, 900);
      addTearDown(t.view.reset);

      final tapped = <String>{};
      Widget corner(String name, Alignment a) => Align(
        alignment: a,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => tapped.add(name),
          child: SizedBox(key: ValueKey(name), width: 40, height: 40),
        ),
      );

      await t.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: UiScaled(
            scale: scale,
            child: Stack(
              children: [
                corner('tl', Alignment.topLeft),
                corner('tr', Alignment.topRight),
                corner('bl', Alignment.bottomLeft),
                corner('br', Alignment.bottomRight),
              ],
            ),
          ),
        ),
      );

      // 绘制出来的界面正好铺满屏幕
      final br = t.getRect(find.byKey(const ValueKey('br'))).bottomRight;
      expect(br.dx, moreOrLessEquals(412, epsilon: 0.01));
      expect(br.dy, moreOrLessEquals(900, epsilon: 0.01));
      for (final name in ['tl', 'tr', 'bl', 'br']) {
        await t.tap(find.byKey(ValueKey(name)));
      }
      expect(tapped, {'tl', 'tr', 'bl', 'br'});
    });
  }
}

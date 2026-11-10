// 安卓全屏绘制（#21）：播放条不能落进手势条。顶栏、抽屉、播放页的 SafeArea 在 Shell 里，单测里起不来（首页要调 Rust），靠截图检查
import 'package:app/theme.dart';
import 'package:app/ui/player_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const insets = EdgeInsets.only(top: 40, bottom: 24);

  Widget host(Widget child) => MaterialApp(
    theme: buildTheme(Brightness.dark),
    home: Scaffold(body: child),
  );

  // 模拟一台 412×900 的手机：顶部状态栏 40，底部手势条 24
  void phone(WidgetTester t) {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(412, 900);
    t.view.padding = const FakeViewPadding(top: 40, bottom: 24);
    t.view.viewPadding = const FakeViewPadding(top: 40, bottom: 24);
    addTearDown(t.view.reset);
  }

  testWidgets('播放条底色铺到手势条下，内容抬到手势条上方', (t) async {
    phone(t);
    await t.pumpWidget(
      host(
        Align(
          alignment: Alignment.bottomCenter,
          child: PlayerBar(onQueue: () {}),
        ),
      ),
    );
    final bar = t.getRect(find.byType(PlayerBar));
    expect(bar.bottom, 900);
    final content = t.getRect(find.byType(Row).first);
    expect(content.bottom, lessThanOrEqualTo(900 - insets.bottom));
  });
}

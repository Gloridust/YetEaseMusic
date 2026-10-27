// 歌曲列表里的歌手名链接（#17）：鼠标悬停后点击要能打开歌手页，且不影响整行的双击播放
import 'package:app/src/rust/api/types.dart';
import 'package:app/theme.dart';
import 'package:app/ui/pages/album_page.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<int> opened;
  late int rowDoubleTaps;

  Future<void> pump(WidgetTester t) async {
    opened = [];
    rowDoubleTaps = 0;
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Scaffold(
          body: Center(
            // 和 SongRow 一样：整行双击播放
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onDoubleTap: () => rowDoubleTaps++,
              child: SizedBox(
                width: 400,
                child: ArtistLinks(
                  artists: const [
                    ArtistItem(id: 11, name: '小石头和孩子们'),
                    ArtistItem(id: 22, name: '韩甜甜'),
                  ],
                  onOpen: opened.add,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 第 [index] 个字符的中心（全局坐标）
  Offset charCenter(WidgetTester t, int index) {
    final p = t.renderObject<RenderParagraph>(find.byType(RichText));
    final box = p.getBoxesForSelection(TextSelection(baseOffset: index, extentOffset: index + 1)).first;
    return p.localToGlobal(box.toRect().center);
  }

  testWidgets('鼠标悬停后单击歌手名，打开对应歌手', (t) async {
    await pump(t);
    final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    final second = charCenter(t, '小石头和孩子们 / '.length + 1);
    await mouse.moveTo(second);
    // 悬停期间连续几帧，以前这里会反复重建
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }
    await mouse.down(second);
    await t.pump(const Duration(milliseconds: 50));
    await mouse.up();
    await t.pump(const Duration(milliseconds: 600));
    expect(opened, [22]);
    expect(rowDoubleTaps, 0);
  });

  testWidgets('触屏点歌手名也能打开', (t) async {
    await pump(t);
    await t.tapAt(charCenter(t, 1));
    await t.pump(const Duration(milliseconds: 600));
    expect(opened, [11]);
  });

  testWidgets('点在分隔符上不打开歌手；在歌手名上双击仍是整行播放', (t) async {
    await pump(t);
    await t.tapAt(charCenter(t, '小石头和孩子们 '.length));
    await t.pump(const Duration(milliseconds: 600));
    expect(opened, isEmpty);

    final pos = charCenter(t, 1);
    await t.tapAt(pos);
    await t.pump(const Duration(milliseconds: 50));
    await t.tapAt(pos);
    await t.pump(const Duration(milliseconds: 600));
    expect(rowDoubleTaps, 1);
    expect(opened, isEmpty);
  });
}

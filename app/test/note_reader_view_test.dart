import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inbox_app/ui/note_reader_view.dart';
import 'package:inbox_app/util/path_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('note_reader_test_');
  });

  tearDown(() {
    tmp.deleteSync(recursive: true);
  });

  File writeNote(String date, String content) {
    final f = File(VaultPaths.dailyInboxFile(tmp.path, DateTime.parse(date)))
      ..createSync(recursive: true)
      ..writeAsStringSync(content);
    return f;
  }

  testWidgets('空目录显示空态且不可编辑', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: NoteReaderView(vaultPath: tmp.path, onBack: () {}),
    ));
    await tester.pumpAndSettle();

    expect(find.text('还没有采集内容'), findsOneWidget);
    // 没有任何可编辑输入控件；SelectableText 自身用只读 EditableText 渲染，
    // 所以这里只断言不存在 TextField。
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('列出最近笔记、倒序、点击切换内容', (tester) async {
    writeNote('2026-08-24', '周一天气晴');
    writeNote('2026-08-25', '周二的笔记');
    writeNote('2026-08-26', '周三最新');

    await tester.pumpWidget(MaterialApp(
      home: NoteReaderView(vaultPath: tmp.path, onBack: () {}),
    ));
    await tester.pumpAndSettle();

    // 三个日期都在侧栏。
    expect(find.text('2026-08-24'), findsOneWidget);
    expect(find.text('2026-08-25'), findsOneWidget);
    expect(find.text('2026-08-26'), findsOneWidget);

    // 默认展示最新一天的内容。
    expect(find.text('周三最新'), findsOneWidget);
    expect(find.text('周一天气晴'), findsNothing);

    // 点 24 号，右侧切换。
    await tester.tap(find.text('2026-08-24'));
    await tester.pumpAndSettle();
    expect(find.text('周一天气晴'), findsOneWidget);
    expect(find.text('周三最新'), findsNothing);

    // 全程无任何可编辑输入控件（SelectableText 内部使用只读
    // EditableText，是预期行为，不在此断言）。
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('返回按钮触发 onBack', (tester) async {
    writeNote('2026-08-26', 'x');
    var back = 0;
    await tester.pumpWidget(MaterialApp(
      home: NoteReaderView(
        vaultPath: tmp.path,
        onBack: () => back += 1,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('返回'));
    expect(back, 1);
  });
}

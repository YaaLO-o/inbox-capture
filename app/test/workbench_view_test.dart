import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inbox_app/services/desktop_file_vault_storage.dart';
import 'package:inbox_app/services/display_service.dart';
import 'package:inbox_app/services/settings_service.dart';
import 'package:inbox_app/ui/workbench_view.dart';
import 'package:inbox_app/util/path_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('workbench_view_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  File writeNote(String date, String content) =>
      File(VaultPaths.dailyInboxFile(tmp.path, DateTime.parse(date)))
        ..createSync(recursive: true)
        ..writeAsStringSync(content);

  Widget workbench() {
    final settings = SettingsService();
    return WorkbenchView(
      vaultPath: tmp.path,
      settings: settings,
      storage: const DesktopFileVaultStorage(),
      display: DisplayService(settings: settings),
      onCheckUpdates: () {},
      onClose: () {},
      onVaultPathChanged: (_) {},
    );
  }

  testWidgets(
    'newest note opens and an older selection changes the read-only body',
    (tester) async {
      writeNote('2026-08-24', 'older content');
      writeNote('2026-08-26', 'newest content');
      await tester.pumpWidget(workbench());
      await tester.pumpAndSettle();

      expect(find.text('newest content'), findsOneWidget);
      expect(find.text('2026-08-24'), findsOneWidget);
      expect(find.text('2026-08-26'), findsWidgets);
      await tester.tap(find.text('2026-08-24'));
      await tester.pumpAndSettle();
      expect(find.text('older content'), findsOneWidget);
      expect(find.text('newest content'), findsNothing);
      expect(find.byType(TextField), findsNothing);
    },
  );

  testWidgets('empty Vault keeps navigation and shows an empty state', (
    tester,
  ) async {
    await tester.pumpWidget(workbench());
    await tester.pumpAndSettle();

    expect(find.text('还没有采集内容'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('deleted selected note shows a read error instead of crashing', (
    tester,
  ) async {
    final note = writeNote('2026-08-26', 'soon gone');
    await tester.pumpWidget(workbench());
    await tester.pumpAndSettle();
    note.deleteSync();

    await tester.tap(find.text('2026-08-26').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('无法读取该文件'), findsOneWidget);
  });
}

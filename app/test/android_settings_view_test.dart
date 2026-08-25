import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inbox_app/ui/android_settings_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.inbox.app/android_vault');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    messenger.setMockMethodCallHandler(channel, (call) async {
      return switch (call.method) {
        'getVault' => <String, Object>{
          'id': 'content://provider/tree/obsidian',
          'displayName': 'Obsidian',
          'accessible': true,
        },
        'pickVault' => <String, Object>{
          'id': 'content://provider/tree/notes',
          'displayName': 'Notes',
          'accessible': true,
        },
        _ => null,
      };
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  testWidgets('shows the minimal Android settings sections', (tester) async {
    await tester.pumpWidget(const AndroidSettingsView());
    await tester.pumpAndSettle();

    expect(find.text('Vault'), findsOneWidget);
    expect(find.text('重新选择 Vault'), findsOneWidget);
    expect(find.text('悬浮 Capture'), findsOneWidget);
    expect(find.text('权限'), findsOneWidget);
    expect(find.text('Obsidian'), findsOneWidget);
    expect(find.text('写入测试 Capture'), findsNothing);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      Colors.white,
    );
  });

  testWidgets('updates the visible descriptor after choosing a Vault', (
    tester,
  ) async {
    await tester.pumpWidget(const AndroidSettingsView());
    await tester.pumpAndSettle();

    await tester.tap(find.text('重新选择 Vault'));
    await tester.pumpAndSettle();

    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Obsidian'), findsNothing);
  });
}

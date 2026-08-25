import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inbox_app/ui/android_settings_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.inbox.app/android_vault');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<MethodCall> calls;
  late Map<String, Object?> handlers;

  setUp(() {
    calls = [];
    handlers = <String, Object?>{};
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      final handler = handlers[call.method];
      if (handler is Object? Function(MethodCall)) {
        return handler(call);
      }
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
        'getOverlayState' => <String, Object>{
          'running': false,
          'overlayPermission': true,
          'notificationPermission': true,
          'vaultConfigured': true,
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

  testWidgets('renders the overlay permission rows', (tester) async {
    handlers['getOverlayState'] = (_) => <String, Object>{
      'running': false,
      'overlayPermission': false,
      'notificationPermission': false,
      'vaultConfigured': true,
    };

    await tester.pumpWidget(const AndroidSettingsView());
    await tester.pumpAndSettle();

    expect(find.text('显示在其他应用上层'), findsOneWidget);
    expect(find.text('通知'), findsOneWidget);
    // Denied permissions render a "去设置" action.
    expect(find.text('去设置'), findsWidgets);
    // Start is enabled (overlay denial does not make the button itself
    // disappear; tapping it launches the permission request).
    expect(find.text('开启悬浮球'), findsOneWidget);
  });

  testWidgets(
    'tapping start with overlay granted requests nothing extra then starts',
    (tester) async {
      var running = false;
      handlers['getOverlayState'] = (_) => <String, Object>{
        'running': running,
        'overlayPermission': true,
        'notificationPermission': true,
        'vaultConfigured': true,
      };
      handlers['requestOverlayPermission'] = (_) => true;
      handlers['startOverlay'] = (_) {
        running = true;
        return null;
      };

      await tester.pumpWidget(const AndroidSettingsView());
      await tester.pumpAndSettle();

      calls.clear();
      await tester.tap(find.text('开启悬浮球'));
      await tester.pumpAndSettle();

      expect(
        calls.map((call) => call.method),
        containsAllInOrder([
          'requestOverlayPermission',
          'startOverlay',
        ]),
      );
      // After refresh the running state should be reflected.
      expect(find.text('停止悬浮球'), findsOneWidget);
    },
  );

  testWidgets(
    'denied overlay permission goes to settings and does not start',
    (tester) async {
      handlers['getOverlayState'] = (_) => <String, Object>{
        'running': false,
        'overlayPermission': false,
        'notificationPermission': true,
        'vaultConfigured': true,
      };
      handlers['requestOverlayPermission'] = (_) => false;

      await tester.pumpWidget(const AndroidSettingsView());
      await tester.pumpAndSettle();

      calls.clear();
      await tester.tap(find.text('开启悬浮球'));
      await tester.pumpAndSettle();

      final methods = calls.map((call) => call.method).toList();
      expect(methods, contains('requestOverlayPermission'));
      expect(methods, isNot(contains('startOverlay')));
    },
  );

  testWidgets('already-running shows stop and calls stopOverlay', (
    tester,
  ) async {
    var running = true;
    handlers['getOverlayState'] = (_) => <String, Object>{
      'running': running,
      'overlayPermission': true,
      'notificationPermission': true,
      'vaultConfigured': true,
    };
    handlers['stopOverlay'] = (_) {
      running = false;
      return null;
    };

    await tester.pumpWidget(const AndroidSettingsView());
    await tester.pumpAndSettle();

    expect(find.text('停止悬浮球'), findsOneWidget);
    calls.clear();

    await tester.tap(find.text('停止悬浮球'));
    await tester.pumpAndSettle();

    expect(
      calls.map((call) => call.method),
      contains('stopOverlay'),
    );
    expect(find.text('开启悬浮球'), findsOneWidget);
  });

  testWidgets('vault-unavailable disables start and shows hint', (tester) async {
    handlers['getOverlayState'] = (_) => <String, Object>{
      'running': false,
      'overlayPermission': true,
      'notificationPermission': true,
      'vaultConfigured': false,
    };

    await tester.pumpWidget(const AndroidSettingsView());
    await tester.pumpAndSettle();

    final startButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '开启悬浮球'),
    );
    expect(startButton.onPressed, isNull);
    expect(find.text('请先选择 Vault 后再开启悬浮球'), findsOneWidget);
  });

  testWidgets(
    'notification denial does not block start and shows status row',
    (tester) async {
      var running = false;
      handlers['getOverlayState'] = (_) => <String, Object>{
        'running': running,
        'overlayPermission': true,
        'notificationPermission': false,
        'vaultConfigured': true,
      };
      handlers['requestOverlayPermission'] = (_) => true;
      handlers['startOverlay'] = (_) {
        running = true;
        return null;
      };

      await tester.pumpWidget(const AndroidSettingsView());
      await tester.pumpAndSettle();

      // Start button is enabled even though notification permission is denied.
      final startButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '开启悬浮球'),
      );
      expect(startButton.onPressed, isNotNull);
      expect(
        find.text('通知权限未授予，悬浮球仍会运行，但不会显示常驻通知。'),
        findsOneWidget,
      );

      await tester.tap(find.text('开启悬浮球'));
      await tester.pumpAndSettle();

      final methods = calls.map((call) => call.method).toList();
      expect(methods, contains('startOverlay'));
    },
  );
}

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inbox_app/main.dart';
import 'package:inbox_app/ui/capture_pill.dart';
import 'package:inbox_app/ui/control_center_view.dart';
import 'package:inbox_app/ui/onboarding_view.dart';
import 'package:inbox_app/ui/update_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.inbox.app/settings');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory root;
  String? savedPath;
  String? pickedPath;
  Completer<String?>? pendingPicker;
  final calls = <MethodCall>[];

  setUp(() {
    root = Directory.systemTemp.createTempSync('inbox_windows_shell_');
    savedPath = root.path;
    pickedPath = null;
    pendingPicker = null;
    calls.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'getVaultPath':
          return savedPath;
        case 'setVaultPath':
          savedPath = call.arguments['path'] as String;
        case 'clearVaultPath':
          savedPath = null;
        case 'pickFolder':
          return pendingPicker?.future ?? Future.value(pickedPath);
        case 'getDisplayMethod':
          return 'inbox';
        case 'getAppVersion':
          return '1.2.0';
        case 'openExternalUrl':
        case 'revealPath':
          return true;
      }
      return null;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    root.deleteSync(recursive: true);
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    final atlas = find.byType(FutureBuilder<ui.Image>);
    if (atlas.evaluate().isNotEmpty) {
      await tester.runAsync(
        () => tester.widget<FutureBuilder<ui.Image>>(atlas).future!,
      );
      await tester.pump();
    }
  }

  Future<void> nativeEvent(String method, [Object? args]) async {
    final done = Completer<void>();
    messenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(MethodCall(method, args)),
      (_) => done.complete(),
    );
    await done.future;
  }

  void windowsTest(String name, WidgetTesterCallback body) {
    testWidgets(
      name,
      body,
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }

  windowsTest(
    'restored Windows Vault boots into floating mode without a picker',
    (tester) async {
      await tester.pumpWidget(const InboxApp());
      await settle(tester);
      expect(find.byType(CapturePill), findsOneWidget);
      expect(calls.where((c) => c.method == 'pickFolder'), isEmpty);
      expect(calls.where((c) => c.method == 'setWindowMode').last.arguments, {
        'mode': 'floating',
      });
      await tester.pumpWidget(const SizedBox());
    },
  );

  windowsTest('first launch uses a standard onboarding window', (tester) async {
    savedPath = null;
    await tester.pumpWidget(const InboxApp());
    await settle(tester);
    expect(find.byType(OnboardingView), findsOneWidget);
    expect(calls.where((c) => c.method == 'setWindowMode').last.arguments, {
      'mode': 'standard',
    });
    await tester.pumpWidget(const SizedBox());
  });

  windowsTest('tray opens the current Vault through the shared app handler', (
    tester,
  ) async {
    await tester.pumpWidget(const InboxApp());
    await settle(tester);
    await nativeEvent('trayAction', 'openVault');
    expect(calls.where((c) => c.method == 'revealPath').single.arguments, {
      'path': root.path,
    });
    await tester.pumpWidget(const SizedBox());
  });

  windowsTest('tray folder cancellation retains the existing Vault and pet', (
    tester,
  ) async {
    await tester.pumpWidget(const InboxApp());
    await settle(tester);
    await nativeEvent('trayAction', 'changeVault');
    await settle(tester);
    expect(calls.where((c) => c.method == 'pickFolder'), hasLength(1));
    expect(calls.where((c) => c.method == 'setVaultPath'), isEmpty);
    expect(
      tester.widget<CapturePill>(find.byType(CapturePill)).vaultPath,
      root.path,
    );
    await tester.pumpWidget(const SizedBox());
  });

  windowsTest(
    'tray folder change persists and returns from control center to pet',
    (tester) async {
      pickedPath = (Directory('${root.path}/中文 新库')..createSync()).path;
      await tester.pumpWidget(const InboxApp());
      await settle(tester);
      tester
          .widget<CapturePill>(find.byType(CapturePill))
          .onOpenControlCenter();
      await settle(tester);
      await nativeEvent('trayAction', 'changeVault');
      await settle(tester);
      expect(savedPath, pickedPath);
      expect(
        tester.widget<CapturePill>(find.byType(CapturePill)).vaultPath,
        pickedPath,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  windowsTest('repeated tray actions cannot open overlapping folder pickers', (
    tester,
  ) async {
    pendingPicker = Completer<String?>();
    await tester.pumpWidget(const InboxApp());
    await settle(tester);
    final first = nativeEvent('trayAction', 'changeVault');
    await tester.pump();
    final second = nativeEvent('trayAction', 'changeVault');
    await tester.pump();
    pendingPicker!.complete(null);
    await Future.wait([first, second]);
    expect(calls.where((c) => c.method == 'pickFolder'), hasLength(1));
    await tester.pumpWidget(const SizedBox());
  });

  windowsTest(
    'Windows update entry opens releases without running the DMG updater',
    (tester) async {
      await tester.pumpWidget(const InboxApp());
      await settle(tester);
      tester.widget<CapturePill>(find.byType(CapturePill)).onCheckUpdates();
      await settle(tester);
      expect(
        calls.where((c) => c.method == 'openExternalUrl').single.arguments,
        {'url': 'https://github.com/YaaLO-o/inbox-capture/releases'},
      );
      expect(calls.where((c) => c.method == 'installUpdate'), isEmpty);
      expect(find.byType(UpdateView), findsNothing);
      expect(find.byType(CapturePill), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  windowsTest('standard close restores pet state after a tray event', (
    tester,
  ) async {
    await tester.pumpWidget(const InboxApp());
    await settle(tester);
    await nativeEvent('trayAction', 'openVault');
    tester.widget<CapturePill>(find.byType(CapturePill)).onOpenControlCenter();
    await settle(tester);
    expect(find.byType(ControlCenterView), findsOneWidget);
    final standardMode = calls.lastIndexWhere(
      (call) =>
          call.method == 'setWindowMode' &&
          call.arguments['mode'] == 'standard',
    );
    final controlCenterSize = calls.lastIndexWhere(
      (call) =>
          call.method == 'setWindowSize' && call.arguments['width'] == 480.0,
    );
    expect(standardMode, lessThan(controlCenterSize));
    await nativeEvent('mainWindowDidClose');
    await settle(tester);
    expect(find.byType(CapturePill), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}

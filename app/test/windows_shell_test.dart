import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inbox_app/main.dart';
import 'package:inbox_app/models/app_release.dart';
import 'package:inbox_app/services/update_service.dart';
import 'package:inbox_app/ui/capture_pill.dart';
import 'package:inbox_app/ui/workbench_view.dart';
import 'package:inbox_app/util/path_utils.dart';
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

  windowsTest(
    'Windows keeps a persisted Vault even when it is briefly offline',
    (tester) async {
      savedPath = r'Z:\temporarily-offline-vault';
      await tester.pumpWidget(const InboxApp());
      await settle(tester);

      expect(find.byType(CapturePill), findsOneWidget);
      expect(calls.where((c) => c.method == 'clearVaultPath'), isEmpty);
      expect(calls.where((c) => c.method == 'pickFolder'), isEmpty);
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

  windowsTest('Windows update entry checks and reports status inside the app', (
    tester,
  ) async {
    final updates = ShellUpdateService();
    await tester.pumpWidget(InboxApp(updateService: updates));
    await settle(tester);
    tester.widget<CapturePill>(find.byType(CapturePill)).onCheckUpdates();
    await tester.pumpAndSettle();
    expect(find.byType(UpdateView), findsOneWidget);
    expect(find.text('正在检查更新…'), findsOneWidget);
    expect(calls.where((c) => c.method == 'openExternalUrl'), isEmpty);

    updates.complete(AppRelease(version: AppVersion.parse('1.2.0')));
    await tester.pumpAndSettle();
    expect(find.text('当前已是最新版本'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  windowsTest('standard close restores pet state after a tray event', (
    tester,
  ) async {
    await tester.pumpWidget(const InboxApp());
    await settle(tester);
    await nativeEvent('trayAction', 'openVault');
    tester.widget<CapturePill>(find.byType(CapturePill)).onOpenControlCenter();
    await settle(tester);
    expect(find.byType(WorkbenchView), findsOneWidget);
    final standardMode = calls.lastIndexWhere(
      (call) =>
          call.method == 'setWindowMode' &&
          call.arguments['mode'] == 'standard',
    );
    final workbenchSize = calls.lastIndexWhere(
      (call) =>
          call.method == 'setWindowSize' && call.arguments['width'] == 860.0,
    );
    expect(standardMode, lessThan(workbenchSize));
    await nativeEvent('mainWindowDidClose');
    await settle(tester);
    expect(find.byType(CapturePill), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  windowsTest(
    'workbench keeps one window through settings and update, then returns to pet',
    (tester) async {
      final updates = ShellUpdateService();
      await tester.pumpWidget(InboxApp(updateService: updates));
      await settle(tester);
      tester
          .widget<CapturePill>(find.byType(CapturePill))
          .onOpenControlCenter();
      await settle(tester);
      expect(find.byType(WorkbenchView), findsOneWidget);
      expect(
        calls.where((c) => c.method == 'setWindowSize').last.arguments['width'],
        860.0,
      );

      await tester.tap(find.text('设置'));
      await settle(tester);
      await tester.tap(find.text('查看内容'));
      await settle(tester);
      expect(find.byType(WorkbenchView), findsOneWidget);
      expect(
        calls.where(
          (c) => c.method == 'setWindowSize' && c.arguments['width'] == 640.0,
        ),
        isEmpty,
      );

      await tester.tap(find.text('设置'));
      await settle(tester);
      await tester.tap(find.text('检查更新'));
      await settle(tester);
      expect(find.byType(UpdateView), findsOneWidget);
      updates.complete(AppRelease(version: AppVersion.parse('1.2.0')));
      await settle(tester);
      tester.widget<UpdateView>(find.byType(UpdateView)).onClose();
      await settle(tester);
      expect(find.byType(WorkbenchView), findsOneWidget);

      await tester.tap(find.text('返回桌宠'));
      await settle(tester);
      expect(find.byType(CapturePill), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  windowsTest('update check preserves the selected note and Settings pane', (
    tester,
  ) async {
    File(VaultPaths.dailyInboxFile(root.path, DateTime(2026, 8, 24)))
      ..createSync(recursive: true)
      ..writeAsStringSync('older note body');
    File(VaultPaths.dailyInboxFile(root.path, DateTime(2026, 8, 26)))
      ..createSync(recursive: true)
      ..writeAsStringSync('newest note body');
    final updates = ShellUpdateService();
    await tester.pumpWidget(InboxApp(updateService: updates));
    await settle(tester);
    tester.widget<CapturePill>(find.byType(CapturePill)).onOpenControlCenter();
    await settle(tester);
    await tester.tap(find.text('2026-08-24'));
    await settle(tester);
    await tester.tap(find.text('设置'));
    await settle(tester);
    await tester.tap(find.text('检查更新'));
    await settle(tester);
    updates.complete(AppRelease(version: AppVersion.parse('1.2.0')));
    await settle(tester);
    tester.widget<UpdateView>(find.byType(UpdateView)).onClose();
    await settle(tester);

    expect(find.text('更改存储文件夹'), findsOneWidget);
    await tester.tap(find.text('查看内容'));
    await settle(tester);
    expect(find.text('older note body'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}

class ShellUpdateService extends UpdateService {
  final Completer<AppRelease> _latest = Completer<AppRelease>();

  @override
  Future<AppRelease> fetchLatest() => _latest.future;

  void complete(AppRelease release) => _latest.complete(release);
}

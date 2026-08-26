import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inbox_app/services/display_service.dart';
import 'package:inbox_app/services/settings_service.dart';
import 'package:inbox_app/services/storage_service.dart';
import 'package:inbox_app/ui/control_center_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.inbox.app/settings');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late Directory tmp;
  final calls = <MethodCall>[];

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('control_center_test_');
    calls.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'getDisplayMethod') return 'inbox';
      if (call.method == 'getAppVersion') return '1.1.1';
      if (call.method == 'revealPath' ||
          call.method == 'openPath' ||
          call.method == 'openExternalUrl') {
        return true;
      }
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    tmp.deleteSync(recursive: true);
  });

  Widget pump({
    void Function(String)? onVaultPathChanged,
    VoidCallback? onCheckUpdates,
    VoidCallback? onOpenContent,
    VoidCallback? onClose,
  }) {
    return MaterialApp(
      home: ControlCenterView(
        vaultPath: tmp.path,
        settings: SettingsService(),
        storage: StorageService(),
        display: DisplayService(settings: SettingsService()),
        onVaultPathChanged: onVaultPathChanged ?? (_) {},
        onCheckUpdates: onCheckUpdates ?? () {},
        onOpenContent: onOpenContent ?? () {},
        onClose: onClose ?? () {},
      ),
    );
  }

  testWidgets('渲染存储位置、展示方式分段、主要按钮', (tester) async {
    await tester.pumpWidget(pump());
    await tester.pumpAndSettle();

    expect(find.text('控制中心'), findsOneWidget);
    expect(find.text('打开存储文件夹'), findsOneWidget);
    expect(find.text('更改存储文件夹'), findsOneWidget);
    expect(find.text('应用内查看'), findsOneWidget);
    expect(find.text('系统默认'), findsOneWidget);
    expect(find.text('Obsidian'), findsOneWidget);
    expect(find.text('查看内容'), findsOneWidget);
    expect(find.text('检查更新'), findsOneWidget);
    expect(find.text('返回桌宠'), findsOneWidget);
    expect(find.textContaining('INbox 1.1.1'), findsOneWidget);
    // 当前存储路径可见。
    expect(find.textContaining(tmp.path), findsOneWidget);
  });

  testWidgets('打开存储文件夹按钮触发 revealPath', (tester) async {
    await tester.pumpWidget(pump());
    await tester.pumpAndSettle();

    await tester.tap(find.text('打开存储文件夹'));
    await tester.pump();

    final reveal = calls.where((c) => c.method == 'revealPath').toList();
    expect(reveal, isNotEmpty);
    expect(reveal.last.arguments, {'path': tmp.path});
  });

  testWidgets('选择 Obsidian 分段会持久化展示方式', (tester) async {
    await tester.pumpWidget(pump());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Obsidian'));
    await tester.pumpAndSettle();

    final setCall = calls.firstWhere(
      (c) => c.method == 'setDisplayMethod',
    );
    expect(setCall.arguments, {'method': 'obsidian'});
  });

  testWidgets('检查更新 / 查看内容 / 返回桌宠 触发各自回调', (tester) async {
    var checks = 0, opens = 0, closes = 0;
    await tester.pumpWidget(pump(
      onCheckUpdates: () => checks += 1,
      onOpenContent: () => opens += 1,
      onClose: () => closes += 1,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('检查更新'));
    await tester.tap(find.text('查看内容'));
    await tester.tap(find.text('返回桌宠'));
    await tester.pump();

    expect(checks, 1);
    expect(opens, 1);
    expect(closes, 1);
  });

  testWidgets('更改存储文件夹：确认后在新位置建布局并写偏好', (tester) async {
    final newFolder = Directory('${tmp.path}/new-store')
      ..createSync(recursive: true);
    String? changedTo;

    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'getDisplayMethod') return 'inbox';
      if (call.method == 'getAppVersion') return '1.1.1';
      if (call.method == 'pickFolder') return newFolder.path;
      return null;
    });

    await tester.pumpWidget(pump(
      onVaultPathChanged: (p) => changedTo = p,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('更改存储文件夹'));
    await tester.pumpAndSettle();

    // 新位置建立了 Universal Capture / attachments 目录。
    expect(
      Directory('${newFolder.path}/Universal Capture/attachments')
          .existsSync(),
      isTrue,
    );
    // 旧位置没有被搬动（新目录里不应出现旧文件——此用例旧位置本来就空，
    // 这里主要验证偏好写入和回调触发）。
    final setVault = calls.firstWhere((c) => c.method == 'setVaultPath');
    expect(setVault.arguments, {'path': newFolder.path});
    expect(changedTo, newFolder.path);
  });
}

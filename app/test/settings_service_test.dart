import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inbox_app/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.inbox.app/settings');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('已保存 Vault 路径失效时清理配置且不重建旧目录', () async {
    final parent = Directory.systemTemp.createTempSync('settings_test_');
    final stalePath = '${parent.path}${Platform.pathSeparator}moved-vault';
    final calls = <MethodCall>[];
    addTearDown(() => parent.deleteSync(recursive: true));

    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'getVaultPath') return stalePath;
      if (call.method == 'clearVaultPath') return null;
      throw PlatformException(code: 'UNEXPECTED', message: call.method);
    });

    final result = await SettingsService().loadValidVaultPath();

    expect(result, isNull);
    expect(calls.map((call) => call.method), [
      'getVaultPath',
      'clearVaultPath',
    ]);
    expect(Directory(stalePath).existsSync(), isFalse);
  });

  test('已保存 Vault 目录仍存在时直接恢复且不清理配置', () async {
    final vault = Directory.systemTemp.createTempSync('valid_vault_');
    final calls = <MethodCall>[];
    addTearDown(() => vault.deleteSync(recursive: true));

    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'getVaultPath') return vault.path;
      throw PlatformException(code: 'UNEXPECTED', message: call.method);
    });

    final result = await SettingsService().loadValidVaultPath();

    expect(result, vault.path);
    expect(calls.map((call) => call.method), ['getVaultPath']);
  });
}

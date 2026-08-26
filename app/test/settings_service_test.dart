import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inbox_app/models/app_release.dart';
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

  test('getAppVersion reads the native app version boundary', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getAppVersion') return '1.1.2';
      throw PlatformException(code: 'UNEXPECTED', message: call.method);
    });

    final result = await SettingsService().getAppVersion();

    expect(result, AppVersion.parse('1.1.2'));
  });

  test(
    'installUpdate passes the verified dmg path to the native boundary',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });

      await SettingsService().installUpdate('/tmp/INbox.dmg');

      expect(calls.single.method, 'installUpdate');
      expect(calls.single.arguments, {'dmgPath': '/tmp/INbox.dmg'});
    },
  );

  test('showWindow asks the native shell to reveal INbox', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });

    await SettingsService().showWindow();

    expect(calls.single.method, 'showWindow');
  });

  test('displayMethod round-trips through the native boundary', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'getDisplayMethod') return 'obsidian';
      return null;
    });

    final settings = SettingsService();
    expect(await settings.getDisplayMethod(), 'obsidian');
    await settings.setDisplayMethod('system');

    expect(calls.map((c) => c.method), ['getDisplayMethod', 'setDisplayMethod']);
    expect(calls[1].arguments, {'method': 'system'});
  });

  test('revealPath / openPath / openExternalUrl / setWindowMode pass args',
      () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'revealPath' ||
          call.method == 'openPath' ||
          call.method == 'openExternalUrl') {
        return true;
      }
      return null;
    });

    final settings = SettingsService();
    expect(await settings.revealPath('/tmp/vault'), isTrue);
    expect(await settings.openPath('/tmp/vault/note.md'), isTrue);
    expect(await settings.openExternalUrl('obsidian://open?path=x'), isTrue);
    await settings.setWindowMode('standard');

    expect(calls.map((c) => c.method), [
      'revealPath',
      'openPath',
      'openExternalUrl',
      'setWindowMode',
    ]);
    expect(calls[0].arguments, {'path': '/tmp/vault'});
    expect(calls[1].arguments, {'path': '/tmp/vault/note.md'});
    expect(calls[2].arguments, {'url': 'obsidian://open?path=x'});
    expect(calls[3].arguments, {'mode': 'standard'});
  });

  test('openExternalUrl returns false when native reports no handler app',
      () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'openExternalUrl') return false;
      throw PlatformException(code: 'UNEXPECTED', message: call.method);
    });

    expect(await SettingsService().openExternalUrl('obsidian://open?path=x'),
        isFalse);
  });

  test('mainWindowDidClose inbound call invokes registered handler', () async {
    var fired = false;
    SettingsService().setMainWindowClosedHandler(() => fired = true);

    // 模拟原生 → Dart 的入向调用。
    await messenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(
        const MethodCall('mainWindowDidClose'),
      ),
      (_) {},
    );

    expect(fired, isTrue);
  });
}

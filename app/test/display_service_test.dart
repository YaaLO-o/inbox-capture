import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inbox_app/services/display_service.dart';
import 'package:inbox_app/services/settings_service.dart';
import 'package:inbox_app/util/path_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.inbox.app/settings');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late Directory tmp;
  late String storedMethod;
  final calls = <MethodCall>[];

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('display_service_test_');
    storedMethod = 'inbox';
    calls.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'getDisplayMethod') return storedMethod;
      if (call.method == 'setDisplayMethod') {
        storedMethod = (call.arguments as Map)['method'] as String;
        return null;
      }
      if (call.method == 'openPath') return true;
      if (call.method == 'openExternalUrl') return true;
      throw PlatformException(code: 'UNEXPECTED', message: call.method);
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    tmp.deleteSync(recursive: true);
  });

  test('未知/空值回落 inbox', () async {
    storedMethod = 'weird-value';
    expect(await DisplayService(settings: SettingsService()).load(),
        DisplayMethod.inbox);
  });

  test('load/save 往返三种展示方式', () async {
    final svc = DisplayService(settings: SettingsService());
    for (final m in DisplayMethod.values) {
      await svc.save(m);
      expect(await svc.load(), m);
    }
  });

  test('system：用系统默认应用打开当日笔记', () async {
    final date = DateTime(2026, 8, 26);
    final note = File(VaultPaths.dailyInboxFile(tmp.path, date))
      ..createSync(recursive: true)
      ..writeAsStringSync('hi');
    storedMethod = 'system';

    final r =
        await DisplayService(settings: SettingsService()).openDailyNoteExternally(
      tmp.path,
      date,
    );

    expect(r, OpenNoteResult.opened);
    final openCall = calls.firstWhere((c) => c.method == 'openPath');
    expect(openCall.arguments, {'path': note.path});
  });

  test('obsidian：拼装 obsidian:// URL 并调起', () async {
    final date = DateTime(2026, 8, 26);
    final note = File(VaultPaths.dailyInboxFile(tmp.path, date))
      ..createSync(recursive: true);
    storedMethod = 'obsidian';

    final r =
        await DisplayService(settings: SettingsService()).openDailyNoteExternally(
      tmp.path,
      date,
    );

    expect(r, OpenNoteResult.opened);
    final openCall = calls.firstWhere((c) => c.method == 'openExternalUrl');
    final url = (openCall.arguments as Map)['url'] as String;
    expect(url.startsWith('obsidian://open?path='), isTrue);
    expect(url, contains(Uri.encodeComponent(note.absolute.path)));
  });

  test('obsidian 未安装：原生返回 false → obsidianMissing', () async {
    final date = DateTime(2026, 8, 26);
    File(VaultPaths.dailyInboxFile(tmp.path, date))
        .createSync(recursive: true);
    storedMethod = 'obsidian';
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'getDisplayMethod') return storedMethod;
      if (call.method == 'openExternalUrl') return false;
      throw PlatformException(code: 'UNEXPECTED', message: call.method);
    });

    final r =
        await DisplayService(settings: SettingsService()).openDailyNoteExternally(
      tmp.path,
      date,
    );

    expect(r, OpenNoteResult.obsidianMissing);
  });

  test('当日笔记不存在：fileMissing，不调用任何打开动作', () async {
    storedMethod = 'system';
    final r =
        await DisplayService(settings: SettingsService()).openDailyNoteExternally(
      tmp.path,
      DateTime(2026, 8, 26),
    );

    expect(r, OpenNoteResult.fileMissing);
    expect(calls.where((c) => c.method == 'openPath'), isEmpty);
    expect(calls.where((c) => c.method == 'openExternalUrl'), isEmpty);
  });
}

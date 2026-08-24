import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inbox_app/services/app_command_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.inbox.app/commands');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  Future<void> sendCommand(String method) {
    final encoded = channel.codec.encodeMethodCall(MethodCall(method));
    final completer = Completer<void>();
    messenger.handlePlatformMessage(channel.name, encoded, (ByteData? data) {
      completer.complete();
    });
    return completer.future;
  }

  tearDown(() {
    AppCommandService().dispose();
  });

  test('routes checkForUpdates command and ignores unknown commands', () async {
    var checks = 0;
    final service = AppCommandService();

    service.start(onCheckForUpdates: () => checks++);

    await sendCommand('checkForUpdates');
    await sendCommand('notACommand');

    expect(checks, 1);
  });
}

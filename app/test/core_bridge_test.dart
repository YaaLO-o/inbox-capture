import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inbox_app/services/capture_coordinator.dart';
import 'package:inbox_app/services/core_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.inbox.app/core');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('native core actions reach their registered callbacks', () async {
    final calls = <String>[];
    final bridge = CoreBridge();
    bridge.setHandlers(
      onCapture: () async => calls.add('capture'),
      onOpenInbox: () async => calls.add('inbox'),
      onOpenHistory: () async => calls.add('history'),
      onOpenSettings: () async => calls.add('settings'),
    );

    for (final method in [
      'capture',
      'openInbox',
      'openHistory',
      'openSettings',
    ]) {
      await messenger.handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(MethodCall(method)),
        (_) {},
      );
    }

    expect(calls, ['capture', 'inbox', 'history', 'settings']);
  });

  test('capture feedback sends platform-neutral status name', () async {
    MethodCall? received;
    messenger.setMockMethodCallHandler(channel, (call) async {
      received = call;
      return null;
    });
    final bridge = CoreBridge();

    await bridge.reportCaptureStatus(CaptureFeedbackStatus.failure);

    expect(received?.method, 'setCaptureStatus');
    expect(received?.arguments, {'status': 'failure'});
  });
}

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inbox_app/models/capture_input.dart';
import 'package:inbox_app/services/android_capture_dispatcher.dart';
import 'package:inbox_app/services/capture_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.inbox.app/android_capture');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final nativeCalls = <MethodCall>[];

  Future<Object?> sendNativeMethodCall(
    String method, [
    Object? arguments,
  ]) async {
    final completer = Completer<ByteData?>();
    await messenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(MethodCall(method, arguments)),
      completer.complete,
    );
    final response = await completer.future;
    return response == null ? null : channel.codec.decodeEnvelope(response);
  }

  setUp(() {
    nativeCalls.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      nativeCalls.add(call);
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('captures a native request after announcing core readiness', () async {
    CaptureInput? receivedInput;
    final dispatcher = AndroidCaptureDispatcher(
      vaultId: () async => 'content://vault/tree',
      capture: (_, input) async {
        receivedInput = input;
        return const CaptureResult(
          CaptureStatus.saved,
          captureId: '20260824-093012-abcd',
        );
      },
    );
    addTearDown(dispatcher.stop);

    await dispatcher.start();
    final result = await sendNativeMethodCall('capture', {
      'source': 'share',
      'text': 'hello',
      'attachments': <Object?>[],
    });

    expect(result, {'status': 'saved', 'captureId': '20260824-093012-abcd'});
    expect(receivedInput?.source, CaptureSource.share);
    expect(receivedInput?.text, 'hello');
    expect(nativeCalls.single.method, 'coreReady');
  });

  test(
    'returns vaultUnavailable without invoking capture when Vault is absent',
    () async {
      var captures = 0;
      final dispatcher = AndroidCaptureDispatcher(
        vaultId: () async => null,
        capture: (_, _) async {
          captures++;
          return const CaptureResult(CaptureStatus.saved);
        },
      );
      addTearDown(dispatcher.stop);

      await dispatcher.start();
      final result = await sendNativeMethodCall('capture', {
        'source': 'clipboard',
        'text': 'hello',
        'attachments': <Object?>[],
      });

      expect(result, {'status': 'vaultUnavailable'});
      expect(captures, 0);
    },
  );

  test('returns error for a malformed native request', () async {
    final dispatcher = AndroidCaptureDispatcher(
      vaultId: () async => 'content://vault/tree',
      capture: (_, _) async => const CaptureResult(CaptureStatus.saved),
    );
    addTearDown(dispatcher.stop);

    await dispatcher.start();

    expect(await sendNativeMethodCall('capture', 'not-a-map'), {
      'status': 'error',
    });
  });

  test('echoes taskId and maps every stable result field', () async {
    final dispatcher = AndroidCaptureDispatcher(
      vaultId: () async => 'content://vault/tree',
      capture: (_, _) async => const CaptureResult(
        CaptureStatus.permissionDenied,
        captureId: 'capture-id',
        message: 'permission lost',
      ),
    );
    addTearDown(dispatcher.stop);

    await dispatcher.start();
    final result = await sendNativeMethodCall('capture', {
      'taskId': 'native-task-1',
      'text': 'hello',
      'attachments': <Object?>[],
    });

    expect(result, {
      'status': 'permissionDenied',
      'captureId': 'capture-id',
      'message': 'permission lost',
      'taskId': 'native-task-1',
    });
  });

  test('stop removes the native capture handler', () async {
    final dispatcher = AndroidCaptureDispatcher(
      vaultId: () async => 'content://vault/tree',
      capture: (_, _) async => const CaptureResult(CaptureStatus.saved),
    );

    await dispatcher.start();
    await dispatcher.stop();

    expect(
      await sendNativeMethodCall('capture', {
        'text': 'hello',
        'attachments': <Object?>[],
      }),
      isNull,
    );
  });
}

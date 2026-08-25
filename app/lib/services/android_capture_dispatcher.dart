import 'package:flutter/services.dart';

import '../models/capture_input.dart';
import 'capture_service.dart';

typedef AndroidVaultIdProvider = Future<String?> Function();
typedef AndroidCaptureCallback = Future<CaptureResult> Function(
  String vaultId,
  CaptureInput input,
);

/// Routes native Android capture requests into the shared capture service.
final class AndroidCaptureDispatcher {
  static const _channel = MethodChannel('com.inbox.app/android_capture');

  final AndroidVaultIdProvider vaultId;
  final AndroidCaptureCallback capture;

  AndroidCaptureDispatcher({required this.vaultId, required this.capture});

  Future<void> start() async {
    _channel.setMethodCallHandler(_handleMethodCall);
    await _channel.invokeMethod<void>('coreReady');
  }

  Future<void> stop() async {
    _channel.setMethodCallHandler(null);
  }

  Future<Object?> _handleMethodCall(MethodCall call) async {
    if (call.method != 'capture') {
      throw MissingPluginException('Unsupported method ${call.method}');
    }

    final arguments = call.arguments;
    if (arguments is! Map) {
      return _result(CaptureStatus.error);
    }

    final request = Map<Object?, Object?>.from(arguments);
    final taskId = request['taskId'] is String
        ? request['taskId'] as String
        : null;
    try {
      final currentVaultId = await vaultId();
      if (currentVaultId == null) {
        return _result(CaptureStatus.vaultUnavailable, taskId: taskId);
      }
      final result = await capture(
        currentVaultId,
        CaptureInput.fromMap(request),
      );
      return _result(
        result.status,
        captureId: result.captureId,
        message: result.message,
        taskId: taskId,
      );
    } catch (_) {
      return _result(CaptureStatus.error, taskId: taskId);
    }
  }

  Map<String, Object> _result(
    CaptureStatus status, {
    String? captureId,
    String? message,
    String? taskId,
  }) => {
    'status': switch (status) {
      CaptureStatus.saved => 'saved',
      CaptureStatus.empty => 'empty',
      CaptureStatus.vaultUnavailable => 'vaultUnavailable',
      CaptureStatus.permissionDenied => 'permissionDenied',
      CaptureStatus.error => 'error',
    },
    'captureId': ?captureId,
    'message': ?message,
    'taskId': ?taskId,
  };
}

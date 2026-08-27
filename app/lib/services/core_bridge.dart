import 'package:flutter/services.dart';

import 'capture_coordinator.dart';

/// macOS Core menu bridge. Capture implementation stays in Dart services.
class CoreBridge {
  static const _channel = MethodChannel('com.inbox.app/core');

  void setHandlers({
    required Future<void> Function() onCapture,
    required Future<void> Function() onOpenInbox,
    required Future<void> Function() onOpenHistory,
    required Future<void> Function() onOpenSettings,
  }) {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'capture':
          await onCapture();
        case 'openInbox':
          await onOpenInbox();
        case 'openHistory':
          await onOpenHistory();
        case 'openSettings':
          await onOpenSettings();
      }
      return null;
    });
  }

  Future<void> reportCaptureStatus(CaptureFeedbackStatus status) =>
      _channel.invokeMethod('setCaptureStatus', {'status': status.name});

  void dispose() {
    _channel.setMethodCallHandler(null);
  }
}

import 'dart:async';

import 'package:flutter/services.dart';

class AppCommandService {
  static const MethodChannel _channel = MethodChannel('com.inbox.app/commands');

  void start({required FutureOr<void> Function() onCheckForUpdates}) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'checkForUpdates') {
        await onCheckForUpdates();
      }
    });
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inbox_app/ui/window_surface.dart';

void main() {
  test('Windows uses the native color key and macOS remains transparent', () {
    expect(
      captureWindowSurfaceColor(TargetPlatform.windows),
      const Color(0xFFFF00FF),
    );
    expect(captureWindowSurfaceColor(TargetPlatform.macOS), Colors.transparent);
  });
}

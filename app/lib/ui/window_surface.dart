import 'package:flutter/material.dart';

const windowsTransparencyKey = Color(0xFFFF00FF);

Color captureWindowSurfaceColor(TargetPlatform platform) =>
    platform == TargetPlatform.windows
    ? windowsTransparencyKey
    : Colors.transparent;

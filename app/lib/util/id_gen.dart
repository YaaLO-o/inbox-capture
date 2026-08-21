import 'dart:math';

/// 生成 Capture ID：`YYYYMMDD-HHMMSS-XXXX`。
///
/// 最后一段是 4 位小写十六进制随机串，用于同一秒内的去重。
/// 不使用 crypto，保持轻量；碰撞概率在单机单用户场景下可忽略。
String generateCaptureId(DateTime now, [Random? random]) {
  final r = random ?? Random();
  final stamp =
      '${_padded(now.year, 4)}${_padded(now.month, 2)}${_padded(now.day, 2)}-${_padded(now.hour, 2)}${_padded(now.minute, 2)}${_padded(now.second, 2)}';
  final hex = r.nextInt(0xFFFF + 1).toRadixString(16).padLeft(4, '0');
  return '$stamp-$hex';
}

String _padded(int v, int width) => v.toString().padLeft(width, '0');

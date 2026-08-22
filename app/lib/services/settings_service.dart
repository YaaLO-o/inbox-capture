import 'dart:io';

import 'package:flutter/services.dart';

/// Vault 路径等设置的持久化。
///
/// 原生层负责平台持久化；Vault 是否仍然存在由这里统一验证。
class SettingsService {
  static const _channel = MethodChannel('com.inbox.app/settings');

  Future<String?> getVaultPath() async {
    final v = await _channel.invokeMethod<String>('getVaultPath');
    if (v == null || v.trim().isEmpty) return null;
    return v;
  }

  Future<void> setVaultPath(String path) =>
      _channel.invokeMethod('setVaultPath', {'path': path});

  Future<void> clearVaultPath() => _channel.invokeMethod('clearVaultPath');

  /// 只恢复仍然存在的目录。验证过程绝不创建路径。
  Future<String?> loadValidVaultPath() async {
    final path = await getVaultPath();
    if (path == null) return null;
    if (Directory(path).existsSync()) return path;
    await clearVaultPath();
    return null;
  }

  /// 弹出原生 NSOpenPanel 让用户选择一个目录（Obsidian Vault）。
  /// 返回选中的绝对路径，取消时返回 null。
  Future<String?> pickFolder() => _channel.invokeMethod<String>('pickFolder');

  /// 调整悬浮窗口尺寸（未配置 Vault 时放大显示引导）。
  /// [animate] 为 false 时即时切换（无动画），用于首帧/视图切换避免尺寸错配。
  Future<void> setWindowSize(double width, double height, {bool animate = true}) =>
      _channel.invokeMethod('setWindowSize', {
        'width': width,
        'height': height,
        'animate': animate,
      });

  /// 按 Flutter 逻辑像素移动原生桌面窗口。
  Future<void> moveWindowBy(double dx, double dy) =>
      _channel.invokeMethod('moveWindowBy', {'dx': dx, 'dy': dy});

  /// 退出应用。
  Future<void> quit() => _channel.invokeMethod('quit');
}

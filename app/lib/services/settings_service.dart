import 'package:flutter/services.dart';

/// Vault 路径等设置的持久化。
///
/// 存储在 macOS UserDefaults（通过原生通道），避免引入额外依赖；
/// 同时保证应用重启后仍记得上次选择的 Vault（见《方案》第十二节）。
class SettingsService {
  static const _channel = MethodChannel('com.inbox.app/settings');

  Future<String?> getVaultPath() async {
    final v = await _channel.invokeMethod<String>('getVaultPath');
    if (v == null || v.trim().isEmpty) return null;
    return v;
  }

  Future<void> setVaultPath(String path) =>
      _channel.invokeMethod('setVaultPath', {'path': path});

  /// 弹出原生 NSOpenPanel 让用户选择一个目录（Obsidian Vault）。
  /// 返回选中的绝对路径，取消时返回 null。
  Future<String?> pickFolder() =>
      _channel.invokeMethod<String>('pickFolder');

  /// 调整悬浮窗口尺寸（未配置 Vault 时放大显示引导）。
  Future<void> setWindowSize(double width, double height) =>
      _channel.invokeMethod('setWindowSize', {
        'width': width,
        'height': height,
      });

  /// 退出应用。
  Future<void> quit() => _channel.invokeMethod('quit');
}

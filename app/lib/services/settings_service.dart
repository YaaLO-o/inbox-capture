import 'dart:io';

import 'package:flutter/services.dart';

import '../models/app_release.dart';

/// 存储文件夹路径、默认展示方式等设置的持久化。
///
/// 原生层负责平台持久化；存储文件夹是否仍然存在由这里统一验证。
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

  /// 默认展示方式：应用内只读查看（inbox）/ 系统默认 Markdown 应用（system）/ Obsidian。
  /// 原生层未保存或保存了未知值时返回 null，由上层回落为 inbox。
  Future<String?> getDisplayMethod() =>
      _channel.invokeMethod<String>('getDisplayMethod');

  Future<void> setDisplayMethod(String method) =>
      _channel.invokeMethod('setDisplayMethod', {'method': method});

  /// 只恢复仍然存在的目录。验证过程绝不创建路径。
  Future<String?> loadValidVaultPath() async {
    final path = await getVaultPath();
    if (path == null) return null;
    if (Directory(path).existsSync()) return path;
    await clearVaultPath();
    return null;
  }

  /// 弹出原生目录选择器（NSOpenPanel / Windows IFileDialog）。
  /// 返回选中的绝对路径，取消时返回 null。
  Future<String?> pickFolder() => _channel.invokeMethod<String>('pickFolder');

  /// 在系统文件管理器中定位到该文件夹（Finder 打开此目录）。
  Future<bool> revealPath(String path) async =>
      await _channel.invokeMethod<bool>('revealPath', {'path': path}) ?? false;

  /// 用系统默认应用打开文件（例如 Markdown 文件）。
  Future<bool> openPath(String path) async =>
      await _channel.invokeMethod<bool>('openPath', {'path': path}) ?? false;

  /// 用能处理该 URL scheme 的应用打开外部链接。
  /// 无应用可处理时原生层返回 false（例如未安装 Obsidian 时打开 obsidian://）。
  Future<bool> openExternalUrl(String url) async =>
      await _channel.invokeMethod<bool>('openExternalUrl', {'url': url}) ??
      false;

  /// 切换原生窗口外观：standard（带标题栏红叉、普通层级）或 floating（悬浮宠物）。
  Future<void> setWindowMode(String mode) =>
      _channel.invokeMethod('setWindowMode', {'mode': mode});

  /// 在同一个 handler 中分发窗口和托盘事件，避免覆盖 macOS 关闭回调。
  void setMainWindowClosedHandler(
    void Function() handler, {
    Future<void> Function(String action)? onTrayAction,
  }) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'mainWindowDidClose') handler();
      if (call.method == 'trayAction' && call.arguments is String) {
        await onTrayAction?.call(call.arguments as String);
      }
      return null;
    });
  }

  void clearDesktopEventHandlers() => _channel.setMethodCallHandler(null);

  Future<void> hideWindow() => _channel.invokeMethod('hideWindow');

  Future<void> showError(String message) =>
      _channel.invokeMethod('showError', {'message': message});

  Future<AppVersion> getAppVersion() async {
    final value = await _channel.invokeMethod<String>('getAppVersion');
    if (value == null || value.trim().isEmpty) {
      throw const FormatException('Native app version is missing');
    }
    return AppVersion.parse(value);
  }

  Future<void> showWindow() => _channel.invokeMethod('showWindow');

  /// 调整悬浮窗口尺寸（未配置 Vault 时放大显示引导）。
  /// [animate] 为 false 时即时切换（无动画），用于首帧/视图切换避免尺寸错配。
  Future<void> setWindowSize(
    double width,
    double height, {
    bool animate = true,
  }) => _channel.invokeMethod('setWindowSize', {
    'width': width,
    'height': height,
    'animate': animate,
  });

  /// 按 Flutter 逻辑像素移动原生桌面窗口。
  Future<void> moveWindowBy(double dx, double dy) =>
      _channel.invokeMethod('moveWindowBy', {'dx': dx, 'dy': dy});

  Future<void> beginWindowDrag() => _channel.invokeMethod('beginWindowDrag');

  Future<void> updateWindowDrag() => _channel.invokeMethod('updateWindowDrag');

  Future<void> endWindowDrag() => _channel.invokeMethod('endWindowDrag');

  Future<void> installUpdate(String packagePath) => _channel.invokeMethod(
    'installUpdate',
    // dmgPath 保持 macOS 原生边界兼容；path 是新的跨平台参数。
    {'path': packagePath, 'dmgPath': packagePath},
  );

  /// 退出应用。
  Future<void> quit() => _channel.invokeMethod('quit');
}

import 'dart:io';

import '../util/path_utils.dart';
import 'settings_service.dart';

/// 用户选择的默认展示方式。
///
/// 切换展示方式只改变"打开/查看笔记时用什么"，绝不移动或重写原文件。
enum DisplayMethod {
  /// INbox 内置只读查看器。
  inbox,

  /// 系统默认 Markdown 应用（Typora、VS Code 等）。
  system,

  /// Obsidian（通过 obsidian:// URL 打开，未安装时返回 obsidianMissing）。
  obsidian,
}

/// 外部打开每日笔记的结果。
enum OpenNoteResult {
  /// 已交给系统/外部应用打开。
  opened,

  /// 用户选了 Obsidian，但系统里没有能处理 obsidian:// 的应用。
  obsidianMissing,

  /// 笔记文件本身不存在（当日还没采集过内容）。
  fileMissing,
}

/// 展示层：把"用什么看笔记"与"笔记怎么存"解耦。
///
/// inbox 方式不经过本服务的外部打开方法，由 UI 直接切到只读阅读器；
/// system / obsidian 由 [openDailyNoteExternally] 调起系统或 Obsidian。
class DisplayService {
  DisplayService({SettingsService? settings})
      : _settings = settings ?? SettingsService();

  final SettingsService _settings;

  /// 读取已保存的展示方式；原生层未保存或保存了未知值时回落为 inbox。
  Future<DisplayMethod> load() async {
    final raw = await _settings.getDisplayMethod();
    return _parse(raw);
  }

  Future<void> save(DisplayMethod method) =>
      _settings.setDisplayMethod(method.name);

  /// 用外部应用打开指定日期的每日笔记。
  ///
  /// - system：系统默认应用打开 .md 文件。
  /// - obsidian：`obsidian://open?path=<urlencoded 绝对路径>`。
  /// - inbox：不应走到这里（UI 应直接切到内置阅读器）；按 fileMissing 处理。
  Future<OpenNoteResult> openDailyNoteExternally(
    String vaultPath,
    DateTime date,
  ) async {
    final file = File(VaultPaths.dailyInboxFile(vaultPath, date));
    if (!file.existsSync()) return OpenNoteResult.fileMissing;

    final method = await load();
    switch (method) {
      case DisplayMethod.obsidian:
        final url =
            'obsidian://open?path=${Uri.encodeComponent(file.absolute.path)}';
        final ok = await _settings.openExternalUrl(url);
        return ok ? OpenNoteResult.opened : OpenNoteResult.obsidianMissing;
      case DisplayMethod.system:
        final ok = await _settings.openPath(file.path);
        return ok ? OpenNoteResult.opened : OpenNoteResult.fileMissing;
      case DisplayMethod.inbox:
        return OpenNoteResult.fileMissing;
    }
  }

  static DisplayMethod _parse(String? raw) {
    switch (raw) {
      case 'system':
        return DisplayMethod.system;
      case 'obsidian':
        return DisplayMethod.obsidian;
      case 'inbox':
      default:
        return DisplayMethod.inbox;
    }
  }
}

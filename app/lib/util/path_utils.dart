import 'dart:io';

/// Obsidian Vault 内的统一跨平台目录协议。
class VaultPaths {
  static const String captureDirName = 'Universal Capture';
  static const String attachmentsDirName = 'attachments';

  static String captureDir(String vaultPath) =>
      _join(vaultPath, captureDirName);

  static String attachmentsDir(String vaultPath) =>
      _join(captureDir(vaultPath), attachmentsDirName);

  /// `Universal Capture/YYYY-MM-DD.md`
  static String dailyInboxFile(String vaultPath, DateTime date) =>
      _join(captureDir(vaultPath), '${_dateStamp(date)}.md');

  static String dateStamp(DateTime date) => _dateStamp(date);

  /// 附件在 Markdown 中的 Obsidian 内嵌引用路径。
  ///
  /// 日记文件和 attachments 目录同在 `Universal Capture/` 下。
  static String embedRef(String fileName) => '$attachmentsDirName/$fileName';

  static String _dateStamp(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String timeStamp(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';

  static String _join(String a, String b, [String? c]) {
    final sep = Platform.isWindows ? '\\' : '/';
    final base = a.endsWith(sep) ? a.substring(0, a.length - 1) : a;
    var p = '$base$sep$b';
    if (c != null) p = '$p$sep$c';
    return p;
  }
}

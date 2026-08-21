import 'dart:io';

/// Obsidian Vault 内的固定相对目录。见《方案》第二、三节。
class VaultPaths {
  static const String materialsDir = '素材';
  static const String inboxDirName = 'Inbox';
  static const String attachmentsDirName = 'attachments';

  static String inboxDir(String vaultPath) =>
      _join(vaultPath, materialsDir, inboxDirName);

  static String attachmentsDir(String vaultPath) =>
      _join(vaultPath, materialsDir, attachmentsDirName);

  /// `素材/Inbox/YYYY-MM-DD.md`
  static String dailyInboxFile(String vaultPath, DateTime date) =>
      _join(inboxDir(vaultPath), '${_dateStamp(date)}.md');

  static String dateStamp(DateTime date) => _dateStamp(date);

  /// 附件在 Markdown 中的 Obsidian 内嵌引用路径。
  ///
  /// Inbox 文件位于 `素材/Inbox/`，附件位于 `素材/attachments/`，
  /// 因此相对路径为 `../attachments/<fileName>`。
  static String embedRef(String fileName) => '../$attachmentsDirName/$fileName';

  static String _dateStamp(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String timeStamp(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}:'
      '${t.second.toString().padLeft(2, '0')}';

  static String _join(String a, String b, [String? c]) {
    final sep = Platform.isWindows ? '\\' : '/';
    final base = a.endsWith(sep) ? a.substring(0, a.length - 1) : a;
    var p = '$base$sep$b';
    if (c != null) p = '$p$sep$c';
    return p;
  }
}

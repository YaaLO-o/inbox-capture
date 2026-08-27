import '../models/capture.dart';
import '../util/path_utils.dart';

/// 把一条 Capture 格式化为追加到每日笔记的标准 Markdown 片段。
///
/// 附件引用使用标准 Markdown 语法：图片 `![](attachments/x.png)`、
/// 普通文件 `[显示名](attachments/x.pdf)`，Obsidian 与 Typora/VS Code 等
/// 任意标准 Markdown 工具均可正常渲染。历史 wiki 语法文件不迁移。
final class MarkdownFormatter {
  const MarkdownFormatter();

  String format(Capture capture) {
    final buffer = StringBuffer()
      ..writeln('## ${VaultPaths.timeStamp(capture.createdAt)}')
      ..writeln()
      ..writeln('<!-- capture:id=${capture.id} -->')
      ..writeln();
    final text = capture.text?.trim();
    if (text != null && text.isNotEmpty) {
      buffer
        ..writeln(text)
        ..writeln();
    }
    for (final attachment in capture.attachments) {
      final ref = VaultPaths.embedRef(attachment.fileName);
      final displayName = safeAttachmentDisplayName(attachment.displayName);
      buffer.writeln(
        attachment.isImage
            ? '![]($ref)'
            : '[${displayName ?? ref}]($ref)',
      );
      buffer.writeln();
    }
    return (buffer
          ..writeln('---')
          ..writeln())
        .toString();
  }
}

String? safeAttachmentDisplayName(String? displayName) {
  if (displayName == null) return null;
  final oneLine = displayName.replaceAll(RegExp(r'[\x00-\x1f\x7f]'), ' ');
  final safe = oneLine
      // 去掉会破坏 [label](url) 结构的字符（含括号）。
      .replaceAll(RegExp(r'[#|^:%\[\]()]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return safe.isEmpty ? null : safe;
}

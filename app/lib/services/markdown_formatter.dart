import '../models/capture.dart';
import '../util/path_utils.dart';

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
            ? '![[$ref]]'
            : displayName == null
            ? '[[$ref]]'
            : '[[$ref|$displayName]]',
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
      .replaceAll(RegExp(r'[#|^:%\[\]]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return safe.isEmpty ? null : safe;
}

import '../services/vault_storage.dart';

enum CaptureSource { desktopClipboard, share, clipboard }

final class CaptureInput {
  final CaptureSource source;
  final String? text;
  final List<CaptureAttachmentInput> attachments;
  final bool usesDesktopFileNames;

  const CaptureInput({
    this.source = CaptureSource.desktopClipboard,
    this.text,
    this.attachments = const [],
    this.usesDesktopFileNames = false,
  });

  bool get hasContent =>
      (text?.trim().isNotEmpty ?? false) || attachments.isNotEmpty;

  factory CaptureInput.fromMap(Map<Object?, Object?> map) {
    final rawText = map['text'];
    final parsed = <CaptureAttachmentInput>[];
    final rawAttachments = map['attachments'];
    if (rawAttachments is List) {
      for (final raw in rawAttachments) {
        if (raw is! Map) continue;
        final uri = raw['uri'];
        if (uri is! String || !uri.startsWith('content://')) continue;
        final rawExtension = raw['extension'];
        final normalized = rawExtension is String
            ? rawExtension.toLowerCase()
            : '';
        final extension = RegExp(r'^[a-z0-9]+$').hasMatch(normalized)
            ? normalized
            : '';
        parsed.add(
          CaptureAttachmentInput(
            source: UriAttachmentSource(uri),
            extension: extension,
            mimeType: raw['mimeType'] is String
                ? raw['mimeType'] as String
                : null,
            displayName: raw['displayName'] is String
                ? raw['displayName'] as String
                : null,
          ),
        );
      }
    }
    return CaptureInput(
      source: switch (map['source']) {
        'share' => CaptureSource.share,
        'clipboard' => CaptureSource.clipboard,
        _ => CaptureSource.desktopClipboard,
      },
      text: rawText is String ? rawText : null,
      attachments: List.unmodifiable(parsed),
    );
  }
}

final class CaptureAttachmentInput {
  final AttachmentSource source;
  final String extension;
  final String? mimeType;
  final String? displayName;

  const CaptureAttachmentInput({
    required this.source,
    required this.extension,
    this.mimeType,
    this.displayName,
  });
}

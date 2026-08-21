/// 统一的 Capture 原始数据模型。
///
/// 这里只描述"原始采集到的内容"，不包含任何分类/摘要等 AI 推理结果。
/// 见《Mac V0.1 开发执行方案》第九节。
class Capture {
  final String id;
  final DateTime createdAt;

  /// 文字内容（文字 Capture 时非空）。
  final String? text;

  /// 本次 Capture 附带的附件（图片 / Finder 复制的本地文件等）。
  final List<Attachment> attachments;

  const Capture({
    required this.id,
    required this.createdAt,
    this.text,
    this.attachments = const [],
  });

  bool get isEmpty =>
      (text == null || text!.trim().isEmpty) && attachments.isEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        if (text != null) 'text': text,
        if (attachments.isNotEmpty)
          'attachments': attachments.map((a) => a.toJson()).toList(),
      };
}

/// 附件的最小描述。文件本体落在 Obsidian Vault 的 attachments 目录，
/// 这里只记录它在 Vault 内的相对文件名与基础元信息。
class Attachment {
  final String id;

  /// 写入 attachments/ 后的文件名，例如 `20260821-103215-a82f.png`。
  final String fileName;

  /// 小写扩展名，不含点，例如 `png` / `mp4` / `pdf`。
  final String originalExtension;

  /// MIME 类型，仅作记录，可能为空。
  final String? mimeType;

  const Attachment({
    required this.id,
    required this.fileName,
    required this.originalExtension,
    this.mimeType,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileName': fileName,
        'originalExtension': originalExtension,
        if (mimeType != null) 'mimeType': mimeType,
      };
}

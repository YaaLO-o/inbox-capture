import 'package:flutter_test/flutter_test.dart';
import 'package:inbox_app/models/capture.dart';
import 'package:inbox_app/services/markdown_formatter.dart';

void main() {
  const formatter = MarkdownFormatter();

  test('formats a capture with text, image, and safe file display name', () {
    final capture = Capture(
      id: '20260824-093012-abcd',
      createdAt: DateTime(2026, 8, 24, 9, 30, 12),
      text: '  一段文字  ',
      attachments: const [
        Attachment(
          id: '20260824-093012-abcd',
          fileName: '20260824-093012-abcd.png',
          originalExtension: 'png',
        ),
        Attachment(
          id: '20260824-093012-abcd-1',
          fileName: '20260824-093012-abcd-1.pdf',
          originalExtension: 'pdf',
          displayName: '报告]|终版.pdf',
        ),
      ],
    );

    expect(formatter.format(capture), '''## 09:30

<!-- capture:id=20260824-093012-abcd -->

一段文字

![[attachments/20260824-093012-abcd.png]]

[[attachments/20260824-093012-abcd-1.pdf|报告终版.pdf]]

---

''');
  });

  test('omits empty text without adding a text paragraph', () {
    final capture = Capture(
      id: '20260824-093012-abcd',
      createdAt: DateTime(2026, 8, 24, 9, 30, 12),
      text: '  ',
    );

    expect(formatter.format(capture), '''## 09:30

<!-- capture:id=20260824-093012-abcd -->

---

''');
  });

  test(
    'sanitizes unsafe display names without breaking capture boundaries',
    () {
      final capture = Capture(
        id: '20260824-093012-abcd',
        createdAt: DateTime(2026, 8, 24, 9, 30, 12),
        attachments: const [
          Attachment(
            id: '20260824-093012-abcd',
            fileName: '20260824-093012-abcd',
            originalExtension: '',
            displayName: '报告\n---\n终版.bad#draft',
          ),
        ],
      );

      expect(formatter.format(capture), '''## 09:30

<!-- capture:id=20260824-093012-abcd -->

[[attachments/20260824-093012-abcd|报告 --- 终版.baddraft]]

---

''');
    },
  );

  test('embeds image extensions', () {
    final capture = Capture(
      id: '20260824-093012-abcd',
      createdAt: DateTime(2026, 8, 24, 9, 30, 12),
      attachments: const [
        Attachment(
          id: '20260824-093012-abcd',
          fileName: '20260824-093012-abcd.svg',
          originalExtension: 'svg',
        ),
      ],
    );

    expect(
      formatter.format(capture),
      contains('![[attachments/20260824-093012-abcd.svg]]'),
    );
  });

  test('formats ordinary files as links', () {
    final capture = Capture(
      id: '20260824-093012-abcd',
      createdAt: DateTime(2026, 8, 24, 9, 30, 12),
      attachments: const [
        Attachment(
          id: '20260824-093012-abcd',
          fileName: '20260824-093012-abcd.pdf',
          originalExtension: 'pdf',
        ),
      ],
    );

    expect(
      formatter.format(capture),
      contains('[[attachments/20260824-093012-abcd.pdf]]'),
    );
  });
}

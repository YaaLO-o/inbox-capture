import 'package:flutter_test/flutter_test.dart';
import 'package:inbox_app/models/app_release.dart';

void main() {
  group('AppVersion.parse', () {
    test('accepts strict three-part stable versions and compares numerically', () {
      expect(
        AppVersion.parse('v1.1.1').compareTo(AppVersion.parse('1.1.0')),
        greaterThan(0),
      );
      expect(
        AppVersion.parse('1.2.0').compareTo(AppVersion.parse('1.10.0')),
        lessThan(0),
      );
      expect(
        AppVersion.parse('2.0.0').compareTo(AppVersion.parse('2.0.0')),
        0,
      );
    });

    test('rejects malformed versions', () {
      expect(() => AppVersion.parse('1.2'), throwsFormatException);
      expect(() => AppVersion.parse('1.2.3-beta'), throwsFormatException);
      expect(() => AppVersion.parse('v1.2.3.4'), throwsFormatException);
    });
  });

  group('AppRelease.fromGitHubJson', () {
    test('selects the fixed universal dmg asset and sha256 digest', () {
      final release = AppRelease.fromGitHubJson({
        'tag_name': 'v1.1.1',
        'assets': [
          {
            'name': 'INbox-macos-universal.dmg',
            'browser_download_url': 'https://example.test/INbox.dmg',
            'digest': 'sha256:abc123',
            'size': 17288518,
          },
        ],
      });

      expect(release.version, AppVersion.parse('1.1.1'));
      expect(release.downloadUrl.toString(), 'https://example.test/INbox.dmg');
      expect(release.digest, 'abc123');
      expect(release.size, 17288518);
    });

    test('rejects payloads without the fixed universal dmg asset', () {
      expect(
        () => AppRelease.fromGitHubJson({
          'tag_name': 'v1.1.1',
          'assets': [
            {
              'name': 'INbox-macos-intel.dmg',
              'browser_download_url': 'https://example.test/INbox.dmg',
              'digest': 'sha256:abc123',
              'size': 17288518,
            },
          ],
        }),
        throwsFormatException,
      );
    });

    test('rejects payloads without a sha256 digest', () {
      expect(
        () => AppRelease.fromGitHubJson({
          'tag_name': 'v1.1.1',
          'assets': [
            {
              'name': 'INbox-macos-universal.dmg',
              'browser_download_url': 'https://example.test/INbox.dmg',
              'size': 17288518,
            },
          ],
        }),
        throwsFormatException,
      );
    });
  });
}

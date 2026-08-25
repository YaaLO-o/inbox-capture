class AppVersion implements Comparable<AppVersion> {
  static final RegExp _pattern = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)$');

  final int major;
  final int minor;
  final int patch;

  const AppVersion(this.major, this.minor, this.patch);

  factory AppVersion.parse(String value) {
    final match = _pattern.firstMatch(value);
    if (match == null) {
      throw FormatException('Invalid app version: $value');
    }

    return AppVersion(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  @override
  int compareTo(AppVersion other) {
    final majorResult = major.compareTo(other.major);
    if (majorResult != 0) return majorResult;

    final minorResult = minor.compareTo(other.minor);
    if (minorResult != 0) return minorResult;

    return patch.compareTo(other.patch);
  }

  @override
  bool operator ==(Object other) {
    return other is AppVersion &&
        major == other.major &&
        minor == other.minor &&
        patch == other.patch;
  }

  @override
  int get hashCode => Object.hash(major, minor, patch);

  @override
  String toString() => '$major.$minor.$patch';
}

class AppRelease {
  static const String assetName = 'INbox-macos-universal.dmg';

  final AppVersion version;
  final Uri downloadUrl;
  final String digest;
  final int size;

  const AppRelease({
    required this.version,
    required this.downloadUrl,
    required this.digest,
    required this.size,
  });

  factory AppRelease.fromGitHubJson(Map<String, Object?> json) {
    final version = AppVersion.parse(_readString(json, 'tag_name'));
    final assets = json['assets'];
    if (assets is! List) {
      throw const FormatException('GitHub release assets are missing');
    }

    Map<String, Object?>? matchedAsset;
    for (final asset in assets) {
      if (asset is! Map) continue;
      final candidate = Map<String, Object?>.from(asset.cast<Object?, Object?>());
      if (candidate['name'] == assetName) {
        matchedAsset = candidate;
        break;
      }
    }

    if (matchedAsset == null) {
      throw const FormatException('GitHub release asset is missing');
    }

    final digest = _readString(matchedAsset, 'digest');
    const digestPrefix = 'sha256:';
    if (!digest.startsWith(digestPrefix) || digest.length <= digestPrefix.length) {
      throw const FormatException('GitHub release digest is invalid');
    }

    final size = matchedAsset['size'];
    if (size is! int) {
      throw const FormatException('GitHub release size is invalid');
    }

    return AppRelease(
      version: version,
      downloadUrl: Uri.parse(_readString(matchedAsset, 'browser_download_url')),
      digest: digest.substring(digestPrefix.length),
      size: size,
    );
  }

  static String _readString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('GitHub release field "$key" is invalid');
    }
    return value;
  }
}

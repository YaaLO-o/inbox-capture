import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:inbox_app/models/app_release.dart';

class DownloadProgress {
  final int received;
  final int total;

  const DownloadProgress({
    required this.received,
    required this.total,
  });
}

class UpdateService {
  UpdateService({
    Uri? latestReleaseUri,
    Directory? downloadDirectory,
    HttpClient Function()? httpClientFactory,
  }) : _latestReleaseUri =
         latestReleaseUri ??
           Uri.parse(
             'https://api.github.com/repos/YaaLO-o/inbox-capture/releases/latest',
           ),
       _downloadDirectory = downloadDirectory ?? Directory.systemTemp,
       _httpClientFactory = httpClientFactory ?? HttpClient.new;

  final Uri _latestReleaseUri;
  final Directory _downloadDirectory;
  final HttpClient Function() _httpClientFactory;

  Future<AppRelease> fetchLatest() async {
    final client = _httpClientFactory();
    try {
      final request = await client.getUrl(_latestReleaseUri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      request.headers.set(HttpHeaders.userAgentHeader, 'INbox-App-Updater');

      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Failed to fetch latest release: ${response.statusCode}',
          uri: _latestReleaseUri,
        );
      }

      final payload = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(payload);
      if (decoded is! Map) {
        throw const FormatException('GitHub latest release payload is invalid');
      }

      return AppRelease.fromGitHubJson(
        Map<String, Object?>.from(decoded.cast<Object?, Object?>()),
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<File> download(
    AppRelease release, {
    void Function(DownloadProgress progress)? onProgress,
  }) async {
    final client = _httpClientFactory();
    File? file;

    try {
      final request = await client.getUrl(release.downloadUrl);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Failed to download release: ${response.statusCode}',
          uri: release.downloadUrl,
        );
      }

      final fileName = 'inbox-update-${DateTime.now().microsecondsSinceEpoch}.dmg';
      file = File('${_downloadDirectory.path}${Platform.pathSeparator}$fileName');
      final sink = file.openWrite();
      var received = 0;
      final total = response.contentLength >= 0 ? response.contentLength : release.size;

      try {
        await for (final chunk in response) {
          received += chunk.length;
          sink.add(chunk);
          onProgress?.call(
            DownloadProgress(received: received, total: total),
          );
        }
      } finally {
        await sink.close();
      }

      final isValid = await verifyDigest(file, release.digest);
      if (!isValid) {
        throw StateError('Downloaded update checksum did not match');
      }

      return file;
    } catch (_) {
      if (file != null && await file.exists()) {
        await file.delete();
      }
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  Future<bool> verifyDigest(File file, String expectedDigest) async {
    final digest = await crypto.sha256.bind(file.openRead()).first;
    return digest.toString() == expectedDigest.toLowerCase();
  }
}

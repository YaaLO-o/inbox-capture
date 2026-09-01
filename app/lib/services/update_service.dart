import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:inbox_app/models/app_release.dart';

class DownloadProgress {
  final int received;
  final int total;

  const DownloadProgress({required this.received, required this.total});
}

/// 更新检查、下载和 SHA-256 校验失败时抛出，便于 UI 区分网络错误与校验错误。
class UpdateException implements Exception {
  final String message;
  const UpdateException(this.message);
  @override
  String toString() => message;
}

class UpdateService {
  UpdateService({
    Uri? latestReleaseUri,
    Directory? downloadDirectory,
    HttpClient Function()? httpClientFactory,
    String? assetName,
  }) : _latestReleaseUri =
           latestReleaseUri ??
           Uri.parse(
             'https://api.github.com/repos/YaaLO-o/inbox-capture/releases/latest',
           ),
       _downloadDirectory = downloadDirectory ?? Directory.systemTemp,
       _httpClientFactory = httpClientFactory ?? HttpClient.new,
       _assetName =
           assetName ??
           (Platform.isWindows
               ? AppRelease.windowsAssetName
               : AppRelease.macOSAssetName);

  final Uri _latestReleaseUri;
  final Directory _downloadDirectory;
  final HttpClient Function() _httpClientFactory;
  final String _assetName;

  static const Duration _requestTimeout = Duration(seconds: 15);
  static const Duration _downloadTimeout = Duration(seconds: 60);

  Future<AppRelease> fetchLatest() async {
    final client = _httpClientFactory();
    client.connectionTimeout = _requestTimeout;
    try {
      final request = await client
          .getUrl(_latestReleaseUri)
          .timeout(_requestTimeout);
      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/vnd.github+json',
      );
      request.headers.set(HttpHeaders.userAgentHeader, 'INbox-App-Updater');

      final response = await request.close().timeout(_requestTimeout);
      if (response.statusCode != HttpStatus.ok) {
        throw UpdateException('检查更新失败（HTTP ${response.statusCode}）');
      }

      final payload = await response
          .transform(utf8.decoder)
          .join()
          .timeout(_requestTimeout);
      final decoded = jsonDecode(payload);
      if (decoded is! Map) {
        throw const UpdateException('更新信息格式无效');
      }

      return AppRelease.fromGitHubJson(
        Map<String, Object?>.from(decoded.cast<Object?, Object?>()),
        assetName: _assetName,
      );
    } on TimeoutException {
      throw const UpdateException('检查更新超时，请检查网络连接');
    } on SocketException {
      throw const UpdateException('无法连接到更新服务器，请检查网络');
    } on FormatException catch (e) {
      throw UpdateException('更新信息解析失败：$e');
    } finally {
      client.close(force: true);
    }
  }

  Future<File> download(
    AppRelease release, {
    void Function(DownloadProgress progress)? onProgress,
  }) async {
    if (!release.hasDownload) {
      throw const UpdateException('此版本尚未提供适用于当前系统的安装包');
    }
    final downloadUrl = release.downloadUrl!;
    final assetName = release.assetName!;
    final expectedDigest = release.digest!;
    final expectedSize = release.size!;
    final client = _httpClientFactory();
    client.connectionTimeout = _requestTimeout;
    Directory? tempDirectory;
    File? file;

    try {
      final request = await client.getUrl(downloadUrl).timeout(_requestTimeout);
      final response = await request.close().timeout(_requestTimeout);
      if (response.statusCode != HttpStatus.ok) {
        throw UpdateException('下载失败（HTTP ${response.statusCode}）');
      }

      tempDirectory = await _downloadDirectory.createTemp('inbox-update_');
      file = File('${tempDirectory.path}${Platform.pathSeparator}$assetName');
      final sink = file.openWrite();
      var received = 0;
      final total = response.contentLength >= 0
          ? response.contentLength
          : expectedSize;

      try {
        await for (final chunk in response.timeout(_downloadTimeout)) {
          received += chunk.length;
          sink.add(chunk);
          onProgress?.call(DownloadProgress(received: received, total: total));
        }
      } on TimeoutException {
        throw const UpdateException('下载超时，请检查网络后重试');
      } finally {
        await sink.close();
      }

      final isValid = await verifyDigest(file, expectedDigest);
      if (!isValid) {
        throw const UpdateException('下载文件校验失败，可能已损坏');
      }

      return file;
    } on SocketException {
      throw const UpdateException('下载失败，请检查网络连接');
    } catch (e) {
      if (tempDirectory != null && await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
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

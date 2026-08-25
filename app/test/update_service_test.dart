import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inbox_app/models/app_release.dart';
import 'package:inbox_app/services/update_service.dart';

void main() {
  const checksum =
      '9f64a747e1b97f131fabb6b447296c9b6f0201e79fb3c5356e6c77e89b6a806a';

  late HttpServer server;
  late Uri baseUri;
  String? acceptHeader;
  String? userAgentHeader;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUri = Uri.parse(
      'http://${server.address.address}:${server.port}',
    );
    acceptHeader = null;
    userAgentHeader = null;

    server.listen((request) async {
      switch (request.uri.path) {
        case '/latest':
          acceptHeader = request.headers.value(HttpHeaders.acceptHeader);
          userAgentHeader = request.headers.value(HttpHeaders.userAgentHeader);
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'tag_name': 'v1.1.1',
              'assets': [
                {
                  'name': AppRelease.assetName,
                  'browser_download_url': baseUri.resolve('/download').toString(),
                  'digest': 'sha256:$checksum',
                  'size': 4,
                },
              ],
            }),
          );
          await request.response.close();
        case '/download':
          request.response.headers.contentLength = 4;
          request.response.add(const [1, 2]);
          await request.response.flush();
          request.response.add(const [3, 4]);
          await request.response.close();
        default:
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
      }
    });
  });

  tearDown(() async {
    await server.close(force: true);
  });

  test('fetchLatest requests the GitHub payload and parses the release', () async {
    final service = UpdateService(latestReleaseUri: baseUri.resolve('/latest'));

    final release = await service.fetchLatest();

    expect(release.version, AppVersion.parse('1.1.1'));
    expect(
      release.downloadUrl,
      baseUri.resolve('/download'),
    );
    expect(release.digest, checksum);
    expect(acceptHeader, 'application/vnd.github+json');
    expect(userAgentHeader, isNotEmpty);
  });

  test('download saves bytes, reports final progress, and verifies checksum', () async {
    final directory = await Directory.systemTemp.createTemp(
      'update_service_test_',
    );
    addTearDown(() => directory.delete(recursive: true));

    final service = UpdateService(
      latestReleaseUri: baseUri.resolve('/latest'),
      downloadDirectory: directory,
    );
    final release = await service.fetchLatest();
    final progress = <DownloadProgress>[];

    final file = await service.download(release, onProgress: progress.add);

    expect(file.parent.path, isNot(directory.path));
    expect(file.parent.parent.path, directory.path);
    expect(await file.readAsBytes(), const [1, 2, 3, 4]);
    expect(progress, isNotEmpty);
    expect(progress.last.received, 4);
    expect(progress.last.total, 4);
    expect(await service.verifyDigest(file, checksum), isTrue);
  });

  test('download deletes the partial file when checksum verification fails', () async {
    final directory = await Directory.systemTemp.createTemp(
      'update_service_bad_checksum_',
    );
    addTearDown(() => directory.delete(recursive: true));

    final service = UpdateService(
      latestReleaseUri: baseUri.resolve('/latest'),
      downloadDirectory: directory,
    );

    await expectLater(
      () => service.download(
        AppRelease(
          version: AppVersion.parse('1.1.1'),
          downloadUrl: baseUri.resolve('/download'),
          digest: '0000',
          size: 4,
        ),
      ),
      throwsA(isA<UpdateException>()),
    );
    expect(directory.listSync(), isEmpty);
  });
}

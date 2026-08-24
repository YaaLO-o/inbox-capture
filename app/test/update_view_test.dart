import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inbox_app/main.dart';
import 'package:inbox_app/models/app_release.dart';
import 'package:inbox_app/services/settings_service.dart';
import 'package:inbox_app/services/update_service.dart';
import 'package:inbox_app/ui/update_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AppRelease release(String version) => AppRelease(
    version: AppVersion.parse(version),
    downloadUrl: Uri.parse('https://example.com/INbox.dmg'),
    digest: 'digest',
    size: 100,
  );

  Future<void> pumpUpdateView(
    WidgetTester tester, {
    required FakeUpdateService service,
    Future<void> Function(String dmgPath)? installer,
    VoidCallback? onClose,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: UpdateView(
          currentVersion: AppVersion.parse('1.1.1'),
          service: service,
          installer: installer ?? (_) async {},
          onClose: onClose ?? () {},
        ),
      ),
    );
  }

  Future<void> sendCommand(String method) {
    const channel = MethodChannel('com.inbox.app/commands');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final encoded = channel.codec.encodeMethodCall(MethodCall(method));
    final completer = Completer<void>();
    messenger.handlePlatformMessage(channel.name, encoded, (ByteData? data) {
      completer.complete();
    });
    return completer.future;
  }

  testWidgets(
    'command opens update view and close restores capture pill size',
    (tester) async {
      final vault = Directory.systemTemp.createTempSync('inbox_vault_');
      final settings = FakeSettingsService(
        vaultPath: vault.path,
        version: AppVersion.parse('1.1.1'),
      );
      final service = FakeUpdateService();
      addTearDown(() => vault.deleteSync(recursive: true));

      await tester.pumpWidget(
        InboxApp(settings: settings, updateService: service),
      );
      await tester.pump();
      await tester.pump();

      await sendCommand('checkForUpdates');
      await tester.pump();

      expect(settings.shows, 1);
      expect(settings.sizes, contains(const WindowSizeCall(420, 300, false)));
      expect(find.text('正在检查更新…'), findsOneWidget);

      service.completeFetch(release('1.1.2'));
      await tester.pump();

      expect(find.text('发现新版本 1.1.2'), findsOneWidget);

      await tester.tap(find.text('关闭'));
      await tester.pump();

      expect(settings.sizes.last, const WindowSizeCall(132, 132, false));
    },
  );

  testWidgets('shows available update, download progress, and install state', (
    tester,
  ) async {
    final service = FakeUpdateService();
    final installerCompleter = Completer<void>();
    var closes = 0;

    await pumpUpdateView(
      tester,
      service: service,
      installer: (_) => installerCompleter.future,
      onClose: () => closes += 1,
    );

    expect(find.text('正在检查更新…'), findsOneWidget);

    service.completeFetch(release('1.1.2'));
    await tester.pump();

    expect(find.text('发现新版本 1.1.2'), findsOneWidget);

    await tester.tap(find.text('下载并安装'));
    await tester.tap(find.text('下载并安装'));
    await tester.pump();
    service.reportProgress(const DownloadProgress(received: 50, total: 100));
    await tester.pump();

    expect(service.downloads, 1);
    expect(find.text('50%'), findsOneWidget);

    service.completeDownload('/tmp/INbox.dmg');
    await tester.pump();

    expect(find.text('正在完成安装，INbox 将重新启动…'), findsOneWidget);

    await tester.tap(find.text('关闭'));
    await tester.pump();

    expect(closes, 0);

    installerCompleter.complete();
    await tester.pump();
    await tester.tap(find.text('关闭'));

    expect(closes, 1);
  });

  testWidgets('keeps close disabled while a download is in flight', (
    tester,
  ) async {
    final service = FakeUpdateService();
    var closes = 0;
    var visible = true;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setHostState) {
            if (!visible) return const SizedBox.shrink();
            return UpdateView(
              currentVersion: AppVersion.parse('1.1.1'),
              service: service,
              installer: (_) async {},
              onClose: () {
                closes += 1;
                setHostState(() => visible = false);
              },
            );
          },
        ),
      ),
    );
    service.completeFetch(release('1.1.2'));
    await tester.pump();

    await tester.tap(find.text('下载并安装'));
    await tester.pump();
    service.reportProgress(const DownloadProgress(received: 50, total: 100));
    await tester.pump();

    await tester.tap(find.text('关闭'));
    await tester.pump();

    expect(closes, 0);
    expect(find.text('正在下载更新…'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
  });

  testWidgets('shows current state when latest release is not newer', (
    tester,
  ) async {
    final service = FakeUpdateService();

    await pumpUpdateView(tester, service: service);
    service.completeFetch(release('1.1.1'));
    await tester.pump();

    expect(find.text('当前已是最新版本'), findsOneWidget);
  });

  testWidgets('shows checksum failure and keeps close available', (
    tester,
  ) async {
    final service = FakeUpdateService();
    var closes = 0;

    await pumpUpdateView(tester, service: service, onClose: () => closes += 1);
    service.completeFetch(release('1.1.2'));
    await tester.pump();

    await tester.tap(find.text('下载并安装'));
    await tester.pump();
    service.failDownload(
      StateError('Downloaded update checksum did not match'),
    );
    await tester.pump();

    expect(find.text('校验失败，已保留当前版本'), findsOneWidget);

    await tester.tap(find.text('关闭'));
    expect(closes, 1);
  });
}

class FakeUpdateService extends UpdateService {
  final Completer<AppRelease> _fetchCompleter = Completer<AppRelease>();
  Completer<File>? _downloadCompleter;
  void Function(DownloadProgress progress)? _onProgress;
  int downloads = 0;

  @override
  Future<AppRelease> fetchLatest() => _fetchCompleter.future;

  @override
  Future<File> download(
    AppRelease release, {
    void Function(DownloadProgress progress)? onProgress,
  }) {
    downloads += 1;
    _onProgress = onProgress;
    _downloadCompleter = Completer<File>();
    return _downloadCompleter!.future;
  }

  void completeFetch(AppRelease release) {
    _fetchCompleter.complete(release);
  }

  void reportProgress(DownloadProgress progress) {
    _onProgress!(progress);
  }

  void completeDownload(String path) {
    _downloadCompleter!.complete(File(path));
  }

  void failDownload(Object error) {
    _downloadCompleter!.completeError(error);
  }
}

class FakeSettingsService extends SettingsService {
  final String? vaultPath;
  final AppVersion version;
  final List<WindowSizeCall> sizes = [];
  final List<String> installedPaths = [];
  int shows = 0;

  FakeSettingsService({required this.vaultPath, required this.version});

  @override
  Future<String?> loadValidVaultPath() async => vaultPath;

  @override
  Future<AppVersion> getAppVersion() async => version;

  @override
  Future<void> setWindowSize(
    double width,
    double height, {
    bool animate = true,
  }) async {
    sizes.add(WindowSizeCall(width, height, animate));
  }

  @override
  Future<void> showWindow() async {
    shows += 1;
  }

  @override
  Future<void> installUpdate(String dmgPath) async {
    installedPaths.add(dmgPath);
  }
}

class WindowSizeCall {
  final double width;
  final double height;
  final bool animate;

  const WindowSizeCall(this.width, this.height, this.animate);

  @override
  bool operator ==(Object other) =>
      other is WindowSizeCall &&
      other.width == width &&
      other.height == height &&
      other.animate == animate;

  @override
  int get hashCode => Object.hash(width, height, animate);

  @override
  String toString() =>
      'WindowSizeCall(width: $width, height: $height, animate: $animate)';
}

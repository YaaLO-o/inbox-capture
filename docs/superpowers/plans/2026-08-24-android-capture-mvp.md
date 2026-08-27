# Android Capture MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an Android API 29+ client to the existing INbox Flutter app that saves shared content and foreground clipboard text into the same Markdown and attachments format as macOS.

**Architecture:** Dart remains the single Capture model, naming, formatting, orchestration, and rollback core. Desktop storage uses filesystem paths; Android storage uses a Kotlin SAF adapter behind MethodChannels, while native Android activities and one foreground overlay service supply user-triggered Capture inputs to one application-owned Flutter engine.

**Tech Stack:** Flutter 3.47.1, Dart 3.13.1, Kotlin, Android API 29+, Android SDK 36, Storage Access Framework, `ContentResolver`, `DocumentFile`, MethodChannel, `TYPE_APPLICATION_OVERLAY`, foreground services

**Spec:** `docs/superpowers/specs/2026-08-24-android-capture-mvp-design.md`

## Global Constraints

- Work only on `feature/android-capture-mvp`; do not merge `main`.
- Set Android `minSdk` to exactly 29 and test the primary device on Android 16 / HyperOS 3.1.
- Keep `Universal Capture/YYYY-MM-DD.md` and `Universal Capture/attachments/` unchanged.
- Keep the exact Capture order `## HH:mm`, blank line, `<!-- capture:id=... -->`, content, `---`.
- Keep image embeds as `![[attachments/attachment-file-name]]` and non-image links as `[[attachments/attachment-file-name|sanitized-display-name]]`.
- Do not introduce AI, search, sync, accounts, backend, database, content deduplication, history UI, Accessibility Service, `MANAGE_EXTERNAL_STORAGE`, or boot auto-start.
- Do not pass large attachment bytes through MethodChannel; Kotlin copies Android `content://` streams directly into SAF.
- Do not replace Android tree URIs with pseudo filesystem paths.
- Do not change current macOS/Windows output or desktop UI behavior.
- Implement every behavior with a red-green test cycle and commit after each task.
- Stop after the clipboard feasibility gate if Android 16 / HyperOS cannot read clipboard text reliably from the focused translucent Activity.

## File Map

### Shared Dart

- `app/lib/models/capture.dart`: persisted Capture and attachment metadata.
- `app/lib/models/capture_input.dart`: platform-neutral text and attachment source inputs.
- `app/lib/services/markdown_formatter.dart`: the only Capture-to-Markdown formatter.
- `app/lib/services/vault_storage.dart`: async storage contract.
- `app/lib/services/desktop_file_vault_storage.dart`: filesystem implementation for macOS/Windows.
- `app/lib/services/android_saf_vault_storage.dart`: Dart proxy for Kotlin SAF operations.
- `app/lib/services/capture_service.dart`: serialization, IDs, imports, append, rollback, and desktop clipboard entrypoint.
- `app/lib/services/android_capture_dispatcher.dart`: native-to-Dart Capture request handler and ready handshake.
- `app/lib/services/android_vault_settings.dart`: Android Vault descriptor and settings channel.
- `app/lib/main.dart`: platform split between existing desktop UI and Android settings UI.
- `app/lib/ui/android_settings_view.dart`: minimal Android settings and permission page.

### Android Kotlin

- `app/android/app/src/main/kotlin/com/inbox/inbox_app/InboxApplication.kt`: owns and caches one Flutter engine.
- `app/android/app/src/main/kotlin/com/inbox/inbox_app/MainActivity.kt`: attaches the cached engine and launches the SAF picker.
- `app/android/app/src/main/kotlin/com/inbox/inbox_app/AndroidCaptureBridge.kt`: ready handshake and native-to-Dart Capture calls.
- `app/android/app/src/main/kotlin/com/inbox/inbox_app/AndroidVaultBridge.kt`: one Vault MethodChannel handler and Activity attachment point.
- `app/android/app/src/main/kotlin/com/inbox/inbox_app/VaultPreferences.kt`: persisted tree URI and display name.
- `app/android/app/src/main/kotlin/com/inbox/inbox_app/SafVaultStore.kt`: all `DocumentFile` and `ContentResolver` I/O.
- `app/android/app/src/main/kotlin/com/inbox/inbox_app/ShareIntentParser.kt`: normalizes `ACTION_SEND` and `ACTION_SEND_MULTIPLE`.
- `app/android/app/src/main/kotlin/com/inbox/inbox_app/ShareCaptureActivity.kt`: short-lived Share target.
- `app/android/app/src/main/kotlin/com/inbox/inbox_app/ClipboardCaptureActivity.kt`: focused clipboard probe and Capture entrypoint.
- `app/android/app/src/main/kotlin/com/inbox/inbox_app/OverlayPositioner.kt`: pure drag threshold, bounds, and edge snap math.
- `app/android/app/src/main/kotlin/com/inbox/inbox_app/OverlayService.kt`: notification, overlay view, dragging, click Capture, and stop action.
- `app/android/app/src/main/AndroidManifest.xml`: application class, permissions, activities, service, and Share filters.
- `app/android/app/src/main/res/values/styles.xml`: translucent Capture Activity theme.
- `app/android/app/src/main/res/values/strings.xml`: visible Android labels and permission copy.

### Tests

- `app/test/markdown_formatter_test.dart`: exact format compatibility.
- `app/test/capture_service_test.dart`: shared transaction and rollback behavior.
- `app/test/android_saf_vault_storage_test.dart`: SAF channel arguments and errors.
- `app/test/android_capture_dispatcher_test.dart`: native Capture request contract.
- `app/test/android_vault_settings_test.dart`: Vault restoration contract.
- `app/test/android_settings_view_test.dart`: minimal settings UI.
- `app/android/app/src/test/kotlin/com/inbox/inbox_app/OverlayPositionerTest.kt`: pure overlay geometry.
- `app/android/app/src/androidTest/kotlin/com/inbox/inbox_app/ShareIntentParserTest.kt`: Android Intent parsing.
- `app/android/app/src/androidTest/kotlin/com/inbox/inbox_app/SafVaultStoreTest.kt`: provider-backed file creation, append, import, and rollback.

---

### Task 1: Install the Android toolchain and add the Android target

**Files:**
- Create: `app/android/` using Flutter's Android template
- Modify: `app/android/app/build.gradle.kts`
- Modify: `app/android/app/src/main/AndroidManifest.xml`
- Modify: `app/android/app/src/main/res/values/strings.xml`
- Modify: `app/pubspec.yaml`

**Interfaces:**
- Produces Android application ID `com.inbox.inbox_app`.
- Produces an installable API 29+ debug APK.
- Keeps the existing Dart entrypoint `main()`.

- [ ] **Step 1: Verify the external prerequisites before changing files**

Run:

```bash
flutter --version
flutter doctor -v
flutter devices
flutter emulators
java -version
adb version
adb devices -l
```

Expected: Flutter and Dart resolve; `flutter doctor -v` marks Android toolchain healthy; Java and ADB resolve; at least one emulator or the Xiaomi device is listed. If Android Studio/SDK/JDK/ADB is still missing, stop this task and ask the user to complete Android Studio's first-run SDK setup. Do not edit shell profiles or guess SDK paths.

- [ ] **Step 2: Accept licenses after the SDK exists**

Run:

```bash
flutter doctor --android-licenses
flutter doctor -v
```

Expected: all licenses accepted and Android toolchain marked healthy.

- [ ] **Step 3: Generate only the Android target**

Run from `app/`:

```bash
flutter create --platforms=android --org com.inbox --project-name inbox_app .
```

Inspect `git status` and confirm that no macOS or Windows runner file changed. Restore generated comment-only churn with surgical patches if Flutter touched unrelated tracked files.

- [ ] **Step 4: Set the Android baseline and visible name**

In `android/app/build.gradle.kts`, keep Flutter's generated compile/target SDK values and set:

```kotlin
defaultConfig {
    applicationId = "com.inbox.inbox_app"
    minSdk = 29
    targetSdk = flutter.targetSdkVersion
    versionCode = flutter.versionCode
    versionName = flutter.versionName
}
```

Set `android:label="INbox"` in the application element and update `pubspec.yaml` description from desktop-only wording to `Personal capture Inbox for desktop and Android.`

- [ ] **Step 5: Build and launch the unmodified Flutter UI as an Android smoke test**

Run:

```bash
flutter pub get
flutter build apk --debug
flutter run
```

Expected: build exits 0 and the process starts. The desktop-shaped UI may be visually wrong at this task; startup must not crash.

- [ ] **Step 6: Verify desktop tests and commit**

Run:

```bash
dart analyze lib test
flutter test
```

Expected: all existing tests pass.

Commit:

```bash
git add app/android app/pubspec.yaml app/pubspec.lock
git commit -m "build: add Android application target"
```

### Task 2: Extract the one Markdown formatter and async storage boundary

**Files:**
- Create: `app/lib/services/markdown_formatter.dart`
- Create: `app/lib/services/vault_storage.dart`
- Create: `app/lib/services/desktop_file_vault_storage.dart`
- Create: `app/test/markdown_formatter_test.dart`
- Modify: `app/lib/services/capture_service.dart`
- Delete: `app/lib/services/storage_service.dart`
- Modify: `app/test/capture_service_test.dart`

**Interfaces:**
- Produces `MarkdownFormatter.format(Capture capture) -> String`.
- Produces `VaultStorage.ensureLayout`, `importAttachment`, `appendMarkdown`, and `deleteAttachment`.
- Produces `VaultStorageException(code, message)` with codes `vaultUnavailable`, `permissionDenied`, `importFailed`, and `appendFailed`.
- Produces `DesktopFileVaultStorage` with filesystem-path Vault IDs.
- Keeps `CaptureService.captureNow(String vaultId, {DateTime? now})` for desktop callers.

- [ ] **Step 1: Write failing exact-format tests**

Create a formatter test with fixed input:

```dart
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

expect(MarkdownFormatter().format(capture), '''## 09:30

<!-- capture:id=20260824-093012-abcd -->

一段文字

![[attachments/20260824-093012-abcd.png]]

[[attachments/20260824-093012-abcd-1.pdf|报告终版.pdf]]

---

''');
```

Also copy the existing empty-text, unsafe display-name, image-extension, and ordinary-file expectations into this test file.

- [ ] **Step 2: Run the formatter test and verify red**

Run: `flutter test test/markdown_formatter_test.dart`

Expected: compile failure because `MarkdownFormatter` does not exist.

- [ ] **Step 3: Implement the pure formatter**

Create:

```dart
final class MarkdownFormatter {
  const MarkdownFormatter();

  String format(Capture capture) {
    final buffer = StringBuffer()
      ..writeln('## ${VaultPaths.timeStamp(capture.createdAt)}')
      ..writeln()
      ..writeln('<!-- capture:id=${capture.id} -->')
      ..writeln();
    final text = capture.text?.trim();
    if (text != null && text.isNotEmpty) buffer..writeln(text)..writeln();
    for (final attachment in capture.attachments) {
      final ref = VaultPaths.embedRef(attachment.fileName);
      final displayName = safeAttachmentDisplayName(attachment.displayName);
      buffer.writeln(attachment.isImage
          ? '![[$ref]]'
          : displayName == null ? '[[$ref]]' : '[[$ref|$displayName]]');
      buffer.writeln();
    }
    return (buffer..writeln('---')..writeln()).toString();
  }
}
```

Move the existing display-name sanitization unchanged into a top-level tested helper in this file.

- [ ] **Step 4: Write the failing async storage migration tests**

Define a fake implementing the intended contract:

```dart
abstract interface class VaultStorage {
  Future<void> ensureLayout(String vaultId);
  Future<void> importAttachment(
    String vaultId,
    AttachmentSource source,
    String fileName,
  );
  Future<void> appendMarkdown(String vaultId, DateTime date, String markdown);
  Future<void> deleteAttachment(String vaultId, String fileName);
}

final class VaultStorageException implements Exception {
  final String code;
  final String message;
  const VaultStorageException(this.code, this.message);
}
```

Update one existing Capture test to `await` every storage operation and assert the exact formatter output passed to `appendMarkdown`.

Run: `flutter test test/capture_service_test.dart`

Expected: compile failure because the storage interface and attachment source type are missing.

- [ ] **Step 5: Implement the storage seam without changing desktop behavior**

Create the interface above. Move filesystem operations from `StorageService` into `DesktopFileVaultStorage`; use `FileMode.append` with `flush: true`. For this task define these source types in `vault_storage.dart`:

```dart
sealed class AttachmentSource { const AttachmentSource(); }
final class BytesAttachmentSource extends AttachmentSource {
  final Uint8List bytes;
  const BytesAttachmentSource(this.bytes);
}
final class FileAttachmentSource extends AttachmentSource {
  final String path;
  const FileAttachmentSource(this.path);
}
final class UriAttachmentSource extends AttachmentSource {
  final String uri;
  const UriAttachmentSource(this.uri);
}
```

`DesktopFileVaultStorage` supports bytes and file sources and throws `UnsupportedError` for URI sources. Make `CaptureService` await the new interface and call `MarkdownFormatter` instead of formatting inside storage.

- [ ] **Step 6: Verify byte-for-byte desktop compatibility and commit**

Run:

```bash
flutter test test/markdown_formatter_test.dart test/capture_service_test.dart
dart analyze lib test
flutter test
```

Expected: all tests pass with the same existing Markdown expectations.

Commit:

```bash
git add app/lib/services app/test/markdown_formatter_test.dart app/test/capture_service_test.dart
git commit -m "refactor: isolate shared capture storage"
```

### Task 3: Add platform-neutral Capture requests, serialization, and rollback

**Files:**
- Create: `app/lib/models/capture_input.dart`
- Modify: `app/lib/services/capture_service.dart`
- Modify: `app/lib/services/clipboard_service.dart`
- Modify: `app/test/capture_service_test.dart`

**Interfaces:**
- Consumes `VaultStorage` and `AttachmentSource` from Task 2.
- Produces `CaptureInput`, `CaptureAttachmentInput`, and `CaptureInput.fromMap`.
- Produces `CaptureSource.desktopClipboard`, `.share`, and `.clipboard`.
- Produces `CaptureService.captureInput(String vaultId, CaptureInput input, {DateTime? now})`.
- Keeps `captureNow` as desktop clipboard-to-`CaptureInput` adaptation.

- [ ] **Step 1: Write failing model serialization tests**

Add tests for a native Android request:

```dart
final input = CaptureInput.fromMap({
  'text': 'https://example.com',
  'attachments': [
    {
      'uri': 'content://provider/photo/7',
      'displayName': '照片.png',
      'mimeType': 'image/png',
      'extension': 'png',
    },
  ],
});

expect(input.text, 'https://example.com');
expect(input.attachments.single.source,
    isA<UriAttachmentSource>());
expect(input.attachments.single.extension, 'png');
```

Also test uppercase extensions normalize to lowercase, unsafe extensions become empty, non-string map fields are ignored, and an empty request reports `hasContent == false`.

- [ ] **Step 2: Run the model tests and verify red**

Run: `flutter test test/capture_service_test.dart`

Expected: compile failure because `CaptureInput` and `captureInput` do not exist.

- [ ] **Step 3: Implement immutable input models**

Use:

```dart
final class CaptureInput {
  final CaptureSource source;
  final String? text;
  final List<CaptureAttachmentInput> attachments;
  const CaptureInput({
    this.source = CaptureSource.desktopClipboard,
    this.text,
    this.attachments = const [],
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
        parsed.add(CaptureAttachmentInput(
          source: UriAttachmentSource(uri),
          extension: extension,
          mimeType: raw['mimeType'] is String
              ? raw['mimeType'] as String
              : null,
          displayName: raw['displayName'] is String
              ? raw['displayName'] as String
              : null,
        ));
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

enum CaptureSource { desktopClipboard, share, clipboard }

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
```

Implement the parsing directly and reject non-`content://` URI strings for Android-native maps. Keep bytes and file construction as typed Dart constructors used by the desktop adapter.

- [ ] **Step 4: Write failing transactional coordinator tests**

Add a recording fake storage and cover:

```dart
expect(storage.events, [
  'ensure:vault',
  'import:20260824-093012-abcd.png',
  'append:2026-08-24',
]);
```

Use a fixed ID generator injection so exact filenames are deterministic. Add cases where the second import throws and where append throws. Expected event tail:

```dart
['delete:20260824-093012-abcd.png']
```

Also start two `captureInput` futures before completing the first fake import and assert the second request does not call storage until the first finishes.

- [ ] **Step 5: Implement the minimal serial transaction**

Inject `String Function(DateTime) idGenerator` with `generateCaptureId` as the default. Chain requests on a private future:

```dart
Future<CaptureResult> captureInput(
  String vaultId,
  CaptureInput input, {
  DateTime? now,
}) {
  final completer = Completer<CaptureResult>();
  _queue = _queue.then((_) async {
    try {
      completer.complete(await _captureInput(vaultId, input, now: now));
    } catch (error, stack) {
      completer.completeError(error, stack);
    }
  });
  return completer.future;
}
```

Inside `_captureInput`, import attachments in order, record completed filenames, format only after all imports succeed, append once, and delete completed files in reverse order on failure. Expand the result enum to `CaptureStatus.saved`, `.empty`, `.vaultUnavailable`, `.permissionDenied`, and `.error`; map typed storage failures without exposing stack traces. Return `CaptureStatus.error` even if cleanup fails. Convert current `ClipboardContent` into typed byte/file attachment inputs with source `desktopClipboard` and delegate `captureNow` to this method.

- [ ] **Step 6: Verify and commit**

Run:

```bash
flutter test test/capture_service_test.dart test/clipboard_service_test.dart
dart analyze lib test
flutter test
```

Expected: all pass.

Commit:

```bash
git add app/lib/models/capture_input.dart app/lib/services/capture_service.dart app/lib/services/clipboard_service.dart app/test
git commit -m "feat: add transactional shared capture inputs"
```

### Task 4: Own one Flutter engine and establish Android channel contracts

**Files:**
- Create: `app/lib/services/android_capture_dispatcher.dart`
- Create: `app/test/android_capture_dispatcher_test.dart`
- Create: `app/android/app/src/main/kotlin/com/inbox/inbox_app/InboxApplication.kt`
- Create: `app/android/app/src/main/kotlin/com/inbox/inbox_app/AndroidCaptureBridge.kt`
- Modify: `app/android/app/src/main/kotlin/com/inbox/inbox_app/MainActivity.kt`
- Modify: `app/android/app/src/main/AndroidManifest.xml`
- Modify: `app/lib/main.dart`

**Interfaces:**
- Produces channel `com.inbox.app/android_capture`.
- Dart handles `capture` with a map and returns `{status, captureId, message}`.
- Dart calls native `coreReady` after installing its handler.
- Kotlin exposes `AndroidCaptureBridge.capture(Map<String, Any?>, callback)`.

- [ ] **Step 1: Write the failing Dart channel test**

Install a mocked native side and assert:

```dart
final dispatcher = AndroidCaptureDispatcher(
  vaultId: () async => 'content://vault/tree',
  capture: (_, input) async => const CaptureResult(
    CaptureStatus.saved,
    captureId: '20260824-093012-abcd',
  ),
);
await dispatcher.start();

final result = await sendNativeMethodCall('capture', {
  'source': 'share',
  'text': 'hello',
  'attachments': <Object?>[],
});
expect(result, {
  'status': 'saved',
  'captureId': '20260824-093012-abcd',
});
expect(nativeCalls.single.method, 'coreReady');
```

Also test no Vault returns `vaultUnavailable`, malformed input returns `error`, and `stop()` removes the handler.

- [ ] **Step 2: Run the Dart test and verify red**

Run: `flutter test test/android_capture_dispatcher_test.dart`

Expected: missing-class compile failure.

- [ ] **Step 3: Implement the Dart dispatcher**

Use a dedicated `MethodChannel`. Install the `capture` handler before invoking `coreReady`. Map the stable statuses `saved`, `empty`, `vaultUnavailable`, `permissionDenied`, and `error`. In this task, Android `main()` installs the dispatcher with `vaultId: () async => null` and a capture callback returning `vaultUnavailable`; this establishes engine readiness without writing to a fake filesystem Vault. Task 5 replaces those closures with `AndroidVaultSettings.getVault` and the real `AndroidSafVaultStorage`. Desktop initialization remains unchanged.

- [ ] **Step 4: Add the application-owned engine**

Implement:

```kotlin
class InboxApplication : FlutterApplication() {
    lateinit var engine: FlutterEngine
        private set

    override fun onCreate() {
        super.onCreate()
        engine = FlutterEngine(this)
        GeneratedPluginRegistrant.registerWith(engine)
        AndroidCaptureBridge.attach(engine.dartExecutor.binaryMessenger)
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )
        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
    }

    companion object { const val ENGINE_ID = "inbox_engine" }
}
```

Make `MainActivity.provideFlutterEngine` return the application engine and `shouldDestroyEngineWithHost()` return false. Set `android:name=".InboxApplication"` in Manifest.

- [ ] **Step 5: Implement queued ready handshake**

`AndroidCaptureBridge` owns one MethodChannel, a `ready` boolean, and a FIFO list of pending requests. Handle Dart's `coreReady` by setting ready and draining the list. `capture` sends immediately when ready or enqueues with a ten-second main-thread timeout. Map Flutter errors to the native callback once. Every request map includes a unique native `taskId`; Dart echoes it in the result so a late callback cannot complete a newer Activity request.

- [ ] **Step 6: Build, test, and commit**

Run:

```bash
flutter test test/android_capture_dispatcher_test.dart
flutter build apk --debug
flutter run
```

Expected: test/build pass and Android startup has no duplicate-engine or channel crash.

Commit:

```bash
git add app/lib/main.dart app/lib/services/android_capture_dispatcher.dart app/test/android_capture_dispatcher_test.dart app/android
git commit -m "feat: add Android capture engine bridge"
```

### Task 5: Select, persist, validate, and write a SAF Vault

**Files:**
- Create: `app/lib/services/android_saf_vault_storage.dart`
- Create: `app/lib/services/android_vault_settings.dart`
- Create: `app/lib/ui/android_settings_view.dart`
- Create: `app/test/android_saf_vault_storage_test.dart`
- Create: `app/test/android_vault_settings_test.dart`
- Create: `app/test/android_settings_view_test.dart`
- Create: `app/android/app/src/main/kotlin/com/inbox/inbox_app/VaultPreferences.kt`
- Create: `app/android/app/src/main/kotlin/com/inbox/inbox_app/SafVaultStore.kt`
- Create: `app/android/app/src/main/kotlin/com/inbox/inbox_app/AndroidVaultBridge.kt`
- Create: `app/android/app/src/androidTest/kotlin/com/inbox/inbox_app/SafVaultStoreTest.kt`
- Create: `app/android/app/src/androidTest/kotlin/com/inbox/inbox_app/TestDocumentsProvider.kt`
- Create: `app/android/app/src/androidTest/AndroidManifest.xml`
- Modify: `app/android/app/src/main/kotlin/com/inbox/inbox_app/InboxApplication.kt`
- Modify: `app/android/app/src/main/kotlin/com/inbox/inbox_app/MainActivity.kt`
- Modify: `app/android/app/build.gradle.kts`
- Modify: `app/lib/main.dart`

**Interfaces:**
- Produces channel `com.inbox.app/android_vault`.
- Produces `VaultDescriptor(id, displayName, accessible)`.
- Produces methods `getVault`, `pickVault`, `clearVault`, `ensureLayout`, `importUri`, `appendMarkdown`, and `deleteAttachment`.
- `AndroidSafVaultStorage` implements `VaultStorage`.
- `AndroidVaultBridge` is the only Kotlin method handler for this channel; `MainActivity` attaches and detaches as its picker host.

- [ ] **Step 1: Write failing Dart settings and storage channel tests**

Mock `com.inbox.app/android_vault` and assert:

```dart
final descriptor = (await settings.getVault())!;
expect(descriptor.id, 'content://provider/tree/primary%3AObsidian');
expect(descriptor.displayName, 'Obsidian');
expect(descriptor.accessible, isTrue);

await storage.appendMarkdown(
  descriptor.id,
  DateTime(2026, 8, 24),
  '## 09:30\n\n---\n\n',
);
expect(lastCall.method, 'appendMarkdown');
expect(lastCall.arguments, containsPair('date', '2026-08-24'));
```

Test platform error codes `VAULT_UNAVAILABLE`, `IMPORT_FAILED`, and `APPEND_FAILED` propagate as typed Dart exceptions.

- [ ] **Step 2: Run tests and verify red**

Run:

```bash
flutter test test/android_saf_vault_storage_test.dart test/android_vault_settings_test.dart
```

Expected: missing classes.

- [ ] **Step 3: Add Android test dependencies and write failing SAF tests**

Add the stable AndroidX test dependencies published for this toolchain:

```kotlin
defaultConfig {
    testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
}

dependencies {
    testImplementation("junit:junit:4.13.2")
    androidTestImplementation("androidx.test:core-ktx:1.7.0")
    androidTestImplementation("androidx.test.ext:junit:1.3.0")
    androidTestImplementation("androidx.test:runner:1.7.0")
}
```

Create an androidTest-only `DocumentsProvider` backed by a temporary directory. It must implement root/document queries, child queries, create, delete, and `openDocument` modes `r`, `w`, `wt`, and `wa`. Register its authority as `${applicationId}.test.documents` only in `src/androidTest/AndroidManifest.xml`.

Write failing tests that call `ensureLayout`, import bytes from a test provider URI, append twice to one date, and delete the imported attachment. Assert the final Markdown is the concatenation of both sections.

Run: `cd android && ./gradlew connectedDebugAndroidTest`

Expected: compile failure because `SafVaultStore` and `AndroidVaultBridge` do not exist.

- [ ] **Step 4: Implement Kotlin Vault persistence and validation**

`VaultPreferences` stores exactly `vaultTreeUri` and `vaultDisplayName`. `isAccessible` must require a matching persisted URI permission with read and write flags plus `DocumentFile.fromTreeUri(...).canWrite()`.

`InboxApplication` constructs one `AndroidVaultBridge`, attaches its single handler to the cached engine messenger, and retains it. `MainActivity.onResume()` calls `vaultBridge.attachActivity(this)` and `onPause()` calls `vaultBridge.detachActivity(this)`. The bridge delegates file operations to `SafVaultStore`; `pickVault` fails with `NO_ACTIVITY` if no visible MainActivity is attached. This prevents two handlers from overwriting each other on the same channel.

In MainActivity, launch:

```kotlin
Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
    addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
    addFlags(Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
}
```

On success call `takePersistableUriPermission`, validate, create the two directories, then persist. Cancellation returns null without modifying the prior Vault.

- [ ] **Step 5: Implement SAF file operations**

Use focused helpers:

```kotlin
fun ensureLayout(treeUri: Uri): CaptureDirs
fun importUri(treeUri: Uri, sourceUri: Uri, fileName: String)
fun appendMarkdown(treeUri: Uri, date: String, markdown: String)
fun deleteAttachment(treeUri: Uri, fileName: String)
```

Create/find `Universal Capture` and `attachments` with `DocumentFile`. Import attachments with `contentResolver.openInputStream(sourceUri)` and `openOutputStream(target.uri, "w")`, `copyTo`, flush, and `use` blocks.

For Markdown, try `openFileDescriptor(uri, "wa")`. If the provider rejects append mode, read the existing small Markdown file fully, then open mode `"wt"` and write `existing + markdown`. Never truncate until the existing text has been read successfully.

- [ ] **Step 6: Implement Dart proxies and the first Android UI test**

Make `AndroidSafVaultStorage` serialize URI sources only. Add a white Material 3 settings view and assert these exact labels:

```dart
expect(find.text('Vault'), findsOneWidget);
expect(find.text('重新选择 Vault'), findsOneWidget);
expect(find.text('悬浮 Capture'), findsOneWidget);
expect(find.text('权限'), findsOneWidget);
```

On Android, `main.dart` renders this view instead of desktop onboarding/pet. Selecting a Vault updates the descriptor and runs a real text Capture button available only during this task as `写入测试 Capture`; remove that button after the first real SAF write succeeds.

Map Kotlin error codes `VAULT_UNAVAILABLE`, `PERMISSION_DENIED`, `IMPORT_FAILED`, and `APPEND_FAILED` to the exact Dart `VaultStorageException` codes defined in Task 2. Replace Task 4's temporary dispatcher closures with the accessible Vault descriptor ID and a `CaptureService` backed by `AndroidSafVaultStorage`.

- [ ] **Step 7: Verify the first real Markdown on an emulator or device**

Run the App, select a test directory, invoke the temporary test Capture, and inspect through ADB or the system Files app. Expected files:

```text
Universal Capture/YYYY-MM-DD.md
Universal Capture/attachments/
```

Expected Markdown contains a valid `capture:id` section. Force-stop and restart the App; expected Vault descriptor remains accessible.

- [ ] **Step 8: Remove the temporary test button, run tests, and commit**

Run:

```bash
flutter test test/android_saf_vault_storage_test.dart test/android_vault_settings_test.dart test/android_settings_view_test.dart
dart analyze lib test
flutter test
flutter build apk --debug
```

Expected: all pass.

Commit:

```bash
git add app/lib app/test app/android
git commit -m "feat: write captures through Android SAF"
```

### Task 6: Receive text and URL shares without opening the full page

**Files:**
- Create: `app/android/app/src/main/kotlin/com/inbox/inbox_app/ShareIntentParser.kt`
- Create: `app/android/app/src/main/kotlin/com/inbox/inbox_app/ShareCaptureActivity.kt`
- Create: `app/android/app/src/androidTest/kotlin/com/inbox/inbox_app/ShareIntentParserTest.kt`
- Modify: `app/android/app/src/main/AndroidManifest.xml`
- Modify: `app/android/app/src/main/res/values/styles.xml`
- Modify: `app/android/app/src/main/res/values/strings.xml`

**Interfaces:**
- Produces `ShareRequest(text: String?, attachments: List<SharedUri>)`.
- Produces `SharedUri(uri: Uri, displayName: String?, mimeType: String?, extension: String)`; text-only requests use an empty list.
- Produces `ShareIntentParser.parse(Intent) -> ShareRequest?`.
- `ShareCaptureActivity` sends the request map to `AndroidCaptureBridge.capture`.

- [ ] **Step 1: Write failing Android text-share tests**

Create instrumentation cases:

```kotlin
val intent = Intent(Intent.ACTION_SEND).apply {
    type = "text/plain"
    putExtra(Intent.EXTRA_TEXT, "https://example.com/article")
}
assertEquals(
    "https://example.com/article",
    ShareIntentParser(context.contentResolver).parse(intent)?.text,
)
```

Also assert whitespace-only text, unsupported action, and missing content return null.

- [ ] **Step 2: Run the test and verify red**

Run:

```bash
flutter build apk --debug
cd android && ./gradlew connectedDebugAndroidTest
```

Expected: compile failure because parser types do not exist.

- [ ] **Step 3: Implement parser and translucent Share Activity**

Trim `EXTRA_TEXT` only for emptiness; pass the original non-empty text to Dart as `{source: share, text: value, attachments: []}`, where shared trim rules apply. `ShareCaptureActivity` uses the translucent theme, validates Vault through the bridge result, displays a short success/error Toast, and always calls `finish()` after the callback or ten-second timeout.

- [ ] **Step 4: Register only text/plain Share initially**

Add an exported Activity filter containing `SEND`, `DEFAULT`, and `text/plain`. Do not add `MAIN` or `LAUNCHER` to this Activity.

- [ ] **Step 5: Verify from ADB and a real Sharesheet**

Run:

```bash
adb shell am start -a android.intent.action.SEND -t text/plain \
  --es android.intent.extra.TEXT "https://example.com/android-share" \
  -n com.inbox.inbox_app/.ShareCaptureActivity
```

Expected: short success feedback, Activity exits, and today's Markdown contains the URL exactly once. Repeat through Chrome's real Sharesheet.

- [ ] **Step 6: Run regression and commit**

Run Flutter tests, Android instrumentation, and debug APK build. Expected: all pass.

Commit:

```bash
git add app/android
git commit -m "feat: capture Android text shares"
```

### Task 7: Stream shared images and ordinary files into attachments

**Files:**
- Modify: `app/android/app/src/main/kotlin/com/inbox/inbox_app/ShareIntentParser.kt`
- Modify: `app/android/app/src/main/kotlin/com/inbox/inbox_app/ShareCaptureActivity.kt`
- Modify: `app/android/app/src/androidTest/kotlin/com/inbox/inbox_app/ShareIntentParserTest.kt`
- Modify: `app/android/app/src/androidTest/kotlin/com/inbox/inbox_app/SafVaultStoreTest.kt`
- Modify: `app/android/app/src/main/AndroidManifest.xml`
- Modify: `app/test/capture_service_test.dart`

**Interfaces:**
- Populates the `SharedUri` metadata type introduced in Task 6.
- Supports `EXTRA_STREAM` and every URI in `ClipData`.
- Sends URI strings to Dart; `SafVaultStore` copies streams before the Activity finishes.

- [ ] **Step 1: Write failing single- and multi-URI parser tests**

Use a test `ContentProvider` with names and MIME types. Cover:

```kotlin
assertEquals("截图.PNG", item.displayName)
assertEquals("image/png", item.mimeType)
assertEquals("png", item.extension)
```

Add `ACTION_SEND_MULTIPLE` with image, PDF, MP4, and extensionless binary URIs; assert original ClipData order and no duplicate when the same URI appears in both `EXTRA_STREAM` and `ClipData`.

- [ ] **Step 2: Verify parser tests fail**

Run `./gradlew connectedDebugAndroidTest` and expect missing attachment parsing behavior.

- [ ] **Step 3: Implement metadata extraction**

Query `OpenableColumns.DISPLAY_NAME`, fall back to the URI last segment, obtain MIME from `ContentResolver.getType`, and derive a safe lowercase `[a-z0-9]+` extension. For missing extensions, use a small exact MIME map for `png`, `jpg`, `gif`, `webp`, `pdf`, `mp4`, and `mov`; otherwise keep extension empty.

- [ ] **Step 4: Add shared-core classification tests**

Assert images embed and PDF/video/unknown files link normally:

```dart
expect(markdown, contains('![[attachments/id.png]]'));
expect(markdown, contains('[[attachments/id-1.pdf|document.pdf]]'));
expect(markdown, contains('[[attachments/id-2.mp4|clip.mp4]]'));
expect(markdown, isNot(contains('![[attachments/id-2.mp4]]')));
```

Run the targeted Dart test and confirm it fails before adding missing MIME/extension normalization.

- [ ] **Step 5: Register attachment MIME filters and preserve URI grants**

Add separate `SEND` and `SEND_MULTIPLE` filters for `image/*`, `video/*`, `application/pdf`, and `*/*`. Keep `FLAG_GRANT_READ_URI_PERMISSION` from the source Intent and finish only after the Dart result returns.

- [ ] **Step 6: Verify real attachment writes**

Share one screenshot, two images together, one PDF, one video, and one ordinary file from emulator apps. Expected: every source is copied, image references embed, all other references are normal links, and the source files remain unchanged.

- [ ] **Step 7: Test failed stream rollback and commit**

Have the test provider throw on the second URI. Expected: error result, no Markdown append, and the first copied target removed.

Run all Dart, instrumentation, and build checks, then commit:

```bash
git add app/lib app/test app/android
git commit -m "feat: capture Android shared attachments"
```

### Task 8: Prove focused clipboard access on Xiaomi 13 Pro

**Files:**
- Create: `app/android/app/src/main/kotlin/com/inbox/inbox_app/ClipboardCaptureActivity.kt`
- Modify: `app/android/app/src/main/AndroidManifest.xml`
- Modify: `app/android/app/src/main/res/values/styles.xml`
- Create or modify: `docs/android-clipboard-verification.md`

**Interfaces:**
- Produces `ClipboardCaptureActivity.launch(Context)`.
- Reads once only after `onWindowFocusChanged(true)`.
- Sends `{source: clipboard, text: copied text, attachments: []}` to the existing bridge.

- [ ] **Step 1: Add the translucent Activity without any background workaround**

Register a non-exported Activity using a translucent, no-action-bar, no-history theme. Guard the one-time read with an atomic boolean:

```kotlin
override fun onWindowFocusChanged(hasFocus: Boolean) {
    super.onWindowFocusChanged(hasFocus)
    if (hasFocus && attempted.compareAndSet(false, true)) {
        captureClipboardOnce()
    }
}
```

Read `ClipboardManager.primaryClip?.getItemAt(0)?.coerceToText(this)?.toString()`. Reject blank text. Do not read images or retain clipboard contents.

- [ ] **Step 2: Add observable diagnostic logging**

Log only event facts—Activity started, focus acquired, clip count, non-empty result, bridge status—and never log clipboard text. Use the fixed tag `INboxClipboardProbe`.

- [ ] **Step 3: Build and invoke the probe from ADB**

Run:

```bash
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell am start -n com.inbox.inbox_app/.ClipboardCaptureActivity
adb logcat -s INboxClipboardProbe
```

Expected on emulator: focus acquired, non-empty clipboard captured, Activity finishes.

- [ ] **Step 4: Run the mandatory Xiaomi 13 Pro decision gate**

On the phone:

1. Copy text in Chrome, WeChat, and one other content App.
2. Trigger ClipboardCaptureActivity while each source App is visible.
3. Repeat each source five times.
4. Confirm all fifteen attempts either save exactly once or return an explicit empty/error result.
5. Confirm focus was acquired in logs and the full INbox page did not appear.
6. Record build number, Android API, HyperOS version, attempts, successes, system clipboard prompts, and failures in `docs/android-clipboard-verification.md`.

Pass criterion: at least fourteen of fifteen attempts save the exact copied text, with no hang and no navigation into the full settings page.

- [ ] **Step 5A: If the gate passes, commit and continue**

Run Flutter tests and APK build, then commit:

```bash
git add app/android docs/android-clipboard-verification.md
git commit -m "feat: capture focused Android clipboard text"
```

- [ ] **Step 5B: If the gate fails, remove the unusable entrypoint and stop**

Use `apply_patch` to remove ClipboardCaptureActivity and its Manifest/theme entries, retain the factual verification document, run the debug build, and commit only the finding:

```bash
git add app/android docs/android-clipboard-verification.md
git commit -m "docs: record Android clipboard capture limitation"
```

Stop execution and report the reproduced platform limitation. Do not start Task 9 and do not add Accessibility Service, polling, IME behavior, or another permission.

### Task 9: Add the user-controlled floating Capture bubble

**Files:**
- Create: `app/android/app/src/main/kotlin/com/inbox/inbox_app/OverlayPositioner.kt`
- Create: `app/android/app/src/main/kotlin/com/inbox/inbox_app/OverlayService.kt`
- Create: `app/android/app/src/test/kotlin/com/inbox/inbox_app/OverlayPositionerTest.kt`
- Modify: `app/android/app/src/main/AndroidManifest.xml`
- Modify: `app/android/app/src/main/res/values/strings.xml`
- Modify: `app/lib/services/android_vault_settings.dart`
- Modify: `app/lib/ui/android_settings_view.dart`
- Modify: `app/test/android_settings_view_test.dart`

**Interfaces:**
- Produces native methods `getOverlayState`, `requestOverlayPermission`, `requestNotificationPermission`, `startOverlay`, `stopOverlay`, and `openNotificationSettings` on `com.inbox.app/android_vault`.
- Produces pure `OverlayPositioner.clamp`, `nearestEdgeX`, and `isClick`.
- Overlay click launches `ClipboardCaptureActivity` from Task 8.
- ClipboardCaptureActivity returns `saved`, `empty`, or `error` to the running service using explicit action `com.inbox.inbox_app.CAPTURE_RESULT` so the bubble can animate without a global broadcast.

- [ ] **Step 1: Write failing geometry unit tests**

Cover exact cases:

```kotlin
assertEquals(0, positioner.nearestEdgeX(x = 100, screenWidth = 1080, bubbleWidth = 48))
assertEquals(1032, positioner.nearestEdgeX(x = 900, screenWidth = 1080, bubbleWidth = 48))
assertTrue(positioner.isClick(downX = 20f, downY = 20f, upX = 24f, upY = 23f, thresholdPx = 12f))
assertFalse(positioner.isClick(downX = 20f, downY = 20f, upX = 60f, upY = 20f, thresholdPx = 12f))
```

Also test status/navigation inset bounds and rotation to a smaller display.

- [ ] **Step 2: Run unit tests and verify red**

Run: `cd android && ./gradlew testDebugUnitTest`

Expected: missing `OverlayPositioner`.

- [ ] **Step 3: Implement geometry and the foreground service**

Use a 32dp visible black circle inside a 48dp transparent `FrameLayout`. Add it with `TYPE_APPLICATION_OVERLAY`, `FLAG_NOT_FOCUSABLE`, and translucent pixel format. Default to the right edge at vertical center when no saved position exists. Track raw pointer down/move/up coordinates; update `WindowManager.LayoutParams`; snap on release; persist final side and Y position.

Create a low-importance notification channel. Start foreground with a notification that contains a `停止悬浮球` action. Use `START_NOT_STICKY`; remove the view in `onDestroy`. After the clipboard bridge callback, `ClipboardCaptureActivity` calls `startService(Intent(this, OverlayService::class.java).setAction(ACTION_CAPTURE_RESULT).putExtra("status", status))` before finishing. The already-running Service handles that action by briefly scaling/coloring the dot for `saved` or showing the short empty/error feedback.

- [ ] **Step 4: Declare the exact permissions and service type**

Manifest entries:

```xml
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

<service
    android:name=".OverlayService"
    android:exported="false"
    android:foregroundServiceType="specialUse">
    <property
        android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE"
        android:value="User-enabled persistent capture overlay" />
</service>
```

Do not add `BOOT_COMPLETED` or battery-optimization permissions.

- [ ] **Step 5: Write failing settings UI behavior tests**

With mocked native state, assert:

```dart
expect(find.text('显示在其他应用上层'), findsOneWidget);
expect(find.text('通知'), findsOneWidget);
expect(find.text('开启悬浮球'), findsOneWidget);
await tester.tap(find.text('开启悬浮球'));
expect(nativeCalls.map((call) => call.method), containsAllInOrder([
  'requestOverlayPermission',
  'startOverlay',
]));
```

Add denied-permission, already-running, stop, Vault-unavailable, and notification-denied cases.

- [ ] **Step 6: Implement the setting controls and safe start order**

Only call `startForegroundService` while MainActivity is visible and after `Settings.canDrawOverlays()` is true. Request `POST_NOTIFICATIONS` through the attached MainActivity on API 33+ and refresh both permission states in `onResume`. A revoked overlay permission stops the Service. Notification denial changes the status row but does not crash or block service startup.

- [ ] **Step 7: Verify overlay interaction on emulator and Xiaomi 13 Pro**

Check:

- permission denial returns safely;
- 32dp dot remains inside the safe screen region;
- 48dp touch area drags smoothly;
- release snaps left or right;
- tap launches the focused clipboard Capture and returns to the source App;
- success produces a brief scale/color response;
- notification action and settings button both stop the Service;
- rotation reclamps the dot;
- phone reboot does not restart it;
- HyperOS process cleanup does not trigger a background keepalive workaround.

- [ ] **Step 8: Run tests and commit**

Run:

```bash
flutter test test/android_settings_view_test.dart
cd android && ./gradlew testDebugUnitTest connectedDebugAndroidTest
cd .. && flutter build apk --debug
```

Expected: all pass.

Commit:

```bash
git add app/lib app/test app/android
git commit -m "feat: add Android floating capture bubble"
```

### Task 10: Complete Android Obsidian acceptance and macOS regression

**Files:**
- Modify: `README.md`
- Modify: `PROJECT_STATE.md`
- Modify: `app/README.md`
- Create: `docs/android-mvp-verification.md`

**Interfaces:**
- Produces the final verified feature matrix and manual-test record.
- Does not change runtime interfaces.

- [x] **Step 1: Run the complete static and automated suite from a clean state**

Run:

```bash
cd app
flutter clean
flutter pub get
dart analyze lib test
flutter test
flutter build apk --debug
flutter build macos --debug
cd android
./gradlew testDebugUnitTest connectedDebugAndroidTest
```

Expected: every command exits 0. Record tool versions, test totals, device IDs, and artifact paths in `docs/android-mvp-verification.md`.

- [x] **Step 2: Run the emulator matrix**

Install the clean APK and verify Vault selection, persisted access, text Capture, repeated Capture, Share text/image/file, overlay switch, drag, permission denial, and App restart. Record pass/fail per item; do not summarize an unrun item as passed.

- [x] **Step 3: Run the Xiaomi 13 Pro and Obsidian matrix**

Select an actual Android Obsidian Vault, then verify in order:

1. Text and URL Capture.
2. Single and multiple image Share.
3. PDF Share.
4. Video and ordinary-file Share.
5. Markdown section layout.
6. Image embed rendering.
7. Ordinary attachment links open.
8. Clipboard overlay Capture from three source Apps.
9. Bubble drag, snap, feedback, stop, denial, and rotation.
10. App restart retains Vault permission.
11. Phone restart does not restart overlay.

Record actual filenames and redacted Markdown examples. Any failure reopens the owning task; fix it with a new failing regression test before changing code.

- [x] **Step 4: Update public and project documentation**

Document Android API 29+, personal sideload status, SAF selection, supported Share MIME categories, overlay/notification permissions, no boot auto-start, and the exact verified device/system. Keep unverified claims explicitly labeled.

- [x] **Step 5: Re-run final checks after documentation and commit**

Final closeout scope was narrowed by the user: after removing the manual instrumentation harness, API 36 `connectedDebugAndroidTest` passed 28/28 with no skips or failures. Runtime code had not changed since the clean full suite, so Flutter, macOS, real-device Share, Obsidian, P1, and the full Android matrix were not repeated.

Run `git diff --check`, `dart analyze lib test`, `flutter test`, `flutter build apk --debug`, and `flutter build macos --debug` again. Expected: clean output and all exit 0.

Commit:

```bash
git add README.md PROJECT_STATE.md app/README.md docs/android-mvp-verification.md
git commit -m "docs: verify Android Capture MVP"
```

- [x] **Step 6: Prepare the final report and stop**

Run:

```bash
git status --short --branch
git log --oneline main..feature/android-capture-mvp
```

Expected: clean worktree and a list of unmerged Android commits. Report environment, implemented APIs, SAF behavior, clipboard result, Share types, automated tests, emulator results, Xiaomi manual checks, macOS regression, remaining manual checks, and the commit list. Do not merge `main` and do not begin another feature.

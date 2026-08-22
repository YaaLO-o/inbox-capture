# Flutter Desktop Unification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `app/` the only production Flutter client with shared macOS/Windows capture behavior and native adapters for each desktop platform.

**Architecture:** Keep Capture, storage, Markdown, paths, Vault validation, and UI behavior in shared Dart. Preserve the existing macOS MethodChannels, add matching Windows C++ channels, and move the old Electron code to a clearly marked legacy directory.

**Tech Stack:** Flutter 3.47.1, Dart 3.13.1, Swift/AppKit, C++/Win32, Flutter MethodChannels, GitHub Actions

**Spec:** `docs/superpowers/specs/2026-08-22-flutter-desktop-unification-design.md`

## Global Constraints

- `app/` is the only production client.
- New macOS and Windows captures use `Universal Capture/YYYY-MM-DD.md` and `Universal Capture/attachments/`.
- Historical Vault data is never migrated, deleted, or overwritten.
- Capture ID, Markdown, append semantics, and attachment naming stay in shared Dart.
- Native adapters use the same MethodChannel names, methods, arguments, and return values.
- No plugins, network services, database, AI features, mobile target, or speculative abstraction is added.
- Windows build success is not claimed until a Windows runner or machine verifies it.

---

### Task 1: Establish the Flutter project as the only production entry point

**Files:**
- Move: `package.json`, `package-lock.json`, `src/`, `tests/`, and old Electron docs to `legacy/electron-windows/`
- Create: `legacy/electron-windows/README.md`
- Modify: `.gitignore`

**Interfaces:**
- Produces: a repository root with no production `npm start` entry point
- Preserves: all Electron source and tests as reference code

- [ ] **Step 1: Record the current tracked Electron file set**

Run: `git ls-files package.json package-lock.json src tests docs/superpowers/specs/2026-08-16-universal-capture-mvp-design.md docs/superpowers/plans/2026-08-16-universal-capture-mvp.md`

- [ ] **Step 2: Move the files with Git history intact**

```bash
mkdir -p legacy/electron-windows/docs/superpowers/specs legacy/electron-windows/docs/superpowers/plans
git mv package.json package-lock.json src tests legacy/electron-windows/
git mv docs/superpowers/specs/2026-08-16-universal-capture-mvp-design.md legacy/electron-windows/docs/superpowers/specs/
git mv docs/superpowers/plans/2026-08-16-universal-capture-mvp.md legacy/electron-windows/docs/superpowers/plans/
```

- [ ] **Step 3: Add a legacy README and verify the root no longer exposes npm start**

Run: `test ! -f package.json && test -f legacy/electron-windows/package.json`

- [ ] **Step 4: Commit**

```bash
git add .gitignore legacy docs
git commit -m "chore: move Electron client to legacy"
```

### Task 2: Define and test the canonical shared Vault protocol

**Files:**
- Modify: `app/test/capture_service_test.dart`
- Modify: `app/lib/util/path_utils.dart`
- Modify: `app/lib/services/storage_service.dart`

**Interfaces:**
- Produces: `VaultPaths.captureDir`, `dailyInboxFile`, `attachmentsDir`, and `embedRef`
- Preserves: `CaptureService.captureNow(String vaultPath, {DateTime? now})`

- [ ] **Step 1: Write failing path and Markdown tests**

```dart
expect(VaultPaths.dailyInboxFile(vault, now), endsWith('Universal Capture${Platform.pathSeparator}2026-08-21.md'));
expect(VaultPaths.attachmentsDir(vault), endsWith('Universal Capture${Platform.pathSeparator}attachments'));
expect(markdown, contains('![[attachments/$fileName]]'));
```

- [ ] **Step 2: Run the focused test and verify it fails on the old `素材/Inbox` paths**

Run: `flutter test test/capture_service_test.dart`

- [ ] **Step 3: Implement the minimum shared path change**

```dart
static const captureDirName = 'Universal Capture';
static const attachmentsDirName = 'attachments';
static String dailyInboxFile(String vaultPath, DateTime date) =>
    _join(captureDir(vaultPath), '${dateStamp(date)}.md');
static String embedRef(String fileName) => '$attachmentsDirName/$fileName';
```

- [ ] **Step 4: Run all Flutter tests**

Run: `flutter test`

- [ ] **Step 5: Commit**

```bash
git add app/lib/util/path_utils.dart app/lib/services/storage_service.dart app/test/capture_service_test.dart
git commit -m "feat: unify desktop capture storage protocol"
```

### Task 3: Reject stale stored Vault paths through shared Dart logic

**Files:**
- Create: `app/test/settings_service_test.dart`
- Modify: `app/lib/services/settings_service.dart`
- Modify: `app/lib/main.dart`
- Modify: `app/macos/Runner/AppDelegate.swift`

**Interfaces:**
- Produces: `SettingsService.loadValidVaultPath()` and `clearVaultPath()`
- Native contract: `clearVaultPath` removes the stored platform value

- [ ] **Step 1: Write a failing MethodChannel test**

```dart
final path = await SettingsService().loadValidVaultPath();
expect(path, isNull);
expect(methods, contains('clearVaultPath'));
expect(Directory(stalePath).existsSync(), isFalse);
```

- [ ] **Step 2: Run the focused test and verify the method is missing**

Run: `flutter test test/settings_service_test.dart`

- [ ] **Step 3: Implement validation without creating directories**

```dart
Future<String?> loadValidVaultPath() async {
  final path = await getVaultPath();
  if (path == null) return null;
  if (Directory(path).existsSync()) return path;
  await clearVaultPath();
  return null;
}
```

- [ ] **Step 4: Add `clearVaultPath` to macOS and use validated loading at boot**

- [ ] **Step 5: Run the focused and full tests**

Run: `flutter test test/settings_service_test.dart && flutter test`

- [ ] **Step 6: Commit**

```bash
git add app/lib app/test/settings_service_test.dart app/macos/Runner/AppDelegate.swift
git commit -m "fix: reject stale Vault settings"
```

### Task 4: Enforce local-file precedence over duplicate image bytes

**Files:**
- Modify: `app/test/capture_service_test.dart`
- Create: `app/test/clipboard_service_test.dart`
- Modify: `app/lib/services/capture_service.dart`
- Modify: `app/lib/services/clipboard_service.dart`
- Modify: `app/macos/Runner/AppDelegate.swift`

**Interfaces:**
- Rule: non-empty `files` suppresses `imageBytes`, while accompanying text remains

- [ ] **Step 1: Write a failing capture test with one source file and image bytes**

```dart
final content = ClipboardContent(files: [source.path], imageBytes: Uint8List.fromList([9]));
expect(Directory(VaultPaths.attachmentsDir(vault)).listSync().whereType<File>(), hasLength(1));
```

- [ ] **Step 2: Verify the old code creates two attachments**

Run: `flutter test test/capture_service_test.dart --plain-name '本地文件优先于重复图片 bytes'`

- [ ] **Step 3: Implement shared precedence and MethodChannel normalization**

```dart
final hasFiles = content.files.isNotEmpty;
if (!hasFiles && content.imageBytes != null) {
  // save image bytes
}
```

- [ ] **Step 4: Make macOS skip `readImage` when file URLs exist**

- [ ] **Step 5: Run all tests and build macOS**

Run: `flutter test && flutter build macos --debug`

- [ ] **Step 6: Commit**

```bash
git add app/lib app/test app/macos/Runner/AppDelegate.swift
git commit -m "fix: avoid duplicate file image captures"
```

### Task 5: Add the Flutter Windows target and matching native adapters

**Files:**
- Generate: `app/windows/`
- Create: `app/windows/runner/platform_channels.h`
- Create: `app/windows/runner/platform_channels.cpp`
- Modify: `app/windows/runner/flutter_window.cpp`
- Modify: `app/windows/runner/win32_window.cpp`
- Modify: `app/windows/runner/CMakeLists.txt`

**Interfaces:**
- Clipboard channel: `com.inbox.app/clipboard`, `readClipboard`
- Settings channel: `com.inbox.app/settings`, all methods listed in the spec

- [ ] **Step 1: Generate only the Windows runner**

Run: `flutter create --platforms=windows .`

- [ ] **Step 2: Register C++ MethodChannels in `FlutterWindow::OnCreate`**

```cpp
platform_channels_ = std::make_unique<PlatformChannels>(
    flutter_controller_->engine()->messenger(), GetHandle());
```

- [ ] **Step 3: Implement clipboard text, `CF_HDROP`, original PNG/JPEG, and bitmap-to-PNG fallback**

- [ ] **Step 4: Implement Registry settings, IFileDialog, window sizing/moving, and quit**

- [ ] **Step 5: Configure a borderless topmost tool window**

- [ ] **Step 6: Add the adapter sources and Windows libraries to CMake**

- [ ] **Step 7: Verify generated files are scoped to Windows and commit**

```bash
git diff --check
git add app/windows app/.metadata
git commit -m "feat: add Flutter Windows desktop adapter"
```

### Task 6: Share the old Windows capture experience across desktop platforms

**Files:**
- Create: `app/test/capture_pill_test.dart`
- Modify: `app/lib/ui/capture_pill.dart`
- Modify: `app/lib/ui/window_sizes.dart`
- Modify: `app/lib/services/settings_service.dart`
- Modify: `app/macos/Runner/AppDelegate.swift`
- Modify: `app/macos/Runner/MainFlutterWindow.swift`

**Interfaces:**
- Produces: round `收` button, drag handle, status label, shared context menu
- Native method: `moveWindowBy(dx, dy)`

- [ ] **Step 1: Write a failing widget test for the visible `收` entry and initial status**

```dart
expect(find.text('收'), findsOneWidget);
expect(find.text('点击保存'), findsOneWidget);
expect(find.text('•••'), findsOneWidget);
```

- [ ] **Step 2: Run the widget test and verify the current pill fails**

Run: `flutter test test/capture_pill_test.dart`

- [ ] **Step 3: Implement the minimum shared widget and drag callback**

- [ ] **Step 4: Implement `moveWindowBy` in macOS and Windows settings adapters**

- [ ] **Step 5: Run widget and full tests**

Run: `flutter test test/capture_pill_test.dart && flutter test`

- [ ] **Step 6: Commit**

```bash
git add app/lib app/test/capture_pill_test.dart app/macos app/windows
git commit -m "feat: share floating capture experience"
```

### Task 7: Add Windows CI, unify documentation, and perform final verification

**Files:**
- Create: `.github/workflows/windows-build.yml`
- Rewrite: `README.md`
- Rewrite: `PROJECT_STATE.md`
- Rewrite: `app/README.md`

**Interfaces:**
- CI runs from `app/` on `windows-latest`
- Documentation distinguishes locally verified results from pending Windows runner results

- [ ] **Step 1: Add the minimal Windows workflow**

```yaml
- uses: subosito/flutter-action@v2
  with:
    flutter-version: '3.47.1'
    channel: stable
- run: flutter pub get
  working-directory: app
- run: flutter test
  working-directory: app
- run: flutter build windows
  working-directory: app
```

- [ ] **Step 2: Rewrite all three README/state documents to match the actual repository**

- [ ] **Step 3: Run fresh local verification**

Run: `flutter pub get && dart analyze lib test && flutter test && flutter build macos --debug`

- [ ] **Step 4: Launch the macOS debug executable briefly and verify it stays alive**

- [ ] **Step 5: Verify repository state and inspect the complete diff**

Run: `git diff --check && git status --short --branch && git log --oneline -8`

- [ ] **Step 6: Commit**

```bash
git add .github README.md PROJECT_STATE.md app/README.md docs/superpowers/plans/2026-08-22-flutter-desktop-unification.md
git commit -m "docs: make Flutter the cross-platform project entry"
```

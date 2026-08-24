# INbox macOS Lifecycle and Updater Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship INbox 1.1.1 with accurate macOS dragging, restored window controls, a persistent menu-bar entry, in-app updates with visible progress, and a rollback-safe terminal installer.

**Architecture:** Flutter keeps capture and update UI state. AppKit owns absolute window positioning, the status item, DMG staging, and process lifecycle; a detached shell helper replaces the running bundle only after the old PID exits.

**Tech Stack:** Flutter 3.47.1, Dart 3.13.1, Swift/AppKit, XCTest, POSIX shell, GitHub Releases

**Spec:** `docs/superpowers/specs/2026-08-24-macos-lifecycle-and-updater-design.md`

## Global Constraints

- Set the application version to exactly `1.1.1+2` and the release tag to `v1.1.1`.
- Keep one Universal DMG containing `arm64` and `x86_64`.
- Do not change capture formats, Vault layout, pet visuals, or animation timing.
- Contact GitHub only after the user selects “检查更新”; no background checks.
- Keep `LSUIElement=true`; use a menu-bar icon instead of a Dock icon.
- First installation shows progress in Terminal; later updates show progress inside INbox.
- Failed installation must leave the prior App recoverable.
- Implement each behavior with a red-green test cycle.

## File Map

- `app/lib/ui/pet/pixel_chest_pet.dart`, `capture_pill.dart`, `settings_service.dart`: macOS drag lifecycle.
- `app/macos/Runner/MainFlutterWindow.swift`: restored traffic lights and absolute drag state.
- `app/macos/Runner/StatusMenuController.swift`, `AppDelegate.swift`: persistent status item and commands.
- `app/lib/models/app_release.dart`, `services/update_service.dart`: version parsing, GitHub lookup, download, digest.
- `app/lib/services/app_command_service.dart`, `ui/update_view.dart`, `main.dart`: command reception and update UI.
- `app/macos/Runner/UpdateInstaller.swift`, `Resources/replace_macos_app.sh`: stage and replace the App.
- `scripts/install.sh`: safe first-install and recovery flow.
- `scripts/release_macos.sh`, `pubspec.yaml`, docs: version and release verification.

---

### Task 1: Absolute macOS window dragging

**Files:**
- Modify: `app/lib/ui/pet/pixel_chest_pet.dart`
- Modify: `app/lib/ui/capture_pill.dart`
- Modify: `app/lib/services/settings_service.dart`
- Modify: `app/macos/Runner/AppDelegate.swift`
- Modify: `app/macos/Runner/MainFlutterWindow.swift`
- Modify: `app/test/pixel_chest_pet_test.dart`
- Modify: `app/test/capture_pill_test.dart`
- Modify: `app/macos/RunnerTests/RunnerTests.swift`

**Interfaces:**
- Produces Dart methods `beginWindowDrag()`, `updateWindowDrag()`, `endWindowDrag()`.
- Produces Swift `WindowDragSession.origin(for:) -> NSPoint`.
- Keeps `moveWindowBy(dx, dy)` as the Windows fallback.

- [ ] **Step 1: Write failing Dart gesture tests**

Add `onDragStart`, `onDragUpdate`, and `onDragEnd` callbacks to the test construction and assert the observable sequence:

```dart
await tester.drag(find.byKey(const Key('pet-visible-region')), const Offset(30, 20));
expect(events.first, 'start');
expect(events, contains('update'));
expect(events.last, 'end');
expect(events, isNot(contains('fallback')));
expect(captures, 0);
```

Add a cancelled-pointer case that still emits `end` once.

- [ ] **Step 2: Verify the Dart tests fail for the missing API**

Run: `cd app && flutter test test/pixel_chest_pet_test.dart test/capture_pill_test.dart`

Expected: compile failure because the drag lifecycle callbacks do not exist.

- [ ] **Step 3: Write failing absolute-coordinate Swift tests**

```swift
func testWindowDragUsesAbsoluteScreenDelta() {
  let session = WindowDragSession(
    mouseOrigin: NSPoint(x: 400, y: 300),
    windowOrigin: NSPoint(x: 100, y: 80)
  )
  XCTAssertEqual(session.origin(for: NSPoint(x: 455, y: 270)), NSPoint(x: 155, y: 50))
}
```

Run: `cd app && xcodebuild test -workspace macos/Runner.xcworkspace -scheme Runner -destination 'platform=macOS'`

Expected: compile failure because `WindowDragSession` does not exist.

- [ ] **Step 4: Implement the minimal native drag session**

```swift
struct WindowDragSession {
  let mouseOrigin: NSPoint
  let windowOrigin: NSPoint

  func origin(for mouse: NSPoint) -> NSPoint {
    NSPoint(
      x: windowOrigin.x + mouse.x - mouseOrigin.x,
      y: windowOrigin.y + mouse.y - mouseOrigin.y
    )
  }
}
```

Record `NSEvent.mouseLocation` and the window origin on begin, calculate from the original pair on every update, and clear state on end or cancel. On macOS, `PixelChestPet` emits lifecycle callbacks; on Windows it keeps passing `details.delta` to `onMove`.

- [ ] **Step 5: Verify and commit**

Run `dart analyze lib test`, the two targeted Flutter tests, and Runner XCTest. Expected: all exit 0.

Commit: `fix: make macOS pet dragging track the pointer`

### Task 2: Restore traffic lights and add the menu-bar lifecycle

**Files:**
- Create: `app/macos/Runner/StatusMenuController.swift`
- Modify: `app/macos/Runner/AppDelegate.swift`
- Modify: `app/macos/Runner/MainFlutterWindow.swift`
- Modify: `app/macos/Runner.xcodeproj/project.pbxproj`
- Modify: `app/macos/RunnerTests/RunnerTests.swift`

**Interfaces:**
- Produces `StatusMenuAction.showWindow`, `.checkForUpdates`, and `.quit`.
- Produces `StatusMenuController(onAction:)`, retained by AppDelegate.
- Sends `checkForUpdates` over `com.inbox.app/commands`.

- [ ] **Step 1: Write the failing action-dispatch test**

```swift
func testStatusMenuDispatchesEverySupportedAction() {
  var received: [StatusMenuAction] = []
  let dispatcher = StatusMenuDispatcher { received.append($0) }
  dispatcher.dispatch(.showWindow)
  dispatcher.dispatch(.checkForUpdates)
  dispatcher.dispatch(.quit)
  XCTAssertEqual(received, [.showWindow, .checkForUpdates, .quit])
}
```

Run Runner XCTest and expect missing-type compile failures.

- [ ] **Step 2: Implement the status item and standard controls**

Create the enum and dispatcher above. Create one `NSStatusItem` with the 18-point application icon and exactly three items: `显示 INbox`, `检查更新`, `完全退出`. AppDelegate shows `mainFlutterWindow`, invokes the Flutter command, or terminates the app.

Remove the three `standardWindowButton(...).isHidden = true` assignments. Keep `LSUIElement=true` and `.accessory` so closing the red button hides the window but the menu-bar entry remains.

- [ ] **Step 3: Register the Swift source, verify, and commit**

Add the file to Runner Sources. Run Runner XCTest and `flutter build macos --debug`; both must exit 0.

Commit: `feat: add menu bar lifecycle controls`

### Task 3: Model GitHub releases and verified downloads

**Files:**
- Create: `app/lib/models/app_release.dart`
- Create: `app/lib/services/update_service.dart`
- Create: `app/test/app_release_test.dart`
- Create: `app/test/update_service_test.dart`
- Modify: `app/pubspec.yaml`
- Modify: `app/pubspec.lock`

**Interfaces:**
- Produces `AppVersion.parse(String)` and `compareTo(AppVersion)`.
- Produces `AppRelease.fromGitHubJson(Map<String, Object?>)`.
- Produces `UpdateService.fetchLatest()`, `download(..., onProgress:)`, and `verifyDigest(...)`.

- [ ] **Step 1: Write failing version and payload tests**

```dart
expect(AppVersion.parse('v1.1.1').compareTo(AppVersion.parse('1.1.0')), greaterThan(0));

final release = AppRelease.fromGitHubJson({
  'tag_name': 'v1.1.1',
  'assets': [{
    'name': 'INbox-macos-universal.dmg',
    'browser_download_url': 'https://example.test/INbox.dmg',
    'digest': 'sha256:abc123',
    'size': 17288518,
  }],
});
expect(release.downloadUrl.toString(), 'https://example.test/INbox.dmg');
expect(release.digest, 'abc123');
```

Also test malformed versions, missing fixed-name asset, and missing digest. Run the model test and expect missing-file failure.

- [ ] **Step 2: Implement the minimal immutable model**

Accept only `^v?(\d+)\.(\d+)\.(\d+)$`. Compare the three integer components. Select only `INbox-macos-universal.dmg` and require a `sha256:` digest.

- [ ] **Step 3: Write failing real local-server service tests**

Use a local `HttpServer` to return a complete GitHub payload and stream bytes `[1,2,3,4]` in two chunks. Assert the saved bytes, the final `DownloadProgress(received: 4, total: 4)`, and SHA-256 `9f64a747e1b97f131fabb6b447296c9b6f0201e79fb3c5356e6c77e89b6a806a`.

- [ ] **Step 4: Add checksum support and implement the service**

Run `cd app && flutter pub add crypto`. Use `dart:io HttpClient`, GitHub API Accept and User-Agent headers, streamed writes to a unique system-temp file, and `crypto.sha256.bind(file.openRead())`. Delete partial files after HTTP, stream, or checksum failures.

- [ ] **Step 5: Verify and commit**

Run both new tests and `dart analyze lib test`; all must pass.

Commit: `feat: add verified release downloads`

### Task 4: Receive menu commands and show in-App update progress

**Files:**
- Create: `app/lib/services/app_command_service.dart`
- Create: `app/lib/ui/update_view.dart`
- Create: `app/test/app_command_service_test.dart`
- Create: `app/test/update_view_test.dart`
- Modify: `app/lib/main.dart`
- Modify: `app/lib/ui/window_sizes.dart`
- Modify: `app/lib/services/settings_service.dart`

**Interfaces:**
- Consumes `UpdateService`, `AppRelease`, and `DownloadProgress` from Task 3.
- Produces `AppCommandService.start(onCheckForUpdates:)` and `dispose()`.
- Produces `UpdateView(currentVersion:, service:, installer:, onClose:)`.
- Produces `SettingsService.installUpdate(String dmgPath)`.

- [ ] **Step 1: Write a failing command-channel behavior test**

Send a real binary-messenger method call named `checkForUpdates` on `com.inbox.app/commands`. Assert the supplied callback runs once; send an unknown method and assert it does not run.

Run: `cd app && flutter test test/app_command_service_test.dart`

Expected: missing-class compile failure.

- [ ] **Step 2: Implement command reception and navigation**

Use a dedicated `MethodChannel`. `_InboxAppState` retains and disposes the command service. The update command makes the window visible, sets its size to `420x300`, and renders `UpdateView`; closing the view returns to the `132x132` capture pill.

- [ ] **Step 3: Write failing user-visible state tests**

Drive the real widget with a service double at the HTTP boundary and assert:

```dart
expect(find.text('正在检查更新…'), findsOneWidget);
expect(find.text('发现新版本 1.1.2'), findsOneWidget);
expect(find.text('50%'), findsOneWidget);
expect(find.text('当前已是最新版本'), findsOneWidget);
expect(find.text('校验失败，已保留当前版本'), findsOneWidget);
```

Also verify repeated taps cannot start two downloads and Close works only when an install is not active.

- [ ] **Step 4: Implement the smallest update state machine**

Use states `checking`, `available`, `downloading`, `installing`, `current`, and `error`. Render determinate progress when total bytes are known. After checksum verification, call `installer(dmgPath)` and display `正在完成安装，INbox 将重新启动…`.

- [ ] **Step 5: Verify and commit**

Run the two targeted widget tests, all Flutter tests, and `dart analyze lib test`; all must pass.

Commit: `feat: show update progress inside INbox`

### Task 5: Stage and atomically install a verified update

**Files:**
- Create: `app/macos/Runner/UpdateInstaller.swift`
- Create: `app/macos/Runner/Resources/replace_macos_app.sh`
- Create: `scripts/tests/replace_macos_app_test.sh`
- Modify: `app/macos/Runner/AppDelegate.swift`
- Modify: `app/macos/Runner.xcodeproj/project.pbxproj`
- Modify: `app/macos/RunnerTests/RunnerTests.swift`

**Interfaces:**
- Consumes a verified DMG path from Task 4.
- Produces `UpdateInstaller.prepare(dmgPath:completion:)`.
- Helper arguments are exactly `OLD_PID STAGED_APP INSTALL_APP BACKUP_APP LOG_PATH`.

- [ ] **Step 1: Write failing pure Swift path and mount tests**

```swift
func testUpdatePathsStayBesideApplicationsInstall() {
  let paths = UpdatePaths(installApp: URL(fileURLWithPath: "/Applications/INbox.app"), pid: 42)
  XCTAssertEqual(paths.staged.path, "/Applications/.INbox.app.installing.42")
  XCTAssertEqual(paths.backup.path, "/Applications/.INbox.app.backup.42")
}
```

Add an `hdiutil -plist` fixture and assert its mount point is `/Volumes/INbox`. Run Runner XCTest and expect missing-type failures.

- [ ] **Step 2: Write failing real helper-script tests**

Use a temporary directory with Old and Staged App marker files plus a fake `open`. Assert success installs the new marker and opens the exact path. Add a failed move that restores the old marker and a live-PID timeout that leaves the installed marker unchanged.

Run: `sh scripts/tests/replace_macos_app_test.sh`

Expected: failure because the helper does not exist.

- [ ] **Step 3: Implement the replacement helper**

Use `set -eu`, quoted explicit paths, a 10-second `kill -0` loop, same-volume `mv`, and an exit trap that restores backup only when the final App is absent. Production uses `/usr/bin/open`; tests may set `INBOX_OPEN_COMMAND`. Recursive cleanup is allowed only after validating the generated staging or backup basename begins with `.INbox.app.`.

- [ ] **Step 4: Implement native DMG staging**

Run `/usr/bin/hdiutil attach -nobrowse -readonly -plist`, parse the mount point, require `INbox.app`, copy it with `/usr/bin/ditto` to the generated staging path, detach, copy the bundled helper to a unique temporary path, mark it executable, and launch it with the five arguments. Map mount, missing-App, permission, staging, and helper-launch errors to distinct Flutter errors. Terminate INbox only after helper launch succeeds.

- [ ] **Step 5: Register resources, verify, and commit**

Add Swift to Runner Sources and the helper to Copy Bundle Resources. Run the helper tests, Runner XCTest, full Flutter tests, analysis, and a Debug macOS build; all must exit 0.

Commit: `feat: install verified updates with rollback`

### Task 6: Harden the terminal installer

**Files:**
- Modify: `scripts/install.sh`
- Create: `scripts/tests/install_sh_test.sh`

**Interfaces:**
- Uses the fixed Latest Release DMG URL.
- Produces a rollback-safe `/Applications/INbox.app` and starts that exact path.
- Test-only overrides: `INBOX_INSTALL_DIR`, `INBOX_DMG_URL`, `INBOX_COMMAND_DIR`, `INBOX_SKIP_OPEN`.

- [ ] **Step 1: Write failing end-to-end shell fixtures**

Use a temporary install directory and fake external commands. Assert:

1. A successful install replaces the marker and opens the exact final App path.
2. Staging completes before the old App is moved.
3. A still-running fake PID aborts with the old marker intact.
4. A failed staged-to-final move restores the old marker.
5. Both formal and Debug executable paths ending in `INbox.app/Contents/MacOS/INbox` receive a graceful quit request.

Run: `sh scripts/tests/install_sh_test.sh`

Expected: the timeout and rollback cases fail against the current script.

- [ ] **Step 2: Implement the minimal safe flow**

Download and mount first, then `ditto` into `.INbox.app.installing.$$`. Enumerate exact executable-suffix matches, request all instances to quit, and poll for 10 seconds. Abort before touching the old App if any remain. Move old to `.backup.$$`, move staged to final, register final, remove backup, and use `open "$APP_PATH"` instead of `open -a`.

The exit trap restores backup only if final is absent and removes only the validated generated staging path. Environment overrides exist solely to test the real script safely.

- [ ] **Step 3: Verify and commit**

Run `sh -n scripts/install.sh` and `sh scripts/tests/install_sh_test.sh`; both must pass.

Commit: `fix: replace macOS installs without stale instances`

### Task 7: Prepare and verify version 1.1.1

**Files:**
- Modify: `app/pubspec.yaml`
- Modify: `app/lib/ui/update_view.dart`
- Modify: `app/macos/Runner/AppDelegate.swift`
- Modify: `scripts/release_macos.sh`
- Modify: `README.md`
- Modify: `.github/DOWNLOAD.md`
- Modify: `PROJECT_STATE.md`

**Interfaces:**
- Produces `dist/INbox-1.1.1-macos-universal.dmg` and `dist/INbox-macos-universal.dmg`.
- Produces native `getAppVersion` backed by `CFBundleShortVersionString`.

- [ ] **Step 1: Set and test the authoritative version**

Set `version: 1.1.1+2`. Replace any temporary Dart version constant with `SettingsService.getAppVersion()`. Test that current `1.1.1` treats remote `1.1.1` as current and remote `1.1.2` as newer.

- [ ] **Step 2: Strengthen the release script**

Require an explicit version argument and build with:

```sh
flutter build macos --release --build-name "$VERSION" --build-number 2
```

Fail unless `CFBundleShortVersionString` equals the argument and `lipo -archs` contains both `arm64` and `x86_64`. Continue producing versioned and fixed-name DMGs.

- [ ] **Step 3: Update public documentation**

Document that versions before 1.1.1 run the Terminal command once; 1.1.1 and later normally use menu-bar `检查更新`; Terminal remains recovery. Explain red-close, menu-bar reopen, complete quit, and that only explicit update actions contact GitHub.

- [ ] **Step 4: Run the full pre-release gate**

```bash
cd app
flutter pub get
dart analyze lib test
flutter test
xcodebuild test -workspace macos/Runner.xcworkspace -scheme Runner -destination 'platform=macOS'
cd ..
sh -n scripts/install.sh scripts/release_macos.sh app/macos/Runner/Resources/replace_macos_app.sh
sh scripts/tests/replace_macos_app_test.sh
sh scripts/tests/install_sh_test.sh
sh scripts/release_macos.sh 1.1.1
```

Expected: every command exits 0.

- [ ] **Step 5: Inspect the fresh artifacts**

Confirm bundle version `1.1.1`, both architectures, identical hashes for fixed and versioned DMGs, and record actual DMG size. Do not require artificial shrinkage.

- [ ] **Step 6: Perform manual acceptance**

Verify pointer-accurate drag, visible traffic lights, red-close plus menu reopen, complete quit, current-version update UI, offline safety, exact installed launch path, and rollback behavior.

- [ ] **Step 7: Commit release preparation**

Commit: `chore: prepare INbox 1.1.1`

- [ ] **Step 8: Stop before external publication**

Report status, commit log, hashes, artifact size, and acceptance results. Do not push, create `v1.1.1`, upload Release assets, or change public GitHub state without the user's explicit authorization.

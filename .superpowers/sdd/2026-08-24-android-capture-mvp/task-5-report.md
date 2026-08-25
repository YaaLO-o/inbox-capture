# Task 5 Report: Android SAF Vault

## Status

Implemented the Task 5 SAF Vault slice: real tree selection and persisted access, native file operations, the single Vault channel bridge, Dart settings/storage proxies, the Android settings view, real capture-dispatcher wiring, and provider-backed instrumentation coverage. The temporary `写入测试 Capture` control was removed after the real emulator write succeeded.

Planned commit message: `feat: write captures through Android SAF`

## Implementation

- Added `AndroidVaultSettings`, `VaultDescriptor`, and `AndroidSafVaultStorage` on `com.inbox.app/android_vault`.
- Kept Android attachment bytes native-side: only `UriAttachmentSource` is accepted, and stable Kotlin errors map to the Task 2 Dart storage codes.
- Replaced Task 4's temporary Android dispatcher closures with the accessible persisted tree URI and a real `CaptureService` backed by SAF storage.
- Added the white Material 3 Android settings view with the exact `Vault`, `重新选择 Vault`, `悬浮 Capture`, and `权限` labels.
- Added `VaultPreferences`, which stores exactly `vaultTreeUri` and `vaultDisplayName`. Accessibility requires an exact persisted read/write grant and a writable existing tree document.
- Added one application-owned `AndroidVaultBridge`. `MainActivity` only attaches/detaches as picker host and launches `ACTION_OPEN_DOCUMENT_TREE` with read, write, persistable, and prefix flags.
- Picker success takes the persistable grant, validates/creates the layout, and then persists the descriptor. Cancellation preserves the previous descriptor; a missing visible activity returns `NO_ACTIVITY`.
- Added `SafVaultStore` layout, native URI copy, append-first Markdown writing, safe read-before-`wt` fallback, and attachment deletion.

## TDD evidence

### RED

The first focused Dart run exited 1 because the new imports and types did not exist:

```text
flutter test test/android_saf_vault_storage_test.dart test/android_vault_settings_test.dart
```

The first Android connected run reached the intended Kotlin compilation RED because `SafVaultStore` and `AndroidVaultBridge` did not exist:

```text
JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' \
  ./gradlew connectedDebugAndroidTest
```

The first settings widget run exited 1 because `android_settings_view.dart` did not exist. A final deterministic cancellation regression also produced an intentional compile RED while `handlePickedVault` was private:

```text
AndroidVaultBridgeTest.kt:44:16 Cannot access 'handlePickedVault': it is private
BUILD FAILED
```

### GREEN

- Focused final Dart settings/storage/UI suite: 11/11 passed.
- Full Flutter suite: 119/119 passed.
- `dart analyze lib test`: `No issues found!`.
- Focused provider-backed `SafVaultStoreTest`: 2/2 passed on API 36, covering layout creation, byte import, two appends, deletion, and append-rejection fallback.
- Focused `AndroidVaultBridgeTest`: 2/2 passed, covering `NO_ACTIVITY` and cancellation preservation.
- Complete connected Android suite: 6/6 passed on `Pixel_6_API36(AVD) - 16`.
- `testDebugUnitTest`: `BUILD SUCCESSFUL`.
- `flutter build apk --debug`: built `build/app/outputs/flutter-apk/app-debug.apk`.

## Android 16 provider-test constraint and ruling

On the API 36 emulator, an ordinary cross-APK resolver cannot directly exercise a `DocumentsProvider` guarded by Android's signature-level `MANAGE_DOCUMENTS` permission. Granting that permission to production would weaken the SAF boundary and was rejected. The controller ruled to use AndroidX test rules `1.7.0` and deprecated `ProviderTestRule` for an isolated `ContentResolver` while retaining a provider declared only in `src/androidTest`.

The resulting test provider implements roots, document/child queries, create, delete, and `r`, `w`, `wt`, and `wa` modes against an isolated temporary directory. `MANAGE_DOCUMENTS`, the provider, and `android.test.mock` are absent from the production merged manifest. `ProviderTestRule` deprecation is accepted test-only debt; real platform grant integration is covered separately below.

## Real API 36 SAF evidence

Used `/Users/mac/Library/Android/sdk/platform-tools/adb` explicitly with the running `Pixel_6_API36` emulator (`emulator-5554`) and completed the system `ACTION_OPEN_DOCUMENT_TREE` flow. The selected tree rendered as `Universal Capture` and `Vault 可读写`.

The application persisted exactly these two values:

```xml
<string name="vaultTreeUri">content://com.android.externalstorage.documents/tree/primary%3ADocuments%2FINboxTask5Vault%2FUniversal%20Capture</string>
<string name="vaultDisplayName">Universal Capture</string>
```

The temporary real-capture action created the canonical layout beneath that selected tree:

```text
<selected tree>/Universal Capture/2026-08-25.md
<selected tree>/Universal Capture/attachments/
```

ADB inspection showed this real Markdown block:

```markdown
## 14:40

<!-- capture:id=20260825-144029-458a -->

Task 5 SAF write

---
```

After `adb shell am force-stop com.inbox.inbox_app` and a fresh `MainActivity` start, UI automation again found `Universal Capture` and `Vault 可读写`, proving the descriptor and persisted grant survived process restart. Only after this check was the temporary write button removed; the final widget test asserts it is absent.

## Self-review

Reviewed the complete Task 5 diff against the plan and controller brief and ran `git diff --check`. Changes are limited to the specified Dart proxies/UI/wiring, Kotlin preferences/store/bridge/picker host, androidTest provider/tests, Gradle test support, and this report. No Task 6+ share, clipboard Activity, or overlay behavior was added. No root-checkout, shell configuration, or production SAF security setting was changed.

## Concerns

- `ProviderTestRule` is deprecated, but is retained as the controller-approved test-only mechanism for deterministic provider-backed file operations on Android 16.
- The build emits existing Gradle/Kotlin and JDK native-access deprecation warnings; all requested builds and tests still exit successfully.

## Review fix round 1: release the superseded Vault grant

Review found that a successful Vault A to Vault B reselection persisted B but retained A's read/write URI grant. Clearing later released only B, leaving A granted indefinitely.

Added bridge-level instrumentation using the real `AndroidVaultBridge`, `VaultPreferences`, `SafVaultStore`, and test `DocumentsProvider`; Android's permission bookkeeping is represented by a recording `MockContentResolver`. Coverage now proves:

- successful A to B reselection persists and grants B, then releases A with both read and write flags;
- cancellation leaves A stored and granted without any release;
- a layout-validation failure removes only the newly taken B grant and leaves A stored and granted;
- same-URI reselection retains the shared grant and performs no release.

### Review RED

Before the production fix, the focused API 36 run executed five tests and failed only the successful A to B regression because A remained granted:

```text
JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' \
  ./gradlew connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.class=com.inbox.inbox_app.AndroidVaultBridgeTest

Starting 5 tests on Pixel_6_API36(AVD) - 16
successfulReselectionReleasesPreviousGrantAfterPersistingNewVault FAILED
AndroidVaultBridgeTest.kt:75
BUILD FAILED
```

### Review GREEN

The minimal fix releases a different previous URI only after the new grant is taken, its layout is validated/created, and the new descriptor is saved. Previous-grant release uses the complete required read/write flags and is best-effort so a grant Android already revoked cannot undo the successfully persisted new selection.

```text
Starting 5 tests on Pixel_6_API36(AVD) - 16
Finished 5 tests on Pixel_6_API36(AVD) - 16
BUILD SUCCESSFUL
```

Proportionate final verification also passed: complete API 36 connected instrumentation 9/9, Android `testDebugUnitTest`, focused Task 5 Dart tests 11/11, full Flutter tests 119/119, and `dart analyze lib test` with no issues.

## Review fix round 2: confirm durable B before releasing A

Re-review found that round 1 called asynchronous `SharedPreferences.apply()` for B and then released A. Process death in that window could leave the durable preference on A after A's URI grant had already been revoked.

`VaultPreferences.save` now snapshots the prior descriptor and synchronously calls `commit()` for the new descriptor. A false commit result synchronously restores the prior descriptor snapshot and returns false. `AndroidVaultBridge` maps that false result to stable `VAULT_UNAVAILABLE`, cleans up only the newly taken B grant, and never reaches A release. `clearVault` is unchanged because this review is limited to atomic A to B replacement.

The bridge instrumentation's SharedPreferences boundary simulates Android's important failure behavior: a failed commit may already have changed the in-memory map. It records persistence and grant events so the tests verify the consumer-visible sequence rather than source structure.

### Review round 2 RED

Before the production change, the focused API 36 run executed six tests and failed the two new durability regressions:

```text
Starting 6 tests on Pixel_6_API36(AVD) - 16

successfulReselectionReleasesPreviousGrantAfterPersistingNewVault FAILED
expected: [commit:B, release:A]
actual:   [apply:B, release:A]

commitFailureRestoresPreviousVaultAndGrantBeforeRemovingNewGrant FAILED
expected stored Vault A, but Vault B remained in memory

BUILD FAILED
```

### Review round 2 GREEN

After the minimal synchronous save/rollback change, the same command passed all six bridge tests:

```text
Starting 6 tests on Pixel_6_API36(AVD) - 16
Finished 6 tests on Pixel_6_API36(AVD) - 16
BUILD SUCCESSFUL
```

The successful regression observes `commit:B` before `release:A`. The forced-failure regression observes `commit:B`, synchronous rollback `commit:A`, then `release:B`; it also asserts A remains stored and granted and B is not granted.

Final verification passed: complete API 36 connected instrumentation 10/10, Android `testDebugUnitTest`, focused Task 5 Dart tests 11/11, full Flutter tests 119/119, and `dart analyze lib test` with no issues.

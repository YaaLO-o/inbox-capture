# Task 6 report — Android text and URL Share Target

## Implementation

- Added `ShareIntentParser`, `ShareRequest`, and the `SharedUri` type reserved for attachment work.
- Task 6 accepts only `ACTION_SEND` with `text/plain` and nonblank `EXTRA_TEXT`; whitespace is used only for emptiness and the original text is preserved.
- Added exported translucent `ShareCaptureActivity` with only the `text/plain` Share Target filter. It sends `{source: share, text, attachments: []}` through the existing application-owned `AndroidCaptureBridge`, shows a short Toast, and finishes on every bridge callback including the existing ten-second readiness timeout.
- No launcher filter, second Flutter engine, attachment filters, or Task 7 behavior was added.

## RED / GREEN

- RED: `JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' ./gradlew :app:compileDebugAndroidTestKotlin` failed because `ShareIntentParser` and `SharedUri` were missing.
- GREEN: the same focused compilation passed after the implementation.
- `:app:testDebugUnitTest` passed.
- `:app:connectedDebugAndroidTest --no-parallel` passed, 16 tests on `Pixel_6_API36`.

## Explicit ADB share

Installed the debug APK and ran:

```text
adb -s emulator-5554 shell am start -a android.intent.action.SEND -t text/plain \
  --es android.intent.extra.TEXT https://example.com/android-share \
  -n com.inbox.inbox_app/.ShareCaptureActivity
```

`dumpsys activity activities` showed `Displayed com.inbox.inbox_app/.ShareCaptureActivity`, followed by a CLOSE transition with `numActivities=0`. The fresh emulator had no configured Vault (`尚未选择` in the settings UI), so this run exercised the bridge error/finish path and could not produce a Markdown count. No Markdown file was present under `/sdcard`.

## Acceptance rerun on API 36 emulator

Configured the real SAF Vault with DocumentsUI on `emulator-5554`: created and selected `CaptureVault`, then selected the app's `Universal Capture` directory. The app displayed `CaptureVault` and `Vault 可读写`; persisted URI was `content://com.android.externalstorage.documents/tree/primary%3ACaptureVault`.

Explicit component send:

```text
adb -s emulator-5554 shell am start -a android.intent.action.SEND -t text/plain \\
  --es android.intent.extra.TEXT https://example.com/task6-explicit-20260825 \\
  -n com.inbox.inbox_app/.ShareCaptureActivity
```

`dumpsys activity activities` showed `ShareCaptureActivity` displayed and then a CLOSE transition with `numActivities=0`; the resumed Activity returned to `MainActivity`. The actual file at `/storage/emulated/0/CaptureVault/Universal Capture/2026-08-25.md` contained the URL once (`rg -o ... | wc -l` = `1`).

Implicit system Sharesheet send:

```text
adb -s emulator-5554 shell am start -a android.intent.action.SEND -t text/plain \\
  --es android.intent.extra.TEXT https://example.com/task6-sharesheet-20260825
```

The Android `ResolverActivity` displayed `INbox` among Quick Share, Chrome, Gmail, Bluetooth, and Chat. I selected the INbox target icon in the system chooser and confirmed `Just once`. No `ShareCaptureActivity` remained after the handoff; the actual Markdown file contained `https://example.com/task6-sharesheet-20260825` exactly once (`rg -o ... | wc -l` = `1`).

## Review fixes

Activity-level outcome verification runs against the exact production `ShareCaptureActivity` using `ActivityScenario`, `Application.ActivityLifecycleCallbacks`, and an androidTest-only fake `BinaryMessenger` attached through `AndroidCaptureBridge.attach`. Instrumentation covered immediate saved success, immediate bridge error, duplicate callbacks, and the real production `AndroidCaptureBridgeCoordinator` 10,000 ms readiness timeout. Each case observed exactly one capture/destruction; the focused class passed 4/4 on `Pixel_6_API36` in 18 seconds. A `TYPE_NOTIFICATION_STATE_CHANGED` listener was attempted for Toast counting, but Android 16 text Toasts emitted no accessibility event on this emulator, so lifecycle/outcome assertions are the deterministic evidence and the production code path still uses the real Toast.

- `EXTRA_TEXT` is read as `CharSequence` and converted to `String`, preserving styled-share characters; an instrumentation regression covers `SpannableString`.
- `ShareCaptureActivity` handles orientation, screen-size, and smallest-screen-size changes without recreation. `ShareCaptureActivityConfigTest` verifies those manifest flags, while `ShareCaptureCoordinatorTest` verifies one submission/outcome for success, bridge error, and the existing ten-second readiness-timeout result (including duplicate callbacks).
- Focused native checks passed: `:app:testDebugUnitTest`, `:app:connectedDebugAndroidTest` (18 tests on `Pixel_6_API36`), and `:app:assembleDebug`. Flutter tests passed (120 tests).

- Round 4 cleanup regression keeps the original test-attached coordinator alive: teardown switches the fake messenger's outgoing capture calls to the real engine messenger and signals `coreReady` through the coordinator's existing inbound handler. The added post-cleanup capture delegated and completed within three seconds; the focused Activity class passed 5/5 on `Pixel_6_API36`.

## Real Sharesheet

`com.android.chrome` is installed and resolves ordinary web URLs, but Chrome's first-run UI remained at `Checking info…` after selecting `Use without an account`. This prevented completing Chrome's real Sharesheet flow. This is an emulator/source-app setup blocker, not a substituted direct component test.

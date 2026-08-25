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

## Real Sharesheet

`com.android.chrome` is installed and resolves ordinary web URLs, but Chrome's first-run UI remained at `Checking info…` after selecting `Use without an account`. This prevented completing Chrome's real Sharesheet flow. This is an emulator/source-app setup blocker, not a substituted direct component test.

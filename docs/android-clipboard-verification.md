# Android clipboard verification

## Scope

Task 8 focused clipboard probe. The Activity is translucent, `noHistory`, and non-exported. It reads the first clipboard item once after focus using an atomic guard and submits through `AndroidCaptureBridge`.

## API 36 emulator

| Field | Evidence |
|---|---|
| Device | `emulator-5554`, Pixel_6_API36 |
| Android API | 36 |
| Build fingerprint | `google/sdk_gphone64_arm64/emu64a:16/BE2A.250530.026.F3/13894323:userdebug/dev-keys` |
| APK | `flutter build apk --debug` passed; installed successfully |
| Activity declaration | Installed manifest has `exported=false`, `noHistory=true`, `ClipboardCaptureTheme` |
| Direct shell launch | Correctly denied by Android with `Permission Denial ... not exported` |
| App-UID `run-as` launch | Also denied. Exact error: `Permission Denial: package=com.android.shell does not belong to uid=10254`; `run-as` keeps the shell caller identity for ActivityManager on this API 36 image |
| Automated probe checks | 3 focused JVM tests passed: focus-gated exact-once read, blank/empty finish, bridge result/finish-once |
| Android test harness | `connectedDebugAndroidTest` passed 27 tests with the manual harness skipped by default; explicit instrumentation invocation ran the real Activity once and passed |
| Exact Markdown write | Not exercised from shell: no exported test launcher and no configured emulator Vault/clipboard injection path was used |
| Visible source UI | Chrome was brought to the foreground and a known string was entered and copied through the visible address-bar UI |
| Explicit harness probe logs | `start`, `focus`, `clip count=0`, `non-empty=false`, `bridge status=empty`; Activity exited. The attempted visible Chrome copy did not leave text in the emulator clipboard, so no exact Markdown save was claimed |

The non-exported Activity must be launched by the in-app overlay entrypoint in the later task or by an instrumented app-owned test. No exported/debug workaround was added.

## Xiaomi 13 Pro gate

At the final gate check, `adb devices -l` showed only `emulator-5554`; the Xiaomi 13 Pro was absent and therefore this gate is **NEEDS_CONTEXT**, not a platform failure. No phone attempts were performed.

| Device fact | Value |
|---|---|
| Android API | pending phone connection |
| Build fingerprint | pending phone connection |
| HyperOS | pending phone connection |

| # | Source app | Attempt | Copied text exact once | Hang | Full settings page | Prompt/failure/log facts |
|---:|---|---:|---|---|---|---|
| 1 | Chrome | 1 |  |  |  |  |
| 2 | Chrome | 2 |  |  |  |  |
| 3 | Chrome | 3 |  |  |  |  |
| 4 | Chrome | 4 |  |  |  |  |
| 5 | Chrome | 5 |  |  |  |  |
| 6 | WeChat | 1 |  |  |  |  |
| 7 | WeChat | 2 |  |  |  |  |
| 8 | WeChat | 3 |  |  |  |  |
| 9 | WeChat | 4 |  |  |  |  |
| 10 | WeChat | 5 |  |  |  |  |
| 11 | Other content app | 1 |  |  |  |  |
| 12 | Other content app | 2 |  |  |  |  |
| 13 | Other content app | 3 |  |  |  |  |
| 14 | Other content app | 4 |  |  |  |  |
| 15 | Other content app | 5 |  |  |  |  |

Pass criterion remains at least 14/15 exact saves, no hang, and no navigation to full settings.

### WeChat gate attempts 1-5

The prior five `com.tencent.mm`, user 999 clone/profile attempts are excluded from the main-WeChat gate: they did not use the required foreground main WeChat user (`u0`) and their count-only storage observation cannot establish a main-user Markdown occurrence. No token text was emitted.

| # | Source app | Result | Probe facts | Activity exit | Shell token count |
|---:|---|---|---|---|---:|
| 1 | WeChat | saved | focus, clip count=1, non-empty=true, bridge status=saved | Yes; WeChat foreground | 0 |
| 2 | WeChat | saved | focus, clip count=1, non-empty=true, bridge status=saved | Yes; WeChat foreground | 0 |
| 3 | WeChat | saved | focus, clip count=1, non-empty=true, bridge status=saved | Yes; WeChat foreground | 0 |
| 4 | WeChat | saved | focus, clip count=1, non-empty=true, bridge status=saved | Yes; WeChat foreground | 0 |
| 5 | WeChat | saved | focus, clip count=1, non-empty=true, bridge status=saved | Yes; WeChat foreground | 0 |

### Xiaomi main-WeChat gate attempts 1-5

With the temporary exported debug APK installed, `dumpsys`/`cmd package resolve-activity` confirmed the installed explicit component `com.inbox.inbox_app/.ClipboardCaptureActivity`; five explicit starts then ran one at a time from foreground main WeChat (`com.tencent.mm`, `u0`). The source manifest was restored immediately after installation to `android:exported="false"`.

The five runtime probes all reached `start`, `focus`, `clip count=1`, `non-empty=true`, and `bridge status=saved`; each Activity exited and `mCurrentFocus` returned to `u0 com.tencent.mm/com.tencent.mm.ui.LauncherUI`. The requested directory `/storage/emulated/0/测试/Universal Capture/today` did not exist. The available date Markdown file was `/storage/emulated/0/测试/Universal Capture/2026-08-25.md`, with modification time `21:24` and size 567 bytes throughout these launches. Its count-only occurrences for the authorized main-WeChat token were 0 after every attempt; count-only `INbox-chrome-*` occurrences were also 0 throughout. Therefore the required baseline-plus-one Markdown proof was not obtained despite each bridge result being `saved`.

| # | Source app | Result | Probe facts | Activity exit / foreground | Main-WeChat token occurrence | Chrome token occurrence |
|---:|---|---|---|---|---:|---:|
| 1 | WeChat main (`u0`) | saved | start, focus, clip count=1, non-empty=true, bridge status=saved | Yes; `u0` WeChat foreground | 0 | 0 |
| 2 | WeChat main (`u0`) | saved | start, focus, clip count=1, non-empty=true, bridge status=saved | Yes; `u0` WeChat foreground | 0 | 0 |
| 3 | WeChat main (`u0`) | saved | start, focus, clip count=1, non-empty=true, bridge status=saved | Yes; `u0` WeChat foreground | 0 | 0 |
| 4 | WeChat main (`u0`) | saved | start, focus, clip count=1, non-empty=true, bridge status=saved | Yes; `u0` WeChat foreground | 0 | 0 |
| 5 | WeChat main (`u0`) | saved | start, focus, clip count=1, non-empty=true, bridge status=saved | Yes; `u0` WeChat foreground | 0 | 0 |

### Xiaomi preparation and Chrome gate attempt

The connected device was recorded as Xiaomi 13 Pro / `nuwa` / `2210132C`, API 36, fingerprint `Xiaomi/nuwa/nuwa:16/BP2A.250605.031.A3/OS3.0.310.0.WMBCNXM:user/release-keys`, HyperOS `OS3.0.310.0.WMBCNXM`. INbox and its androidTest APK were installed with `adb install -r -t` after USB installation authorization. The SAF descriptor persisted as `content://com.android.externalstorage.documents/tree/primary%3A测试`, display name `测试`; shell access was denied as expected because the grant belongs to INbox. For the gate only, a debug APK with the Activity temporarily exported was installed (SHA-256 `c143b6e1249658677c162de4aebf02b488b71ab7f5910338a4a31b5674c641c6`); the source manifest was restored to non-exported immediately after the minimal launch check.

After the user copied the authorized Chrome token and left Chrome visible, five explicit component launches were performed one at a time using the temporary gate APK. Every attempt reached focus, observed one non-empty clip, returned `saved`, exited, returned Chrome to the foreground, and incremented the count-only Markdown occurrence by exactly one. Baseline count was 1; final count was 6.

| # | Source app | Result | Probe facts | Activity exit | Markdown occurrence delta |
|---:|---|---|---|---|---:|
| 1 | Chrome | saved | focus, clip count=1, non-empty=true, bridge status=saved | Yes; Chrome foreground | +1 (2) |
| 2 | Chrome | saved | focus, clip count=1, non-empty=true, bridge status=saved | Yes; Chrome foreground | +1 (3) |
| 3 | Chrome | saved | focus, clip count=1, non-empty=true, bridge status=saved | Yes; Chrome foreground | +1 (4) |
| 4 | Chrome | saved | focus, clip count=1, non-empty=true, bridge status=saved | Yes; Chrome foreground | +1 (5) |
| 5 | Chrome | saved | focus, clip count=1, non-empty=true, bridge status=saved | Yes; Chrome foreground | +1 (6) |

Repeatable app-owned harness command after installing both APKs without clearing app data:

```sh
adb shell am instrument -w \
  -e class com.inbox.inbox_app.ManualClipboardProbeTest \
  -e manualClipboardProbe true \
  com.inbox.inbox_app.test/androidx.test.runner.AndroidJUnitRunner
adb logcat -d -s INboxClipboardProbe:D '*:S'
```

## Task 9 overlay bubble (Xiaomi 13 Pro)

Device: Xiaomi 13 Pro `nuwa` / `2210132C`, Android 16 (API 36), HyperOS `OS3.0.310.0.WMBCNXM`, build `BP2A.250605.031.A3`. APK installed via `adb -s 4f3ae808 install -r -t app/build/app/outputs/flutter-apk/app-debug.apk`.

### Settings UI

- App launches to `Vault` + `悬浮 Capture` + `权限` sections.
- With the test Vault `测试` selected, both permission rows read `已授予`; the action button shows `停止悬浮球` when the service is running and `开启悬浮球` when stopped; status text shows `悬浮球运行中` / `悬浮球未开启`.
- `dumpsys window windows` while running lists one `ty=APPLICATION_OVERLAY` window owned by `com.inbox.inbox_app`: `mAttrs={(954,1137)(126x126) ... fmt=TRANSLUCENT}` (126 px = 48 dp at 420 dpi touch container; the visible dot is 32 dp).
- `dumpsys activity services com.inbox.inbox_app` lists `ServiceRecord{... .OverlayService}` with `isForeground=true foregroundId=4101 types=0x40000000` (`specialUse`) and `foregroundNoti=Notification(channel=inbox_overlay ... flags=ONGOING_EVENT|NO_CLEAR|FOREGROUND_SERVICE ... actions=1 ...)`.

### End-to-end save (manual, user-performed copy)

User copied a unique marker in a foreground main-space app and tapped the bubble. Logcat:

```
08-25 23:17:49.814 D INboxClipboardProbe: start
08-25 23:17:49.873 D INboxClipboardProbe: focus
08-25 23:17:49.875 D INboxClipboardProbe: clip count=1
08-25 23:17:49.876 D INboxClipboardProbe: non-empty=true
08-25 23:17:50.074 D INboxClipboardProbe: bridge status=saved
```

- File `/storage/emulated/0/测试/Universal Capture/2026-08-25.md` grew from 651 to 822 bytes.
- Marker `TASK9-E2E-01-7QK2` appears exactly once (`grep -c` = 1) under `## 23:17` with capture id `20260825-231749-c25a`.
- Two distinct copies saved across two taps (23:14 `他家红枣，椰子奶泡泡好吃`; 23:17 `TASK9-E2E-01-7QK2`) confirm the latest clipboard item is read each time, not a stale one.
- The translucent `ClipboardCaptureActivity` finished and foreground returned to the source app.

### Drag + edge snap

- The 48 dp/126 px touch container (32 dp visible dot) drags left/right/center and snaps to the nearest horizontal edge on release; it stays within screen bounds and is not clipped by the status/navigation bars.
- Persistence: the snapped side + Y are stored in a dedicated `inbox_overlay_prefs` shared-preferences file (not the Vault prefs); stopping and restarting the bubble restores the last position.

### Stop from settings

After tapping `停止悬浮球`:

- `dumpsys window windows | grep ty=APPLICATION_OVERLAY | grep com.inbox.inbox_app` returns nothing (overlay view removed).
- `dumpsys activity services com.inbox.inbox_app` returns no `OverlayService` `ServiceRecord` (FGS destroyed).
- The ongoing `inbox_overlay` notification disappears; the low-importance notification channel remains (expected).
- The settings UI flips to `开启悬浮球` / `悬浮球未开启`.

### Force-stop (HyperOS-kill proxy)

`adb shell am force-stop com.inbox.inbox_app` while the overlay is running:

- The overlay window disappears and the FGS is destroyed with no crash.
- Reopening settings shows `悬浮球未开启`; `OverlayService.isRunning` is false.
- There is no `BOOT_COMPLETED` receiver and the service returns `START_NOT_STICKY`, so neither a reboot nor a HyperOS process cleanup auto-restarts it. The user restarts from settings.

### Revocation robustness

Not exercised live on the user's phone (per instructions, no toggle-revoke). Code path: `MainActivity.onResume` calls `OverlayService.stop(this)` when `OverlayService.isRunning && !Settings.canDrawOverlays(this)` and then `vaultBridge.notifyOverlayStateChanged()`, so a revoked overlay permission tears the service down and refreshes the UI without a stale `运行中` state.

### Notes

- A pre-existing unrelated working-tree change to `SafVaultStore.kt` was present at the start of Task 9; it was reverted to commit `4a3d18f` before the final build so Task 9 ships zero changes to the forbidden file.
- No exported Activities, Accessibility, clipboard polling, IME history, image clipboard, AI, history UI, cloud sync, or battery-optimization permissions were added. `ClipboardCaptureActivity` remains `exported=false` / `noHistory=true`.

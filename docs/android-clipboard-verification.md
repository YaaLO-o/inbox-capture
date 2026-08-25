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

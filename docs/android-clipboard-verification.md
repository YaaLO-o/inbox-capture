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

### Xiaomi preparation and Chrome gate attempt

The connected device was recorded as Xiaomi 13 Pro / `nuwa` / `2210132C`, API 36, fingerprint `Xiaomi/nuwa/nuwa:16/BP2A.250605.031.A3/OS3.0.310.0.WMBCNXM:user/release-keys`, HyperOS `OS3.0.310.0.WMBCNXM`. INbox and its androidTest APK were installed with `adb install -r -t` after USB installation authorization. The SAF descriptor persisted as `content://com.android.externalstorage.documents/tree/primary%3A测试`, display name `测试`; shell access was denied as expected because the grant belongs to INbox.

After the user copied the authorized Chrome token and left Chrome visible, Chrome attempt 1 was invoked through the app-owned manual instrumentation harness. The instrumentation emitted the test-start status but did not return within 60 seconds; no `INboxClipboardProbe` facts were emitted, no Activity exit was observed, and the Markdown token occurrence count remained 0. The attempt was stopped as a harness hang; attempts 2–5 were not run.

| # | Source app | Result | Probe facts | Activity exit | Markdown occurrence delta |
|---:|---|---|---|---|---:|
| 1 | Chrome | HUNG | No probe log emitted | No | 0 |
| 2 | Chrome | not run |  |  |  |
| 3 | Chrome | not run |  |  |  |
| 4 | Chrome | not run |  |  |  |
| 5 | Chrome | not run |  |  |  |

Repeatable app-owned harness command after installing both APKs without clearing app data:

```sh
adb shell am instrument -w \
  -e class com.inbox.inbox_app.ManualClipboardProbeTest \
  -e manualClipboardProbe true \
  com.inbox.inbox_app.test/androidx.test.runner.AndroidJUnitRunner
adb logcat -d -s INboxClipboardProbe:D '*:S'
```

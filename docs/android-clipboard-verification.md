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
| Direct shell launch | Correctly denied by Android with `Permission Denial ... not exported`; this confirms the production entrypoint cannot be shell-launched as a workaround |
| Automated probe checks | 3 focused JVM tests passed: focus-gated exact-once read, blank/empty finish, bridge result/finish-once |
| Exact Markdown write | Not exercised from shell: no exported test launcher and no configured emulator Vault/clipboard injection path was used |
| Probe log inspection | No production probe log was generated because the non-exported Activity was not shell-launched |

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

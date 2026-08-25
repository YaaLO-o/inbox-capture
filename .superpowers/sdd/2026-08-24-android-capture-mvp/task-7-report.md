# Task 7 report — Android shared attachments

Base: `25365ec8a2500ad301fc30921b9c28bd4c2ba369`

## Implemented

- `ShareIntentParser` accepts `ACTION_SEND` and `ACTION_SEND_MULTIPLE`, reads `EXTRA_STREAM` and every `ClipData` URI, retains carrier order, and deduplicates URI values.
- Metadata uses `OpenableColumns.DISPLAY_NAME`, URI fallback, resolver MIME, safe lowercase extensions, and only the planned exact MIME fallback map.
- The native coordinator sends only URI strings and metadata to Dart. Existing Android SAF storage retains native input-stream copying; Dart keeps Task 3 import/rollback semantics.
- Share filters now cover `SEND` and `SEND_MULTIPLE` for `image/*`, `video/*`, `application/pdf`, and `*/*`. The translucent Activity still finishes only from the bridge outcome/timeout.

## RED then GREEN

- RED: `ShareIntentParserTest` initially failed on API 36 for `parsesSingleStreamWithProviderMetadata` and `parsesAllCarriersInOrderAndDeduplicatesUris` because Task 6 parsing returned `null` for attachment intents.
- GREEN: focused `ShareIntentParserTest` passed 8/8 after parser and metadata implementation.
- Dart shared-core coverage verifies PNG embeds while PDF, MP4, and extensionless ordinary files use normal links. The existing second-import failure transaction test now explicitly proves no Markdown append and removal of the first imported name.

## Verification

- `flutter test test/capture_service_test.dart`: 23 passed.
- `dart analyze lib test`: no issues.
- `flutter test`: 120 passed.
- `JAVA_HOME=/Applications/Android Studio.app/Contents/jbr/Contents/Home ./gradlew testDebugUnitTest connectedDebugAndroidTest assembleDebug`: successful; API 36 instrumentation 25/25 passed and debug APK assembled.
- SAF test provider copy coverage asserts unchanged byte values after import; transaction coverage asserts failed second import deletes the first target and never appends Markdown.

## Initial shell-grant probe

The API 36 emulator has a real selected SAF Vault (`CaptureVault`). I created/scanned a screenshot, second image, PDF, MP4, and extensionless ordinary source and recorded their SHA-256 values. Explicit `adb shell am start --grant-read-uri-permission` launches each Share Activity and preserves `flg=0x1`, but it cannot create a usable MediaProvider grant from the shell source UID:

```text
E/DatabaseUtils: java.lang.SecurityException: com.inbox.inbox_app has no access to content://media/external/file/49
W/ContentResolver: Failed to get type for: content://media/external/file/49 (No item at content://media/external/file/49)
```

The failed native copy removes its just-created target and appends no Markdown, preserving data safety. This is an Android 16 external-provider/share-caller grant limitation, not a production permission failure. Per the Task 7 ruling, no risky permission/provider workaround was added. Complete the five real source-app Sharesheet flows (including selecting two images together) from a provider-owning emulator app such as Files/Photos, then compare source/target SHA-256 and inspect the date Markdown embeds/links.

## API 36 real Files Sharesheet acceptance

After the shell probe, the installed system Files/DocumentsUI app was used as the provider-owning sender. Files long-press selection → `Share` opened the genuine Android ResolverActivity, then its `INbox` target was selected. This is deliberately different from `adb shell am`: Files owns the source `content://` URI and grants it through the Sharesheet.

All activities had exited after their callback (`dumpsys activity activities` contains no `ShareCaptureActivity`). The source hashes below were recorded before the shares and again after them; the identical final source values and sizes prove source immutability. Destination bytes are exact matches.

| Flow | Source (SHA-256, bytes) | Target | Markdown evidence |
| --- | --- | --- | --- |
| Single screenshot | `task7-shot.png`: `c1cc7cc17b3986970558f1edae37f0278b4a26e6c8bd18ed7559be081c1beda8`, 22 | `20260825-174645-4d47.png`: same, 22 | `![[attachments/20260825-174645-4d47.png]]` |
| Two images together | `task7-shot.png`: `c1cc7cc17b3986970558f1edae37f0278b4a26e6c8bd18ed7559be081c1beda8`, 22; `task7-second.png`: `68323ee7b377d81a0593b44c2acce1fcca00441fbd56fdc961628f8bd58731a1`, 18 | `20260825-174344-6029.png`: first hash, 22; `20260825-174344-6029-1.png`: second hash, 18 | two embeds: `![[attachments/20260825-174344-6029.png]]`, `![[attachments/20260825-174344-6029-1.png]]` |
| PDF | `task7-document.pdf`: `939b6c103f60ef49c9922be0d2e71e9e8d087df91723c47229a21b5f48ca8e6a`, 11 | `20260825-174147-6e13.pdf`: same, 11 | `[[attachments/20260825-174147-6e13.pdf|task7-document.pdf]]` |
| Video | `task7-video.mp4`: `674bcfb0fc4d32710b78f9e189fd109dd369b1ba66052ca4aec970ea7d71ce22`, 11 | `20260825-174514-fc3b.mp4`: same, 11 | `[[attachments/20260825-174514-fc3b.mp4|task7-video.mp4]]` |
| Ordinary extensionless file | `task7-LICENSE`: `0e8ec2c1d6f90178e3795fccc7e96918792718ce7a0fdd5d34f0b1cb69b02dc6`, 16 | `20260825-174601-b1dc`: same, 16 | `[[attachments/20260825-174601-b1dc|task7-LICENSE]]` |

The two-image ResolverActivity header explicitly showed `Sharing 2 images`. The final date Markdown contained image embeds only for PNGs and ordinary links for PDF, MP4, and the extensionless file.

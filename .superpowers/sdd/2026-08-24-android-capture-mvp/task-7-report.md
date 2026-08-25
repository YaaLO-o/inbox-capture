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

## NEEDS_CONTEXT — real external-share acceptance

The API 36 emulator has a real selected SAF Vault (`CaptureVault`). I created/scanned a screenshot, second image, PDF, MP4, and extensionless ordinary source and recorded their SHA-256 values. Explicit `adb shell am start --grant-read-uri-permission` launches each Share Activity and preserves `flg=0x1`, but it cannot create a usable MediaProvider grant from the shell source UID:

```text
E/DatabaseUtils: java.lang.SecurityException: com.inbox.inbox_app has no access to content://media/external/file/49
W/ContentResolver: Failed to get type for: content://media/external/file/49 (No item at content://media/external/file/49)
```

The failed native copy removes its just-created target and appends no Markdown, preserving data safety. This is an Android 16 external-provider/share-caller grant limitation, not a production permission failure. Per the Task 7 ruling, no risky permission/provider workaround was added. Complete the five real source-app Sharesheet flows (including selecting two images together) from a provider-owning emulator app such as Files/Photos, then compare source/target SHA-256 and inspect the date Markdown embeds/links.

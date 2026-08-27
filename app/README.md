# INbox Flutter Client

This is the only production client for INbox. It shares one Dart Capture layer across Android, macOS, and Windows, with small native adapters under each platform directory.

Run from this directory:

```bash
flutter pub get
flutter test
flutter run -d macos
```

On Windows:

```powershell
flutter pub get
flutter test
flutter run -d windows
```

On Android 10+:

```bash
flutter build apk --debug
flutter run -d <android-device-id>
```

Android uses a persisted Storage Access Framework grant for the selected Obsidian Vault. The system Share Target accepts text, URLs, images, PDFs, videos, and ordinary files. The optional clipboard bubble requires overlay permission and, on Android 13+, notification permission; it does not start on boot.

See the repository [README](../README.md) and [Android MVP verification record](../docs/android-mvp-verification.md) for architecture, Vault layout, prerequisites, and current platform verification status.

# INbox Flutter Desktop Client

This is the only production client for INbox. It shares one Dart Capture and storage layer across macOS and Windows, with small native adapters under `macos/` and `windows/`.

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

See the repository [README](../README.md) for architecture, Vault layout, prerequisites, and current platform verification status.

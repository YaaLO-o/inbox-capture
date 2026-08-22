# Flutter Desktop Unification Design

## Status

Approved for implementation by the user-provided merge brief on 2026-08-22.

## Goal

Make `app/` the only production client and support macOS and Windows from one Flutter project. Both platforms use the same Dart capture model, storage implementation, Markdown protocol, Vault validation, and Flutter UI. Native code only adapts operating-system clipboard, folder selection, persistence, window control, and quit behavior.

## Repository structure

The production project lives in `app/`. The former root Electron project moves intact to `legacy/electron-windows/` as a reference implementation. Root commands and documentation point to Flutter; Electron no longer appears to be the supported entry point.

Historical Electron design documents move with the legacy project. New cross-platform specifications remain under `docs/superpowers/`.

## Shared product behavior

The shared Flutter UI adopts the useful parts of the old Windows widget: a compact always-on-top capture tool, a visible drag handle, a round `收` capture button, and short status feedback. The existing onboarding and right-click actions remain shared.

The shared Dart flow remains:

```text
ClipboardService
  -> CaptureService
  -> StorageService
  -> Obsidian Vault
```

There are no platform-specific storage services and no platform branches in capture or Markdown generation.

## Canonical Vault layout

New captures on both platforms use one user-visible layout:

```text
<Vault>/
└── Universal Capture/
    ├── YYYY-MM-DD.md
    └── attachments/
        └── <capture-id>.<extension>
```

This retains the old Windows client's direct `Universal Capture` classification while adding the Mac Flutter attachment model. Existing `素材/Inbox`, `素材/attachments`, and existing `Universal Capture` files are never deleted or migrated automatically. New versions only standardize future writes.

Each daily file begins with `# YYYY-MM-DD`. Every appended entry contains a local time heading, a unique Capture ID comment, optional trimmed text, zero or more Obsidian embeds such as `![[attachments/name.png]]`, and a separator. Files are opened in append mode only.

## Vault validation

`SettingsService.loadValidVaultPath()` reads the native stored path and validates it through shared Dart filesystem logic. A missing or non-directory path is cleared through the same MethodChannel and onboarding is shown. Validation never creates directories. Layout creation happens only after a user-selected or validated path reaches `CaptureService`.

## Clipboard precedence

The MethodChannel result contract remains:

```text
channel: com.inbox.app/clipboard
method:  readClipboard
result:  text, imageBytes, imageExtension, imageMimeType, files
```

Local file URLs have priority over bitmap data. macOS and Windows native adapters skip image extraction when copied files are present. Shared Dart also enforces the same precedence so a malformed or future adapter cannot save one copied file twice. Text may accompany files and remains part of the same Capture.

## Native settings contract

Both platforms implement `com.inbox.app/settings` with:

- `getVaultPath`
- `setVaultPath(path)`
- `clearVaultPath`
- `pickFolder`
- `setWindowSize(width, height)`
- `moveWindowBy(dx, dy)`
- `quit`

macOS keeps UserDefaults, NSOpenPanel, and AppKit window behavior. Windows uses HKCU registry persistence, IFileDialog folder selection, Win32 window positioning, and process/window messages.

## Windows adapter

The generated Flutter Windows Runner registers both MethodChannels. Clipboard text uses `CF_UNICODETEXT`; Explorer files use `CF_HDROP`; registered PNG/JPEG clipboard formats are retained when available; DIB/bitmap data falls back to PNG. Explorer files suppress bitmap extraction. The runner uses a borderless tool window, keeps it topmost, supports shared drag updates, and does not appear as a normal taskbar application.

No Flutter desktop plugin or network service is introduced.

## Testing and verification

Shared Dart tests cover the canonical paths and Markdown, append behavior, Capture IDs, invalid stored Vault cleanup, identical storage output for platform-labelled inputs, and file-over-bitmap precedence. Existing capture tests remain green.

macOS verification runs dependency resolution, Dart analysis, Flutter tests, a debug build, and a short process launch. Because Flutter Windows cannot be built on macOS, a minimal GitHub Actions Windows job runs `flutter pub get`, `flutter test`, and `flutter build windows`. Until that job or a Windows machine succeeds, Windows native compilation and UI behavior are reported as unverified rather than complete.

## Out of scope

AI features, classification, tags, search, sync, accounts, backend services, databases, network content parsing, downloads, Android, iOS, Web, historical Vault migration, installers, signing, and distribution are excluded.

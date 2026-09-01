# Windows Capture audit

Date: 2026-09-01
Baseline: `main` at `f654b6ad6c72afda3d06733c901e1219ca020c71`
Working branch: `feature/windows-capture`

## Scope and existing code

`app/` is the sole Flutter app. `CaptureService`, `DesktopFileVaultStorage`
(the current shared desktop storage service), `ClipboardReader` /
`ClipboardService`, `SettingsService`, Capture models, ID generation,
`VaultPaths`, `MarkdownFormatter`, onboarding and the pixel chest UI are shared.
Android has its own SAF storage adapter; it must remain unchanged.

The current protocol is **Universal Capture/YYYY-MM-DD.md** and
**Universal Capture/attachments/**, minute-level headings, stable second-level
capture IDs, standard Markdown images and ordinary file links. The supplied
task's older `素材/Inbox` and wiki embeds would conflict with current macOS data.
This work preserves the current protocol and leaves all historical files alone.

macOS uses Swift/AppKit for clipboard, directory picker, UserDefaults, window
styles/dragging and application updates. Windows already has a C++/Win32 target
with clipboard text, PNG/JPEG, bitmap conversion, Explorer CF_HDROP, IFileDialog,
HKCU settings, color-key transparency and basic movement. No extra runtime
plugin is needed to finish these native adapters.

`legacy/electron-windows/` is retained and reviewed. It contains a text-only
Electron implementation with direct Obsidian configuration discovery. Its
business/storage logic is superseded by the shared Dart core. No migration of
that code or data is warranted. Relevant history: `5b91c8f` (legacy move),
`0ed2c04` (Flutter adapter), `b4ebf7a` (transparency), `41273d7` (control center).
Remote macOS and Android branches are preserved.

## Gaps found before implementation

- No Windows system tray or restoration after Explorer restarts.
- `setWindowMode` is a no-op; `showWindow` and native version reading are absent.
- Initial X/Y come from a physical work area but are scaled again, so high-DPI
  startup can put the pet outside the display. Resizing also does not clamp to
  the work area.
- First launch starts at 132x132 then expands; use a visible onboarding size.
- Delta dragging reads coordinates relative to the moving window; reuse native
  absolute cursor sessions to avoid feedback and jitter.
- Shared update flow selects a macOS DMG. Windows must open the releases page
  on explicit request, without running the Mac download/install pipeline.
- Clipboard open failure looks like empty content. Report an actual platform
  error instead; the shared Capture/UI already handles failures.
- UTF-16 conversion caps all text at 32767 characters. Clipboard reads must
  use their allocation bounds and preserve long text; image memory also needs
  bounds checks before handing DIB data to GDI.
- Some shared tests create filenames illegal on Windows (`|`, newlines).
  Test name sanitization with in-memory attachment metadata and keep actual
  filesystem fixtures valid on both desktop platforms.

## Validation plan

Run the existing Flutter suite plus Windows shell/channel, Unicode/multiline,
append, debounce, persistence and attachment tests. Build the actual Debug
runner with MSVC. Use an isolated test Vault for text, images and Explorer
files, restart, drag, tray show/hide/change/open/quit. Preserve source files.
macOS Dart tests run here; AppKit build/interaction require a Mac and will be
reported separately. No push, release publication, legacy deletion or new
product features are part of this work.

## Implementation and evidence

Windows now supplies the missing Win32 adapters without duplicating the Dart
capture core: bounded clipboard reads (Unicode text, registered PNG/JPEG,
bitmap-to-PNG and Explorer file lists), native folder selection, HKCU Vault
persistence, standard/floating window modes, absolute-cursor dragging, shell
show/hide/close behavior, app version reporting and a native system tray. The
tray owns only shell UI and sends actions back to Dart. Windows update requests
open the GitHub releases page and never enter the macOS DMG installer.

Validation on the Windows host:

- `flutter analyze`: no issues.
- `flutter test`: 150 passed, 2 skipped POSIX-only permission tests.
- Native Win32 adapter regression executable: 14 passed, 0 failed. It uses a
  real window, registry round-trip and real clipboard formats, including 50,000
  Unicode characters, bitmap conversion and Explorer file priority.
- `flutter build windows --debug` and `--release`: both succeeded. Flutter
  3.47's analysis/MSBuild transport corrupts non-ASCII project paths, so the
  same checkout was addressed through `C:\Users\Yangy\inbox-work`; source and
  Git state remain in the original checkout.
- Release runner launched and remained responsive. The real first-run folder
  picker accepted the isolated Unicode test path under `%TEMP%`, persisted it,
  and switched the standard onboarding window into the floating pet. The prior
  Vault registry state was restored after the run.

The Windows automation framework deliberately excludes the final transparent
`WS_EX_TOOLWINDOW`, so click-through acceptance for actual text/image/Explorer
capture, pet dragging, rapid clicks and tray menu items still needs a short
human pass. Those paths are covered separately by the shared Dart suite and the
native clipboard/window regression target. AppKit compilation and live macOS
interaction remain Mac-only checks; all shared Dart/macOS behavior tests pass.

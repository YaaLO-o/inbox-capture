# Universal Capture Windows MVP Design

## Goal

Build the smallest useful desktop capture loop for Windows: the user copies text in any application, clicks a small always-on-top floating control, and the application appends the clipboard text to a local Markdown file with immediate feedback.

This version validates capture speed and reliability. It does not include AI processing, cloud sync, accounts, categories, OCR, links, or clipboard history.

## Platform and technology

- Electron with plain HTML, CSS, and JavaScript.
- Windows is the validation platform; the implementation avoids Windows-only APIs so a later macOS build can reuse it.
- Node.js built-in modules handle local filesystem writes.
- Electron owns clipboard access and the floating window lifecycle.

Electron is selected because Node.js is already installed, it supports the required desktop and clipboard APIs, and it provides a direct path to macOS. WPF would be more native but Windows-specific. Tauri would produce a smaller package but requires a Rust toolchain that is not currently installed.

## User experience

1. Launching the app displays a compact, frameless, always-on-top floating window.
2. The window can be dragged to a convenient screen position.
3. Clicking the capture button reads the current text clipboard.
4. When text exists, the app appends it to the Markdown file and briefly displays `已保存`.
5. When the clipboard has no text, it briefly displays `剪贴板没有文本` and writes nothing.
6. When writing fails, it displays `保存失败` without crashing.

The MVP has no settings screen. Closing the floating window exits the application. A keyboard shortcut, tray icon, auto-start behavior, packaging installer, and custom desktop-pet artwork are outside this version.

## Storage

The capture file is:

`%USERPROFILE%\Documents\Universal Capture\captures.md`

The application creates the folder and file when needed. Each capture is appended in UTF-8 using this stable format:

```markdown
## 2026-08-16 14:30:00

Copied text exactly as read from the text clipboard.

---
```

The original clipboard text is preserved. Line endings are normalized only by the operating system and filesystem APIs; no classification or content cleanup occurs. Whitespace-only clipboard content is treated as empty.

## Components and boundaries

### Capture file module

A small Node.js module receives text, a timestamp, and a target path. It validates that the text is non-empty, creates the parent folder, formats one Markdown entry, and appends it. It has no Electron or UI dependency and is covered by filesystem tests using temporary directories.

### Electron main process

Creates the floating window, reads the clipboard after a capture request, invokes the capture file module, and returns a structured success or error result. It exposes only the single capture action to the renderer through a preload bridge.

### Renderer

Renders the draggable floating control, sends the capture request on click, and changes its short status label based on the returned result. It does not access Node.js or the filesystem directly.

## Security and privacy

- The clipboard is read only after an explicit click, not monitored in the background.
- Data is written only to the local Markdown file.
- The renderer runs with context isolation and without Node.js integration.
- No network calls, telemetry, accounts, or external services are present.

## Error handling

- Empty or whitespace-only text produces an `empty` result and no file change.
- Filesystem errors produce an `error` result and a lightweight failure status in the window.
- Rapid repeated clicks are disabled while one write is in progress to avoid accidental duplicate concurrent writes.

Deliberate repeated clicks after a completed save create repeated entries. Automatic deduplication is outside the MVP because it can discard intentional captures.

## Testing and acceptance

Automated tests are written before implementation for the capture file module:

- It formats and appends one text capture with the supplied timestamp.
- It creates the destination directory when absent.
- It preserves multiline and Unicode text.
- It rejects whitespace-only text without changing the file.
- It appends a second capture without overwriting the first.

Desktop integration is verified with a development smoke mode that writes known text to Electron's clipboard, invokes the same capture path used by the UI, and confirms the Markdown output in an isolated temporary location. This validates Electron clipboard access without modifying the user's real capture file.

The MVP is accepted when automated tests pass, the Electron smoke verification confirms clipboard-to-Markdown behavior, and the floating window launches successfully on Windows.

## Project location

All project files live under:

`C:\Users\Yangy\Documents\Codex\UniversalCapture`

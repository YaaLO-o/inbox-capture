# macOS Core / Assistant Decoupling Design

## Goal

Make the menu-bar black dot the stable INbox Core capture entry while retaining the pixel chest as an optional Floating Assistant.

## Architecture

- Dart owns one `CaptureService` and wraps it with a small `CaptureCoordinator`.
- Both menu-bar and Floating Assistant triggers call `CaptureCoordinator.capture`.
- `CaptureCoordinator` publishes platform-neutral `idle`, `success`, and `failure` feedback states.
- A dedicated `CoreBridge` carries menu actions from macOS to Dart and feedback states from Dart to macOS.
- `MenuBarController` owns the `NSStatusItem`, menu actions, and black/green/red rendering. It never reads the clipboard or vault and never formats or writes captures.
- `MainFlutterWindow` owns Floating Assistant window visibility. Visibility is persisted independently from process lifetime.

## Capture Flow

1. A left click on the menu-bar dot invokes `capture` over the Core channel.
2. Dart resolves the current vault and calls the shared `CaptureCoordinator`.
3. The coordinator calls the existing `CaptureService`.
4. A saved result publishes `success`; every non-saved or thrown result publishes `failure`.
5. After a short feedback interval the coordinator publishes `idle`.
6. `MenuBarController` renders idle as black, success as green, and failure as red.

The Floating Assistant receives only a capture callback. It keeps its animation and safe feedback copy, but no longer owns or receives a `CaptureService`.

## Menu and Window Lifecycle

- Left click on the dot captures. Right click opens the menu.
- Menu items are INbox, Capture, Inbox, History, Assistants > Floating Assistant, Settings, and Quit INbox.
- Inbox and History reuse the existing read-only content view; Settings reuses the control center.
- Floating Assistant visibility is stored in `UserDefaults`, defaults to visible, and is exposed through `SettingsService` and the control center.
- Hiding the assistant uses `orderOut`; it does not close the Flutter engine or terminate the app.
- Closing a floating assistant hides it and records the preference. Closing a standard window returns to floating mode, then either shows or hides it according to the preference.
- `applicationShouldTerminateAfterLastWindowClosed` remains false. Only Quit INbox and the existing updater termination path terminate the process.

## Scope Boundary

No plugin manifest, loading, marketplace, download, AI, sync, database, Android behavior, or Markdown format changes are included.

## Verification

- Dart tests cover shared capture dispatch and `idle/success/failure` sequences.
- Settings and UI tests cover persisted assistant visibility and the control-center toggle.
- Runner tests cover native feedback parsing/color semantics and assistant visibility persistence helpers.
- Run scoped tests, native Runner tests, `dart analyze`, `flutter test`, and `flutter build macos`.
- Launch the built app for menu-bar, capture, assistant visibility, restart persistence, and quit checks where local UI automation permits.

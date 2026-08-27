# macOS Core / Assistant Decoupling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the macOS menu-bar black dot the stable Core capture entry and the pixel chest an optional Floating Assistant.

**Architecture:** One Dart `CaptureCoordinator` wraps the existing single `CaptureService`; a dedicated Core channel connects native menu actions to Dart and cross-platform feedback states back to macOS. Native code owns only status-item presentation and window visibility.

**Tech Stack:** Flutter/Dart, Swift/AppKit, Flutter MethodChannel, XCTest.

**Spec:** `docs/superpowers/specs/2026-08-27-macos-core-assistant-decoupling-design.md`

## Global Constraints

- Menu-bar code must not read the clipboard, generate capture IDs, format Markdown, or access vault storage.
- Do not change Markdown output or Android behavior.
- Do not implement a plugin framework.
- Preserve unrelated working-tree changes, including the untracked context document.

---

### Task 1: Shared capture coordination

**Files:**
- Create: `app/lib/services/capture_coordinator.dart`
- Create: `app/test/capture_coordinator_test.dart`

**Interfaces:**
- Consumes: `CaptureService.captureNow(String vaultId)` and `CaptureResult`.
- Produces: `CaptureFeedbackStatus { idle, success, failure }` and `CaptureCoordinator.capture(String? vaultId)`.

- [ ] Write tests proving a saved result emits `success, idle`, a non-saved result emits `failure, idle`, a missing vault fails without calling the service, and repeated triggers still use one injected service.
- [ ] Run `flutter test test/capture_coordinator_test.dart` and confirm the tests fail because the API is absent.
- [ ] Implement the minimal coordinator with a cancellable feedback timer and safe thrown-error conversion.
- [ ] Re-run the scoped test and confirm it passes.

### Task 2: Dedicated Core bridge and Assistant-neutral UI

**Files:**
- Create: `app/lib/services/core_bridge.dart`
- Create: `app/test/core_bridge_test.dart`
- Modify: `app/lib/main.dart`
- Modify: `app/lib/ui/capture_pill.dart`
- Modify: `app/test/capture_pill_test.dart`

**Interfaces:**
- Consumes: `CaptureCoordinator.capture`, existing window-opening callbacks.
- Produces: Core channel handlers for `capture`, `openInbox`, `openHistory`, and `openSettings`; outgoing `setCaptureStatus`.

- [ ] Write failing channel tests proving each native action reaches its callback and feedback uses the exact semantic state name.
- [ ] Change `CapturePill` to accept `Future<CaptureResult> Function() onCapture` instead of a service and vault path; update its existing widget tests first and observe the expected compile failure.
- [ ] Implement the bridge and wire one coordinator in `InboxApp` to both bridge and assistant callback.
- [ ] Add direct standard-window reader/settings routing without creating new content UI.
- [ ] Run the new bridge, coordinator, pill, and existing pet tests.

### Task 3: Persisted Floating Assistant visibility

**Files:**
- Modify: `app/lib/services/settings_service.dart`
- Modify: `app/test/settings_service_test.dart`
- Modify: `app/lib/ui/control_center_view.dart`
- Modify: `app/test/control_center_view_test.dart`
- Modify: `app/macos/Runner/MainFlutterWindow.swift`

**Interfaces:**
- Produces: `getAssistantVisible`, `setAssistantVisible(bool)`, and native window show/hide behavior independent from process termination.

- [ ] Write failing SettingsService tests for the two channel methods and a widget test for the control-center toggle.
- [ ] Add the Dart settings methods and minimal control-center switch.
- [ ] Add native persistence and `orderOut`/`makeKeyAndOrderFront` behavior; keep onboarding visible when no valid vault exists.
- [ ] Make floating-window close hide and persist false; make standard-window close restore the saved visibility.
- [ ] Run the scoped Dart tests.

### Task 4: Native menu-bar controller

**Files:**
- Create: `app/macos/Runner/MenuBarController.swift`
- Modify: `app/macos/Runner/AppDelegate.swift`
- Modify: `app/macos/Runner/MainFlutterWindow.swift`
- Modify: `app/macos/Runner.xcodeproj/project.pbxproj`
- Modify: `app/macos/RunnerTests/RunnerTests.swift`

**Interfaces:**
- Consumes: Core channel feedback names and the existing Flutter controller.
- Produces: left-click capture, right-click menu, status colors, assistant toggle, settings/content actions, and quit.

- [ ] Add failing Runner tests for feedback parsing/color mapping and assistant visibility storage semantics.
- [ ] Implement `MenuBarController` with a non-template circle image and the specified menu.
- [ ] Register it from `AppDelegate`; use the dedicated Core channel for capture/content/settings only.
- [ ] Wire assistant menu state through the same persisted visibility used by SettingsService.
- [ ] Add the Swift file to the Runner target and run the native scoped tests.

### Task 5: Full verification and manual acceptance

**Files:**
- Modify only files required to fix failures caused by Tasks 1-4.

- [ ] Run `dart analyze`.
- [ ] Run `flutter test`.
- [ ] Run `flutter build macos`.
- [ ] Run existing scoped macOS Runner tests.
- [ ] Launch the built app and verify the black dot, capture feedback, assistant hide/show, restart persistence, and quit behavior to the extent supported by the local GUI session.
- [ ] Inspect `git diff --check`, `git status --short`, and the final diff; report any unverified manual items honestly.

# Desktop INbox Workbench Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the separate desktop control-center and read-only reader pages with one responsive two-pane workbench.

**Architecture:** `WorkbenchView` owns note selection, active content pane, and sidebar openness. The existing control-center behavior becomes an embeddable settings panel; the workbench reads the same Vault Markdown files and invokes the same callbacks/services. `InboxApp` opens one standard window and preserves its update/pet transitions.

**Tech Stack:** Flutter/Dart, Material 3, `flutter_test`; no new package.

**Spec:** `docs/superpowers/specs/2026-09-19-desktop-workbench-design.md`

## Global Constraints

- Desktop means macOS and Windows; Android, onboarding, pill capture, tray actions, storage format, and update/download logic stay unchanged.
- Show up to 30 daily `.md` files in descending date order; show selectable raw Markdown and no editing field.
- Collapse the sidebar when the workbench's own width is below 600 px, not based on viewport/platform. Initial wide measurement preserves default openness; manual toggles persist until an actual threshold crossing.
- Preserve all existing Vault, display-method, update, and Return to Pet actions. Changing Vault refreshes the note list without moving files.
- Preserve unrelated existing uncommitted changes; stage only files changed by this plan.

## Review Focus

1. Vault with zero notes: right pane shows an explicit empty state, and Settings remains reachable (Task 2 test).
2. A `.md` file becomes unreadable after listing: right pane shows an error instead of crashing (Task 2 test).
3. Width starts narrow and later widens: sidebar is initially folded and docks after a crossing (Task 1 test).
4. A user manually toggles at constant width: rebuilds do not override their choice (Task 1 test).
5. Vault changes while a note is selected: selection is reset to the newest file in the new Vault (Task 3 test).

---

### Task 1: Responsive sidebar shell

**Files:**
- Create: `app/lib/ui/workbench_sidebar.dart`
- Test: `app/test/workbench_sidebar_test.dart`

**Interfaces:**
- Produces: `WorkbenchSidebar({required Widget sidebar, required Widget child, double collapseBelow = 600, double sidebarWidth = 240})`, with a top-bar toggle exposed to `child` through `WorkbenchSidebarScope.of(context)` returning `open`, `toggle()`, and `narrow`.
- Consumes: Flutter `LayoutBuilder` width and Material widgets only.

- [ ] **Step 1: Write failing width and manual-toggle tests.** Use a fixed-size `SizedBox` around the shell; assert the sidebar is docked at 800 px, initially hidden at 500 px, and available through an overlay after `toggle()`. Resize the same widget to 800 px and assert docking. At fixed 800 px, toggle closed and rebuild; assert it stays closed.

```dart
await tester.pumpWidget(harness(width: 500));
expect(find.text('SIDE'), findsNothing);
await tester.tap(find.byKey(const Key('sidebar-toggle')));
await tester.pumpAndSettle();
expect(find.text('SIDE'), findsOneWidget);
await tester.pumpWidget(harness(width: 800));
await tester.pumpAndSettle();
expect(find.text('SIDE'), findsOneWidget);
```

- [ ] **Step 2: Run `flutter test test/workbench_sidebar_test.dart` from `app/`; confirm the missing shell fails.**
- [ ] **Step 3: Implement a stateful shell.** Track `bool? previousNarrow` and `bool open = true`; in a post-frame callback only respond to first narrow measurement or threshold crossings. Render a 240 px docked sidebar when wide/open, otherwise a full-width main pane; when narrow/open, use a dismissible `Stack` overlay. Use an `InheritedWidget` scope for the top-bar toggle.

```dart
if (previousNarrow != narrow) {
  final first = previousNarrow == null;
  previousNarrow = narrow;
  if (!first || narrow) open = !narrow;
}
```

- [ ] **Step 4: Run the focused test and `flutter analyze lib/ui/workbench_sidebar.dart test/workbench_sidebar_test.dart`; fix failures.**
- [ ] **Step 5: Commit only this shell and test with `feat: add responsive workbench sidebar`.**

### Task 2: Read-only note workspace

**Files:**
- Create: `app/lib/ui/workbench_view.dart`
- Create: `app/test/workbench_view_test.dart`
- Modify: `app/lib/ui/workbench_sidebar.dart` if the shell interface needs a small adjustment identified by tests.

**Interfaces:**
- Produces: `WorkbenchView({required String vaultPath, required SettingsService settings, required VaultStorage storage, required DisplayService display, required VoidCallback onCheckUpdates, required VoidCallback onClose, required ValueChanged<String> onVaultPathChanged})`.
- Consumes: `WorkbenchSidebar`, `VaultPaths.captureDir`, and the existing `ControlCenterView` for the Settings pane until Task 3 extracts embeddable content.

- [ ] **Step 1: Write failing tests for newest selection, selecting an older date, zero notes, unreadable selected file, and absence of `TextField`.** Create temporary Vault directories and use `VaultPaths.dailyInboxFile` to write dated Markdown as `note_reader_view_test.dart` does.

```dart
writeNote('2026-08-24', 'older');
writeNote('2026-08-26', 'newest');
await tester.pumpWidget(workbench(vaultPath: tmp.path));
expect(find.text('newest'), findsOneWidget);
await tester.tap(find.text('2026-08-24'));
await tester.pumpAndSettle();
expect(find.text('older'), findsOneWidget);
expect(find.byType(TextField), findsNothing);
```

- [ ] **Step 2: Run `flutter test test/workbench_view_test.dart`; confirm the new view is missing.**
- [ ] **Step 3: Implement the note list and content pane.** Use `Directory(VaultPaths.captureDir(vaultPath)).listSync()` with `.md` filtering, descending path sort, and `.take(30)`. Keep selected `File?` in state. Read on selection with `try/catch`; render `SelectableText` for content and explicit empty/error text otherwise. Add the sidebar footer actions and a top-bar toggle bound to `WorkbenchSidebarScope`. Render the existing `ControlCenterView` for Settings until Task 3 extracts its embeddable content.

```dart
final files = dir.existsSync()
    ? (dir.listSync().whereType<File>().where((f) => f.path.endsWith('.md')).toList()
      ..sort((a, b) => b.path.compareTo(a.path)))
    : <File>[];
return files.take(30).toList();
```

- [ ] **Step 4: Run focused tests and analyzer; fix failures.**
- [ ] **Step 5: Commit only note-workspace files with `feat: add read-only note workbench`.**

### Task 3: Embed settings and preserve actions

**Files:**
- Modify: `app/lib/ui/control_center_view.dart`
- Modify: `app/lib/ui/workbench_view.dart`
- Modify: `app/test/control_center_view_test.dart`
- Modify: `app/test/workbench_view_test.dart`

**Interfaces:**
- Produces: `ControlCenterPanel` with the existing control-center constructor inputs, plus `VoidCallback onOpenContent`; it renders settings content without owning `MaterialApp`/`Scaffold`.
- Consumes: `WorkbenchView` active-pane state and existing `SettingsService`, `VaultStorage`, `DisplayService` calls.

- [ ] **Step 1: Add failing workbench tests.** Tap Settings and assert the Vault path, display choices, folder actions, update action, and View Content are present. Assert View Content returns to the selected note. Change Vault via mocked `pickFolder`; assert callback, refreshed sidebar, and newest note in new Vault. Keep existing `control_center_view_test.dart` coverage for reveal/persistence callbacks.

```dart
await tester.tap(find.text('设置'));
await tester.pumpAndSettle();
expect(find.text('更改存储文件夹'), findsOneWidget);
await tester.tap(find.text('查看内容'));
await tester.pumpAndSettle();
expect(find.text('selected note body'), findsOneWidget);
```

- [ ] **Step 2: Run both focused tests; confirm Settings navigation and Vault refresh fail.**
- [ ] **Step 3: Extract an embeddable `ControlCenterPanel` from `ControlCenterView` while retaining the old public wrapper for existing tests.** Move existing state/service methods with the settings content, but remove the nested page header/footer from the panel as needed. Wire Settings to the panel and View Content back to note mode. On Vault change, update `vaultPath`, relist files, and select the newest note; forward the callback to `InboxApp`.

```dart
void _handleVaultPathChanged(String path) {
  setState(() {
    _vaultPath = path;
    _files = _listFiles(path);
    _selected = _files.isEmpty ? null : _files.first;
  });
  widget.onVaultPathChanged(path);
}
```

- [ ] **Step 4: Run focused tests and analyzer, including the original control-center tests.**
- [ ] **Step 5: Commit only the affected settings/workbench files with `feat: embed desktop settings in workbench`.**

### Task 4: Desktop app transitions and final verification

**Files:**
- Modify: `app/lib/main.dart`
- Modify: `app/lib/ui/window_sizes.dart`
- Modify: `app/test/windows_shell_test.dart`
- Modify: `app/test/workbench_view_test.dart`
- Delete only if no longer referenced after migration: `app/lib/ui/note_reader_view.dart`, `app/test/note_reader_view_test.dart` (otherwise keep them).

**Interfaces:**
- Consumes: `WorkbenchView` constructor from Task 2/3 and current `InboxApp` callbacks.
- Produces: one `_showingWorkbench` desktop state instead of separate control-center/reader transitions; an explicit workbench window size, e.g. 860 x 580.

- [ ] **Step 1: Update shell tests to expect `WorkbenchView` after the pill action, to keep it after Settings/View Content switches, to return there from UpdateView, and to restore the floating pill on close.** Confirm no intermediate resize to the old reader size.

```dart
tester.widget<CapturePill>(find.byType(CapturePill)).onOpenControlCenter();
await settle(tester);
expect(find.byType(WorkbenchView), findsOneWidget);
expect(calls.where((c) => c.method == 'setWindowSize').last.arguments['width'], 860.0);
```

- [ ] **Step 2: Run `flutter test test/windows_shell_test.dart`; confirm old navigation fails the new assertions.**
- [ ] **Step 3: Replace `_showingControlCenter`/`_showingReader` with `_showingWorkbench`, remove reader open/close resize methods, open a standard 860 x 580 window, and render `WorkbenchView`.** Keep `UpdateView` above it in the build order and preserve the original native-close and tray behavior. Remove old reader files only if references/tests can be migrated without losing coverage.

```dart
if (_showingWorkbench && _vaultPath != null) {
  return WorkbenchView(
    vaultPath: _vaultPath!,
    settings: _settings,
    storage: _storage,
    display: _display,
    onVaultPathChanged: (p) => setState(() => _vaultPath = p),
    onCheckUpdates: () => _showUpdates(origin: _UpdateOrigin.controlCenter),
    onClose: _closeWorkbench,
  );
}
```

- [ ] **Step 4: Run `flutter analyze`, all focused tests, and `flutter test` from `app/`. Inspect `git diff --check` and `git status --short`; distinguish pre-existing dirty files from this task.**
- [ ] **Step 5: Commit only files changed for the workbench with `feat: unify desktop control center and reader`. Report test results and any remaining limitations.**

# Desktop INbox Workbench Design

## Intent and scope

Merge the desktop control center and read-only note reader into one workspace. The user wants the feel of the supplied ChatApp shell: a persistent left sidebar, a main content pane, and a sidebar that folds away when the shell itself is too narrow. The reference is a layout and interaction model, not a request for chat, editing, or AI features.

This affects the macOS and Windows standard-window experience entered from the floating capture pill. Android, onboarding, the capture pill, native tray handling, storage format, and update/download logic remain unchanged.

## User experience

- Opening the desktop workspace shows the newest of up to 30 daily Markdown files from the current Vault. The sidebar lists those files in descending date order and highlights the selection.
- The sidebar footer has Settings and Return to Pet actions. The right pane has a top bar with INbox branding, the current note date or Settings title, and a sidebar toggle. The selected note is shown as selectable, unrendered Markdown. No edit field is introduced.
- Settings replaces only the right-pane content. It preserves the existing Vault path display, reveal/change folder actions, display-method selection, update check, version, and View Content action. View Content returns to the selected note.
- Empty content, file-read errors, and folder-change errors remain explicit. Changing Vault refreshes the note list and selection for the new location without moving old files.
- A standard window opens large enough to show both panes. At shell width below 600 px, the sidebar is off-canvas and can be opened from the top bar. At or above 600 px it is docked. Initial narrow measurement folds it; initial wide measurement respects the default-open state. Only actual threshold crossings automatically change openness, so manual toggles persist while width remains on one side of the threshold.

## Structure and state

Introduce one desktop `WorkbenchView` as the standard-window page. It owns `selectedFile`, active pane (`note` or `settings`), the current file list, and sidebar open state. A small sidebar-shell widget uses `LayoutBuilder` to measure its own available width rather than the whole screen. The sidebar and right pane share the same selection state; only the right pane changes for Settings.

Extract the existing read-only note body and settings controls into focused widgets or adapt their current views for composition. Preserve their service calls and callbacks. `InboxApp` opens the workbench directly from the pill, instead of navigating control center -> reader and resizing between them. UpdateView can still temporarily replace the workbench and returns to it afterward. The native close handler still returns to the floating pill.

The desktop window target is increased from the current 480 x 360 control center / 640 x 480 reader sizes to a workbench-sized standard window. Resizing below 600 px is handled within Flutter even if the user manually narrows the native window. Avoid moving or rewriting Vault data.

## Testing and acceptance

- Widget tests cover newest-note selection, sidebar selection, Settings/View Content navigation, empty and read-error states, and a read-only body.
- Width tests cover initial wide/narrow layouts, threshold crossings, and manual toggle persistence at a fixed width.
- Existing control-center service behavior remains covered: reveal/change folder, display-method persistence, update callback, and Return to Pet.
- Desktop shell tests verify opening the workbench from the pill, returning from update, and closing to the pill on Windows and macOS where testable.
- Run Flutter analyze and relevant widget tests, then the full Flutter test suite. Preserve unrelated existing worktree changes.

## Out of scope

Chat input, AI, Markdown editing/rendering, search, note deletion, content management, Android redesign, and changes to the capture/storage model.

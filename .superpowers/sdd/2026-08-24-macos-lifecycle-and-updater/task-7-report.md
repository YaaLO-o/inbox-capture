# Task 7 Report: Prepare and Verify Version 1.1.1

## Status

Local release preparation is complete. Version `1.1.1+2` is configured, release-script checks are enforced, the full local gate exits 0, and both Universal DMGs were built and inspected. No push, tag, GitHub Release mutation, asset upload, or `/Applications` install was performed.

The native `getAppVersion` method backed by `CFBundleShortVersionString` and its Dart consumer `SettingsService.getAppVersion()` were already present in committed Task 4 code. Task 7 retained those interfaces and re-verified their tests instead of duplicating or changing them.

## Implementation

- Set `app/pubspec.yaml` to `version: 1.1.1+2`.
- Made `scripts/release_macos.sh` require exactly one non-empty version argument.
- Passed `--build-name "$VERSION" --build-number 2` to the release build.
- Stopped before DMG creation unless `CFBundleShortVersionString` equals the requested version.
- Stopped before DMG creation unless `lipo -archs` contains both `arm64` and `x86_64`.
- Preserved both versioned and fixed-name DMG outputs.
- Added isolated shell behavior tests under a temporary repository fixture. The tests never touch the real build or `dist/` trees.
- Updated public installation, update, privacy, lifecycle, recovery, and exact install-path instructions.
- Updated `PROJECT_STATE.md` with the current interfaces, 85-test count, local gate, artifact evidence, publication boundary, and remaining manual checks.

## RED Evidence

Command:

```bash
sh scripts/tests/release_macos_test.sh
```

Result before implementation was exit 1 with four expected behavior failures:

```text
FAIL: release script should fail without an explicit version
not ok - test_requires_explicit_version_argument
FAIL: flutter build should receive release metadata
not ok - test_passes_release_metadata_to_flutter_build
FAIL: release script should reject a mismatched bundle version
not ok - test_rejects_bundle_version_mismatch
FAIL: release script should reject a non-universal binary
not ok - test_rejects_missing_intel_architecture
release_macos_test.sh: 4 failure(s)
```

The production changes that make these tests fail under mutation are the default version fallback, omitted Flutter build metadata, omitted bundle comparison, and omitted architecture guard.

## GREEN Evidence

Command:

```bash
sh scripts/tests/release_macos_test.sh
```

Result was exit 0:

```text
ok - test_requires_explicit_version_argument
ok - test_passes_release_metadata_to_flutter_build
ok - test_rejects_bundle_version_mismatch
ok - test_rejects_missing_intel_architecture
release_macos_test.sh: all tests passed
```

Existing authoritative-version and update-comparison tests were also run directly:

```bash
cd app
flutter test test/update_view_test.dart test/settings_service_test.dart
```

Result was exit 0 with 10 tests passed. The coverage includes native `getAppVersion`, remote `1.1.1` rendering the current state, and remote `1.1.2` rendering an available update for current `1.1.1`.

## Full Local Gate

All commands ran from `/Users/mac/Desktop/ai/个人/INbox/.worktrees/macos-lifecycle-updater` or its `app/` child, preserving the real non-ASCII path.

1. `cd app && flutter pub get`
   - Exit 0, dependencies resolved.
   - Two dependency update notices were informational and outside the locked constraints.
2. `cd app && dart analyze lib test`
   - Exit 0, `No issues found!`
3. `cd app && flutter test`
   - Exit 0, 85/85 passed.
4. `cd app && xcodebuild test -workspace macos/Runner.xcworkspace -scheme Runner -destination 'platform=macOS'`
   - Exit 0, `** TEST SUCCEEDED **`, 5/5 Runner tests passed.
   - Existing linker warnings note XCTest libraries built for macOS 14 while the test target is macOS 12.
5. `sh -n scripts/install.sh scripts/release_macos.sh app/macos/Runner/Resources/replace_macos_app.sh`
   - Exit 0 with no output.
6. `sh scripts/tests/replace_macos_app_test.sh`
   - Exit 0, all tests passed.
7. `sh scripts/tests/install_sh_test.sh`
   - Exit 0, 7/7 passed.
8. `sh scripts/tests/release_macos_test.sh`
   - Exit 0, 4/4 passed.
9. `sh scripts/release_macos.sh 1.1.1`
   - Exit 0.
   - Flutter reported `Built build/macos/Build/Products/Release/INbox.app (40.2MB)`.
   - Release script reported `Arch: x86_64 arm64`.

## Fresh Artifact Inspection

Files produced:

- `dist/INbox-1.1.1-macos-universal.dmg`
- `dist/INbox-macos-universal.dmg`

Evidence from `PlistBuddy`, `lipo`, `file`, `shasum`, `stat`, `du`, `cmp`, and `hdiutil verify`:

```text
CFBundleShortVersionString  1.1.1
CFBundleVersion             2
Architectures               x86_64 arm64
Versioned DMG size          17682577 bytes (17M)
Fixed-name DMG size         17682577 bytes (17M)
SHA-256, both DMGs          2e5189e7c894c404725ddcc1c32a8fbef11795be43ffdecde4ab2e9c7ce13425
cmp                         byte-identical
hdiutil verify              VALID
```

The exact DMG size is recorded without an artificial shrink target.

## Manual Acceptance

The build-tree app was launched with Computer Use. It was not copied to `/Applications`.

| Acceptance item | Result |
| --- | --- |
| Pointer-accurate drag | Partial. A visible pet drag was exercised without triggering capture. Exact absolute screen-delta behavior is covered by passing Flutter and Runner tests, but the Computer Use capture does not expose post-drag window coordinates. |
| Visible traffic lights | Pass. The build-tree window visibly showed red, yellow, and green controls; the accessibility tree exposed close, minimize, and zoom buttons. |
| Red-close plus menu reopen | Partial. Computer Use clicked the real red close button; a separate host-window capture no longer showed the floating INbox window while exact Release PID `20042` remained alive. Computer Use could not expose or reliably select the NSStatusItem, so the exact `显示 INbox` action remains an unresolved manual risk. |
| Complete quit | Manual gap. Computer Use could not expose or reliably select the NSStatusItem, so the exact `完全退出` action remains unresolved. Command-Q was used only to clean up the isolated test process; a subsequent exact-path `pgrep` returned no match. |
| Current-version update UI | Automated pass, manual gap. Widget tests prove current `1.1.1` plus remote `1.1.1` is current and remote `1.1.2` is newer. No public 1.1.1 Release was created, so a deterministic live equal-version UI check was not performed. |
| Offline safety | Automated pass, unresolved live risk. Update error UI, failed checksum retention, installer failure, and rollback fixtures pass. A live check would require disconnecting or intercepting the user's network, so no system-wide network state was changed. |
| Exact installed launch path | Automated pass, manual gap. Path and open-command fixtures require `/Applications/INbox.app`; no installed app exists and the task forbids installing over `/Applications`. |
| Rollback behavior | Automated pass, manual gap. Both replacement test suites cover failed replacement and restoration. A real `/Applications` failure was intentionally not induced. |

## Files

- Modified `.github/DOWNLOAD.md`
- Modified `PROJECT_STATE.md`
- Modified `README.md`
- Modified `app/pubspec.yaml`
- Modified `scripts/release_macos.sh`
- Added `scripts/tests/release_macos_test.sh`
- Added `.superpowers/sdd/2026-08-24-macos-lifecycle-and-updater/task-7-report.md`

No Task 7 production edit was needed in `app/lib/ui/update_view.dart` or `app/macos/Runner/AppDelegate.swift`; the required authoritative-version flow was already committed and freshly verified.

## Self-Review

- Confirmed every production line changed maps to version metadata, release checks, or required documentation.
- Confirmed the new script test fixture copies the release script and creates the fake app and DMGs only under a guarded `mktemp` root.
- Confirmed bundle-version and architecture checks execute before codesign, staging cleanup, DMG removal, or DMG creation.
- Confirmed the release command keeps both public asset names.
- Confirmed `crypto` remains at `^3.0.7` and update/install interfaces are unchanged.
- Confirmed no process remains from the build-tree manual check.
- Confirmed no `/Applications/INbox.app` exists and no install command targeted `/Applications`.
- Confirmed no network publication or GitHub mutation command was run.

## Concerns

- The exact status-menu `显示 INbox` and `完全退出` actions remain an unresolved release risk because Computer Use does not expose the app's NSStatusItem.
- Live offline behavior remains an unresolved release risk because testing it would require disconnecting or intercepting the user's network. No system-wide network state was changed.
- Real installed-path and rollback acceptance remain open because this task forbids installing over `/Applications`.
- `xcodebuild` passes but retains the pre-existing XCTest deployment-target linker warnings described above.
- The final quiet `xcodebuild` rerun also reported stale Flutter framework files under another DerivedData directory as outside allowed roots. The command still exited 0 and all five tests passed; no repository or release artifact path was implicated.
- Apple Developer ID signing and notarization remain outside this local release preparation.

## Commits

- `d3c858c` `chore: prepare INbox 1.1.1` completed the tracked Task 7 release preparation.

## Fix Round 1

### Findings addressed

- Scoped the Gatekeeper paragraph in `.github/DOWNLOAD.md` to local capture and storage, with the explicit GitHub contact exception for user-triggered update actions.
- Repeated feasible lifecycle acceptance against the exact worktree Release app path without installing or replacing `/Applications/INbox.app`.
- Corrected the manual-acceptance table and concerns so status-menu limits and offline limits are not attributed to publication restrictions.

### Exact manual evidence

The app target was:

```text
/Users/mac/Desktop/ai/个人/INbox/.worktrees/macos-lifecycle-updater/app/build/macos/Build/Products/Release/INbox.app
```

- Before launch, exact-path `pgrep` returned no Release process.
- Computer Use launched the full path; exact-path `pgrep` reported PID `20042` with the matching `Contents/MacOS/INbox` path.
- Computer Use clicked the native red close button. A separate host-window capture showed no floating INbox window, while exact-path `pgrep` still reported PID `20042`. This verifies red close hid the window without terminating the process.
- Computer Use did not expose the NSStatusItem in the app accessibility tree. Direct `SystemUIServer` inspection timed out, and keyboard status-menu focus could not identify the item reliably. No unidentified menu item was intentionally selected. The exact `显示 INbox` and `完全退出` clicks remain unresolved release risks.
- Computer Use sent Command-Q only to the exact worktree Release app to clean up. Exact-path `pgrep` then returned no match.
- `/Applications/INbox.app` remained absent throughout.
- Live offline behavior remains unresolved because a truthful test would require disconnecting or intercepting the user's network. No network setting was changed.

### Focused verification

```bash
rg -n '完全在本地运行|不联网|采集和本地存储|检查更新|联系 GitHub' .github/DOWNLOAD.md README.md
rg -n 'd3c858c|Red-close plus menu reopen|Complete quit|Offline safety|unresolved release risk|Fix Round 1' .superpowers/sdd/2026-08-24-macos-lifecycle-and-updater/task-7-report.md
sh -n scripts/release_macos.sh
git diff --check
```

All four commands exited 0. The first scan found no remaining claim that the whole application never connects to the network; every network statement is scoped to local capture/storage or includes the explicit update exception. The report scan found completed commit `d3c858c` and the corrected acceptance risks, with no future-tense commit marker.

Final process and install-path check:

```text
exact isolated Release process is absent
/Applications/INbox.app remains absent
```

### Self-review

- No application code, release script, artifact, `/Applications` path, or system network setting was changed in this fix round.
- The public privacy wording now matches the explicit update behavior documented later on the same page.
- Manual results distinguish verified red-close behavior, automated lifecycle coverage, and unresolved status-menu and live-offline risks.

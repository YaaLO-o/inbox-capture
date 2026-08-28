# MAC_CORE_REFACTOR_CONTEXT

只读审计，2026-08-27。为 macOS Core / Assistant 解耦准备的最小上下文。
仓库为 Flutter 桌面应用，主工程在 `app/`；macOS 原生层在 `app/macos/Runner/`。
当前**不存在任何 NSStatusItem / 菜单栏图标**（grep 全仓确认），"常驻入口"角色由悬浮窗承担。

## Relevant Files

### macOS 原生（Swift）
- `app/macos/Runner/AppDelegate.swift` — `FlutterAppDelegate`。`applicationShouldTerminateAfterLastWindowClosed` → `false`（关窗不退出）；`applicationShouldHandleReopen` → 重新显示窗口。内含两个 MethodChannel：
  - `ClipboardChannel`（`com.inbox.app/clipboard`，`readClipboard`，读 NSPasteboard 文字/图片/Finder 文件）。
  - `SettingsChannel`（`com.inbox.app/settings`）：vaultPath / displayMethod 持久化（UserDefaults）、`pickFolder`、`revealPath`/`openPath`/`openExternalUrl`、`setWindowMode`(standard|floating)、`setWindowSize`、`moveWindowBy`、`begin/update/endWindowDrag`、`showWindow`、`getAppVersion`、`installUpdate`、`quit`（→`NSApp.terminate`）。
- `app/macos/Runner/MainFlutterWindow.swift` — 应用**唯一窗口**（xib 加载）。`applyFloatingWindowStyle()`：132×132、右上角、透明、`.floating` 层级、`canJoinAllSpaces`、`NSApp.setActivationPolicy(.accessory)`。`applyStandardWindowStyle()`：带标题栏红叉的普通窗口（控制中心/阅读器）。`windowShouldClose`：standard 模式 → 切回 floating 并经 channel 调 Dart `mainWindowDidClose`，返回 false；floating 模式 → 返回 true（窗口真关闭，App 因 delegate 配置不退出，但**此时无任何可见 UI**）。
- `app/macos/Runner/Info.plist` — `LSUIElement=true`（无 Dock 图标）。
- `app/macos/Runner/Base.lproj/MainMenu.xib` — 标准 Flutter 主菜单；挂 AppDelegate 与 MainFlutterWindow。
- `app/macos/Runner/UpdateInstaller.swift` — DMG 更新安装，成功后 `NSApp.terminate`。
- `app/macos/RunnerTests/RunnerTests.swift` — 仅 4 个原生测试（拖动换算、更新路径、hdiutil plist 解析、helper 环境变量）；**不覆盖 AppDelegate / 窗口样式 / channel**。

### Dart 服务（平台共享，Android 也用 CaptureService）
- `app/lib/services/capture_service.dart` — `CaptureService.captureNow(vaultId)` / `captureInput(...)`：剪贴板读取 → 串行队列落盘附件 → 原子 append Markdown，500ms 防抖，失败回滚。返回 `CaptureResult(CaptureStatus{saved, empty, vaultUnavailable, permissionDenied, error})`。**无 UI 依赖。**
- `app/lib/services/clipboard_service.dart` — `ClipboardReader` 接口 + `ClipboardService`（走 clipboard channel）。
- `app/lib/services/vault_storage.dart` — `VaultStorage` 接口、`VaultStorageException`、`AttachmentSource`（即"StorageService"抽象）。
- `app/lib/services/desktop_file_vault_storage.dart` — 桌面文件实现（capture 目录、attachments、`YYYY-MM-DD.md` append）。
- `app/lib/services/settings_service.dart` — settings channel 的 Dart 封装，含 `setWindowMode/setWindowSize/showWindow/quit`、`setMainWindowClosedHandler`（唯一的原生→Dart 回调）。
- `app/lib/services/display_service.dart` — 笔记展示方式 inbox/system/obsidian。
- `app/lib/services/markdown_formatter.dart` — Markdown 格式（禁改）。

### Dart UI / 应用装配
- `app/lib/main.dart` — `InboxApp`（StatefulWidget）**持有全部服务实例**（settings/capture/storage/display/updates），并按状态切换视图：loading → `OnboardingView` / `CapturePill` / `ControlCenterView` / `NoteReaderView` / `UpdateView`。`_openControlCenter/_closeControlCenter` 调 `setWindowMode`；`_onNativeWindowClosed` 复位视图状态。macOS 入口为 `runApp(InboxApp())`；Android 分支复用同一 `CaptureService.captureInput`。
- `app/lib/ui/capture_pill.dart` — 悬浮窗内容 = 宝箱怪 + 右键菜单。**macOS 上唯一的 Capture 触发点**：`onTap → widget.capture.captureNow(vaultPath)`（result 不被本 widget 使用，反馈在宠物内部消费）。菜单 4 项：控制中心 / 更改存储文件夹 / 检查更新 / 退出（`_settings.quit()`）。自带 `static final SettingsService` 实例（与 InboxApp 的实例不同，当前无状态所以无害）。菜单展开时调 `setWindowSize` 增高窗口。
- `app/lib/ui/pet/pixel_chest_pet.dart` — 宝箱怪 widget。**Capture 结果反馈（成功/失败视觉）目前只存在这里**：`_capture()` 把 `CaptureResult.status` 映射为 success/error/empty 动画 + 文字反馈。
- `app/lib/ui/pet/pet_popup_menu.dart` — 右键菜单（替代系统菜单的动作入口）。
- `app/lib/ui/pet/pet_animation_manifest.dart`、`pixel_chest_sprite.dart`、`app/assets/pet/pixel_chest_atlas.png` — 宠物视觉资源。
- `app/lib/ui/control_center_view.dart` — 控制中心（存储位置、展示方式、查看内容、检查更新、"返回桌宠"）。
- `app/lib/ui/note_reader_view.dart` — 内置只读阅读器，左侧列出最近每日笔记（当前最接近 "Inbox/History" 的功能）。
- `app/lib/ui/onboarding_view.dart` — 首启选文件夹，会调 `setWindowSize`。
- `app/lib/ui/window_sizes.dart`（pill 132² / onboarding 420×300 / controlCenter 480×360 / reader 640×480）、`window_surface.dart`（透明色）。

## Current Call Flow

- **Capture（macOS）**：用户点宝箱怪 → `PixelChestPet._capture` → `CapturePill` 注入的 `capture.captureNow(vaultPath)` → `ClipboardService.read` → channel → `ClipboardChannel.readClipboard`（NSPasteboard）→ 回到 `CaptureService` → `DesktopFileVaultStorage.ensureLayout/importAttachment/appendMarkdown`（写入 vaultPath 下目录与当日 md）→ `CaptureResult` → `PixelChestPet` 按 status 播放动画/反馈。
- **打开控制中心**：右键宠物 → `PetPopupMenu`「控制中心」→ `main._openControlCenter` → `setWindowSize(480×360)` + `setWindowMode('standard')` → `MainFlutterWindow.applyStandardWindowStyle` → 显示 `ControlCenterView`。红叉（`windowShouldClose`）或「返回桌宠」→ floating 样式 + `mainWindowDidClose` → Dart 复位。
- **退出**：宠物右键菜单「退出 INbox」→ `SettingsService.quit` → settings channel `quit` → `NSApp.terminate`。更新安装成功后同路径 terminate。
- **启动**：xib → `MainFlutterWindow.awakeFromNib`（floating 样式、注册两个 channel、按 vaultPath 是否有效决定 132² 或 420×300）→ Flutter `main()` → `InboxApp.initState` 建服务 → `_boot()` 校验 vaultPath → Onboarding 或 CapturePill。
- **关窗后恢复**：floating 窗口被关闭后 App 仍存活但无 UI；再次打开 App（Finder/Spotlight）→ `applicationShouldHandleReopen` → `makeKeyAndOrderFront`。

## Current Coupling

1. **App 唯一窗口就是宝箱怪窗口**：floating 模式内容恒为 `CapturePill`/`PixelChestPet`；不存在"宠物隐藏但 Core 运行"的状态。
2. **菜单栏常驻入口角色由悬浮窗承担**：`.accessory` 激活策略、无 Dock 图标、无 NSStatusItem；宠物窗口 = 事实上的 tray。
3. **Capture 触发与结果反馈都绑在宠物上**：macOS 仅 `PixelChestPet` 点击区调用 `captureNow`；成功/失败的视觉表达（动画状态机）也在该 widget 内，服务层之外没有第二处反馈。
4. **应用动作挂在宠物右键菜单**（PetPopupMenu：控制中心/改 vault/更新/退出），而非系统菜单栏。
5. **窗口尺寸与宠物 UI 绑定**：`WindowSizes.pill*`、菜单展开增高逻辑在 `CapturePill._syncWindowSize`；Swift 端 `isStandardMode` 与 Dart 端 `_showingControlCenter/_showingReader/_showingUpdate` 双份状态靠 channel 消息同步。
6. **"关闭标准窗口 = 回到桌宠"** 写死在 `windowShouldClose` + `_onNativeWindowClosed`；控制中心退出路径文案就是"返回桌宠"。
7. **vaultPath 与服务实例保存在 `InboxApp` State 中**，没有独立于 widget 树的 core 控制器；菜单动作要触发 capture/开窗，必须经过该 State 的方法。

## Likely Change Points

仅文件级指引，不含架构设计：

- **菜单栏黑点（新增 NSStatusItem）**：`app/macos/Runner/AppDelegate.swift`（或新增 Swift 文件，由 AppDelegate/window 持有 status item）。`LSUIElement=true` 与 accessory 策略下 status item 可正常显示，无需改 Info.plist 方向（未确认细节）。
- **菜单动作 Capture / Inbox / History / Settings / Quit**：Swift 菜单 → Dart 需要原生→Dart 调用；Dart 汇合点是 `app/lib/main.dart` 的 `_InboxAppState`（持有 `_capture`、视图切换方法）。Quit 已有 `quit` channel 可复用。
- **Capture 成功绿 / 失败红**：`CaptureStatus` 已在 `capture_service.dart`（禁改服务，只需消费其结果）；需要把 Dart 侧 capture 结果回传 Swift（新 channel 方法或新通道）驱动 `NSStatusItem.button` 颜色。两处触发必须调同一个 `CaptureService` 实例（`main.dart` 中的 `_capture`），串行队列/防抖即天然共享。
- **隐藏/显示 Assistant（宝箱怪）**：窗口显隐目前只有 `setWindowMode` + `showWindow`；"隐藏宠物窗口但 Core 存活"需要新的可见性控制（`MainFlutterWindow.swift` 的 orderOut/makeKeyAndOrderFront + `SettingsChannel`/`SettingsService` 新增方法）。Dart 侧"不渲染宠物"对应 `main.dart` 视图分支。
- **App 不因 Assistant 关闭而退出**：`applicationShouldTerminateAfterLastWindowClosed` 已为 false；但 floating 模式 `windowShouldClose` 返回 true 会造成无 UI 僵尸态（见 Risks），status item 落地前不要把"关窗"当作"后台运行"。
- **History / Inbox 菜单**：现有可复用入口为 `NoteReaderView`（最近笔记列表）与控制中心"查看内容"路径。**Assistants 概念在代码中不存在**（未确认产品定义）。

## Existing Tests

- Flutter：`cd app && flutter test`（2026-08-27 审计实跑 **144/144 通过**；PROJECT_STATE 中 126 为旧记录）。相关文件：
  - 服务：`test/capture_service_test.dart`、`clipboard_service_test.dart`、`settings_service_test.dart`、`display_service_test.dart`、`desktop_file_vault_storage_test.dart`、`markdown_formatter_test.dart`。
  - UI：`test/capture_pill_test.dart`（pill+菜单，mock settings channel）、`pixel_chest_pet_test.dart`（点击/拖拽/右键/成功失败反馈/reduced-motion）、`pixel_chest_sprite_test.dart`、`pet_animation_manifest_test.dart`、`control_center_view_test.dart`、`onboarding_view_test.dart`、`note_reader_view_test.dart`、`window_surface_test.dart`、`update_view_test.dart` 等；golden 在 `test/goldens/`。
- 原生：`cd app && xcodebuild test -workspace macos/Runner.xcworkspace -scheme Runner -destination 'platform=macOS'`（RunnerTests，4 项；不覆盖 AppDelegate/channel/窗口样式）。
- 静态检查：`cd app && dart analyze lib test`。
- 脚本测试：`scripts/tests/install_sh_test.sh`、`release_macos_test.sh`、`replace_macos_app_test.sh`。
- CI：仅 `.github/workflows/windows-build.yml`（Windows 上跑 analyze + flutter test）；**无 macOS CI**。

## Risks

1. **菜单栏能力从零新增**：Swift 侧无任何 status item 代码；channel、菜单回调、状态色同步均为新代码，且 RunnerTests 不覆盖原生层，回归只能靠手动验收。
2. **单窗口 + 单 Flutter 引擎**：隐藏宠物窗口（orderOut）后 Dart 侧 capture/channel/timer 是否照常工作未确认（理论上引擎不随窗口停止，但无验证）。
3. **floating 关窗 = 无 UI 僵尸态**：窗口关闭后无 Dock 图标、无 status item，只能靠 reopen 恢复；解耦前用户可能误关宠物导致"应用消失"。
4. **原生→Dart 通道 handler 占用**：settings channel 当前只有一个 Dart handler（`settings_service.dart` 注释明确说明 MethodChannel 仅支持一个入向 handler）。新增菜单回调需么在该 handler 内分发，要么开新 channel，否则会顶掉 `mainWindowDidClose`。
5. **窗口状态双端同步**：`isStandardMode`（Swift）与 `_showing*`（Dart）靠消息同步；新增"assistant 隐藏"是第三种可见性状态，不同步会出现窗口在/内容错或点不到的情况。
6. **Capture 反馈逻辑在宠物 widget 内**：`PixelChestPet` 的动画/反馈与 capture 调用交织；菜单黑点需要同一份 `CaptureResult`，注意不要复制一套 capture 调用（会绕开服务内防抖与串行队列）。
7. **共享服务影响 Android**：`CaptureService`/`VaultStorage`/Markdown 格式为 Android 与桌面共享（`main.dart` Android 分支、`android_capture_dispatcher.dart`），签名或行为变动会波及 Android；本轮禁改这些文件。
8. **`CapturePill` 自建 static `SettingsService`**：与 `InboxApp` 持有的不是同一实例；当前服务无状态无害，但新增有状态逻辑（如回调注册）时会漏接。
9. **floating 窗口关闭不通知 Dart**：`mainWindowDidClose` 只在 standard→floating 时发送；真正关窗时 Dart 无感知，视图状态可能停留在宠物态。
10. **产品菜单项与现有功能不对齐**：Assistants 无代码；Inbox/History 仅有只读阅读器可对应；具体映射未确认。

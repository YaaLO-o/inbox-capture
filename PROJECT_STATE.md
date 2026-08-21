# Project State

## 产品定位

个人兴趣与知识采集 Inbox。当在小红书、微博、抖音、网页、购物平台等处看到以后想看的书、电影、商品、店铺、文章、观点或图片时，用一个极低摩擦的动作（复制 → 点击 Mac 桌面悬浮入口）直接保存到自己的 Obsidian Vault，而不再依赖各平台自己的收藏夹。

## 长期目标

产品逻辑：Capture → Understand → Organize。

- 当前只做 **Capture**，不做任何 AI 分类/摘要/整理。
- 目标平台：macOS（当前）、Windows、Android、iOS（未来）。用 Flutter 保持跨平台可能，macOS 特殊系统能力用原生 Swift + Platform Channel 补足。

## 当前阶段

Mac V0.1 Capture MVP。

## 当前架构

技术栈：Flutter 3.47.1 / Dart 3.13.1，macOS 原生 Swift。工程位于 `app/`。

- Flutter macOS 模板通过 **Swift Package Manager (SPM)** 集成 FlutterMacOS 引擎，不是 CocoaPods。
- V0.1 只使用原生 MethodChannel，**未引入任何需要 CocoaPods 的三方 Flutter 插件**，因此本版本构建/运行不依赖 CocoaPods。
- 分层：
  - `lib/main.dart`：应用启动、加载 Vault 设置、在引导页与悬浮胶囊间切换、调整窗口尺寸。
  - `lib/services/clipboard_service.dart`：剪贴板抽象 `ClipboardReader` + 原生通道实现，返回文字/图片字节/本地文件路径。
  - `lib/services/storage_service.dart`：唯一存储层。建目录、每日 Inbox 追加（同步写、只追加不覆盖）、附件写入/复制。
  - `lib/services/capture_service.dart`：Capture 编排。读剪贴板 → 生成 Capture ID → 落盘附件 → 追加 Markdown；含 500ms 防抖；异常不外抛。
  - `lib/services/settings_service.dart`：Vault 路径持久化（UserDefaults）、原生选目录、窗口尺寸、退出。
  - `lib/models/capture.dart`：Capture / Attachment 轻量数据模型。
  - `lib/util/id_gen.dart`：Capture ID `YYYYMMDD-HHMMSS-XXXX`。
  - `lib/util/path_utils.dart`：Vault 内固定目录与 Obsidian 引用路径。
  - `lib/ui/onboarding_view.dart`：首次启动选择 Vault。
  - `lib/ui/capture_pill.dart`：悬浮胶囊按钮，点击采集，轻量反馈后自动消失；右键菜单可重选 Vault / 退出。
  - `macos/Runner/AppDelegate.swift`：两个 MethodChannel——剪贴板（文字、原始格式图片 PNG/JPEG/GIF/TIFF/WebP、Finder 文件 URL）、设置（UserDefaults、NSOpenPanel 选目录、窗口尺寸、退出）。
  - `macos/Runner/MainFlutterWindow.swift`：配置小型、可拖拽、置顶、跨空间的悬浮窗口；`NSApp.setActivationPolicy(.accessory)` 隐藏 Dock 图标。

数据流：复制内容 → 点击胶囊 → `ClipboardService` 经 MethodChannel 读 NSPasteboard → `CaptureService` 生成 Capture 并调用 `StorageService` → 附件落 `素材/attachments/`、Markdown 追加到 `素材/Inbox/YYYY-MM-DD.md` → UI 显示「✓ 已保存」并自动消失。

## Obsidian 数据结构

所有内容都是普通 Markdown 与普通文件，直接存于用户选择的 Obsidian Vault。无数据库、无 Base64、无媒体数据库。

```
<Vault>/
└── 素材/
    ├── Inbox/
    │   ├── 2026-08-21.md
    │   └── ...
    └── attachments/
        ├── 20260821-103215-a82f.png
        └── ...
```

每条 Capture 格式：

```markdown
## 10:32:15

<!-- capture:id=20260821-103215-a82f -->

内容文字 / 或 ![[../attachments/xxxx.png]]

---
```

- 每天一个 Inbox 文件，首行 `# YYYY-MM-DD`，只追加，绝不覆盖。
- 附件保留原始格式（PNG/JPEG/GIF/PDF/MP4/MOV…）；只有剪贴板仅提供原始 bitmap 时才回退落为 PNG。
- 图片/PDF/视频在 Markdown 中统一用 Obsidian embed `![[../attachments/<文件名>]]`，由扩展名决定渲染。

## 已实现

- 文字 Capture：读剪贴板、trim、空内容不保存、写入当天 Inbox、含创建时间与唯一 ID。
- 连续追加保存：多次点击全部追加、不覆盖、顺序正确、每条独立 ID。
- 图片 Capture：读取剪贴板图片（尽量保留原始格式），写入 `素材/attachments/`，Inbox 写入内嵌引用。
- Finder 复制的本地文件：复制进 `素材/attachments/`（顺带支持，不阻塞 V0.1），Markdown 写入内嵌引用；源文件保留。
- 首次启动弹出原生目录选择器选择 Obsidian Vault；路径写入 UserDefaults，重启后自动读取、不再询问。
- 自动创建 `素材/`、`素材/Inbox/`、`素材/attachments/`。
- 悬浮入口：小窗口、可拖拽、置顶、跨桌面空间、不长期遮挡；点击即采集；成功显示「✓ 已保存」约 1.4 秒后自动消失；失败显示「保存失败」；空剪贴板显示提示；不崩溃。
- 重复快速点击防抖（500ms 内忽略）。
- 右键菜单：重新选择 Vault、退出。
- 单元测试 7 项全绿（ID 格式、文字、连续 10 条、图片、本地文件、空剪贴板、文字+图片混合）。
- `dart analyze lib test`：No issues found。
- `flutter build macos --debug`：构建成功，产出 `app/build/macos/Build/Products/Debug/inbox_app.app`，并已实际启动验证进程稳定运行不崩溃。

## 当前问题

- App Sandbox 在 V0.1 被关闭（`com.apple.security.app-sandbox = false`）。原因：sandbox 下写入用户任意选择的 Vault 目录并在重启后继续写入，需要持久化 security-scoped bookmark，超出本版范围。未来若要上架/沙箱分发需补上。
- 因 LSUIElement/accessory 模式，应用不在 Dock 显示图标、无标准主菜单；退出通过胶囊右键菜单。
- 自动化的真实点击/截图在当前终端缺少「辅助功能/屏幕录制」权限，未能用脚本完成端到端点击；已用单元测试覆盖数据路径，原生代码已通过真实编译。**剩余的人工验证：在 Obsidian 中确认图片 embed 能正常显示（测试 3）。**
- 网络视频/小红书/抖音等「复制」得到的是 URL 或分享文本，按普通文字保存；不做任何网络下载或解析。
- `flutter analyze`（analysis server）在本机偶发进程崩溃（exit 255，分析器自身问题）；改用 `dart analyze` 结果为干净。

## 已确认决策

- Capture 阶段不分类、不摘要、不打标签（书/电影/商品/店铺/文章等属于未来 AI Understand）。
- Raw Inbox 是 source of truth；未来 AI 整理结果是 derived data，默认不删除原始 Inbox。
- Obsidian 是唯一存储层；不建数据库、不建应用自己的媒体库。
- 媒体采用 Obsidian attachment 模型：附件作为普通文件存放，Markdown 只保存引用。
- 网络视频暂不自动下载；URL/分享文本按文字 Capture 保存。
- 工程放在 `app/` 子目录，避免污染 Vault 根目录。
- V0.1 关闭 App Sandbox 以换取对任意 Vault 目录的直接读写与重启后可写。
- 本版本不依赖 CocoaPods（SPM 集成引擎 + 原生 MethodChannel，零三方插件）。

## 如何运行 / 测试

前置：Flutter 3.47.1、Xcode（命令行可 `flutter doctor` 确认）。无需 CocoaPods。

```bash
cd app
flutter pub get
flutter analyze            # 或 dart analyze lib test
flutter test               # 7 项单元测试
flutter run -d macos       # 启动悬浮应用
# 发布/调试构建：
flutter build macos --debug
```

首次启动会弹出目录选择器，选择你的 Obsidian Vault 根目录即可；之后重启自动记住。

## 下一步

- 人工在真实 Obsidian Vault 中验证：文字、连续保存、图片内嵌显示、重启记忆、空剪贴板/无权限/快速点击等异常场景。
- 评估是否需要安全-scoped bookmark 以重新启用 App Sandbox（为未来分发准备）。
- 打磨悬浮窗口的视觉细节与拖拽/定位记忆（当前不阻塞 V0.1 验收）。
- Capture 阶段之后再规划 Understand / Organize（AI 整理），当前不实现。

## 最近更新

日期：2026-08-21

本轮完成：
- 搭建 Flutter macOS 工程（`app/`），确认引擎经 SPM 集成、无需 CocoaPods。
- 实现 Dart 存储层、Capture 编排、ID 生成、设置持久化、剪贴板抽象。
- 实现 macOS 原生 MethodChannel（剪贴板文字/原始图片/文件、NSOpenPanel 选目录、UserDefaults、窗口控制、退出）。
- 实现悬浮窗口（置顶/可拖拽/跨空间/Dock 隐藏）与引导页、胶囊按钮及反馈。
- 配置 Info.plist（LSUIElement）与 entitlements（V0.1 关闭沙箱）。
- 编写并通过 7 项单元测试；`dart analyze` 无问题；`flutter build macos --debug` 成功并实际启动。

验证：
- 单元测试：7/7 通过。
- 静态分析：No issues found。
- 构建：成功产出 .app 并启动运行不崩溃。
- 待人工补充：Obsidian 内图片显示与异常场景的真机点击。

遗留：
- 沙箱关闭的安全权衡（见「当前问题」）。
- 真机端到端点击/截图受限于系统辅助功能与屏幕录制权限。
- 系统 Ruby 仍为 2.6.10（按要求未改动）；Homebrew 已解压到 `~/homebrew` 但未继续装 Ruby/CocoaPods——V0.1 不需要。

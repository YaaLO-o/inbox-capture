# INbox / Universal Capture

INbox 是一个本地优先的桌面采集工具。复制文字、图片或本地文件后，点击桌面悬浮入口，内容会作为普通 Markdown 和附件追加到用户选择的 Obsidian Vault。

`app/` 下的 Flutter 工程是唯一正式客户端，同一套 Dart 产品与数据层面向 macOS 和 Windows。项目不使用数据库，不上传内容，也不在后台监听剪贴板。

## 当前平台状态

- macOS：Flutter + Swift/AppKit，V0.1 已在本机完成分析、测试、Release 构建、Applications 安装和独立启动验证；桌面入口为像素宝箱怪桌宠。
- Windows：同一 Flutter 工程 + C++/Win32 Runner，已实现原生适配器；仓库包含 Windows GitHub Actions 构建检查，仍需 Windows runner 或真机完成首次编译与交互验证。
- Android、iOS、Web：不在当前范围。

## 功能

- 文字、图片和 Finder/Explorer 本地文件 Capture
- 每条 Capture 的唯一 ID
- 每日 Markdown 只追加、不覆盖
- 图片和本地文件作为普通附件保存，尽量保留原始格式
- Finder/Explorer 文件优先，避免同一图片重复保存为文件和 bitmap
- 失效 Vault 路径自动清理，不会在旧位置重新创建目录
- 像素宝箱怪桌宠作为置顶悬浮入口，整个箱体可拖拽，点击 Capture，带保存状态动画
- 右键重新选择 Vault 或退出

Capture、路径、附件命名、Markdown 和 append 行为全部位于共享 Dart 层；平台原生代码只负责剪贴板、文件夹选择、设置持久化和窗口行为。

## Vault 数据结构

macOS 和 Windows 的新版本统一写入：

```text
<Vault>/
└── Universal Capture/
    ├── 2026-08-22.md
    └── attachments/
        ├── 20260822-103215-a82f.png
        └── ...
```

每条记录格式：

```markdown
## 10:32

<!-- capture:id=20260822-103215-a82f -->

复制的文字

![[attachments/20260822-103215-a82f.png]]

---
```

## Capture 与 Knowledge 决策

- Obsidian 支持预览的图片附件使用 embed；PDF、视频、Office、ZIP 和其他普通文件使用普通链接。Finder/Explorer 文件的非图片链接会显示安全处理后的原始 basename；普通剪贴板图片没有原始名，因此不生成 alias。
- AI 分类、标签、embedding 和语义搜索均推迟。当前只保留稳定的 `capture:id` 和 Capture section，供未来 derived data 引用。
- `Universal Capture/` 与 `Universal Capture/attachments/` 是 Raw Capture Layer，不是 Knowledge Graph。Obsidian Graph Filter 如需隐藏附件，使用 `-path:"Universal Capture/attachments"`；如需排除整个 Raw 层，使用 `-path:"Universal Capture"`。本项目不新增 Graph UI，也不自动修改 Obsidian 配置。

旧版本已经产生的 `素材/Inbox`、`素材/attachments` 或旧 `Universal Capture` 内容不会被删除或自动迁移。

## 目录结构

```text
INbox/
├── app/                         # 唯一正式 Flutter 客户端
│   ├── lib/                     # 共享模型、服务、路径与 UI
│   ├── macos/                   # Swift/AppKit adapter
│   ├── windows/                 # C++/Win32 adapter
│   └── test/                    # 共享 Dart/Widget 测试
├── legacy/
│   └── electron-windows/        # 旧 Electron 参考实现，不再进入主线
├── docs/superpowers/            # 当前架构设计和实施计划
├── README.md
└── PROJECT_STATE.md
```

## macOS 运行

前置环境：Flutter 3.47.1、Dart 3.13.1、Xcode。当前工程使用 Swift Package Manager，不依赖 CocoaPods。

开发启动：

```bash
cd app
flutter pub get
flutter run -d macos
```

本机正式使用：

```text
/Applications/INbox.app
```

可以在「应用程序 / Applications」中双击 `INbox`，或通过 Spotlight 搜索 `INbox` 直接启动，不需要终端或 `flutter run`。

代码更新后，在仓库根目录重新构建并安装：

```bash
./scripts/install_macos.sh
```

脚本会执行 `flutter pub get` 和 macOS Release 构建，然后使用 `ditto` 将产物安装到 `/Applications/INbox.app`。安装成功后，脚本会将 build 目录中的同名应用产物改为 `.noindex`，避免 Spotlight 出现多个 INbox；后续构建会正常重新生成产物。如果当前用户无权写入 `/Applications`，脚本会输出 Release 产物路径供手动拖入，不会调用 `sudo`。

开发验证：

```bash
dart analyze lib test
flutter test
flutter build macos --debug
```

## Windows 运行

前置环境：Flutter 3.47.1、Visual Studio 2022，并安装“使用 C++ 的桌面开发”工作负载。

```powershell
cd app
flutter pub get
flutter run -d windows
```

构建验证：

```powershell
dart analyze lib test
flutter test
flutter build windows
```

`.github/workflows/windows-build.yml` 会在 Windows runner 上执行相同的最小构建检查。

## Legacy Electron

原 Windows Electron 客户端完整保留在 `legacy/electron-windows/`，用于追溯旧悬浮入口体验和历史行为。它不再是正式入口，也不应继续承载新功能。

## 当前仍需人工验证

- Windows runner 首次 `flutter build windows` 结果
- Windows 文字、PNG/JPEG、bitmap、Explorer 文件和窗口交互真机测试
- macOS 与 Windows 中 Obsidian 图片 embed、普通文件链接的真实显示
- macOS App Sandbox 仍为关闭状态；安装包、签名和分发不在本轮范围

真实完成状态和最新验证记录见 [`PROJECT_STATE.md`](PROJECT_STATE.md)。

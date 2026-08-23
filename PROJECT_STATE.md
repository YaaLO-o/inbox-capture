# Project State

更新时间：2026-08-22

## 当前阶段

Flutter Desktop Capture 基础设施统一完成。`app/` 是唯一正式主工程，包含 macOS 和 Windows target；旧 Electron Windows 客户端已降级到 `legacy/electron-windows/`，只作为迁移参考。

Windows 原生代码已经实现，但当前开发机是 macOS，无法在本机编译 Windows Runner。仓库已增加 Windows GitHub Actions build check；在该工作流或 Windows 真机成功前，Windows 状态是“代码完成、待 Windows 编译与交互验证”。

## 产品范围

当前只做 Capture：用户复制文字、图片或本地文件后点击悬浮入口，原始内容直接追加到 Obsidian Vault。

不包含 AI 分类、摘要、标签、embedding、语义搜索、Understand、Organize、云同步、账号、后端、数据库、网络内容解析、下载、Android、iOS 或 Web。

## 最终架构

```text
Shared Flutter app
├── Dart model / CaptureService / StorageService / VaultPaths
├── shared onboarding and floating capture UI
├── macOS Swift + AppKit MethodChannel adapter
└── Windows C++ + Win32 MethodChannel adapter
```

共享 Dart 决定：

- Capture ID
- 文字 trim 与空内容处理
- 文件优先于重复 bitmap
- 附件文件名
- Vault 目录
- Markdown 格式
- 每日文件和 append 行为
- 已保存 Vault 路径有效性

平台 adapter 只提供：

- 剪贴板文字、图片字节、原始格式和本地文件路径
- 原生文件夹选择
- Vault 路径持久化与清理
- 窗口尺寸和位置
- 应用退出

## MethodChannel contract

两个平台使用相同 channel：

```text
com.inbox.app/clipboard
  readClipboard -> text, imageBytes, imageExtension, imageMimeType, files

com.inbox.app/settings
  getVaultPath
  setVaultPath(path)
  clearVaultPath
  pickFolder
  setWindowSize(width, height)
  moveWindowBy(dx, dy)
  quit
```

macOS 使用 NSPasteboard、UserDefaults、NSOpenPanel 和 NSWindow。Windows 使用 Win32 Clipboard、CF_HDROP、Registry、IFileDialog 和原生窗口 API。

## 统一 Vault 协议

两个平台的新 Capture 统一写入：

```text
<Vault>/
└── Universal Capture/
    ├── YYYY-MM-DD.md
    └── attachments/
        └── <capture-id>.<extension>
```

日期只由每日文件名表达，正文不再重复日期一级标题。每条 Capture 按“分钟级时间、唯一 ID 注释、可选文字、附件、分隔线”顺序写入；人类可见标题使用 `HH:mm`，机器使用的 Capture ID 和附件文件名仍保留秒数。Obsidian 支持预览的图片附件使用 embed；PDF、视频、Office、ZIP 和其他普通文件使用普通链接，Finder/Explorer 文件链接显示安全处理后的原始 basename。所有写入使用 append，不覆盖已有内容。

`capture:id` 保持稳定唯一，Capture section 保持可供未来 derived data 引用；AI 分类、标签、embedding 和语义搜索仍明确推迟。

`Universal Capture/` 与 `Universal Capture/attachments/` 是 Raw Capture Layer，不是 Knowledge Graph。Obsidian Graph Filter 要隐藏附件时使用 `-path:"Universal Capture/attachments"`；要排除整个 Raw 层时使用 `-path:"Universal Capture"`。当前不新增 Graph UI，也不自动修改 Obsidian 配置。

历史 `素材/Inbox`、`素材/attachments` 和旧 Electron 内容不会被自动迁移或删除。

## 已实现

### 共享 Dart 与 UI

- 文字、图片、本地文件 Capture
- 唯一 Capture ID 和每日 Markdown
- 附件普通文件存储；图片 Obsidian embed、非图片普通链接
- 连续 append、不覆盖
- 500ms 快速点击防重
- 失效 Vault 路径清理，验证过程不创建旧目录
- 本地文件优先于同一剪贴板对象的 bitmap
- 共享 `•••` 拖动把手、圆形“收”入口和状态反馈
- 右键重新选择 Vault、退出

### macOS adapter

- 文字、PNG、JPEG、GIF、TIFF、WebP 和 bitmap PNG 回退
- Finder 文件 URL
- Finder 文件存在时不再读取重复图片 bytes
- UserDefaults、NSOpenPanel、窗口缩放/移动、置顶和跨空间
- LSUIElement/accessory 模式隐藏 Dock 图标

### Windows adapter

- CF_UNICODETEXT 文字
- CF_HDROP Explorer 文件
- 注册剪贴板 PNG/JPEG 原始字节优先
- CF_BITMAP、CF_DIB、CF_DIBV5 通过 GDI+ 回退 PNG
- 文件存在时不再读取 bitmap
- HKCU Registry Vault 持久化
- IFileDialog 原生目录选择
- 无边框、置顶、Tool Window 窗口
- 窗口缩放、拖动和退出

## 自动化测试

当前 Flutter 测试共 17 项，覆盖：

- 统一目录和 attachment 引用
- macOS/Windows 标记输入生成相同 Markdown
- Capture ID
- 文字 trim、新文件格式
- 连续 10 条 append
- 图片和本地文件
- 带点父目录中的无扩展名文件
- 文件优先于重复 bitmap
- 空剪贴板
- 文字与图片混合
- 有效和失效 Vault 配置
- ClipboardService contract 归一化
- 共享悬浮入口可见元素和拖动通道
- 首次引导中的统一目录说明

旧 Electron 11 项 Node 测试仍保留在 legacy 目录并通过，但不再作为正式客户端验收项。

## 本轮本机验证

在 macOS 开发机完成：

```text
flutter pub get                 通过
dart analyze lib test           No issues found
flutter test                    17/17 通过
flutter build macos --debug     通过
macOS debug executable launch   通过，进程稳定存活 3 秒
```

## Windows CI

`.github/workflows/windows-build.yml` 使用 `windows-latest` 和 Flutter 3.47.1，执行：

```text
flutter pub get
dart analyze lib test
flutter test
flutter build windows
```

工作流文件已加入仓库，但本轮没有 push，因此尚无远端 Windows runner 结果。不能据此声称 Windows 已编译通过。

## 已知问题与人工验证

- 必须在 Windows runner 或 Windows 真机首次编译 C++ Runner。
- 必须真机测试 Windows 文字、PNG/JPEG、bitmap、Explorer 文件、目录选择、重启恢复、拖动、右键菜单与退出。
- 需要在真实 Obsidian 中验证图片 embed 与普通文件链接显示。
- macOS App Sandbox 仍关闭；重新启用需要 security-scoped bookmark。
- 安装包、代码签名、公证、开机启动和发布流程不在当前范围。

## 运行方式

macOS：

```bash
cd app
flutter pub get
flutter run -d macos
```

Windows：

```powershell
cd app
flutter pub get
flutter run -d windows
```

# Project State

更新时间　2026-08-26

## 当前阶段

V0.1（Mac Capture MVP）和 Android Capture MVP 已完成。macOS 生命周期与应用内更新已完成 1.1.1 本地发布准备和预发布验证。`app/` 是唯一正式主工程，包含 Android、macOS 和 Windows target；旧 Electron Windows 客户端已降级到 `legacy/electron-windows/`，只作为迁移参考。桌面入口已从悬浮胶囊改为像素宝箱怪桌宠。

macOS Release App 已完成本机安装验证。正式应用名为 `INbox`，Bundle Identifier 保持 `com.inbox.inboxApp`，安装位置为 `/Applications/INbox.app`；可从 Applications 或 Spotlight 启动，运行后继续保持 LSUIElement 桌面悬浮助手模式。再次从 Applications 或 Spotlight 打开已运行的 INbox 时，AppDelegate 会重新显示悬浮窗。安装脚本会注销并归档 build 目录中的同名 `.app` 产物，避免开发产物污染 Spotlight 搜索结果。

Windows 原生代码已经实现，但当前开发机是 macOS，无法在本机编译 Windows Runner。仓库已增加 Windows GitHub Actions build check；在该工作流或 Windows 真机成功前，Windows 状态是“代码完成、待 Windows 编译与交互验证”。

## 产品范围

当前核心是 Capture：用户复制文字、图片或本地文件后点击悬浮入口，原始内容以标准 Markdown 追加到用户自选的存储文件夹。桌宠仍是主要入口；Mac 端另有"控制中心"主页面承担存储位置、展示方式、检查更新等控制职能。存储层是开放文件（Markdown + attachments），展示层可在应用内只读查看、系统默认 Markdown 应用、Obsidian 之间切换；Obsidian 是其中一种打开方式，不是数据存储本身。Apple 备忘录暂留作以后"导出到备忘录"，不作为底层存储目标。

不包含 AI 分类、摘要、标签、embedding、语义搜索、Understand、Organize、云同步、账号、后端、数据库、网络内容解析、下载、iOS 或 Web。Android 当前范围仅为个人侧载的 Capture MVP。

## 最终架构

```text
Shared Flutter app
├── Dart model / CaptureService / StorageService / VaultPaths
├── shared onboarding and floating capture UI
├── Android Kotlin SAF / Share Target / floating overlay adapter
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
- 原生 bundle 版本读取和 macOS 更新安装

## MethodChannel contract

两个平台使用相同 channel：

```text
com.inbox.app/clipboard
  readClipboard -> text, imageBytes, imageExtension, imageMimeType, files

com.inbox.app/settings
  getVaultPath
  setVaultPath(path)
  clearVaultPath
  getDisplayMethod / setDisplayMethod(method ∈ inbox|system|obsidian)
  pickFolder
  revealPath(path)              # Finder/Explorer 打开存储文件夹
  openPath(path)                # 系统默认应用打开文件
  openExternalUrl(url)          # 打开 obsidian:// 等外部 scheme；无 handler 返回 false
  setWindowMode(standard|floating)  # 切换原生窗口样式（红叉/标题栏 vs 悬浮）
  getAppVersion
  showWindow
  setWindowSize(width, height, animate)
  moveWindowBy(dx, dy)
  beginWindowDrag
  updateWindowDrag
  endWindowDrag
  installUpdate(dmgPath)
  quit

  # 原生 → Dart 反向调用：
  mainWindowDidClose            # 标准窗口红叉触发，Dart 复位模式状态
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

日期只由每日文件名表达，正文不再重复日期一级标题。每条 Capture 按"分钟级时间、唯一 ID 注释、可选文字、附件、分隔线"顺序写入；人类可见标题使用 `HH:mm`，机器使用的 Capture ID 和附件文件名仍保留秒数。图片附件使用标准 Markdown 嵌入语法 `![](attachments/<file>)`；PDF、视频、Office、ZIP 和其他普通文件使用标准链接 `[安全显示名](attachments/<file>)`，显示名中的 `#|^:%[]()` 等字符会被清洗以保护链接结构。Obsidian 对标准 Markdown 语法完全兼容，其他 Markdown 工具（Typora、VS Code 等）也能正常渲染。所有写入使用 append，不覆盖已有内容；历史 wiki 语法文件（`![[...]]`/`[[...|name]]`）保持原样不迁移。

`capture:id` 保持稳定唯一，Capture section 保持可供未来 derived data 引用；AI 分类、标签、embedding 和语义搜索仍明确推迟。

`Universal Capture/` 与 `Universal Capture/attachments/` 是 Raw Capture Layer，不是 Knowledge Graph。Obsidian Graph Filter 要隐藏附件时使用 `-path:"Universal Capture/attachments"`；要排除整个 Raw 层时使用 `-path:"Universal Capture"`。当前不新增 Graph UI，也不自动修改 Obsidian 配置。

历史 `素材/Inbox`、`素材/attachments` 和旧 Electron 内容不会被自动迁移或删除。

## 已实现

### 共享 Dart 与 UI

- 文字、图片、本地文件 Capture
- 唯一 Capture ID 和每日 Markdown
- 附件普通文件存储；图片标准 Markdown 嵌入语法、非图片标准链接
- 连续 append、不覆盖
- 500ms 快速点击防重
- 失效存储文件夹路径清理，验证过程不创建旧目录
- 本地文件优先于同一剪贴板对象的 bitmap
- 像素宝箱怪桌宠作为桌面入口：整个箱体可拖拽，点击触发 Capture，带 idle/capturing/success/empty/error 动画与 golden 测试
- 右键弹出浅色快捷菜单（控制中心 / 更改存储文件夹 / 检查更新 / 退出 INbox），不跟随系统 Dark Mode
- 控制中心（Mac 主页面）：当前存储位置显示、打开/更改存储文件夹、默认展示方式选择、查看内容、检查更新、返回桌宠
- 可切换展示层：应用内只读查看器 / 系统默认 Markdown 应用 / Obsidian；切换展示方式只改变"用什么看"，不移动或重写文件；未检测到 Obsidian 时弹窗提示可用系统默认应用打开
- 应用内只读查看器：按日期列出最近笔记，右侧用 SelectableText 展示 Markdown 原文，无编辑功能
- 更新界面显示检查、下载进度、本机校验、安装与保留旧版的状态；从控制中心进入更新页时窗口保持标准样式，关闭后回到控制中心
- 当前版本来自原生 `CFBundleShortVersionString`，不在 Dart 中另设版本常量

### macOS adapter

- 文字、PNG、JPEG、GIF、TIFF、WebP 和 bitmap PNG 回退
- Finder 文件 URL
- Finder 文件存在时不再读取重复图片 bytes
- UserDefaults、NSOpenPanel、窗口缩放/移动、置顶和跨空间
- LSUIElement/accessory 模式隐藏 Dock 图标
- 单窗口双样式：同一 NSWindow 在悬浮宠物与标准 macOS 窗口（标题栏 + 红叉、普通层级、居中）之间原地切换；标准窗口红叉不退出进程，切回悬浮宠物并通过 `mainWindowDidClose` 通知 Dart 复位状态
- 右键宠物弹出四项快捷菜单（控制中心 / 更改存储文件夹 / 检查更新 / 退出 INbox）
- `revealPath`/`openPath`/`openExternalUrl` 调起 Finder、系统默认应用与外部 URL scheme（含 Obsidian 存在性探测）
- 更新包校验通过后由本地 helper 替换 `/Applications/INbox.app`，失败时保留或回滚到旧版
- 只有用户点「检查更新」或主动运行安装脚本时才联系 GitHub

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

### Android adapter

- Android 10（API 29）及以上，当前为个人侧载 APK
- 通过 Storage Access Framework 持久授权真实 Obsidian Vault，不申请全盘存储权限
- 系统 Share Target 支持文字、URL、单图、多图、PDF、视频和普通文件
- 附件以流方式写入并校验真实字节；图片生成 Obsidian embed，其他附件生成普通链接
- 用户主动开启的悬浮球在点击时读取一次当前剪贴板，不做后台轮询
- 悬浮球需要 overlay 权限，Android 13 及以上需要通知权限；不注册开机启动
- 跨日首次 Capture 会按设备当天日期自动创建缺失的 `YYYY-MM-DD.md`

## 自动化测试

当前 Flutter 测试共 126 项，覆盖桌面与 Android 共享 Capture 行为，包括：

- 统一目录和 attachment 引用
- macOS/Windows 标记输入生成相同 Markdown
- Capture ID（稳定、唯一、隐藏 HTML 注释）
- 文字 trim、`HH:mm` 分钟级标题、新文件格式
- 连续 10 条 append
- 图片 embed、PDF/视频/普通文件链接
- 带点父目录中的无扩展名文件
- 文件优先于重复 bitmap
- 空剪贴板与文字/图片混合
- 有效和失效 Vault 配置
- ClipboardService contract 归一化
- 像素宝箱怪桌宠：动画 manifest、sprite 渲染、点击/拖拽/右键、success/empty/error、reduced-motion、golden
- 右键快捷菜单：显示/关闭、点击外部关闭、菜单项功能
- 窗口透明 surface 与首次引导中的统一目录说明
- 更新界面的当前版本判定、新版提示、下载进度和错误保护
- macOS 菜单栏动作、窗口绝对指针拖动、更新安装路径和 helper 环境清理
- 安装与替换脚本的进程防护、路径校验、替换和回滚

旧 Electron 11 项 Node 测试仍保留在 legacy 目录并通过，但不再作为正式客户端验收项。

## 1.1.1 本地预发布验证

2026-08-25 在 macOS 开发机和含中文字符的工作区路径下完成。

```text
flutter pub get                 通过
dart analyze lib test           No issues found
flutter test                    85/85 通过
xcodebuild test                 5/5 RunnerTests 通过
sh -n                           安装、发布和替换脚本通过
replace_macos_app_test.sh       通过
install_sh_test.sh              7/7 通过
release_macos_test.sh           4/4 通过
release_macos.sh 1.1.1          通过
```

新构建的 app bundle 版本为 `1.1.1`，build 为 `2`，二进制同时包含 `x86_64` 和 `arm64`。两个 DMG 均为 `17682577` 字节，SHA-256 均为 `2e5189e7c894c404725ddcc1c32a8fbef11795be43ffdecde4ab2e9c7ce13425`，通过 `cmp` 字节比较和 `hdiutil verify`。

本轮没有把应用安装到 `/Applications`，也没有推送、打 tag、上传资产或修改 GitHub Release。精确安装路径、真实断网、更新回滚与安装后交互仍需在授权后手动验收。

## V0.1 本机验证

在 macOS 开发机完成：

```text
flutter pub get                 通过
dart analyze lib test           No issues found
flutter test                    66/66 通过
flutter build macos --debug     通过，产物为 INbox.app
flutter build macos --release   通过，产物为 Universal INbox.app (arm64+x86_64)
GitHub Release v0.1.0           已发布，含 DMG 下载
curl|sh 一键安装                通过，无 Gatekeeper 拦截
macOS floating pet UI           通过，像素宝箱怪桌宠实际可见
```

## Windows CI

`.github/workflows/windows-build.yml` 使用 `windows-latest` 和 Flutter 3.47.1，执行：

```text
flutter pub get
dart analyze lib test
flutter test
flutter build windows
```

工作流文件已加入仓库并推送到远程；Windows runner 结果以实际 Actions 运行为准，不能据此声称 Windows 已编译通过。

## 已知问题与人工验证

- 必须在 Windows runner 或 Windows 真机首次编译 C++ Runner。
- 必须真机测试 Windows 文字、PNG/JPEG、bitmap、Explorer 文件、目录选择、重启恢复、拖动、右键菜单与退出。
- Android overlay 权限在应用处于后台时被撤销，前台服务和通知可能暂时残留到下次应用恢复；Capture 数据正确性不受影响，列为 P2。
- Pixel 6 API 36 模拟器未复现悬浮球进入状态栏或手势区的问题；真实 WindowInsets 的额外 OEM 覆盖列为 P2。
- macOS App Sandbox 仍关闭；重新启用需要 security-scoped bookmark。
- Developer ID、公证、开机启动和公开发布仍是后续工作。本地可以生成 Universal DMG，但未经明确授权不会推送、打 tag 或修改 GitHub Release。

## 运行方式

macOS：

```bash
# 开发启动
cd app
flutter pub get
flutter run -d macos

# 返回仓库根目录后，重新构建并安装本机 Release App
cd ..
./scripts/install_macos.sh

# 在仓库根目录构建 1.1.1 Universal DMG
sh scripts/release_macos.sh 1.1.1
```

日常使用时直接在 Applications 双击 `INbox`，或通过 Spotlight 搜索 `INbox`。正式安装路径是 `/Applications/INbox.app`。

Windows：

```powershell
cd app
flutter pub get
flutter run -d windows
```

## Android MVP 验证

2026-08-26 已在 Pixel 6 API 36 模拟器与 Xiaomi 13 Pro（Android 16 / HyperOS OS3.0.310.0.WMBCNXM）完成验收。静态分析、Flutter 126/126、Android JVM tests、API 36 instrumentation、Android debug APK 和 macOS debug build 均通过；Xiaomi 的 Share 附件与来源 SHA-256 一致，Obsidian 1.13.8 可渲染图片并识别普通附件链接。详见 [`docs/android-mvp-verification.md`](docs/android-mvp-verification.md)。

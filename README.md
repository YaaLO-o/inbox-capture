![INbox](https://socialify.git.ci/YaaLO-o/inbox-capture/image?description=1&font=Source+Code+Pro&forks=1&issues=1&logo=https%3A%2F%2Fraw.githubusercontent.com%2FYaaLO-o%2Finbox-capture%2Fmain%2Fapp%2Fmacos%2FRunner%2FAssets.xcassets%2FAppIcon.appiconset%2Fapp_icon_1024.png&name=1&owner=1&pattern=Floating+Cogs&pulls=1&stargazers=1&theme=Auto)

<div align="center">

**把任何平台看到的文字、图片和文件，一键收进你的 Obsidian。**

一个本地优先、不上传、不监听剪贴板的桌面采集 Inbox。

<div>
    <a href="https://github.com/YaaLO-o/inbox-capture/releases/latest"><img alt="macOS" src="https://img.shields.io/badge/-macOS%20Universal-black?style=flat-square&logo=apple&logoColor=white" /></a>
    <a href="https://github.com/YaaLO-o/inbox-capture/releases"><img alt="Windows (待验证)" src="https://img.shields.io/badge/-Windows%20%E5%BE%85%E9%AA%8C%E8%AF%81-blue?style=flat-square&logo=windows&logoColor=white" /></a>
</div>

<p>
    <a href="https://github.com/YaaLO-o/inbox-capture/releases/latest"><img alt="Latest Release" src="https://img.shields.io/github/v/release/YaaLO-o/inbox-capture?style=flat-square" /></a>
    <a href="https://github.com/YaaLO-o/inbox-capture/blob/main/LICENSE"><img alt="License" src="https://img.shields.io/github/license/YaaLO-o/inbox-capture?style=flat-square" /></a>
    <a href="https://github.com/YaaLO-o/inbox-capture/releases"><img alt="Downloads" src="https://img.shields.io/github/downloads/YaaLO-o/inbox-capture/total?style=flat-square" /></a>
    <a href="https://docs.flutter.dev/release/archive"><img alt="Flutter 3.47" src="https://img.shields.io/badge/Flutter-3.47-02569B?style=flat-square&logo=flutter&logoColor=white" /></a>
</p>

</div>

![像素宝箱怪桌宠：待机 → 采集 → 成功](docs/assets/pet-hero.png)

## 下载

当前提供 **macOS（Apple Silicon + Intel，Universal）** 版本：

👉 **[在 Releases 下载最新版 INbox](https://github.com/YaaLO-o/inbox-capture/releases/latest)**

下载 `.dmg`，双击打开，把 `INbox` 拖入「应用程序 / Applications」即完成安装。

> 首次打开若提示「无法验证开发者」或「已损坏」，请**右键 → 打开**，或参阅 [安装指南](.github/DOWNLOAD.md)。这是因为当前版本尚未购买 Apple Developer ID 进行签名和公证，应用本身完全本地运行、不联网。

## 它是什么

INbox 解决的问题很简单：在微博、小红书、抖音、网页、购物平台看到一本书、一部电影、一个观点或一张图时，不想分散收藏在各个平台里，而是用最低摩擦的动作直接存进自己的 Obsidian。

核心动作：

```text
复制内容 → 点击桌宠 → 写入 Obsidian → 宝箱怪开心地收下
```

- **本地优先**：内容直接写进你自己选择的 Obsidian Vault，纯 Markdown + 附件文件，可直接阅读、搜索、迁移。
- **Obsidian 是唯一存储层**：不使用数据库，不建账号，不上传内容，不请求网络。
- **不监听剪贴板**：只有你点击桌宠的那一刻才会读取一次剪贴板。
- **像素宝箱怪桌宠**：一个置顶、可拖拽的小入口；点击采集，带开箱动画反馈，右键切换 Vault / 退出。

## 功能

- 文字、图片、Finder 本地文件采集
- 每条记录有稳定、唯一的隐藏 `capture:id`，可供未来引用
- 每天一个 Inbox Markdown，只追加、不覆盖
- 图片在 Obsidian 中内嵌预览；PDF、视频、Office、ZIP 等以可点击链接保存
- Finder/Explorer 文件优先，避免同一张图既存文件又存 bitmap
- 失效 Vault 路径自动清理，不会在旧位置重建目录
- 置顶悬浮桌宠，整个箱体可拖拽，保存状态有动画反馈

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

- Obsidian 支持预览的图片附件用 embed；PDF、视频、Office、ZIP 等用普通链接。Finder 文件的非图片链接会显示安全处理后的原始文件名；普通剪贴板图片没有原始名，因此不生成 alias。
- AI 分类、标签、摘要、embedding、语义搜索均**推迟**。当前只保留稳定的 `capture:id` 和 Capture section，供未来 derived data 引用。
- `Universal Capture/` 与 `Universal Capture/attachments/` 是 **Raw Capture Layer，不是 Knowledge Graph**。需要在 Obsidian Graph 中隐藏附件时用 `-path:"Universal Capture/attachments"`；排除整个 Raw 层用 `-path:"Universal Capture"`。本项目不新增 Graph UI，也不自动修改 Obsidian 配置。

旧版本产生的 `素材/Inbox`、`素材/attachments` 或旧 `Universal Capture` 内容不会被删除或自动迁移。

## 目录结构

```text
INbox/
├── app/                         # 唯一正式 Flutter 客户端
│   ├── lib/                     # 共享模型、服务、路径与 UI（含像素宝箱怪桌宠）
│   ├── macos/                   # Swift/AppKit adapter
│   ├── windows/                 # C++/Win32 adapter
│   └── test/                    # 共享 Dart/Widget 测试（63 项）
├── scripts/                     # install_macos.sh / release_macos.sh
├── legacy/
│   └── electron-windows/        # 旧 Electron 参考实现，不再进入主线
├── docs/superpowers/            # 架构设计与实施计划
├── README.md
└── PROJECT_STATE.md
```

## 从源码构建

前置环境：Flutter 3.47.1、Dart 3.13.1、Xcode。工程使用 Swift Package Manager，不依赖 CocoaPods。

```bash
cd app
flutter pub get
flutter run -d macos
```

验证：

```bash
dart analyze lib test
flutter test
flutter build macos --release
```

一键构建 Release 并打包成可分发 DMG：

```bash
sh scripts/release_macos.sh 0.1.0
# 产物：dist/INbox-0.1.0-macos-universal.dmg
```

日常本机使用可在仓库根目录运行 `./scripts/install_macos.sh`，它会构建 Release 并安装到 `/Applications/INbox.app`。

## 当前状态与限制

- ✅ **macOS V0.1 完成**：`dart analyze` 无问题、63/63 测试通过、Release 构建为 Universal `INbox.app`，已验证可安装启动。
- 🟡 **Windows**：同一套 Flutter + C++/Win32 代码已完成，仓库含 GitHub Actions 构建检查，但尚未在 Windows 真机首次编译与交互验证，暂不提供下载。
- 🔒 macOS App Sandbox 当前关闭（重新启用需要 security-scoped bookmark）。
- 🚫 暂未做 Apple Developer ID 签名 / 公证、DMG/PKG 分发流程，因此首次打开需按 [安装指南](.github/DOWNLOAD.md) 放行。
- 🤖 AI 分类、标签、摘要、语义搜索、Knowledge Layer、云同步均在后续版本规划中，V0.1 只做 Capture。

真实完成状态与验证记录见 [PROJECT_STATE.md](PROJECT_STATE.md)。

## 历史星标

<a href="https://www.star-history.com/#YaaLO-o/inbox-capture&Date">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=YaaLO-o/inbox-capture&type=Date&theme=dark" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=YaaLO-o/inbox-capture&type=Date" />
   <img alt="Star History" src="https://api.star-history.com/svg?repos=YaaLO-o/inbox-capture&type=Date" />
 </picture>
</a>

## License

本项目采用 [MIT License](LICENSE)。

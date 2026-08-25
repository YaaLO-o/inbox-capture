![INbox](https://socialify.git.ci/YaaLO-o/inbox-capture/image?description=1&font=Source+Code+Pro&forks=1&issues=1&logo=https%3A%2F%2Fraw.githubusercontent.com%2FYaaLO-o%2Finbox-capture%2Fmain%2Fapp%2Fmacos%2FRunner%2FAssets.xcassets%2FAppIcon.appiconset%2Fapp_icon_1024.png&name=1&owner=1&pattern=Floating+Cogs&pulls=1&stargazers=1&theme=Auto)

<div align="center">

**把任何平台看到的东西，一键收进你的 Obsidian。**

一个本地优先、不上传、不后台监听的桌面采集 Inbox。用一个像素宝箱怪作为桌面入口，复制完点一下，文字、图片、文件就写进你自己的库。

<div>
    <a href="#安装"><img alt="macOS" src="https://img.shields.io/badge/-macOS%20Universal-black?style=flat-square&logo=apple&logoColor=white" /></a>
    <a href="https://github.com/YaaLO-o/inbox-capture/releases"><img alt="Windows" src="https://img.shields.io/badge/-Windows%20%E8%A7%84%E5%88%92%E4%B8%AD-blue?style=flat-square&logo=windows&logoColor=white" /></a>
</div>

<p>
    <a href="https://github.com/YaaLO-o/inbox-capture/releases/latest"><img alt="Latest Release" src="https://img.shields.io/github/v/release/YaaLO-o/inbox-capture?style=flat-square" /></a>
    <a href="LICENSE"><img alt="License" src="https://img.shields.io/github/license/YaaLO-o/inbox-capture?style=flat-square" /></a>
    <a href="https://github.com/YaaLO-o/inbox-capture/releases"><img alt="Downloads" src="https://img.shields.io/github/downloads/YaaLO-o/inbox-capture/total?style=flat-square" /></a>
    <a href="https://docs.flutter.dev/release/archive"><img alt="Flutter 3.47" src="https://img.shields.io/badge/Flutter-3.47-02569B?style=flat-square&logo=flutter&logoColor=white" /></a>
</p>

</div>

![像素宝箱怪桌宠：待机 → 采集 → 开心收下](docs/assets/pet-hero.png)

## 它解决什么问题

在微博、小红书、抖音、网页、购物平台看到一本书、一部电影、一段话、一个观点或一张图时，你不想分散收藏在各个平台里，也不想事后找不到。INbox 让你用最低摩擦的动作把这些内容收进**自己的** Obsidian：

```text
复制内容  →  点击桌宠  →  写入 Obsidian  →  宝箱怪开心地收下
```

采集的内容就是你硬盘上的普通 Markdown 和附件文件，可以直接阅读、搜索、用 Git 备份、用任何工具处理。

## 特性

- 📝 **文字、图片、本地文件**都能采集——Finder 里复制的文件会原样存进附件目录
- 🗂️ **每天一个 Markdown 文件**，只追加、不覆盖，按时间排列
- 🔗 图片在 Obsidian 中**内嵌预览**；PDF、视频、Office、ZIP 等保存为**可点击链接**
- 🆔 每条记录都有稳定、唯一的隐藏 `capture:id`，为以后的整理、引用留好锚点
- 👾 **像素宝箱怪桌宠**：置顶在桌面右上角，整个身体可拖拽，点击采集，带开箱动画反馈；右键切换库或退出
- 🔍 **不后台监听剪贴板**——只有你点击的那一瞬间才读一次
- 🙈 **采集和存储完全本地**，没有服务器、没有账号、不上传任何内容

## 隐私

INbox 的设计原则是"你的东西只属于你"：

- Obsidian Vault 是**唯一存储层**，数据就是你电脑上的文件
- 不使用数据库，不建账号
- 不跟踪、不上报、不分析
- 只有你在菜单栏点「检查更新」，或主动运行安装命令时，INbox 才会联系 GitHub
- 源代码完全开放，可以自行审计

## 安装

### 方式一：终端一键安装（推荐）

复制下面这行到「终端」回车，会自动下载最新版并安装到 `/Applications/INbox.app`。

```bash
curl -fsSL https://raw.githubusercontent.com/YaaLO-o/inbox-capture/main/scripts/install.sh | sh
```

用这种方式安装不会出现「无法验证开发者」的提示。原理和 Homebrew 的 `brew install --no-quarantine` 相同。

正在使用 1.1.0 或更早版本时，请运行一次这条命令升级到 1.1.1。之后也可以直接在菜单栏点「检查更新」自动升级。

### 方式二：手动下载 DMG

<a href="https://github.com/YaaLO-o/inbox-capture/releases/latest/download/INbox-macos-universal.dmg"><b>⬇ 下载 INbox for macOS（Universal DMG）</b></a>

下载后双击 DMG，把 `INbox` 拖入「应用程序」。安装完成后的路径应为 `/Applications/INbox.app`。

> 首次打开若被 Gatekeeper 拦截，请**右键 → 打开**，或到「系统设置 → 隐私与安全性」点「仍要打开」。当前版本尚未使用 Apple Developer ID 签名和公证。日常采集完全本地运行，只有显式更新操作会联系 GitHub。上面的终端一键安装可绕过此提示。完整说明见[安装指南](.github/DOWNLOAD.md)。

支持 Apple Silicon（M 系列）和 Intel 芯片。

### 1.1.1 及后续版本的更新

正常更新时，点 macOS 菜单栏里的 INbox 图标，再点「检查更新」。INbox 会在本机校验下载文件，校验成功后替换 `/Applications/INbox.app` 并重新打开。网络断开、校验失败或安装失败时，当前版本会保留。

上面的终端命令仍然保留。当菜单更新无法打开，或一次更新被中断时，可以用它恢复到最新版。

### 窗口与退出

INbox 窗口保留 macOS 的红黄绿按钮。点红色关闭按钮只会隐藏窗口，应用会继续运行。需要重新打开时，点菜单栏里的 INbox 图标，再点「显示 INbox」。需要结束进程时，请点「完全退出」。

## 数据存在哪

INbox 把内容写进你选择的 Obsidian Vault：

```text
<Vault>/
└── Universal Capture/
    ├── 2026-08-23.md          # 每天一个文件
    └── attachments/
        ├── 20260823-103215-a82f.png
        └── ...
```

每条记录的格式：

```markdown
## 10:32

<!-- capture:id=20260823-103215-a82f -->

复制的文字

![[attachments/20260823-103215-a82f.png]]

---
```

这是一个**原始采集层（Raw Inbox）**，不是知识库本身。它只负责低摩擦地把东西先收进来，后续的整理、分类、关联仍然在 Obsidian 里由你完成。AI 分类、标签、摘要、语义搜索等功能暂未实现，未来会基于稳定的 `capture:id` 构建。

## 从源码构建

需要 Flutter 3.47.1、Dart 3.13.1、Xcode（Swift Package Manager，无需 CocoaPods）。

```bash
cd app
flutter pub get
flutter run -d macos
```

跑测试和构建：

```bash
dart analyze lib test
flutter test
cd ..
sh scripts/release_macos.sh 1.1.1
```

项目用 Flutter 共享一套 Dart 代码（模型、采集逻辑、存储、UI），macOS 和 Windows 各有很薄的原生适配层（剪贴板、文件夹选择、窗口控制）。

## 路线图

- ✅ macOS 文字 / 图片 / 文件采集，像素桌宠入口
- ✅ 菜单栏图标（显示 / 检查更新 / 完全退出）
- ✅ App 内更新（下载进度、SHA-256 校验、原子替换、失败回滚）
- 🚧 Windows 适配（代码已完成，待真机首次编译验证）
- ⏳ AI 分类、标签、摘要、语义搜索（基于 `capture:id`）
- ⏳ Apple Developer ID 签名与公证，免去首次打开提示

## 致谢

像素宝箱怪的设计灵感来自经典 RPG 里的宝箱怪（Mimic）。

## Star 历史

<a href="https://www.star-history.com/#YaaLO-o/inbox-capture&Date">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=YaaLO-o/inbox-capture&type=Date&theme=dark" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=YaaLO-o/inbox-capture&type=Date" />
   <img alt="Star History" src="https://api.star-history.com/svg?repos=YaaLO-o/inbox-capture&type=Date" />
 </picture>
</a>

## License

[MIT License](LICENSE)

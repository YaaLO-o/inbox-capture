# 安装指南

## macOS

文件同时支持 **Apple Silicon（M 系列）和 Intel** 芯片。

### 方式一　终端一键安装（首次安装、旧版升级与恢复）

复制下面这行到「终端」回车：

```bash
curl -fsSL https://raw.githubusercontent.com/YaaLO-o/inbox-capture/main/scripts/install.sh | sh
```

脚本会自动下载最新版、安装到 `/Applications/INbox.app` 并启动。用这种方式安装不会出现「无法验证开发者」的提示。`curl` 下载的文件不会被浏览器附加 macOS 隔离标记，原理和 Homebrew 的 `brew install --no-quarantine` 相同。

如果电脑上还在运行 1.1.0 或更早版本，请执行一次这条命令升级到 1.1.1。1.1.1 及以后版本通常从菜单栏更新，终端命令保留给首次安装和故障恢复。

### 方式二：手动下载 DMG

在 [Releases](https://github.com/YaaLO-o/inbox-capture/releases/latest) 下载最新的 `INbox-<版本>-macos-universal.dmg`（或点 README 里的下载按钮）。

### 2. 安装

1. 双击打开下载的 `.dmg` 文件；
2. 在弹出的窗口里，把 **INbox** 拖到 **Applications**（应用程序）文件夹；
3. 等待拷贝完成，确认安装路径为 `/Applications/INbox.app`，即可在「应用程序」或 Spotlight 中搜索 `INbox` 启动。

### 3. 首次打开（重要）

当前版本**尚未购买 Apple Developer ID 进行签名和公证**。采集和本地存储完全在本机完成，只有用户点「检查更新」或主动运行安装命令时才会联系 GitHub。macOS 的 Gatekeeper 第一次会拦截，按下面任意一种方式放行即可。

**方式 A：右键打开（最简单）**

1. 在「应用程序」里找到 `INbox`；
2. **按住 Control 点击**（或右键）图标，选择「打开」；
3. 在弹出的对话框中再点一次「打开」。

之后就可以正常双击启动。

**方式 B：系统设置放行**

如果方式 A 没有「打开」选项，直接双击后：

1. 打开「系统设置 → 隐私与安全性」；
2. 往下滚动，会看到「已阻止使用 INbox，因为它来自身份不明的开发者」；
3. 点「仍要打开」，输入密码确认。

**方式 C：终端命令（适合熟悉命令行的用户）**

```bash
xattr -dr com.apple.quarantine /Applications/INbox.app
```

执行后即可正常双击打开。

### 4. 更新

1.1.1 及以后版本可以直接点 macOS 菜单栏里的 INbox 图标，再点「检查更新」。INbox 只会在你执行这个动作，或主动运行安装命令时联系 GitHub。日常采集不会发出网络请求。

更新包会先在本机校验。下载、校验或替换失败时，当前的 `/Applications/INbox.app` 会保留或恢复。菜单更新无法使用时，重新执行上面的终端命令即可恢复。

### 5. 使用

启动后屏幕右上角会出现一个置顶的**像素宝箱怪**：

- **点击箱体**：读取当前剪贴板，把内容采集进 Obsidian；
- **拖拽箱体**：移动桌宠位置（拖动不会触发采集）；
- **右键**：重新选择 Vault 文件夹，或退出。
- **红色关闭按钮**只隐藏窗口，INbox 会继续运行；
- **菜单栏「显示 INbox」**会重新打开被隐藏的窗口；
- **菜单栏「完全退出」**会结束 INbox 进程。

窗口左上角会显示 macOS 的红黄绿按钮。平时不需要保持窗口展开，可以用菜单栏图标随时找回它。

第一次使用会先让你选择一个 Obsidian Vault 文件夹。采集内容会写入：

```text
<你选择的 Vault>/Universal Capture/YYYY-MM-DD.md
<你选择的 Vault>/Universal Capture/attachments/...
```

### 常见问题

- **「INbox 已损坏，无法打开」**：这通常是 Gatekeeper 的隔离提示，并非真的损坏。用上面的「方式 C」执行 `xattr` 命令即可。
- **找不到窗口 / Dock 里没有图标**时，点菜单栏里的 INbox 图标，再点「显示 INbox」即可重新打开窗口。INbox 默认作为 LSUIElement 桌面悬浮助手运行，Dock 里不会显示图标。
- **想卸载**：把 `/Applications/INbox.app` 移到废纸篓即可；采集的数据保留在你自己的 Obsidian Vault 里，不会被删除。

## Windows

Windows 版本代码已完成，但尚未在 Windows 真机首次编译和交互验证，暂不提供下载。请关注后续 Release。

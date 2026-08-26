# 安装指南

## macOS

文件同时支持 **Apple Silicon（M 系列）和 Intel** 芯片。

### 方式一　终端一键安装（首次安装、旧版升级与恢复）

复制下面这行到「终端」回车：

```bash
curl -fsSL https://raw.githubusercontent.com/YaaLO-o/inbox-capture/main/scripts/install.sh | sh
```

脚本会自动下载最新版、安装到 `/Applications/INbox.app` 并启动。用这种方式安装不会出现「无法验证开发者」的提示。`curl` 下载的文件不会被浏览器附加 macOS 隔离标记，原理和 Homebrew 的 `brew install --no-quarantine` 相同。

如果电脑上还在运行旧版本，执行一次这条命令即可升级到最新版。1.2.0 及以后版本通常在应用内（右键桌宠 → 控制中心 → 检查更新）更新，终端命令保留给首次安装和故障恢复。

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

1.2.0 及以后版本：右键桌宠 →「控制中心」→「检查更新」。INbox 只会在你执行这个动作，或主动运行安装命令时联系 GitHub。日常采集不会发出网络请求。

更新包会先在本机做 SHA-256 校验。下载、校验或替换失败时，当前的 `/Applications/INbox.app` 会保留或恢复。应用内更新无法使用时，重新执行上面的终端命令即可恢复到最新版。

### 5. 使用

启动后屏幕右上角会出现一个置顶的**像素宝箱怪**（Dock 不显示图标）：

- **点击箱体**：读取当前剪贴板，把内容采集进你选择的存储文件夹；
- **拖拽箱体**：移动桌宠位置（拖动不会触发采集）；
- **右键**：打开控制中心、更改存储文件夹、检查更新或退出。
- **控制中心 / 阅读器的红色关闭按钮**会回到悬浮桌宠，INbox 继续运行；
- 找不到窗口时，从 Applications 或 Spotlight 再次打开 INbox 即可唤回；
- 要完全结束进程，右键桌宠 →「退出 INbox」。

第一次使用会让你选择一个**存储文件夹**（任何普通文件夹都可以，也可以是 Obsidian vault）。采集内容会以标准 Markdown 写入：

```text
<你选择的文件夹>/Universal Capture/YYYY-MM-DD.md
<你选择的文件夹>/Universal Capture/attachments/...
```

默认展示方式可以在控制中心切换：应用内只读查看、系统默认 Markdown 应用，或 Obsidian。切换展示方式不会移动或修改任何文件。

### 常见问题

- **「INbox 已损坏，无法打开」**：这通常是 Gatekeeper 的隔离提示，并非真的损坏。用上面的「方式 C」执行 `xattr` 命令即可。
- **找不到窗口 / Dock 里没有图标**时，从 Applications 或 Spotlight 再次打开 INbox 即可。INbox 作为桌面悬浮助手运行，Dock 里不显示图标。
- **想卸载**：把 `/Applications/INbox.app` 移到废纸篓即可；采集的数据保留在你自己选择的存储文件夹里，不会被删除。

## Windows

Windows 版本代码已完成，但尚未在 Windows 真机首次编译和交互验证，暂不提供下载。请关注后续 Release。

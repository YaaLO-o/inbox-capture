# 安装指南

## macOS

### 1. 下载

在 [Releases](https://github.com/YaaLO-o/inbox-capture/releases/latest) 下载最新的 `INbox-<版本>-macos-universal.dmg`。

文件同时支持 **Apple Silicon（M 系列）和 Intel** 芯片。

### 2. 安装

1. 双击打开下载的 `.dmg` 文件；
2. 在弹出的窗口里，把 **INbox** 拖到 **Applications**（应用程序）文件夹；
3. 等待拷贝完成，即可在「应用程序」或 Spotlight 中搜索 `INbox` 启动。

### 3. 首次打开（重要）

当前版本**尚未购买 Apple Developer ID 进行签名和公证**，应用完全在本地运行、不联网，但 macOS 的 Gatekeeper 第一次会拦截。按下面任意一种方式放行即可：

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

### 4. 使用

启动后屏幕右上角会出现一个置顶的**像素宝箱怪**：

- **点击箱体**：读取当前剪贴板，把内容采集进 Obsidian；
- **拖拽箱体**：移动桌宠位置（拖动不会触发采集）；
- **右键**：重新选择 Vault 文件夹，或退出。

第一次使用会先让你选择一个 Obsidian Vault 文件夹。采集内容会写入：

```text
<你选择的 Vault>/Universal Capture/YYYY-MM-DD.md
<你选择的 Vault>/Universal Capture/attachments/...
```

### 常见问题

- **「INbox 已损坏，无法打开」**：这通常是 Gatekeeper 的隔离提示，并非真的损坏。用上面的「方式 C」执行 `xattr` 命令即可。
- **找不到窗口 / Dock 里没有图标**：INbox 是桌面悬浮助手（LSUIElement），默认不显示 Dock 图标和主窗口，只有屏幕上的小桌宠；右键桌宠可以退出。
- **想卸载**：把 `/Applications/INbox.app` 移到废纸篓即可；采集的数据保留在你自己的 Obsidian Vault 里，不会被删除。

## Windows

Windows 版本代码已完成，但尚未在 Windows 真机首次编译和交互验证，暂不提供下载。请关注后续 Release。

# Universal Capture

Universal Capture 是一个本地优先的桌面文本采集工具。它把“随手复制的内容”快速追加到 Obsidian 仓库中的 Markdown 文件。

当前版本只完成最小闭环：

1. 在任意应用中复制文本。
2. 点击桌面上的“收”悬浮按钮。
3. 应用读取当前文本剪贴板。
4. 内容追加到 Obsidian，并短暂显示“已保存”。

## 运行环境

- Windows 10 或 Windows 11（64 位）
- Node.js 22.12.0 或更高版本
- 已安装并至少打开过一次 Obsidian

本项目当前锁定 Electron 43.4.0。

## 启动

在项目目录中运行：

```powershell
npm install
npm start
```

启动后，桌面会出现一个始终置顶的小圆形悬浮入口。拖动按钮周围的空白区域可以调整位置，关闭悬浮窗口即可退出应用。

## 保存位置

应用读取 Obsidian 的本地配置，优先选择当前打开且真实存在的仓库。采集内容保存到：

```text
<Obsidian 仓库>\Universal Capture\captures.md
```

例如，这台开发电脑当前会保存到：

```text
C:\Users\Yangy\Documents\Obsidian Vault\Universal Capture\captures.md
```

如果 `Universal Capture` 文件夹或 `captures.md` 不存在，第一次成功采集时会自动创建。每条内容使用以下格式追加：

```markdown
## 2026-08-16 14:30:00

剪贴板中的原始文本

---
```

如果未找到可用的 Obsidian 仓库，悬浮窗口会提示“未找到 Obsidian 仓库”，不会把内容写到其他位置。

## 隐私

- 只有主动点击悬浮按钮时才读取剪贴板。
- 不在后台监听剪贴板。
- 不连接网络，不上传采集内容。
- 不需要账号，也不包含遥测。

## 测试

运行核心自动化测试：

```powershell
npm test
```

运行真实 Electron 剪贴板到临时 Markdown 文件的冒烟验证：

```powershell
$env:UNIVERSAL_CAPTURE_SMOKE_PATH = Join-Path ([System.IO.Path]::GetTempPath()) 'universal-capture-smoke\captures.md'
npm run smoke
```

验证成功时会显示 `SMOKE_OK`。冒烟验证使用临时文件，不会修改真实 Obsidian 仓库。

## 当前版本暂不包含

- AI 提取或分类
- 云同步
- 图片和 OCR
- 网页来源识别
- 自动去重
- 全局快捷键、系统托盘和开机启动
- 安装包

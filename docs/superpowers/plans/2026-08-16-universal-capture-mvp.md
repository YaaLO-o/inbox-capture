# Universal Capture MVP 实施计划

> **供执行者使用：** 必须使用 `superpowers:executing-plans` 逐项执行本计划，步骤使用复选框跟踪。

**Goal:** 在 Windows 上实现“复制文本 → 点击悬浮入口 → 追加本地 Markdown → 显示反馈”的最小闭环。

**Architecture:** Electron 主进程负责剪贴板、窗口与文件写入，预加载脚本只开放单一采集接口，渲染进程只负责悬浮界面。Markdown 追加与采集协调是无界面依赖的独立模块，使用 Node.js 内置测试框架按测试驱动方式实现。

**Tech Stack:** Electron、CommonJS JavaScript、HTML、CSS、`node:test`、`fs/promises`。

## Global Constraints

- Windows 优先验证，但不使用 Windows 独占接口。
- 不包含 AI、云同步、账号、分类、OCR、链接解析、后台监听和遥测。
- 只有用户主动点击时读取剪贴板。
- 默认保存到 `%USERPROFILE%\Documents\Universal Capture\captures.md`，使用 UTF-8。
- 渲染进程启用上下文隔离并关闭 Node.js 集成。
- 所有用户可见文案和说明使用中文。

---

## 文件结构

- `package.json`：项目命令和 Electron 依赖。
- `src/capture-store.js`：验证文本、格式化记录并追加 Markdown。
- `src/capture-service.js`：协调剪贴板读取与写入。
- `src/main.js`：Electron 生命周期、窗口、IPC 和冒烟模式。
- `src/preload.js`：安全地开放采集方法。
- `src/renderer/*`：悬浮入口和反馈。
- `tests/*.test.js`：核心行为测试。
- `README.md`：中文使用说明。

### Task 1：Markdown 追加写入核心

**Files:**
- Create: `package.json`
- Create: `tests/capture-store.test.js`
- Create: `src/capture-store.js`

**Interfaces:**
- Produces: `appendCapture({ text, capturedAt, filePath }): Promise<{status: 'saved', filePath} | {status: 'empty'}>`

- [ ] **Step 1：创建测试命令并安装 Electron**

`package.json` 设置 `main` 为 `src/main.js`，并加入 `start: electron .`、`test: node --test`、`smoke: electron . --smoke-test`。运行 `npm install --save-dev electron` 生成锁文件。

- [ ] **Step 2：先写失败测试**

`tests/capture-store.test.js` 使用 `fs.mkdtemp` 创建真实临时目录，固定时间为 `new Date(2026, 7, 16, 14, 30, 5)`，断言中文多行文本最终得到以下手写结果：

```text
## 2026-08-16 14:30:05

第一行
第二行中文

---

```

同时加入两个独立测试：空白字符串返回 `{ status: 'empty' }` 且不创建文件；连续写入“第一条”和“第二条”时两条记录按顺序保留。

- [ ] **Step 3：确认测试因生产模块缺失而失败**

Run: `npm test -- tests/capture-store.test.js`

Expected: FAIL，包含 `Cannot find module '../src/capture-store'`。

- [ ] **Step 4：编写最小实现**

`src/capture-store.js` 使用以下接口和核心行为：

```js
async function appendCapture({ text, capturedAt, filePath }) {
  if (typeof text !== 'string' || text.trim().length === 0) return { status: 'empty' };
  await fs.mkdir(path.dirname(filePath), { recursive: true });
  const entry = `## ${formatTimestamp(capturedAt)}\n\n${text}\n\n---\n\n`;
  await fs.appendFile(filePath, entry, 'utf8');
  return { status: 'saved', filePath };
}
```

`formatTimestamp` 用本地时间生成固定的 `YYYY-MM-DD HH:mm:ss`，各数字字段使用 `padStart(2, '0')`。

- [ ] **Step 5：运行测试并提交**

Run: `npm test -- tests/capture-store.test.js`

Expected: 3 tests passed，0 failed。

Commit: `git commit -m "feat: add Markdown capture store"`

### Task 2：可测试的剪贴板采集流程

**Files:**
- Create: `tests/capture-service.test.js`
- Create: `src/capture-service.js`

**Interfaces:**
- Consumes: `appendCapture({ text, capturedAt, filePath })`
- Produces: `captureCurrentClipboard({ readText, append, filePath, now }): Promise<CaptureResult>`

- [ ] **Step 1：先写三个结果分支的测试**

成功与空文本分支使用真实 `appendCapture` 和临时文件；写入失败分支注入一个抛出 `new Error('disk full')` 的函数，只隔离无法安全制造的磁盘故障。分别断言：真实文件包含剪贴板中文；空文本不创建文件；异常转换为 `{ status: 'error', message: 'disk full' }`。

- [ ] **Step 2：确认测试因模块缺失而失败**

Run: `npm test -- tests/capture-service.test.js`

Expected: FAIL，包含 `Cannot find module '../src/capture-service'`。

- [ ] **Step 3：实现最小采集协调函数**

```js
async function captureCurrentClipboard({ readText, append, filePath, now }) {
  try {
    return await append({ text: readText(), capturedAt: now(), filePath });
  } catch (error) {
    return { status: 'error', message: error instanceof Error ? error.message : String(error) };
  }
}
```

- [ ] **Step 4：运行全部测试并提交**

Run: `npm test`

Expected: 6 tests passed，0 failed。

Commit: `git commit -m "feat: add clipboard capture service"`

### Task 3：Electron 悬浮入口

**Files:**
- Create: `src/main.js`
- Create: `src/preload.js`
- Create: `src/renderer/index.html`
- Create: `src/renderer/styles.css`
- Create: `src/renderer/renderer.js`

**Interfaces:**
- Renderer bridge: `window.universalCapture.captureClipboard(): Promise<CaptureResult>`
- IPC channel: `capture:clipboard`

- [ ] **Step 1：建立最小安全桥接**

`src/preload.js` 使用 `contextBridge.exposeInMainWorld`，只暴露 `captureClipboard: () => ipcRenderer.invoke('capture:clipboard')`。

- [ ] **Step 2：实现主进程和真实保存路径**

`src/main.js` 创建 116×132、透明、无边框、始终置顶、不可缩放且不显示在任务栏的窗口。启用 `contextIsolation: true`、`nodeIntegration: false`。IPC 处理器使用 `clipboard.readText()`，保存路径通过 `path.join(app.getPath('documents'), 'Universal Capture', 'captures.md')` 得到。

冒烟模式检测 `--smoke-test`：把“通用采集器冒烟测试”写入 Electron 剪贴板，通过同一个 `captureCurrentClipboard` 写到 `UNIVERSAL_CAPTURE_SMOKE_PATH`，读取文件确认文本后输出 `SMOKE_OK` 并退出；错误时设置非零退出状态。

- [ ] **Step 3：实现中文悬浮界面**

外层使用 `-webkit-app-region: drag`，圆形按钮使用 `no-drag`。默认显示“收”和“点击保存”。点击时禁用按钮，调用桥接方法，将 `saved`、`empty`、`error` 映射为“已保存”“剪贴板没有文本”“保存失败”，1200 毫秒后恢复。

- [ ] **Step 4：验证并提交桌面入口**

Run: `npm test`

Expected: 6 tests passed，0 failed。

Run: `npm start`

Expected: Windows 桌面出现可拖动的置顶悬浮入口，关闭窗口后应用退出。

Commit: `git commit -m "feat: add floating Electron capture entry"`

### Task 4：真实剪贴板冒烟验证与中文说明

**Files:**
- Create: `README.md`
- Modify: `package.json`
- Modify: `package-lock.json`

**Interfaces:**
- Consumes: `npm test`、`npm run smoke`、`npm start`

- [ ] **Step 1：运行隔离的剪贴板闭环验证**

将 `UNIVERSAL_CAPTURE_SMOKE_PATH` 指向系统临时目录下明确的 `universal-capture-smoke/captures.md`，执行 `npm run smoke`。断言进程状态为 0、输出包含 `SMOKE_OK`、文件包含“通用采集器冒烟测试”和时间标题。验证后仅删除这一个已核对的临时目录。

- [ ] **Step 2：编写中文 README**

说明项目用途、`npm install` 与 `npm start`、默认保存位置、“复制后点击悬浮按钮”的操作流程、本地隐私、测试命令和当前不包含的功能。

- [ ] **Step 3：最终验证**

Run: `npm test`

Expected: 6 tests passed，0 failed。

Run: `npm run smoke`

Expected: `SMOKE_OK`，退出状态为 0。

Run: `git diff --check` 和 `git status --short`

Expected: 没有空白错误，只有预期收尾文件。

- [ ] **Step 4：提交说明**

Commit: `git commit -m "docs: add Windows MVP usage guide"`

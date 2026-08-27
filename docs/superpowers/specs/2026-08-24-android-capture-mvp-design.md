# Android Capture MVP 设计

日期：2026-08-24

状态：已批准，待实施计划
分支：`feature/android-capture-mvp`

## 1. 目标

在现有 INbox Flutter 主工程中增加 Android 平台实现，验证移动端高频内容消费场景中的低摩擦 Capture：用户通过系统分享或屏幕边缘悬浮球，将文字、URL、图片、PDF、视频和普通文件保存到用户选择的本地 Obsidian Vault。

Android 与 macOS 必须生成同一种 Raw Capture 数据：

```text
<Vault>/
└── Universal Capture/
    ├── YYYY-MM-DD.md
    └── attachments/
```

每条 Capture 继续使用：

```markdown
## HH:mm

<!-- capture:id=... -->

内容

---
```

文字写入 Markdown 正文；图片保存到 `attachments/` 后使用 Obsidian embed；PDF、视频和普通文件保存到 `attachments/` 后使用普通 Obsidian link。Markdown 与普通附件文件是 source of truth。

## 2. 范围

本轮包含：

- Android API 29 及以上，首要真机为 Xiaomi 13 Pro、Android 16、HyperOS 3.1。
- 个人侧载 APK，不在本轮处理 Google Play 或小米应用商店上架。
- Android Storage Access Framework Vault 选择与持久授权。
- 文字、URL、图片、PDF、视频和普通文件 Share Target。
- 前台 translucent Activity 读取文字剪贴板的技术验证。
- 可拖动、吸边的小型 overlay Capture 入口。
- 最小白底设置页、权限状态和悬浮服务开关。
- Shared Core、Android 构建、模拟器、真机与 macOS 回归测试。

本轮不包含 AI 分类、AI 摘要、embedding、搜索、同步、账户、后端、数据库、插件市场、Obsidian 插件、内容去重、复杂管理页、历史列表、剪贴板图片 Capture、Accessibility Service、开机自启和危险后台保活。

## 3. 已确认环境

设计阶段检查结果：

- Flutter 3.47.1 正常。
- Dart 3.13.1 正常。
- 仓库工作区干净。
- Flutter 工程当前只有 macOS 和 Windows target，没有 `android/` 目录。
- Android Studio、Android SDK、JDK、ADB 和 Android Emulator 尚未安装或不可用。
- `flutter doctor -v` 报告 Android SDK 缺失。
- `flutter devices` 只有 macOS 和 Chrome。

实现 Android target、licenses、APK 构建和设备测试前，用户需要通过 Android Studio 首次安装向导安装 Android SDK、Platform Tools、JDK 与一个 Emulator system image。实现过程不擅自修改系统环境。

## 4. 设计原则

### 4.1 唯一 Capture Core

Capture ID、附件命名、类型规则、Markdown 格式、Capture 编排和快速点击防重只保留一份 Dart 实现。Android 不复制第二套 Markdown formatter。

### 4.2 平台能力通过 adapter 隔离

桌面继续使用普通 filesystem path。Android SAF 使用 tree URI、`ContentResolver` 和 `DocumentFile`。tree URI 绝不转换成伪 filesystem path。

### 4.3 大文件不经过 MethodChannel 搬运

图片、PDF、视频和普通文件的 `content://` URI 与元数据传给 Dart 编排层；实际字节由 Kotlin 在 URI 临时授权有效期间流式复制到 SAF Vault。MethodChannel 不传输大文件字节。

### 4.4 用户主动触发

Share、Vault 选择和悬浮球点击都由用户明确触发。不轮询剪贴板，不在后台偷偷读取，不使用 Accessibility Service。

### 4.5 失败不生成悬空引用

附件全部复制成功后才追加 Markdown。任一附件失败则整条 Capture 失败，并尽量删除本次已经复制的附件。Markdown append 失败时同样回滚本次附件。

## 5. 架构

```text
CaptureInput
    ↓
CaptureCoordinator
    ├── Capture ID / 500ms 防重复
    ├── 附件命名与类型判断
    ├── MarkdownFormatter
    └── VaultStorage
             ├── DesktopFileVaultStorage
             └── AndroidSafVaultStorage
```

### 5.1 Shared Dart Core

#### CaptureInput

描述一次已标准化的采集输入：

- 可选文字。
- 零个或多个附件来源。
- 附件显示名、MIME 类型和安全扩展名。
- 平台附件 source token。桌面可以是本地路径，Android 可以是临时 `content://` URI。

`CaptureInput` 不负责打开附件。

#### MarkdownFormatter

纯 Dart、无 I/O。输入 `Capture`，输出完整 Capture section。它是所有平台唯一的 Markdown 格式定义。

格式要求：

- 标题只包含分钟级 `HH:mm`。
- ID 使用隐藏 HTML comment。
- 文字 trim 后写入正文。
- 图片使用 `![[attachments/<name>]]`。
- 非图片使用 `[[attachments/<name>|<safe display name>]]`；无显示名时省略 alias。
- section 以 `---` 和空行结束。

#### CaptureCoordinator

负责：

1. 将 Capture 请求串行化。
2. 应用现有 500ms 快速点击防重规则。
3. 生成 Capture ID。
4. 为多附件生成同一 ID 加序号的文件名。
5. 要求 `VaultStorage` 确保目录存在。
6. 导入所有附件。
7. 调用 `MarkdownFormatter`。
8. append 当日 Markdown。
9. 失败时回滚本次附件并返回明确状态。

它不理解 filesystem path、SAF 或 Android Activity 生命周期。

#### VaultStorage

异步接口，最小能力包括：

- 查询 Vault 是否已配置和仍可访问。
- 确保 `Universal Capture/attachments` 布局存在。
- 导入一个附件 source token 到指定附件文件名。
- 将文本追加到指定日期的 `.md` 文件并 flush。
- 删除本次失败操作已创建的附件。
- 提供用户可读 Vault 显示名称。

### 5.2 DesktopFileVaultStorage

从现有 `StorageService` 提取。继续使用 `dart:io` 与绝对路径，保持 macOS/Windows 当前写入行为。拆分只服务于平台边界，不改变桌面数据协议或 UI。

### 5.3 AndroidSafVaultStorage

Dart adapter 通过 MethodChannel 调用 Kotlin SAF 实现。Kotlin 侧保存 tree URI，并用 `DocumentFile`/`ContentResolver`：

- 查找或创建 `Universal Capture`。
- 查找或创建 `attachments`。
- 通过输入流和输出流复制分享附件。
- 创建或查找 `YYYY-MM-DD.md`。
- 使用可 append 的文件描述符或可靠的 read-modify-write fallback 追加 Markdown。
- flush 并关闭所有流。

如果具体 DocumentsProvider 不支持可靠 append，fallback 必须先读出现有 Markdown，再写回“原内容 + 新 section”；写回失败要返回错误，不能覆盖为空。此 fallback 只用于 Markdown 小文本文件，不用于附件。

## 6. Android 原生组件

```text
InboxApplication
└── 单个应用级 FlutterEngine + Dart Core

MainActivity
└── 最小设置页面

ShareCaptureActivity
└── ACTION_SEND / ACTION_SEND_MULTIPLE

ClipboardCaptureActivity
└── 取得前台焦点后读取 Clipboard

OverlayService
└── WindowManager 小圆点与 foreground notification

AndroidCaptureBridge
└── 原生组件与 Dart Core 的命令/结果通道
```

### 6.1 Flutter engine

应用进程使用一个缓存 Flutter engine。MainActivity、ShareCaptureActivity 和 ClipboardCaptureActivity 将任务送到同一个 Dart Core，避免多个 isolate 并发写同一个日记文件。

Dart 初始化完成后通过 ready handshake 通知原生层。原生 Capture Activity 在 ready 前排队等待；超时则显示失败并退出，不能永久停留在透明页面。

### 6.2 AndroidCaptureBridge

桥接协议使用结构化 map，至少区分：

- Capture 来源：`share` 或 `clipboard`。
- 文字内容。
- 附件 URI、MIME、显示名和扩展名。
- 任务 ID。
- 结果：`saved`、`empty`、`vaultUnavailable`、`permissionDenied`、`error`。

所有异常转换成稳定错误码与简短用户消息；原生堆栈只写本地日志。

## 7. Vault 配置

用户在设置页点击选择 Vault 后执行：

```text
ACTION_OPEN_DOCUMENT_TREE
→ 用户选择 Obsidian Vault
→ takePersistableUriPermission(read | write)
→ 验证 tree URI 可读写
→ 创建/确认 Universal Capture 与 attachments
→ 保存 tree URI 和显示名称
```

Android 原生层在 SharedPreferences 中保存 tree URI 字符串和显示名称。恢复时同时检查：

- URI 存在于 `ContentResolver.persistedUriPermissions`。
- 授权包含读写能力。
- `DocumentFile` 仍存在且可写。

授权失效时标记 Vault 不可用并要求重新选择。不自动选择其他目录，不创建伪路径，不申请 `MANAGE_EXTERNAL_STORAGE`。

## 8. Share Target

Manifest 注册 `ACTION_SEND` 与 `ACTION_SEND_MULTIPLE`，覆盖：

- `text/plain` 与 URL。
- `image/*`。
- `video/*`。
- `application/pdf`。
- 可由 `*/*` 接收的普通文件 URI。

ShareCaptureActivity 的流程：

1. 校验 Intent action。
2. 从 `EXTRA_TEXT`、`EXTRA_STREAM` 与 `ClipData` 提取内容。
3. 对 URI 读取 `DISPLAY_NAME` 和 MIME；安全解析扩展名。
4. 等待 Dart Core ready。
5. 调用 `CaptureCoordinator`。
6. 在 Activity 结束前完成所有 URI 流式复制。
7. 成功后显示短 Toast 并 `finish()`，返回来源 App。

`ACTION_SEND_MULTIPLE` 的附件共享同一 Capture ID，文件名用 `-0`、`-1` 等稳定序号避免冲突。

Vault 未配置或授权失效时，ShareCaptureActivity 转到最小设置页并提示用户配置后重新分享。本轮不缓存待处理 Share，以免引入数据库或隐式临时仓库。

URI 无法读取、没有可用内容或任一附件复制失败时不写 Markdown。

## 9. Clipboard Capture 技术验证

Android 10 及以上只有当前获得焦点的 App 或默认输入法可以读取剪贴板。第一版验证：

```text
用户点击 overlay
→ 启动 translucent ClipboardCaptureActivity
→ 等待 Activity 取得 window focus
→ ClipboardManager 读取文字
→ CaptureCoordinator 保存
→ 反馈
→ Activity finish
```

ClipboardCaptureActivity 不显示完整 INbox 页面，只提供透明或半透明的瞬时 surface。读取仅发生一次，只接受非空文字或 URL。

Android/HyperOS 可能显示系统剪贴板隐私提示，这是允许且不可规避的系统反馈。

如果 Xiaomi 13 Pro 上 Activity 已获得焦点但仍不能稳定读取剪贴板，停止继续堆叠 workaround。记录 Android 版本、焦点状态、读取结果和系统日志，在最终报告中说明限制。不得引入 Accessibility Service、输入法身份、后台轮询或危险权限。

## 10. Overlay Service

悬浮球只允许从可见 MainActivity 中由用户主动开启：

1. 检查 Vault 可用。
2. 检查 `Settings.canDrawOverlays()`。
3. 未授权时跳转系统 overlay 授权页。
4. 回到 App 后再次确认授权。
5. 在 App 仍可见时启动 foreground service。
6. Service 发布通知并通过 `WindowManager` 添加 `TYPE_APPLICATION_OVERLAY` view。

不从后台或 `BOOT_COMPLETED` 启动 foreground service。

Android 14 及以上使用 `specialUse` foreground service type，并在 Manifest 中声明其用途为用户主动开启的持续 Capture overlay。声明对应 foreground service 权限。

悬浮球行为：

- 可见圆点约 30–32dp，透明触控区域约 48dp。
- 默认停靠右侧中部。
- 拖动跟随手指。
- 位移低于阈值视为点击，否则视为拖动。
- 松手后吸附最近的左右边缘。
- 不覆盖状态栏、导航栏、刘海或手势安全区。
- 屏幕旋转和可用区域变化后重新约束坐标。
- 拖动位置保存在本地设置中。
- 保存成功时短暂缩放或变色，随后恢复。
- 空剪贴板与错误使用短 Toast 或轻微失败反馈。

foreground notification 提供停止操作。停止时删除 overlay view、更新设置状态并结束 Service。Service 被系统终止时不使用后台保活 hack；用户重新打开设置页恢复。

手机重启后不自动恢复 overlay。用户需要重新打开 INbox 并开启。

## 11. Android 设置页

Android 主页面为白底、黑字的最小设置页：

```text
INbox

Vault
已选择：<目录显示名称>
[重新选择 Vault]

悬浮 Capture
状态：已停止 / 运行中
[开启悬浮球] 或 [停止悬浮球]

权限
Vault 访问         已授权 / 需重新选择
显示在其他应用上层  已授权 / 去授权
通知               已授权 / 去设置
```

页面不展示 Capture 历史、文件列表、分类、搜索或管理功能。Android 不复用 Mac 像素宝箱桌宠 UI。

## 12. 权限

仅声明或请求：

- SAF tree URI 持久读写授权。
- `SYSTEM_ALERT_WINDOW`。
- `FOREGROUND_SERVICE`。
- Android 14+ 对应的 `FOREGROUND_SERVICE_SPECIAL_USE`。
- Android 13+ `POST_NOTIFICATIONS`。

拒绝 `POST_NOTIFICATIONS` 不阻止 foreground service 启动，但设置页显示通知未授权。系统仍可在任务管理界面展示 foreground service。

不声明或请求：

- `MANAGE_EXTERNAL_STORAGE`。
- Accessibility Service。
- 全量媒体库读取权限。
- 后台剪贴板能力。
- 开机启动。
- 电池优化白名单强制跳转。

HyperOS 如果主动限制后台运行，先通过真机观察事实；本轮不自动引导高风险厂商专有设置。

## 13. 错误处理与一致性

### Vault 不可用

禁止 Capture，返回 `vaultUnavailable`，设置页显示重新选择入口。

### Overlay 权限撤销

Service 删除悬浮 view、停止自身并将运行状态设为 false。

### Share URI 读取失败

整条 Capture 失败，不追加 Markdown。已复制附件进入回滚。

### Markdown append 失败

删除本次已经复制的附件。若删除也失败，保留无引用附件并记录日志，但结果仍为失败。

### Flutter engine 未就绪

Capture Activity 等待有限时间后失败退出，不显示永久透明层。

### 重复或并发请求

Dart coordinator 使用单队列执行。500ms 内的重复点击继续返回“操作过于频繁”；不做内容去重。

## 14. 测试策略

所有功能按 TDD 推进，先写失败测试，再写最小实现。

### 14.1 Shared Dart 测试

- `MarkdownFormatter` 精确输出文字、图片、PDF、视频、普通文件与多附件。
- macOS、Windows、Android 等价输入生成相同 Capture section。
- Capture ID、附件命名和序号。
- MIME 与扩展名分类。
- 显示名清理。
- 500ms 快速点击防重。
- 串行 Capture 顺序。
- 单个附件失败、append 失败和回滚。
- Vault 未配置与授权失效状态。

### 14.2 Flutter UI 与 channel 测试

- Android 设置页的 Vault、overlay 和通知状态。
- 选择/重新选择 Vault。
- 开启/停止悬浮服务。
- 用户拒绝权限时不崩溃。
- MethodChannel 参数与结果 contract。

### 14.3 Kotlin/Android 测试

- `ACTION_SEND`/`ACTION_SEND_MULTIPLE` Intent 解析。
- `EXTRA_TEXT`、`EXTRA_STREAM` 与 `ClipData` 归一化。
- MIME、显示名和扩展名提取。
- overlay 点击/拖动阈值与吸边坐标。
- ready handshake、超时和错误映射。
- 可自动化范围内的 SAF 目录创建、附件复制和 Markdown append。

### 14.4 构建与回归

最终必须通过：

```bash
dart analyze lib test
flutter test
flutter build apk --debug
flutter build macos --debug
```

已有 macOS 测试必须继续通过，Markdown 输出不得变化。

### 14.5 Emulator 验证

Android SDK 与 emulator 可用后验证：

- APK 安装与启动。
- Vault 选择与重启恢复。
- 文字 Capture。
- Share text、image 和 file。
- overlay 开关、拖动与权限拒绝。
- App 重启后的授权状态。

### 14.6 Xiaomi 13 Pro 真机验证

- 选择 Android Obsidian 正在使用的 Vault。
- 保存文字与 URL。
- 分享单图、多图、PDF、视频和普通文件。
- Obsidian 中查看 Markdown、图片 embed 和附件链接。
- translucent Activity 剪贴板读取。
- overlay 开启、拖动、吸边、点击、反馈和停止。
- 拒绝 overlay/通知权限。
- HyperOS 清理后台后的行为。
- 手机重启后 overlay 不自动启动。

系统目录选择器、Sharesheet、overlay、HyperOS 后台策略和 Obsidian 展示以真机人工结果为准。不能可靠自动化的项目必须列入最终人工验证清单。

## 15. 实施阶段与阶段门槛

### A. 环境

安装 Android Studio/SDK/JDK/Platform Tools/Emulator，运行 `flutter doctor -v`、`flutter devices`、`adb devices` 和 Android licenses。Android toolchain 正常后进入 B。

### B. Android target

生成现有 Flutter 工程的 Android target，启动最小设置页。构建与启动成功后进入 C。

### C. Shared Core 与 SAF

用测试驱动拆分 formatter/coordinator/storage adapter，在 emulator 或真机选择 Vault 并写出第一条 Markdown。桌面测试保持通过后进入 D。

### D. Share text

完成 text/plain 与 URL 分享，验证保存后返回原 App。

### E. Share attachments

完成单个和多个图片、PDF、视频及普通文件流式复制与 Markdown 引用。

### F. Clipboard 技术验证

先独立验证 translucent Activity 的前台焦点和 Clipboard 结果。可靠才进入 G；不可靠则停止并报告。

### G. Floating Bubble

接入正规 overlay、foreground service、拖动、吸边、点击 Capture、反馈和停止。

### H. 完整验收

执行 analyze、Flutter tests、Android build、Android tests、emulator、Xiaomi 13 Pro、Android Obsidian 与 macOS 回归。

每阶段通过自己的验证门槛后才能进入下一阶段，不能一次写完再集中测试。

## 16. 完成标准

Android MVP 完成必须满足：

- Android App 可安装启动。
- 可选择本地 Vault。
- URI permission 重启后有效。
- 可保存文字 Markdown。
- 可分享文字、图片和普通文件给 INbox。
- 图片与文件真实落盘。
- Android Obsidian 可直接查看。
- 悬浮入口完成真机技术验证；若系统限制阻塞，报告可复现事实且不引入高风险权限。
- Mac 原功能没有回归。
- analyze、tests、Android debug build 和 macOS debug build 通过。

完成后不继续开发 AI、分类、同步或插件系统。所有 Android MVP 修改提交到 `feature/android-capture-mvp`，不合并 `main`。

## 17. 最终报告

实施结束后报告：

1. Android 环境状态。
2. 实际实现能力。
3. 使用的 Android 原生 API。
4. Vault 保存与权限恢复方式。
5. Xiaomi 13 Pro 上 clipboard overlay Capture 的实际结果。
6. Share Target 支持类型。
7. 自动测试结果。
8. Emulator 测试结果。
9. 需要用户真机验证的项目。
10. Mac 回归测试结果。
11. 尚未合并 `main` 的提交列表。

报告后停止，等待用户实际使用 Android MVP 并决定是否合并及下一阶段。

# Android Capture MVP 验证记录

日期：2026-08-26

分支：`feature/android-capture-mvp`

发布边界：Android 10（API 29）及以上，个人侧载，不含商店发布、开机自启、后台剪贴板轮询或云同步。

## 已实现范围

- 系统目录选择器授权 Obsidian Vault，并持久保存 SAF 权限。
- 共享 Capture Core 按设备当天日期追加 `Universal Capture/YYYY-MM-DD.md`；当天文件不存在时由应用自动创建。
- Share Target 支持文字、URL、单图、多图、PDF、视频和普通文件。
- 图片写入 `attachments/` 并生成 Obsidian embed；其他附件生成普通链接。
- 用户主动开启的悬浮球在点击时读取一次当前剪贴板，支持拖动、吸边、反馈和停止。
- overlay 前台服务不注册 boot receiver，不随手机开机自动启动。

## 自动化与构建

代码修复完成后从干净状态执行过以下完整套件：

| 检查 | 结果 |
| --- | --- |
| `dart analyze lib test` | 通过，0 问题 |
| `flutter test` | 通过，126/126 |
| `flutter build apk --debug` | 通过，生成 `app/build/app/outputs/flutter-apk/app-debug.apk` |
| `flutter build macos --debug` | 通过，生成 `app/build/macos/Build/Products/Debug/INbox.app` |
| `./gradlew testDebugUnitTest` | 通过 |
| API 36 `connectedDebugAndroidTest` | 收尾 scoped 回归通过，28/28，0 跳过、0 失败；临时 manual harness 已删除 |

完整套件之后没有修改运行时实现，因此文档收尾没有重复执行 Flutter 与 macOS 全矩阵。

## Pixel 6 API 36 模拟器

- 在全新 SAF Vault 中，选择目录后仅创建固定目录结构，没有预建当天 Markdown。
- 通过生产 Share Activity 发送文字时，Dart 使用当前日期 `2026-08-26`，应用自行创建 `2026-08-26.md`。
- 重复 Share 与强制停止后重新启动均追加到同一个文件，Vault SAF 配置保持有效。
- 图片和普通文件 Share 成功，来源与目标 SHA-256 一致。
- overlay 权限拒绝、开启、拖动、吸边、通知与停止路径通过。
- 拖到顶部和底部时保持在 WindowManager 可用区域内，未复现进入状态栏或手势区。

## Xiaomi 13 Pro 与 Obsidian

设备：Xiaomi 13 Pro `nuwa` / `2210132C`，Android 16（API 36），HyperOS `OS3.0.310.0.WMBCNXM`。测试 Vault 为 `测试`，显示覆盖为 1080×2400 / 420 dpi。

- 跨日首次 Capture 已真机确认：应用根据当天日期自动创建缺失的 `2026-08-26.md`，随后 Capture 追加同一文件。修复提交为 `13172dd`。
- URL、单图、PDF、视频和普通文件经生产 Share Activity 写入成功。
- 本轮来源与目标附件 SHA-256 一致：图片 `7401cf…`、PDF `ea6c5b…`、视频 `985632…`、普通文件 `e97813…`。
- 多图 Share 已在 Task 1–7 的 Xiaomi 真机验收中通过并确认附件 SHA-256；本次收尾未重复扩展测试。临时多图 instrumentation harness 因 HyperOS 生命周期卡住未产生文件增量，已删除且不计作通过证据。
- Markdown 中图片使用 `![[attachments/...]]`，PDF、视频和普通文件使用安全显示名的普通链接。
- Obsidian 1.13.8 通过 Vault deep link 打开 `Universal Capture/2026-08-26`：图片在阅读视图中渲染，PDF、视频和普通文件均显示为指向对应附件的可点击链接。
- 重装与进程重启后的实际 Share 继续使用已保存 Vault 授权；当前检查中 INbox 无残留 Activity 或前台服务。
- Task 9 已完成手机重启后 overlay 不自启的验收，本次收尾未重复重启真机。

## 已知 P2

- 当 INbox 在后台时撤销 overlay 权限，HyperOS 上前台服务和通知可能继续显示，直到应用下次恢复后清理。该问题不影响 Capture 数据正确性，不阻塞 MVP。
- 悬浮球使用真实系统窗口区域的额外 OEM inset 覆盖仍保留在 backlog；Pixel 6 API 36 模拟器未复现球进入状态栏或手势区。

## 结论

Android Capture MVP 的数据路径、SAF 持久化、日期文件自动创建、Share 类型、悬浮球入口和 Obsidian 展示均达到个人侧载交付标准。上述 P2 不影响 Capture 数据完整性，留待后续稳定性迭代。

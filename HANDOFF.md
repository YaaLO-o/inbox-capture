# Android Capture MVP 最终交接

更新时间：2026-08-26

工作目录：`/Users/mac/Desktop/ai/个人/INbox/.worktrees/android-capture-mvp`

分支：`feature/android-capture-mvp`

## 当前状态

Task 1–10 已完成，Android MVP 已达到个人侧载交付状态。不要重新调查已闭环的跨日 P1，也不要在收尾阶段扩大 scope。

- Task 1–9 的 Capture Core、事务回滚、SAF Vault、Android bridge、Share Target 和悬浮球均已完成。
- 跨日首次 Capture 会由应用读取当天日期，并在当天 Markdown 不存在时自动创建；没有人工预建文件。HyperOS Binder 丢失异常 cause 的兼容修复提交为 `13172dd`，已真机验证。
- 完整自动化、构建、模拟器、Xiaomi Share 和 Obsidian 验收结果见 `docs/android-mvp-verification.md`。
- 所有临时诊断和 manual instrumentation harness 均已删除。

## 保留的 P2 backlog

1. INbox 位于后台时撤销 overlay 权限，HyperOS 可能保留 FGS 与通知，直到应用下次恢复后清理；不影响 Capture 数据正确性。
2. 悬浮球进入状态栏或手势区的问题在 Pixel 6 API 36 模拟器不可复现，保留真实 OEM WindowInsets 覆盖。
3. Windows 真机首次编译与交互、公开商店发布、签名和公证仍属于 Android MVP 之外的后续工作。

## 产品边界

Android 当前为 API 29+ 个人侧载 MVP。不做开机自启、Accessibility、后台剪贴板轮询、输入法剪贴板历史、AI 分类、云同步、分身或工作资料适配。未经用户要求不要 merge `main` 或 push。

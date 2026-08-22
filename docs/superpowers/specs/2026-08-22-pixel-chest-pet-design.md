# INbox 像素宝箱怪设计规格

## 状态

角色与交互方向已在 2026-08-22 获得确认。本文件等待书面规格评审，评审通过后再编写实现计划。

## 目标

INbox 将现有圆形 Capture 入口换成一个安静合着的像素宝箱怪。用户复制内容后点击箱体，宝箱打开并把一张抽象纸片吞进去。保存成功时箱盖啪嗒合上，失败时纸片卡住并出现短提示。

这个桌宠仍是 Capture UI。它不引入养成、聊天、全局键鼠监听或新的内容处理流程。

设计遵守四项原则。

- Capture first
- Character second
- Low friction
- Low distraction

## 工程边界

桌宠替换 `app/lib/ui/capture_pill.dart` 的视觉、动画和局部手势层。它继续接收 `vaultPath`、`CaptureService` 和 `onChangeVault`，点击后继续调用 `CaptureService.captureNow(vaultPath)`。

下列部分保持不动。

- `CaptureService`
- `ClipboardService`
- `StorageService`
- Capture 数据模型与 Markdown 格式
- Vault 选择、验证和持久化
- macOS 与 Windows 剪贴板适配器
- `com.inbox.app/settings` MethodChannel 契约
- onboarding 分流

动画只消费 `CaptureResult`。动画代码不直接读取剪贴板，不写 Vault，也不解释 Capture 内容。

```text
PixelChestPet
  -> CaptureService.captureNow(vaultPath)
  -> CaptureResult
  -> PetAnimationState
```

## 角色定义

第一版角色采用「咔嗒锁舌」。

它是一只紧凑方形的像素宝箱怪。闭合时首先被识别成宝箱，只有箱盖缝里的眼睛和中央锁舌透露生命感。锁舌同时承担锁扣、舌头和 Capture 记号。怪感来自箱缝其实是嘴，以及两只略不对称的眼睛。牙齿保持很短，上颚两颗，下颚三颗。Idle 最多露出一像素牙尖。

角色不使用长舌、大嘴、密集尖牙、黏液或持续红眼。它也不借用任何具体游戏 IP 的宝箱怪轮廓、配色或动作。

## 比例与像素网格

每一帧使用固定的 32 × 32 px 画布。角色闭合轮廓约占 24 × 20 px，按三倍整数缩放后约为 72 × 60 逻辑像素。开箱动作可以占用画布上方空间，但所有帧的锚点与底边位置保持一致。

宠物继续放在现有 132 × 132 逻辑像素窗口中。角色动画区域为 96 × 96，错误提示占用下方剩余空间。第一版不根据动画临时改变窗口尺寸。

渲染必须使用整数倍缩放和最近邻采样。角色不能在动画过程中落到半像素位置。

## 颜色

第一版使用低饱和暖色箱体与少量冷色 Capture 提示。

| 用途 | 色值 |
| --- | --- |
| 深色轮廓 | `#2B1D32` |
| 胡桃木暗面 | `#6B3F2A` |
| 胡桃木亮面 | `#9B6240` |
| 黄铜主体 | `#C9903B` |
| 黄铜高光 | `#E8C268` |
| 琥珀眼睛 | `#F3A43B` |
| Capture 冷色提示 | `#69C6D4` |
| Error 珊瑚色 | `#C85B5B` |
| 纸片 | `#E9E0CF` |

Success 只让锁扣亮一帧黄铜高光。Error 只在眼睛和卡住的纸片边缘使用珊瑚色，不让整个角色闪红。

## 状态机

第一版使用以下最小状态。

```text
Idle
  -> Capturing
  -> Success | Error
  -> Idle
```

`CaptureStatus.empty` 走 Error 动画族中的轻量空嚼变体，不新增独立宠物状态。`CaptureStatus.error` 走纸片卡住变体。

Capturing 期间再次点击箱体不会启动第二次 Capture。拖动与右键菜单仍然可用。

## Idle

默认帧是一只完全合上的宝箱。画面没有常驻文字、光晕或呼吸循环。

角色进入 Idle 二十至四十五秒后播放一次两帧单眼眨动，随后重新随机等待。每次 Capture 完成后重新计时。第一版不加入箱盖持续抖动、睡眠、长时间待机姿势或自主移动。

## Capturing

用户点击箱体后立即进入 Capturing，不等待剪贴板读取完成才开始反馈。

动作使用六至七帧，约 360 毫秒完成。

1. 锁扣向前弹一格。
2. 箱盖快速抬起。
3. 箱盖缝中的眼睛完全出现。
4. 一张浅色像素纸片从角色上方偏前的位置进入画面。
5. 纸片折叠并缩小。
6. 纸片被吸入箱内。
7. 箱口停在等待结果的姿势。

纸片代表一次 Capture，不显示真实剪贴板内容，也不区分文字、图片和文件。

如果 `CaptureService` 在吞入动作结束前返回，结果先暂存，吞入动作完成后再进入结果状态。如果服务仍未返回，箱口在两个幅度很小的等待帧之间切换，单帧约 180 毫秒。等待动画不增加粒子、旋转图标或文字。

## Success

Success 使用三至四帧，约 440 毫秒完成。

1. 箱体向下压一格。
2. 箱盖快速合上。
3. 锁扣啪嗒扣住并亮一帧。
4. 闭合姿势停留约 160 毫秒后回到 Idle。

Success 不显示常驻文字，不加星星，不播放连续弹跳。一次正常成功 Capture 从点击到回到 Idle 约需 800 毫秒，服务耗时较长时顺延。

## Error 与 Empty

普通 Error 使用四至五帧，约 480 毫秒完成。纸片卡在短牙之间，箱盖合到一半后回弹一格，箱体左右摇一次，随后回到 Idle。窗口下方显示 `保存失败`，最长保留 1400 毫秒。

Empty 使用同一动画族的空嚼变体。箱盖合到一半，嘴里没有纸片，角色轻轻夹空一次后回到 Idle。窗口下方显示 `剪贴板为空`，最长保留 1400 毫秒。

桌面提示不直接展示异常对象、文件路径或原生错误文本。`CaptureResult.message` 只在等于已知安全文案时使用。其余错误统一显示 `保存失败`。

## 输入与手势

窗口中的可见宠物分为两个主要命中区。

| 区域 | 左键 | 右键 |
| --- | --- | --- |
| 箱盖顶部黄铜提手区 | 拖动窗口 | 打开菜单 |
| 箱体主体 | Capture | 打开菜单 |

提手区约占角色显示高度顶部 12 逻辑像素。拖动开始后只移动窗口，不触发 Capture。箱体主体接受一次完整点击，按下后产生明显位移时取消 Capture。实现计划应优先采用专用提手区，让点击与拖动无需依靠很小的位移阈值竞争。

右键菜单继续提供 `重新选择 Vault` 与 `退出`。菜单使用现有轻量菜单，不增加宠物内嵌按钮。右键不会触发 Capture，也不会改变宠物状态。

Capturing 期间箱体左键被忽略。提手拖动和右键菜单保持可用。

## 文本反馈

Idle 不显示 `点击保存`。Capturing 不显示 `正在保存`。Success 完全依靠动画表达。

只有 Empty 与 Error 显示短文字。标签不改变窗口尺寸，最多一行，不能遮挡角色。文字消失与宠物回到 Idle 分开计时，宠物可以先安静合箱，标签随后淡出。

## 动画资源

第一版预计包含十八至二十二个独立帧。

| 动画 | 独立帧估算 |
| --- | --- |
| Idle 与眨眼 | 3 |
| Capturing 与等待 | 7 至 9 |
| Success | 3 至 4 |
| Error 与 Empty 共用帧 | 5 至 6 |

资源使用一张带透明通道的 PNG sprite atlas。所有帧使用相同画布、底边和视觉锚点。动画清单单独描述每个状态使用的帧区间、单帧时长和是否循环。

第一版不使用 GIF、Animated WebP、Live2D、骨骼动画、3D 模型或 Flame。也不使用一组尺寸不一致的独立 PNG 作为最终资源。

## Flutter 表现层

Flutter 负责角色渲染、状态推进、结果分支、短文字和手势。一个 `AnimationController` 驱动时间，`CustomPainter` 从 sprite atlas 裁切当前帧，并采用 `FilterQuality.none`。

状态控制与绘制分开。控制器只接收点击、拖动开始、`CaptureResult` 和动画完成事件。绘制器只接收当前帧、缩放和可选的纸片位置。

每次进入新状态前不重新解码图片。sprite atlas 在角色显示前完成加载，避免第一下点击出现空帧。

## 平台窗口

macOS 继续使用现有透明、非 opaque、置顶和跨 Space 窗口。Windows 第一版必须完成无边框 Flutter 窗口的透明背景验证，并在 Windows 真机检查 100%、150% 与 200% DPI。

第一版允许原生窗口仍以 132 × 132 矩形参与系统命中。Flutter 手势只绑定到可见角色和提示区域。透明像素级点击穿透、窗口位置持久化、屏幕边界夹紧和托盘召回留在后续版本。

Windows 右键菜单需要真机确认不会被置顶窗口遮挡。优先沿用平台正常 topmost 行为，不增加高频强制置顶循环。

## 降低动态效果

系统关闭动画或 Flutter 的 `disableAnimations` 生效时，角色不播放眨眼、摇动和等待循环。点击后可以短暂显示开箱静帧，结果返回后直接切换到合箱帧。Error 与 Empty 仍显示短文字，确保状态不只依赖动作判断。

## 测试与验收

共享 Flutter 测试应覆盖以下行为。

- Idle 显示闭合宝箱且没有常驻状态文字
- 箱体点击只调用一次 `CaptureService`
- Capturing 期间重复点击不重复调用 Capture
- 快速返回结果时仍完整播放吞入动作
- 慢速返回结果时进入轻量等待循环
- `saved` 进入 Success 后回到 Idle
- `empty` 播放空嚼并显示安全提示
- `error` 播放卡住动作且不显示原始异常文本
- 提手拖动继续调用 `moveWindowBy`
- 拖动不会同时触发 Capture
- 右键菜单继续提供 Vault 选择和退出
- 降低动态效果时不播放循环动作

macOS 真机验收应覆盖透明背景、跨 Space、左键 Capture、提手拖动、右键菜单和动画期间移动。

Windows 真机验收应覆盖透明背景、置顶、任务栏隐藏、右键菜单、100% 到 200% DPI、初始位置、拖动和透明窗口周围是否出现方框。Windows 真机验收通过前，不宣称两端视觉行为完全一致。

## 许可与原创性

BongoCat 仅作为窗口与桌宠关系、状态分层和桌面交互的研究参考。第一版不复制其猫咪角色、Live2D 模型、贴图、动作、声音或资源目录内容。

如果实现阶段复制了 BongoCat 的具体代码或实质性片段，分发物必须包含其 MIT License 全文和 `Copyright (c) 2025 ayangweb`。项目应在第三方声明中记录来源仓库、固定提交、复用文件和修改说明。只采用通用设计思想时不加入无关代码声明。

## 第一版范围外

- Hover 表情
- Sleeping 与 long idle
- 文字、图片和文件的不同吞入物
- 声音与啪嗒音效
- 养成、心情、饥饿和成长
- 自主行走与屏幕边缘攀爬
- 模型或皮肤导入
- 全局键鼠监听
- 透明像素级点击穿透
- 窗口位置持久化与多显示器恢复
- 托盘菜单和开机启动

## 参考

- [BongoCat 固定提交](https://github.com/BongoCatPet/BongoCat/tree/44f44bcf2b17b8e16463ad479a477a949d01cc9a)
- [BongoCat 主窗口配置](https://github.com/BongoCatPet/BongoCat/blob/44f44bcf2b17b8e16463ad479a477a949d01cc9a/src-tauri/tauri.conf.json)
- [BongoCat 主宠物页面](https://github.com/BongoCatPet/BongoCat/blob/44f44bcf2b17b8e16463ad479a477a949d01cc9a/src/pages/main/index.vue)
- [BongoCat MIT License](https://github.com/BongoCatPet/BongoCat/blob/44f44bcf2b17b8e16463ad479a477a949d01cc9a/LICENSE)
- [Flutter 动画概览](https://docs.flutter.dev/ui/animations/overview)
- [Flutter FilterQuality](https://api.flutter.dev/flutter/dart-ui/FilterQuality.html)

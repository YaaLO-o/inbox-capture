# 个人兴趣采集 Inbox：Mac V0.1 开发执行方案

请从零开始实现这个项目。所有代码、测试结果和必要的技术状态都保留在本地工作区。

Codex 不创建或长期维护 GitHub 仓库，不执行 commit、push、PR 或其他远程仓库操作。后续复查、文档同步和版本提交由其他模型负责。

这个项目不是单纯的剪贴板工具，而是一个个人兴趣与知识采集 Inbox。

核心场景是：

我在小红书、微博、抖音、网页、购物平台等地方看到一本以后想看的书、一部电影、一个商品、一家店、一篇文章、一段观点或一张图片时，希望不用继续依赖各个平台自己的收藏夹，而是通过一个极低摩擦的动作直接保存到自己的 Obsidian。

当前核心动作：

```text
复制内容
→
点击 Mac 桌面悬浮入口
→
读取剪贴板
→
保存到 Obsidian
→
出现保存成功提示
```

长期产品逻辑是：

```text
Capture
→
Understand
→
Organize
```

当前只开发 Capture。

不要开发 AI 分类、摘要、知识整理等功能。

---

# 一、技术方向

项目长期目标平台：

* macOS
* Windows
* Android
* iOS

当前只实现 macOS。

优先采用 Flutter 创建工程，使未来可以继续扩展到其他平台，但不要同时开发 Windows、Android、iOS。

如果实际调研后发现 Flutter 在 macOS 悬浮窗口或剪贴板媒体读取方面需要平台原生能力，可以：

* Flutter 负责主体应用
* macOS 原生 Swift / Platform Channel 负责特殊系统能力

不要为了追求“纯 Flutter”而牺牲实际可用性。

---

# 二、Obsidian 是唯一存储层

不要建立数据库。

不要创建应用自己的媒体数据库。

所有内容最终都是普通 Markdown 和普通文件，直接存在 Obsidian Vault 中。

目录固定设计为：

```text
Obsidian Vault/
└── 素材/
    ├── Inbox/
    │   ├── 2026-08-21.md
    │   ├── 2026-08-22.md
    │   └── ...
    │
    └── attachments/
        ├── 20260821-100215.png
        ├── 20260821-103512.jpg
        ├── 20260821-140355.pdf
        └── 20260821-180412.mp4
```

`Inbox` 是原始采集记录。

`attachments` 是所有附件。

不要按照：

```text
图片/
视频/
PDF/
```

再次分类。

文件扩展名本身已经表达媒体类型。

---

# 三、每日 Inbox

每天只有一个原始 Markdown：

```text
素材/Inbox/YYYY-MM-DD.md
```

例如：

```text
素材/Inbox/2026-08-21.md
```

所有当天采集的内容都进入这个文件。

当前 Capture 阶段绝对不要判断：

* 这是书
* 这是电影
* 这是商品
* 这是店铺
* 这是文章

这些属于未来 AI Understand 阶段。

现在只负责忠实保存。

---

# 四、Capture 数据边界

每次点击保存，都创建一个独立 Capture。

格式尽量保持简单：

```markdown
## 10:32:15

<!-- capture:id=20260821-103215-a82f -->

这里是保存的内容。

---
```

必须包含：

* 创建时间
* 唯一 Capture ID
* 原始内容
* Capture 之间的明确边界

Capture ID 可以使用：

```text
YYYYMMDD-HHMMSS-短随机ID
```

例如：

```text
20260821-103215-a82f
```

HTML 注释中的 ID 不应该明显影响用户在 Obsidian 中阅读。

---

# 五、文字 Capture

剪贴板为文字时：

1. 读取剪贴板文字。
2. 去除首尾无意义空白。
3. 如果完全为空，则不保存。
4. 获取本地日期。
5. 检查：

```text
素材/Inbox/YYYY-MM-DD.md
```

6. 不存在则创建。
7. 文件第一行：

```markdown
# YYYY-MM-DD
```

8. 在文件末尾追加 Capture。
9. 绝对不能覆盖之前的内容。

---

# 六、图片与附件原则

附件处理完全参考 Obsidian 的思路：

**附件本身作为普通文件存放在 Vault 中，Markdown 只保存引用。**

不要 Base64。

不要建立媒体数据库。

不要把图片内容塞进 Markdown。

原则上尽量保留原始格式。

例如：

* PNG → PNG
* JPEG → JPEG
* GIF → GIF
* PDF → PDF
* MP4 → MP4
* MOV → MOV

只有系统剪贴板只提供原始 bitmap 而没有原文件格式时，才允许落盘为 PNG。

不要为了统一格式主动进行大量转码。

---

# 七、图片 Capture

当 macOS 剪贴板中存在图片数据时：

保存到：

```text
素材/attachments/
```

推荐文件名：

```text
YYYYMMDD-HHMMSS-短ID.扩展名
```

例如：

```text
20260821-103215-a82f.png
```

然后当天 Markdown 写入：

```markdown
## 10:32:15

<!-- capture:id=20260821-103215-a82f -->

![[../attachments/20260821-103215-a82f.png]]

---
```

必须在实际 Obsidian 中确认：

图片可以正常显示。

---

# 八、视频与其他文件

不要做网络视频下载功能。

特别注意：

用户在小红书、抖音、B站等地方点击“复制”时，通常得到的是：

* URL
* 分享文本

而不是视频文件。

这种情况按照普通文字 Capture 保存即可。

例如：

```markdown
## 14:20:31

<!-- capture:id=... -->

这个电影推荐以后看看

https://example.com/xxxxx

---
```

禁止看到 URL 后自动下载网络视频。

但是如果系统剪贴板明确包含一个本地文件，例如用户在 Finder 中复制：

```text
movie.mp4
document.pdf
image.jpg
```

可以把文件复制进：

```text
素材/attachments/
```

然后在 Markdown 中使用 Obsidian embed：

```markdown
![[../attachments/xxxx.mp4]]
```

或者：

```markdown
![[../attachments/xxxx.pdf]]
```

V0.1 的最低要求仍然只有：

* 文字
* 图片

如果本地文件复制支持实现简单，可以顺带实现。

如果实现复杂，不要因此阻塞 Mac V0.1。

---

# 九、Capture 数据模型

内部可以设计一个非常轻量的统一 Capture 对象，例如：

```text
Capture

id
createdAt
text?
attachments[]
```

Attachment 可以包含：

```text
id
fileName
originalExtension
mimeType
```

这里不要加入：

```text
movie
book
product
shop
```

这些属于未来 AI 推理结果，不属于 Capture 原始数据。

---

# 十、未来 AI 架构原则

当前不实现 AI，但必须遵循一个原则：

```text
Raw Capture = source of truth
AI 整理结果 = derived data
```

未来 AI 可以读取：

```text
素材/Inbox/
```

然后创建：

```text
兴趣库/
├── 电影/
├── 书籍/
├── 商品/
├── 店铺/
├── 文章/
└── ...
```

但是默认不删除原始 Inbox。

原因：

* AI 可能判断错误
* 后续模型可能改变
* 用户可能希望重新整理
* 原始数据应该由用户长期保留

---

# 十一、Mac 桌面入口

V0.1 实现一个非常轻量的悬浮入口。

要求：

* 小型悬浮窗口
* 可以拖动
* 可以保持在普通窗口之上
* 不长期遮挡大量内容
* 点击即触发 Capture
* 用户不需要切回主窗口

用户点击后：

```text
读取剪贴板
→
判断是否有可保存内容
→
保存
→
反馈
```

成功：

```text
✓ 已保存
```

轻量显示后自动消失。

失败：

显示简单错误信息。

不能直接崩溃。

---

# 十二、Vault 选择

禁止硬编码我的本地 Obsidian 路径。

第一次启动：

让用户选择 Obsidian Vault。

保存这个设置。

以后启动默认读取。

如果：

```text
素材/
素材/Inbox/
素材/attachments/
```

不存在，则自动创建。

---

# 十三、项目共享状态文件

这是整个项目最重要的协作要求之一。

项目根目录建立：

```text
PROJECT_STATE.md
```

这个文件是：

**本地开发过程中的技术状态事实源。**

以后不要要求用户手工复制聊天进度。

Codex 完成本地代码和测试后，必须更新这个文件，准确记录当前架构、已实现功能、测试结果、已知问题和下一步。Codex 只负责更新本地文件，不负责把状态同步到其他文档，也不负责 commit 或 push。

`PROJECT_STATE.md` 固定包含以下内容：

```markdown
# Project State

## 产品定位

项目是什么、解决什么问题。

## 长期目标

Capture → Understand → Organize。

最终希望支持哪些平台。

## 当前阶段

例如：

Mac V0.1 Capture MVP

## 当前架构

技术栈、核心模块以及数据流。

## Obsidian 数据结构

当前实际使用的数据和附件目录。

## 已实现

真实已经跑通的功能。

不要记录“准备做”的功能。

## 当前问题

仍然存在的 bug、限制或者技术问题。

## 已确认决策

记录关键产品和技术决策，以及简短原因。

例如：

- Capture 阶段不分类。
- Raw Inbox 是 source of truth。
- AI 整理属于 derived data。
- Obsidian 是唯一存储层。
- 媒体采用 Obsidian attachment 模型。
- 网络视频暂不自动下载。

## 下一步

只维护最近准备推进的少量事项。

## 最近更新

日期：

本轮完成：
- ...

验证：
- ...

遗留：
- ...
```

不要把这个文件写成开发日志。

不要不断堆积每天的流水账。

它必须始终保持为：

**一个新的 GPT 或 Codex 打开后，几分钟内就能理解整个项目现状的文件。**

如果旧信息已经失效，直接修改旧状态，而不是永远追加。

---

# 十四、README 与文档同步

README 面向未来的自己或项目托管页面阅读，可以说明：

* 项目是什么
* 当前支持平台
* 当前支持的 Capture 类型
* 如何运行
* 如何配置 Obsidian Vault
* 文件保存在哪里
* 当前限制

README 和其他对外文档由后续模型检查并同步。Codex 本轮不负责创建或更新 README，也不负责让 README 与代码状态保持同步。

Codex 只更新本地技术状态：

```text
PROJECT_STATE.md
```

---

# 十五、本地交付与职责边界

Codex 的工作到本地交付为止。

Codex 必须在本地留下：

* 完整源代码
* 可以复现的本地测试结果
* 已更新的 `PROJECT_STATE.md`
* 运行和测试所必需的本地配置示例

Codex 不负责：

* 创建 GitHub 仓库
* 长期维护代码仓库
* 执行 `git add`、`git commit` 或 `git push`
* 创建 PR 或检查远程仓库状态
* 同步 README 和其他文档

后续复查、文档同步、commit 和 push 由其他模型负责。

本地文件中仍然不得写入：

* API Key
* Token
* 密码
* 私人凭据
* 构建缓存
* 不必要的大型临时文件

如果工程需要，可以在本地配置合理的 `.gitignore`，但 Codex 不负责提交或推送。

---

# 十六、本轮明确不做

不要实现：

* AI
* 自动分类
* 自动摘要
* OCR
* 推荐系统
* 向量数据库
* 搜索系统
* 网络视频下载
* 小红书解析器
* 抖音解析器
* 浏览器插件
* Android
* iOS
* Windows
* 云同步
* 用户账户
* 登录
* Notion
* UI 大规模美化

---

# 十七、Mac V0.1 验收

必须实际验证以下场景。

### 测试 1：文字

复制一段文字。

点击悬浮按钮。

确认：

```text
素材/Inbox/YYYY-MM-DD.md
```

出现新的 Capture。

### 测试 2：连续保存

连续保存至少 10 条内容。

确认：

* 全部追加
* 没有覆盖
* 顺序正确
* 每条有独立 ID

### 测试 3：图片

复制一张图片。

点击保存。

确认：

附件进入：

```text
素材/attachments/
```

当天 Inbox 中出现：

```markdown
![[../attachments/文件名]]
```

并在 Obsidian 中正常显示。

### 测试 4：程序重启

关闭程序。

重新打开。

不重新选择 Vault。

继续保存成功。

### 测试 5：异常

测试：

* 空剪贴板
* Vault 不存在
* 无写权限
* 重复快速点击

程序不得直接崩溃。

---

# 十八、执行顺序

先检查当前 Mac 环境：

* Flutter
* Xcode

然后建立工程。

先给出简短设计，确认：

1. Flutter 项目结构。
2. macOS Clipboard 实现。
3. 图片数据读取方案。
4. Floating Window 实现。
5. Vault picker 和配置保存方式。
6. Storage 层。
7. Attachment 层。
8. `PROJECT_STATE.md` 初稿。

不要扩展需求。

设计合理后直接实现 Mac V0.1。

完成以后真实运行并测试，更新本地 `PROJECT_STATE.md`，随后停止。不要执行文档同步、commit 或 push，也不要创建或维护远程仓库。后续复查、文档同步和版本提交由其他模型负责。


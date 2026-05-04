# MLX Voice Notes 策划交接说明书

> 接手对象：新的产品策划 / 项目规划 AI  
> 项目所有者：vanselee  
> 联系邮箱：liyifc@gmail.com  
> 当前日期：2026-05-04  
> 项目路径：`/Users/apple/Desktop/SoftDev/aiaudiovideo`

## 1. 项目定位

MLX Voice Notes 是一个 macOS 本地多角色配音工具，核心目标是：

- 用户输入一篇文案。
- App 自动解析角色和段落。
- 用户为不同角色绑定不同参考音色。
- App 使用本地 MLX/Qwen3 TTS 模型按段生成音频。
- 最终只导出一条完整 WAV 音频，不需要导出分段音频。

产品初衷不是普通朗读器，而是面向短视频口播、对话脚本、播客草稿等场景的“多音色本地配音工作台”。

## 2. 当前产品结构

目前主导航已经收敛为：

- 文案列表：核心工作区，负责新建、编辑、解析角色、绑定音色、生成音频、导出 WAV。
- 角色确认：查看/确认文案解析出的角色与段落。
- 资源中心：管理模型与音色，包含创建参考音色入口。
- 任务总览：查看生成任务与段落状态。
- 偏好设置：语言、导出位置、缓存上限。

之前的“配音工作台”已被弱化/取消，功能并入“文案列表”。这是用户确认过的方向：不要让用户在多个页面之间来回跳，文案列表应成为主工作区。

## 3. 当前技术状态

### 3.1 已接入内容

- SwiftUI + SwiftData macOS App。
- 本地 MLX 依赖已接入。
- Qwen3 TTS bf16 模型已通过真实生成测试。
- 8bit 模型生成杂音，已被排除出 MVP。
- 真实生成链路已完成：
  - 文案段落串行生成。
  - 每段音频保存到 Application Support。
  - App 重启后仍可再次导出。
  - 导出时合并为完整 WAV。
- 参考音色链路已初步完成：
  - 创建音色。
  - 保存参考音频。
  - 保存参考文本。
  - 生成时按角色绑定读取参考音频和参考文本。

### 3.2 已验证结论

- Qwen3 8bit：不进入 MVP，生成为杂音。
- Qwen3 bf16：可作为 MVP 默认模型。
- 仅用 voice instruct 控制音色：不稳定，表现接近随机音色。
- 使用 refAudio + refText：测试通过，是当前音色控制路线。
- 多段、多角色生成可以跑通。
- 完整 WAV 导出可以跑通。

## 4. 当前最重要的未解决问题

### 4.1 文案列表显示/新建异常

用户实测反馈：

- 文案列表 / 文案工作区点击“新建文案”没有反应。
- 之前遗留的测试文案在 UI 中消失。
- 另一个 AI 已提交 `7682cd8 fix: 修复文案和音色 SwiftData 持久化问题`，但用户实测未通过。

关键排查结果：

- 本机 SwiftData 数据库并不是空的。
- `/Users/apple/Library/Application Support/default.store` 中可查到：
  - `ZSCRIPT = 9`
  - `ZVOICEPROFILE = 4`
- 数据库里能看到“肖老师”音色和多篇文案。

推断：

- 数据保存并非完全失败。
- 更可能是 App 当前运行时 UI 没读到预期 store，或 SwiftData 默认 store 路径混乱。
- 当前 `.modelContainer(for:)` 没有显式指定数据库路径，SwiftData 使用了 `Application Support/default.store`。
- 这对长期项目不可接受，容易在开发、预览、调试、多次 schema 变化后混乱。

优先建议：

- 不要继续盲改 `createScript()`。
- 先把 SwiftData store 路径显式收敛到：
  - `/Users/apple/Library/Application Support/MLX Voice Notes/MLXVoiceNotes.store`
- 同时增加启动诊断：
  - 当前 store URL。
  - Script 数量。
  - VoiceProfile 数量。
- 新建文案和保存音色必须有 UI 可见错误提示，不要只 `print`。

### 4.2 创建音色保存体验不稳定

用户反馈：

- 资源中心创建音色可以创建并影响生成，但点保存体验上像无效。

排查结果：

- 数据库中已有用户创建的“肖老师”音色。
- 参考音频文件也写入了：
  - `/Users/apple/Library/Application Support/MLX Voice Notes/VoiceProfiles/...`

推断：

- 文件资产存储是生效的。
- SwiftData 记录也可能已写入。
- 问题更可能是 UI 刷新、保存反馈、store 路径或错误提示不足。

建议：

- 保存成功后显示明确成功反馈。
- 保存失败时停留在创建音色窗口，并显示错误。
- 音色列表要确保使用同一个 SwiftData container 查询。

## 5. 重要文件索引

项目入口：

- `MLXVoiceNotes/MLXVoiceNotes/MLXVoiceNotesApp.swift`
- `MLXVoiceNotes/MLXVoiceNotes/Views/ContentView.swift`

数据模型：

- `MLXVoiceNotes/MLXVoiceNotes/Models/AppModels.swift`

文案列表：

- `MLXVoiceNotes/MLXVoiceNotes/Views/ScriptLibraryView.swift`

资源中心与音色创建：

- `MLXVoiceNotes/MLXVoiceNotes/Views/ResourceCenterView.swift`
- `MLXVoiceNotes/MLXVoiceNotes/Views/CreateVoiceProfileView.swift`

生成与导出：

- `MLXVoiceNotes/MLXVoiceNotes/Services/GenerationService.swift`
- `MLXVoiceNotes/MLXVoiceNotes/Services/MLXAudioService.swift`
- `MLXVoiceNotes/MLXVoiceNotes/Services/AudioStorageService.swift`
- `MLXVoiceNotes/MLXVoiceNotes/Services/AudioExportService.swift`
- `MLXVoiceNotes/MLXVoiceNotes/Services/VoiceProfileStorageService.swift`

阶段文档：

- `docs/phase0/phase0-results.md`
- `docs/phase2-voice-control-test.md`
- `docs/phase2c-voice-profile-design.md`
- `docs/qa/mvp-smoke-test.md`

## 6. 当前推荐优先级

### P0：先修 SwiftData store 和诊断

目标：

- 让 App 明确读写同一个数据库。
- 让用户和开发 AI 能看到当前文案/音色数量。
- 避免继续凭感觉判断“保存是否成功”。

建议任务：

1. 显式指定 SwiftData store URL。
2. 在 Debug 模式显示或打印 store URL、文案数、音色数。
3. 新建文案失败和保存音色失败必须弹出/显示错误。
4. Build。
5. 用户手动验证新建文案、音色保存、重启后是否仍存在。

### P1：修复文案列表交互闭环

目标：

- 文案列表为空时自动出现可编辑草稿或样本文案。
- 点击“新建文案”一定要产生可见结果。
- 如果复用空白草稿，要明确展开该草稿。

### P2：完善音色创建体验

目标：

- 保存成功后资源中心列表立即刷新。
- 角色音色下拉框立即可选。
- 保存失败时显示原因。

### P3：继续产品功能扩展

在 P0-P2 稳定后再继续：

- 音色删除与资产清理。
- 音色重命名。
- 文案列表更多排序/搜索。
- 任务总览和文案列表进一步合并体验。
- SwiftData schema 迁移策略。

## 7. 不要踩的坑

- 不要优先改 UI 外观。当前核心问题是数据读写和刷新。
- 不要删除 `default.store`，里面有当前测试数据。
- 不要随意清空 Application Support。
- 不要重新引入 Soprano、Kokoro、Pocket TTS、VyvoTTS 等模型。
- MVP 阶段只考虑 Qwen3 bf16。
- 不要把 8bit 重新设为默认模型。
- 不要依赖 voice instruct 控制音色，已经验证不稳定。
- 不要把分段音频作为用户导出目标，用户只需要完整 WAV。

## 8. 给新策划 AI 的启动提示词

可以直接复制下面这段给新的策划 AI：

```text
你现在接手 MLX Voice Notes 项目的产品策划与任务拆分工作。请先阅读：

1. /Users/apple/Desktop/SoftDev/aiaudiovideo/docs/project-handoff-planning.md
2. /Users/apple/Desktop/SoftDev/aiaudiovideo/docs/phase2c-voice-profile-design.md
3. /Users/apple/Desktop/SoftDev/aiaudiovideo/docs/phase0/phase0-results.md
4. /Users/apple/Desktop/SoftDev/aiaudiovideo/docs/qa/mvp-smoke-test.md

项目定位：macOS 本地多角色配音工具，用户输入文案，解析角色，绑定参考音色，用 Qwen3 bf16 本地生成，最终导出一条完整 WAV。

当前最紧急问题不是 UI，而是 SwiftData store 和运行时诊断：
- UI 中“新建文案”无反应。
- 文案列表看不到旧测试文案。
- 创建音色保存体验像无效。
- 但本机 /Users/apple/Library/Application Support/default.store 里实际有 ZSCRIPT=9、ZVOICEPROFILE=4。

请先给出产品/工程任务拆分，不要直接大改代码。
优先规划：
P0：显式 SwiftData store 路径 + 启动诊断 + 保存失败可见提示。
P1：文案列表新建和空列表体验恢复。
P2：音色创建保存后的反馈和刷新。

约束：
- 不上传 GitHub。
- 每次代码修改都要本地 git commit。
- 后续 git commit 信息用中文。
- 作者为 vanselee，邮箱 liyifc@gmail.com。
- MVP 阶段只用 Qwen3 bf16，不要引入其他模型。
- 不要删除 default.store 或 Application Support 中的用户数据。
```

## 9. 给执行型 AI 的第一步提示词

如果接下来要交给执行型 AI 修复，可以使用：

```text
请只做 P0 诊断修复，不改 UI 大结构、不改 MLX 生成逻辑、不改 schema。

任务：
1. 在 MLXVoiceNotesApp.swift 中显式创建 SwiftData ModelContainer。
2. 将 SwiftData store URL 指定为：
   ~/Library/Application Support/MLX Voice Notes/MLXVoiceNotes.store
3. 确保目录不存在时创建。
4. DEBUG 下启动时打印：
   - store URL
   - Script 数量
   - VoiceProfile 数量
5. ScriptLibraryView.createScript() 保存失败时显示用户可见错误。
6. CreateVoiceProfileView.saveVoice() 保存失败时显示用户可见错误，不要只 print。
7. 不要删除 /Users/apple/Library/Application Support/default.store。
8. Build 成功后提交，提交信息用中文。

注意：当前 default.store 里已有测试数据，切换 store 后旧数据不会自动出现。本次只做 store 路径收敛和诊断，不做数据迁移。
```

## 10. 建议验收清单

P0 修复后，请用户手动验证：

- 启动 App 后能看到当前 store 路径或控制台日志。
- 文案列表显示的文案数量与日志一致。
- 点击“新建文案”后，列表出现新文案并展开编辑。
- 创建音色保存后，资源中心音色列表出现新音色。
- 重启 App 后，新文案和新音色仍存在。
- 如果保存失败，界面能看到错误原因。


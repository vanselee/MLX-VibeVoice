# MLX Voice Notes 策划交接说明书

> 接手对象：新的产品策划 / 项目规划 AI  
> 项目所有者：vanselee  
> 联系邮箱：liyifc@gmail.com  
> 当前日期：2026-05-06  
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
- 文案新建已测试通过。
- 音色创建、保存、下拉使用已测试通过。
- 音色删除与资产清理已实现。
- 音色重命名已实现。
- SwiftData store 显式路径和 schema 备份已实现。
- 音频导出停顿与淡入淡出已实现初版。

### 3.2 已验证结论

- Qwen3 8bit：不进入 MVP，生成为杂音。
- Qwen3 bf16：可作为 MVP 默认模型。
- 仅用 voice instruct 控制音色：不稳定，表现接近随机音色。
- 使用 refAudio + refText：测试通过，是当前音色控制路线。
- 多段、多角色生成可以跑通。
- 完整 WAV 导出可以跑通。

## 4. 历史问题 / 已解决问题

### 4.1 文案列表显示/新建异常 ✅ 已解决

**原问题描述**：

- 文案列表 / 文案工作区点击“新建文案”没有反应。
- 之前遗留的测试文案在 UI 中消失。

**解决过程**：

- `7682cd8` 修复文案和音色 SwiftData 持久化问题（inverse relationship 未正确建立）。
- `170edbd` 显式配置 SwiftData store 路径 + 启动诊断日志。
- `ab91300` 空列表欢迎引导。
- `800b885` 复用空白草稿提示气泡。

**当前状态**：文案新建已测试通过，空列表体验已优化。

### 4.2 创建音色保存体验不稳定 ✅ 已解决

**原问题描述**：

- 资源中心创建音色可以创建并影响生成，但点保存体验上像无效。

**解决过程**：

- `170edbd` CreateVoiceProfileView.saveVoice() 增加 UI 错误反馈。
- SwiftData @Query 自动刷新列表。
- 动态音色选择器接入。

**当前状态**：音色创建、保存、下拉使用已测试通过。

---

## 5. 当前未解决问题

### 5.1 音频停顿规则初版需修正

**问题**：`f0f168f` 实现的停顿与淡入淡出初版存在以下缺陷：

- 旁白判断逻辑不正确。
- 中文标点处理不完整。
- 手动停顿标签解析有 bug。
- 段号偏移计算错误。

**影响**：多角色对话音频节奏不自然。

### 5.2 音频后处理仍缺少关键能力

**缺失功能**：

- 首尾静音裁剪。
- 响度归一化。
- 多角色音量平衡。

**影响**：不同音色响度差异大，听感不一致。

### 5.3 路线图同步问题

**问题**：`docs/project-roadmap.md` 需保持和 git 提交同步，避免后续 AI 被过期信息误导。

**状态**：已于 `69a6936` 同步到 P3A 状态。

## 6. 重要文件索引

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

## 7. 当前推荐优先级

### P3A-1：修复停顿规则 bug

**目标**：修正音频停顿规则初版的缺陷。

**任务**：

1. 修正旁白判断逻辑。
2. 完善中文标点处理。
3. 修复手动停顿标签解析。
4. 修正段号偏移计算。
5. Build + 用户听感验证。

### P3A-2：多角色导出听感验收

**目标**：验证多角色文案生成效果。

**任务**：

1. 创建多角色测试文案。
2. 绑定不同音色。
3. 生成并导出完整 WAV。
4. 用户主观听感评价。

### P3B：资源中心模型列表收敛

**目标**：资源中心模型 Tab 仅显示 MVP 相关模型。

### P3C：日志诊断增强

**目标**：增强运行时诊断能力，便于排查问题。

## 8. 不要踩的坑

- 不要优先改 UI 外观。当前核心问题是数据读写和刷新。
- 不要删除 `default.store`，里面有当前测试数据。
- 不要随意清空 Application Support。
- 不要重新引入 Soprano、Kokoro、Pocket TTS、VyvoTTS 等模型。
- MVP 阶段只考虑 Qwen3 bf16。
- 不要把 8bit 重新设为默认模型。
- 不要依赖 voice instruct 控制音色，已经验证不稳定。
- 不要把分段音频作为用户导出目标，用户只需要完整 WAV。

## 9. 给新策划 AI 的启动提示词

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

## 10. 给执行型 AI 的第一步提示词

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

## 11. 建议验收清单

P3A-1 修复后，请用户手动验证：

- 多角色文案生成后，段落间停顿自然。
- 不同角色切换时无明显跳变。
- 手动停顿标签生效。
- 导出 WAV 听感流畅。


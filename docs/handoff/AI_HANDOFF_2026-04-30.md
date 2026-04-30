# MLX Voice Notes AI Handoff

更新日期：2026-04-30

## 项目定位

MLX Voice Notes 是一个 macOS 本地多角色配音工具。目标用户把文案导入或粘贴进 App，App 解析角色、绑定不同音色、自动生成多段语音，最终只导出一条完整成品 WAV 音频。

MVP 核心原则：

- 本地优先。
- 多角色、多音色配音是核心，不应降级成单旁白。
- 最终导出只需要完整音频，不导出分段音频。
- 当前阶段先跑通 SwiftUI + SwiftData + 任务流，真实 TTS 接入放在后续。

## 当前 Git 状态

- 仓库路径：`/Users/apple/Desktop/SoftDev/aiaudiovideo`
- 当前功能代码提交：`0ceb52b feat: use inline script editing workflow`
- 已有标签：`phase0-start`
- 本项目目前采用本地 Git 管理。每次完成明确修改必须提交一次本地 Git 记录。
- 交接前必须运行 `git status --short`。如果看到 `mlxvoicenote说明书.md` 或 `对话.txt` 被删除，不要擅自提交这些删除，先向用户确认。

常用命令：

```bash
git status --short
git log --oneline -12
xcodebuild build -project MLXVoiceNotes/MLXVoiceNotes.xcodeproj -scheme "MLX Voice Notes" -configuration Debug -derivedDataPath /private/tmp/MLXVoiceNotesDerivedData CODE_SIGNING_ALLOWED=NO
swiftc -module-cache-path /private/tmp/mlx-voice-notes-swift-module-cache MLXVoiceNotes/MLXVoiceNotes/Services/ScriptParser.swift tools/test_script_parser.swift -o /private/tmp/test_script_parser
/private/tmp/test_script_parser
```

## 重要文档

- 主 PRD：`/Users/apple/Desktop/SoftDev/aiaudiovideo/mlxvoicenote说明书_更新版.md`
- PRD 副本：`/Users/apple/Desktop/SoftDev/aiaudiovideo/docs/PRD.md`
- 开发规则：`/Users/apple/Desktop/SoftDev/aiaudiovideo/docs/development-rules.md`
- Phase 0 验证结果：`/Users/apple/Desktop/SoftDev/aiaudiovideo/docs/phase0/phase0-results.md`
- 模型矩阵：`/Users/apple/Desktop/SoftDev/aiaudiovideo/docs/phase0/model-matrix.md`
- 高保真原型：`/Users/apple/Desktop/SoftDev/aiaudiovideo/docs/prototypes/mlx-voice-notes-hifi-pages.html`
- 低保真原型：`/Users/apple/Desktop/SoftDev/aiaudiovideo/docs/prototypes/mlx-voice-notes-low-fi.html`

## 当前 App 代码结构

Xcode 工程：

- `MLXVoiceNotes/MLXVoiceNotes.xcodeproj`

主要代码：

- `MLXVoiceNotes/MLXVoiceNotes/Views/ContentView.swift`
  - 当前主要 SwiftUI 页面都在这里。
  - 最新交互已经把文案库改成“文案工作区”：默认列表态，点击行内展开编辑。

- `MLXVoiceNotes/MLXVoiceNotes/Models/AppModels.swift`
  - SwiftData 模型：`Script`、`ScriptSegment`、`VoiceRole`、`VoiceProfile`、`GenerationJob`、`ExportRecord`。

- `MLXVoiceNotes/MLXVoiceNotes/Services/ScriptParser.swift`
  - 文案解析服务。
  - 支持 `[角色] 文本`、`【角色】文本`、`角色：文本`、`角色: 文本`。
  - 无角色标记文本默认归为“旁白”。

- `MLXVoiceNotes/MLXVoiceNotes/Services/GenerationService.swift`
  - 当前是占位生成调度器。
  - 支持开始、暂停、取消、失败重试、定时自动推进段落状态。
  - 还没有真实 TTS。

- `MLXVoiceNotes/MLXVoiceNotes/Services/AudioExportService.swift`
  - 当前是占位 WAV 导出服务。
  - 会生成 24kHz / 16-bit PCM / mono 静音 WAV。
  - 默认导出目录：`~/Downloads/MLX Voice Notes Exports`

- `tools/test_script_parser.swift`
  - 轻量 parser smoke test。

## 当前已实现体验

当前版本已经实现：

- macOS SwiftUI App shell。
- SwiftData 本地数据模型。
- 文案列表。
- 行内展开编辑：
  - 默认打开 App 不直接进入编辑状态。
  - 点击文案行进入编辑。
  - 点击“保存”收起编辑。
  - 已移除副标题输入。
- 新建文案：
  - 如果已有空白“未命名文案”草稿，会直接打开复用。
  - 避免重复创建多个空白文案。
- 一键粘贴。
- 角色解析。
- 角色音色绑定页面仍保留为独立页。
- 列表行直接“生成音频”。
- 占位自动生成任务：
  - 每秒自动推进段落状态。
  - 用户不需要逐段点击。
- 任务队列页面：
  - 以文案为主任务。
  - 展示当前文案的段落明细。
  - 支持暂停、取消、重试失败。
  - 取消任务会把文案移出任务队列，回到草稿。
- 占位 WAV 导出。
- 文案删除功能和确认弹窗。

## 当前没有实现或只是占位

- 真实 MLX TTS 尚未接入。
- 真实音色克隆尚未实现。
- 角色音色只是绑定 UI 和占位音色名。
- WAV 导出目前是静音占位文件，不是真实配音。
- 任务失败目前没有真实错误来源。
- 模型下载中心仍是静态 UI。
- 资源中心、导出设置、配音工作台等页面仍有旧结构，后续需要清理。
- 角色确认还没有内联到文案列表编辑区。
- 生成音频前的“未标记音色提示/是否选择音色”还未完整实现。

## 最近关键设计决策

1. 主流程从多页面跳转改为“文案工作区”。
   - 用户打开 App 默认看到文案列表。
   - 点击某条文案才展开编辑。
   - 不再默认显示顶部固定编辑器。

2. “配音工作台”暂时保留。
   - 目前它是旧工作流页面。
   - 不建议继续在它上面投入新功能。
   - 后续应弱化、删除或改成高级模式。

3. “生成整篇”改为“生成音频”。
   - 这是更符合用户理解的按钮文案。

4. 不要导出分段音频。
   - 内部分段只用于生成、缓存、重试。
   - 用户导出只需要完整成品音频。

5. 副标题输入不需要。
   - 主工作区已经删除副标题输入。
   - 模型里仍有 `subtitle` 字段，暂不急着迁移删除，避免 SwiftData 迁移风险。

## 建议下一步

优先级从高到低：

1. 把“角色音色”内联进文案展开编辑区。
   - 现在点击“角色音色”还会跳到独立角色确认页。
   - 更好的体验是在当前展开行内显示角色列表、音色选择、语速调节。

2. 弱化或移除旧“配音工作台”导航。
   - 当前主流程已经转到文案工作区。
   - 保留旧页面会让用户困惑。

3. 给文案列表增加搜索/排序。
   - 目前只有按修改时间排序。
   - 文案多后需要搜索标题和正文。

4. 改进生成音频的状态反馈。
   - 列表行里显示生成进度、完成状态、导出入口。
   - 完成后直接提供“导出 WAV”按钮。

5. 接入真实 TTS 前，先完善服务边界。
   - `GenerationService` 后续应拆成真实任务调度器。
   - `AudioExportService` 后续应接收真实音频片段并拼接整篇。

6. 再接 MLX / Qwen3-TTS。
   - 优先验证 Swift 版是否能支持目标 TTS 模型。
   - 如果 Swift 版暂不支持，再考虑 Python CLI 桥接。

## 给下一个 AI 的注意事项

- 不要破坏本地 Git 记录。
- 每次完成明确修改都要提交一次本地 Git commit。
- 不要用 `git reset --hard` 或回退用户改动，除非用户明确要求。
- 先运行 `git status --short`，确认工作区状态。
- 修改 Swift 文件后必须运行：

```bash
xcodebuild build -project MLXVoiceNotes/MLXVoiceNotes.xcodeproj -scheme "MLX Voice Notes" -configuration Debug -derivedDataPath /private/tmp/MLXVoiceNotesDerivedData CODE_SIGNING_ALLOWED=NO
```

- 修改解析逻辑后运行：

```bash
swiftc -module-cache-path /private/tmp/mlx-voice-notes-swift-module-cache MLXVoiceNotes/MLXVoiceNotes/Services/ScriptParser.swift tools/test_script_parser.swift -o /private/tmp/test_script_parser
/private/tmp/test_script_parser
```

- 当前用户非常重视交互直觉。不要只做功能堆叠，要优先保证：
  - 打开 App 不强迫用户进入编辑态。
  - 点击哪里，就在哪里展开/反馈。
  - 用户不需要猜下一步去哪一页。
  - 主流程应尽量在文案工作区内完成。

## 推荐给下一个 AI 的初始提示词

请阅读并遵守以下上下文：

我正在开发一个 macOS 本地多角色配音工具，项目路径是：

`/Users/apple/Desktop/SoftDev/aiaudiovideo`

请先阅读：

- `/Users/apple/Desktop/SoftDev/aiaudiovideo/docs/handoff/AI_HANDOFF_2026-04-30.md`
- `/Users/apple/Desktop/SoftDev/aiaudiovideo/mlxvoicenote说明书_更新版.md`
- `/Users/apple/Desktop/SoftDev/aiaudiovideo/docs/development-rules.md`

当前功能代码提交是：

`0ceb52b feat: use inline script editing workflow`

请先运行：

```bash
git status --short
git log --oneline -8
```

要求：

1. 每完成一次明确修改，必须提交一次本地 Git commit。
2. 不要上传 GitHub，不要做远程操作。
3. 不要使用破坏性 Git 命令。
4. 修改后必须编译验证。
5. 当前优先目标不是接真实 TTS，而是继续优化文案工作区体验：
   - 把角色音色绑定内联到文案展开编辑区。
   - 弱化或移除旧配音工作台导航。
   - 让生成完成后可以在文案行直接导出 WAV。

请先总结你理解的当前项目状态和下一步计划，再开始修改。

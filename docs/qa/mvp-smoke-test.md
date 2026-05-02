# MLX Voice Notes MVP 验收清单

此清单用于每次功能改动后验证核心流程是否正常工作。

---

## 📋 验收清单

### 1. 文案列表 (Script Library)

- [ ] 可以正常启动应用
- [ ] 点击左侧"文案列表"按钮可以正确切换页面
- [ ] 点击"新建文案"可以创建新文案
- [ ] 新建文案有默认标题和默认内容
- [ ] 可以在编辑页面修改标题和内容
- [ ] 点击"保存"按钮可以保存内容
- [ ] 点击"一键粘贴"可以正确从剪贴板粘贴内容
- [ ] 点击"解析角色"可以解析角色和段落
- [ ] 角色解析后，角色标签有高亮
- [ ] 解析摘要显示正确（角色数、段数）
- [ ] 点击"编辑"可以展开已有的文案
- [ ] 点击"删除"可以删除文案（删除前有警告弹窗）
- [ ] 删除文案后，左侧选中项自动更新
- [ ] 文案列表按创建时间倒序排列
- [ ] 可以在文案详情页右侧看到生成状态
- [ ] 生成中有进度条显示
- [ ] 点击"查看任务队列"可以切换到任务队列页

---

### 2. 角色确认 (Role Review)

- [ ] 点击左侧"角色确认"按钮可以正确切换页面
- [ ] 页面显示当前选中文案的角色列表
- [ ] 每个角色可以选择音色
- [ ] 有"试听"按钮（占位，不必须工作）
- [ ] 有段落预览列表
- [ ] 段落列表显示角色名和内容

---

### 3. 资源中心 (Resource Center)

- [ ] 点击左侧"资源中心"按钮可以正确切换页面
- [ ] 可以在"模型"和"音色"之间切换标签
- [ ] 模型标签显示示例模型列表（占位）
- [ ] 音色标签显示音色列表
- [ ] 音色卡片显示音色名称、来源、时长、状态
- [ ] 音色有"试听"、"重命名"、"删除"按钮（占位）
- [ ] 可以点击"创建音色"打开创建弹窗

---

### 4. 任务队列 (Task Queue)

- [ ] 点击左侧"任务总览"按钮可以正确切换页面
- [ ] 左侧显示正在/已生成的文案列表
- [ ] 点击文案可以切换当前查看的文案
- [ ] 显示全局进度条和统计
- [ ] 段落列表显示每个段落的状态
- [ ] 失败的段落可以点击"重试"
- [ ] "暂停"、"取消"、"重试失败"按钮存在

---

### 5. 偏好设置 (Preferences)

- [ ] 点击左侧"偏好设置"按钮可以正确切换页面
- [ ] 语言选择功能正常（下拉菜单）
- [ ] 导出路径显示正确
- [ ] "恢复默认位置"按钮存在
- [ ] "更改位置"按钮可以打开文件选择器
- [ ] 当前缓存占用显示（占位，不必须工作）
- [ ] 缓存上限设置（下拉菜单）
- [ ] "清理缓存"按钮存在（禁用状态）

---

### 6. 创建音色 (Create Voice Profile)

- [ ] 可以从资源中心打开创建音色弹窗
- [ ] 可以输入音色名称
- [ ] 名称错误时有红色提示
- [ ] 可以选择参考音频文件
- [ ] 可以输入/粘贴参考文本
- [ ] "自动转写"按钮存在（禁用）
- [ ] 测试句可以编辑
- [ ] "生成测试音频"和"试听结果"按钮存在
- [ ] 点击"保存音色"可以保存
- [ ] 点击"取消"可以关闭弹窗
- [ ] 保存后音色出现在音色列表

---

### 7. 音频导出 (Export)

- [ ] 在文案详情页可以看到导出选项
- [ ] 可以点击"导出 WAV"按钮
- [ ] 可以点击"打开文件夹"打开导出目录
- [ ] 导出文件名有时间戳
- [ ] 导出后"最近导出"时间更新
- [ ] 未完成生成时"导出 WAV"按钮禁用

---

### 8. 状态同步与持久化

- [ ] 页面切换后，状态保持正确
- [ ] 应用重启后，之前的文案内容保持
- [ ] 音色绑定关系保持
- [ ] 生成进度保持
- [ ] 偏好设置保持

---

### 9. SwiftData 关系完整性

- [ ] 删除一个 Script 后，关联的 ScriptSegments 和 VoiceRoles 也被删除
- [ ] 删除一个 VoiceProfile 不会影响已完成的生成
- [ ] 创建新 VoiceProfile 后，出现在音色选择下拉中

---

## 📝 测试脚本

### 标准测试用例

```
测试文案 1（单角色）：
[旁白] 你好，这是一段测试文案。我们来验证一下单角色配音功能是否正常工作。

测试文案 2（多角色）：
[小明] 你好，我是小明。
[小红] 你好小明，我是小红。
[旁白] 他们开始了一段对话，准备测试多角色配音功能。

测试文案 3（混合格式）：
[旁白] 这是第一段。
[旁白] 这是第二段。
普通无标记文本（应归为旁白）
小明： 这是另一种格式的角色标记
```

---

## 🔍 性能检查

- [ ] 启动应用时间 < 2秒
- [ ] 新建文案切换到编辑状态无明显卡顿
- [ ] 解析 10 段文案 < 0.5秒
- [ ] 页面切换流畅（无明显卡壳）
- [ ] 内存占用合理（空闲时 < 200MB）

---

## 🎨 UI 检查

- [ ] 支持深色模式
- [ ] 支持语言切换（中文/英文）
- [ ] 各按钮对齐整齐
- [ ] 所有图标正确显示（SF Symbols）
- [ ] 各页面过渡动画流畅
- [ ] 窗口最小尺寸（1100x720）正常工作

---

## 📦 发布前检查清单

- [ ] 项目可以正常 archive
- [ ] 签名配置正确
- [ ] 所有警告已处理
- [ ] 无严重问题（编译错误）
- [ ] 测试至少在 2 台不同设备上运行过
- [ ] 所有验收项目通过

---

## Verification Log — 2026-05-02 (Code Review)

**Last verified**: 2026-05-02 10:54 (commit `c1c6c62`)
**Result**: ✅ 14 PASSED / 1 PASSED-WITH-NOTES / 0 FAILED / Build SUCCEEDED

All 15 smoke-test items verified by code inspection. No blocking issues found. No code changes made.

### Detailed Results

| # | Item | Status | Evidence |
|---|------|--------|----------|
| 1 | App 能启动 | ✅ PASS | `App` struct + `SwiftDataContainer` configured in app entry |
| 2 | 新建文案能创建新文案 | ✅ PASS | `createScript()` → `modelContext.insert(Script(...))` + `openEditor(for:)` |
| 3 | 最近空白草稿复用 | ✅ PASS | `isReusableBlankDraft()` — checks `status==.draft && title=="未命名文案" && body matches default`; sample scripts use `status=.completed/.generating` so never match |
| 4 | 点击卡片空白区域选中文案 | ✅ PASS | `.contentShape(Rectangle()).onTapGesture { selectedScriptID = script.id }` |
| 5 | 编辑按钮进入编辑状态 | ✅ PASS | `openEditor(for:)` sets `expandedScriptID`, triggers `currentScriptEditor` inline expansion |
| 6 | 保存后回到列表 | ✅ PASS | `saveAndCollapse(_:)` sets `expandedScriptID = nil` |
| 7 | 删除文案按钮有效 | ✅ PASS | `deleteCandidate` + `.alert("删除文案？", …)` + `modelContext.delete(script)`, disabled during `.generating` |
| 8 | 解析角色识别 `[旁白]`/`[角色名]` | ✅ PASS | `bracketMarker(open:"[", close:"]")` in `ScriptParser.parseLine()`, also handles `【】` and `:` colon |
| 9 | 音色下拉、语速滑块能保存 | ✅ PASS | `VoiceRole.defaultVoiceName` + `speed` are SwiftData `@Model` properties; bindings `set:` writes directly |
| 10 | 生成音频按钮触发模拟生成 | ✅ PASS | `startPlaceholderGeneration()` → `GenerationService.start(script:)`; timer `advanceOneTick()` advances state each second |
| 11 | 生成完成导出 WAV 按钮可用 | ✅ PASS | Export guarded by `completed == total && total > 0`; calls `AudioExportService.exportPlaceholderWAV()` (silent WAV stub) |
| 12 | 任务总览以"文案"为单位，详情以"段落"为单位 | ✅ PASS | Sidebar lists `taskScripts` (`Script` objects); main area lists `segmentRows` from `script.segments` |
| 13 | 偏好设置只有语言/导出位置/缓存 | ✅ PASS | Exactly 3 `settingsCard` blocks in `PreferencesView` |
| 14 | 资源中心页面不崩溃 | ✅ PASS | `ResourceCenterView` has `modelContent`/`voiceContent` tabs; `VoiceLibraryView` has empty state guard |
| 15 | 角色确认页面不崩溃 | ✅ PASS | `if let script` guard with `ContentUnavailableView` fallback |

### Non-blocking Observations

- Language row in Preferences uses inline `.frame` instead of `preferenceRow` helper — cosmetic inconsistency, no functional impact
- Export path Text in cache section missing explicit height constraint — no functional impact
- Voice row action buttons (试听/重命名/删除) are no-op placeholders — expected for Phase 1
- Cache usage shows "待统计" — intentional placeholder for future phase

### Build Verification

```bash
cd /Users/apple/Desktop/SoftDev/aiaudiovideo && \
xcodebuild build \
  -project MLXVoiceNotes/MLXVoiceNotes.xcodeproj \
  -scheme "MLX Voice Notes" \
  -configuration Debug \
  -derivedDataPath /private/tmp/MLXVoiceNotesDerivedDataVerify \
  CODE_SIGNING_ALLOWED=NO
# ✅ BUILD SUCCEEDED
```

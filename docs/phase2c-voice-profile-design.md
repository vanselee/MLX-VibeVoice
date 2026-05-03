# Phase 2C 参考音色资产设计

> 状态：设计阶段，代码未改动
> 日期：2026-05-03
> 负责人：Software Architect
> 范围：VoiceProfile Schema 最小改动 + 参考音频存储 + 音色到生成参数映射

---

## 1. VoiceProfile 最小 Schema 改动

| 字段名 | 类型 | Optional | 立即加原因 |
|--------|------|---------|-----------|
| `referenceAudioLocalPath: String` | `String` | **否** | 无本地路径则生成链路必断；MLX refAudio 必须有路径才能加载 |
| `referenceText: String` | `String` | **否** | MLX refText 缺失则音色克隆质量不可控；指参考音频对应的原始文本 |
| `voiceProfileID: UUID?` | `UUID?` | **是** | VoiceRole → VoiceProfile 绑定键；阶段1用 name 匹配过渡，阶段2切 UUID 绑定 |
| `durationSeconds: Double` | `Double` | **是** | UI 显示用；可从音频路径加载时自动填充，不阻塞核心逻辑 |

**延后字段**：内置音色（preset/builtIn）的参考音频字段可空；克隆后生成的预览音频路径。

**旧数据兼容**：`referenceAudioLocalPath` 和 `voiceProfileID` 默认 nil；VoiceRole 已有 `defaultVoiceName` 字符串字段，先用它匹配 `VoiceProfile.name`，后续再切 voiceProfileID 绑定。

**最小结论**：阶段1只加 `voiceProfileID: UUID?` 到 VoiceRole；其他复用现有 VoiceProfile 字段。

---

## 2. 参考音频文件存储

| 项目 | 设计决策 |
|------|---------|
| **保存目录** | `Application Support/MLX Voice Notes/VoiceAssets/<profileID>/reference.<ext>` |
| **保存格式** | 保留原始文件（mp3/m4a/wav），不转码；MLX `loadAudioArray` 支持多格式；转码会损失质量 |
| **路径类型** | 存相对路径 `VoiceAssets/<profileID>/reference.mp3`，代码拼接 Application Support 根目录；适应用户路径差异 |
| **删除时清理** | 是。删除 VoiceProfile 时同步删除整个 `<profileID>/` 目录（含参考音频和后续生成的 preview） |
| **与 GeneratedAudio 区分** | `VoiceAssets/` = 用户输入资产（永久保留）；`GeneratedAudio/` = TTS 输出产物（可重新生成，文案删除时一并清理） |

---

## 3. 角色音色到生成参数的映射

### 3.1 查询链路

| 步骤 | 映射逻辑 |
|------|---------|
| `segment.roleName` → VoiceRole | `roleName` 已是 `VoiceRole.name`，SwiftData Query 按 name 精确匹配 |
| VoiceRole.defaultVoiceName → VoiceProfile | 阶段1：字符串 name 匹配（零改动）；阶段2：VoiceRole.voiceProfileID → UUID 绑定 |
| VoiceProfile → refAudioURL/refText | 直接取字段，拼装为完整路径 |

### 3.2 VoiceProfile 转生成参数

```
refAudioURL = URL(appSupportDir).appendingPathComponent(profile.referenceAudioLocalPath)
refText     = profile.referenceText
```

两个字段均非 nil 时才传入 MLXAudioService 生成函数。

### 3.3 找不到参考音色时

**报错阻断，不静默降级**。

原因：音色是语义级属性，缺失时生成无意义；降级会导致用户以为用了某音色实际未用，传播错误。

---

## 4. Service 层改动

| 层级 | 改动范围 |
|------|---------|
| **GenerationService** | 传入 VoiceRole → 查询 VoiceProfile → 提取 refAudio/refText → 转发给 MLXAudioService；其他逻辑不变（串行逐段生成） |
| **MLXAudioService** | 无需改动。当前函数签名已支持 `refAudioURL: URL?` 和 `refText: String?`，nil 时走默认音色路线 |

---

## 5. 设计约束

- 不修改正式生成流程（现有 segment → generation 链路）
- 不修改 SwiftData schema 主干（Script、ScriptSegment 不动）
- 禁止 destructive git 命令

---

## 6. 实施记录

| 日期 | 步骤 | 状态 | Commit |
|------|------|------|--------|
| 2026-05-03 | Step 1A: VoiceProfile init 字段补全 | ✅ | ec87ada |
| 2026-05-03 | Step 1B: VoiceProfileStorageService 新建 | ✅ | e5b6f66 |
| 2026-05-03 | Step 2: CreateVoiceProfileView 接入存储服务 | ✅ | 5506130 |
| 2026-05-03 | Step 3: 参考音色测试试听（生成 + 试听 + 保存验证状态） | ✅ | 4d21ade |

### Step 1B 实施详情

**新增文件**：`MLXVoiceNotes/Services/VoiceProfileStorageService.swift`

| 方法 | 职责 |
|------|------|
| `voiceProfilesRoot` | 返回 `~/Library/Application Support/MLX Voice Notes/VoiceProfiles/` |
| `directory(for:)` | 拼接 `<root>/<voiceProfileID>/` |
| `referenceAudioURL(for:originalExtension:)` | 返回 `.../reference.<ext>` |
| `persistReferenceAudio(sourceURL:for:)` | createDirectory → copyItem；重复导入覆盖旧文件 |
| `relativePath(from:)` | 绝对路径 → `VoiceProfiles/<profileID>/reference.<ext>` 相对路径 |
| `absoluteURL(from:)` | 相对路径 → 绝对 URL |
| `assetExists(at:)` | fileExists 检查 |
| `deleteVoiceProfileAssets(for:)` | 删除整个 `<profileID>/` 目录 |

**Build**：✅ `** BUILD SUCCEEDED **`

**下一步**：Step 1C 接入 CreateVoiceProfileView UI（参考音频导入 → 存储 → 写入 VoiceProfile.referenceAudioLocalPath）

### Step 2 实施详情

**改动文件**：`MLXVoiceNotes/MLXVoiceNotes/Views/CreateVoiceProfileView.swift`

- 新增 `@State private var saveError: String?`、`@State private var isSaving = false`
- `saveVoice()` 调用 `VoiceProfileStorageService.shared.persistReferenceAudio()` 保存参考音频
- `VoiceProfileStorageService.swift` 加入 Xcode target membership

**Build**：✅ `** BUILD SUCCEEDED **`

### Step 3 实施详情

**改动文件**：`CreateVoiceProfileView.swift`、`VoiceProfileStorageService.swift`

**CreateVoiceProfileView** 新增状态和方法：
- `@State isGeneratingTest`: 生成中禁用按钮
- `@State testAudioError`: 失败提示
- `@State testAudioPath`: 临时文件路径
- `@State audioPlayer/isPlaying`: 试听播放
- `private let mlxService`: 内部 MLX 服务实例

**generateTestAudio()** 逻辑：
1. 检查参考音频路径 + refText 非空
2. 调用 `mlxService.generateAudio(text:refAudioURL:refText:language:)` 生成到临时目录
3. 成功 → `hasTestAudio=true`，`testAudioPath` 记录临时 URL
4. 失败 → `testAudioError` 显示错误文本

**playTestAudio()** 逻辑：
- 使用 `AVAudioPlayer` 播放 `testAudioPath` 对应的临时文件

**saveVoice()** 保存后逻辑：
- 若 `hasTestAudio=true`，调用 `persistTestAudio(from:for:)` 将临时文件移到 `VoiceProfiles/<id>/test.wav`
- 设置 `profile.isVerifiedForGeneration = true`，`profile.lastTestedAt = Date()`

**VoiceProfileStorageService** 新增：
- `testAudioURL(for:)`: 返回 `<profileDir>/test.wav`
- `persistTestAudio(from:for:)`: createDirectory → moveItem（覆盖旧文件）

**约束遵守**：
- ✅ 不改 GenerationService
- ✅ 不改 SwiftData schema
- ✅ 不接入正式角色生成
- ✅ 测试音频与 GeneratedAudio 目录分离

**Build**：✅ `** BUILD SUCCEEDED **`
# Phase 2 Voice Control Verification — Qwen3-TTS bf16

## Status Summary

| 方向 | 状态 | 结论 |
|------|------|------|
| voice instruct | ❌ 放弃 | Base 模型无法稳定控制音色，不适合 MVP 角色绑定 |
| refAudio/refText | ✅ 通过 | bf16 Base + refAudio + refText 连续生成稳定，测试通过 |

---

## voice instruct 测试结论

### 测试配置

| 项 | 值 |
|----|-----|
| 模型 | Qwen3-TTS-12Hz-0.6B-Base-bf16 |
| 参考音频 | 无 |
| 目标文本 | 你好，这是 MLX Voice Notes 的测试... |
| 生成次数 | 3 |
| voice 参数 | "中文女声，自然、清晰、适合旁白" 等不同 instruct |

### 失败原因

1. **bf16 模型**：instruct 可以改变音色特征，但不同 instruct 之间无明显可区分性，无法用于角色绑定
2. **Base 模型无 Custom Voice 支持**：预设音色名（Vivian/Serena 等）仅对 Custom Voice 模型有效

### 结论
voice instruct **不适合**作为 MVP 多音色稳定绑定方案，已放弃。

---

## Phase 2B: refAudio/refText 稳定性测试

### 测试配置

| 项 | 值 |
|----|-----|
| 模型 | Qwen3-TTS-12Hz-0.6B-Base-bf16 |
| 参考音频 | `/Users/apple/Desktop/李不二聊电商/4月12日音频母带/4月22日声音母带.mp3` |
| 参考文本 | 你永远都搞不清楚这些平台它到底要什么，不要什么，有时候一条视频吧，花几个小时你把它做出来了，发到了a平台呢，正常通过，发到b平台呢，直接限流，有的还给你封号呢 |
| 目标文本 | 你好，这是 MLX Voice Notes 的参考音色稳定性测试。如果三次声音接近一致，说明参考音色可以用于角色绑定。 |
| 生成次数 | 3 |
| 输出目录 | `~/Library/Application Support/MLX Voice Notes/GeneratedAudio/Phase2RefAudio/` |

### generate 参数

```
voice: nil
refAudio: MLXArray (from loadAudioArray)
refText: "你永远都搞不清楚..."
language: "chinese"
generationParameters: model.defaultGenerationParameters
```

### refAudio 加载 API

```swift
let (sr, arr) = try loadAudioArray(from: refAudioURL, sampleRate: model.sampleRate)
```

### 输出文件

| Run | 文件 | 大小 |
|-----|------|------|
| 1 | refAudio_run1.wav | 956 KB |
| 2 | refAudio_run2.wav | 925 KB |
| 3 | refAudio_run3.wav | 895 KB |

---

## Phase 2B 测试结论 ✅

**测试通过** — 2026-05-03 11:19 GMT+8

- 三次连续生成音色稳定
- refAudio + refText 方案可作为 MVP 多音色绑定基础

---

## MVP 多音色路线决策（Phase 2B 完成后）

### 结论

1. **voice instruct 放弃**：连续生成音色不稳定，不能作为 MVP 角色音色绑定方案。
2. **refAudio/refText 确立**：Qwen3 bf16 Base 使用 refAudio + refText 连续生成稳定，通过测试。
3. **VoiceProfile 必须包含参考音频**：角色绑定 VoiceProfile，VoiceProfile 必须包含参考音频和参考文本。
4. **生成链路映射**：生成时按段落角色查 `VoiceRole.defaultVoiceName`，再映射到 `VoiceProfile.refAudio / refText`。
5. **内置音色限制**："默认清晰女声 / 自然男声"等内置音色如果要作为稳定音色，也必须有内置参考音频资产；否则只能作为 UI 占位，不应声称可稳定控制。
6. **下一步**：进入 Phase 2C — VoiceProfile 数据结构与生成链路映射设计。**不要立刻大改正式生成流程**，先设计再评审。

### VoiceProfile 结构需求（Phase 2C）

每个 VoiceProfile 必须包含：

| 字段 | 说明 | 来源 |
|------|------|------|
| `id` | 唯一标识 | SwiftData |
| `name` | 音色名称 | 用户输入 |
| `kind` | builtIn / reference / cloned | 类型 |
| `referenceAudioPath` | 参考音频本地路径 | **必须** |
| `referenceText` | 参考音频对应文本 | **必须** |
| `language` | 语言 | 可选 |
| `durationSeconds` | 参考音频时长 | 可选 |
| `status` | builtIn / available / pendingReview | 状态 |

### 生成链路映射设计（Phase 2C）

```
ScriptSegment.voiceRole → VoiceRole.defaultVoiceName
    → VoiceProfile (by name or id)
    → refAudio / refText
    → MLXAudioService.generate(..., refAudio:, refText:, ...)
```

---

## 后续决策树（更新后）

```
Phase 2B 结果
└── ✅ refAudio/refText 稳定 → 进入 Phase 2C

Phase 2C: VoiceProfile 数据结构 + 生成链路映射设计
├── VoiceProfile 增加 refAudio/refText 字段
├── VoiceRole → VoiceProfile 映射关系
├── GenerationService.generate 调用增加 refAudio/refText 参数
└── 评审通过后 → Phase 3 正式实现
```

---

## 约束遵守

- ✅ 不改正式文案生成流程
- ✅ 不改 SwiftData schema（Phase 2C 设计后统一改）
- ✅ 不接入角色绑定
- ✅ 不下载模型
- ✅ 使用默认 bf16 模型
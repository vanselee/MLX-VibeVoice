# Phase 2 Voice Control Verification — Qwen3-TTS bf16

## Status Summary

| 方向 | 状态 | 结论 |
|------|------|------|
| voice instruct | ❌ 不适合 | Base 模型无法通过 instruct 稳定控制音色，8bit 模型输出杂音 |
| refAudio/refText | ⏳ 测试中 | Qwen3-TTS Base 支持参考音频克隆，待验证稳定性 |

---

## voice instruct 测试结论

### 原因
Qwen3-TTS Base 模型（bf16）在无参考音频时，voice instruct 参数无法稳定控制音色：

1. **8bit 模型**：输出几乎全为噪声，无论 instruct 文案如何（已排除，commit 73376b0）
2. **bf16 模型**：instruct 可以改变音色特征，但不同 instruct 之间无明显可区分性，无法用于角色绑定
3. **Base 模型无 Custom Voice 支持**：预设音色名（Vivian/Serena 等）仅对 Custom Voice 模型有效

### 结论
voice instruct **不适合**作为 MVP 多音色稳定绑定方案。

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
refAudioArray = try loadAudioArray(from: refAudioURL, sampleRate: model.sampleRate)
```

---

## 结果记录（Phase 2B）

### 稳定性评估

| Run | 文件 | maxAbs | rms | duration (s) | 主观听感 |
|-----|------|--------|-----|-------------|---------|
| 1 | refAudio_run1.wav | | | | |
| 2 | refAudio_run2.wav | | | | |
| 3 | refAudio_run3.wav | | | | |

### 评估标准

**稳定性**：三次生成是否接近一致
- ✅ 三次音色基本相同
- ⚠️ 三次有轻微差异
- ❌ 三次差异明显

**音色匹配度**：生成音色是否接近参考音频
- ✅ 与参考音频音色一致
- ⚠️ 部分接近
- ❌ 与参考音频明显不同

---

## 后续决策树

```
Phase 2B 稳定性测试结果
├── ✅ 三次一致 + 音色匹配 → 进入 Phase 3（正式音色克隆流程）
│                                  MVP 音色绑定基于参考音频资产
│
├── ⚠️ 三次基本一致 + 部分匹配 → 评估 instruct 微调
│                                   记录为 "可用但需调整"
│
└── ❌ 三次差异明显或不匹配 → Qwen3 Base 不满足多音色 MVP
                                    建议评估:
                                    - CustomVoice 模型 (需下载)
                                    - VoiceDesign API (需网络)
                                    - Python CLI 路线 (需环境配置)
```

---

## 约束遵守

- ✅ 不改正式文案生成流程
- ✅ 不改 SwiftData schema
- ✅ 不接入角色绑定
- ✅ 不下载模型
- ✅ 使用默认 bf16 模型
# Phase 2A: Voice Instruct 稳定性测试

## 目标
验证 Qwen3-TTS bf16 的 voice instruct 是否能稳定控制音色，为正式多角色生成流程做准备。

## 测试配置

| 项 | 值 |
|----|-----|
| 模型 | Qwen3-TTS-12Hz-0.6B-Base-bf16 |
| 测试文本 | "你好，欢迎来到 MLX Voice Notes，今天我们将测试语音合成效果。" |
| 每组生成次数 | 3 |
| 总生成次数 | 9 |

## Voice Instruct 矩阵

| 组 | voice instruct | 用途 |
|----|--------------|------|
| A1 | 中文女声，自然、清晰、适合旁白 | 中文女声 |
| A2 | 中文男声，沉稳、浑厚、适合解说 | 中文男声 |
| A3 | 平淡叙述，无感情色彩 | 旁白风格 |

## 输出位置

`~/Library/Application Support/MLX Voice Notes/GeneratedAudio/Phase2VoiceInstruct/`

文件命名：`A1_run1.wav` ~ `A3_run3.wav`

## 测试方法

1. 启动 MLX Voice Notes App
2. 进入 "Phase 0: MLX TTS Test" 页面
3. 确认模型状态为 "Model Ready"
4. 点击 **"Phase 2A: Voice Instruct Test"** 按钮
5. 等待 9 次生成完成（约 5-10 分钟）
6. 查看控制台输出和 UI 结果面板
7. 逐个播放 WAV 文件，评估主观听感

## 结果记录模板

### A1: 中文女声，自然、清晰、适合旁白

| Run | 文件 | duration | maxAbs | rms | 主观听感 |
|-----|------|----------|--------|-----|---------|
| 1 | A1_run1.wav | | | | |
| 2 | A1_run2.wav | | | | |
| 3 | A1_run3.wav | | | | |

### A2: 中文男声，沉稳、浑厚、适合解说

| Run | 文件 | duration | maxAbs | rms | 主观听感 |
|-----|------|----------|--------|-----|---------|
| 1 | A2_run1.wav | | | | |
| 2 | A2_run2.wav | | | | |
| 3 | A3_run3.wav | | | | |

### A3: 平淡叙述，无感情色彩

| Run | 文件 | duration | maxAbs | rms | 主观听感 |
|-----|------|----------|--------|-----|---------|
| 1 | A3_run1.wav | | | | |
| 2 | A3_run2.wav | | | | |
| 3 | A3_run3.wav | | | | |

## 评估标准

### 稳定性
- ✅ 同一组 3 次生成的音色基本一致
- ⚠️ 音色有轻微差异但可接受
- ❌ 音色差异明显，无法作为固定角色使用

### 音色匹配度
- ✅ 音色符合 instruct 描述
- ⚠️ 部分符合（如 A1 听起来像女声但不够自然）
- ❌ 音色与 instruct 不匹配

### MVP 可用性
- ✅ 可用于 MVP 多角色生成
- ⚠️ 可用但需调整 instruct 文案
- ❌ 不可用，需换模型或方案

## refAudio/refText 状态

**待验证** — Qwen3-TTS Base 模型是否支持 refAudio/refText 参数尚无源码或实测确认，当前测试传 nil。

## 约束遵守

- ✅ 不改正式文案生成流程
- ✅ 不改 SwiftData schema
- ✅ 不接入角色绑定
- ✅ 不做 refAudio/refText
- ✅ UI 改动最小（仅添加一个测试按钮 + 结果面板）

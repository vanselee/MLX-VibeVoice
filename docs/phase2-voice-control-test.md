# Phase 2: 音色可控性验证方案

## 目标
验证 Qwen3-TTS bf16 的音色控制能力（voice instruct），为正式多角色生成流程做准备。

## 测试矩阵

### 1. voice instruct 测试（3 组 × 3 次 = 9 次）

| 组 | voice instruct | 用途 |
|----|--------------|------|
| A1 | 中文女声，自然、清晰、适合旁白 | 中文女声 |
| A2 | 中文男声，沉稳、浑厚、适合解说 | 中文男声 |
| A3 | 平淡叙述，无感情色彩 | 旁白风格 |

测试文本：`"你好，欢迎来到 MLX Voice Notes，今天我们将测试语音合成效果。"`

### 2. refAudio/refText 测试

**状态：待验证** — Qwen3-TTS Base 模型是否支持 refAudio/refText 参数尚无源码或实测确认，传 nil 作为保守默认值。

### 3. 稳定性验证

每组连续生成 3 次，记录：
- maxAbs / rms / duration 是否一致
- 主观听感是否稳定

## 预期结论

| 控制方式 | MVP 可用性 | 说明 |
|---------|----------|------|
| voice instruct | 待验证 | Base 模型唯一可用方式 |
| refAudio/refText | 待验证 | Base 模型支持情况待确认 |

## 正式角色绑定方案（待定）

如果 voice instruct 可用：

| 角色 | voice instruct |
|------|-------------|
| 清晰女声 | "中文女声，自然、清晰、适合旁白" |
| 自然男声 | "中文男声，沉稳、浑厚、适合解说" |
| 旁白风格 | "平淡叙述，无感情色彩" |

## 输出位置

`~/Library/Application Support/MLX Voice Notes/GeneratedAudio/Phase2/`
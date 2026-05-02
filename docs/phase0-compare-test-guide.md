# Phase 0 对照测试执行指南

## 测试目标
验证 Qwen3-TTS 8bit 模型在不同 voice instruct 配置下的音频输出质量，诊断是否仍有杂音问题。

## 测试矩阵

| # | voice (instruct) | 预期记录 |
|---|-------------------|----------|
| 1 | `nil`（留空或输入 "default"） | 诊断数据 + 主观听感 |
| 2 | `中文女声，自然、清晰、适合旁白` | 诊断数据 + 主观听感 |
| 3 | `中文男声，自然、稳定、适合解说` | 诊断数据 + 主观听感 |

## 执行步骤

### 1. 启动 App
```bash
open /tmp/MLXVoiceNotesDerivedDataCompareTest2/Build/Products/Debug/MLX\ Voice\ Notes.app
```

### 2. 进入测试页面
- 点击左侧边栏 "Phase 0: MLX TTS Test"

### 3. 执行对照测试

#### 测试 #1：voice = nil
1. Voice Instruct 输入框：输入 `default` 或点击 Clear 按钮
2. 点击 "Generate Audio"
3. 等待生成完成
4. 查看诊断信息：
   - samples: ?
   - maxAbs: ?
   - rms: ?
   - sampleRate: ?
   - duration: ?
5. 点击 "Play" 播放
6. 记录主观听感：正常语音 / 杂音 / 静音

#### 测试 #2：voice = 中文女声
1. Voice Instruct 输入框：输入 `中文女声，自然、清晰、适合旁白`
2. 重复步骤 2-6

#### 测试 #3：voice = 中文男声
1. Voice Instruct 输入框：输入 `中文男声，自然、稳定、适合解说`
2. 重复步骤 2-6

## 记录模板

```markdown
### 测试 #1
- voice: nil
- samples: ?
- maxAbs: ?
- rms: ?
- sampleRate: ?
- duration: ?
- 主观听感: ?

### 测试 #2
- voice: 中文女声，自然、清晰、适合旁白
- samples: ?
- maxAbs: ?
- rms: ?
- sampleRate: ?
- duration: ?
- 主观听感: ?

### 测试 #3
- voice: 中文男声，自然、稳定、适合解说
- samples: ?
- maxAbs: ?
- rms: ?
- sampleRate: ?
- duration: ?
- 主观听感: ?
```

## 决策规则

| 结果 | 下一步 |
|------|--------|
| 3 条均为杂音或近似静音 | **停止 8bit 方向**，转向 bf16 本地模型复现 |
| 任一条为正常语音 | 记录成功配置，继续优化其他参数 |
| 结果不一致 | 分析差异，调整 temperature/topP/topK |

## bf16 本地模型路径
```
/Users/apple/Desktop/SoftDev/aiaudiovideo/MLXVoiceNotesAssets/Models/mlx-community_Qwen3-TTS-12Hz-0.6B-Base-bf16
```

## 约束检查
- ✅ 不下载模型
- ✅ 不移动模型文件
- ✅ 不改 SwiftData schema
- ✅ 不接入正式生成流程

## Commit
- `4cd216e` — `feat(phase0): add voice instruct input and diag display for compare test`

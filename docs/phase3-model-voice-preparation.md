# P3C Step 3 — 模型 × 音色准备状态设计

> 状态：设计文档（不涉及实现代码）
> 日期：2026-05-10

---

## 1. 核心结论

### 1.1 每个模型必须有独立的生成参数配置

音色预学习 / conditioning 的计算结果与模型架构强耦合。不同模型有不同的：

- 隐层维度（hidden size）
- 注意力头数（attention heads）
- 量化方式（fp16 / bf16 / 8bit / 4bit）
- 训练语料分布

因此，**同一音色在不同模型之间不能默认复用预学习结果**。即使两个模型架构相同但量化精度不同，其 conditioning 向量也可能不兼容。

### 1.2 音色预学习文件必须严格按复合 key 绑定

缓存 key 必须同时包含：

| 字段 | 说明 |
|------|------|
| `modelRepo` | 模型仓库标识（必填） |
| `voiceProfileID` | 音色档案 ID（必填） |
| `referenceAudioHash` | 参考音频 SHA-256（必填） |
| `referenceTextHash` | 参考文本 SHA-256（必填） |
| `appVersion` | 可选，防止跨版本不兼容 |
| `modelRevision` | 可选，模型权重版本变化时使缓存失效 |

> ⚠️ **禁止**仅用 `voiceProfileID` 作为缓存 key 的原因：用户更新参考音频后，旧的预处理文件绝不应当被复用。

### 1.3 不同模型之间不能复用音色预学习文件

即使用户选择了同一个音色角色，如果切换了模型（如从 Qwen3-0.6B 切换到 Qwen3-1.7B），**必须重新为新模型生成/加载音色 conditioning**，哪怕参考音频和参考文本完全相同。

### 1.4 bf16 / 8bit / 4bit 量化精度也不能默认复用

量化精度变化后，模型权重数值范围发生变化，直接复用上一次 fp16 生成的 conditioning 会导致音色失真。必须在缓存 key 中体现精度差异（通过 `modelRepo` 中已包含的信息来区分）。

---

## 2. 当前阶段现状

> 以下描述的是 Phase 3 之前的实际状态，而非设计目标。

| 方面 | 现状 |
|------|------|
| 参考音频文件持久化 | ✅ 已实现，存储在 `~/Library/Application Support/MLX Voice Notes/VoiceProfiles/<voiceProfileID>/` |
| 参考文本持久化 | ✅ 已实现，存储在 SwiftData `VoiceProfile` 中 |
| MLXArray 内存缓存 | ✅ 已实现，缓存在 `MLXAudioService` 内存中 |
| conditioning / speaker embedding 文件持久化 | ❌ **尚未实现**，当前没有文件级持久化 |
| 音色可用性判断 | ⚠️ 当前"音色可用"仅意味着参考音频和参考文本可读，**不代表已针对当前模型完成准备** |

**当前关键缺陷**：如果用户切换到另一个模型，上一次生成的 conditioning 缓存会因模型卸载而清空，再次生成时没有持久化的 conditioning 文件可以复用，会导致音色与上次不一致（除非重新预学习）。

---

## 3. 未来状态设计：VoiceProfileAssetStatus

### 3.1 枚举定义（Swift）

```swift
enum VoiceProfileAssetStatus {
    /// 参考音频和参考文本可读，但尚未针对任何模型完成准备
    case assetReady
    
    /// 已针对指定模型完成音色准备，可以直接用于生成
    case modelReady(modelRepo: String)
    
    /// 正在为指定模型准备音色 conditioning
    case preparing(modelRepo: String)
    
    /// 为指定模型准备音色失败，阻止使用该音色生成
    case failed(modelRepo: String, reason: String)
}
```

### 3.2 状态流转语义

```
[用户上传参考音频 + 参考文本]
        ↓
   assetReady  ← 最低保证：原材料可读
        ↓
[用户选择音色 + 切换模型]
        ↓
   preparing(modelRepo)  ← 开始为当前模型计算 conditioning
        ↓
   modelReady(modelRepo)  ← 成功，下次直接使用
   or
   failed(modelRepo, reason)  ← 失败，阻止生成
```

### 3.3 设计原则

- `assetReady` 是所有状态的根起点，不可跳过后续状态直接使用音色。
- `modelReady(modelRepo)` 与具体模型绑定，同一个音色对模型 A 是 `modelReady`，对模型 B 可能是 `assetReady`（未准备）。
- `preparing` 和 `failed` 是过渡/终态，`failed` 需要用户主动触发重试。

---

## 4. 缓存 Key 结构

```
{modelRepo}/{voiceProfileID}/{referenceAudioHash}/{referenceTextHash}/[可选字段]
```

**目录结构示例**（未来持久化时）：

```
~/Library/Application Support/MLX Voice Notes/
└── VoiceProfiles/
    └── {voiceProfileID}/
        ├── reference_audio.wav
        ├── reference_text.txt
        └── conditioning/
            └── {modelRepo}/
                ├── {referenceAudioHash}_{referenceTextHash}.mlxdat
                └── metadata.json
```

**metadata.json 内容**：

```json
{
  "modelRepo": "mlx-community/Qwen3-TTS-0.6B",
  "referenceAudioHash": "sha256:abc123...",
  "referenceTextHash": "sha256:def456...",
  "createdAt": "2026-05-10T12:00:00Z",
  "appVersion": "0.1.0",
  "conditioningType": "reference_conditioning"
}
```

---

## 5. 模型切换后的行为规范

### 5.1 切换触发流程

```
用户切换模型
    ↓
检查：当前音色（voiceProfileID）是否已有 modelReady(新modelRepo) 记录
    ├── 有 → 直接可用，无需额外操作
    └── 无 → UI 显示"需准备"状态
    ↓
用户点击"生成音频"
    ↓
[检测] 当前音色是否是 assetReady？
    ├── 是 → 自动触发 preparing(新modelRepo)
    │         完成后 → modelReady(新modelRepo)
    │         失败 → failed(新modelRepo, reason)，阻止生成
    └── 否（无参考材料）→ 提示用户先上传参考音频
```

### 5.2 UI 状态显示（设计，不含实现）

| 状态 | 建议显示 |
|------|----------|
| `assetReady` | 音色已加载，模型切换后将重新准备 |
| `modelReady(当前模型)` | ✅ 音色就绪 |
| `preparing(当前模型)` | ⏳ 正在准备音色... |
| `failed(当前模型, reason)` | ❌ 音色准备失败：[reason]，点击重试 |

### 5.3 生成阻断规则

- 如果目标模型没有该音色的 `modelReady` 记录，**不能直接开始正文生成**，必须先完成音色准备。
- 音色准备失败时，显示具体错误原因（如"模型不支持 reference conditioning"、"参考音频采样率不匹配"），不阻塞用户其他操作。

---

## 6. 后续实现顺序建议

### Phase A：模型独立生成参数

**目标**：每个模型保存自己的一套 `defaultGenerationParameters`（语速、音调等），切换模型时使用对应参数。

**前置条件**：无，完全独立模块。
**收益**：为后续所有音色准备奠定基础。

### Phase B：导出完整性门禁

**目标**：生成音频前，检查所有原材料（模型、参考音频、参考文本、生成参数）是否完整可用。

**前置条件**：Phase A（需要模型独立参数）。
**收益**：防止半成品状态触发 MLX 调用，减少调试成本。

### Phase C：模型级音色准备状态

**目标**：实现 `VoiceProfileAssetStatus` 枚举、状态流转逻辑、UI 状态显示。

**前置条件**：Phase B（需要原材料完整性检查）。
**收益**：用户明确感知音色准备进度和状态。

### Phase D：持久化 Qwen3 Reference Conditioning（可选）

**目标**：将计算出的 conditioning 写入文件系统，支持跨会话复用。

**前置条件**：Phase C 完成并稳定运行。
**技术风险**：Qwen3-TTS 的 conditioning 格式和持久化接口尚未确认，此阶段可能有较大不确定性。
**替代方案**：如持久化不可行，可考虑每次生成时重新计算（利用内存缓存加速）。

---

## 7. 设计约束与风险

| 风险 | 说明 | 缓解措施 |
|------|------|----------|
| conditioning 格式不确定 | Qwen3-TTS 的 conditioning 输出格式和持久化方式尚未确认 | Phase D 设为可选，发现不兼容时降级为纯内存缓存 |
| 参考音频变化检测 | 用户可能修改参考音频但忘记更新 | 以 `referenceAudioHash` 作为缓存 key 的必填字段 |
| 多模型 × 多音色组合爆炸 | 每个组合都可能需要独立缓存，存储空间增长快 | 缓存按 `{modelRepo}/{voiceProfileID}/` 组织，必要时可清理旧缓存 |
| 量化精度差异 | bf16 / 8bit / 4bit 的 conditioning 不兼容 | 缓存 key 中通过 `modelRepo` 已隐含量化精度信息 |

---

## 8. 术语表

| 术语 | 定义 |
|------|------|
| **音色预学习 / conditioning** | 将参考音频和参考文本转换为模型可用的 latent 向量，作为生成时的条件输入 |
| **speaker embedding / speaker prompt** | 与 conditioning 概念相关，特指说话人特征向量 |
| **VoiceProfile** | SwiftData 模型，存储音色角色的元数据（ID、名称、描述、参考音频路径） |
| **VoiceProfileAssetStatus** | 枚举，表示某个音色角色对某个模型的准备状态 |
| **modelRepo** | 模型在 HuggingFace 上的仓库标识，如 `mlx-community/Qwen3-TTS-0.6B` |
| **referenceAudioHash** | 参考音频文件的 SHA-256，用于检测音频是否发生变化 |
| **referenceTextHash** | 参考文本的 SHA-256，用于检测文本是否发生变化 |

# Phase 0 Spike: mlx-audio-swift 集成计划

此文档记录 Phase 0 Spike 的目标、要求和验证标准。

---

## 🎯 Phase 0 目标

1. ✅ 验证 mlx-audio-swift 是否可以集成到我们的项目中
2. ✅ 验证可以在 Apple Silicon 上本地生成单句 TTS
3. ✅ 验证性能（速度、内存）
4. ✅ 验证输出音频质量

---

## 📋 验收标准

### 必须通过 (Passing)

- [ ] 可以编译项目，无链接错误
- [ ] 可以导入并调用 mlx-audio-swift
- [ ] 可以加载模型（使用默认模型）
- [ ] 可以将文本转为音频，保存 WAV 文件
- [ ] 音频可以播放，声音清晰可懂
- [ ] 单次生成（~20 字）速度 < 5 秒
- [ ] 内存占用合理（< 500MB）

### 可选通过 (Nice to Have)

- [ ] 支持不同声音
- [ ] 支持调整语速
- [ ] 支持调整音量
- [ ] 支持参考音频克隆

---

## 🔧 集成步骤

### 步骤 1：下载模型文件

根据 mlx-integration-guide.md：

```bash
git clone https://github.com/Blaizzy/mlx-audio-swift.git
```

### 步骤 2：复制模型文件到项目

从下载的仓库中复制：
- Kokoro 模型文件到 `Resources/Kokoro/`
- Voice 文件到 `Resources/Kokoro/voices/`
- espeak-ng-data 到 `Resources/Kokoro/`

### 步骤 3：添加模型到 Xcode

1. 在 Xcode 中创建 Resources 文件夹
2. 添加模型文件到 Copy Bundle Resources

### 步骤 4：更新代码

更新 `MLXAudioService.swift`，实现真正的 Kokoro TTS。

### 步骤 5：测试

使用 MLXTestView 进行测试。

---

## 📊 性能基准

| 指标 | 目标 | 备注 |
|------|------|------|
| 启动加载 | < 2秒 | 第一次启动加载模型 |
| 20字生成 | < 3秒 | 单句，中等长度 |
| 100字生成 | < 15秒 | 长文本，分段生成 |
| 峰值内存 | < 500MB | 单次生成期间 |

---

## 📝 实验记录

### 第一次尝试

- **日期**: 2026-05-02
- **设备**: 待定
- **结果**: ⏳ 待测试
- **备注**: 代码骨架已完成

---

## 🚨 风险与备选方案

### 风险 1：mlx-audio-swift 无法集成
- **备选**: 使用其他本地 TTS 库
- **备选**: 使用远程 API

### 风险 2：性能太差
- **备选**: 使用更轻量模型
- **备选**: 降低采样率

### 风险 3：质量不够好
- **备选**: 添加模型选项，让用户选择
- **备选**: 同时支持云端 API

---

## 🚀 下一步计划

如果 Phase 0 通过，下一步：
1. 替换 GenerationService 的占位实现
2. 集成到文案生成流程
3. 支持多音色选择
4. 实现声音克隆

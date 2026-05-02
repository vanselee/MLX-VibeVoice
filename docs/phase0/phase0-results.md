# Phase 0 验证记录

## 实验 #1: 代码骨架搭建

- **日期**: 2026-05-02
- **状态**: ✅ 完成
- **内容**:
  - 创建 MLXAudioService.swift 服务骨架
  - 创建 MLXTestView.swift 测试视图
  - 更新 ContentView.swift 添加 Debug 测试入口
  - 创建 mlx-integration-guide.md 集成指南
  - 更新 spike-plan.md 集成计划
- **结果**: 代码骨架完成，待手动验证

---

## 实验 #2: mlx-audio-swift SPM 依赖集成

- **日期**: 2026-05-02
- **状态**: ✅ 完成
- **内容**:
  - 通过 Xcode GUI 手动添加 mlx-audio-swift SPM 依赖
  - 更新 MLXAudioService.swift 适配真实 API
  - 添加本地缓存完整性检查，阻止自动下载
  - 自定义 createWAVData 函数将 [Float] 转换为 WAV 格式
- **结果**: BUILD SUCCEEDED，代码提交 (commit 60d33d0)

---

## 实验 #3: Qwen3 模型策略修正

- **日期**: 2026-05-02
- **状态**: ✅ 完成
- **内容**:
  - 移除 Soprano/Pocket/Kokoro/VyvoTTS 示例模型
  - 默认模型改为 Qwen3-TTS-12Hz-0.6B-Base-8bit
  - 添加本地缓存完整性检查，阻止自动下载
  - 更新测试文本为中文
  - 更新文档明确当前阶段只测试 Qwen3
- **结果**: 待 build 验证

---

## 实验 #4: 8bit vs bf16 对照测试

- **日期**: 2026-05-02
- **状态**: ✅ 完成
- **内容**:
  - 添加 Voice Instruct 输入框和诊断信息显示
  - 执行 3 组 voice instruct 对照测试
  - 记录诊断数据（samples/maxAbs/rms/sampleRate）
  - 主观听感验证
- **结果**:
  - **8bit 模型**: ❌ 失败，输出为杂音
  - **bf16 模型**: ✅ 通过，可生成可听语音
- **决策**: bf16 作为 MVP 默认候选，8bit 仅作为实验模型

---

## 验证清单

### 代码层面
- [x] MLXAudioService.swift 编译通过
- [x] MLXTestView.swift 编译通过
- [x] Debug 测试入口正常显示

### 功能层面
- [x] 模型加载成功（bf16）
- [x] 文本生成音频成功（bf16）
- [x] 音频保存为 WAV 文件
- [x] 音频可以播放
- [ ] 支持不同声音切换（待测试）

### 性能层面
- [ ] 模型加载时间 < 5秒
- [ ] 单句生成时间 < 3秒
- [ ] 内存占用 < 1GB
- [ ] 无明显卡顿

### 质量层面
- [x] 音频清晰可懂（bf16）
- [x] 声音自然（bf16）
- [x] 无明显杂音（bf16）

---

## 问题记录

| 日期 | 问题 | 解决方案 | 状态 |
|------|------|---------|------|
| 2026-05-02 | pbxproj add_package 参数不匹配 | 改用 Xcode GUI 手动添加 SPM 依赖 | ✅ 已解决 |
| 2026-05-02 | saveAudioArray 函数不存在 | 自定义 createWAVData 函数转换 [Float] 为 WAV | ✅ 已解决 |
| 2026-05-02 | Soprano 等模型不符合产品策略 | 移除示例模型，只保留 Qwen3 系列 | ✅ 已解决 |
| 2026-05-02 | Qwen3 8bit 输出杂音 | 改用 bf16 模型作为默认 | ✅ 已解决 |

---

## 下一步行动

1. [x] 添加 mlx-audio-swift SPM 依赖
2. [x] 更新 MLXAudioService.swift 适配真实 API
3. [x] 移除非 Qwen3 模型
4. [x] 添加本地缓存完整性检查
5. [x] 运行真实测试验证音频生成
6. [x] 记录性能和质量结果
7. [ ] 替换 GenerationService 的占位实现
8. [ ] 集成到文案生成流程

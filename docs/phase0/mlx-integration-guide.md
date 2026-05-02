# Phase 0: mlx-audio-swift 集成指南

## 📋 概述

mlx-audio-swift 是一个本地 TTS 库，支持 Qwen3-TTS、Kokoro、Orpheus 和 Marvis 模型。

**当前阶段策略**：只测试 Qwen3-TTS-12Hz-0.6B-Base-8bit，其他模型（Kokoro/Orpheus/Marvis/Soprano/Pocket/VyvoTTS）不进入本轮测试。

## 🎯 支持的模型

### 1. Qwen3-TTS 0.6B Base 8bit（当前测试模型）
- **特点**：中文支持，体积小，适合 MVP
- **Hugging Face repo**：`mlx-community/Qwen3-TTS-12Hz-0.6B-Base-8bit`
- **本地缓存**：`~/.cache/huggingface/hub/mlx-audio/mlx-community_Qwen3-TTS-12Hz-0.6B-Base-8bit`
- **体积**：约 528MB
- **语言**：中文、英文
- **状态**：✅ 本地缓存完整，已集成

### 2. Qwen3-TTS 0.6B Base bf16（候选，暂不测试）
- **特点**：更高精度，但体积更大
- **Hugging Face repo**：`mlx-community/Qwen3-TTS-12Hz-0.6B-Base-bf16`
- **体积**：约 2.3GB
- **状态**：⚠️ 未接入本地 cache 映射，暂不测试

### 3. Kokoro（非当前 MVP 模型）
- **特点**：速度快，体积小，音质好
- **状态**：❌ 不进入本轮测试

### 4. Orpheus（非当前 MVP 模型）
- **特点**：支持情感表达
- **状态**：❌ 不进入本轮测试

### 5. Marvis（非当前 MVP 模型）
- **特点**：流式生成，对话场景优化
- **状态**：❌ 不进入本轮测试

### 6. Soprano/Pocket/VyvoTTS（非当前 MVP 模型）
- **状态**：❌ 不进入本轮测试

## 🔧 集成步骤

### 步骤 1：下载 mlx-audio-swift 仓库

```bash
git clone https://github.com/Blaizzy/mlx-audio-swift.git
```

### 步骤 2：复制必要文件

从下载的仓库中复制以下文件到项目：

```
mlx-audio-swift/
├── MLXAudio/Resources/Kokoro/
│   ├── kokoro-v1_0.safetensors
│   ├── voices/
│   │   ├── af_bella.safetensors
│   │   ├── af_nicole.safetensors
│   │   └── ... 其他声音文件
│   └── espeak-ng-data/
│       └── ... eSpeak NG 数据
└── MLXAudio/Resources/Orpheus/
    └── ... Orpheus 模型文件
```

### 步骤 3：添加依赖到 Xcode

1. 打开 `MLXVoiceNotes.xcodeproj`
2. 选择项目 -> Build Phases
3. 添加以下文件到 "Copy Bundle Resources"：
   - 所有 Kokoro 模型文件
   - 所有 voice 文件
   - espeak-ng-data 文件夹

### 步骤 4：修改代码

#### 更新 MLXAudioService.swift

```swift
import Foundation
import AVFoundation
import MLX
import MLXSwift
import MLXAudio

class MLXAudioService: ObservableObject {
    @Published var isModelLoaded = false
    @Published var isGenerating = false
    @Published var progress: Double = 0
    @Published var errorMessage: String?
    
    private var ttsEngine: KokoroTTS?
    private var currentVoice: String = "af_bella"
    
    init() {
        loadModel()
    }
    
    func loadModel() async {
        do {
            // 加载 Kokoro 模型
            let modelPath = Bundle.main.resourcePath! + "/Kokoro"
            ttsEngine = try KokoroTTS(modelPath: modelPath)
            await MainActor.run {
                isModelLoaded = true
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load model: \(error.localizedDescription)"
            }
        }
    }
    
    func generateAudio(text: String, voice: String = "af_bella") async throws -> URL {
        guard let engine = ttsEngine else {
            throw TTSError.modelNotLoaded
        }
        
        await MainActor.run {
            isGenerating = true
            progress = 0
        }
        
        do {
            // 生成音频
            let audioData = try await engine.generate(text: text, voice: voice)
            
            // 保存为 WAV 文件
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = UUID().uuidString + ".wav"
            let url = tempDir.appendingPathComponent(fileName)
            
            try audioData.write(to: url)
            
            await MainActor.run {
                isGenerating = false
                progress = 1.0
            }
            
            return url
        } catch {
            await MainActor.run {
                isGenerating = false
                errorMessage = error.localizedDescription
            }
            throw error
        }
    }
    
    func setVoice(_ voiceName: String) {
        currentVoice = voiceName
    }
    
    func availableVoices() -> [String] {
        // 返回可用的声音列表
        return ["af_bella", "af_nicole", "af_sarah", "af_sky", "bf_emma", "bf_isabella"]
    }
}

enum TTSError: Error {
    case modelNotLoaded
    case generationFailed
    case audioSaveFailed
}
```

## 📱 macOS 应用配置

### Info.plist 设置

确保添加必要的权限：

```xml
<key>NSDocumentsFolderUsageDescription</key>
<string>需要访问 Documents 文件夹来保存导出的音频文件</string>
```

### entitlements

如果需要沙盒：

```xml
<key>com.apple.security.app-sandbox</key>
<false/>
```

## 🧪 测试

### 本地测试脚本

```swift
func testKokoroTTS() async {
    let service = MLXAudioService()
    
    // 等待模型加载
    try? await Task.sleep(nanoseconds: 2_000_000_000)
    
    // 测试生成
    do {
        let url = try await service.generateAudio(
            text: "你好，这是一段测试音频。",
            voice: "af_bella"
        )
        print("Generated: \(url)")
    } catch {
        print("Error: \(error)")
    }
}
```

## 📊 性能基准

| 指标 | Kokoro | Orpheus | Marvis |
|------|--------|---------|--------|
| 模型大小 | ~300MB | ~2GB | ~1GB |
| 生成速度 | ~10x 实时 | ~0.1x 实时 | ~5x 实时 |
| 内存占用 | ~500MB | ~3GB | ~1.5GB |
| 音质 | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |

## 🚨 常见问题

### Q: 模型文件太大？
A: 可以只下载 Kokoro 模型（约 300MB），跳过 Orpheus。

### Q: 编译报错 "module not found"?
A: 确保模型文件已正确添加到 Xcode 项目的 Copy Bundle Resources。

### Q: 内存不足？
A: 建议 8GB 以上 RAM，关闭其他应用。

### Q: 生成速度慢？
A: Orpheus 在 M1 上约 0.1x 实时，Kokoro 约 10x 实时。

## 📝 下一步

1. 下载 Kokoro 模型文件
2. 添加到 Xcode 项目
3. 更新 MLXAudioService.swift
4. 运行 MLXTestView 测试
5. 验证生成质量和速度

## 🔗 参考资源

- mlx-audio-swift 仓库：https://github.com/Blaizzy/mlx-audio-swift
- Kokoro 模型下载：https://huggingface.co/mlx-community/Kokoro
- Orpheus 模型下载：https://huggingface.co/mlx-community/Orpheus

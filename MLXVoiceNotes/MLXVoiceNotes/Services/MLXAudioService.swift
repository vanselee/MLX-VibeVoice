import Foundation
import AVFoundation

#if canImport(MLXAudioTTS)
import MLXAudioTTS
import MLXAudioCore
import MLXLMCommon
import MLX
#endif

struct AudioDiagInfo {
    let fileName: String
    let sampleCount: Int
    let maxAbs: Double
    let rms: Double
    let sampleRate: Int
    let filePath: String
    let durationSec: Double
}

// MARK: - Instruct Voice 测试候选（自由文本，非预设名）
let testInstructVoices: [String?] = [
    nil,  // 无 instruct
    "中文女声，自然、清晰、适合旁白",
    "中文男声，自然、稳定、适合解说"
]

class MLXAudioService: ObservableObject {
    @Published var isModelLoaded = false
    @Published var isGenerating = false
    @Published var progress: Double = 0
    @Published var errorMessage: String?
    @Published var availableVoices: [String] = []
    @Published var currentModelName: String = "Simulated"
    @Published var lastDiag: AudioDiagInfo?  // 最近一次生成的诊断信息

#if canImport(MLXAudioTTS)
    private var ttsModel: (any SpeechGenerationModel)?
#endif

    init() {
        Task {
            await loadModel()
        }
    }

    func loadModel() async {
        await MainActor.run {
            isModelLoaded = false
            errorMessage = nil
        }

#if canImport(MLXAudioTTS)
        // Phase 0 结论：bf16 通过，8bit 输出杂音
        // 默认使用 bf16 本地模型
        let modelRepo = "mlx-community/Qwen3-TTS-12Hz-0.6B-Base-bf16"
        let cacheDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cache/huggingface/hub/mlx-audio/mlx-community_Qwen3-TTS-12Hz-0.6B-Base-bf16")

        let requiredFiles = [
            "config.json",
            "model.safetensors",
            "tokenizer_config.json",
            "generation_config.json",
            "vocab.json",
            "merges.txt"
        ]

        var cacheValid = true
        var missingFiles: [String] = []

        for file in requiredFiles {
            let filePath = cacheDir.appendingPathComponent(file)
            if !FileManager.default.fileExists(atPath: filePath.path) {
                cacheValid = false
                missingFiles.append(file)
                break
            }
            if let attrs = try? FileManager.default.attributesOfItem(atPath: filePath.path),
               let size = attrs[.size] as? Int, size == 0 {
                cacheValid = false
                missingFiles.append("\(file) (empty)")
                break
            }
        }

        // 检查 speech_tokenizer/config.json
        let speechTokenizerConfig = cacheDir.appendingPathComponent("speech_tokenizer/config.json")
        if !FileManager.default.fileExists(atPath: speechTokenizerConfig.path) {
            cacheValid = false
            missingFiles.append("speech_tokenizer/config.json")
        }

        if !cacheValid {
            await MainActor.run {
                self.errorMessage = "bf16 本地模型不完整，缺少: \(missingFiles.joined(separator: ", "))。已阻止自动下载。"
                self.isModelLoaded = true
                self.currentModelName = "Missing bf16 Model"
            }
            return
        }

        do {
            let model = try await TTS.loadModel(modelRepo: modelRepo)

            await MainActor.run {
                self.ttsModel = model
                self.isModelLoaded = true
                self.currentModelName = "Qwen3 0.6B Base bf16"
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load bf16 model: \(error.localizedDescription)"
                self.isModelLoaded = true
                self.currentModelName = "Simulated"
            }
        }
#else
        await MainActor.run {
            isModelLoaded = true
            currentModelName = "Simulated"
            availableVoices = ["Voice 1", "Voice 2", "Voice 3"]
        }
#endif
    }

    func generateAudio(
        text: String,
        voice: String? = nil,
        refAudioURL: URL? = nil,
        refText: String? = nil,
        language: String = "zh",
        generationParams: GenerateParameters? = nil
    ) async throws -> URL {
#if canImport(MLXAudioTTS)
        guard let model = ttsModel else {
            throw TTSError.modelNotLoaded
        }
#endif

        await MainActor.run {
            isGenerating = true
            progress = 0
            errorMessage = nil
        }

#if canImport(MLXAudioTTS)
        do {
            // 先获取模型采样率（用于诊断）
            let outputSampleRate = model.sampleRate

            var refAudioArray: MLXArray? = nil
            if let refAudioURL {
                // TODO: refAudio 加载需要确认正确 API
                // AudioUtils.loadAudioArray 可能不存在，暂时跳过
                print("[MLXTTS] refAudio URL provided but loading not yet implemented: \(refAudioURL.path)")
            }

            // Qwen3 Base 模型
            // 注意：generationParameters 使用传入参数或默认值，不依赖 model.defaultGenerationParameters
            let genParams = generationParams ?? GenerateParameters()
            let audioArray = try await model.generate(
                text: text,
                voice: voice,
                refAudio: refAudioArray,
                refText: refText,
                language: language,
                generationParameters: genParams
            )

            await MainActor.run {
                progress = 0.8
            }

            let samples = audioArray.asArray(Float.self)

            // 样本诊断（只打印，不改变音频）
            let sampleCount = samples.count
            var maxAbs: Double = 0.0
            var rms: Double = 0.0

            print("[MLXTTS] samples.count: \(sampleCount)")
            if sampleCount > 0 {
                let absValues = samples.map { Double(abs($0)) }
                maxAbs = absValues.max() ?? 0.0
                let sumOfSquares: Double = absValues.reduce(0.0) { $0 + $1 * $1 }
                rms = sqrt(sumOfSquares / Double(sampleCount))
                print("[MLXTTS] maxAbs: \(maxAbs), rms: \(rms), sampleRate: \(outputSampleRate)")

                // 空样本或全零信号 → 抛出明确错误
                if maxAbs == 0 {
                    throw TTSError.emptyAudioOutput
                }
            } else {
                throw TTSError.emptyAudioOutput
            }

            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "tts_\(UUID().uuidString).wav"
            let url = tempDir.appendingPathComponent(fileName)
            print("[MLXTTS] output path: \(url.path)")

            // 使用官方 AudioUtils，不做强制归一化
            try AudioUtils.writeWavFile(
                samples: samples,
                sampleRate: outputSampleRate,
                fileURL: url
            )

            let diag = AudioDiagInfo(
                fileName: fileName,
                sampleCount: sampleCount,
                maxAbs: maxAbs,
                rms: rms,
                sampleRate: outputSampleRate,
                filePath: url.path,
                durationSec: Double(sampleCount) / Double(outputSampleRate)
            )

            await MainActor.run {
                progress = 1.0
                isGenerating = false
                lastDiag = diag  // 保存诊断信息
            }

            return url
        } catch {
            await MainActor.run {
                isGenerating = false
                errorMessage = error.localizedDescription
            }
            throw TTSError.generationFailed
        }
#else
        await simulateGeneration()
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "tts_\(UUID().uuidString).wav"
        let url = tempDir.appendingPathComponent(fileName)

        let wavData = generatePlaceholderWAV(duration: 1.0)
        try wavData.write(to: url)
        
        let placeholderDiag = AudioDiagInfo(
            fileName: fileName,
            sampleCount: Int(24000 * 1.0),
            maxAbs: 0.0,
            rms: 0.0,
            sampleRate: 24000,
            filePath: url.path,
            durationSec: 1.0
        )
        await MainActor.run {
            lastDiag = placeholderDiag
        }
        return url
#endif
    }

#if canImport(MLXAudioTTS)
    func switchModel(_ modelName: String, modelRepo: String) async {
        await MainActor.run {
            isModelLoaded = false
            errorMessage = nil
        }

        do {
            let model = try await TTS.loadModel(modelRepo: modelRepo)

            await MainActor.run {
                self.ttsModel = model
                self.isModelLoaded = true
                self.currentModelName = modelName
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load model: \(error.localizedDescription)"
            }
        }
    }

    func availableModels() -> [(name: String, repo: String)] {
        // Phase 0 结论：bf16 通过，8bit 输出杂音
        // MVP 阶段仅保留 bf16
        let bf16CacheDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cache/huggingface/hub/mlx-audio/mlx-community_Qwen3-TTS-12Hz-0.6B-Base-bf16")
        let bf16ConfigExists = FileManager.default.fileExists(atPath: bf16CacheDir.appendingPathComponent("config.json").path)

        if bf16ConfigExists {
            return [("Qwen3 0.6B Base bf16", "mlx-community/Qwen3-TTS-12Hz-0.6B-Base-bf16")]
        } else {
            // bf16 不存在时返回空，触发错误提示
            return []
        }
    }

    /// 测试 instruct voice（自由文本，非预设名）
    /// 返回每次生成的诊断信息
    func runInstructVoiceTests(text: String) async throws -> [(instruct: String?, diag: AudioDiagInfo)] {
        var results: [(String?, AudioDiagInfo)] = []

        for instruct in testInstructVoices {
            _ = try await generateAudio(
                text: text,
                voice: instruct,
                language: "zh"
            )
            if let diag = lastDiag {
                results.append((instruct, diag))
                print("[MLXTTS] instruct test: \(instruct ?? "nil") → samples=\(diag.sampleCount), maxAbs=\(diag.maxAbs)")
            }
        }
        return results
    }

    /// 使用参考音频生成
    func testWithRefAudio(text: String, refAudioURL: URL, refText: String?) async throws -> AudioDiagInfo? {
        _ = try await generateAudio(
            text: text,
            voice: nil,
            refAudioURL: refAudioURL,
            refText: refText,
            language: "zh"
        )
        return lastDiag
    }
#endif

    private func simulateGeneration() async {
        for i in 0...10 {
            await MainActor.run {
                progress = Double(i) / 10.0
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
    }

    private func generatePlaceholderWAV(duration: Double) -> Data {
        var audioData = Data()
        
        var chunkID: UInt32 = 0x46464952
        audioData.append(UnsafeBufferPointer(start: &chunkID, count: 1))
        
        var chunkSize: UInt32 = UInt32(duration * 24000 * 2 + 36)
        audioData.append(UnsafeBufferPointer(start: &chunkSize, count: 1))
        
        var format: UInt32 = 0x45564157
        audioData.append(UnsafeBufferPointer(start: &format, count: 1))
        
        var subChunk1Id: UInt32 = 0x20746d66
        audioData.append(UnsafeBufferPointer(start: &subChunk1Id, count: 1))
        
        var subChunk1Size: UInt32 = 16
        audioData.append(UnsafeBufferPointer(start: &subChunk1Size, count: 1))
        
        var audioFormat: UInt16 = 1
        audioData.append(UnsafeBufferPointer(start: &audioFormat, count: 1))
        
        var numChannels: UInt16 = 1
        audioData.append(UnsafeBufferPointer(start: &numChannels, count: 1))
        
        var sampleRate: UInt32 = 24000
        audioData.append(UnsafeBufferPointer(start: &sampleRate, count: 1))
        
        var byteRate: UInt32 = 24000 * 2
        audioData.append(UnsafeBufferPointer(start: &byteRate, count: 1))
        
        var blockAlign: UInt16 = 2
        audioData.append(UnsafeBufferPointer(start: &blockAlign, count: 1))
        
        var bitsPerSample: UInt16 = 16
        audioData.append(UnsafeBufferPointer(start: &bitsPerSample, count: 1))
        
        var subChunk2Id: UInt32 = 0x61746164
        audioData.append(UnsafeBufferPointer(start: &subChunk2Id, count: 1))
        
        var subChunk2Size: UInt32 = UInt32(duration * 24000 * 2)
        audioData.append(UnsafeBufferPointer(start: &subChunk2Size, count: 1))
        
        for _ in 0..<Int(duration * 24000) {
            var sample: Int16 = 0
            audioData.append(UnsafeBufferPointer(start: &sample, count: 1))
        }
        
        return audioData
    }

    // MARK: - 归一化和手写 WAV 已移除
    // 如需恢复参考 git 历史 commit d85dfdd

}

enum TTSError: Error, LocalizedError {
    case modelNotLoaded
    case generationFailed
    case audioSaveFailed
    case emptyAudioOutput

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded: return "TTS model not loaded"
        case .generationFailed: return "Audio generation failed"
        case .audioSaveFailed: return "Failed to save audio file"
        case .emptyAudioOutput: return "Model returned empty or silent audio"
        }
    }
}

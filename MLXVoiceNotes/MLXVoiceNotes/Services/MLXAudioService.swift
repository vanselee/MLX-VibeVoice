import Foundation
import AVFoundation

#if canImport(MLXAudioTTS)
import MLXAudioTTS
import MLXAudioCore
import MLXLMCommon
#endif

class MLXAudioService: ObservableObject {
    @Published var isModelLoaded = false
    @Published var isGenerating = false
    @Published var progress: Double = 0
    @Published var errorMessage: String?
    @Published var availableVoices: [String] = []
    @Published var currentModelName: String = "Simulated"

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
        // 本地缓存完整性检查，阻止自动下载
        let modelRepo = "mlx-community/Qwen3-TTS-12Hz-0.6B-Base-8bit"
        let cacheDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cache/huggingface/hub/mlx-audio/mlx-community_Qwen3-TTS-12Hz-0.6B-Base-8bit")

        let requiredFiles = [
            "config.json",
            "model.safetensors",
            "tokenizer_config.json",
            "generation_config.json",
            "vocab.json",
            "merges.txt"
        ]

        var cacheValid = true
        for file in requiredFiles {
            let filePath = cacheDir.appendingPathComponent(file)
            if !FileManager.default.fileExists(atPath: filePath.path) {
                cacheValid = false
                break
            }
            if let attrs = try? FileManager.default.attributesOfItem(atPath: filePath.path),
               let size = attrs[.size] as? Int, size == 0 {
                cacheValid = false
                break
            }
        }

        // 检查 speech_tokenizer/config.json
        let speechTokenizerConfig = cacheDir.appendingPathComponent("speech_tokenizer/config.json")
        if !FileManager.default.fileExists(atPath: speechTokenizerConfig.path) {
            cacheValid = false
        }

        if !cacheValid {
            await MainActor.run {
                self.errorMessage = "本地 Qwen3 模型缓存不完整，已阻止自动下载"
                self.isModelLoaded = true
                self.currentModelName = "Missing Local Qwen3 Cache"
            }
            return
        }

        do {
            let model = try await TTS.loadModel(modelRepo: modelRepo)

            await MainActor.run {
                self.ttsModel = model
                self.isModelLoaded = true
                self.currentModelName = "Qwen3 0.6B Base 8bit"
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load model: \(error.localizedDescription)"
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

    func generateAudio(text: String, voice: String? = nil) async throws -> URL {
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
            // Qwen3 Base 模型：voice 传 nil，language 传 "zh"
            let audioArray = try await model.generate(
                text: text,
                voice: nil,
                refAudio: nil,
                refText: nil,
                language: "zh",
                generationParameters: GenerateParameters()
            )

            await MainActor.run {
                progress = 0.8
            }

            let samples = audioArray.asArray(Float.self)

            // 使用模型真实采样率
            let outputSampleRate = model.sampleRate

            // 样本诊断（只打印，不改变音频）
            let sampleCount = samples.count
            print("[MLXTTS] samples.count: \(sampleCount)")
            if sampleCount > 0 {
                let absValues = samples.map { abs($0) }
                let maxAbs = absValues.max() ?? 0.0
                let sumOfSquares: Double = absValues.reduce(0.0) { $0 + Double($1) * Double($1) }
                let rms = sqrt(sumOfSquares / Double(sampleCount))
                print("[MLXTTS] maxAbs: \(maxAbs), rms: \(rms), sampleRate: \(outputSampleRate)")

                // 空样本或全零信号 → 抛出明确错误
                if sampleCount == 0 {
                    throw TTSError.emptyAudioOutput
                }
                if maxAbs == 0 {
                    throw TTSError.emptyAudioOutput
                }
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

            await MainActor.run {
                progress = 1.0
                isGenerating = false
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
        // 现阶段只测试 Qwen3-TTS-12Hz-0.6B-Base-8bit
        // bf16 版本未接入本地 cache 映射，暂不测试
        return [
            ("Qwen3 0.6B Base 8bit", "mlx-community/Qwen3-TTS-12Hz-0.6B-Base-8bit")
        ]
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

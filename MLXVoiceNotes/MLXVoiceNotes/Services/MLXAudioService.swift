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
    private let sampleRate: Int = 24000
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
        do {
            let model = try await TTS.loadModel(modelRepo: "mlx-community/Soprano-80M-bf16")

            await MainActor.run {
                self.ttsModel = model
                self.isModelLoaded = true
                self.currentModelName = "Soprano-80M"
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
            let audioArray = try await model.generate(
                text: text,
                voice: voice,
                refAudio: nil,
                refText: nil,
                language: "auto",
                generationParameters: GenerateParameters()
            )

            await MainActor.run {
                progress = 0.8
            }

            let samples = audioArray.asArray(Float.self)

            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "tts_\(UUID().uuidString).wav"
            let url = tempDir.appendingPathComponent(fileName)

            // 将 [Float] 转换为 WAV Data 并保存
            let wavData = createWAVData(from: samples, sampleRate: sampleRate)
            try wavData.write(to: url)

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
        return [
            ("Soprano-80M", "mlx-community/Soprano-80M-bf16"),
            ("Pocket TTS", "mlx-community/pocket-tts"),
            ("Kokoro", "mlx-community/Kokoro-77M"),
            ("VyvoTTS", "mlx-community/VyvoTTS-EN-Beta-4bit")
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

    private func createWAVData(from samples: [Float], sampleRate: Int) -> Data {
        var audioData = Data()
        
        let numSamples = samples.count
        let dataSize = numSamples * 2  // 16-bit samples
        
        // RIFF header
        var chunkID: UInt32 = 0x46464952  // "RIFF"
        audioData.append(UnsafeBufferPointer(start: &chunkID, count: 1))
        
        var chunkSize: UInt32 = UInt32(36 + dataSize)
        audioData.append(UnsafeBufferPointer(start: &chunkSize, count: 1))
        
        var format: UInt32 = 0x45564157  // "WAVE"
        audioData.append(UnsafeBufferPointer(start: &format, count: 1))
        
        // fmt subchunk
        var subChunk1Id: UInt32 = 0x20746d66  // "fmt "
        audioData.append(UnsafeBufferPointer(start: &subChunk1Id, count: 1))
        
        var subChunk1Size: UInt32 = 16
        audioData.append(UnsafeBufferPointer(start: &subChunk1Size, count: 1))
        
        var audioFormat: UInt16 = 1  // PCM
        audioData.append(UnsafeBufferPointer(start: &audioFormat, count: 1))
        
        var numChannels: UInt16 = 1
        audioData.append(UnsafeBufferPointer(start: &numChannels, count: 1))
        
        var sampleRateValue: UInt32 = UInt32(sampleRate)
        audioData.append(UnsafeBufferPointer(start: &sampleRateValue, count: 1))
        
        var byteRate: UInt32 = UInt32(sampleRate * 2)
        audioData.append(UnsafeBufferPointer(start: &byteRate, count: 1))
        
        var blockAlign: UInt16 = 2
        audioData.append(UnsafeBufferPointer(start: &blockAlign, count: 1))
        
        var bitsPerSample: UInt16 = 16
        audioData.append(UnsafeBufferPointer(start: &bitsPerSample, count: 1))
        
        // data subchunk
        var subChunk2Id: UInt32 = 0x61746164  // "data"
        audioData.append(UnsafeBufferPointer(start: &subChunk2Id, count: 1))
        
        var subChunk2Size: UInt32 = UInt32(dataSize)
        audioData.append(UnsafeBufferPointer(start: &subChunk2Size, count: 1))
        
        // Convert Float samples to Int16
        for sample in samples {
            // Clamp to [-1.0, 1.0] and scale to Int16 range
            let clamped = max(-1.0, min(1.0, sample))
            var intSample: Int16 = Int16(clamped * 32767.0)
            audioData.append(UnsafeBufferPointer(start: &intSample, count: 1))
        }
        
        return audioData
    }
}

enum TTSError: Error, LocalizedError {
    case modelNotLoaded
    case generationFailed
    case audioSaveFailed

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded: return "TTS model not loaded"
        case .generationFailed: return "Audio generation failed"
        case .audioSaveFailed: return "Failed to save audio file"
        }
    }
}

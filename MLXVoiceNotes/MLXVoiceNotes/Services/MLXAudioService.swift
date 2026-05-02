import Foundation
import AVFoundation
import MLXAudioTTS
import MLXAudioCore

class MLXAudioService: ObservableObject {
    @Published var isModelLoaded = false
    @Published var isGenerating = false
    @Published var progress: Double = 0
    @Published var errorMessage: String?
    @Published var availableVoices: [String] = []
    @Published var currentModelName: String = "Soprano"

    private var ttsModel: SpeechGenerationModel?
    private let sampleRate: Int = 24000

    init() {
        loadModel()
    }

    func loadModel() async {
        await MainActor.run {
            isModelLoaded = false
            errorMessage = nil
        }

        do {
            // 加载 Soprano 模型（80M 参数，适合快速测试）
            let model = try await TTS.loadModel(modelRepo: "mlx-community/Soprano-80M-bf16")

            await MainActor.run {
                self.ttsModel = model
                self.isModelLoaded = true
                self.currentModelName = "Soprano-80M"
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load model: \(error.localizedDescription)"
            }
        }
    }

    func generateAudio(text: String, voice: String? = nil) async throws -> URL {
        guard let model = ttsModel else {
            throw TTSError.modelNotLoaded
        }

        await MainActor.run {
            isGenerating = true
            progress = 0
            errorMessage = nil
        }

        do {
            let audio = try await model.generate(
                text: text,
                voice: voice
            )

            await MainActor.run {
                progress = 0.8
            }

            // 保存为 WAV 文件
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "tts_\(UUID().uuidString).wav"
            let url = tempDir.appendingPathComponent(fileName)

            try saveAudioArray(audio, sampleRate: Double(sampleRate), to: url)

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
    }

    func generateAudioWithProgress(text: String, voice: String? = nil) -> AsyncThrowingStream<Double, Error> {
        AsyncThrowingStream { continuation in
            Task {
                guard let model = ttsModel else {
                    continuation.finish(throwing: TTSError.modelNotLoaded)
                    return
                }

                await MainActor.run {
                    isGenerating = true
                    errorMessage = nil
                }

                do {
                    continuation.yield(0.1)
                    
                    let audio = try await model.generate(
                        text: text,
                        voice: voice
                    )

                    continuation.yield(0.8)

                    // 保存为 WAV 文件
                    let tempDir = FileManager.default.temporaryDirectory
                    let fileName = "tts_\(UUID().uuidString).wav"
                    let url = tempDir.appendingPathComponent(fileName)

                    try saveAudioArray(audio, sampleRate: Double(sampleRate), to: url)

                    continuation.yield(1.0)

                    await MainActor.run {
                        isGenerating = false
                    }

                    continuation.finish()
                } catch {
                    await MainActor.run {
                        isGenerating = false
                        errorMessage = error.localizedDescription
                    }
                    continuation.finish(throwing: TTSError.generationFailed)
                }
            }
        }
    }

    func setVoice(_ voiceName: String) {
        // voiceName 设置当前音色
    }

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
}

enum TTSError: Error, LocalizedError {
    case modelNotLoaded
    case generationFailed
    case audioSaveFailed

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "TTS model not loaded"
        case .generationFailed:
            return "Audio generation failed"
        case .audioSaveFailed:
            return "Failed to save audio file"
        }
    }
}

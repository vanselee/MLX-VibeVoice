import Foundation

#if canImport(MLXLMCommon)
import MLXLMCommon
#endif

#if canImport(MLXLMCommon)
enum ModelGenerationProfile {
    static func parameters(for repo: String, fallback: GenerateParameters) -> GenerateParameters {
        switch repo {
        case "mlx-community/Qwen3-TTS-12Hz-1.7B-CustomVoice-bf16":
            return GenerateParameters(
                maxTokens: 8192,
                temperature: 0.9,
                topP: 1.0,
                repetitionPenalty: 1.05,
                repetitionContextSize: 20
            )

        case "mlx-community/Qwen3-TTS-12Hz-1.7B-CustomVoice-8bit":
            return GenerateParameters(
                maxTokens: 8192,
                temperature: 0.75,
                topP: 0.9,
                repetitionPenalty: 1.1,
                repetitionContextSize: 20
            )

        case "mlx-community/Qwen3-TTS-12Hz-1.7B-CustomVoice-4bit":
            return GenerateParameters(
                maxTokens: 8192,
                temperature: 0.65,
                topP: 0.85,
                repetitionPenalty: 1.15,
                repetitionContextSize: 20
            )

        case "mlx-community/Qwen3-TTS-12Hz-0.6B-CustomVoice-8bit":
            return GenerateParameters(
                maxTokens: 4096,
                temperature: 0.7,
                topP: 0.9,
                repetitionPenalty: 1.1,
                repetitionContextSize: 20
            )

        case "mlx-community/Qwen3-TTS-12Hz-0.6B-Base-bf16":
            return GenerateParameters(
                maxTokens: 4096,
                temperature: 0.6,
                topP: 0.8,
                repetitionPenalty: 1.3,
                repetitionContextSize: 20
            )

        default:
            return fallback
        }
    }
}
#endif

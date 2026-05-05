import Foundation

/// 音频淡入淡出处理器
enum AudioFadeProcessor {
    /// 对音频样本应用淡入淡出
    /// - Parameters:
    ///   - samples: 原始音频样本
    ///   - fadeInMs: 淡入毫秒数
    ///   - fadeOutMs: 淡出毫秒数
    ///   - sampleRate: 采样率
    /// - Returns: 处理后的音频样本
    static func applyFade(
        samples: [Float],
        fadeInMs: Int,
        fadeOutMs: Int,
        sampleRate: Double
    ) -> [Float] {
        guard !samples.isEmpty else { return samples }

        let sampleCount = samples.count
        let maxHalfSize = sampleCount / 2  // 淡入淡出样本数限制在音频长度的一半以内

        var result = samples

        // 计算淡入样本数（不超过一半）
        let fadeInSamples = min(Int(Double(fadeInMs) * sampleRate / 1000.0), maxHalfSize)
        // 计算淡出样本数（不超过一半）
        let fadeOutSamples = min(Int(Double(fadeOutMs) * sampleRate / 1000.0), maxHalfSize)

        // 淡入：从 0 渐变到 1
        if fadeInSamples > 0 {
            for i in 0..<fadeInSamples {
                let gain = Float(i) / Float(fadeInSamples)
                result[i] = samples[i] * gain
            }
        }

        // 淡出：从 1 渐变到 0
        if fadeOutSamples > 0 {
            let fadeOutStart = sampleCount - fadeOutSamples
            for i in 0..<fadeOutSamples {
                let index = fadeOutStart + i
                let gain = Float(fadeOutSamples - i) / Float(fadeOutSamples)
                result[index] = samples[index] * gain
            }
        }

        return result
    }

    /// 生成指定毫秒数的静音样本
    /// - Parameters:
    ///   - ms: 毫秒数
    ///   - sampleRate: 采样率
    /// - Returns: 静音样本数组（全 0）
    static func generateSilence(ms: Int, sampleRate: Double) -> [Float] {
        let sampleCount = Int(Double(ms) * sampleRate / 1000.0)
        return [Float](repeating: 0.0, count: sampleCount)
    }
}
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
    let elapsedSec: Double
    let realtimeFactor: Double
    // 分阶段耗时
    let referenceAudioLoadElapsedSec: Double
    let modelGenerateElapsedSec: Double
    let wavWriteElapsedSec: Double
    let totalElapsedSec: Double
}

/// 参考音频缓存条目
private struct CachedRefAudio {
    let mlxArray: MLXArray
    let sampleCount: Int
    let createdAt: Date
    let fileModificationDate: Date?
    let fileSize: Int64
}

// MARK: - Phase 2B: refAudio/refText Stability Test
let phase2RefAudioPath = "/Users/apple/Desktop/李不二聊电商/4月12日音频母带/4月22日声音母带.mp3"
let phase2RefText = "你永远都搞不清楚这些平台它到底要什么，不要什么，有时候一条视频吧，花几个小时你把它做出来了，发到了a平台呢，正常通过，发到b平台呢，直接限流，有的还给你封号呢"
let phase2TargetText = "你好，这是 MLX Voice Notes 的参考音色稳定性测试。如果三次声音接近一致，说明参考音色可以用于角色绑定。"

class MLXAudioService: ObservableObject {
    static let shared = MLXAudioService()

    @Published var isModelLoaded = false
    @Published var isGenerating = false
    @Published var progress: Double = 0
    @Published var errorMessage: String?
    @Published var availableVoices: [String] = []
    @Published var currentModelName: String = "Simulated"
    @Published var lastDiag: AudioDiagInfo?  // 最近一次生成的诊断信息

    /// 当前已加载模型的 repo（公开只读，供 UI 判断当前选中模型）
    public var currentLoadedRepo: String? { loadedModelRepo }

    /// 当前选择的模型 repo（UserDefaults 持久化）
    @Published var selectedModelRepo: String {
        didSet {
            UserDefaults.standard.set(selectedModelRepo, forKey: "selectedTTSModelRepo")
        }
    }

    /// 当前已加载的模型 repo（用于判断是否需要重新加载）
    private var loadedModelRepo: String?

#if canImport(MLXAudioTTS)
    private var ttsModel: (any SpeechGenerationModel)?
#endif

    /// 防止并发加载模型
    private var loadModelTask: Task<Void, Never>?

    /// 参考音频 MLXArray 缓存（key: URL.path），最多 8 条，超出时移除最旧
    private var refAudioCache: [String: CachedRefAudio] = [:]
    private let maxRefAudioCacheCount = 8

    /// 清理过期缓存条目（最多缓存 maxRefAudioCacheCount 条，超出时移除最旧）
    private func pruneRefAudioCache() {
        guard refAudioCache.count >= maxRefAudioCacheCount else { return }
        let oldest = refAudioCache.min { $0.value.createdAt < $1.value.createdAt }
        if let key = oldest?.key {
            refAudioCache.removeValue(forKey: key)
        }
    }

    private func fileModificationDate(for url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date)
    }

    private func fileSize(for url: URL) -> Int64 {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: "selectedTTSModelRepo")
        ?? "mlx-community/Qwen3-TTS-12Hz-0.6B-Base-bf16"
        selectedModelRepo = saved
    }

    /// 幂等加载模型：已加载则直接返回，正在加载则等待完成，否则启动加载
    func ensureModelLoaded() async {
        // 已加载 → 直接返回
#if canImport(MLXAudioTTS)
        if ttsModel != nil && isModelLoaded { return }
#else
        if isModelLoaded { return }
#endif

        // 正在加载 → 等待已有 Task 完成
        if let existing = loadModelTask {
            await existing.value
            return
        }

        // 启动新加载
        let task = Task {
            await loadModel()
        }
        loadModelTask = task
        await task.value
        loadModelTask = nil
    }

    func loadModel() async {
#if canImport(MLXAudioTTS)
        // 防重复加载守卫（同一 repo 不重复加载）
        if ttsModel != nil && isModelLoaded && loadedModelRepo == selectedModelRepo { return }
#endif

        await MainActor.run {
            isModelLoaded = false
            errorMessage = nil
        }

#if canImport(MLXAudioTTS)
        let modelRepo = selectedModelRepo

        // 验证模型是否已安装且完整
        guard let catalogModel = ModelCatalog.model(for: modelRepo) else {
            await MainActor.run {
                self.errorMessage = "当前模型不在支持列表中，请到资源中心切换模型"
                self.isModelLoaded = true
                self.currentModelName = "Unknown Model"
            }
            return
        }

        let status = ModelDownloadManager.shared.checkStatus(for: catalogModel)
        switch status {
        case .notDownloaded:
            await MainActor.run {
                self.errorMessage = "当前模型未安装，请先到资源中心下载或切换模型"
                self.isModelLoaded = true
                self.currentModelName = "Model Not Installed"
            }
            return
        case .incomplete(let missingFiles):
            await MainActor.run {
                self.errorMessage = "当前模型文件不完整，缺少: \(missingFiles.prefix(3).joined(separator: ", "))。请到资源中心下载或切换模型"
                self.isModelLoaded = true
                self.currentModelName = "Model Incomplete"
            }
            return
        case .installing, .failed:
            await MainActor.run {
                self.errorMessage = "当前模型状态异常，请到资源中心检查"
                self.isModelLoaded = true
                self.currentModelName = "Model Unavailable"
            }
            return
        case .installed:
            break // 继续加载
        }

        do {
            let model = try await TTS.loadModel(modelRepo: modelRepo)

            await MainActor.run {
                self.ttsModel = model
                self.isModelLoaded = true
                self.loadedModelRepo = modelRepo
                self.currentModelName = catalogModel.displayName + " (\(catalogModel.precision))"
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

    func generateAudio(
        text: String,
        voice: String? = nil,
        refAudioURL: URL? = nil,
        refText: String? = nil,
        language: String = "auto",
        generationParams: GenerateParameters? = nil
    ) async throws -> URL {
        // 检查当前选择的模型是否已安装且完整
        let selectedRepo = selectedModelRepo
        if let catalogModel = ModelCatalog.model(for: selectedRepo) {
            let status = ModelDownloadManager.shared.checkStatus(for: catalogModel)
            if !status.isInstalled {
                await MainActor.run {
                    self.errorMessage = "当前模型未安装，请先到资源中心下载或切换模型"
                }
                throw TTSError.modelNotInstalled
            }
        } else {
            await MainActor.run {
                self.errorMessage = "当前模型不在支持列表中，请到资源中心切换模型"
            }
            throw TTSError.modelNotInstalled
        }

        // 确保模型已加载（幂等，不重复加载）
        await ensureModelLoaded()

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
            // 分阶段计时：参考音频加载
            let refAudioLoadStart = Date()
            if let refAudioURL {
                if let cached = refAudioCache[refAudioURL.path],
                   cached.fileModificationDate == fileModificationDate(for: refAudioURL),
                   cached.fileSize == fileSize(for: refAudioURL) {
                    // 命中缓存，直接复用 MLXArray
                    refAudioArray = cached.mlxArray
                    print("[MLXTTS] refAudio cache hit: \(refAudioURL.path)")
                } else {
                    // 未命中，加载并缓存
                    let (sampleCount, loadedArray) = try loadAudioArray(from: refAudioURL, sampleRate: outputSampleRate)
                    refAudioArray = loadedArray
                    print("[MLXTTS] refAudio loaded from: \(refAudioURL.path)")
                    // 写入缓存
                    pruneRefAudioCache()
                    refAudioCache[refAudioURL.path] = CachedRefAudio(
                        mlxArray: loadedArray,
                        sampleCount: sampleCount,
                        createdAt: Date(),
                        fileModificationDate: fileModificationDate(for: refAudioURL),
                        fileSize: fileSize(for: refAudioURL)
                    )
                }
            }
            let refAudioLoadElapsed = Date().timeIntervalSince(refAudioLoadStart)

            // 分阶段计时：总耗时起点（必须在所有操作之前记录）
            let totalStart = Date()

            let genParams = generationParams ?? model.defaultGenerationParameters

            // 分阶段计时：模型推理
            let modelGenStart = Date()

            let audioArray = try await model.generate(
                text: text,
                voice: voice,
                refAudio: refAudioArray,
                refText: refText,
                language: language,
                generationParameters: genParams
            )
            let modelGenElapsed = Date().timeIntervalSince(modelGenStart)

            // 样本诊断（只打印，不改变音频）
            let samples = audioArray.asArray(Float.self)
            let sampleCount = samples.count
            var maxAbs: Double = 0.0
            var rms: Double = 0.0

            // 样本诊断（只打印，不改变音频）
            // 1. 空样本 → 抛出明确错误
            if sampleCount == 0 {
                throw TTSError.emptyAudioOutput
            }

            let absValues = samples.map { Double(abs($0)) }
            maxAbs = absValues.max() ?? 0.0
            let sumOfSquares: Double = absValues.reduce(0.0) { $0 + $1 * $1 }
            rms = sqrt(sumOfSquares / Double(sampleCount))
            print("[MLXTTS] samples.count: \(sampleCount), maxAbs: \(maxAbs), rms: \(rms), sampleRate: \(outputSampleRate)")

            // 2. 全零信号 → emptyAudioOutput
            if maxAbs == 0 {
                throw TTSError.emptyAudioOutput
            }

            // 3. 近静音检测（maxAbs < 0.05 或 rms < 0.01）
            if maxAbs < 0.05 || rms < 0.01 {
                throw TTSError.nearSilentAudio(maxAbs: maxAbs, rms: rms)
            }

            // 4. 开头长静音检测（阈值 0.003，超过 1.2 秒则失败）
            let leadingSilenceThreshold: Float = 0.003
            var leadingSilenceFrames = 0
            for sample in samples {
                if abs(sample) < leadingSilenceThreshold {
                    leadingSilenceFrames += 1
                } else {
                    break
                }
            }
            let leadingSilenceSec = Double(leadingSilenceFrames) / Double(outputSampleRate)
            if leadingSilenceSec > 1.2 {
                throw TTSError.excessiveLeadingSilence(seconds: leadingSilenceSec)
            }

            // 5. 中间长静音检测（阈值 0.003，非首尾区域连续静音超过 2.0 秒则失败，暂不裁剪）
            let internalSilenceThreshold: Float = 0.003
            var currentSilenceFrames = 0
            var maxInternalSilenceFrames = 0
            for (i, sample) in samples.enumerated() {
                if abs(sample) < internalSilenceThreshold {
                    currentSilenceFrames += 1
                } else {
                    // 只在非首尾区域统计最大静音区间
                    let silenceStart = i - currentSilenceFrames
                    let silenceEnd = i - 1
                    let isLeading = silenceEnd < leadingSilenceFrames
                    let isTrailing = silenceEnd >= sampleCount - Int(2.0 * Double(outputSampleRate))
                    if !isLeading && !isTrailing {
                        maxInternalSilenceFrames = max(maxInternalSilenceFrames, currentSilenceFrames)
                    }
                    currentSilenceFrames = 0
                }
            }
            let maxInternalSilenceSec = Double(maxInternalSilenceFrames) / Double(outputSampleRate)
            if maxInternalSilenceSec > 2.0 {
                throw TTSError.excessiveInternalSilence(seconds: maxInternalSilenceSec)
            }

            // 在所有操作完成后计算完整耗时
            let durationSec = Double(sampleCount) / Double(outputSampleRate)

            await MainActor.run {
                progress = 0.8
            }

            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "tts_\(UUID().uuidString).wav"
            let url = tempDir.appendingPathComponent(fileName)
            print("[MLXTTS] output path: \(url.path)")

            // 分阶段计时：WAV 写入
            let wavWriteStart = Date()
            try AudioUtils.writeWavFile(
                samples: samples,
                sampleRate: outputSampleRate,
                fileURL: url
            )
            let wavWriteElapsed = Date().timeIntervalSince(wavWriteStart)

            // 完整耗时（包含参考音频加载 + 推理 + WAV 写入）
            let elapsedSec = Date().timeIntervalSince(totalStart)
            let totalElapsedSec = elapsedSec
            let realtimeFactor = durationSec > 0 ? totalElapsedSec / durationSec : 0

            let diag = AudioDiagInfo(
                fileName: fileName,
                sampleCount: sampleCount,
                maxAbs: maxAbs,
                rms: rms,
                sampleRate: outputSampleRate,
                filePath: url.path,
                durationSec: durationSec,
                elapsedSec: elapsedSec,
                realtimeFactor: realtimeFactor,
                referenceAudioLoadElapsedSec: refAudioLoadElapsed,
                modelGenerateElapsedSec: modelGenElapsed,
                wavWriteElapsedSec: wavWriteElapsed,
                totalElapsedSec: totalElapsedSec
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
            durationSec: 1.0,
            elapsedSec: 0,
            realtimeFactor: 0,
            referenceAudioLoadElapsedSec: 0,
            modelGenerateElapsedSec: 0,
            wavWriteElapsedSec: 0,
            totalElapsedSec: 0
        )
        await MainActor.run {
            lastDiag = placeholderDiag
        }
        return url
#endif
    }

#if canImport(MLXAudioTTS)
    /// 切换到指定模型
    /// - 清空当前已加载模型
    /// - 清空参考音频缓存
    /// - 下一次 generate 时自动加载新模型
    func switchToModel(repo: String) async {
        // 同一 repo 不需要切换
        guard repo != loadedModelRepo else { return }

        await MainActor.run {
            // 清空已加载模型
            self.ttsModel = nil
            self.isModelLoaded = false
            self.loadedModelRepo = nil
            self.currentModelName = "Switching..."
            self.errorMessage = nil

            // 清空参考音频缓存
            self.refAudioCache.removeAll()

            // 更新选择
            self.selectedModelRepo = repo
        }

        // 加载新模型
        await loadModel()
    }

    /// Phase 2B refAudio 稳定性测试：同一目标文本 × 3 次生成
    /// 使用参考音频和参考文本，验证音色克隆稳定性
    func runRefAudioStabilityTests() async throws -> [(run: Int, diag: AudioDiagInfo)] {
        var results: [(Int, AudioDiagInfo)] = []

        guard let refAudioURL = URL(string: phase2RefAudioPath) else {
            throw TTSError.invalidRefAudioPath
        }

        // 验证参考音频文件存在
        guard FileManager.default.fileExists(atPath: refAudioURL.path) else {
            throw TTSError.refAudioFileNotFound
        }

        // 准备输出目录
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let phase2Dir = appSupport
            .appendingPathComponent("MLX Voice Notes")
            .appendingPathComponent("GeneratedAudio")
            .appendingPathComponent("Phase2RefAudio")
        try FileManager.default.createDirectory(at: phase2Dir, withIntermediateDirectories: true)

        guard let model = ttsModel else {
            throw TTSError.modelNotLoaded
        }

        for run in 1...3 {
            let fileName = "refAudio_run\(run).wav"
            let destURL = phase2Dir.appendingPathComponent(fileName)

            // 生成音频
            let genParams = model.defaultGenerationParameters
            let tempURL = try await generateAudio(
                text: phase2TargetText,
                voice: nil,
                refAudioURL: refAudioURL,
                refText: phase2RefText,
                language: "auto",
                generationParams: genParams
            )

            // 移动到 Phase2 输出目录
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.moveItem(at: tempURL, to: destURL)

            // 更新诊断信息
            if var diag = lastDiag {
                diag = AudioDiagInfo(
                    fileName: fileName,
                    sampleCount: diag.sampleCount,
                    maxAbs: diag.maxAbs,
                    rms: diag.rms,
                    sampleRate: diag.sampleRate,
                    filePath: destURL.path,
                    durationSec: diag.durationSec,
                    elapsedSec: diag.elapsedSec,
                    realtimeFactor: diag.realtimeFactor,
                    referenceAudioLoadElapsedSec: diag.referenceAudioLoadElapsedSec,
                    modelGenerateElapsedSec: diag.modelGenerateElapsedSec,
                    wavWriteElapsedSec: diag.wavWriteElapsedSec,
                    totalElapsedSec: diag.totalElapsedSec
                )
                results.append((run, diag))
                print("[Phase2B] run#\(run): maxAbs=\(String(format: "%.6f", diag.maxAbs)), rms=\(String(format: "%.6f", diag.rms)), dur=\(String(format: "%.2f", diag.durationSec))s")
                print("[Phase2B] saved: \(destURL.path)")
            }
        }

        return results
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
    case modelNotInstalled
    case generationFailed
    case audioSaveFailed
    case emptyAudioOutput
    case nearSilentAudio(maxAbs: Double, rms: Double)
    case excessiveLeadingSilence(seconds: Double)
    case excessiveInternalSilence(seconds: Double)
    case invalidRefAudioPath
    case refAudioFileNotFound
    case refAudioLoadFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded: return "TTS model not loaded"
        case .modelNotInstalled: return "当前模型未安装，请先到资源中心下载或切换模型"
        case .generationFailed: return "Audio generation failed"
        case .audioSaveFailed: return "Failed to save audio file"
        case .emptyAudioOutput: return "Model returned empty audio (sampleCount == 0)"
        case .nearSilentAudio(let maxAbs, let rms): return "Generated audio is nearly silent (maxAbs=\(String(format: "%.4f", maxAbs)), rms=\(String(format: "%.4f", rms)), expected maxAbs≥0.05 and rms≥0.01)"
        case .excessiveLeadingSilence(let seconds): return "Generated audio has excessive leading silence (\(String(format: "%.2f", seconds))s > 1.2s threshold)"
        case .excessiveInternalSilence(let seconds): return "Generated audio contains internal silence block (\(String(format: "%.2f", seconds))s > 2.0s threshold)"
        case .invalidRefAudioPath: return "Invalid refAudio path URL"
        case .refAudioFileNotFound: return "Reference audio file not found"
        case .refAudioLoadFailed(let msg): return "Failed to load reference audio: \(msg)"
        }
    }
}

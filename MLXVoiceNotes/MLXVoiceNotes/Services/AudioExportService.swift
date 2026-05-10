import Foundation
import AVFoundation

struct AudioExportResult {
    let fileURL: URL
}

/// Phase 0.5: 真实音频导出服务
/// - 合并所有段落的 WAV 文件（读取 PCM samples，合并后写新 WAV）
/// - 不简单拼接 WAV 字节（WAV 有 header）
enum AudioExportService {
    /// 导出目录（用户偏好设置）
    static var exportDirectory: URL {
        if let customPath = UserDefaults.standard.string(forKey: "defaultExportDirectory"), !customPath.isEmpty {
            return URL(fileURLWithPath: customPath)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Downloads", isDirectory: true)
            .appendingPathComponent("MLX VibeVoice Exports", isDirectory: true)
    }

    /// 默认导出目录
    static let defaultExportDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Downloads", isDirectory: true)
        .appendingPathComponent("MLX VibeVoice Exports", isDirectory: true)

    /// 导出真实 WAV（合并所有段落音频）
    /// - Parameters:
    ///   - script: 文案
    ///   - fileName: 输出文件名（不含扩展名）
    /// - Returns: 导出结果
    /// - Throws: 文件操作错误
    static func exportRealWAV(for script: Script, fileName: String) throws -> AudioExportResult {
        // 确保导出目录存在
        try FileManager.default.createDirectory(at: exportDirectory, withIntermediateDirectories: true)

        // 导出前必须确保整篇文案所有段落都已成功生成，避免漏导成不完整 WAV。
        let orderedSegments = script.segments.sorted { $0.order < $1.order }

        guard !orderedSegments.isEmpty else {
            throw AudioExportError.noCompletedSegments
        }

        let failedOrders = orderedSegments
            .filter { $0.status == .failed }
            .map(\.order)

        if !failedOrders.isEmpty {
            throw AudioExportError.failedSegments(failedOrders)
        }

        let incompleteOrders = orderedSegments
            .filter { $0.status != .completed }
            .map(\.order)

        if !incompleteOrders.isEmpty {
            throw AudioExportError.incompleteSegments(incompleteOrders)
        }

        let completedSegments = orderedSegments

        guard !completedSegments.isEmpty else {
            throw AudioExportError.noCompletedSegments
        }

        // 严格检查：每个 completed 段落必须有音频文件
        for segment in completedSegments {
            // segment.order 已经是 1-based，直接使用
            let segmentIndex = segment.order
            guard let relativePath = segment.generatedAudioPath else {
                throw AudioExportError.missingGeneratedAudio(segmentIndex: segmentIndex)
            }
            let audioURL = AudioStorageService.absoluteURL(from: relativePath)
            guard FileManager.default.fileExists(atPath: audioURL.path) else {
                throw AudioExportError.missingAudioFile(segmentIndex: segmentIndex)
            }
        }

        // 合并所有段落的 PCM samples（含停顿和淡入淡出）
        var allSamples: [Float] = []
        var sampleRate: Double = 24000  // 默认 24kHz
        
        // 淡入淡出配置
        let fullStartFadeMs = 60
        let fullEndFadeMs = 80
        let segmentFadeMs = 20
        
        for (index, segment) in completedSegments.enumerated() {
            let relativePath = segment.generatedAudioPath!
            let audioURL = AudioStorageService.absoluteURL(from: relativePath)
            let (samples, sr) = try readPCMSamples(from: audioURL)
            sampleRate = sr
            
            // 1. 插入停顿（非第一段）
            if index > 0 {
                let prevSegment = completedSegments[index - 1]
                if let pauseMs = PauseCalculator.calculatePause(prevSegment: prevSegment, currentSegment: segment) {
                    let silence = AudioFadeProcessor.generateSilence(ms: pauseMs, sampleRate: sampleRate)
                    allSamples.append(contentsOf: silence)
                }
            }
            
            // 2. 应用淡入淡出
            let isFirst = index == 0
            let isLast = index == completedSegments.count - 1
            
            let fadeInMs: Int = isFirst ? fullStartFadeMs : segmentFadeMs
            let fadeOutMs: Int = isLast ? fullEndFadeMs : segmentFadeMs
            
            let fadedSamples = AudioFadeProcessor.applyFade(
                samples: samples,
                fadeInMs: fadeInMs,
                fadeOutMs: fadeOutMs,
                sampleRate: sampleRate
            )
            allSamples.append(contentsOf: fadedSamples)
        }

        guard !allSamples.isEmpty else {
            throw AudioExportError.emptyAudioData
        }

        // 写入合并后的 WAV 文件
        let outputURL = exportDirectory.appendingPathComponent("\(fileName).wav")
        try writeWAVFile(samples: allSamples, sampleRate: Int(sampleRate), to: outputURL)

        return AudioExportResult(fileURL: outputURL)
    }

    /// 占位 WAV 导出（Phase 0 兼容，生成静音 WAV）
    static func exportPlaceholderWAV(for script: Script, fileName: String) throws -> AudioExportResult {
        try FileManager.default.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
        let fileURL = exportDirectory.appendingPathComponent("\(fileName).wav")
        let duration = max(1.0, Double(script.segments.count) * 0.8)
        let wavData = SilentWAVFactory.make(duration: duration)
        try wavData.write(to: fileURL, options: .atomic)
        return AudioExportResult(fileURL: fileURL)
    }

    // MARK: - Private Helpers

    /// 使用 AVAudioFile 读取 PCM samples
    /// - Parameter url: WAV 文件 URL
    /// - Returns: (samples, sampleRate)
    private static func readPCMSamples(from url: URL) throws -> ([Float], Double) {
        guard let audioFile = try? AVAudioFile(forReading: url) else {
            throw AudioExportError.failedToReadAudioFile
        }

        let format = audioFile.processingFormat
        let frameCount = UInt32(audioFile.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw AudioExportError.failedToCreateBuffer
        }

        try audioFile.read(into: buffer)

        // 提取 Float samples（假设 mono）
        guard let channelData = buffer.floatChannelData else {
            throw AudioExportError.noChannelData
        }

        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: Int(buffer.frameLength)))
        return (samples, format.sampleRate)
    }

    /// 写入 WAV 文件（使用 AVAudioFile）
    /// - Parameters:
    ///   - samples: PCM samples
    ///   - sampleRate: 采样率
    ///   - url: 输出 URL
    private static func writeWAVFile(samples: [Float], sampleRate: Int, to url: URL) throws {
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Double(sampleRate), channels: 1, interleaved: false)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: UInt32(samples.count)) else {
            throw AudioExportError.failedToCreateBuffer
        }

        buffer.frameLength = UInt32(samples.count)
        guard let channelData = buffer.floatChannelData else {
            throw AudioExportError.noChannelData
        }

        // 复制 samples 到 buffer
        for (i, sample) in samples.enumerated() {
            channelData[0][i] = sample
        }

        // 写入文件
        guard let outputFile = try? AVAudioFile(forWriting: url, settings: format.settings, commonFormat: format.commonFormat, interleaved: false) else {
            throw AudioExportError.failedToWriteAudioFile
        }

        try outputFile.write(from: buffer)
    }
}

// MARK: - Errors

enum AudioExportError: Error, LocalizedError {
    case noCompletedSegments
    case incompleteSegments([Int])
    case failedSegments([Int])
    case missingGeneratedAudio(segmentIndex: Int)
    case missingAudioFile(segmentIndex: Int)
    case emptyAudioData
    case failedToReadAudioFile
    case failedToCreateBuffer
    case noChannelData
    case failedToWriteAudioFile

    var errorDescription: String? {
        switch self {
        case .noCompletedSegments:
            return "没有可导出的已生成音频"
        case .incompleteSegments(let orders):
            return "第 \(Self.formatSegmentOrders(orders)) 段尚未生成完成，请生成完成后再导出"
        case .failedSegments(let orders):
            return "第 \(Self.formatSegmentOrders(orders)) 段生成失败，请重新生成后再导出"
        case .missingGeneratedAudio(let idx):
            return "第 \(idx) 段缺少生成音频，请重新生成"
        case .missingAudioFile(let idx):
            return "第 \(idx) 段音频文件丢失，请重新生成"
        case .emptyAudioData:
            return "音频数据为空"
        case .failedToReadAudioFile:
            return "无法读取音频文件"
        case .failedToCreateBuffer:
            return "无法创建音频缓冲区"
        case .noChannelData:
            return "音频无通道数据"
        case .failedToWriteAudioFile:
            return "无法写入音频文件"
        }
    }

    private static func formatSegmentOrders(_ orders: [Int]) -> String {
        orders.map(String.init).joined(separator: ", ")
    }
}

// MARK: - Silent WAV Factory (Phase 0 兼容)

private enum SilentWAVFactory {
    static func make(duration: Double, sampleRate: Int = 24_000) -> Data {
        let channelCount = 1
        let bitDepth = 16
        let byteRate = sampleRate * channelCount * bitDepth / 8
        let blockAlign = channelCount * bitDepth / 8
        let sampleCount = max(1, Int(duration * Double(sampleRate)))
        let dataSize = sampleCount * blockAlign

        var data = Data()
        data.appendASCII("RIFF")
        data.appendUInt32LE(UInt32(36 + dataSize))
        data.appendASCII("WAVE")
        data.appendASCII("fmt ")
        data.appendUInt32LE(16)
        data.appendUInt16LE(1)
        data.appendUInt16LE(UInt16(channelCount))
        data.appendUInt32LE(UInt32(sampleRate))
        data.appendUInt32LE(UInt32(byteRate))
        data.appendUInt16LE(UInt16(blockAlign))
        data.appendUInt16LE(UInt16(bitDepth))
        data.appendASCII("data")
        data.appendUInt32LE(UInt32(dataSize))
        data.append(Data(repeating: 0, count: dataSize))
        return data
    }
}

private extension Data {
    mutating func appendASCII(_ string: String) {
        append(contentsOf: string.utf8)
    }

    mutating func appendUInt16LE(_ value: UInt16) {
        append(UInt8(value & 0xff))
        append(UInt8((value >> 8) & 0xff))
    }

    mutating func appendUInt32LE(_ value: UInt32) {
        append(UInt8(value & 0xff))
        append(UInt8((value >> 8) & 0xff))
        append(UInt8((value >> 16) & 0xff))
        append(UInt8((value >> 24) & 0xff))
    }
}

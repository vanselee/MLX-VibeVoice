import Foundation

struct AudioExportResult {
    let fileURL: URL
}

enum AudioExportService {
    static var exportDirectory: URL {
        if let customPath = UserDefaults.standard.string(forKey: "defaultExportDirectory"), !customPath.isEmpty {
            return URL(fileURLWithPath: customPath)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Downloads", isDirectory: true)
            .appendingPathComponent("MLX Voice Notes Exports", isDirectory: true)
    }

    static let defaultExportDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Downloads", isDirectory: true)
        .appendingPathComponent("MLX Voice Notes Exports", isDirectory: true)

    static func exportPlaceholderWAV(for script: Script, fileName: String) throws -> AudioExportResult {
        try FileManager.default.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
        let fileURL = exportDirectory.appendingPathComponent("\(fileName).wav")
        let duration = max(1.0, Double(script.segments.count) * 0.8)
        let wavData = SilentWAVFactory.make(duration: duration)
        try wavData.write(to: fileURL, options: .atomic)
        return AudioExportResult(fileURL: fileURL)
    }
}

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

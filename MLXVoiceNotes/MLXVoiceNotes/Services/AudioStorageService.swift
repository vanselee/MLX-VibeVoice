import Foundation

/// 管理 App 持久化音频存储目录
/// Phase 0.5: 生成的音频文件存储在 Application Support/MLX Voice Notes/GeneratedAudio/<scriptID>/<segmentID>.wav
enum AudioStorageService {
    /// App 持久化音频根目录
    static var generatedAudioRoot: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("MLX Voice Notes/GeneratedAudio", isDirectory: true)
    }

    /// 获取指定文案的音频目录
    /// - Parameter scriptID: 文案 ID
    /// - Returns: 目录 URL（如不存在会自动创建）
    static func audioDirectory(for scriptID: UUID) throws -> URL {
        let dir = generatedAudioRoot.appendingPathComponent(scriptID.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// 获取指定段落的音频文件路径
    /// - Parameters:
    ///   - scriptID: 文案 ID
    ///   - segmentID: 段落 ID
    /// - Returns: 音频文件 URL
    static func audioFileURL(for scriptID: UUID, segmentID: UUID) throws -> URL {
        let dir = try audioDirectory(for: scriptID)
        return dir.appendingPathComponent("\(segmentID.uuidString).wav")
    }

    /// 将临时音频文件复制到持久化目录
    /// - Parameters:
    ///   - tempURL: 临时文件 URL（来自 MLXAudioService）
    ///   - scriptID: 文案 ID
    ///   - segmentID: 段落 ID
    /// - Returns: 持久化文件 URL
    /// - Throws: 文件操作错误
    static func persistAudioFile(tempURL: URL, for scriptID: UUID, segmentID: UUID) throws -> URL {
        let destURL = try audioFileURL(for: scriptID, segmentID: segmentID)

        // 如果目标文件已存在，先删除
        if FileManager.default.fileExists(atPath: destURL.path) {
            try FileManager.default.removeItem(at: destURL)
        }

        // 复制临时文件到持久化目录
        try FileManager.default.copyItem(at: tempURL, to: destURL)

        return destURL
    }

    /// 获取持久化音频文件的相对路径（相对于 generatedAudioRoot）
    /// - Parameter url: 绝对路径 URL
    /// - Returns: 相对路径字符串（如 "scriptID/segmentID.wav"）
    static func relativePath(from url: URL) -> String {
        let rootPath = generatedAudioRoot.path
        let absolutePath = url.path
        if absolutePath.hasPrefix(rootPath) {
            let relative = String(absolutePath.dropFirst(rootPath.count))
            return relative.hasPrefix("/") ? String(relative.dropFirst()) : relative
        }
        return absolutePath
    }

    /// 从相对路径恢复绝对路径
    /// - Parameter relativePath: 相对路径字符串
    /// - Returns: 绝对路径 URL
    static func absoluteURL(from relativePath: String) -> URL {
        return generatedAudioRoot.appendingPathComponent(relativePath)
    }

    /// 检查音频文件是否存在
    /// - Parameter relativePath: 相对路径
    /// - Returns: 文件是否存在
    static func audioFileExists(at relativePath: String) -> Bool {
        let url = absoluteURL(from: relativePath)
        return FileManager.default.fileExists(atPath: url.path)
    }

    /// 删除指定文案的所有音频文件
    /// - Parameter scriptID: 文案 ID
    static func deleteAudioFiles(for scriptID: UUID) throws {
        let dir = try audioDirectory(for: scriptID)
        if FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.removeItem(at: dir)
        }
    }

    /// 清理所有生成的音频文件（用于缓存清理）
    static func clearAllGeneratedAudio() throws {
        if FileManager.default.fileExists(atPath: generatedAudioRoot.path) {
            try FileManager.default.removeItem(at: generatedAudioRoot)
        }
    }

    /// 计算生成的音频文件总大小（字节）
    static func totalGeneratedAudioSize() throws -> Int64 {
        guard FileManager.default.fileExists(atPath: generatedAudioRoot.path) else {
            return 0
        }

        let enumerator = FileManager.default.enumerator(at: generatedAudioRoot, includingPropertiesForKeys: [.fileSizeKey])
        var totalSize: Int64 = 0

        while let fileURL = enumerator?.nextObject() as? URL {
            let attrs = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            if let size = attrs[.size] as? Int64 {
                totalSize += size
            }
        }

        return totalSize
    }
}

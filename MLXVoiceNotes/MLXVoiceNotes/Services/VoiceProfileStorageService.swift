import Foundation

/// Phase 2C 参考音色资产存储服务
///
/// 存储结构：
/// Application Support/MLX Voice Notes/VoiceProfiles/<voiceProfileID>/
///   └── reference.<ext>
///
/// 与 GeneratedAudio 的区别：
///   - VoiceProfiles/：用户输入资产（永久保留，仅用户删除音色时清理）
///   - GeneratedAudio/：TTS 输出产物（可重新生成，文案删除时一并清理）
final class VoiceProfileStorageService {

    static let shared = VoiceProfileStorageService()

    private let fileManager = FileManager.default

    // MARK: - Directory

    /// Application Support 下 VoiceProfiles 根目录
    var voiceProfilesRoot: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("MLX Voice Notes/VoiceProfiles", isDirectory: true)
    }

    /// 指定 VoiceProfile 的资产目录
    func directory(for voiceProfileID: UUID) -> URL {
        voiceProfilesRoot.appendingPathComponent(voiceProfileID.uuidString, isDirectory: true)
    }

    // MARK: - Reference Audio

    /// 给定 VoiceProfile，推断参考音频的存放 URL（原扩展名）
    func referenceAudioURL(for voiceProfileID: UUID, originalExtension: String) -> URL {
        directory(for: voiceProfileID)
            .appendingPathComponent("reference.\(originalExtension.lowercased())")
    }

    /// 将外部音频文件复制到音色资产目录
    /// - Parameters:
    ///   - sourceURL: 用户导入的原始音频文件 URL
    ///   - voiceProfileID: 目标 VoiceProfile 的 UUID
    /// - Returns: 复制后的目标 URL
    /// - Throws: 文件复制错误
    func persistReferenceAudio(sourceURL: URL, for voiceProfileID: UUID) throws -> URL {
        let destDir = directory(for: voiceProfileID)
        try fileManager.createDirectory(at: destDir, withIntermediateDirectories: true)

        let ext = sourceURL.pathExtension.isEmpty ? "mp3" : sourceURL.pathExtension
        let destURL = referenceAudioURL(for: voiceProfileID, originalExtension: ext)

        // 若目标已存在（重复导入），先删除旧文件
        if fileManager.fileExists(atPath: destURL.path) {
            try fileManager.removeItem(at: destURL)
        }

        try fileManager.copyItem(at: sourceURL, to: destURL)
        return destURL
    }

    // MARK: - Path Helpers

    /// 将绝对 URL 转换为 VoiceProfiles/... 相对路径
    /// 用于存入 VoiceProfile.referenceAudioLocalPath
    func relativePath(from absoluteURL: URL) -> String {
        voiceProfilesRoot.pathComponents
            .reduce(absoluteURL.pathComponents) { components, rootComponent in
                guard components.first == rootComponent else { return components }
                return Array(components.dropFirst())
            }
            .joined(separator: "/")
    }

    /// 将相对路径转换为绝对 URL
    func absoluteURL(from relativePath: String) -> URL {
        voiceProfilesRoot.appendingPathComponent(relativePath)
    }

    // MARK: - Asset Existence

    /// 检查资产文件是否存在
    func assetExists(at relativePath: String) -> Bool {
        let url = absoluteURL(from: relativePath)
        return fileManager.fileExists(atPath: url.path)
    }

    // MARK: - Test Audio

    /// 返回指定 VoiceProfile 的测试音频存放路径
    func testAudioURL(for voiceProfileID: UUID) -> URL {
        directory(for: voiceProfileID).appendingPathComponent("test.wav")
    }

    /// 移动临时测试音频到音色资产目录
    /// - Returns: 最终存放的 URL
    func persistTestAudio(from tempURL: URL, for voiceProfileID: UUID) throws -> URL {
        let destURL = testAudioURL(for: voiceProfileID)
        let destDir = directory(for: voiceProfileID)
        try fileManager.createDirectory(at: destDir, withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: destURL.path) {
            try fileManager.removeItem(at: destURL)
        }
        try fileManager.moveItem(at: tempURL, to: destURL)
        return destURL
    }

    /// 删除指定 VoiceProfile 的全部资产目录
    func deleteVoiceProfileAssets(for voiceProfileID: UUID) throws {
        let profileDir = directory(for: voiceProfileID)
        if fileManager.fileExists(atPath: profileDir.path) {
            try fileManager.removeItem(at: profileDir)
        }
    }
}
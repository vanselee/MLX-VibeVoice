import Foundation
import SwiftData
import AVFoundation

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

    // MARK: - Voice Profile Readiness

    /// 错误类型：音色资产准备失败
    enum ReadinessError: LocalizedError {
        case profileNotFound
        case emptyName
        case emptyReferenceAudioPath
        case emptyReferenceText
        case referenceAudioNotPersisted(path: String)
        case referenceAudioNotReadable(path: String)
        case modelContextUnavailable

        var errorDescription: String? {
            switch self {
            case .profileNotFound:            return "音色档案未找到"
            case .emptyName:                  return "音色名称为空"
            case .emptyReferenceAudioPath:    return "参考音频路径为空"
            case .emptyReferenceText:          return "参考文本为空"
            case .referenceAudioNotPersisted(let path): return "参考音频未持久化：\(path)"
            case .referenceAudioNotReadable(let path):  return "参考音频无法读取：\(path)"
            case .modelContextUnavailable:    return "无法访问数据上下文"
            }
        }
    }

    /// 确保音色档案已完成资产准备。
    /// 校验：名称 + referenceAudioPath + referenceText + 音频文件可读 + 可作为 MLX 输入。
    /// 成功后自行更新 VoiceProfile.status = .available 并保存上下文。
    /// - Parameters:
    ///   - profileID: 目标 VoiceProfile 的 UUID
    ///   - context: SwiftData ModelContext
    /// - Returns: 校验通过的 VoiceProfile 实例
    /// - Throws: ReadinessError
    /// 确保音色档案已完成资产准备并标记为可用。
    /// 校验：名称 + referenceAudioPath + referenceText + 音频文件存在 + 音频可读取。
    /// 成功后自行更新 VoiceProfile.status = .available 并保存上下文。
    /// 失败时将 status 改为 .failed 并保存上下文，避免资源中心永久显示"创建中"。
    func ensureVoiceProfileReady(profileID: UUID, context: ModelContext) async throws -> VoiceProfile {
        // 1. 获取音色档案
        let descriptor = FetchDescriptor<VoiceProfile>(predicate: #Predicate { $0.id == profileID })
        guard let profile = try context.fetch(descriptor).first else {
            throw ReadinessError.profileNotFound
        }

        // 2. 音色名称
        guard !profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            await markFailed(profile: profile, context: context)
            throw ReadinessError.emptyName
        }

        // 3. referenceAudioPath
        guard let refPath = profile.referenceAudioPath, !refPath.isEmpty else {
            await markFailed(profile: profile, context: context)
            throw ReadinessError.emptyReferenceAudioPath
        }

        // 4. referenceText
        guard let refText = profile.referenceText,
              !refText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            await markFailed(profile: profile, context: context)
            throw ReadinessError.emptyReferenceText
        }

        // 5. 确认参考音频已持久化
        let absURL = absoluteURL(from: refPath)
        guard fileManager.fileExists(atPath: absURL.path) else {
            await markFailed(profile: profile, context: context)
            throw ReadinessError.referenceAudioNotPersisted(path: absURL.path)
        }

        // 6. 确认参考音频可读取（能加载时长即为可读）
        let asset = AVURLAsset(url: absURL)
        do {
            let duration = try await asset.load(.duration)
            let secs = CMTimeGetSeconds(duration)
            if secs.isFinite && secs > 0 {
                profile.durationSeconds = secs
            }
        } catch {
            await markFailed(profile: profile, context: context)
            throw ReadinessError.referenceAudioNotReadable(path: absURL.path)
        }

        // 7. 校验全部通过，标记可用并保存
        profile.status = .available
        profile.modifiedAt = Date()
        try context.save()

        return profile
    }

    /// 将音色标记为失败状态并保存，避免资源中心永久显示"创建中"
    private func markFailed(profile: VoiceProfile, context: ModelContext) async {
        profile.status = .failed
        profile.modifiedAt = Date()
        try? context.save()
    }
}
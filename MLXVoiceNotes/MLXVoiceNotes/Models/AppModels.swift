import Foundation
import SwiftData

enum ScriptStatus: String, Codable, CaseIterable {
    case draft
    case ready
    case generating
    case completed
    case failed
}

enum SegmentStatus: String, Codable, CaseIterable {
    case pending
    case generating
    case completed
    case failed
    case skipped
}

enum VoiceKind: String, Codable, CaseIterable {
    case preset   // 内置 / 系统音色
    case reference // 参考音色
    case cloned   // 克隆音色
}

enum VoiceProfileStatus: String, Codable, CaseIterable {
    case builtIn        // 内置，不可删除
    case available      // 可用
    case pendingReview  // 待验证
    case failed         // 失败
}

enum VoiceSource: String, Codable, CaseIterable {
    case system         // 系统内置
    case localAudio     // 本地音频导入
    case localGenerated // 本地生成（克隆）
}

enum ExportKind: String, Codable, CaseIterable {
    case wav
    case srt
    case projectPackage
}

enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case system
    case zhHans
    case en

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .zhHans: return "中文"
        case .en: return "English"
        }
    }
}

enum CacheLimit: String, CaseIterable, Identifiable {
    case gb5 = "5GB"
    case gb10 = "10GB"
    case gb20 = "20GB"
    case unlimited = "不限制"

    var id: String { rawValue }

    var displayName: String { rawValue }
}

@Model
final class Script {
    var id: UUID
    var title: String
    var subtitle: String
    var bodyText: String
    var status: ScriptStatus
    var createdAt: Date
    var updatedAt: Date
    var lastExportedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \ScriptSegment.script)
    var segments: [ScriptSegment]

    @Relationship(deleteRule: .cascade, inverse: \VoiceRole.script)
    var roles: [VoiceRole]

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String = "",
        bodyText: String = "",
        status: ScriptStatus = .draft,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        lastExportedAt: Date? = nil,
        segments: [ScriptSegment] = [],
        roles: [VoiceRole] = []
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.bodyText = bodyText
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastExportedAt = lastExportedAt
        self.segments = segments
        self.roles = roles
    }
}

@Model
final class ScriptSegment {
    var id: UUID
    var order: Int
    var text: String
    var roleName: String
    var status: SegmentStatus
    var selectedVersion: Int
    var generatedAudioPath: String?  // Phase 0.5: 生成的音频文件路径（相对路径，位于 App GeneratedAudio 目录）
    var script: Script?

    init(
        id: UUID = UUID(),
        order: Int,
        text: String,
        roleName: String = "旁白",
        status: SegmentStatus = .pending,
        selectedVersion: Int = 1,
        generatedAudioPath: String? = nil,
        script: Script? = nil
    ) {
        self.id = id
        self.order = order
        self.text = text
        self.roleName = roleName
        self.status = status
        self.selectedVersion = selectedVersion
        self.generatedAudioPath = generatedAudioPath
        self.script = script
    }
}

@Model
final class VoiceRole {
    var id: UUID
    var name: String
    var normalizedName: String
    var defaultVoiceName: String
    var speed: Double
    var volumeDB: Double
    var pitch: Double
    var script: Script?

    init(
        id: UUID = UUID(),
        name: String,
        normalizedName: String,
        defaultVoiceName: String = "默认旁白",
        speed: Double = 1.0,
        volumeDB: Double = 0,
        pitch: Double = 0,
        script: Script? = nil
    ) {
        self.id = id
        self.name = name
        self.normalizedName = normalizedName
        self.defaultVoiceName = defaultVoiceName
        self.speed = speed
        self.volumeDB = volumeDB
        self.pitch = pitch
        self.script = script
    }
}

@Model
final class VoiceProfile {
    var id: UUID
    var name: String
    var kind: VoiceKind
    var source: VoiceSource
    var status: VoiceProfileStatus
    var localeIdentifier: String
    var referenceAudioPath: String?
    var referenceText: String?
    var durationSeconds: Double?
    var isDefaultNarrator: Bool
    var createdAt: Date
    var modifiedAt: Date
    var lastUsedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        kind: VoiceKind,
        source: VoiceSource,
        status: VoiceProfileStatus,
        localeIdentifier: String = "zh-Hans",
        referenceAudioPath: String? = nil,
        referenceText: String? = nil,
        durationSeconds: Double? = nil,
        isDefaultNarrator: Bool = false,
        createdAt: Date = .now,
        modifiedAt: Date = .now,
        lastUsedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.source = source
        self.status = status
        self.localeIdentifier = localeIdentifier
        self.referenceAudioPath = referenceAudioPath
        self.referenceText = referenceText
        self.durationSeconds = durationSeconds
        self.isDefaultNarrator = isDefaultNarrator
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.lastUsedAt = lastUsedAt
    }

    var kindLabel: String {
        switch kind {
        case .preset:    return "内置"
        case .reference: return "参考音色"
        case .cloned:    return "克隆音色"
        }
    }

    var sourceLabel: String {
        switch source {
        case .system:         return "系统"
        case .localAudio:    return "本地音频"
        case .localGenerated: return "本地生成"
        }
    }

    var statusLabel: String {
        switch status {
        case .builtIn:       return "内置"
        case .available:     return "可用"
        case .pendingReview: return "待验证"
        case .failed:        return "失败"
        }
    }

    var durationLabel: String {
        guard let s = durationSeconds else { return "-" }
        return String(format: "%.0f 秒", s)
    }
}

// MARK: - Sample Data for Preview / Development

extension VoiceProfile {
    static var samples: [VoiceProfile] {
        [
            VoiceProfile(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                name: "默认清晰女声",
                kind: .preset,
                source: .system,
                status: .builtIn,
                localeIdentifier: "zh-Hans",
                lastUsedAt: Date()
            ),
            VoiceProfile(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                name: "自然男声",
                kind: .preset,
                source: .system,
                status: .builtIn,
                localeIdentifier: "zh-Hans",
                lastUsedAt: Date().addingTimeInterval(-86400)
            ),
            VoiceProfile(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
                name: "vanselee 参考音色",
                kind: .reference,
                source: .localAudio,
                status: .available,
                referenceAudioPath: "~/Downloads/4月22日声音母带.mp3",
                referenceText: "你永远都搞不清楚这些平台它到底要什么，不要什么。",
                durationSeconds: 28,
                lastUsedAt: Date().addingTimeInterval(-3600)
            )
        ]
    }
}

@Model
final class GenerationJob {
    var id: UUID
    var scriptTitle: String
    var totalSegments: Int
    var completedSegments: Int
    var failedSegments: Int
    var status: ScriptStatus
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        scriptTitle: String,
        totalSegments: Int,
        completedSegments: Int = 0,
        failedSegments: Int = 0,
        status: ScriptStatus = .ready,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.scriptTitle = scriptTitle
        self.totalSegments = totalSegments
        self.completedSegments = completedSegments
        self.failedSegments = failedSegments
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class ExportRecord {
    var id: UUID
    var scriptTitle: String
    var kind: ExportKind
    var filePath: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        scriptTitle: String,
        kind: ExportKind,
        filePath: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.scriptTitle = scriptTitle
        self.kind = kind
        self.filePath = filePath
        self.createdAt = createdAt
    }
}

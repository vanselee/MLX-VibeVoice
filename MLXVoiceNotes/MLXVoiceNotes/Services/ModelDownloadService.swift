import Foundation

/// 本地模型状态检测服务
/// 注意：本步骤不下载、不删除文件，仅做状态检测
final class ModelDownloadService {
    static let shared = ModelDownloadService()

    // MARK: - 常量

    /// 当前唯一支持模型
    static let supportedModelID = "mlx-community/Qwen3-TTS-12Hz-0.6B-Base-bf16"

    /// 本地缓存根目录（`~/.cache/huggingface/hub/mlx-audio/`）
    static var modelCacheRoot: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home
            .appendingPathComponent(".cache")
            .appendingPathComponent("huggingface")
            .appendingPathComponent("hub")
            .appendingPathComponent("mlx-audio")
    }

    /// 当前模型目录
    static var currentModelPath: URL {
        modelCacheRoot
            .appendingPathComponent("mlx-community_Qwen3-TTS-12Hz-0.6B-Base-bf16")
    }

    /// 必需文件清单
    private static let requiredFiles: [String] = [
        "config.json",
        "generation_config.json",
        "merges.txt",
        "model.safetensors",
        "model.safetensors.index.json",
        "preprocessor_config.json",
        "tokenizer.json",
        "tokenizer_config.json",
        "vocab.json",
        "speech_tokenizer/config.json",
        "speech_tokenizer/configuration.json",
        "speech_tokenizer/model.safetensors",
        "speech_tokenizer/preprocessor_config.json"
    ]

    // MARK: - 状态定义

    enum ModelStatus: Equatable {
        case installed(sizeBytes: Int64)       // 已安装，显示大小
        case notDownloaded                     // 未下载
        case incomplete(missingFiles: [String]) // 文件不完整

        var displaySize: String {
            switch self {
            case .installed(let bytes):
                return ModelDownloadService.formatBytes(bytes)
            case .notDownloaded, .incomplete:
                return "约 2.35GB"
            }
        }

        var statusSummary: String {
            switch self {
            case .installed:
                return "已安装 · \(displaySize) · 推荐 8GB 以上统一内存"
            case .notDownloaded:
                return "未下载 · \(displaySize)"
            case .incomplete(let files):
                let count = files.count
                return "文件不完整 · 缺失 \(count) 个文件"
            }
        }
    }

    // MARK: - 核心检测

    /// 检测当前模型状态
    func checkModelStatus() -> ModelStatus {
        let modelPath = Self.currentModelPath

        // 目录不存在
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: modelPath.path, isDirectory: &isDir),
              isDir.boolValue else {
            return .notDownloaded
        }

        // 逐文件检查
        var missingFiles: [String] = []
        var totalSize: Int64 = 0

        for fileName in Self.requiredFiles {
            let filePath = modelPath.appendingPathComponent(fileName)
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: filePath.path),
                  let size = attrs[.size] as? Int64,
                  size > 0 else {
                missingFiles.append(fileName)
                continue
            }
            totalSize += size
        }

        if missingFiles.isEmpty {
            return .installed(sizeBytes: totalSize)
        } else {
            return .incomplete(missingFiles: missingFiles)
        }
    }

    /// 获取缺失文件列表（供 UI 显示）
    func missingFiles() -> [String] {
        let modelPath = Self.currentModelPath
        var missing: [String] = []

        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: modelPath.path, isDirectory: &isDir),
              isDir.boolValue else {
            return Self.requiredFiles
        }

        for fileName in Self.requiredFiles {
            let filePath = modelPath.appendingPathComponent(fileName)
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: filePath.path),
                  let size = attrs[.size] as? Int64,
                  size > 0 else {
                missing.append(fileName)
                continue
            }
        }
        return missing
    }

    // MARK: - 辅助

    private static func formatBytes(_ bytes: Int64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1.0 {
            return String(format: "%.2fGB", gb)
        }
        let mb = Double(bytes) / 1_048_576
        return String(format: "%.0fMB", mb)
    }
}

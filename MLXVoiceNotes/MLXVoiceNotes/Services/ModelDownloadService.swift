import Foundation

// MARK: - 模型定义

/// Qwen3 TTS 模型信息
struct QwenTTSModel: Identifiable, Hashable {
    let id: String                    // repo name (unique identifier)
    let displayName: String           // 显示名称
    let repo: String                  // HuggingFace repo
    let localDirectoryName: String    // 本地目录名
    let category: String              // 分类描述
    let precision: String             // bf16 / 8bit / 4bit
    let modelSizeLevel: String        // 0.6B / 1.7B
    let expectedSizeText: String      // 预估大小文本
    let memoryHint: String            // 内存建议
    let isBaseline: Bool              // 是否为基准模型
    let isRecommended: Bool           // 是否推荐
    let isExperimental: Bool          // 是否实验性
    let requiredFiles: [String]       // 必需文件列表

    /// 本地缓存路径
    var localPath: URL {
        ModelDownloadService.modelCacheRoot.appendingPathComponent(localDirectoryName)
    }
}

// MARK: - 模型目录

/// Qwen3 TTS 模型目录（固定 5 个模型）
enum ModelCatalog {
    /// 所有支持的模型列表（按优先级排序：基准模型优先，然后按推荐/实验排序）
    static let allModels: [QwenTTSModel] = [
        // 基准模型（已验证）
        QwenTTSModel(
            id: "mlx-community/Qwen3-TTS-12Hz-0.6B-Base-bf16",
            displayName: "Qwen3-TTS 0.6B Base",
            repo: "mlx-community/Qwen3-TTS-12Hz-0.6B-Base-bf16",
            localDirectoryName: "mlx-community_Qwen3-TTS-12Hz-0.6B-Base-bf16",
            category: "基准模型",
            precision: "bf16",
            modelSizeLevel: "0.6B",
            expectedSizeText: "~2.35GB",
            memoryHint: "推荐 8GB 以上统一内存",
            isBaseline: true,
            isRecommended: true,
            isExperimental: false,
            requiredFiles: standardRequiredFiles
        ),

        // 1.7B CustomVoice 系列（按精度排序）
        QwenTTSModel(
            id: "mlx-community/Qwen3-TTS-12Hz-1.7B-CustomVoice-8bit",
            displayName: "Qwen3-TTS 1.7B CustomVoice",
            repo: "mlx-community/Qwen3-TTS-12Hz-1.7B-CustomVoice-8bit",
            localDirectoryName: "mlx-community_Qwen3-TTS-12Hz-1.7B-CustomVoice-8bit",
            category: "参考音色",
            precision: "8bit",
            modelSizeLevel: "1.7B",
            expectedSizeText: "~3.5GB",
            memoryHint: "推荐 12GB 以上统一内存",
            isBaseline: false,
            isRecommended: true,
            isExperimental: false,
            requiredFiles: standardRequiredFiles
        ),
        QwenTTSModel(
            id: "mlx-community/Qwen3-TTS-12Hz-1.7B-CustomVoice-bf16",
            displayName: "Qwen3-TTS 1.7B CustomVoice",
            repo: "mlx-community/Qwen3-TTS-12Hz-1.7B-CustomVoice-bf16",
            localDirectoryName: "mlx-community_Qwen3-TTS-12Hz-1.7B-CustomVoice-bf16",
            category: "参考音色",
            precision: "bf16",
            modelSizeLevel: "1.7B",
            expectedSizeText: "~6.5GB",
            memoryHint: "推荐 16GB 以上统一内存",
            isBaseline: false,
            isRecommended: false,
            isExperimental: true,
            requiredFiles: standardRequiredFiles
        ),
        QwenTTSModel(
            id: "mlx-community/Qwen3-TTS-12Hz-1.7B-CustomVoice-4bit",
            displayName: "Qwen3-TTS 1.7B CustomVoice",
            repo: "mlx-community/Qwen3-TTS-12Hz-1.7B-CustomVoice-4bit",
            localDirectoryName: "mlx-community_Qwen3-TTS-12Hz-1.7B-CustomVoice-4bit",
            category: "参考音色",
            precision: "4bit",
            modelSizeLevel: "1.7B",
            expectedSizeText: "~2.0GB",
            memoryHint: "推荐 8GB 以上统一内存",
            isBaseline: false,
            isRecommended: false,
            isExperimental: true,
            requiredFiles: standardRequiredFiles
        ),

        // 0.6B CustomVoice（轻量实验）
        QwenTTSModel(
            id: "mlx-community/Qwen3-TTS-12Hz-0.6B-CustomVoice-8bit",
            displayName: "Qwen3-TTS 0.6B CustomVoice",
            repo: "mlx-community/Qwen3-TTS-12Hz-0.6B-CustomVoice-8bit",
            localDirectoryName: "mlx-community_Qwen3-TTS-12Hz-0.6B-CustomVoice-8bit",
            category: "参考音色",
            precision: "8bit",
            modelSizeLevel: "0.6B",
            expectedSizeText: "~1.5GB",
            memoryHint: "推荐 6GB 以上统一内存",
            isBaseline: false,
            isRecommended: false,
            isExperimental: true,
            requiredFiles: standardRequiredFiles
        )
    ]

    /// 标准必需文件清单
    private static let standardRequiredFiles: [String] = [
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

    /// 当前基准模型（用于正式生成）
    static let baselineModel = allModels.first { $0.isBaseline }!

    /// 根据 repo 查找模型
    static func find(byRepo repo: String) -> QwenTTSModel? {
        allModels.first { $0.repo == repo }
    }
}

// MARK: - 状态定义

/// 模型安装状态
enum ModelInstallStatus: Equatable {
    case installed(sizeBytes: Int64)       // 已安装
    case notDownloaded                    // 未下载
    case incomplete(missingFiles: [String]) // 文件不完整

    /// 显示文本
    var displayText: String {
        switch self {
        case .installed:
            return "已安装"
        case .notDownloaded:
            return "未下载"
        case .incomplete:
            return "文件不完整"
        }
    }

    /// 是否已安装
    var isInstalled: Bool {
        if case .installed = self { return true }
        return false
    }
}

// MARK: - 检测服务

/// 本地模型状态检测服务
/// 注意：本步骤不下载、不删除文件，仅做状态检测
final class ModelDownloadService {
    static let shared = ModelDownloadService()

    // MARK: - 常量

    /// 本地缓存根目录（`~/.cache/huggingface/hub/mlx-audio/`）
    static var modelCacheRoot: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home
            .appendingPathComponent(".cache")
            .appendingPathComponent("huggingface")
            .appendingPathComponent("hub")
            .appendingPathComponent("mlx-audio")
    }

    /// 当前基准模型路径（兼容旧代码）
    static var currentModelPath: URL {
        ModelCatalog.baselineModel.localPath
    }

    private init() {}

    // MARK: - 核心检测

    /// 检测指定模型的安装状态
    func checkStatus(for model: QwenTTSModel) -> ModelInstallStatus {
        let modelPath = model.localPath

        // 目录不存在
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: modelPath.path, isDirectory: &isDir),
              isDir.boolValue else {
            return .notDownloaded
        }

        // 逐文件检查
        var missingFiles: [String] = []
        var totalSize: Int64 = 0

        for fileName in model.requiredFiles {
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

    /// 获取缺失文件列表
    func missingFiles(for model: QwenTTSModel) -> [String] {
        let modelPath = model.localPath
        var missing: [String] = []

        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: modelPath.path, isDirectory: &isDir),
              isDir.boolValue else {
            return model.requiredFiles
        }

        for fileName in model.requiredFiles {
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

    /// 批量检测所有模型状态
    func checkAllModels() -> [(model: QwenTTSModel, status: ModelInstallStatus)] {
        ModelCatalog.allModels.map { model in
            (model: model, status: checkStatus(for: model))
        }
    }

    // MARK: - 兼容旧 API

    /// 旧 API：检测当前模型状态（兼容现有代码）
    func checkModelStatus() -> LegacyModelStatus {
        let status = checkStatus(for: ModelCatalog.baselineModel)
        switch status {
        case .installed(let bytes):
            return .installed(sizeBytes: bytes)
        case .notDownloaded:
            return .notDownloaded
        case .incomplete(let files):
            return .incomplete(missingFiles: files)
        }
    }

    /// 旧 API：获取缺失文件列表
    func missingFiles() -> [String] {
        missingFiles(for: ModelCatalog.baselineModel)
    }

    // MARK: - 辅助

    static func formatBytes(_ bytes: Int64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1.0 {
            return String(format: "%.2fGB", gb)
        }
        let mb = Double(bytes) / 1_048_576
        return String(format: "%.0fMB", mb)
    }
}

// MARK: - 兼容旧类型

/// 旧 ModelStatus 类型（兼容现有 UI）
enum LegacyModelStatus: Equatable {
    case installed(sizeBytes: Int64)
    case notDownloaded
    case incomplete(missingFiles: [String])

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

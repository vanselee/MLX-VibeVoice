import Foundation
import Combine

// MARK: - 模型定义

/// Qwen TTS 模型元数据
struct QwenTTSModel: Identifiable, Equatable, Hashable {
    let id: String
    let displayName: String
    let repo: String
    let subdirectory: String?
    let precision: String
    let sizeLabel: String
    let memoryHint: String
    let isBaseline: Bool
    let isRecommended: Bool
    let isExperimental: Bool

    var category: String {
        if repo.contains("Base") {
            return "基础模型"
        } else if repo.contains("CustomVoice") {
            return "音色定制"
        }
        return "通用"
    }

    var modelSizeLevel: String {
        if displayName.contains("1.7B") {
            return "1.7B"
        } else if displayName.contains("0.6B") {
            return "0.6B"
        }
        return sizeLabel
    }

    var expectedSizeText: String {
        sizeLabel
    }

    /// 标准必需文件清单（所有 Qwen TTS 模型通用）
    static let standardRequiredFiles: [String] = [
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
        "speech_tokenizer/preprocessor_config.json",
    ]

    var requiredFiles: [String] { Self.standardRequiredFiles }

    var localPath: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let repoDirName = repo.replacingOccurrences(of: "/", with: "_")
        return home
            .appendingPathComponent(".cache/huggingface/hub/mlx-audio")
            .appendingPathComponent(repoDirName)
    }
}

/// 模型目录（固定 5 个模型）
enum ModelCatalog {
    static let allModels: [QwenTTSModel] = [
        QwenTTSModel(
            id: "cv-17B-bf16",
            displayName: "CustomVoice 1.7B (bf16)",
            repo: "mlx-community/Qwen3-TTS-12Hz-1.7B-CustomVoice-bf16",
            subdirectory: nil,
            precision: "bf16",
            sizeLabel: "~3.4GB",
            memoryHint: "~6GB",
            isBaseline: false,
            isRecommended: true,
            isExperimental: false
        ),
        QwenTTSModel(
            id: "cv-17B-8bit",
            displayName: "CustomVoice 1.7B (8bit)",
            repo: "mlx-community/Qwen3-TTS-12Hz-1.7B-CustomVoice-8bit",
            subdirectory: nil,
            precision: "8bit",
            sizeLabel: "~1.8GB",
            memoryHint: "~4GB",
            isBaseline: false,
            isRecommended: false,
            isExperimental: false
        ),
        QwenTTSModel(
            id: "cv-17B-4bit",
            displayName: "CustomVoice 1.7B (4bit)",
            repo: "mlx-community/Qwen3-TTS-12Hz-1.7B-CustomVoice-4bit",
            subdirectory: nil,
            precision: "4bit",
            sizeLabel: "~1.0GB",
            memoryHint: "~3GB",
            isBaseline: false,
            isRecommended: false,
            isExperimental: true
        ),
        QwenTTSModel(
            id: "cv-06B-8bit",
            displayName: "CustomVoice 0.6B (8bit)",
            repo: "mlx-community/Qwen3-TTS-12Hz-0.6B-CustomVoice-8bit",
            subdirectory: nil,
            precision: "8bit",
            sizeLabel: "~0.7GB",
            memoryHint: "~1GB",
            isBaseline: false,
            isRecommended: false,
            isExperimental: false
        ),
        QwenTTSModel(
            id: "base-06B",
            displayName: "Base 0.6B (bf16)",
            repo: "mlx-community/Qwen3-TTS-12Hz-0.6B-Base-bf16",
            subdirectory: nil,
            precision: "bf16",
            sizeLabel: "~1.2GB",
            memoryHint: "~1.5GB",
            isBaseline: true,
            isRecommended: false,
            isExperimental: false
        ),
    ]

    static func model(for repo: String) -> QwenTTSModel? {
        allModels.first { $0.repo == repo }
    }
}

/// 模型的安装状态
enum ModelInstallStatus: Equatable {
    case notDownloaded
    case installing(progress: Double)
    case installed(totalBytes: Int64)
    case incomplete(missingFiles: [String])
    case failed(message: String)

    var isInstalled: Bool {
        if case .installed = self { return true }
        return false
    }
}

// MARK: - 下载状态

/// 单个文件的下载状态
enum FileDownloadState: Equatable {
    case pending           // 等待下载
    case downloading(progress: Double, downloadedBytes: Int64)  // 下载中
    case paused(partialBytes: Int64)    // 已暂停
    case completed                   // 已完成
    case failed(error: String)       // 失败
}

/// 整个模型的下载状态
enum ModelDownloadState: Equatable {
    case idle                    // 未开始
    case preparing               // 准备中（获取文件清单）
    case downloading(progress: Double, downloadedBytes: Int64, totalBytes: Int64, speedBps: Double, currentFile: String, isResuming: Bool)
    case paused(partialBytes: Int64, totalBytes: Int64)
    case failed(error: String)
    case completed

    var isActive: Bool {
        switch self {
        case .downloading: return true
        default: return false
        }
    }
}

// MARK: - 模型下载任务

/// 按 requiredFiles 顺序逐个下载模型文件，使用 HTTPRangeFileDownloader 实现断点续传。
/// - 已完成文件跳过；.partial 文件自动续传
/// - 总进度 = (已完成文件大小 + 当前文件进度) / manifest 总大小
/// - 取消时保留 .partial；失败时保留错误状态，不破坏正式文件
final class ModelDownloadTask: ObservableObject, @unchecked Sendable {
    let model: QwenTTSModel

    @Published var state: ModelDownloadState = .idle
    @Published var files: [String: FileDownloadState] = [:]

    private var currentDownloader: HTTPRangeFileDownloader?
    private var totalBytes: Int64 = 0
    private var completedBytes: Int64 = 0
    private var isCancelled = false

    init(model: QwenTTSModel) {
        self.model = model
        for file in model.requiredFiles {
            files[file] = .pending
        }
    }

    /// 启动下载：HEAD 获取所有文件大小 → 按顺序逐个下载
    func start() {
        isCancelled = false
        completedBytes = 0
        state = .preparing

        fetchAllFileSizes { [weak self] fileInfos in
            guard let self = self, !self.isCancelled else { return }
            let ordered = self.model.requiredFiles.compactMap { file in
                fileInfos.first(where: { $0.path == file })
            }
            self.downloadSequentially(ordered)
        }
    }

    /// 取消下载（保留 .partial 文件供续传）
    func cancel() {
        isCancelled = true
        currentDownloader?.cancel()
        let currentBytes = completedBytes + (currentDownloader?.downloadedBytes ?? 0)
        DispatchQueue.main.async {
            for (key, fileState) in self.files {
                if case .downloading = fileState {
                    let partial = self.model.localPath
                        .appendingPathComponent(key)
                        .appendingPathExtension("partial")
                    let partialSize: Int64
                    if let attrs = try? FileManager.default.attributesOfItem(atPath: partial.path),
                       let size = attrs[.size] as? Int64 {
                        partialSize = size
                    } else {
                        partialSize = 0
                    }
                    self.files[key] = .paused(partialBytes: partialSize)
                }
            }
            self.state = .paused(partialBytes: currentBytes, totalBytes: self.totalBytes)
        }
    }

    /// 仅删除 .partial 文件，不删除模型目录和正式文件
    func cleanupPartials() {
        let dir = model.localPath
        for file in model.requiredFiles {
            let partial = dir.appendingPathComponent(file).appendingPathExtension("partial")
            try? FileManager.default.removeItem(at: partial)
        }
        DispatchQueue.main.async {
            for key in self.files.keys {
                self.files[key] = .pending
            }
            self.state = .idle
        }
    }

    // MARK: - 顺序下载

    private func downloadSequentially(_ fileInfos: [(path: String, remote: URL, totalSize: Int64)]) {
        let fm = FileManager.default
        let dir = model.localPath
        var remaining: [(path: String, remote: URL, totalSize: Int64)] = []

        // 缓存远端大小到 manager
        ModelDownloadManager.shared.cacheRemoteSizes(for: model.repo, sizes: Dictionary(uniqueKeysWithValues: fileInfos.map { ($0.path, $0.totalSize) }))

        // 跳过已完整存在的文件：有远端大小时严格校验；HEAD 失败时退化为 size > 0。
        for info in fileInfos {
            let local = dir.appendingPathComponent(info.path)
            if fm.fileExists(atPath: local.path),
               let attrs = try? fm.attributesOfItem(atPath: local.path),
               let size = attrs[.size] as? Int64,
               (info.totalSize > 0 ? size == info.totalSize : size > 0) {
                DispatchQueue.main.async { self.files[info.path] = .completed }
                completedBytes += size
            } else {
                remaining.append(info)
            }
        }

        totalBytes = completedBytes + remaining.reduce(Int64(0)) { $0 + $1.totalSize }

        if remaining.isEmpty {
            DispatchQueue.main.async { self.state = .completed }
            return
        }

        downloadNextFile(from: remaining, index: 0)
    }

    private func downloadNextFile(from files: [(path: String, remote: URL, totalSize: Int64)], index: Int) {
        guard index < files.count, !isCancelled else {
            if !isCancelled { checkAllCompleted() }
            return
        }

        let info = files[index]
        let local = model.localPath.appendingPathComponent(info.path)
        let isResuming = FileManager.default.fileExists(atPath: local.appendingPathExtension("partial").path)

        // 确保目录存在
        try? FileManager.default.createDirectory(at: local.deletingLastPathComponent(), withIntermediateDirectories: true)

        DispatchQueue.main.async {
            self.files[info.path] = .downloading(progress: 0, downloadedBytes: 0)
            self.state = .downloading(
                progress: self.totalBytes > 0 ? Double(self.completedBytes) / Double(self.totalBytes) : 0,
                downloadedBytes: self.completedBytes,
                totalBytes: self.totalBytes, speedBps: 0,
                currentFile: info.path, isResuming: isResuming
            )
        }

        let downloader = HTTPRangeFileDownloader(url: info.remote, destination: local)
        currentDownloader = downloader

        downloader.onProgress = { [weak self] progress in
            guard let self = self else { return }
            let fileBytes = Int64(progress * Double(max(info.totalSize, 1)))
            let total = self.completedBytes + fileBytes
            DispatchQueue.main.async {
                self.files[info.path] = .downloading(progress: progress, downloadedBytes: fileBytes)
                self.state = .downloading(
                    progress: self.totalBytes > 0 ? Double(total) / Double(self.totalBytes) : 0,
                    downloadedBytes: total,
                    totalBytes: self.totalBytes,
                    speedBps: Double(self.currentDownloader?.currentSpeed ?? 0),
                    currentFile: info.path, isResuming: isResuming
                )
            }
        }

        downloader.onSpeed = { [weak self] speed in
            guard let self = self else { return }
            let total = self.completedBytes + (self.currentDownloader?.downloadedBytes ?? 0)
            DispatchQueue.main.async {
                self.state = .downloading(
                    progress: self.totalBytes > 0 ? Double(total) / Double(self.totalBytes) : 0,
                    downloadedBytes: total,
                    totalBytes: self.totalBytes, speedBps: Double(speed),
                    currentFile: info.path, isResuming: isResuming
                )
            }
        }

        downloader.onComplete = { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                // 失败：保留错误状态，不破坏正式文件（.partial 由 HTTPRangeFileDownloader 自动保留）
                DispatchQueue.main.async {
                    self.files[info.path] = .failed(error: error.localizedDescription)
                    self.state = .failed(error: error.localizedDescription)
                }
                return
            }

            // 文件下载完成（HTTPRangeFileDownloader 已原子移动 .partial → 正式文件）
            let actualSize = (try? FileManager.default.attributesOfItem(atPath: local.path)[.size] as? Int64) ?? info.totalSize
            self.completedBytes += actualSize
            self.currentDownloader = nil

            DispatchQueue.main.async {
                self.files[info.path] = .completed
                self.downloadNextFile(from: files, index: index + 1)
            }
        }

        downloader.start()
    }

    private func checkAllCompleted() {
        if files.values.allSatisfy({ if case .completed = $0 { true } else { false } }) {
            state = .completed
        }
    }

    // MARK: - HEAD 请求

    /// 构建 HuggingFace 下载 URL
    static func huggingFaceResolveURL(repo: String, path: String) -> URL {
        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        return URL(string: "https://huggingface.co/\(repo)/resolve/main/\(encodedPath)?download=true")!
    }

    /// 并发 HEAD 请求获取所有文件大小
    private func fetchAllFileSizes(completion: @escaping ([(path: String, remote: URL, totalSize: Int64)]) -> Void) {
        let group = DispatchGroup()
        var results: [(path: String, remote: URL, totalSize: Int64)] = []
        let lock = NSLock()

        for file in model.requiredFiles {
            group.enter()
            let remote = Self.huggingFaceResolveURL(repo: model.repo, path: file)
            var request = URLRequest(url: remote)
            request.httpMethod = "HEAD"
            request.timeoutInterval = 30

            URLSession.shared.dataTask(with: request) { _, response, _ in
                let size: Int64
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200 {
                    size = Int64(httpResponse.expectedContentLength)
                } else {
                    size = 0
                }
                lock.lock()
                results.append((path: file, remote: remote, totalSize: size))
                lock.unlock()
                group.leave()
            }.resume()
        }

        group.notify(queue: .main) {
            completion(results)
        }
    }
}

// MARK: - 全局下载管理器

/// 全局下载管理器（ObservableObject，供 SwiftUI 绑定）
final class ModelDownloadManager: ObservableObject {
    static let shared = ModelDownloadManager()

    /// 所有活跃下载任务（repo -> task）
    @Published private(set) var activeTasks: [String: ModelDownloadTask] = [:]
    /// Combine 订阅（转发 task 状态变更到 manager，驱动 SwiftUI 刷新）
    private var cancellables: [String: AnyCancellable] = [:]
    /// 其他 Combine 订阅
    private var otherCancellables = Set<AnyCancellable>()
    /// 缓存远端文件大小（repo -> [path: Int64]）
    private var remoteSizeCache: [String: [String: Int64]] = [:]

    private init() {}

    enum ModelDeletionError: LocalizedError {
        case selectedModel

        var errorDescription: String? {
            switch self {
            case .selectedModel:
                return "当前正在使用的模型不能删除，请先切换到其他已安装模型。"
            }
        }
    }

    /// 获取已有的下载任务（不创建新任务）
    func task(for model: QwenTTSModel) -> ModelDownloadTask? {
        activeTasks[model.repo]
    }

    /// 开始下载指定模型（创建并启动下载任务）
    @discardableResult
    func startDownload(for model: QwenTTSModel) -> ModelDownloadTask {
        if let existing = activeTasks[model.repo] {
            existing.start()
            return existing
        }
        let task = ModelDownloadTask(model: model)
        // 转发 task 的 objectWillChange → manager → SwiftUI 自动刷新
        cancellables[model.repo] = task.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
        activeTasks[model.repo] = task
        // 下载完成后刷新远端缓存
        task.$state
            .filter { if case .completed = $0 { true } else { false } }
            .first()
            .sink { [weak self] _ in
                self?.remoteSizeCache.removeValue(forKey: model.repo)
            }
            .store(in: &otherCancellables)
        task.start()
        return task
    }

    /// 缓存远端文件大小（由 ModelDownloadTask.fetchAllFileSizes 调用）
    func cacheRemoteSizes(for repo: String, sizes: [String: Int64]) {
        remoteSizeCache[repo] = sizes
    }

    /// 获取模型当前状态（下载状态优先级最高）
    func downloadState(for model: QwenTTSModel) -> ModelDownloadState {
        activeTasks[model.repo]?.state ?? .idle
    }

    /// 获取指定文件的下载状态
    func fileState(for model: QwenTTSModel, file: String) -> FileDownloadState {
        activeTasks[model.repo]?.files[file] ?? .pending
    }

    /// 是否正在下载指定模型
    func isDownloading(_ model: QwenTTSModel) -> Bool {
        activeTasks[model.repo]?.state.isActive ?? false
    }

    /// 格式化字节数
    static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    /// 检测并返回模型缺失的文件列表
    /// 如果有远端大小缓存，则本地文件大小必须等于远端大小才算完整
    /// 如果远端大小未知，退化为 size > 0
    func missingFiles(for model: QwenTTSModel) -> [String] {
        let dir = model.localPath
        let cached = remoteSizeCache[model.repo]
        return model.requiredFiles.filter { file in
            let src = dir.appendingPathComponent(file)
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: src.path),
                  let size = attrs[.size] as? Int64, size > 0 else {
                return true // 文件不存在或大小为 0
            }
            // 如果有远端大小缓存，严格校验
            if let remoteSize = cached?[file], remoteSize > 0 {
                return size != remoteSize
            }
            // 无远端大小，退化为 size > 0（已通过上 guard）
            return false
        }
    }

    /// 检测所有模型安装状态
    func checkAllModels() -> [(model: QwenTTSModel, status: ModelInstallStatus)] {
        ModelCatalog.allModels.map { model in
            (model, checkStatus(for: model))
        }
    }

    /// 检测单个模型的安装状态
    func checkStatus(for model: QwenTTSModel) -> ModelInstallStatus {
        let missing = missingFiles(for: model)
        if missing.isEmpty {
            let totalBytes = model.requiredFiles.reduce(Int64(0)) { sum, file in
                let src = model.localPath.appendingPathComponent(file)
                guard let attrs = try? FileManager.default.attributesOfItem(atPath: src.path),
                      let size = attrs[.size] as? Int64 else { return sum }
                return sum + size
            }
            return .installed(totalBytes: totalBytes)
        } else if missing.count == model.requiredFiles.count {
            return .notDownloaded
        } else {
            return .incomplete(missingFiles: missing)
        }
    }

    /// 清理已完成的下载任务
    func removeCompletedTasks() {
        for (repo, task) in activeTasks {
            if case .completed = task.state {
                activeTasks.removeValue(forKey: repo)
                cancellables.removeValue(forKey: repo)
            }
        }
    }

    /// 删除已安装的模型（删除整个模型目录 + 清理下载任务）
    func deleteModel(_ model: QwenTTSModel) throws {
        let selectedRepo = UserDefaults.standard.string(forKey: "selectedTTSModelRepo")
            ?? "mlx-community/Qwen3-TTS-12Hz-0.6B-Base-bf16"
        guard selectedRepo != model.repo else {
            throw ModelDeletionError.selectedModel
        }

        activeTasks[model.repo]?.cancel()
        let dir = model.localPath
        if FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.removeItem(at: dir)
        }
        activeTasks.removeValue(forKey: model.repo)
        cancellables.removeValue(forKey: model.repo)
        objectWillChange.send()
    }
}

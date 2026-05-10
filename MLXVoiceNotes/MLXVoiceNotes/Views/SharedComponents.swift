import SwiftUI

struct AppPageScaffold<Content: View, Sidebar: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content
    @ViewBuilder var sidebar: Sidebar
    var hideSidebar: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.largeTitle.bold())
                Text(subtitle).foregroundStyle(.secondary)
            }
            HStack(alignment: .top, spacing: 16) {
                ScrollView {
                    content
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                if !hideSidebar {
                    ScrollView {
                        sidebar
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    .frame(minWidth: 220, idealWidth: 280, maxWidth: 300, alignment: .topLeading)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(20)
    }
}

extension AppPageScaffold where Sidebar == EmptyView {
    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
        self.sidebar = EmptyView()
        self.hideSidebar = true
    }
}

struct ActionCard: View {
    let title: String
    let rows: [(String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            ForEach(rows, id: \.0) { row in
                HStack {
                    Text(row.0).foregroundStyle(.secondary)
                    Spacer()
                    Text(row.1).fontWeight(.semibold)
                }
                Divider()
            }
        }
    }
}

struct ReviewRow: View {
    let role: String
    let text: String
    let action: String

    var body: some View {
        HStack(spacing: 12) {
            Text(role)
                .fontWeight(.semibold)
                .frame(width: 72)
            Text(text)
            Spacer()
            Button(action) {}
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct ResourceRow: View {
    let name: String
    let status: String

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(name).fontWeight(.semibold)
                Text(status).foregroundStyle(.secondary)
            }
            Spacer()
            Button(status.contains("失败") ? "重试" : "管理") {}
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// 模型列表行（资源中心-模型 Tab）
struct ModelRow: View {
    let model: QwenTTSModel
    let status: ModelInstallStatus
    let missingFiles: [String]
    let onRefresh: () -> Void
    @AppStorage("selectedTTSModelRepo") private var selectedModelRepo: String = "mlx-community/Qwen3-TTS-12Hz-0.6B-Base-bf16"

    /// 可选的下载任务观察者（传入时启用下载控制）
    var downloadTask: ModelDownloadTask?

    @ObservedObject private var downloadManager = ModelDownloadManager.shared
    @State private var showDeleteConfirmation = false
    @State private var deleteError: String?
    @State private var showDeleteError = false

    private var effectiveDownloadTask: ModelDownloadTask? {
        downloadTask ?? downloadManager.task(for: model)
    }

    private var isCurrentlySelected: Bool {
        status.isInstalled && model.repo == selectedModelRepo
    }

    private var isInstalledAndNotSelected: Bool {
        if case .installed = status { return model.repo != selectedModelRepo }
        return false
    }

    var body: some View {
        HStack(spacing: 12) {
            // 左侧：模型信息
            VStack(alignment: .leading, spacing: 6) {
                // 第一行：名称 + 标签
                HStack(spacing: 8) {
                    Text(model.displayName)
                        .fontWeight(.semibold)
                        .font(.body)

                    // 精度标签
                    precisionBadge

                    // 大小标签
                    sizeBadge

                    // 推荐标签
                    if model.isRecommended {
                        Text("推荐")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15))
                            .foregroundStyle(.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }

                    // 实验标签
                    if model.isExperimental {
                        Text("实验")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .foregroundStyle(.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }

                // 第二行：分类 + 内存建议
                HStack(spacing: 16) {
                    Text(model.category)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(model.memoryHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // 第三行：安装状态
                HStack(spacing: 8) {
                    statusBadge

                    if isCurrentlySelected {
                        Text("当前使用中")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }

                    if case .installed(let bytes) = status {
                        Text(ModelDownloadManager.formatBytes(bytes))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(model.expectedSizeText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // 第四行：缺失文件（仅 incomplete 时显示）
                if case .incomplete = status {
                    let names = missingFiles.prefix(3).joined(separator: ", ")
                    let extra = missingFiles.count > 3 ? " 等" : ""
                    Text("缺失文件: \(names)\(extra)")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            // 右侧：操作按钮占位
            actionButton
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .alert("删除模型", isPresented: $showDeleteConfirmation) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                deleteModel()
            }
        } message: {
            Text("确定要删除「\(model.displayName)」的本地模型文件吗？\n\n删除后需要重新下载才能使用。")
        }
        .alert("删除失败", isPresented: $showDeleteError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(deleteError ?? "未知错误")
        }
    }

    // MARK: - 子组件

    private var precisionBadge: some View {
        let color: Color = {
            switch model.precision {
            case "bf16": return .purple
            case "8bit": return .blue
            case "4bit": return .cyan
            default: return .secondary
            }
        }()
        return Text(model.precision)
            .font(.caption2)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }

    private var sizeBadge: some View {
        let color: Color = model.modelSizeLevel == "1.7B" ? .orange : .green
        return Text(model.modelSizeLevel)
            .font(.caption2)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }

    private var statusBadge: some View {
        let (text, color): (String, Color) = {
            switch status {
            case .installed: return ("已安装", .green)
            case .notDownloaded: return ("未下载", .secondary)
            case .incomplete: return ("文件不完整", .orange)
            case .installing: return ("下载中", .blue)
            case .failed: return ("失败", .red)
            }
        }()
        return Text(text)
            .font(.caption)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var actionButton: some View {
        let task = effectiveDownloadTask
        let downloadState = task?.state ?? .idle

        // 下载进行中/暂停/失败/完成时，操作按钮在面板中显示
        switch downloadState {
        case .preparing, .connecting, .downloading, .paused, .failed, .completed:
            return EmptyView().eraseToAnyView()

        case .idle:
            // 已安装模型
            if isCurrentlySelected {
                return HStack(spacing: 4) {
                    Text("当前使用中")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Button {
                        onRefresh()
                    } label: {
                        Label("重新校验", systemImage: "checkmark.shield")
                    }
                    .controlSize(.small)
                }
                .eraseToAnyView()
            } else if isInstalledAndNotSelected {
                return HStack(spacing: 4) {
                    Button {
                        onRefresh()
                    } label: {
                        Label("重新校验", systemImage: "checkmark.shield")
                    }
                    .controlSize(.small)
                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                    .controlSize(.small)
                    .foregroundStyle(.red)
                    Button {
                        Task {
                            await MLXAudioService.shared.switchToModel(repo: model.repo)
                        }
                    } label: {
                        Label("设为当前", systemImage: "checkmark.circle")
                    }
                    .controlSize(.small)
                    .disabled(GenerationService.currentlyGeneratingScriptID != nil)
                    .help(GenerationService.currentlyGeneratingScriptID != nil ? "生成中不可切换模型" : "")
                }
                .eraseToAnyView()
            } else if case .incomplete = status {
                return HStack(spacing: 4) {
                    Button {
                        downloadManager.startDownload(for: model)
                    } label: {
                        Label("下载模型", systemImage: "arrow.down.circle")
                    }
                    .controlSize(.small)

                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                    .controlSize(.small)
                    .foregroundStyle(.red)
                }
                .eraseToAnyView()
            } else if case .notDownloaded = status {
                return Button {
                    downloadManager.startDownload(for: model)
                } label: {
                    Label("下载模型", systemImage: "arrow.down.circle")
                }
                .controlSize(.small)
                .eraseToAnyView()
            } else {
                return Button {
                    onRefresh()
                } label: {
                    Label("检测", systemImage: "arrow.clockwise")
                }
                .controlSize(.small)
                .eraseToAnyView()
            }
        }
    }

    private func deleteModel() {
        do {
            try downloadManager.deleteModel(model)
            onRefresh()
        } catch {
            deleteError = error.localizedDescription
            showDeleteError = true
        }
    }
}

// MARK: - 模型下载面板

/// 显示详细下载进度的面板（含操作按钮）
struct ModelDownloadPanel: View {
    @ObservedObject var downloadTask: ModelDownloadTask
    var onRefresh: () -> Void = {}

    var body: some View {
        if case .idle = downloadTask.state {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 10) {
                // 标题行 + 状态标签
                HStack {
                    Text("下载进度")
                        .font(.caption.bold())
                    Spacer()
                    stateLabel
                }

                switch downloadTask.state {
                case .preparing:
                    ProgressView("正在获取文件信息...")
                        .controlSize(.small)

                case .connecting(let currentFile, let currentURL):
                    connectingContent(currentFile: currentFile, currentURL: currentURL)

                case .downloading(let progress, let downloadedBytes, let totalBytes, let speedBps, let currentFile, let currentURL, let isResuming):
                    downloadingContent(
                        progress: progress,
                        downloadedBytes: downloadedBytes,
                        totalBytes: totalBytes,
                        speedBps: speedBps,
                        currentFile: currentFile,
                        currentURL: currentURL,
                        isResuming: isResuming
                    )

                case .paused(let partialBytes, let totalBytes):
                    pausedContent(partialBytes: partialBytes, totalBytes: totalBytes)

                case .failed(let error):
                    failedContent(error: error)

                case .completed:
                    completedContent

                case .idle:
                    EmptyView()
                }

                // 操作按钮
                actionButtons
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )
        }
    }

    // MARK: - 下载中内容

    // MARK: - 连接中内容

    @ViewBuilder
    private func connectingContent(currentFile: String, currentURL: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ProgressView()
                .controlSize(.small)

            Text("正在连接...")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Text(truncateFileName(currentFile))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text("下载地址: \(currentURL)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(currentURL)
        }
    }

    // MARK: - 下载中内容

    @ViewBuilder
    private func downloadingContent(progress: Double, downloadedBytes: Int64, totalBytes: Int64, speedBps: Double, currentFile: String, currentURL: String, isResuming: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // 总进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentColor)
                        .frame(width: geometry.size.width * CGFloat(progress), height: 8)
                }
            }
            .frame(height: 8)

            // 详情行
            HStack {
                Text(String(format: "%.1f%%", progress * 100))
                    .font(.caption.monospacedDigit())
                    .frame(width: 44, alignment: .leading)
                Text(formatBytes(downloadedBytes) + " / " + formatBytes(totalBytes))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatSpeed(speedBps))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            // 当前文件 + 续传标签
            HStack(spacing: 6) {
                if isResuming {
                    Text("续传")
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.green.opacity(0.15))
                        .foregroundStyle(.green)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                Text(truncateFileName(currentFile))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            // 下载地址
            Text("下载地址: \(currentURL)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(currentURL)
        }
    }

    // MARK: - 已暂停内容

    @ViewBuilder
    private func pausedContent(partialBytes: Int64, totalBytes: Int64) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("已暂停，可继续下载")
                .font(.caption)
                .foregroundStyle(.orange)
            Text("已下载: " + formatBytes(partialBytes) + " / " + formatBytes(totalBytes))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 失败内容

    @ViewBuilder
    private func failedContent(error: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("下载失败")
                .font(.caption)
                .foregroundStyle(.red)
            Text(error)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    // MARK: - 完成内容

    @ViewBuilder
    private var completedContent: some View {
        Text("下载完成")
            .font(.caption)
            .foregroundStyle(.green)
    }

    // MARK: - 操作按钮

    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 8) {
            switch downloadTask.state {
            case .connecting:
                Button {
                    downloadTask.cancel()
                } label: {
                    Label("暂停", systemImage: "pause.circle")
                }
                .controlSize(.small)
                .foregroundStyle(.orange)

            case .downloading:
                Button {
                    downloadTask.cancel()
                } label: {
                    Label("暂停", systemImage: "pause.circle")
                }
                .controlSize(.small)
                .foregroundStyle(.orange)

            case .paused:
                Button {
                    downloadTask.start()
                } label: {
                    Label("继续下载", systemImage: "arrow.clockwise")
                }
                .controlSize(.small)

                Button {
                    downloadTask.cleanupPartials()
                } label: {
                    Label("清理临时文件", systemImage: "trash")
                }
                .controlSize(.small)
                .foregroundStyle(.orange)

            case .failed:
                Button {
                    downloadTask.start()
                } label: {
                    Label("重试", systemImage: "arrow.clockwise")
                }
                .controlSize(.small)

                Button {
                    downloadTask.cleanupPartials()
                } label: {
                    Label("清理", systemImage: "trash")
                }
                .controlSize(.small)
                .foregroundStyle(.orange)

            case .completed:
                Button {
                    onRefresh()
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .controlSize(.small)

            default:
                EmptyView()
            }
        }
    }

    // MARK: - 状态标签

    @ViewBuilder
    private var stateLabel: some View {
        let (text, color): (String, Color) = {
            switch downloadTask.state {
            case .idle: return ("空闲", .secondary)
            case .preparing: return ("准备中", .blue)
            case .connecting: return ("连接中", .blue)
            case .downloading: return ("下载中", .blue)
            case .paused: return ("已暂停", .orange)
            case .failed: return ("失败", .red)
            case .completed: return ("完成", .green)
            }
        }()
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - 格式化工具

    private func formatBytes(_ bytes: Int64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1.0 { return String(format: "%.2fGB", gb) }
        let mb = Double(bytes) / 1_048_576
        if mb >= 1.0 { return String(format: "%.1fMB", mb) }
        let kb = Double(bytes) / 1_024
        return String(format: "%.0fKB", kb)
    }

    private func formatSpeed(_ bps: Double) -> String {
        if bps <= 0 { return "等待响应..." }
        let mbps = bps / 1_048_576
        if mbps >= 1.0 { return String(format: "%.1f MB/s", mbps) }
        let kbps = bps / 1_024
        return String(format: "%.0f KB/s", kbps)
    }

    private func truncateFileName(_ path: String) -> String {
        let components = path.split(separator: "/")
        if components.count > 2 {
            return ".../" + components.suffix(2).joined(separator: "/")
        }
        return path
    }
}

// MARK: - AnyView 辅助

extension View {
    func eraseToAnyView() -> AnyView {
        AnyView(self)
    }
}

/// 旧版模型状态（兼容旧代码）
enum LegacyModelStatus: Equatable {
    case available
    case missing
    case error
    case incomplete

    var statusSummary: String {
        switch self {
        case .available:
            return "已安装"
        case .missing:
            return "模型文件下载目录不存在"
        case .error:
            return "未知错误"
        case .incomplete:
            return "不完整 / 缺少文件"
        }
    }
}

/// 旧版模型状态行（兼容旧代码）
struct ModelStatusRow: View {
    let status: LegacyModelStatus
    let missingFiles: [String]
    let onRefresh: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Qwen3-TTS 0.6B Base bf16")
                    .fontWeight(.semibold)
                    .font(.body)

                Text(status.statusSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if case .incomplete = status {
                    let names = missingFiles.prefix(3).joined(separator: ", ")
                    let extra = missingFiles.count > 3 ? " 等" : ""
                    Text("缺失文件: \(names)\(extra)")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            if case .incomplete = status {
                Button("重新检测") {
                    onRefresh()
                }
                .controlSize(.small)
            } else {
                Text("-")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct QueueCard: View {
    let title: String
    let detail: String
    let active: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).fontWeight(.semibold)
            Text(detail).foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(active ? Color.accentColor.opacity(0.12) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct SegmentRow: Identifiable {
    let id = UUID()
    let segment: ScriptSegment
    let index: String
    let role: String
    let voice: String
    let status: String
    let text: String
    let action: String
}

struct SegmentQueueRow: View {
    let row: SegmentRow
    let onRetry: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(row.index)
                .frame(width: 36, alignment: .leading)
            Text(row.role)
                .fontWeight(.semibold)
                .frame(width: 60, alignment: .leading)
            Text(row.voice)
                .lineLimit(1)
                .frame(minWidth: 80, maxWidth: 140, alignment: .leading)
            Text(row.status)
                .frame(width: 56, alignment: .leading)
                .foregroundStyle(statusColor)
            Text(row.text)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(row.action) {
                if row.segment.status == .failed {
                    onRetry()
                }
            }
            .frame(width: 56, alignment: .trailing)
            .disabled(row.segment.status != .failed)
        }
        .font(.callout)
        .padding(8)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var statusColor: Color {
        switch row.segment.status {
        case .completed: .green
        case .generating: .blue
        case .failed: .red
        case .pending, .skipped: .secondary
        }
    }
}

struct ScriptListRow: View {
    let script: Script

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 4) {
            GridRow {
                VStack(alignment: .leading) {
                    Text(script.title).fontWeight(.semibold)
                    Text("修改 \(script.updatedAt.relativeLabel)")
                        .foregroundStyle(.secondary)
                }
                Text(script.status.displayName)
                Text("\(script.roles.count) / \(script.segments.count)")
                Text(script.updatedAt.relativeLabel)
                Text(script.lastExportedAt?.relativeLabel ?? "未导出")
            }
        }
        .padding(.vertical, 6)
    }
}

struct StatusBadge: View {
    let status: ScriptStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(status.foregroundColor)
            .background(status.backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

extension ScriptStatus {
    var displayName: String {
        switch self {
        case .draft: "草稿"
        case .ready: "待生成"
        case .generating: "生成中"
        case .completed: "已生成"
        case .failed: "有失败"
        }
    }

    var foregroundColor: Color {
        switch self {
        case .completed: .green
        case .generating: .blue
        case .failed: .red
        case .ready, .draft: .secondary
        }
    }

    var backgroundColor: Color {
        switch self {
        case .completed: Color.green.opacity(0.12)
        case .generating: Color.blue.opacity(0.12)
        case .failed: Color.red.opacity(0.12)
        case .ready, .draft: Color.secondary.opacity(0.1)
        }
    }
}

extension SegmentStatus {
    var displayName: String {
        switch self {
        case .pending: "等待"
        case .generating: "生成中"
        case .completed: "完成"
        case .failed: "失败"
        case .skipped: "已跳过"
        }
    }
}

extension Date {
    var relativeLabel: String {
        if Calendar.current.isDateInToday(self) {
            return "今天 " + Self.timeFormatter.string(from: self)
        }
        if Calendar.current.isDateInYesterday(self) {
            return "昨天 " + Self.timeFormatter.string(from: self)
        }
        return Self.dateFormatter.string(from: self)
    }

    var fileStamp: String {
        Self.fileStampFormatter.string(from: self)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

    private static let fileStampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()
}

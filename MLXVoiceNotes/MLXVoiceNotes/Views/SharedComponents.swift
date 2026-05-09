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
                        Text(ModelDownloadService.formatBytes(bytes))
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
        if isCurrentlySelected {
            return Button("当前使用中") {}
                .controlSize(.small)
                .disabled(true)
                .eraseToAnyView()
        } else if isInstalledAndNotSelected {
            return Button("设为当前模型") {
                Task {
                    await MLXAudioService.shared.switchToModel(repo: model.repo)
                }
            }
            .controlSize(.small)
            .eraseToAnyView()
        } else if case .incomplete = status {
            return Button("重新检测") {
                onRefresh()
            }
            .controlSize(.small)
            .eraseToAnyView()
        } else {
            return Text("-")
                .foregroundStyle(.secondary)
                .eraseToAnyView()
        }
    }
}

// MARK: - AnyView 辅助

extension View {
    func eraseToAnyView() -> AnyView {
        AnyView(self)
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

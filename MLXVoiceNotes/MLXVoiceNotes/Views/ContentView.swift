import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Script.updatedAt, order: .reverse) private var scripts: [Script]
    @State private var selectedPage: AppPage = .scriptLibrary
    @State private var selectedScriptID: UUID?

    var selectedScript: Script? {
        scripts.first { $0.id == selectedScriptID } ?? scripts.first
    }

    var body: some View {
        NavigationSplitView {
            List(AppPage.allCases, selection: $selectedPage) { page in
                Label(page.title, systemImage: page.systemImage)
                    .tag(page)
            }
            .navigationTitle("MLX Voice Notes")
            .frame(minWidth: 220)
        } detail: {
            detailView
                .frame(minWidth: 860, minHeight: 620)
        }
        .onAppear {
            seedSampleScriptsIfNeeded()
            selectedScriptID = selectedScriptID ?? scripts.first?.id
        }
        .onChange(of: scripts.map(\.id)) { _, scriptIDs in
            if selectedScriptID == nil || !scriptIDs.contains(selectedScriptID!) {
                selectedScriptID = scriptIDs.first
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedPage {
        case .scriptLibrary:
            ScriptLibraryView(scripts: scripts, selectedScriptID: $selectedScriptID)
        case .workbench:
            WorkbenchView(scripts: scripts, selectedScriptID: $selectedScriptID)
        case .roleReview:
            RoleReviewView(script: selectedScript)
        case .resources:
            ResourceCenterView()
        case .taskQueue:
            TaskQueueView(script: selectedScript)
        case .exportSettings:
            ExportSettingsView(script: selectedScript)
        }
    }

    private func seedSampleScriptsIfNeeded() {
        guard scripts.isEmpty else { return }

        let now = Date()
        let samples = [
            Script(
                title: "平台规则吐槽",
                subtitle: "短视频口播",
                bodyText: """
                [旁白] 你永远都搞不清楚这些平台到底要什么，不要什么。
                [博主] 有时候一条视频，花几个小时做出来，发到 A 平台正常通过。
                [博主] 发到 B 平台，直接限流，有的还给你封号。
                [旁白] 所以做内容不能只看播放量，还要看平台规则和账号风险。
                """,
                status: .completed,
                createdAt: now.addingTimeInterval(-7_200),
                updatedAt: now.addingTimeInterval(-1_200),
                lastExportedAt: now.addingTimeInterval(-600),
                segments: [
                    ScriptSegment(order: 1, text: "你永远都搞不清楚这些平台到底要什么，不要什么。", roleName: "旁白", status: .completed, selectedVersion: 2),
                    ScriptSegment(order: 2, text: "有时候一条视频，花几个小时做出来，发到 A 平台正常通过。", roleName: "博主", status: .generating),
                    ScriptSegment(order: 3, text: "发到 B 平台，直接限流，有的还给你封号。", roleName: "博主"),
                    ScriptSegment(order: 4, text: "所以做内容不能只看播放量，还要看平台规则和账号风险。", roleName: "旁白")
                ],
                roles: [
                    VoiceRole(name: "旁白", normalizedName: "旁白", defaultVoiceName: "默认清晰女声"),
                    VoiceRole(name: "博主", normalizedName: "博主", defaultVoiceName: "vanselee 参考音色", speed: 1.05)
                ]
            ),
            Script(
                title: "直播间脚本",
                subtitle: "老板 · 客服 · 旁白",
                bodyText: "[旁白] 直播开始前先确认优惠、库存和客服话术。",
                status: .generating,
                createdAt: now.addingTimeInterval(-172_800),
                updatedAt: now.addingTimeInterval(-68_400),
                segments: [
                    ScriptSegment(order: 1, text: "直播开始前先确认优惠、库存和客服话术。", roleName: "旁白", status: .generating)
                ],
                roles: [
                    VoiceRole(name: "老板", normalizedName: "老板", defaultVoiceName: "自然男声"),
                    VoiceRole(name: "客服", normalizedName: "客服", defaultVoiceName: "默认清晰女声"),
                    VoiceRole(name: "旁白", normalizedName: "旁白", defaultVoiceName: "默认清晰女声")
                ]
            ),
            Script(
                title: "短视频开头库",
                subtitle: "开场白集合",
                bodyText: "[旁白] 这类视频开头一定要先讲结果，再讲过程。",
                createdAt: now.addingTimeInterval(-950_400),
                updatedAt: now.addingTimeInterval(-86_400)
            )
        ]

        samples.forEach(modelContext.insert)
        selectedScriptID = samples.first?.id
    }
}

private enum AppPage: String, CaseIterable, Identifiable {
    case scriptLibrary
    case workbench
    case roleReview
    case resources
    case taskQueue
    case exportSettings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .scriptLibrary: "文案库"
        case .workbench: "配音工作台"
        case .roleReview: "角色确认"
        case .resources: "资源中心"
        case .taskQueue: "任务队列"
        case .exportSettings: "导出与设置"
        }
    }

    var systemImage: String {
        switch self {
        case .scriptLibrary: "doc.text"
        case .workbench: "waveform"
        case .roleReview: "person.2"
        case .resources: "externaldrive"
        case .taskQueue: "list.bullet.rectangle"
        case .exportSettings: "square.and.arrow.up"
        }
    }
}

private struct ScriptLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    let scripts: [Script]
    @Binding var selectedScriptID: UUID?

    private var selectedScript: Script? {
        scripts.first { $0.id == selectedScriptID } ?? scripts.first
    }

    var body: some View {
        AppPageScaffold(title: "文案库", subtitle: "管理所有配音文案、生成状态和导出记录。") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("默认按最近修改排序")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("新建文案") {
                        createScript()
                    }
                    .buttonStyle(.borderedProminent)
                }

                List(selection: $selectedScriptID) {
                    ForEach(scripts) { script in
                        ScriptListRow(script: script)
                            .tag(script.id)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        } sidebar: {
            if let selectedScript {
                ActionCard(title: "选中文案详情", rows: [
                    ("标题", selectedScript.title),
                    ("创建时间", selectedScript.createdAt.relativeLabel),
                    ("修改时间", selectedScript.updatedAt.relativeLabel),
                    ("字数", "\(selectedScript.bodyText.count) 字"),
                    ("角色/段落", "\(selectedScript.roles.count) / \(selectedScript.segments.count)"),
                    ("最近导出", selectedScript.lastExportedAt?.relativeLabel ?? "未导出")
                ])
            } else {
                ContentUnavailableView("暂无文案", systemImage: "doc.text")
            }
        }
    }

    private func createScript() {
        let script = Script(
            title: "未命名文案",
            subtitle: "新建配音文案",
            bodyText: "[旁白] 在这里输入要配音的文案。",
            updatedAt: .now,
            segments: [
                ScriptSegment(order: 1, text: "在这里输入要配音的文案。", roleName: "旁白")
            ],
            roles: [
                VoiceRole(name: "旁白", normalizedName: "旁白", defaultVoiceName: "默认清晰女声")
            ]
        )
        modelContext.insert(script)
        selectedScriptID = script.id
    }
}

private struct ScriptListRow: View {
    let script: Script

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 4) {
            GridRow {
                VStack(alignment: .leading) {
                    Text(script.title).fontWeight(.semibold)
                    Text(script.subtitle.isEmpty ? "无副标题" : script.subtitle)
                        .foregroundStyle(.secondary)
                }
                StatusBadge(status: script.status)
                Text("\(script.roles.count) / \(script.segments.count)")
                Text(script.updatedAt.relativeLabel)
                Text(script.lastExportedAt?.relativeLabel ?? "未导出")
            }
        }
        .padding(.vertical, 6)
    }
}

private struct WorkbenchView: View {
    @Environment(\.modelContext) private var modelContext
    let scripts: [Script]
    @Binding var selectedScriptID: UUID?

    private var selectedScript: Script? {
        scripts.first { $0.id == selectedScriptID } ?? scripts.first
    }

    var body: some View {
        AppPageScaffold(title: "配音工作台", subtitle: "输入文案、确认角色音色，然后生成完整成品音频。") {
            if let selectedScript {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("当前文案", selection: currentScriptBinding) {
                        ForEach(scripts) { script in
                            Text(script.title).tag(Optional(script.id))
                        }
                    }
                    .pickerStyle(.menu)

                    TextField("标题", text: binding(for: selectedScript, keyPath: \.title))
                        .textFieldStyle(.roundedBorder)

                    TextField("副标题", text: binding(for: selectedScript, keyPath: \.subtitle))
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        Button("新建") {
                            createScript()
                        }
                        Button("一键粘贴") {
                            pasteClipboard(into: selectedScript)
                        }
                        Button("AI 文案整理提示词") {}
                        Spacer()
                        Button("生成整篇") {}
                            .buttonStyle(.borderedProminent)
                    }

                    TextEditor(text: binding(for: selectedScript, keyPath: \.bodyText))
                        .font(.body.monospaced())
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(.background)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            } else {
                ContentUnavailableView {
                    Label("暂无文案", systemImage: "doc.text")
                } description: {
                    Text("先新建一篇配音文案。")
                } actions: {
                    Button("新建文案") {
                        createScript()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        } sidebar: {
            if let selectedScript {
                ActionCard(title: "当前文案", rows: [
                    ("状态", selectedScript.status.displayName),
                    ("角色", "\(selectedScript.roles.count)"),
                    ("段落", "\(selectedScript.segments.count)"),
                    ("修改时间", selectedScript.updatedAt.relativeLabel),
                    ("输出", "完整 WAV")
                ])
            }
        }
    }

    private var currentScriptBinding: Binding<UUID?> {
        Binding(
            get: { selectedScript?.id },
            set: { selectedScriptID = $0 }
        )
    }

    private func binding(for script: Script, keyPath: ReferenceWritableKeyPath<Script, String>) -> Binding<String> {
        Binding {
            script[keyPath: keyPath]
        } set: { value in
            script[keyPath: keyPath] = value
            script.updatedAt = .now
            script.status = .draft
        }
    }

    private func createScript() {
        let script = Script(
            title: "未命名文案",
            subtitle: "新建配音文案",
            bodyText: "[旁白] 在这里输入要配音的文案。",
            updatedAt: .now,
            segments: [
                ScriptSegment(order: 1, text: "在这里输入要配音的文案。", roleName: "旁白")
            ],
            roles: [
                VoiceRole(name: "旁白", normalizedName: "旁白", defaultVoiceName: "默认清晰女声")
            ]
        )
        modelContext.insert(script)
        selectedScriptID = script.id
    }

    private func pasteClipboard(into script: Script) {
        #if os(macOS)
        guard let clipboardText = NSPasteboard.general.string(forType: .string),
              !clipboardText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return
        }
        script.bodyText = clipboardText
        script.updatedAt = .now
        script.status = .draft
        #endif
    }
}

private struct RoleReviewView: View {
    let script: Script?

    var body: some View {
        AppPageScaffold(title: "角色确认", subtitle: "批量处理候选角色、相似名和未标记文本。") {
            if let script, !script.segments.isEmpty {
                VStack(spacing: 10) {
                    ForEach(script.segments.sorted { $0.order < $1.order }) { segment in
                        ReviewRow(role: segment.roleName, text: segment.text, action: segment.status == .failed ? "重生成" : "试听")
                    }
                }
            } else {
                ContentUnavailableView("暂无段落", systemImage: "text.badge.checkmark")
            }
        } sidebar: {
            ActionCard(title: "确认结果", rows: [
                ("候选角色", "\(script?.roles.count ?? 0)"),
                ("相似名", "0 组"),
                ("未标记", "0 段")
            ])
        }
    }
}

private struct ResourceCenterView: View {
    var body: some View {
        AppPageScaffold(title: "资源中心", subtitle: "模型下载、音色库和缓存管理。") {
            VStack(spacing: 10) {
                ResourceRow(name: "Qwen3-TTS 0.6B Base bf16", status: "已安装 · 推荐 8GB 以上统一内存")
                ResourceRow(name: "Qwen3-TTS 0.6B Base 8bit", status: "下载中 · 42%")
                ResourceRow(name: "Qwen3-TTS 1.7B Base", status: "下载失败 · 可重试")
            }
        } sidebar: {
            ActionCard(title: "缓存", rows: [
                ("模型占用", "1.4GB"),
                ("缓存上限", "20GB"),
                ("下载状态", "支持断点续传")
            ])
        }
    }
}

private struct TaskQueueView: View {
    let script: Script?

    var body: some View {
        AppPageScaffold(title: "任务队列", subtitle: "主队列以文案为单位；详情区展示当前文案的段落队列。") {
            VStack(alignment: .leading, spacing: 12) {
                Text(queueSummary)
                    .font(.headline)
                ProgressView(value: queueProgress)
                Table(segmentRows) {
                    TableColumn("段落", value: \.index)
                    TableColumn("角色", value: \.role)
                    TableColumn("音色", value: \.voice)
                    TableColumn("状态", value: \.status)
                    TableColumn("操作", value: \.action)
                }
                .frame(minHeight: 320)
            }
        } sidebar: {
            VStack(alignment: .leading, spacing: 10) {
                Text("文案任务").font(.headline)
                if let script {
                    QueueCard(title: script.title, detail: "\(script.segments.count) 段 · 完成 \(completedCount) · 失败 \(failedCount)", active: true)
                } else {
                    Text("暂无任务").foregroundStyle(.secondary)
                }
            }
        }
    }

    private var completedCount: Int {
        script?.segments.filter { $0.status == .completed }.count ?? 0
    }

    private var failedCount: Int {
        script?.segments.filter { $0.status == .failed }.count ?? 0
    }

    private var queueProgress: Double {
        guard let script, !script.segments.isEmpty else { return 0 }
        return Double(completedCount) / Double(script.segments.count)
    }

    private var queueSummary: String {
        guard let script else { return "暂无文案任务" }
        return "\(script.title) · \(script.segments.count) 段 · 已完成 \(completedCount) 段 · 失败 \(failedCount) 段；最终只导出整篇完整音频。"
    }

    private var segmentRows: [SegmentRow] {
        guard let script else { return [] }
        return script.segments.sorted { $0.order < $1.order }.map { segment in
            SegmentRow(
                index: String(format: "%02d", segment.order),
                role: segment.roleName,
                voice: script.roles.first { $0.normalizedName == segment.roleName }?.defaultVoiceName ?? "默认旁白",
                status: segment.status.displayName,
                action: segment.status == .failed ? "重试" : "试听"
            )
        }
    }
}

private struct ExportSettingsView: View {
    let script: Script?

    var body: some View {
        AppPageScaffold(title: "导出与设置", subtitle: "导出完整成品音频，首次默认 Downloads。") {
            VStack(spacing: 12) {
                ActionCard(title: "导出预览", rows: [
                    ("文件名", "\(safeFileName).wav"),
                    ("规格", "完整 WAV · 24kHz · mono"),
                    ("字幕", "句子级 SRT · UTF-8"),
                    ("音频文件", "仅完整成品")
                ])
                HStack {
                    Button("导出 WAV") {}
                        .buttonStyle(.borderedProminent)
                    Button("打开文件夹") {}
                    Button("复制路径") {}
                    Spacer()
                }
            }
        } sidebar: {
            ActionCard(title: "应用设置", rows: [
                ("界面语言", "跟随系统"),
                ("缓存上限", "20GB"),
                ("自动更新", "MVP 不启用")
            ])
        }
    }

    private var safeFileName: String {
        let title = script?.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title?.isEmpty == false ? "\(title!)_\(Date.now.fileStamp)" : "未命名文案_\(Date.now.fileStamp)"
    }
}

private struct AppPageScaffold<Content: View, Sidebar: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content
    @ViewBuilder var sidebar: Sidebar

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.largeTitle.bold())
                Text(subtitle).foregroundStyle(.secondary)
            }
            HStack(alignment: .top, spacing: 16) {
                content
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                sidebar
                    .padding()
                    .frame(width: 280, alignment: .topLeading)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(20)
    }
}

private struct StatusBadge: View {
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

private struct ActionCard: View {
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

private struct ReviewRow: View {
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

private struct ResourceRow: View {
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

private struct QueueCard: View {
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

private struct SegmentRow: Identifiable {
    let id = UUID()
    let index: String
    let role: String
    let voice: String
    let status: String
    let action: String
}

private extension ScriptStatus {
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

private extension SegmentStatus {
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

private extension Date {
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

#Preview {
    ContentView()
        .modelContainer(for: [
            Script.self,
            ScriptSegment.self,
            VoiceRole.self,
            VoiceProfile.self,
            GenerationJob.self,
            ExportRecord.self
        ], inMemory: true)
}

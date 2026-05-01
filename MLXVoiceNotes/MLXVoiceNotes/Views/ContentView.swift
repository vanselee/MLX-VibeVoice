import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Script.createdAt, order: .reverse) private var scripts: [Script]
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
        .onReceive(Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()) { _ in
            GenerationService.advanceOneTick(in: scripts)
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedPage {
        case .scriptLibrary:
            ScriptLibraryView(scripts: scripts, selectedScriptID: $selectedScriptID, selectedPage: $selectedPage)
        case .roleReview:
            RoleReviewView(script: selectedScript)
        case .resources:
            ResourceCenterView()
        case .taskQueue:
            TaskQueueView(scripts: scripts, selectedScriptID: $selectedScriptID)
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
    case roleReview
    case resources
    case taskQueue
    case exportSettings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .scriptLibrary: return "文案库"
        case .roleReview: return "角色确认"
        case .resources: return "资源中心"
        case .taskQueue: return "任务队列"
        case .exportSettings: return "导出与设置"
        }
    }

    var systemImage: String {
        switch self {
        case .scriptLibrary: return "doc.text"
        case .roleReview: return "person.2"
        case .resources: return "externaldrive"
        case .taskQueue: return "list.bullet.rectangle"
        case .exportSettings: return "square.and.arrow.up"
        }
    }
}

private struct ScriptLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    let scripts: [Script]
    @Binding var selectedScriptID: UUID?
    @Binding var selectedPage: AppPage
    @State private var expandedScriptID: UUID?
    @State private var deleteCandidate: Script?
    @State private var parseSummary = "等待解析"

    private var selectedScript: Script? {
        scripts.first { $0.id == selectedScriptID } ?? scripts.first
    }

    var body: some View {
        AppPageScaffold(title: "文案工作区", subtitle: "管理文案列表，点击文案即可展开编辑并生成音频。") {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("按创建时间排序")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("新建文案") {
                        createScript()
                    }
                    .buttonStyle(.borderedProminent)
                }

                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(scripts) { script in
                            scriptRow(for: script)
                        }
                    }
                    .padding(.vertical, 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .alert("删除文案？", isPresented: deleteAlertBinding) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    deleteSelectedCandidate()
                }
            } message: {
                Text("删除后会移除这篇文案及其段落、角色绑定和生成状态。")
            }
        } sidebar: {
            if let selectedScript {
                scriptDetailPanel(for: selectedScript)
            } else {
                ContentUnavailableView("暂无文案", systemImage: "doc.text")
            }
        }
    }

    @ViewBuilder
    private func scriptRow(for script: Script) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // 第一行：标题 + 状态
            HStack(spacing: 12) {
                Button {
                    openEditor(for: script)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(script.title)
                            .fontWeight(.semibold)
                        Text("修改 \(script.updatedAt.relativeLabel) · \(script.roles.count) 角色 / \(script.segments.count) 段")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)

                StatusBadge(status: script.status)

                if script.status == .generating {
                    ProgressView(value: generationProgress(for: script))
                        .frame(width: 120)
                }
            }

            // 第二行：操作按钮（展开时显示保存，否则显示编辑）
            HStack(spacing: 8) {
                Button(expandedScriptID == script.id ? "保存" : "编辑") {
                    if expandedScriptID == script.id {
                        saveAndCollapse(script)
                    } else {
                        openEditor(for: script)
                    }
                }

                Button("生成音频") {
                    startPlaceholderGeneration(for: script)
                }
                .buttonStyle(.borderedProminent)
                .disabled(script.status == .generating)

                Button("删除", role: .destructive) {
                    deleteCandidate = script
                }
                .disabled(script.status == .generating)

                Spacer()
            }

            if expandedScriptID == script.id {
                currentScriptEditor(for: script)
                    .padding(12)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(script.id == selectedScriptID ? Color.accentColor.opacity(0.12) : Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onTapGesture {
            selectedScriptID = script.id
        }
    }

    private let availableVoices = ["默认清晰女声", "自然男声", "vanselee 参考音色", "默认旁白"]

    @ViewBuilder
    private func currentScriptEditor(for script: Script) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("编辑文案")
                    .font(.headline)
                StatusBadge(status: script.status)
                if script.status == .generating {
                    ProgressView(value: generationProgress(for: script))
                        .frame(width: 160)
                }
                Spacer()
                Button("保存") {
                    saveAndCollapse(script)
                }
            }

            TextField("标题", text: binding(for: script, keyPath: \.title))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: .infinity)

            HStack {
                Button("一键粘贴") {
                    pasteClipboard(into: script)
                }
                Button("AI 文案整理提示词") {}
                Button("解析角色") {
                    parseRolesAndSegments(for: script)
                }
                Spacer()
                if script.status == .generating {
                    Button("查看任务队列") {
                        selectedPage = .taskQueue
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !script.roles.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("角色音色绑定")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(script.roles.sorted { $0.normalizedName < $1.normalizedName }) { role in
                        VStack(alignment: .leading, spacing: 6) {
                            // 第一行：角色名 + 音色选择
                            HStack(spacing: 10) {
                                Text(role.name)
                                    .fontWeight(.medium)
                                    .frame(width: 70, alignment: .leading)
                                Picker("音色", selection: Binding(
                                    get: { role.defaultVoiceName },
                                    set: { role.defaultVoiceName = $0; script.updatedAt = .now }
                                )) {
                                    ForEach(availableVoices, id: \.self) { voice in
                                        Text(voice).tag(voice)
                                    }
                                }
                                .labelsHidden()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                Spacer(minLength: 0)
                            }

                            // 第二行：语速 + 试听
                            HStack(spacing: 10) {
                                Text("语速")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Slider(value: Binding(
                                    get: { role.speed },
                                    set: { role.speed = $0; script.updatedAt = .now }
                                ), in: 0.75...1.5)
                                Text("\(role.speed.formatted(.number.precision(.fractionLength(2))))x")
                                    .font(.caption)
                                    .frame(width: 36)
                                Button("试听") {}
                                    .font(.caption)
                                    .buttonStyle(.bordered)
                                Spacer(minLength: 0)
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }

            if script.status == .completed {
                HStack {
                    Label("生成完成", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(progressLabel(for: script))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("导出 WAV") {
                        exportWAV(for: script)
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if script.status == .generating {
                HStack {
                    Label("生成中", systemImage: "waveform")
                        .foregroundStyle(.blue)
                    Text(progressLabel(for: script))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("查看任务队列") {
                        selectedPage = .taskQueue
                    }
                }
            }

            TextEditor(text: binding(for: script, keyPath: \.bodyText))
                .font(.body.monospaced())
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(minHeight: 220)
                .frame(maxWidth: .infinity)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.8), lineWidth: 1)
                )

            HStack(spacing: 12) {
                Label(parseSummary, systemImage: "text.badge.checkmark")
                Text("\(script.roles.count) 角色")
                Text("\(script.segments.count) 段")
                Spacer()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func createScript() {
        if let reusableDraft = scripts.first(where: isReusableBlankDraft) {
            openEditor(for: reusableDraft)
            parseSummary = "继续编辑空白草稿"
            return
        }

        let script = Script(
            title: "未命名文案",
            subtitle: "",
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
        openEditor(for: script)
        parseSummary = "等待解析"
    }

    private func openEditor(for script: Script) {
        selectedScriptID = script.id
        expandedScriptID = script.id
    }

    private func saveAndCollapse(_ script: Script) {
        script.updatedAt = .now
        expandedScriptID = nil
    }

    private var deleteAlertBinding: Binding<Bool> {
        Binding {
            deleteCandidate != nil
        } set: { isPresented in
            if !isPresented {
                deleteCandidate = nil
            }
        }
    }

    private func deleteSelectedCandidate() {
        guard let script = deleteCandidate else { return }
        if selectedScriptID == script.id {
            selectedScriptID = scripts.first { $0.id != script.id }?.id
        }
        if expandedScriptID == script.id {
            expandedScriptID = nil
        }
        modelContext.delete(script)
        deleteCandidate = nil
    }

    private func isReusableBlankDraft(_ script: Script) -> Bool {
        let trimmedBody = script.bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        return script.status == .draft &&
            script.title == "未命名文案" &&
            (trimmedBody.isEmpty || trimmedBody == "[旁白] 在这里输入要配音的文案。") &&
            script.lastExportedAt == nil
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
        parseSummary = "已粘贴，等待解析"
        #endif
    }

    private func parseRolesAndSegments(for script: Script) {
        let parsedScript = ScriptParser.parse(script.bodyText)

        let oldSegments = script.segments
        let oldRoles = script.roles
        script.segments.removeAll()
        script.roles.removeAll()
        oldSegments.forEach(modelContext.delete)
        oldRoles.forEach(modelContext.delete)

        for parsedRole in parsedScript.roles {
            let role = VoiceRole(
                name: parsedRole.name,
                normalizedName: parsedRole.normalizedName,
                defaultVoiceName: defaultVoiceName(for: parsedRole.normalizedName),
                script: script
            )
            modelContext.insert(role)
            script.roles.append(role)
        }

        for parsedSegment in parsedScript.segments {
            let segment = ScriptSegment(
                order: parsedSegment.order,
                text: parsedSegment.text,
                roleName: parsedSegment.roleName,
                script: script
            )
            modelContext.insert(segment)
            script.segments.append(segment)
        }

        script.status = .ready
        script.updatedAt = .now
        parseSummary = "\(parsedScript.roles.count) 角色 / \(parsedScript.segments.count) 段"
        if parsedScript.unmarkedSegmentCount > 0 {
            parseSummary += "，\(parsedScript.unmarkedSegmentCount) 段旁白兜底"
        }
    }

    private func startPlaceholderGeneration(for script: Script) {
        if script.segments.isEmpty || script.roles.isEmpty {
            parseRolesAndSegments(for: script)
        }

        guard !script.segments.isEmpty else { return }

        GenerationService.start(script: script)
        parseSummary = "已开始生成"

        let job = GenerationJob(
            scriptTitle: script.title,
            totalSegments: script.segments.count,
            status: .generating
        )
        modelContext.insert(job)
        selectedScriptID = script.id
    }

    private func defaultVoiceName(for roleName: String) -> String {
        if roleName == "旁白" {
            return "默认清晰女声"
        }
        if roleName.contains("男") || roleName.contains("博主") || roleName.contains("老板") {
            return "自然男声"
        }
        return "默认清晰女声"
    }

    private func exportWAV(for script: Script) {
        let safeName = (script.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "未命名文案" : script.title)
        let fileName = "\(safeName)_\(Date().fileStamp)"
        do {
            _ = try AudioExportService.exportPlaceholderWAV(for: script, fileName: fileName)
            script.lastExportedAt = .now
            parseSummary = "已导出 WAV"
        } catch {
            parseSummary = "导出失败：\(error.localizedDescription)"
        }
    }

    private func generationProgress(for script: Script) -> Double {
        guard !script.segments.isEmpty else { return 0 }
        return Double(completedCount(for: script)) / Double(script.segments.count)
    }

    private func progressLabel(for script: Script) -> String {
        "\(completedCount(for: script)) / \(script.segments.count) 段"
    }

    private func completedCount(for script: Script) -> Int {
        script.segments.filter { $0.status == .completed }.count
    }

    private func failedCount(for script: Script) -> Int {
        script.segments.filter { $0.status == .failed }.count
    }

    private func scriptDetailPanel(for script: Script) -> some View {
        let total = script.segments.count
        let completed = completedCount(for: script)
        let failed = failedCount(for: script)
        let pending = total - completed - failed

        return VStack(alignment: .leading, spacing: 0) {
            // 基础信息卡片
            ActionCard(title: "选中文案详情", rows: [
                ("标题", script.title),
                ("状态", script.status.displayName),
                ("创建时间", script.createdAt.relativeLabel),
                ("修改时间", script.updatedAt.relativeLabel),
                ("字数", "\(script.bodyText.count) 字"),
                ("角色/段落", "\(script.roles.count) / \(total)"),
                ("最近导出", script.lastExportedAt?.relativeLabel ?? "未导出")
            ])

            // 生成状态区域
            VStack(alignment: .leading, spacing: 10) {
                Divider()
                    .padding(.top, 4)

                Text("生成状态").font(.headline)

                if script.status == .generating {
                    HStack(spacing: 8) {
                        ProgressView(value: total > 0 ? Double(completed) / Double(total) : 0)
                            .frame(height: 6)
                        Text("\(completed)/\(total)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("生成中 · \(pending) 段待生成")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if completed == total && total > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        Text("已完成 · \(total) 段").foregroundStyle(.secondary)
                    }
                    .font(.caption)
                } else if failed > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        Text("\(failed) 段失败").foregroundStyle(.orange)
                    }
                    .font(.caption)
                    Text("\(completed)/\(total) · \(pending) 段待生成")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if completed > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "circle.lefthalf.filled").foregroundStyle(.blue)
                        Text("部分完成 · \(completed)/\(total) 段").foregroundStyle(.secondary)
                    }
                    .font(.caption)
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "circle").foregroundStyle(.secondary)
                        Text("未生成 · \(total) 段待处理").foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }

                // 操作按钮
                HStack(spacing: 8) {
                    if script.status == .generating {
                        Button("暂停") { GenerationService.pause(script: script) }
                        Button("取消") { GenerationService.cancel(script: script) }
                    } else if completed == total && total > 0 {
                        Button("导出 WAV") { exportWAV(for: script) }
                        Button("重新生成") { startPlaceholderGeneration(for: script) }
                    } else if failed > 0 {
                        Button("重试失败") { GenerationService.retryFailedSegments(script: script) }
                        Button("取消") { GenerationService.cancel(script: script) }
                    } else if pending > 0 && completed == 0 && failed == 0 {
                        Button("生成音频") { startPlaceholderGeneration(for: script) }
                    } else if completed > 0 {
                        Button("继续生成") { GenerationService.resume(script: script) }
                        Button("取消") { GenerationService.cancel(script: script) }
                    } else {
                        Button("生成音频") { startPlaceholderGeneration(for: script) }
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.top, 12)

            Spacer()
        }
    }
}

private struct ScriptListRow: View {
    let script: Script

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 4) {
            GridRow {
                VStack(alignment: .leading) {
                    Text(script.title).fontWeight(.semibold)
                    Text("修改 \(script.updatedAt.relativeLabel)")
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

private struct RoleReviewView: View {
    let script: Script?
    private let availableVoices = ["默认清晰女声", "自然男声", "vanselee 参考音色", "默认旁白"]

    var body: some View {
        AppPageScaffold(title: "角色确认", subtitle: "确认角色、绑定音色，并检查解析出的段落。") {
            if let script {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("角色音色绑定")
                                .font(.headline)
                            ForEach(script.roles.sorted { $0.normalizedName < $1.normalizedName }) { role in
                                RoleVoiceBindingRow(role: role, availableVoices: availableVoices) {
                                    script.updatedAt = .now
                                }
                            }
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 10) {
                            Text("段落预览")
                                .font(.headline)
                            if script.segments.isEmpty {
                                ContentUnavailableView("暂无段落", systemImage: "text.badge.checkmark")
                            } else {
                                ForEach(script.segments.sorted { $0.order < $1.order }) { segment in
                                    ReviewRow(role: segment.roleName, text: segment.text, action: segment.status == .failed ? "重生成" : "试听")
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            } else {
                ContentUnavailableView("暂无段落", systemImage: "text.badge.checkmark")
            }
        } sidebar: {
            ActionCard(title: "确认结果", rows: [
                ("候选角色", "\(script?.roles.count ?? 0)"),
                ("已绑定音色", "\(script?.roles.filter { !$0.defaultVoiceName.isEmpty }.count ?? 0)"),
                ("相似名", "0 组"),
                ("未标记", "0 段")
            ])
        }
    }
}

private struct RoleVoiceBindingRow: View {
    let role: VoiceRole
    let availableVoices: [String]
    let onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(role.name)
                        .fontWeight(.semibold)
                    Text("\(role.speed.formatted(.number.precision(.fractionLength(2))))x · \(role.volumeDB.formatted(.number.precision(.fractionLength(0)))) dB")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .frame(minWidth: 80, alignment: .leading)

                Picker("音色", selection: voiceBinding) {
                    ForEach(availableVoices, id: \.self) { voice in
                        Text(voice).tag(voice)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 200)

                Spacer()
            }
            HStack(spacing: 12) {
                Slider(value: speedBinding, in: 0.75...1.5) {
                    Text("语速")
                }
                .frame(maxWidth: 160)

                Button("试听") {}
                Spacer()
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var voiceBinding: Binding<String> {
        Binding {
            role.defaultVoiceName
        } set: { value in
            role.defaultVoiceName = value
            onChange()
        }
    }

    private var speedBinding: Binding<Double> {
        Binding {
            role.speed
        } set: { value in
            role.speed = value
            onChange()
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
    let scripts: [Script]
    @Binding var selectedScriptID: UUID?

    private var selectedScript: Script? {
        if let selected = taskScripts.first(where: { $0.id == selectedScriptID }) {
            return selected
        }
        return taskScripts.first
    }

    var body: some View {
        AppPageScaffold(title: "任务队列", subtitle: "主队列以文案为单位；详情区展示当前文案的段落队列。") {
            VStack(alignment: .leading, spacing: 14) {
                Text(queueSummary)
                    .font(.headline)
                ProgressView(value: queueProgress)
                HStack {
                    Button(primaryActionTitle) {
                        resumeSelectedTask()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(primaryActionDisabled)

                    Button("暂停") {
                        pauseSelectedTask()
                    }
                    .disabled(selectedScript?.status != .generating)

                    Button("取消任务") {
                        cancelSelectedTask()
                    }
                    .disabled(selectedScript == nil)

                    Button("重试失败") {
                        retryFailedSegments()
                    }
                    .disabled(failedCount == 0)

                    Spacer()
                }

                VStack(spacing: 8) {
                    HStack {
                        Text("段落").frame(width: 36, alignment: .leading)
                        Text("角色").frame(width: 60, alignment: .leading)
                        Text("音色").frame(minWidth: 80, maxWidth: 140, alignment: .leading)
                        Text("状态").frame(width: 56, alignment: .leading)
                        Text("文本").frame(maxWidth: .infinity, alignment: .leading)
                        Text("操作").frame(width: 56, alignment: .trailing)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                    if segmentRows.isEmpty {
                        ContentUnavailableView("暂无段落任务", systemImage: "list.bullet.rectangle")
                    } else {
                        ForEach(segmentRows) { row in
                            SegmentQueueRow(row: row) {
                                retrySegment(row.segment)
                            }
                        }
                    }
                }
            }
        } sidebar: {
            VStack(alignment: .leading, spacing: 10) {
                Text("文案任务").font(.headline)
                if taskScripts.isEmpty {
                    Text("暂无任务").foregroundStyle(.secondary)
                } else {
                    ForEach(taskScripts) { script in
                        Button {
                            selectedScriptID = script.id
                        } label: {
                            QueueCard(
                                title: script.title,
                                detail: "\(script.status.displayName) · \(script.segments.count) 段 · 完成 \(completedCount(for: script)) · 失败 \(failedCount(for: script))",
                                active: script.id == selectedScript?.id
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var taskScripts: [Script] {
        scripts.filter { script in
            [.ready, .generating, .completed, .failed].contains(script.status)
        }
    }

    private var completedCount: Int {
        selectedScript.map(completedCount(for:)) ?? 0
    }

    private var failedCount: Int {
        selectedScript.map(failedCount(for:)) ?? 0
    }

    private var queueProgress: Double {
        guard let script = selectedScript, !script.segments.isEmpty else { return 0 }
        return Double(completedCount) / Double(script.segments.count)
    }

    private var queueSummary: String {
        guard let script = selectedScript else { return "暂无文案任务" }
        return "\(script.title) · \(script.status.displayName) · \(script.segments.count) 段 · 已完成 \(completedCount) 段 · 失败 \(failedCount) 段；最终只导出整篇完整音频。"
    }

    private var primaryActionTitle: String {
        guard let script = selectedScript else { return "继续生成" }
        return switch script.status {
        case .generating: "自动生成中"
        case .completed: "重新生成"
        case .failed: "重试失败"
        case .draft, .ready: "继续生成"
        }
    }

    private var primaryActionDisabled: Bool {
        selectedScript == nil || selectedScript?.segments.isEmpty == true || selectedScript?.status == .generating
    }

    private var segmentRows: [SegmentRow] {
        guard let script = selectedScript else { return [] }
        return script.segments.sorted { $0.order < $1.order }.map { segment in
            SegmentRow(
                segment: segment,
                index: String(format: "%02d", segment.order),
                role: segment.roleName,
                voice: script.roles.first { $0.normalizedName == segment.roleName }?.defaultVoiceName ?? "默认旁白",
                status: segment.status.displayName,
                text: segment.text,
                action: segment.status == .failed ? "重试" : "试听"
            )
        }
    }

    private func completedCount(for script: Script) -> Int {
        script.segments.filter { $0.status == .completed }.count
    }

    private func failedCount(for script: Script) -> Int {
        script.segments.filter { $0.status == .failed }.count
    }

    private func resumeSelectedTask() {
        guard let script = selectedScript else { return }

        if failedCount(for: script) > 0 {
            retryFailedSegments()
            return
        }

        GenerationService.resume(script: script)
    }

    private func pauseSelectedTask() {
        guard let script = selectedScript else { return }
        GenerationService.pause(script: script)
    }

    private func cancelSelectedTask() {
        guard let script = selectedScript else { return }
        GenerationService.cancel(script: script)
    }

    private func retryFailedSegments() {
        guard let script = selectedScript else { return }
        GenerationService.retryFailedSegments(script: script)
    }

    private func retrySegment(_ segment: ScriptSegment) {
        guard let script = selectedScript else { return }
        GenerationService.retry(segment: segment, in: script)
    }
}

private struct ExportSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    let script: Script?
    @State private var exportStatus = "等待导出"
    @State private var lastExportPath: String?

    var body: some View {
        AppPageScaffold(title: "导出与设置", subtitle: "导出完整成品音频，首次默认 Downloads。") {
            VStack(spacing: 12) {
                ActionCard(title: "导出预览", rows: [
                    ("文件名", "\(safeFileName).wav"),
                    ("规格", "完整 WAV · 24kHz · mono"),
                    ("字幕", "句子级 SRT · UTF-8"),
                    ("音频文件", "仅完整成品"),
                    ("状态", exportStatus),
                    ("最近路径", lastExportPath ?? "尚未导出")
                ])
                HStack {
                    Button("导出 WAV") {
                        exportPlaceholderWAV()
                    }
                        .buttonStyle(.borderedProminent)
                        .disabled(script == nil || script?.status != .completed)
                    Button("打开文件夹") {
                        openExportFolder()
                    }
                    Button("复制路径") {
                        copyLastExportPath()
                    }
                    .disabled(lastExportPath == nil)
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

    private func exportPlaceholderWAV() {
        guard let script else { return }
        guard script.status == .completed else {
            exportStatus = "请先完成整篇生成"
            return
        }

        do {
            let result = try AudioExportService.exportPlaceholderWAV(for: script, fileName: safeFileName)

            script.lastExportedAt = .now
            script.updatedAt = .now
            modelContext.insert(ExportRecord(scriptTitle: script.title, kind: .wav, filePath: result.fileURL.path))
            lastExportPath = result.fileURL.path
            exportStatus = "已导出占位 WAV"
        } catch {
            exportStatus = "导出失败：\(error.localizedDescription)"
        }
    }

    private func openExportFolder() {
        #if os(macOS)
        NSWorkspace.shared.open(AudioExportService.exportDirectory)
        #endif
    }

    private func copyLastExportPath() {
        #if os(macOS)
        guard let lastExportPath else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lastExportPath, forType: .string)
        exportStatus = "已复制路径"
        #endif
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
                ScrollView {
                    content
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))

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
    let segment: ScriptSegment
    let index: String
    let role: String
    let voice: String
    let status: String
    let text: String
    let action: String
}

private struct SegmentQueueRow: View {
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

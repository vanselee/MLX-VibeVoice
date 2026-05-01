import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Script.createdAt, order: .reverse) private var scripts: [Script]
    @Query private var voiceProfiles: [VoiceProfile]
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
            seedSampleVoiceProfilesIfNeeded()
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
            ExportSettingsView()
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

    private func seedSampleVoiceProfilesIfNeeded() {
        guard voiceProfiles.isEmpty else { return }
        VoiceProfile.samples.forEach(modelContext.insert)
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
        case .scriptLibrary: return "文案列表"
        case .roleReview: return "角色确认"
        case .resources: return "资源中心"
        case .taskQueue: return "任务总览"
        case .exportSettings: return "偏好设置"
        }
    }

    var systemImage: String {
        switch self {
        case .scriptLibrary: return "doc.text"
        case .roleReview: return "person.2"
        case .resources: return "externaldrive"
        case .taskQueue: return "list.bullet.rectangle"
        case .exportSettings: return "gearshape"
        }
    }
}

private struct ScriptLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var voiceProfiles: [VoiceProfile]
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
                Button("编辑") {
                    openEditor(for: script)
                }

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

    /// 音色选项：从 VoiceProfile 动态读取（builtIn + available + pendingReview）
    private var availableVoices: [String] {
        let allowedStatuses: Set<VoiceProfileStatus> = [.builtIn, .available, .pendingReview]
        return voiceProfiles
            .filter { allowedStatuses.contains($0.status) }
            .map(\.name)
    }

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

    private var exportDisplayPath: String {
        let dir = AudioExportService.exportDirectory
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = dir.path
        if path.hasPrefix(home) {
            let relative = String(path.dropFirst(home.count))
            return relative
                .replacingOccurrences(of: "/Downloads/MLX Voice Notes Exports", with: "Downloads / MLX Voice Notes Exports")
        }
        return path
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
            // 生成状态区域
            VStack(alignment: .leading, spacing: 10) {
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
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        Button("取消") { GenerationService.cancel(script: script) }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    } else if completed == total && total > 0 {
                        Button("重新生成") { startPlaceholderGeneration(for: script) }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                    } else if failed > 0 {
                        Button("重试失败") { GenerationService.retryFailedSegments(script: script) }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        Button("取消") { GenerationService.cancel(script: script) }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    } else if pending > 0 && completed == 0 && failed == 0 {
                        Button("生成音频") { startPlaceholderGeneration(for: script) }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.regular)
                    } else if completed > 0 {
                        Button("继续生成") { GenerationService.resume(script: script) }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        Button("取消") { GenerationService.cancel(script: script) }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    } else {
                        Button("生成音频") { startPlaceholderGeneration(for: script) }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.regular)
                    }
                }
            }

            // 导出操作区域
            VStack(alignment: .leading, spacing: 10) {
                Divider()
                    .padding(.top, 4)

                Text("导出音频").font(.headline)

                HStack(spacing: 16) {
                    Label("WAV", systemImage: "waveform")
                    Label("24kHz", systemImage: "waveform.path")
                    Label("Mono", systemImage: "speaker.wave.1")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    Image(systemName: "folder")
                    Text(exportDisplayPath)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if script.lastExportedAt != nil {
                    Text("最近导出：\(script.lastExportedAt!.relativeLabel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                let isCompleted = completed == total && total > 0
                HStack(spacing: 8) {
                    Button("导出 WAV") {
                        exportWAV(for: script)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isCompleted)

                    Button("打开文件夹") {
                        #if os(macOS)
                        NSWorkspace.shared.open(AudioExportService.exportDirectory)
                        #endif
                    }
                }

                if !isCompleted {
                    Text("生成完成后可导出")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 12)

            // 文案详情
            VStack(alignment: .leading, spacing: 10) {
                Divider()
                    .padding(.top, 4)

                Text("文案详情").font(.headline)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("标题").foregroundStyle(.secondary)
                        Spacer()
                        Text(script.title).lineLimit(1)
                    }
                    HStack {
                        Text("状态").foregroundStyle(.secondary)
                        Spacer()
                        Text(script.status.displayName)
                    }
                    HStack {
                        Text("创建时间").foregroundStyle(.secondary)
                        Spacer()
                        Text(script.createdAt.relativeLabel)
                    }
                    HStack {
                        Text("修改时间").foregroundStyle(.secondary)
                        Spacer()
                        Text(script.updatedAt.relativeLabel)
                    }
                    HStack {
                        Text("字数").foregroundStyle(.secondary)
                        Spacer()
                        Text("\(script.bodyText.count) 字")
                    }
                    HStack {
                        Text("角色 / 段落").foregroundStyle(.secondary)
                        Spacer()
                        Text("\(script.roles.count) / \(total)")
                    }
                    HStack {
                        Text("最近导出").foregroundStyle(.secondary)
                        Spacer()
                        Text(script.lastExportedAt?.relativeLabel ?? "未导出")
                    }
                }
                .font(.caption)
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
    @Query private var voiceProfiles: [VoiceProfile]
    let script: Script?

    /// 音色选项：从 VoiceProfile 动态读取（builtIn + available + pendingReview）
    private var availableVoices: [String] {
        let allowedStatuses: Set<VoiceProfileStatus> = [.builtIn, .available, .pendingReview]
        return voiceProfiles
            .filter { allowedStatuses.contains($0.status) }
            .map(\.name)
    }

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
    @State private var selectedTab: ResourceTab = .model

    enum ResourceTab: String, CaseIterable {
        case model = "模型"
        case voice = "音色"
    }

    @State private var showCreateVoice = false

    var body: some View {
        AppPageScaffold(title: "资源中心", subtitle: "管理模型与音色资源。") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    ForEach(ResourceTab.allCases, id: \.self) { tab in
                        Button {
                            selectedTab = tab
                        } label: {
                            Text(tab.rawValue)
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.bordered)
                        .tint(selectedTab == tab ? .accentColor : .secondary)
                    }
                    Spacer()
                    if selectedTab == .voice {
                        Button {
                            showCreateVoice = true
                        } label: {
                            Label("创建音色", systemImage: "plus")
                                .font(.subheadline.weight(.medium))
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }

                switch selectedTab {
                case .model:
                    modelContent
                case .voice:
                    voiceContent
                }
            }
        }
        .sheet(isPresented: $showCreateVoice) {
            CreateVoiceProfileView(onDismiss: { showCreateVoice = false })
        }
    }

    @ViewBuilder
    private var modelContent: some View {
        VStack(spacing: 10) {
            ResourceRow(name: "Qwen3-TTS 0.6B Base bf16", status: "已安装 · 推荐 8GB 以上统一内存")
            ResourceRow(name: "Qwen3-TTS 0.6B Base 8bit", status: "下载中 · 42%")
            ResourceRow(name: "Qwen3-TTS 1.7B Base", status: "下载失败 · 可重试")
        }
    }

    @ViewBuilder
    private var voiceContent: some View {
        VoiceLibraryView()
    }
}

private struct VoiceLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \VoiceProfile.createdAt, order: .reverse) private var profiles: [VoiceProfile]

    var body: some View {
        if profiles.isEmpty {
            emptyState
        } else {
            VStack(spacing: 0) {
                voiceListHeader
                Divider()
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(profiles, id: \.id) { profile in
                            VoiceRow(profile: profile)
                            if profile.id != profiles.last?.id {
                                Divider().padding(.leading, 12)
                            }
                        }
                    }
                }
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
            .padding(.horizontal, 4)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.wave.2")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("暂无音色")
                .font(.headline)
            Text("点击上方「创建音色」创建可复用音色")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var voiceListHeader: some View {
        HStack(spacing: 0) {
            Text("音色名称").frame(maxWidth: .infinity, alignment: .leading)
            Text("类型").frame(width: 80, alignment: .center)
            Text("来源").frame(width: 80, alignment: .center)
            Text("时长").frame(width: 56, alignment: .trailing)
            Text("状态").frame(width: 72, alignment: .center)
            Text("最近使用").frame(width: 88, alignment: .center)
            Text("操作").frame(width: 100, alignment: .center)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.6))
    }
}

private struct VoiceRow: View {
    let profile: VoiceProfile

    var body: some View {
        HStack(spacing: 0) {
            // 音色名称
            HStack(spacing: 8) {
                Text(String(profile.name.prefix(1)))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(Color.accentColor.opacity(0.7))
                    .clipShape(Circle())
                Text(profile.name)
                    .font(.body)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 类型
            Text(profile.kindLabel)
                .font(.caption)
                .frame(width: 80, alignment: .center)

            // 来源
            Text(profile.sourceLabel)
                .font(.caption)
                .frame(width: 80, alignment: .center)

            // 时长
            Text(profile.durationLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .trailing)

            // 状态
            voiceStatusBadge
                .frame(width: 72, alignment: .center)

            // 最近使用
            Text(profile.lastUsedAt?.relativeLabel ?? "未使用")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 88, alignment: .center)

            // 操作
            voiceActions
                .frame(width: 100, alignment: .center)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var voiceStatusBadge: some View {
        let color: Color = {
            switch profile.status {
            case .builtIn:       return .secondary
            case .available:     return .green
            case .pendingReview: return .orange
            case .failed:        return .red
            }
        }()
        return Text(profile.statusLabel)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var voiceActions: some View {
        HStack(spacing: 6) {
            Button {
                // TODO: 试听
            } label: {
                Image(systemName: "play.circle")
                    .font(.body)
            }
            .buttonStyle(.plain)
            .help("试听")

            if profile.kind != .preset {
                Button {
                    // TODO: 重命名
                } label: {
                    Image(systemName: "pencil")
                        .font(.body)
                }
                .buttonStyle(.plain)
                .help("重命名")

                Button {
                    // TODO: 删除
                } label: {
                    Image(systemName: "trash")
                        .font(.body)
                        .foregroundStyle(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("删除")
            }
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
        AppPageScaffold(title: "任务总览", subtitle: "查看所有文案生成任务，并展开排查单篇文案的段落状态。") {
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
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .system
    @AppStorage("cacheLimit") private var cacheLimit: CacheLimit = .gb20
    @AppStorage("defaultExportDirectory") private var defaultExportDirectory: String = ""
    @State private var cacheUsage: String = "待统计"

    // 统一尺寸常量
    private static let trailingColumnWidth: CGFloat = 300
    private static let controlWidth: CGFloat = 176
    private static let pairButtonWidth: CGFloat = 124
    private static let controlHeight: CGFloat = 32

    private var currentExportDisplayPath: String {
        if defaultExportDirectory.isEmpty {
            return "Downloads / MLX Voice Notes Exports"
        } else {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            let path = defaultExportDirectory
            if path.hasPrefix(home) {
                return String(path.dropFirst(home.count))
                    .replacingOccurrences(of: "/Downloads/MLX Voice Notes Exports", with: "Downloads / MLX Voice Notes Exports")
            }
            return path
        }
    }

    var body: some View {
        AppPageScaffold(title: "偏好设置", subtitle: "管理语言、导出位置和本地缓存。") {
            VStack(alignment: .leading, spacing: 14) {
                // 语言模块 — 标题与控件合并到同一行
                settingsCard("") {
                    HStack(spacing: 0) {
                        Text("语言")
                            .font(.body)
                            .frame(width: 80, alignment: .leading)
                        Spacer()
                        Picker("", selection: $appLanguage) {
                            ForEach(AppLanguage.allCases) { lang in
                                Text(lang.displayName).tag(lang)
                            }
                        }
                        .labelsHidden()
                        .font(.body)
                        .controlSize(.regular)
                        .frame(width: Self.controlWidth, height: Self.controlHeight)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }

                // 导出位置模块 — 标签+路径一行，按钮一行
                settingsCard("") {
                    VStack(spacing: 12) {
                        // 第一排：导出位置左，路径右
                        HStack {
                            Text("导出位置")
                                .font(.body)
                                .frame(width: 80, alignment: .leading)
                            Spacer()
                            Text(currentExportDisplayPath)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(width: Self.controlWidth, alignment: .trailing)
                        }
                        // 第二排：按钮靠近，右对齐
                        HStack {
                            Spacer()
                            Button("恢复默认位置") {
                                defaultExportDirectory = ""
                            }
                            .font(.body)
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            Button("更改位置") {
                                changeExportDirectory()
                            }
                            .font(.body)
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }

                // 缓存模块
                settingsCard("") {
                    VStack(spacing: 0) {
                        settingsRowLabel("当前占用缓存", subtitle: nil) {
                            Text(cacheUsage)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .frame(width: Self.controlWidth, alignment: .trailing)
                        }

                        Divider().padding(.horizontal, 16)

                        settingsRowLabel("缓存上限", subtitle: "达到上限后提醒用户清理缓存。") {
                            Picker("缓存上限", selection: $cacheLimit) {
                                ForEach(CacheLimit.allCases) { limit in
                                    Text(limit.displayName).tag(limit)
                                }
                            }
                            .labelsHidden()
                            .font(.body)
                            .controlSize(.regular)
                            .frame(width: Self.controlWidth)
                        }

                        Divider().padding(.horizontal, 16)

                        settingsRowLabel("清理缓存", subtitle: "清除可再生成的临时文件，不删除用户文案和导出音频。") {
                            Button("清理缓存") {
                                // TODO: implement cache cleanup
                            }
                            .font(.body)
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            .frame(width: Self.controlWidth)
                            .disabled(true)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Settings Card Helper

    private func settingsCard<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if !title.isEmpty {
                Text(title)
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
            }

            VStack(spacing: 0) {
                content()
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(
                RoundedRectangle(cornerRadius: 10)
            )
        }
    }

    // MARK: - Settings Row Helper

    @ViewBuilder
    private func settingsRowLabel(
        _ label: String,
        subtitle: String?,
        @ViewBuilder control: () -> some View
    ) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.body)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            control()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }



    // MARK: - Actions

    private func changeExportDirectory() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.title = "选择导出目录"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true

        if !defaultExportDirectory.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: defaultExportDirectory)
        } else {
            panel.directoryURL = AudioExportService.defaultExportDirectory
        }

        if panel.runModal() == .OK, let url = panel.url {
            defaultExportDirectory = url.path
        }
        #endif
    }
}

private struct AppPageScaffold<Content: View, Sidebar: View>: View {
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

// MARK: - CreateVoiceProfileView

struct CreateVoiceProfileView: View {
    let onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var voiceName = ""
    @State private var referenceAudioPath = ""
    @State private var referenceText = ""
    @State private var testSentence = "这是一个用于确认音色效果的测试句。"
    @State private var showHelp = false
    @State private var showFileImporter = false
    @State private var hasTestAudio = false
    @State private var nameError = false

    var body: some View {
        VStack(spacing: 0) {
            // ── Title bar ──
            HStack {
                Text("创建音色")
                    .font(.headline)
                Spacer()
                Button("取消") { onDismiss() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button("保存音色") { saveVoice() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // ── Content ──
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Description + help
                    HStack(alignment: .top) {
                        Text("导入参考音频，校对参考文本，生成测试音频后保存为可复用音色。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            showHelp.toggle()
                        } label: {
                            Text("?")
                                .font(.caption.bold())
                                .frame(width: 22, height: 22)
                                .background(Circle().stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showHelp, arrowEdge: .top) {
                            VStack(alignment: .leading, spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("1. 导入参考音频").font(.caption.bold())
                                    Text("建议 10-30 秒，单人声，低噪声").font(.caption2).foregroundStyle(.secondary)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("2. 校对参考文本").font(.caption.bold())
                                    Text("文字越准确，音色测试越稳定").font(.caption2).foregroundStyle(.secondary)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("3. 生成测试音频").font(.caption.bold())
                                    Text("确认效果后保存为可复用音色").font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                            .padding(12)
                            .frame(width: 220)
                        }
                    }

                    // ── Left column: form fields ──
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 14) {
                            // Voice name
                            formCard {
                                Text("音色名称").font(.subheadline.bold())
                                TextField("输入音色名称", text: $voiceName)
                                    .textFieldStyle(.roundedBorder)
                                    .border(nameError ? Color.red : Color.clear)
                                    .onChange(of: voiceName) { nameError = false }
                                if nameError {
                                    Text("请输入音色名称")
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                            }

                            // Reference audio
                            formCard {
                                Text("参考音频").font(.subheadline.bold())
                                if referenceAudioPath.isEmpty {
                                    HStack {
                                        TextField("未选择音频文件", text: .constant(""))
                                            .textFieldStyle(.roundedBorder)
                                            .disabled(true)
                                        Button("选择文件...") { showFileImporter = true }
                                            .buttonStyle(.bordered)
                                            .controlSize(.small)
                                    }
                                } else {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(URL(fileURLWithPath: referenceAudioPath).lastPathComponent)
                                            .font(.subheadline)
                                        HStack(spacing: 8) {
                                            Button("替换音频") { showFileImporter = true }
                                                .buttonStyle(.bordered)
                                                .controlSize(.small)
                                            Button("试听原音频") { }
                                                .buttonStyle(.bordered)
                                                .controlSize(.small)
                                        }
                                    }
                                    .padding(10)
                                    .background(Color(nsColor: .controlBackgroundColor))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                            }

                            // Reference text
                            formCard {
                                HStack {
                                    Text("参考文本").font(.subheadline.bold())
                                    Spacer()
                                    Button("自动转写") { }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                        .disabled(true)
                                }
                                TextEditor(text: $referenceText)
                                    .font(.body)
                                    .frame(minHeight: 100, maxHeight: 160)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 5)
                                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                                    )
                                    .overlay(alignment: .topLeading) {
                                        if referenceText.isEmpty {
                                            Text("输入或粘贴参考文本...")
                                                .font(.body)
                                                .foregroundStyle(.tertiary)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 8)
                                                .allowsHitTesting(false)
                                        }
                                    }
                            }
                        }

                        // ── Right column: test & save ──
                        VStack(alignment: .leading, spacing: 12) {
                            formCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("测试与保存").font(.subheadline.bold())

                                    HStack {
                                        Text("克隆模式")
                                            .font(.caption).foregroundStyle(.secondary)
                                        Spacer()
                                        Text("本地优先")
                                            .font(.caption)
                                    }
                                    Divider()
                                    HStack {
                                        Text("模型状态")
                                            .font(.caption).foregroundStyle(.secondary)
                                        Spacer()
                                        Text("待验证")
                                            .font(.caption)
                                    }
                                    Divider()

                                    Text("测试句").font(.caption.bold())
                                    TextEditor(text: $testSentence)
                                        .font(.caption)
                                        .frame(minHeight: 56, maxHeight: 80)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 5)
                                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                                        )

                                    HStack(spacing: 8) {
                                        Button("生成测试音频") {
                                            hasTestAudio = true
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)

                                        Button("试听结果") { }
                                            .buttonStyle(.bordered)
                                            .controlSize(.small)
                                            .disabled(!hasTestAudio)
                                    }

                                    if hasTestAudio {
                                        Text("真实克隆能力将在 Phase 3 接入")
                                            .font(.caption2)
                                            .foregroundStyle(.orange)
                                    }
                                }
                            }

                            formCard {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("保存后")
                                        .font(.caption.bold())
                                    Text("新音色会进入资源中心的音色库，并出现在文案列表的角色音色下拉菜单中。")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .frame(width: 240)
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 680, height: 520)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    referenceAudioPath = url.path
                }
            case .failure:
                break
            }
        }
    }

    // MARK: - Save Logic

    private func saveVoice() {
        let trimmed = voiceName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            nameError = true
            return
        }
        nameError = false

        let profile = VoiceProfile(
            name: trimmed,
            kind: .reference,
            source: .localAudio,
            status: .pendingReview,
            referenceAudioPath: referenceAudioPath.isEmpty ? nil : referenceAudioPath,
            referenceText: referenceText.isEmpty ? nil : referenceText
        )
        modelContext.insert(profile)
        onDismiss()
    }

    private func formCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            content()
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 1)
        )
    }
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

import SwiftUI
import SwiftData

struct ScriptLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var voiceProfiles: [VoiceProfile]
    @StateObject private var mlxService = MLXAudioService()
    let scripts: [Script]
    @Binding var selectedScriptID: UUID?
    @Binding var selectedPage: AppPage
    @State private var expandedScriptID: UUID?
    @State private var deleteCandidate: Script?
    @State private var parseSummary = "等待解析"
    @State private var showDraftReuseTip = false

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

                if showDraftReuseTip {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.on.doc")
                        Text("正在复用一个空白草稿")
                        Spacer()
                    }
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .padding(8)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                ScrollView {
                    if scripts.isEmpty {
                        VStack(spacing: 16) {
                            ContentUnavailableView(
                                "欢迎使用 MLX Voice Notes",
                                systemImage: "waveform.badge.mic",
                                description: Text("点击「新建文案」开始创建你的第一个配音项目。")
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.vertical, 60)
                        }
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(scripts) { script in
                                scriptRow(for: script)
                            }
                        }
                        .padding(.vertical, 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
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

            HStack(spacing: 8) {
                Button("编辑") {
                    openEditor(for: script)
                }
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
        print("[createScript] 进入")
        
        if let reusableDraft = scripts.first(where: isReusableBlankDraft) {
            print("[createScript] 复用空白草稿 id=\(reusableDraft.id)")
            openEditor(for: reusableDraft)
            parseSummary = "继续编辑空白草稿"
            showDraftReuseTip = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showDraftReuseTip = false
            }
            return
        }
        
        print("[createScript] 新建 Script")
        
        let script = Script(
            title: "未命名文案",
            subtitle: "",
            bodyText: "[旁白] 在这里输入要配音的文案。",
            updatedAt: .now
        )
        let scriptID = script.id
        print("[createScript] 新建 Script id=\(scriptID)")
        
        modelContext.insert(script)

        let role = VoiceRole(
            name: "旁白",
            normalizedName: "旁白",
            defaultVoiceName: "默认清晰女声",
            script: script
        )
        modelContext.insert(role)
        script.roles.append(role)

        let segment = ScriptSegment(
            order: 1,
            text: "在这里输入要配音的文案。",
            roleName: "旁白",
            script: script
        )
        modelContext.insert(segment)
        script.segments.append(segment)

        do {
            try modelContext.save()
            print("[createScript] save 成功 id=\(scriptID)")
            parseSummary = "等待解析"
            openEditor(for: script)
        } catch {
            print("[createScript] save 失败: \(error.localizedDescription)")
            parseSummary = "新建失败：\(error.localizedDescription)"
        }
    }

    private func openEditor(for script: Script) {
        selectedScriptID = script.id
        expandedScriptID = script.id
    }

    private func saveAndCollapse(_ script: Script) {
        script.updatedAt = .now
        saveContext()
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
        // 如果正在生成，先取消
        if script.status == .generating {
            GenerationService.cancel(script: script)
        }
        if selectedScriptID == script.id {
            selectedScriptID = scripts.first { $0.id != script.id }?.id
        }
        if expandedScriptID == script.id {
            expandedScriptID = nil
        }
        // 清理关联的音频文件（失败不阻止删除）
        try? AudioStorageService.deleteAudioFiles(for: script.id)
        modelContext.delete(script)
        saveContext()
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
        saveContext()
    }

    private func startPlaceholderGeneration(for script: Script) {
        if script.segments.isEmpty || script.roles.isEmpty {
            parseRolesAndSegments(for: script)
        }

        guard !script.segments.isEmpty else { return }

        // Phase 0.5: 调用真实生成
        GenerationService.start(script: script, voiceProfiles: voiceProfiles, voiceInstruct: nil) { result in
            switch result {
            case .success:
                parseSummary = "生成完成"
            case .failure(let error):
                parseSummary = "生成失败：\(error.localizedDescription)"
            }
        }
        parseSummary = "已开始生成"

        let job = GenerationJob(
            scriptTitle: script.title,
            totalSegments: script.segments.count,
            status: .generating
        )
        modelContext.insert(job)
        saveContext()
        selectedScriptID = script.id
    }

    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            parseSummary = "保存失败：\(error.localizedDescription)"
        }
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
            _ = try AudioExportService.exportRealWAV(for: script, fileName: fileName)
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
        let isAnyGenerating = GenerationService.currentlyGeneratingScriptID != nil
        let isCurrentGenerating = script.status == .generating
        let canStartGeneration = !isAnyGenerating && !isCurrentGenerating

        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("生成状态").font(.headline)

                if let diag = mlxService.lastDiag, diag.elapsedSec > 0 {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("生成耗时 \(String(format: "%.1f", diag.elapsedSec)) 秒").font(.caption)
                        Text("音频时长 \(String(format: "%.1f", diag.durationSec)) 秒").font(.caption)
                        Text("生成速度 \(String(format: "%.2f", diag.realtimeFactor)) 倍").font(.caption)
                    }
                    .foregroundStyle(.secondary)
                    Divider()
                }

                if isCurrentGenerating {
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
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                            Text("\(failed) 段生成失败").foregroundStyle(.orange)
                        }
                        .font(.caption)
                        Text("\(completed)/\(total) 已完成 · \(pending) 段待生成")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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

                if isAnyGenerating && !isCurrentGenerating {
                    Text("其他文案正在生成中，请等待完成")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    if isCurrentGenerating {
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
                            .disabled(!canStartGeneration)
                    } else if failed > 0 {
                        Button("重试失败") {
                            GenerationService.retryFailedSegments(script: script, voiceProfiles: voiceProfiles) { result in
                                if case .failure(let error) = result {
                                    parseSummary = "重试失败：\(error.localizedDescription)"
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                        .disabled(!canStartGeneration)
                        Button("全部重新生成") { startPlaceholderGeneration(for: script) }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(!canStartGeneration)
                    } else if completed > 0 {
                        Button("继续生成") {
                            GenerationService.resume(script: script, voiceProfiles: voiceProfiles) { result in
                                if case .failure(let error) = result {
                                    parseSummary = "继续生成失败：\(error.localizedDescription)"
                                }
                            }
                        }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(!canStartGeneration)
                    } else {
                        Button("生成音频") { startPlaceholderGeneration(for: script) }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.regular)
                            .disabled(!canStartGeneration)
                    }
                }
            }

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
                    .disabled(!isCompleted || isCurrentGenerating)

                    Button("打开文件夹") {
                        #if os(macOS)
                        NSWorkspace.shared.open(AudioExportService.exportDirectory)
                        #endif
                    }
                }

                if !isCompleted && total > 0 {
                    if isCurrentGenerating {
                        Text("生成完成后可导出")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if failed > 0 {
                        Text("有段落生成失败，请重试后再导出")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else {
                        Text("生成完成后可导出")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.top, 12)

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

#Preview {
    ScriptLibraryView(
        scripts: [],
        selectedScriptID: .constant(nil),
        selectedPage: .constant(.scriptLibrary)
    )
    .modelContainer(for: [
        Script.self,
        ScriptSegment.self,
        VoiceRole.self,
        VoiceProfile.self,
        GenerationJob.self,
        ExportRecord.self
    ], inMemory: true)
}

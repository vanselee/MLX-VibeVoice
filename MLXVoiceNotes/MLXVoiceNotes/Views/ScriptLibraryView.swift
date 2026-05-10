import SwiftUI
import SwiftData

struct VoiceRoleBinding {
    let defaultVoiceName: String
    let speed: Double
    let volumeDB: Double
    let pitch: Double
}

struct ScriptLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var voiceProfiles: [VoiceProfile]
    @ObservedObject private var mlxService = MLXAudioService.shared
    let scripts: [Script]
    @Binding var selectedScriptID: UUID?
    @Binding var selectedPage: AppPage
    @State private var expandedScriptID: UUID?
    @State private var deleteCandidate: Script?
    @State private var parseSummary: String = ""
    @State private var showDraftReuseTip = false

    private var selectedScript: Script? {
        scripts.first { $0.id == selectedScriptID } ?? scripts.first
    }

    var body: some View {
        AppPageScaffold(titleKey: "scriptLibrary.title", subtitleKey: "scriptLibrary.subtitle") {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(LocalizedStringKey("scriptLibrary.sortedByCreated"))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(LocalizedStringKey("scriptLibrary.newScript")) {
                        createScript()
                    }
                    .buttonStyle(.borderedProminent)
                }

                if showDraftReuseTip {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.on.doc")
                        Text(LocalizedStringKey("scriptLibrary.reusingBlankDraft"))
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
                                LocalizedStringKey("scriptLibrary.welcomeTitle"),
                                systemImage: "waveform.badge.mic",
                                description: Text(LocalizedStringKey("scriptLibrary.welcomeHint"))
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
            .alert(LocalizedStringKey("scriptLibrary.deleteConfirmTitle"), isPresented: deleteAlertBinding) {
                Button(LocalizedStringKey("button.cancel"), role: .cancel) {}
                Button(LocalizedStringKey("button.delete"), role: .destructive) {
                    deleteSelectedCandidate()
                }
            } message: {
                Text(LocalizedStringKey("scriptLibrary.deleteConfirmMessage"))
            }
        } sidebar: {
            if let selectedScript {
                scriptDetailPanel(for: selectedScript)
            } else {
                ContentUnavailableView(LocalizedStringKey("scriptLibrary.noScript"), systemImage: "doc.text")
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
                        Text(String(format: String(localized: "scriptLibrary.scriptMeta"), script.updatedAt.relativeLabel, script.roles.count, script.segments.count))
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
                Button(LocalizedStringKey("button.edit")) {
                    openEditor(for: script)
                }
                .disabled(script.status == .generating)

                Button(LocalizedStringKey("button.delete"), role: .destructive) {
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
        let allowedStatuses: Set<VoiceProfileStatus> = [.builtIn, .available]
        return voiceProfiles
            .filter { allowedStatuses.contains($0.status) }
            .map(\.name)
    }

    @ViewBuilder
    private func currentScriptEditor(for script: Script) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(LocalizedStringKey("label.editScript"))
                    .font(.headline)
                StatusBadge(status: script.status)
                if script.status == .generating {
                    ProgressView(value: generationProgress(for: script))
                        .frame(width: 160)
                }
                Spacer()
                Button(LocalizedStringKey("button.save")) {
                    saveAndCollapse(script)
                }
            }

            TextField(String(localized: "label.title"), text: binding(for: script, keyPath: \.title))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: .infinity)

            HStack {
                Button(LocalizedStringKey("button.pasteOneClick")) {
                    pasteClipboard(into: script)
                }
                Button(LocalizedStringKey("button.aiPrompt")) {}
                Button(LocalizedStringKey("button.parseRoles")) {
                    parseRolesAndSegments(for: script)
                }
                Spacer()
                if script.status == .generating {
                    Button(LocalizedStringKey("button.viewTaskQueue")) {
                        selectedPage = .taskQueue
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !script.roles.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(LocalizedStringKey("label.roleVoiceBinding"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(script.roles.sorted { $0.normalizedName < $1.normalizedName }) { role in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 10) {
                                Text(role.name)
                                    .fontWeight(.medium)
                                    .frame(width: 70, alignment: .leading)
                                Picker(String(localized: "label.voice"), selection: Binding(
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
                                Text(LocalizedStringKey("label.speed"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Slider(value: Binding(
                                    get: { role.speed },
                                    set: { role.speed = $0; script.updatedAt = .now }
                                ), in: 0.75...1.5)
                                Text("\(role.speed.formatted(.number.precision(.fractionLength(2))))x")
                                    .font(.caption)
                                    .frame(width: 36)
                                Button(LocalizedStringKey("button.preview")) {}
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
                    Label(LocalizedStringKey("message.generationCompleted"), systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(progressLabel(for: script))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else if script.status == .generating {
                HStack {
                    Label(LocalizedStringKey("status.generating"), systemImage: "waveform")
                        .foregroundStyle(.blue)
                    Text(progressLabel(for: script))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(LocalizedStringKey("button.viewTaskQueue")) {
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
                Text(String(format: String(localized: "message.roles"), script.roles.count))
                Text(String(format: String(localized: "message.segments"), script.segments.count))
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
            parseSummary = String(localized: "message.continueBlankDraft")
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
            parseSummary = String(localized: "message.waitingParse")
            openEditor(for: script)
        } catch {
            print("[createScript] save 失败: \(error.localizedDescription)")
            parseSummary = String(format: String(localized: "message.createFailed"), error.localizedDescription)
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
        if script.status == .generating {
            GenerationService.cancel(script: script)
        }
        if selectedScriptID == script.id {
            selectedScriptID = scripts.first { $0.id != script.id }?.id
        }
        if expandedScriptID == script.id {
            expandedScriptID = nil
        }
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

    private func defaultVoiceName(for roleName: String) -> String {
        if let refVoice = findAvailableReferenceVoice() {
            return refVoice
        }
        if roleName == "旁白" {
            return "默认清晰女声"
        }
        if roleName.contains("男") || roleName.contains("博主") || roleName.contains("老板") {
            return "自然男声"
        }
        return "默认清晰女声"
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
        parseSummary = String(localized: "message.pastedWaitingParse")
        #endif
    }

    private func parseRolesAndSegments(for script: Script) {
        let parsedScript = ScriptParser.parse(script.bodyText)

        var oldVoiceBindings: [String: VoiceRoleBinding] = [:]
        for oldRole in script.roles {
            oldVoiceBindings[oldRole.normalizedName] = VoiceRoleBinding(
                defaultVoiceName: oldRole.defaultVoiceName,
                speed: oldRole.speed,
                volumeDB: oldRole.volumeDB,
                pitch: oldRole.pitch
            )
        }

        let oldSegments = script.segments
        let oldRoles = script.roles
        script.segments.removeAll()
        script.roles.removeAll()
        oldSegments.forEach(modelContext.delete)
        oldRoles.forEach(modelContext.delete)

        for parsedRole in parsedScript.roles {
            let binding = oldVoiceBindings[parsedRole.normalizedName]
            let voiceName = binding?.defaultVoiceName ?? defaultVoiceName(for: parsedRole.normalizedName)
            
            let role = VoiceRole(
                name: parsedRole.name,
                normalizedName: parsedRole.normalizedName,
                defaultVoiceName: voiceName,
                speed: binding?.speed ?? 1.0,
                volumeDB: binding?.volumeDB ?? 0.0,
                pitch: binding?.pitch ?? 0,
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
        
        var resultParts: [String] = []
        resultParts.append(String(format: String(localized: "message.parseResult"), parsedScript.roles.count, parsedScript.segments.count))
        if parsedScript.unmarkedSegmentCount > 0 {
            resultParts.append(String(format: String(localized: "message.unmarkedFallback"), parsedScript.unmarkedSegmentCount))
        }
        parseSummary = resultParts.joined()
        saveContext()
    }

    private func startPlaceholderGeneration(for script: Script) {
        parseRolesAndSegments(for: script)
        guard !script.segments.isEmpty else { return }

        if let errorMessage = validateRolesForGeneration(for: script) {
            parseSummary = errorMessage
            return
        }

        try? AudioStorageService.deleteAudioFiles(for: script.id)

        GenerationService.start(script: script, voiceProfiles: voiceProfiles, voiceInstruct: nil) { result in
            switch result {
            case .success:
                parseSummary = String(localized: "message.generationCompleted")
            case .failure(let error):
                parseSummary = String(format: String(localized: "message.generationFailed"), error.localizedDescription)
            }
        }
        parseSummary = String(localized: "message.generationStarted")

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
            parseSummary = String(format: String(localized: "message.saveFailed"), error.localizedDescription)
        }
    }

    private func findAvailableReferenceVoice() -> String? {
        let available = voiceProfiles.first {
            $0.status == .available &&
            $0.referenceAudioPath != nil &&
            !$0.referenceAudioPath!.isEmpty &&
            $0.referenceText != nil &&
            !$0.referenceText!.isEmpty
        }
        return available?.name
    }

    private func validateRolesForGeneration(for script: Script) -> String? {
        for role in script.roles {
            guard let profile = voiceProfiles.first(where: { $0.name == role.defaultVoiceName }) else {
                return String(format: String(localized: "message.roleNotBound"), role.name)
            }
            let hasValidReference = profile.status == .available || profile.status == .builtIn
            let hasAudio = profile.referenceAudioPath != nil && !profile.referenceAudioPath!.isEmpty
            let hasText = profile.referenceText != nil && !profile.referenceText!.isEmpty
            
            if profile.status == .builtIn {
                continue
            }
            if profile.status != .available {
                return String(format: String(localized: "message.voiceStatusInvalid"), role.name, profile.name, profile.statusLabel)
            }
            if !hasAudio || !hasText {
                return String(format: String(localized: "message.voiceMissing"), role.name, profile.name)
            }
        }
        return nil
    }

    private var exportDisplayPath: String {
        let dir = AudioExportService.exportDirectory
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = dir.path
        if path.hasPrefix(home) {
            let relative = String(path.dropFirst(home.count))
            return relative
                .replacingOccurrences(of: "/Downloads/MLX VibeVoice Exports", with: "Downloads / MLX VibeVoice Exports")
        }
        return path
    }

    private func exportWAV(for script: Script) {
        let safeName = (script.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? String(localized: "script.untitled") : script.title)
        let fileName = "\(safeName)_\(Date().fileStamp)"
        do {
            _ = try AudioExportService.exportRealWAV(for: script, fileName: fileName)
            script.lastExportedAt = .now
            parseSummary = String(localized: "message.exported")
        } catch {
            parseSummary = String(format: String(localized: "message.exportFailed"), error.localizedDescription)
        }
    }

    private func generationProgress(for script: Script) -> Double {
        guard !script.segments.isEmpty else { return 0 }
        return Double(completedCount(for: script)) / Double(script.segments.count)
    }

    private func progressLabel(for script: Script) -> String {
        return String(format: String(localized: "message.progress"), completedCount(for: script), script.segments.count)
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
                Text(LocalizedStringKey("sidebar.generationStatus")).font(.headline)

                Text(String(format: String(localized: "message.currentModel"), mlxService.currentModelName))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let diag = mlxService.lastDiag, diag.elapsedSec > 0 {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(format: String(localized: "message.generationTime"), diag.elapsedSec)).font(.caption)
                        Text(String(format: String(localized: "message.audioDuration"), diag.durationSec)).font(.caption)
                        Text(String(format: String(localized: "message.generationSpeed"), diag.realtimeFactor)).font(.caption)
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
                    Text(String(format: String(localized: "message.pendingSegments"), pending))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if completed == total && total > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        Text(String(format: String(localized: "message.completedSegments"), total)).foregroundStyle(.secondary)
                    }
                    .font(.caption)
                } else if failed > 0 {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                            Text(String(format: String(localized: "message.failedSegments"), failed)).foregroundStyle(.orange)
                        }
                        .font(.caption)
                        Text(String(format: String(localized: "message.completedFailedPending"), completed, total, pending))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if completed > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "circle.lefthalf.filled").foregroundStyle(.blue)
                        Text(String(format: String(localized: "message.partiallyCompleted"), completed, total)).foregroundStyle(.secondary)
                    }
                    .font(.caption)
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "circle").foregroundStyle(.secondary)
                        Text(String(format: String(localized: "message.notGenerated"), total)).foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }

                if isAnyGenerating && !isCurrentGenerating {
                    Text(LocalizedStringKey("message.otherGenerating"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    if isCurrentGenerating {
                        Button(LocalizedStringKey("button.pause")) { GenerationService.pause(script: script) }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        Button(LocalizedStringKey("button.cancel")) { GenerationService.cancel(script: script) }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    } else if completed == total && total > 0 {
                        Button(LocalizedStringKey("button.regenerate")) { startPlaceholderGeneration(for: script) }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            .disabled(!canStartGeneration)
                    } else if failed > 0 {
                        Button(LocalizedStringKey("button.retryFailed")) {
                            GenerationService.retryFailedSegments(script: script, voiceProfiles: voiceProfiles) { result in
                                if case .failure(let error) = result {
                                    parseSummary = String(format: String(localized: "message.retryFailed"), error.localizedDescription)
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                        .disabled(!canStartGeneration)
                        Button(LocalizedStringKey("button.regenerateAll")) { startPlaceholderGeneration(for: script) }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(!canStartGeneration)
                    } else if completed > 0 {
                        Button(LocalizedStringKey("button.continueGenerate")) {
                            GenerationService.resume(script: script, voiceProfiles: voiceProfiles) { result in
                                if case .failure(let error) = result {
                                    parseSummary = String(format: String(localized: "message.continueFailed"), error.localizedDescription)
                                }
                            }
                        }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(!canStartGeneration)
                    } else {
                        Button(LocalizedStringKey("button.generateAudio")) { startPlaceholderGeneration(for: script) }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.regular)
                            .disabled(!canStartGeneration)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Divider()
                    .padding(.top, 4)

                Text(LocalizedStringKey("sidebar.exportAudio")).font(.headline)

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
                    Text(String(format: String(localized: "message.recentExport"), script.lastExportedAt!.relativeLabel))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                let isCompleted = completed == total && total > 0
                HStack(spacing: 8) {
                    Button(LocalizedStringKey("button.exportWav")) {
                        exportWAV(for: script)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isCompleted || isCurrentGenerating)

                    Button(LocalizedStringKey("button.openFolder")) {
                        #if os(macOS)
                        NSWorkspace.shared.open(AudioExportService.exportDirectory)
                        #endif
                    }
                }

                if !isCompleted && total > 0 {
                    if isCurrentGenerating {
                        Text(LocalizedStringKey("message.exportAfterComplete"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if failed > 0 {
                        Text(LocalizedStringKey("message.retryBeforeExport"))
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else {
                        Text(LocalizedStringKey("message.exportAfterComplete"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.top, 12)

            VStack(alignment: .leading, spacing: 10) {
                Divider()
                    .padding(.top, 4)

                Text(LocalizedStringKey("sidebar.scriptDetails")).font(.headline)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(LocalizedStringKey("sidebar.title")).foregroundStyle(.secondary)
                        Spacer()
                        Text(script.title).lineLimit(1)
                    }
                    HStack {
                        Text(LocalizedStringKey("sidebar.status")).foregroundStyle(.secondary)
                        Spacer()
                        Text(script.status.displayName)
                    }
                    HStack {
                        Text(LocalizedStringKey("sidebar.createdAt")).foregroundStyle(.secondary)
                        Spacer()
                        Text(script.createdAt.relativeLabel)
                    }
                    HStack {
                        Text(LocalizedStringKey("sidebar.updatedAt")).foregroundStyle(.secondary)
                        Spacer()
                        Text(script.updatedAt.relativeLabel)
                    }
                    HStack {
                        Text(LocalizedStringKey("sidebar.charCount")).foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: String(localized: "message.chars"), script.bodyText.count))
                    }
                    HStack {
                        Text(LocalizedStringKey("sidebar.rolesSegments")).foregroundStyle(.secondary)
                        Spacer()
                        Text("\(script.roles.count) / \(total)")
                    }
                    HStack {
                        Text(LocalizedStringKey("sidebar.lastExport")).foregroundStyle(.secondary)
                        Spacer()
                        Text(script.lastExportedAt?.relativeLabel ?? String(localized: "status.notExported"))
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

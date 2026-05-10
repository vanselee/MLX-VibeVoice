import SwiftUI
import SwiftData

struct ResourceCenterView: View {
    @State private var selectedTab: ResourceTab = .model
    @State private var showCreateVoice = false
    @State private var modelStatuses: [(model: QwenTTSModel, status: ModelInstallStatus)] = []
    @ObservedObject private var downloadManager = ModelDownloadManager.shared

    enum ResourceTab: String, CaseIterable {
        case model = "resourceCenter.model"
        case voice = "resourceCenter.voice"
    }

    var body: some View {
        AppPageScaffold(titleKey: "resourceCenter.title", subtitleKey: "resourceCenter.subtitle") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    ForEach(ResourceTab.allCases, id: \.self) { tab in
                        Button {
                            selectedTab = tab
                        } label: {
                            Text(LocalizedStringKey(tab.rawValue))
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
                            Label(LocalizedStringKey("resourceCenter.createVoice"), systemImage: "plus")
                                .font(.subheadline.weight(.medium))
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }

                switch selectedTab {
                case .model:
                    modelContent
                        .task {
                            refreshAllModelStatuses()
                        }
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
        if modelStatuses.isEmpty {
            ProgressView(LocalizedStringKey("resourceCenter.detectingModels"))
                .frame(maxWidth: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(modelStatuses, id: \.model.id) { item in
                        let downloadTask = downloadManager.task(for: item.model)
                        VStack(spacing: 8) {
                            ModelRow(
                                model: item.model,
                                status: item.status,
                                missingFiles: ModelDownloadManager.shared.missingFiles(for: item.model),
                                onRefresh: {
                                    refreshAllModelStatuses()
                                },
                                downloadTask: downloadTask
                            )

                            // 下载进度面板（非 idle 状态时显示）
                            if let task = downloadTask, task.state != .idle {
                                ModelDownloadPanel(downloadTask: task, onRefresh: {
                                    refreshAllModelStatuses()
                                })
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func refreshAllModelStatuses() {
        modelStatuses = ModelDownloadManager.shared.checkAllModels()
        downloadManager.removeCompletedTasks()
    }

    @ViewBuilder
    private var voiceContent: some View {
        VoiceLibraryView()
    }
}

struct VoiceLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \VoiceProfile.createdAt, order: .reverse) private var profiles: [VoiceProfile]
    
    @State private var profileToDelete: VoiceProfile?
    @State private var showDeleteConfirmation = false
    @State private var deleteError: String?
    @State private var showError = false
    
    @State private var profileToRename: VoiceProfile?

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
                            VoiceRow(profile: profile, onDelete: {
                                profileToDelete = profile
                                showDeleteConfirmation = true
                            }, onRename: {
                                profileToRename = profile
                            })
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
            .alert(LocalizedStringKey("resourceCenter.confirmDelete"), isPresented: $showDeleteConfirmation) {
                Button(LocalizedStringKey("resourceCenter.cancel"), role: .cancel) {
                    profileToDelete = nil
                }
                Button(LocalizedStringKey("resourceCenter.delete"), role: .destructive) {
                    deleteSelectedProfile()
                }
            } message: {
                if let profile = profileToDelete {
                    Text(String(format: String(localized: "resourceCenter.deleteVoiceConfirm"), profile.name))
                }
            }
            .alert(LocalizedStringKey("resourceCenter.deleteResult"), isPresented: $showError) {
                Button(LocalizedStringKey("resourceCenter.ok"), role: .cancel) { }
            } message: {
                if let err = deleteError {
                    Text(err)
                }
            }
            .sheet(item: $profileToRename) { profile in
                RenameVoiceProfileSheet(profile: profile)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.wave.2")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(LocalizedStringKey("resourceCenter.noVoices"))
                .font(.headline)
            Text(LocalizedStringKey("resourceCenter.noVoicesHint"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var voiceListHeader: some View {
        HStack(spacing: 0) {
            Text(LocalizedStringKey("resourceCenter.voiceName")).frame(maxWidth: .infinity, alignment: .leading)
            Text(LocalizedStringKey("resourceCenter.voiceType")).frame(width: 80, alignment: .center)
            Text(LocalizedStringKey("resourceCenter.voiceSource")).frame(width: 80, alignment: .center)
            Text(LocalizedStringKey("resourceCenter.voiceDuration")).frame(width: 56, alignment: .trailing)
            Text(LocalizedStringKey("resourceCenter.voiceStatus")).frame(width: 72, alignment: .center)
            Text(LocalizedStringKey("resourceCenter.voiceLastUsed")).frame(width: 88, alignment: .center)
            Text(LocalizedStringKey("resourceCenter.voiceActions")).frame(width: 100, alignment: .center)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.6))
    }
    
    // MARK: - Delete
    
    private func deleteSelectedProfile() {
        guard let profile = profileToDelete else { return }
        let profileID = profile.id
        let profileName = profile.name
        
        // 1. 先删除音频文件（失败不阻止 VoiceProfile 删除）
        var audioDeleteError: String?
        do {
            try VoiceProfileStorageService.shared.deleteVoiceProfileAssets(for: profileID)
            print("[deleteVoiceProfile] 已删除音频资产: \(profileID)")
        } catch {
            audioDeleteError = error.localizedDescription
            print("[deleteVoiceProfile] 音频资产删除失败: \(error.localizedDescription)")
        }
        
        // 2. 从 SwiftData 删除 VoiceProfile
        modelContext.delete(profile)
        
        // 3. 保存 context
        do {
            try modelContext.save()
            print("[deleteVoiceProfile] 已删除 VoiceProfile: \(profileName) id=\(profileID)")
        } catch {
            let errMsg = String(format: String(localized: "voice.delete.failed"), error.localizedDescription)
            print("[deleteVoiceProfile] \(errMsg)")
            deleteError = errMsg
            showError = true
            return
        }
        
        // 4. 如果音频删除失败，提示用户（但音色已删除）
        if let audioErr = audioDeleteError {
            deleteError = String(format: String(localized: "voice.delete.audioCleanupFailed"), audioErr)
            showError = true
        }
        
        profileToDelete = nil
    }
}

struct VoiceRow: View {
    let profile: VoiceProfile
    var onDelete: (() -> Void)?
    var onRename: (() -> Void)?
    
    var body: some View {
        HStack(spacing: 0) {
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

            Text(profile.kindLabel)
                .font(.caption)
                .frame(width: 80, alignment: .center)

            Text(profile.sourceLabel)
                .font(.caption)
                .frame(width: 80, alignment: .center)

            Text(profile.durationLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .trailing)

            voiceStatusBadge
                .frame(width: 72, alignment: .center)

            Text(profile.lastUsedAt?.relativeLabel ?? String(localized: "resourceCenter.notUsed"))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 88, alignment: .center)

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
            } label: {
                Image(systemName: "play.circle")
                    .font(.body)
            }
            .buttonStyle(.plain)
            .help(String(localized: "resourceCenter.preview"))

            if profile.kind != .preset {
                Button {
                    onRename?()
                } label: {
                    Image(systemName: "pencil")
                        .font(.body)
                }
                .buttonStyle(.plain)
                .help(String(localized: "resourceCenter.rename"))

                Button {
                    onDelete?()
                } label: {
                    Image(systemName: "trash")
                        .font(.body)
                        .foregroundStyle(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help(String(localized: "resourceCenter.delete"))
            }
        }
    }
}

#Preview {
    ResourceCenterView()
        .modelContainer(for: [
            Script.self,
            ScriptSegment.self,
            VoiceRole.self,
            VoiceProfile.self,
            GenerationJob.self,
            ExportRecord.self
        ], inMemory: true)
}

// MARK: - Rename Voice Profile Sheet

struct RenameVoiceProfileSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let profile: VoiceProfile
    
    @State private var newName: String = ""
    @State private var errorMessage: String?
    @State private var isSaving = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(LocalizedStringKey("resourceCenter.renameVoice"))
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(LocalizedStringKey("resourceCenter.currentName"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(profile.name)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(LocalizedStringKey("resourceCenter.newName"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField(String(localized: "resourceCenter.enterNewName"), text: $newName)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: newName) { _, _ in
                            errorMessage = nil
                        }
                }
                
                if let err = errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(20)
            
            Spacer()
            
            HStack {
                Spacer()
                Button(LocalizedStringKey("resourceCenter.cancel")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button(LocalizedStringKey("resourceCenter.save")) {
                    saveRename()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .frame(width: 380, height: 280)
        .onAppear {
            newName = profile.name
        }
    }
    
    private func saveRename() {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = String(localized: "resourceCenter.nameCannotBeEmpty")
            return
        }
        
        if trimmed == profile.name {
            dismiss()
            return
        }
        
        isSaving = true
        profile.name = trimmed
        profile.modifiedAt = Date()
        
        do {
            try modelContext.save()
            print("[RenameVoiceProfile] 保存成功: \(trimmed)")
            dismiss()
        } catch {
            errorMessage = String(format: String(localized: "resourceCenter.saveFailed"), error.localizedDescription)
            profile.name = profile.name
            isSaving = false
        }
    }
}

import SwiftUI
import SwiftData

struct ResourceCenterView: View {
    @State private var selectedTab: ResourceTab = .model
    @State private var showCreateVoice = false

    enum ResourceTab: String, CaseIterable {
        case model = "模型"
        case voice = "音色"
    }

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
            .alert("确认删除", isPresented: $showDeleteConfirmation) {
                Button("取消", role: .cancel) {
                    profileToDelete = nil
                }
                Button("删除", role: .destructive) {
                    deleteSelectedProfile()
                }
            } message: {
                if let profile = profileToDelete {
                    Text("确定要删除音色「\(profile.name)」吗？\n\n此操作将同时删除关联的参考音频文件，且无法恢复。")
                }
            }
            .alert("删除结果", isPresented: $showError) {
                Button("确定", role: .cancel) { }
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
            let errMsg = "删除音色失败: \(error.localizedDescription)"
            print("[deleteVoiceProfile] \(errMsg)")
            deleteError = errMsg
            showError = true
            return
        }
        
        // 4. 如果音频删除失败，提示用户（但音色已删除）
        if let audioErr = audioDeleteError {
            deleteError = "音色已删除，但音频文件清理失败: \(audioErr)"
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

            Text(profile.lastUsedAt?.relativeLabel ?? "未使用")
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
            .help("试听")

            if profile.kind != .preset {
                Button {
                    onRename?()
                } label: {
                    Image(systemName: "pencil")
                        .font(.body)
                }
                .buttonStyle(.plain)
                .help("重命名")

                Button {
                    onDelete?()
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
            // Header
            HStack {
                Text("重命名音色")
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
            
            // Content
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("当前名称")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(profile.name)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("新名称")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("输入新名称", text: $newName)
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
            
            // Footer buttons
            HStack {
                Spacer()
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("保存") {
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
            errorMessage = "名称不能为空"
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
            errorMessage = "保存失败: \(error.localizedDescription)"
            profile.name = profile.name // 还原
            isSaving = false
        }
    }
}

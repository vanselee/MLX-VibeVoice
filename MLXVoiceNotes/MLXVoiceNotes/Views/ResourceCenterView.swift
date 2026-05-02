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

struct VoiceRow: View {
    let profile: VoiceProfile

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
                } label: {
                    Image(systemName: "pencil")
                        .font(.body)
                }
                .buttonStyle(.plain)
                .help("重命名")

                Button {
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

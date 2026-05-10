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
            List(allPages, selection: $selectedPage) { page in
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
        // Phase 0.5: 移除 Timer 调度，改为 Task 串行生成
        // 不再调用 GenerationService.advanceOneTick
    }

    private var allPages: [AppPage] {
        AppPage.allCases
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
            PreferencesView()
        }
    }

    private func seedSampleScriptsIfNeeded() {
        guard scripts.isEmpty else { return }

        let now = Date()

        // 样本文案 1：完整段落 + 角色
        let s1 = Script(
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
            lastExportedAt: now.addingTimeInterval(-600)
        )
        modelContext.insert(s1)

        let r1 = VoiceRole(name: "旁白", normalizedName: "旁白", defaultVoiceName: "默认清晰女声", script: s1)
        modelContext.insert(r1)
        s1.roles.append(r1)

        let r2 = VoiceRole(name: "博主", normalizedName: "博主", defaultVoiceName: "默认清晰女声", speed: 1.05, script: s1)
        modelContext.insert(r2)
        s1.roles.append(r2)

        for seg in [
            (1, "你永远都搞不清楚这些平台到底要什么，不要什么。", "旁白", SegmentStatus.completed, 2),
            (2, "有时候一条视频，花几个小时做出来，发到 A 平台正常通过。", "博主", SegmentStatus.generating, 0),
            (3, "发到 B 平台，直接限流，有的还给你封号。", "博主", SegmentStatus.pending, 0),
            (4, "所以做内容不能只看播放量，还要看平台规则和账号风险。", "旁白", SegmentStatus.pending, 0)
        ] {
            let segObj = ScriptSegment(order: seg.0, text: seg.1, roleName: seg.2, status: seg.3, selectedVersion: seg.4, script: s1)
            modelContext.insert(segObj)
            s1.segments.append(segObj)
        }

        // 样本文案 2：部分段落
        let s2 = Script(
            title: "直播间脚本",
            subtitle: "老板 · 客服 · 旁白",
            bodyText: "[旁白] 直播开始前先确认优惠、库存和客服话术。",
            status: .generating,
            createdAt: now.addingTimeInterval(-172_800),
            updatedAt: now.addingTimeInterval(-68_400)
        )
        modelContext.insert(s2)

        let r3 = VoiceRole(name: "老板", normalizedName: "老板", defaultVoiceName: "自然男声", script: s2)
        modelContext.insert(r3)
        s2.roles.append(r3)

        let r4 = VoiceRole(name: "客服", normalizedName: "客服", defaultVoiceName: "默认清晰女声", script: s2)
        modelContext.insert(r4)
        s2.roles.append(r4)

        let r5 = VoiceRole(name: "旁白", normalizedName: "旁白", defaultVoiceName: "默认清晰女声", script: s2)
        modelContext.insert(r5)
        s2.roles.append(r5)

        let seg2 = ScriptSegment(order: 1, text: "直播开始前先确认优惠、库存和客服话术。", roleName: "旁白", status: .generating, script: s2)
        modelContext.insert(seg2)
        s2.segments.append(seg2)

        // 样本文案 3：仅文案，无子模型（延迟解析）
        let s3 = Script(
            title: "短视频开头库",
            subtitle: "开场白集合",
            bodyText: "[旁白] 这类视频开头一定要先讲结果，再讲过程。",
            createdAt: now.addingTimeInterval(-950_400),
            updatedAt: now.addingTimeInterval(-86_400)
        )
        modelContext.insert(s3)

        saveSeedData()
        selectedScriptID = s1.id
    }

    private func seedSampleVoiceProfilesIfNeeded() {
        guard voiceProfiles.isEmpty else { return }
        VoiceProfile.samples.forEach(modelContext.insert)
        saveSeedData()
    }

    private func saveSeedData() {
        do {
            try modelContext.save()
        } catch {
            print("Seed data save failed: \(error.localizedDescription)")
        }
    }

}

enum AppPage: String, CaseIterable, Identifiable {
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

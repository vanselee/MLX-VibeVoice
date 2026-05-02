import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Script.createdAt, order: .reverse) private var scripts: [Script]
    @Query private var voiceProfiles: [VoiceProfile]
    @State private var selectedPage: AppPage = .scriptLibrary
    @State private var selectedScriptID: UUID?
    
    // Debug 测试页面（仅在 DEBUG 模式启用）
    #if DEBUG
    @State private var showMLXTest = false
    #endif

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
        #if DEBUG
        .sheet(isPresented: $showMLXTest) {
            MLXTestView()
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: { showMLXTest.toggle() }) {
                    Image(systemName: "wand.and.stars")
                }
            }
        }
        #endif
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

    @ViewBuilder
    private var allPages: [AppPage] {
        var pages = AppPage.allCases
        #if DEBUG
        pages.append(.mlxTest)
        #endif
        return pages
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
        #if DEBUG
        case .mlxTest:
            MLXTestView()
        #endif
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

enum AppPage: String, CaseIterable, Identifiable {
    case scriptLibrary
    case roleReview
    case resources
    case taskQueue
    case exportSettings
    #if DEBUG
    case mlxTest
    #endif

    var id: String { rawValue }

    var title: String {
        switch self {
        case .scriptLibrary: return "文案列表"
        case .roleReview: return "角色确认"
        case .resources: return "资源中心"
        case .taskQueue: return "任务总览"
        case .exportSettings: return "偏好设置"
        #if DEBUG
        case .mlxTest: return "MLX Test"
        #endif
        }
    }

    var systemImage: String {
        switch self {
        case .scriptLibrary: return "doc.text"
        case .roleReview: return "person.2"
        case .resources: return "externaldrive"
        case .taskQueue: return "list.bullet.rectangle"
        case .exportSettings: return "gearshape"
        #if DEBUG
        case .mlxTest: return "wand.and.stars"
        #endif
        }
    }
}

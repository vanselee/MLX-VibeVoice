import SwiftUI

struct ContentView: View {
    @State private var selectedPage: AppPage = .scriptLibrary

    var body: some View {
        NavigationSplitView {
            List(AppPage.allCases, selection: $selectedPage) { page in
                Label(page.title, systemImage: page.systemImage)
                    .tag(page)
            }
            .navigationTitle("MLX Voice Notes")
            .frame(minWidth: 220)
        } detail: {
            selectedPage.view
                .frame(minWidth: 860, minHeight: 620)
        }
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

    @ViewBuilder
    var view: some View {
        switch self {
        case .scriptLibrary:
            ScriptLibraryView()
        case .workbench:
            WorkbenchView()
        case .roleReview:
            RoleReviewView()
        case .resources:
            ResourceCenterView()
        case .taskQueue:
            TaskQueueView()
        case .exportSettings:
            ExportSettingsView()
        }
    }
}

private struct ScriptLibraryView: View {
    var body: some View {
        AppPageScaffold(title: "文案库", subtitle: "管理所有配音文案、生成状态和导出记录。") {
            Table(sampleScripts) {
                TableColumn("标题") { script in
                    VStack(alignment: .leading) {
                        Text(script.title).fontWeight(.semibold)
                        Text(script.subtitle).foregroundStyle(.secondary)
                    }
                }
                TableColumn("状态", value: \.status)
                TableColumn("角色 / 段落", value: \.roleSegments)
                TableColumn("修改时间", value: \.updatedAt)
                TableColumn("最近导出", value: \.lastExportedAt)
            }
            .frame(minHeight: 360)
        } sidebar: {
            ActionCard(title: "选中文案详情", rows: [
                ("标题", "平台规则吐槽"),
                ("字数", "486 字"),
                ("角色/段落", "3 / 12"),
                ("最近导出", "今天 11:15")
            ])
        }
    }
}

private struct WorkbenchView: View {
    @State private var draft = """
    [旁白] 你永远都搞不清楚这些平台到底要什么，不要什么。
    [博主] 有时候一条视频，花几个小时做出来，发到 A 平台正常通过。
    [博主] 发到 B 平台，直接限流，有的还给你封号。
    """

    var body: some View {
        AppPageScaffold(title: "配音工作台", subtitle: "输入文案、确认角色音色，然后生成完整成品音频。") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button("新建") {}
                    Button("一键粘贴") {}
                    Button("AI 文案整理提示词") {}
                    Spacer()
                    Button("生成整篇") {}
                        .buttonStyle(.borderedProminent)
                }
                TextEditor(text: $draft)
                    .font(.body.monospaced())
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(.background)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        } sidebar: {
            ActionCard(title: "当前角色", rows: [
                ("角色", "博主"),
                ("音色", "vanselee 参考音色"),
                ("语速", "1.05x"),
                ("音量", "0 dB"),
                ("音调", "默认")
            ])
        }
    }
}

private struct RoleReviewView: View {
    var body: some View {
        AppPageScaffold(title: "角色确认", subtitle: "批量处理候选角色、相似名和未标记文本。") {
            VStack(spacing: 10) {
                ReviewRow(role: "旁白", text: "你永远都搞不清楚这些平台到底要什么，不要什么。", action: "试听")
                ReviewRow(role: "博主", text: "发到了 A 平台呢，正常通过。", action: "重生成")
                ReviewRow(role: "未标记", text: "所以做内容不能只看播放量。", action: "选音色")
            }
        } sidebar: {
            ActionCard(title: "确认结果", rows: [
                ("候选角色", "4"),
                ("相似名", "1 组"),
                ("未标记", "1 段")
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
    var body: some View {
        AppPageScaffold(title: "任务队列", subtitle: "主队列以文案为单位；详情区展示当前文案的段落队列。") {
            VStack(alignment: .leading, spacing: 12) {
                Text("平台规则吐槽 · 12 段 · 已完成 5 段 · 失败 1 段 · 剩余约 2 分钟")
                    .font(.headline)
                ProgressView(value: 0.42)
                Table(sampleSegments) {
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
                QueueCard(title: "平台规则吐槽", detail: "12 段 · 完成 5 · 失败 1", active: true)
                QueueCard(title: "直播间脚本", detail: "18 段 · 等待模型下载", active: false)
            }
        }
    }
}

private struct ExportSettingsView: View {
    var body: some View {
        AppPageScaffold(title: "导出与设置", subtitle: "导出完整成品音频，首次默认 Downloads。") {
            VStack(spacing: 12) {
                ActionCard(title: "导出预览", rows: [
                    ("文件名", "平台规则吐槽_20260430_231500.wav"),
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

private struct ScriptRow: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let status: String
    let roleSegments: String
    let updatedAt: String
    let lastExportedAt: String
}

private struct SegmentRow: Identifiable {
    let id = UUID()
    let index: String
    let role: String
    let voice: String
    let status: String
    let action: String
}

private let sampleScripts = [
    ScriptRow(title: "平台规则吐槽", subtitle: "短视频口播", status: "已生成", roleSegments: "3 / 12", updatedAt: "今天 10:48", lastExportedAt: "今天 11:15"),
    ScriptRow(title: "直播间脚本", subtitle: "老板 · 客服 · 旁白", status: "生成中 62%", roleSegments: "3 / 18", updatedAt: "昨天 21:40", lastExportedAt: "未导出"),
    ScriptRow(title: "短视频开头库", subtitle: "开场白集合", status: "未生成", roleSegments: "1 / 32", updatedAt: "2026-04-29", lastExportedAt: "未导出"),
    ScriptRow(title: "售后争议案例", subtitle: "案例复盘", status: "有失败", roleSegments: "4 / 21", updatedAt: "2026-04-30", lastExportedAt: "2026-04-29")
]

private let sampleSegments = [
    SegmentRow(index: "01", role: "旁白", voice: "默认女声", status: "完成", action: "试听"),
    SegmentRow(index: "02", role: "博主", voice: "vanselee", status: "生成中", action: "暂停"),
    SegmentRow(index: "03", role: "博主", voice: "vanselee", status: "等待", action: "跳过"),
    SegmentRow(index: "04", role: "旁白", voice: "默认女声", status: "等待", action: "跳过"),
    SegmentRow(index: "05", role: "质疑者", voice: "自然男声", status: "失败", action: "重试")
]

#Preview {
    ContentView()
}

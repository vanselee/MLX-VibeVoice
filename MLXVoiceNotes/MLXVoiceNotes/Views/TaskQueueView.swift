import SwiftUI
import SwiftData

struct TaskQueueView: View {
    @Query private var voiceProfiles: [VoiceProfile]
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

        GenerationService.resume(script: script, voiceProfiles: voiceProfiles)
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
        GenerationService.retryFailedSegments(script: script, voiceProfiles: voiceProfiles)
    }

    private func retrySegment(_ segment: ScriptSegment) {
        guard let script = selectedScript else { return }
        GenerationService.retry(segment: segment, in: script, voiceProfiles: voiceProfiles)
    }
}

#Preview {
    TaskQueueView(scripts: [], selectedScriptID: .constant(nil))
        .modelContainer(for: [
            Script.self,
            ScriptSegment.self,
            VoiceRole.self,
            VoiceProfile.self,
            GenerationJob.self,
            ExportRecord.self
        ], inMemory: true)
}

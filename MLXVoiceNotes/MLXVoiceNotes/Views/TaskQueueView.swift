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
        AppPageScaffold(title: String(localized: LocalizedStringKey("taskQueue.title")), subtitle: String(localized: LocalizedStringKey("taskQueue.subtitle"))) {
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

                    Button(String(localized: LocalizedStringKey("taskQueue.pause"))) {
                        pauseSelectedTask()
                    }
                    .disabled(selectedScript?.status != .generating)

                    Button(String(localized: LocalizedStringKey("taskQueue.cancelTask"))) {
                        cancelSelectedTask()
                    }
                    .disabled(selectedScript == nil)

                    Button(String(localized: LocalizedStringKey("taskQueue.retryFailed"))) {
                        retryFailedSegments()
                    }
                    .disabled(failedCount == 0)

                    Spacer()
                }

                VStack(spacing: 8) {
                    HStack {
                        Text(String(localized: LocalizedStringKey("taskQueue.segment"))).frame(width: 36, alignment: .leading)
                        Text(String(localized: LocalizedStringKey("taskQueue.role"))).frame(width: 60, alignment: .leading)
                        Text(String(localized: LocalizedStringKey("taskQueue.voice"))).frame(minWidth: 80, maxWidth: 140, alignment: .leading)
                        Text(String(localized: LocalizedStringKey("taskQueue.status"))).frame(width: 56, alignment: .leading)
                        Text(String(localized: LocalizedStringKey("taskQueue.text"))).frame(maxWidth: .infinity, alignment: .leading)
                        Text(String(localized: LocalizedStringKey("taskQueue.action"))).frame(width: 56, alignment: .trailing)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                    if segmentRows.isEmpty {
                        ContentUnavailableView(String(localized: LocalizedStringKey("taskQueue.noSegments")), systemImage: "list.bullet.rectangle")
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
                Text(String(localized: LocalizedStringKey("taskQueue.scriptTasks"))).font(.headline)
                if taskScripts.isEmpty {
                    Text(String(localized: LocalizedStringKey("taskQueue.noTasks"))).foregroundStyle(.secondary)
                } else {
                    ForEach(taskScripts) { script in
                        Button {
                            selectedScriptID = script.id
                        } label: {
                            QueueCard(
                                title: script.title,
                                detail: String(localized: LocalizedStringKey("taskQueue.taskCardStatus", defaultValue: "\(script.status.displayName) · \(script.segments.count) 段 · 完成 \(completedCount(for: script)) · 失败 \(failedCount(for: script))", comment: "Task card status with counts")),
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
        guard let script = selectedScript else { return String(localized: LocalizedStringKey("taskQueue.noScriptTasks")) }
        return String(localized: LocalizedStringKey("taskQueue.queueSummary", defaultValue: "\(script.title) · \(script.status.displayName) · \(script.segments.count) 段 · 已完成 \(completedCount) 段 · 失败 \(failedCount) 段；最终只导出整篇完整音频。", comment: "Queue summary with script info"))
    }

    private var primaryActionTitle: String {
        guard let script = selectedScript else { return String(localized: LocalizedStringKey("taskQueue.continueGenerate")) }
        return switch script.status {
        case .generating: String(localized: LocalizedStringKey("taskQueue.autoGenerating"))
        case .completed: String(localized: LocalizedStringKey("taskQueue.regenerate"))
        case .failed: String(localized: LocalizedStringKey("taskQueue.retryFailed"))
        case .draft, .ready: String(localized: LocalizedStringKey("taskQueue.continueGenerate"))
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
                voice: script.roles.first { $0.normalizedName == segment.roleName }?.defaultVoiceName ?? String(localized: LocalizedStringKey("taskQueue.defaultNarrator")),
                status: segment.status.displayName,
                text: segment.text,
                action: segment.status == .failed ? String(localized: LocalizedStringKey("taskQueue.retry")) : String(localized: LocalizedStringKey("taskQueue.preview"))
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

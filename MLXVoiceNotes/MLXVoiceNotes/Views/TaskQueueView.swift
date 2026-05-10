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
        AppPageScaffold(titleKey: "taskQueue.title", subtitleKey: "taskQueue.subtitle") {
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

                    Button(LocalizedStringKey("taskQueue.pause")) {
                        pauseSelectedTask()
                    }
                    .disabled(selectedScript?.status != .generating)

                    Button(LocalizedStringKey("taskQueue.cancelTask")) {
                        cancelSelectedTask()
                    }
                    .disabled(selectedScript == nil)

                    Button(LocalizedStringKey("taskQueue.retryFailed")) {
                        retryFailedSegments()
                    }
                    .disabled(failedCount == 0)

                    Spacer()
                }

                VStack(spacing: 8) {
                    HStack {
                        Text(LocalizedStringKey("taskQueue.segment")).frame(width: 36, alignment: .leading)
                        Text(LocalizedStringKey("taskQueue.role")).frame(width: 60, alignment: .leading)
                        Text(LocalizedStringKey("taskQueue.voice")).frame(minWidth: 80, maxWidth: 140, alignment: .leading)
                        Text(LocalizedStringKey("taskQueue.status")).frame(width: 56, alignment: .leading)
                        Text(LocalizedStringKey("taskQueue.text")).frame(maxWidth: .infinity, alignment: .leading)
                        Text(LocalizedStringKey("taskQueue.action")).frame(width: 56, alignment: .trailing)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                    if segmentRows.isEmpty {
                        ContentUnavailableView(LocalizedStringKey("taskQueue.noSegments"), systemImage: "list.bullet.rectangle")
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
                Text(LocalizedStringKey("taskQueue.scriptTasks")).font(.headline)
                if taskScripts.isEmpty {
                    Text(LocalizedStringKey("taskQueue.noTasks")).foregroundStyle(.secondary)
                } else {
                    ForEach(taskScripts) { script in
                        Button {
                            selectedScriptID = script.id
                        } label: {
                            QueueCard(
                                title: script.title,
                                detail: String(format: String(localized: "taskQueue.taskCardStatus"), script.status.displayName, script.segments.count, completedCount(for: script), failedCount(for: script)),
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
        guard let script = selectedScript else { return String(localized: "taskQueue.noScriptTasks") }
        return String(format: String(localized: "taskQueue.queueSummary"), script.title, script.status.displayName, script.segments.count, completedCount, failedCount)
    }

    private var primaryActionTitle: String {
        guard let script = selectedScript else { return String(localized: "taskQueue.continueGenerate") }
        return switch script.status {
        case .generating: String(localized: "taskQueue.autoGenerating")
        case .completed: String(localized: "taskQueue.regenerate")
        case .failed: String(localized: "taskQueue.retryFailed")
        case .draft, .ready: String(localized: "taskQueue.continueGenerate")
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
                voice: script.roles.first { $0.normalizedName == segment.roleName }?.defaultVoiceName ?? String(localized: "taskQueue.defaultNarrator"),
                status: segment.status.displayName,
                text: segment.text,
                action: segment.status == .failed ? String(localized: "taskQueue.retry") : String(localized: "taskQueue.preview")
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

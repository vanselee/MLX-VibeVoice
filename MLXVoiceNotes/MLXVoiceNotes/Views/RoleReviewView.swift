import SwiftUI
import SwiftData

struct RoleReviewView: View {
    @Query private var voiceProfiles: [VoiceProfile]
    let script: Script?

    private var availableVoices: [String] {
        let allowedStatuses: Set<VoiceProfileStatus> = [.builtIn, .available]
        return voiceProfiles
            .filter { allowedStatuses.contains($0.status) }
            .map(\.name)
    }

    var body: some View {
        AppPageScaffold(title: String(localized: LocalizedStringKey("roleReview.title")), subtitle: String(localized: LocalizedStringKey("roleReview.subtitle"))) {
            if let script {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(String(localized: LocalizedStringKey("roleReview.roleVoiceBinding")))
                                .font(.headline)
                            ForEach(script.roles.sorted { $0.normalizedName < $1.normalizedName }) { role in
                                RoleVoiceBindingRow(role: role, availableVoices: availableVoices) {
                                    script.updatedAt = .now
                                }
                            }
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 10) {
                            Text(String(localized: LocalizedStringKey("roleReview.segmentPreview")))
                                .font(.headline)
                            if script.segments.isEmpty {
                                ContentUnavailableView(String(localized: LocalizedStringKey("roleReview.noSegments")), systemImage: "text.badge.checkmark")
                            } else {
                                ForEach(script.segments.sorted { $0.order < $1.order }) { segment in
                                    ReviewRow(role: segment.roleName, text: segment.text, action: segment.status == .failed ? String(localized: LocalizedStringKey("roleReview.regenerate")) : String(localized: LocalizedStringKey("taskQueue.preview")))
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            } else {
                ContentUnavailableView(String(localized: LocalizedStringKey("roleReview.noSegments")), systemImage: "text.badge.checkmark")
            }
        } sidebar: {
            ActionCard(title: String(localized: LocalizedStringKey("roleReview.confirmResult")), rows: [
                (String(localized: LocalizedStringKey("roleReview.candidateRoles")), "\(script?.roles.count ?? 0)"),
                (String(localized: LocalizedStringKey("roleReview.voicesBound")), "\(script?.roles.filter { !$0.defaultVoiceName.isEmpty }.count ?? 0)"),
                (String(localized: LocalizedStringKey("roleReview.similarNames")), "0 组"),
                (String(localized: LocalizedStringKey("roleReview.unmarked")), "0 段")
            ])
        }
    }
}

struct RoleVoiceBindingRow: View {
    let role: VoiceRole
    let availableVoices: [String]
    let onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(role.name)
                        .fontWeight(.semibold)
                    Text("\(role.speed.formatted(.number.precision(.fractionLength(2))))x · \(role.volumeDB.formatted(.number.precision(.fractionLength(0)))) dB")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .frame(minWidth: 80, alignment: .leading)

                Picker(String(localized: LocalizedStringKey("taskQueue.voice")), selection: voiceBinding) {
                    ForEach(availableVoices, id: \.self) { voice in
                        Text(voice).tag(voice)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 200)

                Spacer()
            }
            HStack(spacing: 12) {
                Slider(value: speedBinding, in: 0.75...1.5) {
                    Text(String(localized: LocalizedStringKey("roleReview.speed")))
                }
                .frame(maxWidth: 160)

                Button(String(localized: LocalizedStringKey("taskQueue.preview"))) {}
                Spacer()
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var voiceBinding: Binding<String> {
        Binding {
            role.defaultVoiceName
        } set: { value in
            role.defaultVoiceName = value
            onChange()
        }
    }

    private var speedBinding: Binding<Double> {
        Binding {
            role.speed
        } set: { value in
            role.speed = value
            onChange()
        }
    }
}

#Preview {
    RoleReviewView(script: nil)
        .modelContainer(for: [
            Script.self,
            ScriptSegment.self,
            VoiceRole.self,
            VoiceProfile.self,
            GenerationJob.self,
            ExportRecord.self
        ], inMemory: true)
}

import SwiftUI
import SwiftData
import AVFoundation

struct CreateVoiceProfileView: View {
    let onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var voiceName = ""
    @State private var referenceAudioPath = ""
    @State private var referenceText = ""
    @State private var testSentence = "这是一个用于确认音色效果的测试句。"
    @State private var showHelp = false
    @State private var showFileImporter = false
    @State private var hasTestAudio = false
    @State private var nameError = false
    @State private var refAudioError = false
    @State private var refTextError = false
    @State private var saveError: String?
    /// 当前正在编辑的 VoiceProfile ID（保存后或已存在时有效）
    @State private var currentProfileID: UUID?

    // MARK: - Test audio state
    @State private var isGeneratingTest = false
    @State private var testAudioError: String?
    @State private var testAudioPath: String?
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying = false
    private let mlxService = MLXAudioService.shared

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(LocalizedStringKey("createVoice.title"))
                    .font(.headline)
                Spacer()
                if let err = saveError {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Button(LocalizedStringKey("createVoice.cancel")) { onDismiss() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button(LocalizedStringKey("createVoice.saveVoice")) { saveVoice() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top) {
                        Text(LocalizedStringKey("createVoice.description"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            showHelp.toggle()
                        } label: {
                            Text("?")
                                .font(.caption.bold())
                                .frame(width: 22, height: 22)
                                .background(Circle().stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showHelp, arrowEdge: .top) {
                            VStack(alignment: .leading, spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(LocalizedStringKey("createVoice.step1Import")).font(.caption.bold())
                                    Text(LocalizedStringKey("createVoice.step1Hint")).font(.caption2).foregroundStyle(.secondary)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(LocalizedStringKey("createVoice.step2Verify")).font(.caption.bold())
                                    Text(LocalizedStringKey("createVoice.step2Hint")).font(.caption2).foregroundStyle(.secondary)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(LocalizedStringKey("createVoice.step3Test")).font(.caption.bold())
                                    Text(LocalizedStringKey("createVoice.step3Hint")).font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                            .padding(12)
                            .frame(width: 220)
                        }
                    }

                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 14) {
                            formCard {
                                Text(LocalizedStringKey("createVoice.voiceName")).font(.subheadline.bold())
                                TextField(String(localized: "createVoice.enterVoiceName"), text: $voiceName)
                                    .textFieldStyle(.roundedBorder)
                                    .border(nameError ? Color.red : Color.clear)
                                    .onChange(of: voiceName) { nameError = false }
                                if nameError {
                                    Text(LocalizedStringKey("createVoice.pleaseEnterName"))
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                            }

                            formCard {
                                Text(LocalizedStringKey("createVoice.referenceAudio")).font(.subheadline.bold())
                                if referenceAudioPath.isEmpty {
                                    HStack {
                                        TextField(String(localized: "createVoice.noAudioSelected"), text: .constant(""))
                                            .textFieldStyle(.roundedBorder)
                                            .disabled(true)
                                        Button(LocalizedStringKey("createVoice.selectFile")) { showFileImporter = true }
                                            .buttonStyle(.bordered)
                                            .controlSize(.small)
                                    }
                                } else {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(URL(fileURLWithPath: referenceAudioPath).lastPathComponent)
                                            .font(.subheadline)
                                        HStack(spacing: 8) {
                                            Button(LocalizedStringKey("createVoice.replaceAudio")) { showFileImporter = true }
                                                .buttonStyle(.bordered)
                                                .controlSize(.small)
                                            Button(LocalizedStringKey("createVoice.previewOriginal")) { }
                                                .buttonStyle(.bordered)
                                                .controlSize(.small)
                                        }
                                    }
                                    .padding(10)
                                    .background(Color(nsColor: .controlBackgroundColor))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                            }

                            formCard {
                                HStack {
                                    Text(LocalizedStringKey("createVoice.referenceText")).font(.subheadline.bold())
                                    Spacer()
                                    Button(LocalizedStringKey("createVoice.autoTranscribe")) { }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                        .disabled(true)
                                }
                                TextEditor(text: $referenceText)
                                    .font(.body)
                                    .frame(minHeight: 100, maxHeight: 160)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 5)
                                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                                    )
                                    .overlay(alignment: .topLeading) {
                                        if referenceText.isEmpty {
                                            Text(LocalizedStringKey("createVoice.enterReferenceText"))
                                                .font(.body)
                                                .foregroundStyle(.tertiary)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 8)
                                                .allowsHitTesting(false)
                                        }
                                    }
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            formCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(LocalizedStringKey("createVoice.testAndSave")).font(.subheadline.bold())

                                    HStack {
                                        Text(LocalizedStringKey("createVoice.cloneMode"))
                                            .font(.caption).foregroundStyle(.secondary)
                                        Spacer()
                                        Text(LocalizedStringKey("createVoice.localFirst"))
                                            .font(.caption)
                                    }
                                    Divider()
                                    HStack {
                                        Text(LocalizedStringKey("createVoice.modelStatus"))
                                            .font(.caption).foregroundStyle(.secondary)
                                        Spacer()
                                        Text(LocalizedStringKey("createVoice.toBeVerified"))
                                            .font(.caption)
                                    }
                                    Divider()

                                    Text(LocalizedStringKey("createVoice.testSentence")).font(.caption.bold())
                                    TextEditor(text: $testSentence)
                                        .font(.caption)
                                        .frame(minHeight: 56, maxHeight: 80)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 5)
                                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                                        )

                                    HStack(spacing: 8) {
                                        Button(LocalizedStringKey("createVoice.generateTestAudio")) {
                                            generateTestAudio()
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                        .disabled(isGeneratingTest || referenceAudioPath.isEmpty || referenceText.isEmpty)

                                        Button(LocalizedStringKey("createVoice.previewResult")) {
                                            playTestAudio()
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                        .disabled(!hasTestAudio || isGeneratingTest)
                                    }

                                    if isGeneratingTest {
                                        HStack(spacing: 4) {
                                            ProgressView()
                                                .controlSize(.small)
                                            Text(LocalizedStringKey("createVoice.generating"))
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    } else if let err = testAudioError {
                                        Text(err)
                                            .font(.caption)
                                            .foregroundStyle(.red)
                                    } else if hasTestAudio {
                                        Text(LocalizedStringKey("createVoice.testAudioGenerated"))
                                            .font(.caption)
                                            .foregroundStyle(.green)
                                    }
                                }
                            }

                            formCard {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(LocalizedStringKey("createVoice.afterSave"))
                                        .font(.caption.bold())
                                    Text(LocalizedStringKey("createVoice.afterSaveHint"))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .frame(width: 240)
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 680, height: 520)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    referenceAudioPath = url.path
                }
            case .failure:
                break
            }
        }
    }

    private func saveVoice() {
        // 1. 校验必填项
        let trimmed = voiceName.trimmingCharacters(in: .whitespacesAndNewlines)
        let refAudioTrimmed = referenceAudioPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let refTextTrimmed = referenceText.trimmingCharacters(in: .whitespacesAndNewlines)

        nameError = trimmed.isEmpty
        refAudioError = refAudioTrimmed.isEmpty
        refTextError = refTextTrimmed.isEmpty

        if nameError || refAudioError || refTextError {
            saveError = String(localized: "createVoice.pleaseFillRequired")
            return
        }
        saveError = nil

        // 2. 如果当前有测试音频，先持久化
        if hasTestAudio, let tempPath = testAudioPath {
            Task {
                // 确保音色档案已就绪（会创建 profile 或复用已有 profile）
                do {
                    let profile = try await ensureCurrentVoiceProfileReadyForCreation()
                    let tempURL = URL(fileURLWithPath: tempPath)
                    _ = try VoiceProfileStorageService.shared.persistTestAudio(from: tempURL, for: profile.id)
                    profile.isVerifiedForGeneration = true
                    profile.lastTestedAt = Date()
                    try modelContext.save()
                    print("[saveVoice] 测试音频已持久化，profile.isVerifiedForGeneration = true")
                    await MainActor.run {
                        self.onDismiss()
                    }
                } catch {
                    await MainActor.run {
                        self.saveError = String(format: String(localized: "createVoice.saveFailed"), error.localizedDescription)
                    }
                }
            }
        } else {
            // 无测试音频，同样走统一流程
            Task {
                do {
                    _ = try await ensureCurrentVoiceProfileReadyForCreation()
                    await MainActor.run {
                        self.onDismiss()
                    }
                } catch {
                    await MainActor.run {
                        self.saveError = String(format: String(localized: "createVoice.saveFailed"), error.localizedDescription)
                    }
                }
            }
        }
    }

    // MARK: - Test Audio Logic

    private func generateTestAudio() {
        guard !referenceAudioPath.isEmpty, !referenceText.isEmpty else { return }
        isGeneratingTest = true
        testAudioError = nil
        hasTestAudio = false
        testAudioPath = nil

        Task {
            do {
                // Step 1: 确保音色档案已就绪，获取持久化的 referenceAudioPath
                let profile = try await ensureCurrentVoiceProfileReadyForCreation()
                print("[generateTestAudio] profile ready: id=\(profile.id) refPath=\(profile.referenceAudioPath ?? "nil")")

                // Step 2: 用持久化的参考音频路径生成测试音频
                guard let refPath = profile.referenceAudioPath else {
                    throw VoiceProfileStorageService.ReadinessError.emptyReferenceAudioPath
                }
                let refURL = VoiceProfileStorageService.shared.absoluteURL(from: refPath)

                let tempURL = try await mlxService.generateAudio(
                    text: testSentence,
                    refAudioURL: refURL,
                    refText: referenceText,
                    language: "auto"
                )
                await MainActor.run {
                    testAudioPath = tempURL.path
                    hasTestAudio = true
                    isGeneratingTest = false
                }
            } catch {
                await MainActor.run {
                    testAudioError = String(format: String(localized: "createVoice.generationFailed"), error.localizedDescription)
                    isGeneratingTest = false
                }
            }
        }
    }

    private func playTestAudio() {
        guard let path = testAudioPath else { return }
        let url = URL(fileURLWithPath: path)
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
            isPlaying = true
        } catch {
            testAudioError = String(format: String(localized: "createVoice.playbackFailed"), error.localizedDescription)
        }
    }

    // MARK: - Unified Voice Profile Readiness

    /// 统一入口：确保当前音色档案已完成资产准备。
    /// - 如果当前无 profile（未保存），自动创建 VoiceProfile（status=.pendingReview）并持久化参考音频
    /// - 保存 referenceText
    /// - 调用 ensureVoiceProfileReady() 完成校验，校验成功后 status → .available
    /// - 返回可用 VoiceProfile
    /// - 失败时 status → .failed，避免资源中心永久显示"创建中"
    private func ensureCurrentVoiceProfileReadyForCreation() async throws -> VoiceProfile {
        let trimmed = voiceName.trimmingCharacters(in: .whitespacesAndNewlines)
        let refAudioTrimmed = referenceAudioPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let refTextTrimmed = referenceText.trimmingCharacters(in: .whitespacesAndNewlines)

        // A. 已有 profile（保存过或从其他操作创建过）
        if let existingID = currentProfileID {
            let descriptor = FetchDescriptor<VoiceProfile>(predicate: #Predicate { $0.id == existingID })
            guard let profile = try modelContext.fetch(descriptor).first else {
                throw VoiceProfileStorageService.ReadinessError.profileNotFound
            }
            return try await VoiceProfileStorageService.shared.ensureVoiceProfileReady(
                profileID: profile.id,
                context: modelContext
            )
        }

        // B. 无 profile，需要新建
        let profile = VoiceProfile(
            name: trimmed,
            kind: .reference,
            source: .localAudio,
            status: .pendingReview,
            referenceAudioPath: nil,
            referenceText: refTextTrimmed,
            isVerifiedForGeneration: false,
            lastTestedAt: nil
        )
        print("[ensureCurrentVoiceProfileReadyForCreation] 创建临时 profile id=\(profile.id)")

        // 持久化参考音频
        let sourceURL = URL(fileURLWithPath: refAudioTrimmed)
        let storedURL = try VoiceProfileStorageService.shared.persistReferenceAudio(
            sourceURL: sourceURL,
            for: profile.id
        )
        profile.referenceAudioPath = VoiceProfileStorageService.shared.relativePath(from: storedURL)
        print("[ensureCurrentVoiceProfileReadyForCreation] 参考音频已存储: \(profile.referenceAudioPath ?? "nil")")

        // 写入 SwiftData
        modelContext.insert(profile)
        try modelContext.save()

        // 记录当前 profile ID
        currentProfileID = profile.id

        // 调用统一校验链
        return try await VoiceProfileStorageService.shared.ensureVoiceProfileReady(
            profileID: profile.id,
            context: modelContext
        )
    }

    private func formCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
            VStack(alignment: .leading, spacing: 6) {
                content()
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 1)
            )
    }
}

#Preview {
    CreateVoiceProfileView(onDismiss: {})
        .modelContainer(for: [
            Script.self,
            ScriptSegment.self,
            VoiceRole.self,
            VoiceProfile.self,
            GenerationJob.self,
            ExportRecord.self
        ], inMemory: true)
}

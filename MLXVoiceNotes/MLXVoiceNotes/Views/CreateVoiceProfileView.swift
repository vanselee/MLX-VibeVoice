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
                Text("创建音色")
                    .font(.headline)
                Spacer()
                if let err = saveError {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Button("取消") { onDismiss() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button("保存音色") { saveVoice() }
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
                        Text("导入参考音频，校对参考文本，生成测试音频后保存为可复用音色。")
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
                                    Text("1. 导入参考音频").font(.caption.bold())
                                    Text("建议 10-30 秒，单人声，低噪声").font(.caption2).foregroundStyle(.secondary)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("2. 校对参考文本").font(.caption.bold())
                                    Text("文字越准确，音色测试越稳定").font(.caption2).foregroundStyle(.secondary)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("3. 生成测试音频").font(.caption.bold())
                                    Text("确认效果后保存为可复用音色").font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                            .padding(12)
                            .frame(width: 220)
                        }
                    }

                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 14) {
                            formCard {
                                Text("音色名称").font(.subheadline.bold())
                                TextField("输入音色名称", text: $voiceName)
                                    .textFieldStyle(.roundedBorder)
                                    .border(nameError ? Color.red : Color.clear)
                                    .onChange(of: voiceName) { nameError = false }
                                if nameError {
                                    Text("请输入音色名称")
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                            }

                            formCard {
                                Text("参考音频").font(.subheadline.bold())
                                if referenceAudioPath.isEmpty {
                                    HStack {
                                        TextField("未选择音频文件", text: .constant(""))
                                            .textFieldStyle(.roundedBorder)
                                            .disabled(true)
                                        Button("选择文件...") { showFileImporter = true }
                                            .buttonStyle(.bordered)
                                            .controlSize(.small)
                                    }
                                } else {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(URL(fileURLWithPath: referenceAudioPath).lastPathComponent)
                                            .font(.subheadline)
                                        HStack(spacing: 8) {
                                            Button("替换音频") { showFileImporter = true }
                                                .buttonStyle(.bordered)
                                                .controlSize(.small)
                                            Button("试听原音频") { }
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
                                    Text("参考文本").font(.subheadline.bold())
                                    Spacer()
                                    Button("自动转写") { }
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
                                            Text("输入或粘贴参考文本...")
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
                                    Text("测试与保存").font(.subheadline.bold())

                                    HStack {
                                        Text("克隆模式")
                                            .font(.caption).foregroundStyle(.secondary)
                                        Spacer()
                                        Text("本地优先")
                                            .font(.caption)
                                    }
                                    Divider()
                                    HStack {
                                        Text("模型状态")
                                            .font(.caption).foregroundStyle(.secondary)
                                        Spacer()
                                        Text("待验证")
                                            .font(.caption)
                                    }
                                    Divider()

                                    Text("测试句").font(.caption.bold())
                                    TextEditor(text: $testSentence)
                                        .font(.caption)
                                        .frame(minHeight: 56, maxHeight: 80)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 5)
                                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                                        )

                                    HStack(spacing: 8) {
                                        Button("生成测试音频") {
                                            generateTestAudio()
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                        .disabled(isGeneratingTest || referenceAudioPath.isEmpty || referenceText.isEmpty)

                                        Button("试听结果") {
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
                                            Text("生成中...")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    } else if let err = testAudioError {
                                        Text(err)
                                            .font(.caption)
                                            .foregroundStyle(.red)
                                    } else if hasTestAudio {
                                        Text("测试音频已生成")
                                            .font(.caption)
                                            .foregroundStyle(.green)
                                    }
                                }
                            }

                            formCard {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("保存后")
                                        .font(.caption.bold())
                                    Text("新音色会进入资源中心的音色库，并出现在文案列表的角色音色下拉菜单中。")
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
        // 1. 校验
        let trimmed = voiceName.trimmingCharacters(in: .whitespacesAndNewlines)
        let refAudioTrimmed = referenceAudioPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let refTextTrimmed = referenceText.trimmingCharacters(in: .whitespacesAndNewlines)

        nameError = trimmed.isEmpty
        refAudioError = refAudioTrimmed.isEmpty
        refTextError = refTextTrimmed.isEmpty

        if nameError || refAudioError || refTextError {
            saveError = "请填写必填项"
            return
        }
        saveError = nil

        // 2. 创建 VoiceProfile 对象（此时无 referenceAudioPath）
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
        print("[saveVoice] 创建 VoiceProfile id=\(profile.id) name=\(trimmed)")

        // 3. 复制参考音频到 VoiceProfiles/<id>/reference.<ext>
        let sourceURL = URL(fileURLWithPath: refAudioTrimmed)
        do {
            let storedURL = try VoiceProfileStorageService.shared.persistReferenceAudio(
                sourceURL: sourceURL,
                for: profile.id
            )
            profile.referenceAudioPath = VoiceProfileStorageService.shared.relativePath(from: storedURL)
            print("[saveVoice] 参考音频已存储: \(profile.referenceAudioPath ?? "nil")")
        } catch {
            let errMsg = "保存参考音频失败: \(error.localizedDescription)"
            print("[saveVoice] \(errMsg)")
            saveError = errMsg
            return
        }

        // 4. 写入 SwiftData（isVerifiedForGeneration = hasTestAudio）
        modelContext.insert(profile)
        
        // 5. 生成测试音频并持久化
        if hasTestAudio, let tempPath = testAudioPath {
            let tempURL = URL(fileURLWithPath: tempPath)
            do {
                _ = try VoiceProfileStorageService.shared.persistTestAudio(from: tempURL, for: profile.id)
                profile.isVerifiedForGeneration = true
                profile.lastTestedAt = Date()
            } catch {
                let errMsg = "保存测试音频失败: \(error.localizedDescription)"
                print("[saveVoice] \(errMsg)")
                saveError = errMsg
            }
        }
        
        // 6. 必须显式保存，保存成功才关闭窗口
        do {
            try modelContext.save()
            print("[saveVoice] 保存成功 id=\(profile.id) name=\(profile.name) refPath=\(profile.referenceAudioPath ?? "nil")")
            onDismiss()
        } catch {
            let errMsg = "保存音色失败: \(error.localizedDescription)"
            print("[saveVoice] \(errMsg)")
            saveError = errMsg
            // 不调用 onDismiss()，窗口保持，用户可修改后重试
        }
    }

    // MARK: - Test Audio Logic

    private func generateTestAudio() {
        guard !referenceAudioPath.isEmpty, !referenceText.isEmpty else { return }
        let refURL = URL(fileURLWithPath: referenceAudioPath)
        guard FileManager.default.fileExists(atPath: refURL.path) else {
            testAudioError = "参考音频文件不存在"
            return
        }
        isGeneratingTest = true
        testAudioError = nil
        hasTestAudio = false
        testAudioPath = nil

        Task {
            do {
                let tempURL = try await mlxService.generateAudio(
                    text: testSentence,
                    refAudioURL: refURL,
                    refText: referenceText,
                    language: "chinese"
                )
                await MainActor.run {
                    testAudioPath = tempURL.path
                    hasTestAudio = true
                    isGeneratingTest = false
                }
            } catch {
                await MainActor.run {
                    testAudioError = "生成失败: \(error.localizedDescription)"
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
            testAudioError = "播放失败: \(error.localizedDescription)"
        }
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

import SwiftUI
import AVFoundation

struct MLXTestView: View {
    @ObservedObject private var mlxService = MLXAudioService.shared
    @State private var testText: String = "你好，这是 MLX Voice Notes 的本地语音合成测试。"
    @State private var selectedVoice: String = "default"
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying: Bool = false
    @State private var generatedURL: URL?
    @State private var phase2TestResults: String = ""
#if canImport(MLXAudioTTS)
    @State private var showModelPicker: Bool = false
#endif

    var body: some View {
        VStack(spacing: 16) {
            header
            Divider()
            formSection
            if let generatedURL {
                resultSection(url: generatedURL)
            }
            Spacer()
            footerSection
        }
        .padding()
        .frame(width: 650, height: 500)
        .task {
            await mlxService.ensureModelLoaded()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Phase 0: MLX TTS Test").font(.title2).fontWeight(.bold)
#if canImport(MLXAudioTTS)
                Spacer()
                Button(action: { showModelPicker.toggle() }) {
                    HStack(spacing: 4) {
                        Text(mlxService.currentModelName)
                        Image(systemName: "chevron.down")
                    }
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.2))
                    .clipShape(Capsule())
                }
                .popover(isPresented: $showModelPicker) {
                    modelPickerPopover
                }
#endif
            }
            HStack(spacing: 12) {
                StatusBadgeText(
                    text: mlxService.isModelLoaded ? "Model Ready" : "Loading...",
                    color: mlxService.isModelLoaded ? .green : .orange
                )
                StatusBadgeText(
                    text: mlxService.isGenerating ? "Generating..." : "Idle",
                    color: mlxService.isGenerating ? .blue : .secondary
                )
            }
        }
    }

#if canImport(MLXAudioTTS)
    private var modelPickerPopover: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select Model").font(.headline)
            ForEach(mlxService.availableModels(), id: \.name) { model in
                Button(action: {
                    Task {
                        await mlxService.switchModel(model.name, modelRepo: model.repo)
                    }
                    showModelPicker = false
                }) {
                    HStack {
                        Text(model.name)
                        Spacer()
                        if mlxService.currentModelName == model.name {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)
            }
        }
        .padding()
        .frame(width: 250)
    }
#endif

    private var formSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Test Text").font(.headline)
            TextEditor(text: $testText)
                .font(.body)
                .frame(minHeight: 80, maxHeight: 120)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.5), lineWidth: 1))

            // Voice instruct 输入（Phase 0 对照测试用）
            HStack {
                Text("Voice Instruct:").font(.subheadline)
                TextField("nil = 无 instruct", text: $selectedVoice)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)
                Button("Clear") { selectedVoice = "default" }
                    .buttonStyle(.bordered)
            }

            HStack(spacing: 12) {
                Button("Generate Audio") {
                    Task {
                        await generateAudio()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(mlxService.isGenerating)

#if canImport(MLXAudioTTS)
                Button("Phase 2B: RefAudio Test") {
                    Task {
                        await runPhase2BTest()
                    }
                }
                .buttonStyle(.bordered)
                .disabled(mlxService.isGenerating)
#endif

                if mlxService.isGenerating {
                    ProgressView(value: mlxService.progress)
                        .frame(width: 200)
                }
            }

            if let error = mlxService.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(8)
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            // Phase 2A 测试结果
            if !phase2TestResults.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Phase 2A Results:").font(.caption).fontWeight(.bold)
                    Text(phase2TestResults)
                        .font(.caption).fontDesign(.monospaced)
                        .textSelection(.enabled)
                }
                .padding(8)
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    @ViewBuilder
    private func resultSection(url: URL) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Result").font(.headline)

            HStack(spacing: 12) {
                Text(url.lastPathComponent)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(isPlaying ? "Stop" : "Play") {
                    togglePlayback(url)
                }
                .buttonStyle(.bordered)
            }

            // 诊断信息显示
            if let diag = mlxService.lastDiag {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Diagnostics:").font(.caption).fontWeight(.bold)
                    Text("samples: \(diag.sampleCount), maxAbs: \(String(format: "%.6f", diag.maxAbs)), rms: \(String(format: "%.6f", diag.rms))")
                        .font(.caption).fontDesign(.monospaced)
                    Text("sampleRate: \(diag.sampleRate) Hz, duration: \(String(format: "%.2f", diag.durationSec))s, elapsed: \(String(format: "%.2f", diag.elapsedSec))s")
                        .font(.caption).fontDesign(.monospaced)
                    Text("realtimeFactor: \(String(format: "%.2f", diag.realtimeFactor))x, path: \(diag.filePath)")
                        .font(.caption).fontDesign(.monospaced).lineLimit(1).truncationMode(.middle)
                }
                .padding(8)
                .background(Color.yellow.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            HStack(spacing: 12) {
                Button("Reveal in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
                Spacer()
                Button("Copy to Clipboard") {
#if os(macOS)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.writeObjects([url as NSURL])
#endif
                }
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var footerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Model Info").font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 16) {
                Label("Sample Rate: 24kHz", systemImage: "waveform")
                Label("Format: WAV", systemImage: "doc")
#if canImport(MLXAudioTTS)
                Label("MLX Engine Available", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
#else
                Label("MLX Engine Unavailable (Simulated)", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
#endif
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private func generateAudio() async {
        do {
            let url = try await mlxService.generateAudio(
                text: testText,
                voice: selectedVoice == "default" ? nil : selectedVoice
            )
            await MainActor.run {
                self.generatedURL = url
                self.mlxService.errorMessage = nil
            }
        } catch {
            await MainActor.run {
                self.mlxService.errorMessage = "Error: \(error.localizedDescription)"
            }
        }
    }

#if canImport(MLXAudioTTS)
    private func runPhase2BTest() async {
        do {
            let results = try await mlxService.runRefAudioStabilityTests()
            let summary = results.map { (run, diag) in
                "run#\(run): maxAbs=\(String(format: "%.6f", diag.maxAbs)) rms=\(String(format: "%.6f", diag.rms)) dur=\(String(format: "%.2f", diag.durationSec))s"
            }.joined(separator: "\n")
            await MainActor.run {
                phase2TestResults = summary
                mlxService.errorMessage = nil
            }
        } catch {
            await MainActor.run {
                mlxService.errorMessage = "Phase 2B Error: \(error.localizedDescription)"
            }
        }
    }
#endif

    private func togglePlayback(_ url: URL) {
        if isPlaying {
            audioPlayer?.stop()
            isPlaying = false
        } else {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.play()
                isPlaying = true
            } catch {
                self.mlxService.errorMessage = "Error playing audio: \(error.localizedDescription)"
            }
        }
    }
}

private struct StatusBadgeText: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}

#Preview {
    MLXTestView()
}

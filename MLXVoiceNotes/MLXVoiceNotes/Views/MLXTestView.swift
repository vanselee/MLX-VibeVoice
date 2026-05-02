import SwiftUI
import AVFoundation

struct MLXTestView: View {
    @StateObject private var mlxService = MLXAudioService()
    @State private var testText: String = "Hello, this is a test of the local TTS system."
    @State private var selectedVoice: String = "default"
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying: Bool = false
    @State private var generatedURL: URL?
    @State private var showModelPicker: Bool = false
    @State private var selectedModel: String = "Soprano-80M"

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
            await mlxService.loadModel()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Phase 0: MLX TTS Test").font(.title2).fontWeight(.bold)
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

    private var modelPickerPopover: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select Model").font(.headline)
            ForEach(mlxService.availableModels(), id: \.name) { model in
                Button(action: {
                    Task {
                        await mlxService.switchModel(model.name, modelRepo: model.repo)
                        selectedModel = model.name
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

    private var formSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Test Text").font(.headline)
            TextEditor(text: $testText)
                .font(.body)
                .frame(minHeight: 100, maxHeight: 150)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.5), lineWidth: 1))

            HStack(spacing: 12) {
                Button("Generate Audio") {
                    Task {
                        await generateAudio()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(mlxService.isGenerating || !mlxService.isModelLoaded)

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

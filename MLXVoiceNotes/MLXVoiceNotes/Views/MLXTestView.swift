import SwiftUI
import AVFoundation

// Phase 0: MLX 测试视图
// 此视图用于验证本地 TTS 引擎的功能
// 仅用于开发测试
struct MLXTestView: View {
    @StateObject private var mlxService = MLXAudioService()
    @State private var testText: String = "你好，这是一段测试音频。"
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying: Bool = false
    @State private var generatedURL: URL?

    var body: some View {
        VStack(spacing: 16) {
            header
            Divider()
            formSection
            if let generatedURL {
                resultSection(url: generatedURL)
            }
            Spacer()
        }
        .padding()
        .frame(width: 600, height: 450)
        .task {
            await mlxService.loadModel()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Phase 0: MLX TTS Test").font(.title).fontWeight(.bold)
            HStack(spacing: 12) {
                StatusBadgeText(text: "Model Status", color: mlxService.isModelLoaded ? .green : .secondary)
                StatusBadgeText(text: mlxService.isGenerating ? "Generating..." : "Idle",
                               color: mlxService.isGenerating ? .blue : .secondary)
            }
        }
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
                Text(url.lastPathComponent).font(.body)
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
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func generateAudio() async {
        do {
            let url = try await mlxService.generateAudio(text: testText)
            await MainActor.run {
                self.generatedURL = url
                self.mlxService.errorMessage = nil
            }
        } catch {
            await MainActor.run {
                self.mlxService.errorMessage = "Error generating audio: \(error.localizedDescription)"
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

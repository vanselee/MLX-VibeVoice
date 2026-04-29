# Phase 0 Results

## Environment

- macOS: 26.4.1 (Build 25E253)
- Architecture: arm64
- Mac model: not recorded yet
- Chip: not recorded yet; `sysctl` hardware queries were blocked in the current sandbox
- RAM: not recorded yet; `sysctl` hardware queries were blocked in the current sandbox
- Xcode: full Xcode not active; `xcode-select -p` is `/Library/Developer/CommandLineTools`
- Swift: Apple Swift 6.3.1 (`swift-driver` 1.148.6), target `arm64-apple-macosx26.0`

## Summary

- Local Git repository initialized.
- Git author configured as `vanselee <liyifc@gmail.com>`.
- Initial project planning committed and tagged as `phase0-start`.
- `mlx-audio-swift` cloned locally under ignored `External/mlx-audio-swift`.
- `mlx-audio-swift` HEAD: `dfb938211eb4132966bd703e626c0307a0b4bb44`.
- SwiftPM build of product `mlx-audio-swift-tts` completed successfully.
- Running the TTS executable failed before model download with `Failed to load the default metallib`.

## Findings

- `mlx-audio-swift` exposes a `mlx-audio-swift-tts` executable.
- CLI usage supports `--text`, `--voice`, `--model`, `--output`, `--ref_audio`, `--ref_text`, `--language`, `--timestamps`, and `--benchmark`.
- README lists Qwen3-TTS, Fish Audio S2 Pro, Soprano, VyvoTTS, Orpheus, Marvis TTS, and Pocket TTS as TTS model families.
- Qwen3-TTS Swift README explicitly documents voice cloning with `refAudio` and `refText`.
- Chatterbox Swift README documents voice cloning with `refAudio`.
- `mlx-swift` README states SwiftPM command line cannot build Metal shaders and that Xcode / xcodebuild is required for Metal shader builds.

## Blockers

- Full Xcode is not active. Current active developer directory is Command Line Tools.
- TTS runtime cannot proceed until `default.metallib` is built/available.
- Need to install full Xcode and switch developer directory, for example with `xcode-select`, before continuing MLX runtime validation.

## Decisions

- Keep Swift-native path as primary because the TTS executable builds and Swift-side cloning APIs exist in documentation.
- Treat full Xcode setup as the immediate Phase 0 blocker before attempting model downloads or audio generation.

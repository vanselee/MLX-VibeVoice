# Phase 0 Results

## Environment

- macOS: 26.4.1 (Build 25E253)
- Architecture: arm64
- Mac model: not recorded yet
- Chip: not recorded yet; `sysctl` hardware queries were blocked in the current sandbox
- RAM: not recorded yet; `sysctl` hardware queries were blocked in the current sandbox
- Xcode: 26.4.1 (Build 17E202), active developer directory `/Applications/Xcode.app/Contents/Developer`
- Swift: Apple Swift 6.3.1 (`swift-driver` 1.148.6), target `arm64-apple-macosx26.0`
- Metal Toolchain: downloaded and installed via `xcodebuild -downloadComponent MetalToolchain`; reported build `17E188`

## Summary

- Local Git repository initialized.
- Git author configured as `vanselee <liyifc@gmail.com>`.
- Initial project planning committed and tagged as `phase0-start`.
- `mlx-audio-swift` cloned locally under ignored `External/mlx-audio-swift`.
- `mlx-audio-swift` HEAD: `dfb938211eb4132966bd703e626c0307a0b4bb44`.
- SwiftPM build of product `mlx-audio-swift-tts` completed successfully.
- Initial TTS runtime failed before model download with `Failed to load the default metallib`.
- `mlx.metallib` was manually generated from `mlx-swift` generated Metal sources and placed beside the TTS executable.
- After adding `mlx.metallib`, the TTS executable passed Metal initialization and reached model download.
- Qwen3-TTS and default Marvis TTS validation are currently blocked by unstable Hugging Face downloads rather than local MLX startup.
- Existing local model assets were discovered under MimikaStudio and QwenVoice application support directories.
- A complete existing `mlx-community/Qwen3-TTS-12Hz-0.6B-Base-bf16` snapshot was mapped into the `mlx-audio-swift` cache using absolute symlinks, avoiding a duplicate 2.3 GB copy.
- The mapped bf16 Qwen3-TTS model successfully generated a Chinese WAV file.

## Findings

- `mlx-audio-swift` exposes a `mlx-audio-swift-tts` executable.
- CLI usage supports `--text`, `--voice`, `--model`, `--output`, `--ref_audio`, `--ref_text`, `--language`, `--timestamps`, and `--benchmark`.
- README lists Qwen3-TTS, Fish Audio S2 Pro, Soprano, VyvoTTS, Orpheus, Marvis TTS, and Pocket TTS as TTS model families.
- Qwen3-TTS Swift README explicitly documents voice cloning with `refAudio` and `refText`.
- Chatterbox Swift README documents voice cloning with `refAudio`.
- `mlx-swift` README states SwiftPM command line cannot build Metal shaders and that Xcode / xcodebuild is required for Metal shader builds.
- `mlx-swift` runtime searches for `mlx.metallib` beside the executable before looking for SwiftPM bundle resources.
- SwiftPM built the executable but did not generate or package the Metal shader library.
- The Metal compiler tried to write its module cache under `/Users/apple/.cache/clang/ModuleCache`, which is outside the Codex sandbox.
- Passing `-fmodules-cache-path=/private/tmp/mlx-metal-module-cache` allowed Metal shader compilation to succeed inside the sandbox.
- The generated `mlx.metallib` is about 3.0 MB.
- Default model download failed with `NSURLErrorDomain Code=-1005` (`The network connection was lost`) while fetching from Hugging Face.
- Qwen3-TTS download reached only partial cache state in this run and did not generate output audio.
- Directly symlinking a Hugging Face `snapshots/...` directory is not safe because snapshot contents are relative symlinks; moving the snapshot path breaks those internal links.
- The working mapping approach is: create a real target model directory, then symlink each required file to its absolute resolved source path.
- `mlx-community/Qwen3-TTS-12Hz-0.6B-Base-bf16` generated `phase0-qwen3-bf16-mapped.wav` in about 10 seconds.
- Generated audio properties: WAV, mono, 24 kHz, Float32, about 3.68 seconds, 349 KB.
- Runtime memory for the mapped bf16 model: peak about 5.2 GB, active about 2.4 GB, cache about 256 MB.
- The current 8bit Qwen3-TTS cache contains a partial root `model.safetensors`; it must not be treated as a valid completed model.

## Blockers

- Model downloads from Hugging Face are not stable enough yet to complete first-run TTS validation.
- Need a repeatable model download strategy before app development starts: retry/resume behavior, progress reporting, checksum/state validation, and user-facing failure recovery.
- Need to decide whether Phase 0 should test with a pre-downloaded model cache, a smaller model, or an alternate mirror/proxy if Hugging Face remains unreliable.
- `ModelUtils` currently treats any non-zero `.safetensors` file as enough to consider a model directory present; this is risky for interrupted downloads and should be hardened with expected file size/hash validation.

## Decisions

- Keep Swift-native path as primary because the TTS executable builds and Swift-side cloning APIs exist in documentation.
- Treat full Xcode and Metal Toolchain setup as resolved for the current machine.
- Treat `mlx.metallib` generation/packaging as a real engineering requirement for the future Xcode app target, not a one-off terminal detail.
- Treat model distribution/download robustness as the next immediate Phase 0 risk.
- Add local model reuse as a first-class product capability: users should be able to choose an existing model folder, and the app should store references or symlinks rather than duplicate large model files when possible.
- Keep `0.6B-Base-bf16` as a validated local fallback for Phase 0 Swift-native Qwen3-TTS testing.

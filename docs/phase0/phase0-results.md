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
- A complete existing `mlx-community/Qwen3-TTS-12Hz-0.6B-Base-bf16` snapshot was copied into the project-owned model directory because MimikaStudio may be removed.
- The `mlx-audio-swift` cache entry was rebuilt as a real directory whose files are hard links to the project-owned model files, avoiding a duplicate 2.3 GB copy.
- The project-owned bf16 Qwen3-TTS model successfully generated a Chinese WAV file.

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
- Using a directory symlink as the `mlx-audio-swift` cache entry is also unreliable because `ModelUtils` may judge the cache as incomplete and clear it.
- The working project-owned approach is: store real model files under `MLXVoiceNotesAssets/Models`, create a real cache directory under Hugging Face cache, then hard-link each cache file to the project-owned file.
- `mlx-community/Qwen3-TTS-12Hz-0.6B-Base-bf16` generated `phase0-qwen3-bf16-mapped.wav` in about 10 seconds.
- Generated audio properties: WAV, mono, 24 kHz, Float32, about 3.68 seconds, 349 KB.
- Runtime memory for the mapped bf16 model: peak about 5.2 GB, active about 2.4 GB, cache about 256 MB.
- The project-owned hard-link cache generated `phase0-qwen3-bf16-project-hardlink.wav` in about 4.9 seconds.
- Hard-link verification: project file and cache file share the same inode with link count 2 for both root `model.safetensors` and `speech_tokenizer/model.safetensors`.
- Hard-link generated audio properties: WAV, mono, 24 kHz, Float32, about 3.52 seconds, 334 KB.
- Hard-link runtime memory: peak about 5.15 GB, active about 2.4 GB, cache about 256 MB.
- After MimikaStudio was removed, the project-owned hard-link cache still generated `phase0-after-mimika-removal.wav`; generated audio was WAV, mono, 24 kHz, Float32, about 4.88 seconds, 462 KB, with peak memory about 5.27 GB.
- Qwen3-TTS reference-audio generation using `--ref_audio` and `--ref_text` succeeded with the project-owned bf16 model.
- Reference-audio test output: `phase0-qwen3-ref-audio-test.wav`, WAV, mono, 24 kHz, Float32, about 5.36 seconds, 507 KB.
- Reference-audio runtime: generated in about 17.1 seconds, peak memory about 6.05 GB, active memory about 2.5 GB, cache about 256 MB.
- Real user reference audio was converted from MP3 to `phase0-vanselee-reference-20260422.wav`, WAV, mono, 24 kHz, Int16, about 12.30 seconds, 577 KB.
- Real user reference-audio generation succeeded with `--ref_audio` and `--ref_text`.
- Real user reference output: `phase0-vanselee-refclone-test.wav`, WAV, mono, 24 kHz, Float32, about 9.96 seconds, 938 KB.
- Real user reference runtime: generated in about 24.5 seconds, peak memory about 8.01 GB, active memory about 2.5 GB, cache about 257 MB.
- User listened to the real reference-audio output and judged the result acceptable.
- Medium-length preset voice test succeeded with about 260 Chinese characters.
- Medium-length preset output: `phase0-qwen3-500char-preset.wav`, WAV, mono, 24 kHz, Float32, about 39.76 seconds, 3.6 MB.
- Medium-length preset runtime: generated in about 54.5 seconds, peak memory about 7.88 GB, active memory about 2.4 GB, cache about 257 MB.
- Segment generation test succeeded by splitting the medium text into four shorter chunks: `phase0-segment-01.wav` through `phase0-segment-04.wav`.
- Segment outputs were all WAV, mono, 24 kHz, Float32. Durations were about 16.96s, 17.12s, 11.44s, and 11.52s.
- Segment runtimes were about 42.1s, 39.9s, 26.5s, and 28.5s. Per-process peak memory was about 7.19 GB, 7.24 GB, 6.34 GB, and 6.39 GB.
- Starting multiple segment generation processes in parallel did not crash in this run, but it produced high memory pressure and should not be the default product behavior.
- The current 8bit Qwen3-TTS cache contains a partial root `model.safetensors`; it must not be treated as a valid completed model.

## Blockers

- Model downloads from Hugging Face are not stable enough yet to complete first-run TTS validation.
- Need a repeatable model download strategy before app development starts: retry/resume behavior, progress reporting, checksum/state validation, and user-facing failure recovery.
- Need to decide whether Phase 0 should test with a pre-downloaded model cache, a smaller model, or an alternate mirror/proxy if Hugging Face remains unreliable.
- `ModelUtils` currently treats any non-zero `.safetensors` file as enough to consider a model directory present; this is risky for interrupted downloads and should be hardened with expected file size/hash validation.
- Reference-audio generation raises memory pressure compared with preset voice generation; this must be tested carefully on the M2 8 GB baseline with longer inputs.
- Real user reference-audio generation reached about 8.01 GB peak memory, so this mode should be considered high-risk on 8 GB machines unless input length and concurrency are tightly controlled.
- Medium-length text generation with bf16 nearly reaches an 8 GB memory budget, so the app must enforce segment-based generation and avoid concurrent TTS jobs on low-memory machines.
- Segment generation should be queued serially by default on 8 GB machines. Parallel generation should require explicit higher-memory capability detection and user opt-in.

## Decisions

- Keep Swift-native path as primary because the TTS executable builds and Swift-side cloning APIs exist in documentation.
- Treat full Xcode and Metal Toolchain setup as resolved for the current machine.
- Treat `mlx.metallib` generation/packaging as a real engineering requirement for the future Xcode app target, not a one-off terminal detail.
- Treat model distribution/download robustness as the next immediate Phase 0 risk.
- Add local model reuse as a first-class product capability: users should be able to choose an existing model folder, and the app should support importing, referencing, symlinking, or hard-linking large model files depending on safety and lifecycle needs.
- Prefer project-owned model files for models needed by this app long term. Use hard links for cache compatibility when the source and target are on the same filesystem.
- Keep `0.6B-Base-bf16` as a validated local fallback for Phase 0 Swift-native Qwen3-TTS testing.
- Do not spend more Phase 0 time searching for lower-memory models. Instead, provide model recommendation ranges by device memory and let users choose within or outside the recommended range with clear warnings.
- Treat robust in-app model download as the ordinary-user path. Manual model directory import/reuse remains useful for advanced users but is not the MVP primary path.
- Keep multi-role, multi-voice dubbing as the MVP product center; do not reduce the app to a single-narrator TTS tool.

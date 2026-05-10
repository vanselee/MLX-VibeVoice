# Third-Party Notices

This project uses Swift Package Manager dependencies and external model
repositories. Before publishing a release build, verify the current license of
each dependency and model at the pinned revision or model page.

## Swift Packages

The pinned package list is stored in:

`MLXVoiceNotes/MLXVoiceNotes.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`

Current direct and transitive dependencies include:

- `mlx-audio-swift` - https://github.com/Blaizzy/mlx-audio-swift
- `mlx-swift` - https://github.com/ml-explore/mlx-swift
- `mlx-swift-lm` - https://github.com/ml-explore/mlx-swift-lm
- `swift-transformers` - https://github.com/huggingface/swift-transformers
- `swift-huggingface` - https://github.com/huggingface/swift-huggingface
- `swift-jinja` - https://github.com/huggingface/swift-jinja
- `swift-nio` - https://github.com/apple/swift-nio
- `swift-crypto` - https://github.com/apple/swift-crypto
- `swift-asn1` - https://github.com/apple/swift-asn1
- `swift-collections` - https://github.com/apple/swift-collections
- `swift-atomics` - https://github.com/apple/swift-atomics
- `swift-numerics` - https://github.com/apple/swift-numerics
- `swift-system` - https://github.com/apple/swift-system
- `EventSource` - https://github.com/mattt/EventSource
- `yyjson` - https://github.com/ibireme/yyjson

## Model Repositories

The app can download or load Qwen TTS models from `mlx-community`, including:

- `mlx-community/Qwen3-TTS-12Hz-1.7B-CustomVoice-bf16`
- `mlx-community/Qwen3-TTS-12Hz-1.7B-CustomVoice-8bit`
- `mlx-community/Qwen3-TTS-12Hz-1.7B-CustomVoice-4bit`
- `mlx-community/Qwen3-TTS-12Hz-0.6B-CustomVoice-8bit`
- `mlx-community/Qwen3-TTS-12Hz-0.6B-Base-bf16`

Model weights are intentionally excluded from this repository. Users are
responsible for complying with the upstream model licenses and acceptable-use
terms.

## Release Checklist

- Do not bundle model weights unless their licenses explicitly allow it.
- Do not bundle generated audio or reference voice audio.
- Include a copy of required third-party notices when distributing binaries.
- Re-check upstream licenses before each public release.


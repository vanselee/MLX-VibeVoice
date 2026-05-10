# MLX VibeVoice

[English](#english) | [中文](#中文)

---

<a id="english"></a>

MLX VibeVoice is a local-first macOS app for turning scripts into speech with
Apple Silicon and MLX-based Qwen TTS models. It is designed for multi-role
scripts, reusable reference voices, local model management, and complete WAV
export.

> Status: active development. The app is usable for local experiments, but model
> quality, generation speed, and voice stability are still being tuned.

## Audio Demo

https://github.com/user-attachments/assets/d17bfef2-7e08-446a-890f-21166bd6f5c2

*Multi-role dialogue demo — generated with Qwen3 TTS and custom reference voices.*

---

## Features

- Script library with multi-role parsing.
- Role-to-voice binding for dialogue-style scripts.
- Local Qwen TTS model selection and download management.
- Reference voice creation from user-provided audio and text.
- Local generation with per-model generation parameters.
- Complete WAV export with strict segment-completion checks.
- Local-first storage for scripts, generated audio, reference audio, and cache.

## Requirements

- macOS 14 or later.
- Apple Silicon Mac.
- Xcode 26.4.1 or compatible recent Xcode.
- Network access only when downloading Swift packages or model files.

## Development

Open the Xcode project:

```bash
open MLXVoiceNotes/MLXVoiceNotes.xcodeproj
```

Command-line build:

```bash
xcodebuild build \
  -project MLXVoiceNotes/MLXVoiceNotes.xcodeproj \
  -scheme "MLX Voice Notes" \
  -configuration Debug \
  -derivedDataPath /private/tmp/MLXVoiceNotesDerivedData \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGNING_ALLOWED=NO
```

## Models

The app currently targets Qwen3 TTS MLX models from `mlx-community`, including:

- `mlx-community/Qwen3-TTS-12Hz-1.7B-CustomVoice-bf16`
- `mlx-community/Qwen3-TTS-12Hz-1.7B-CustomVoice-8bit`
- `mlx-community/Qwen3-TTS-12Hz-1.7B-CustomVoice-4bit`
- `mlx-community/Qwen3-TTS-12Hz-0.6B-CustomVoice-8bit`
- `mlx-community/Qwen3-TTS-12Hz-0.6B-Base-bf16`

Model weights are not included in this repository. Users download models through
the app or provide their own local Hugging Face cache. Model files are governed
by their upstream licenses and terms.

## Privacy

MLX VibeVoice is designed to run locally. Scripts, generated audio, reference
audio, and voice assets are stored on the user's Mac by default. The app should
not upload user content unless a future cloud feature is explicitly added and
clearly disclosed.

Do not commit or publish:

- model weights,
- generated audio,
- reference voice audio,
- SwiftData stores,
- export files,
- local caches,
- credentials or tokens.

## Responsible Use

Use reference voices only when you own the audio or have permission from the
speaker. Do not use this software to impersonate, defraud, harass, or mislead
others. Users are responsible for the content they generate and publish.

## License

Copyright 2026 vanselee.

Licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE).

---

<a id="中文"></a>

# MLX VibeVoice

MLX VibeVoice 是一款本地优先的 macOS 应用，基于 Apple Silicon 和 MLX 版 Qwen TTS 模型，将剧本转化为语音。支持多角色剧本、可复用的参考音色、本地模型管理和完整 WAV 导出。

> 当前状态：活跃开发中。应用可用于本地实验，但模型质量、生成速度和音色稳定性仍在调优。

## 音频演示

https://github.com/user-attachments/assets/d17bfef2-7e08-446a-890f-21166bd6f5c2

*多角色对话演示 — 使用 Qwen3 TTS 和自定义参考音色生成。*

---

## 功能特性

- 剧本库，支持多角色解析。
- 角色与音色绑定，适用于对话式剧本。
- 本地 Qwen TTS 模型选择与下载管理。
- 从用户提供的音频和文本创建参考音色。
- 本地生成，支持按模型配置生成参数。
- 完整 WAV 导出，具备严格的片段完成检查。
- 本地优先存储：剧本、生成音频、参考音色和缓存。

## 系统要求

- macOS 14 或更高版本。
- Apple Silicon Mac。
- Xcode 26.4.1 或兼容的近期 Xcode 版本。
- 仅在下载 Swift 包或模型文件时需要网络。

## 开发

打开 Xcode 项目：

```bash
open MLXVoiceNotes/MLXVoiceNotes.xcodeproj
```

命令行构建：

```bash
xcodebuild build \
  -project MLXVoiceNotes/MLXVoiceNotes.xcodeproj \
  -scheme "MLX Voice Notes" \
  -configuration Debug \
  -derivedDataPath /private/tmp/MLXVoiceNotesDerivedData \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGNING_ALLOWED=NO
```

## 模型

应用当前支持来自 `mlx-community` 的 Qwen3 TTS MLX 模型，包括：

- `mlx-community/Qwen3-TTS-12Hz-1.7B-CustomVoice-bf16`
- `mlx-community/Qwen3-TTS-12Hz-1.7B-CustomVoice-8bit`
- `mlx-community/Qwen3-TTS-12Hz-1.7B-CustomVoice-4bit`
- `mlx-community/Qwen3-TTS-12Hz-0.6B-CustomVoice-8bit`
- `mlx-community/Qwen3-TTS-12Hz-0.6B-Base-bf16`

本仓库不包含模型权重。用户通过应用下载模型，或提供本地 Hugging Face 缓存。模型文件受其上游许可证和条款约束。

## 隐私

MLX VibeVoice 设计为本地运行。剧本、生成音频、参考音色和音色资产默认存储在用户的 Mac 上。除非未来明确添加并清晰披露云功能，应用不应上传用户内容。

请勿提交或发布：

- 模型权重
- 生成音频
- 参考音色音频
- SwiftData 数据库
- 导出文件
- 本地缓存
- 凭证或令牌

## 负责任使用

仅在拥有音频或获得说话者许可时使用参考音色。请勿使用本软件冒充、欺诈、骚扰或误导他人。用户应对其生成和发布的内容负责。

## 许可证

Copyright 2026 vanselee.

基于 Apache License 2.0 许可。详见 [LICENSE](LICENSE)。

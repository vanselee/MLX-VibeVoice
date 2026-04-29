# MLX Voice Notes

MLX Voice Notes is a macOS Apple Silicon audio creation app for turning scripts into speech with local-first MLX inference.

## Project Identity

- App name: MLX Voice Notes
- Bundle identifier: `com.vanselee.MLXVoiceNotes`
- Author: vanselee
- Email: liyifc@gmail.com
- Copyright: Copyright © 2026 vanselee. All rights reserved.

## Current Status

The project is in Phase 0 preparation. Phase 0 validates the core technical risks before UI prototyping:

- `mlx-audio-swift` local TTS viability
- Chinese TTS model support
- Multi-role script splitting and WAV stitching
- 24kHz / 16-bit PCM / mono export path
- Python/CLI local cloning feasibility as a non-blocking key validation item

## Local Development Rules

- This repository is local-first for now. Do not upload to GitHub until the license and public release policy are decided.
- Do not commit models, generated audio, reference audio, caches, exports, credentials, or packaged app artifacts.
- Product and file attribution should use `vanselee`; do not add AI tool names as authors or co-authors.


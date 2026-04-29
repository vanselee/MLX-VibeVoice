# Development Rules

## Attribution

- Product author: vanselee
- Git author name: vanselee
- Git author email: liyifc@gmail.com
- Copyright: Copyright © 2026 vanselee. All rights reserved.
- Do not add AI tool names such as ChatGPT, Claude, Codex, or OpenAI as file authors.
- Do not add `Co-authored-by` trailers for AI tools.

## Version Control

- Use local Git during early development.
- Keep source code, documentation, scripts, and small test fixtures in Git.
- Keep models, generated audio, reference audio, exports, caches, virtual environments, and packaged builds out of Git.
- Tag important milestones, for example:
  - `phase0-start`
  - `phase0-swift-tts-ok`
  - `phase0-wav-stitching-ok`
  - `phase1-start`

## Branching

- `main`: stable local history.
- `spike/*`: technical experiments.
- `feature/*`: app features.
- `fix/*`: bug fixes.

## Commit Style

Use concise Conventional Commit style:

```text
docs: add phase0 validation plan
feat: add note autosave model
fix: handle damaged model index
chore: ignore generated audio assets
```


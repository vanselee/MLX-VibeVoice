# ADR 0001: Local-First Version Control

## Status

Accepted

## Context

The project will initially include technical spikes, model experiments, generated audio, and local reference assets. Uploading too early may expose private files or commit large artifacts.

## Decision

Use local Git during early development. Do not upload to GitHub until license, public release policy, and large-file rules are finalized.

## Consequences

- The project gets local history and rollback without cloud exposure.
- Models, generated audio, caches, and reference audio remain outside Git.
- Phase milestones should be tagged locally.


# Phase 6 Implementation Plan - Save/Load Robustness

## Objective

Prevent stale state from surviving when a full game snapshot is loaded into an existing model.

## Scope

- Clear prior game state before loading a new `<game>` snapshot.
- Add a regression that proves old players/tiles do not leak into the next snapshot.

## Execution Steps

1. [x] Reset existing model state at the start of `Game.load(from:)`.
2. [x] Add a CLI regression for loading a second snapshot into the same `Game` instance.
3. [x] Validate with build + tests.

## Validation

- `swift build --target FreeColApp`
- `swift run FreeColProtocolCLI`
- `swift test`

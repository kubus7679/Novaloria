# Phase 30: Set AI Action MVP Plan

## Goal

Close another concrete gap from "missing action messages and UI affordances" by adding the `setAI` action in state and UI.

## Scope

- [x] Add `setLocalPlayerAI(_:)` action in `GameState` to send `setAI` with `player` and `ai`.
- [x] Expose an in-game UI affordance in `GameView` to trigger setAI for the local player.
- [x] Add CLI integration regression to verify outgoing `setAI` payload.
- [x] Validate with build and CLI suite.

## Validation Checklist

- [x] `swift build --target Novaloria`
- [x] `swift run FreeColProtocolCLI`

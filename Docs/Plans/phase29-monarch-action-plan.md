# Phase 29: Monarch Action MVP Plan

## Goal

Close another concrete gap from "missing action messages and UI affordances" by adding the `monarchAction` action in state and UI.

## Scope

- [x] Add `sendMonarchAction(_:)` action in `GameState` to send `monarchAction` with `action` and `player`.
- [x] Expose an in-game UI affordance in `GameView` to trigger a monarch action for the local player.
- [x] Add CLI integration regression to verify outgoing `monarchAction` payload.
- [x] Validate with build and CLI suite.

## Validation Checklist

- [x] `swift build --target Novaloria`
- [x] `swift run FreeColProtocolCLI`

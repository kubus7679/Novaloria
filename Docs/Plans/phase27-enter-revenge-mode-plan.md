# Phase 27: Enter Revenge Mode Action MVP Plan

## Goal

Close another concrete gap from "missing action messages and UI affordances" by adding the `enterRevengeMode` in-game action in state and UI.

## Scope

- [x] Add `enterRevengeMode()` action in `GameState` to send `enterRevengeMode`.
- [x] Expose an in-game UI affordance in `GameView` to trigger enter revenge mode.
- [x] Add CLI integration regression to verify outgoing `enterRevengeMode` payload.
- [x] Validate with build and CLI suite.

## Validation Checklist

- [x] `swift build --target Novaloria`
- [x] `swift run FreeColProtocolCLI`

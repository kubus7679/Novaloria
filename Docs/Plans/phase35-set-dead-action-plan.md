# Phase 35: Set Dead Action MVP Plan

## Goal

Close another small action/UI gap by adding support for `setDead` from the Swift client.

## Scope

- [x] Add `setLocalPlayerDead()` action in `GameState` to send `setDead` with `player`.
- [x] Expose an in-game UI affordance in `GameView` to trigger setDead for the local player.
- [x] Add CLI integration regression to verify outgoing `setDead` payload.
- [x] Validate with build and CLI suite.

## Validation Checklist

- [x] `swift build --target FreeColApp`
- [x] `swift run FreeColProtocolCLI`

# Phase 36: Claim Land Action MVP Plan

## Goal

Close another small action/UI gap by adding support for `claimLand` from the Swift client.

## Scope

- [x] Add `claimLand(price:tile:)` action in `GameState` to send `claimLand` with `price`, `claimant`, and `tile`.
- [x] Expose an in-game UI affordance in `GameView` to claim the currently selected tile.
- [x] Add CLI integration regression to verify outgoing `claimLand` payload.
- [x] Validate with build and CLI suite.

## Validation Checklist

- [x] `swift build --target Novaloria`
- [x] `swift run FreeColProtocolCLI`

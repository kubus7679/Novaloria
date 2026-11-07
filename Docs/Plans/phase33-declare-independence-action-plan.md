# Phase 33: Declare Independence Action MVP Plan

## Goal

Close another gameplay action/UI gap by adding support for `declareIndependence` from the Swift client.

## Scope

- [x] Add `declareIndependence(countryName:nationName:)` action in `GameState` to send `declareIndependence` with `countryName` and `nationName`.
- [x] Expose in-game UI affordances in `GameView` for entering country and nation names and triggering the action.
- [x] Add CLI integration regression to verify outgoing `declareIndependence` payload.
- [x] Validate with build and CLI suite.

## Validation Checklist

- [x] `swift build --target Novaloria`
- [x] `swift run FreeColProtocolCLI`

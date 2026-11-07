# Phase 23: Update MapGeneratorOptions Action MVP Plan

## Goal

Close another concrete gap from "missing action messages and UI affordances" by adding the `updateMapGeneratorOptions` pre-game action in lobby state and UI.

## Scope

- [x] Add `updateSingleMapGeneratorOption(id:value:)` action in `GameState` to send `updateMapGeneratorOptions` with one `<option/>` child.
- [x] Expose a lobby UI affordance in `LoginView` to submit one map-generator option key/value pair.
- [x] Add CLI integration regression to verify outgoing `updateMapGeneratorOptions` payload.
- [x] Validate with build and CLI suite.

## Validation Checklist

- [x] `swift build --target Novaloria`
- [x] `swift run FreeColProtocolCLI`

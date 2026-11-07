# Phase 24: Choose FoundingFather Action MVP Plan

## Goal

Close another concrete gap from "missing action messages and UI affordances" by adding the `chooseFoundingFather` pre-game action in lobby state and UI.

## Scope

- [x] Add `chooseFoundingFather(_:)` action in `GameState` to send `chooseFoundingFather` with `foundingFather`.
- [x] Expose a lobby UI affordance in `LoginView` to submit a founding-father id.
- [x] Add CLI integration regression to verify outgoing `chooseFoundingFather` payload.
- [x] Validate with build and CLI suite.

## Validation Checklist

- [x] `swift build --target Novaloria`
- [x] `swift run FreeColProtocolCLI`

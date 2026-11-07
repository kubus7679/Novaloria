# Phase 4 Implementation Plan - Colony Actions MVP

## Objective

Expose first colony management actions from the SwiftUI client:
- changeWorkType
- rearrangeColony (minimal no-op payload)
- setBuildQueue

## Scope

- Add guarded colony action APIs in GameState.
- Extend ColonyPanelView with compact action controls.
- Keep local/mock compatibility via lightweight local model fallback where applicable.
- Add protocol CLI integration regression for outbound message shape.

## Execution Steps

1. [x] Confirm Java-compatible attribute shape for `changeWorkType`, `rearrangeColony`, and `setBuildQueue`.
2. [x] Add local model helper for unit `workType` updates.
3. [x] Add GameState colony action methods with ownership/turn guards.
4. [x] Extend ColonyPanelView + GameView wiring with MVP controls.
5. [x] Add CLI integration regression covering all three outbound message tags.
6. [x] Validate with build + CLI suite.

## Validation

- swift build --target Novaloria
- swift run FreeColProtocolCLI

## Expected Result

Selected own colonies can trigger initial management actions from UI, and emitted protocol messages match Java-side tag/attribute expectations.

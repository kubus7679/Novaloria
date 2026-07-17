# Phase 2 Implementation Plan - Disband Unit Action

## Objective

Implement a guarded unit disband action in the Swift client parity layer.

## Scope

- Add guarded `disbandUnit` action API in `GameState`.
- Expose a selected-unit disband control in `GameView`.
- Keep mock-server compatibility via local model fallback.
- Add protocol CLI integration regression to validate outbound `disbandUnit` message shape.

## Execution Steps

1. [x] Confirm `disbandUnit` message attribute contract in generated protocol messages and Java source.
2. [x] Add local model helper to remove a unit for mock-server simulation.
3. [x] Add `GameState` action methods:
   - [x] `canDisbandSelectedUnit`
   - [x] `disbandSelectedUnit()`
4. [x] Update `GameView` with a selected-unit disband control and visible error surface.
5. [x] Add integration regression in `FreeColProtocolCLI` for outbound `disbandUnit`.
6. [x] Validate with build + CLI suite.

## Validation

- `swift build --target FreeColApp`
- `swift run FreeColProtocolCLI`

## Expected Result

Selected own units can be disbanded with legal guards, protocol-compliant `disbandUnit` messages are emitted, and action failures are visible in the in-game UI.

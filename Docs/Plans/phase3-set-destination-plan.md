# Phase 3 Implementation Plan - Goto / SetDestination

## Objective

Implement basic destination orders for selected units via `setDestination`.

## Scope

- Add guarded destination action API in `GameState`.
- Expose selected-unit destination controls in `GameView` using selected map tile.
- Keep mock-server compatibility via local model fallback.
- Add protocol CLI integration regression to validate outbound `setDestination` message shape (set + clear).

## Execution Steps

1. [x] Confirm `setDestination` message attribute contract (including nullable destination) in generated protocol messages and Java source.
2. [x] Add local model helper to set/clear `Unit.destination` for mock-server simulation.
3. [x] Add `GameState` action methods:
   - [x] `canSetSelectedUnitDestination(to:)`
   - [x] `canClearSelectedUnitDestination`
   - [x] `setSelectedUnitDestination(to:)`
   - [x] `clearSelectedUnitDestination()`
4. [x] Update `GameView` with selected-unit destination controls and destination status.
5. [x] Add integration regression in `FreeColProtocolCLI` for outbound `setDestination` (set and clear).
6. [x] Validate with build + CLI suite.

## Validation

- `swift build --target FreeColApp`
- `swift run FreeColProtocolCLI`

## Expected Result

Selected own units can receive and clear destination orders using the selected tile, with protocol-compliant `setDestination` messages and regression coverage.

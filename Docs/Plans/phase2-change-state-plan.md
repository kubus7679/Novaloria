# Phase 2 Implementation Plan - Unit State Actions (changeState)

## Objective

Add first tactical unit state controls to Swift client parity layer:

- set selected unit to ACTIVE
- set selected unit to FORTIFYING/FORTIFIED path
- set selected unit to SENTRY

## Scope

- Add guarded `changeState` action API in `GameState`.
- Expose in-game buttons for selected unit state actions.
- Keep mock-server compatibility via local model fallback.
- Add protocol CLI integration regression to validate outbound `changeState` message shape.

## Execution Steps

1. [x] Confirm `changeState` message attribute contract in generated protocol messages.
2. [x] Extend `UnitState` model parsing with missing server state values used by Java client.
3. [x] Add `GameState` action methods:
   - `canChangeSelectedUnitState(to:)`
   - `setSelectedUnitState(_:)`
4. [x] Update `GameView` with selected-unit state action controls.
5. [x] Add integration regression in `FreeColProtocolCLI` for outbound `changeState`.
6. [x] Validate with build + CLI suite.

## Validation

- `swift build --target Novaloria`
- `swift run FreeColProtocolCLI`

## Expected Result

Selected units can be toggled between tactical states with legal guards, and the client emits protocol-compliant `changeState` messages.

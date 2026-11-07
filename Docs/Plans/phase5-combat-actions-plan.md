# Phase 5 Implementation Plan - Combat Actions MVP

## Objective

Implement first tactical combat actions from the Swift client:
- attack
- attackRanged

## Scope

- Add guarded combat actions in GameState.
- Add map tap shortcut behavior for hostile targets.
- Add compact in-game combat controls in GameView.
- Add protocol CLI regression for outbound `attack` and `attackRanged`.

## Execution Steps

1. [x] Confirm Java-compatible message contracts for `attack` and `attackRanged`.
2. [x] Add GameState guard helpers for hostile target detection and direction resolution.
3. [x] Add GameState action methods for melee/ranged attack sends.
4. [x] Extend MapView and GameView to trigger combat actions when legal.
5. [x] Add CLI integration regression for outbound combat message shapes.
6. [x] Validate with build + CLI suite.

## Validation

- swift build --target Novaloria
- swift run FreeColProtocolCLI

## Expected Result

Selected own units can attack hostile units via tap/buttons, and emitted combat messages follow Java server contract (`attack` with `direction`, `attackRanged` with `target`).

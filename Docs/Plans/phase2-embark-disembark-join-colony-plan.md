# Phase 2 Implementation Plan - Embark/Disembark/Join Colony

## Objective

Add the first Java-client parity action cluster to the Swift client:

- embark units onto carriers
- disembark units from carriers
- join an existing colony on the selected tile

## Scope

- Extend `GameState` action API with guarded methods for `embark`, `disembark`, and `joinColony`.
- Extend in-game UI controls in `GameView` for selected-unit action buttons.
- Keep behavior mock-server compatible using local model fallback where server logic is absent.
- Add integration regression coverage in `FreeColProtocolCLI` for outbound message correctness.

## Execution Steps

1. Add action guards and methods in `Sources/FreeColApp/GameState.swift`:
   - `canJoinSelectedColony`
   - `joinSelectedColony()`
   - `canEmbarkSelectedUnit(onCarrier:)`
   - `embarkSelectedUnit(onCarrier:)`
   - `canDisembarkSelectedUnit()`
   - `disembarkSelectedUnit()`
2. Add local model helper methods in `Sources/FreeColGame/Model/Game.swift` for mock fallback:
   - `joinColony(unitId:colonyId:)`
   - `embarkUnit(unitId:carrierId:)`
   - `disembarkUnit(unitId:)`
3. Expose new controls in `Sources/FreeColApp/GameView.swift`:
   - Join Colony button when selected tile has colony and selected unit is valid.
   - Embark button when selected tile has a friendly carrier unit.
   - Disembark button when selected unit is embarked.
4. Add integration tests in `Sources/FreeColProtocolCLI/main.swift`:
   - verify client sends `joinColony`
   - verify client sends `embark`
   - verify client sends `disembark`
5. [x] Improve carrier validation + map interaction quality:
   - [x] derive carrier suitability from available unit data (carrier detection by loaded units and naval-type heuristics)
   - [x] support map tap shortcuts for disembark/join-colony/embark when action is legal

## Validation

- `swift build --target FreeColApp`
- `swift run FreeColProtocolCLI`

## Expected Result

From in-game selection flow, the player can trigger join-colony and embark/disembark actions, and the client sends protocol-compliant messages while preserving guarded action behavior.

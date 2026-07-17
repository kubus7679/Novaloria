# Phase 3 Implementation Plan - Order Cycle Robustness

## Objective

Harden destination order lifecycle handling so stale selection/order references are avoided during remove/update flows.

## Scope

- Keep selected-unit state consistent after model updates.
- Clear destination orders when a move reaches destination in local simulation.
- Clean up unit references to removed objects in model remove handling.
- Add model regressions in CLI tests.

## Execution Steps

1. [x] Add model-level destination lifecycle handling for move execution.
2. [x] Extend remove handling to clear unit location/destination references to removed object ids.
3. [x] Add GameState sync reconciliation for selected-unit reached-destination cleanup.
4. [x] Add CLI model regressions for move-to-destination and remove-reference cleanup.
5. [x] Validate with build + CLI suite.

## Validation

- swift build --target FreeColApp
- swift run FreeColProtocolCLI

## Expected Result

Destination order cycle remains stable through move execution and remove/update events, without stale selection/order references.

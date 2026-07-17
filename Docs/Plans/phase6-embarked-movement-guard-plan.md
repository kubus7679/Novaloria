# Phase 6 Implementation Plan - Embarked Movement Guard

## Objective

Prevent embarked units from being treated as directly movable map units.

## Scope

- Block move actions when the selected unit is inside a carrier.
- Show a clear UI error telling the player to disembark first.
- Normalize the corresponding server reject message.

## Execution Steps

1. [x] Require a real tile location before sending move orders.
2. [x] Surface a clear error when the selected unit is embarked.
3. [x] Map `MOVE_NO_ACCESS_EMBARK` to a user-facing message.
4. [x] Add a CLI regression for the reject mapping.
5. [x] Validate with build + tests.

## Validation

- `swift build --target FreeColApp`
- `swift run FreeColProtocolCLI`
- `swift test`

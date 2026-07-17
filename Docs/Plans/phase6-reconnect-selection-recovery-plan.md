# Phase 6 Implementation Plan - Reconnect Flows and Stale Selection Recovery

## Objective

Make disconnect/reconnect handling more forgiving by recovering selection state when the selected unit disappears.

## Scope

- Recover a sensible local selection after model updates remove the currently selected unit.
- Prefer a surviving unit on the same tile, then fall back to the first active local unit.
- Keep the behavior local to the Swift client.

## Execution Steps

1. [x] Add model helpers to recover a local selection from tile/unit state.
2. [x] Update `GameState` reconciliation to use those helpers after stale selections.
3. [x] Add a CLI regression for recovery behavior.
4. [ ] Extend reconnect UX if needed after verifying recovery in practice.
5. [x] Validate with build + tests.

## Validation

- `swift build --target FreeColApp`
- `swift run FreeColProtocolCLI`
- `swift test`

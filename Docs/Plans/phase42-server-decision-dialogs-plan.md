# Phase 42: Server Decision Dialogs

## Objective

Replace the placeholder-only handling for `fountainOfYouth`, `indianDemand`, and `lootCargo` with a real pending-decision state in app state and a first UI shell for the decision workflow.

## Scope

- Capture the three inbound server messages as structured, pending decision state instead of plain `statusMessage` text.
- Keep local guards in place so a decision is not sent twice or after reconnect/logout.
- Present a minimal UI shell in the game overlay to show a pending choice while preserving the current status bar.
- Add regression coverage for the new decision state lifecycle.

## Implementation Steps

1. Add a pending-decision model to `GameState` that represents the three decision types and keeps the minimal data required for rendering and reply handling.
2. Update `applySessionMessage(_:)` so the three tags populate the pending-decision state and clear stale state on reconnect/logout/game-end resets.
3. Add a lightweight game-overlay sheet in `GameView` that surfaces the pending decision in the UI and keeps the status bar as secondary feedback.
4. Add tests covering the lifecycle of `fountainOfYouth`, `indianDemand`, and `lootCargo` message handling.
5. Run the relevant Swift build/test commands and fix regressions.

## Validation

- `swift build --target FreeColApp`
- `swift test`

## Expected Result

The client treats these server messages as actionable prompts instead of one-off placeholder strings, and the first UI shell is ready for the subsequent protocol-backed reply implementation.

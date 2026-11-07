# Phase 6 Implementation Plan - Server Reject Handling

## Objective

Normalize common server reject responses into clearer UI messages and keep local action gating aligned with rejected actions.

## Scope

- Map common error strings and template IDs to friendly messages.
- Reconcile local unit move state when the server rejects movement because a unit has no moves left.
- Add regressions for message normalization.

## Execution Steps

1. [x] Add a shared reject-message mapper in `NovaloriaClient`.
2. [x] Use the mapper from `GameState` error handling.
3. [x] Add CLI regressions for common reject cases.
4. [x] Extended message-specific mappings (not-your-turn, amphibious, native
   trade/hostile), including regressions (Phase 53).
5. [x] Validate with build + tests.

## Validation

- `swift build --target Novaloria`
- `swift run FreeColProtocolCLI`
- `swift test`

# In-Game Turn Sync Plan

## Objective

Stabilize turn progression in active games so local end-turn behavior remains legal and server-driven turn ownership/reconnect events are reflected immediately in UI state.

## Scope

- Keep question-wrapped and normal server updates synchronized to model/UI.
- Preserve strict local guardrails for `endTurn` in app state and UI.
- Handle server `reconnect` messages explicitly in app state.
- Add regression coverage for reconnect and turn-sync relevant message flow.

## Implementation Steps

1. [x] Extend session message handling in app state with explicit `reconnect` processing.
2. [x] Ensure reconnect processing clears pending turn action state via existing disconnect/reset path.
3. [x] Add integration regression in `FreeColProtocolCLI`:
   - [x] message loop receives `<reconnect/>`
   - [x] delegate observes reconnect event.
4. [x] Add integration regression for in-game turn-owner sync after `endTurn` server updates.
5. [x] Re-run build and protocol CLI regressions.

## Validation

- `swift build --target Novaloria`
- `swift run FreeColProtocolCLI`

## Expected Result

- End-turn remains locally guarded.
- Server-driven reconnect is visible to the client state and no stale pending-turn lock remains.
- Regression suite captures reconnect handling in message loop.

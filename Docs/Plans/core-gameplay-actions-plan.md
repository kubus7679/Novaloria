# Core Gameplay Actions Implementation Plan

## Context

This plan expands phase 3 (Core gameplay actions) into concrete implementation steps for the current Swift client architecture.

## Objective

Enable a minimal but playable in-game loop from SwiftUI by implementing and validating:

- unit movement with legal-action guarding
- turn progression with correct local turn gating
- colony founding flow from selected unit
- selection-driven actions (unit/tile focus, action availability)

## Non-Goals

- No broad UI redesign.
- No full parity with all FreeCol Java client actions.
- No hand editing of generated protocol message files.

## Implementation Scope

### 1. Action Contract Alignment (Java server parity)

Goal: Confirm exact request/response expectations before coding behavior.

Tasks:

1. Verify current action tags and required attributes against server behavior for:
   - moveTo / move
   - endTurn
   - buildColony
2. Confirm whether actions are expected directly or wrapped in question/reply flows in active sessions.
3. Record any mandatory attributes and expected error templates for each action.

Deliverable:

- Short compatibility notes added to this file (append section) during implementation.

### 2. App-State Action Layer Hardening

Goal: Make GameState the single guarded action boundary.

Tasks:

1. Keep all outbound gameplay actions in GameState methods.
2. Add or refine guard conditions:
   - connected and in-game phase
   - local player turn (for turn-bound actions)
   - selected unit exists in current snapshot
   - destination/action target validity where known locally
3. Standardize error propagation to user-facing status/error fields.

Deliverable:

- Stable GameState action methods for move, end turn, and found colony.

### 3. Model Sync For Action Results

Goal: Ensure server updates after actions are always reflected in model/UI.

Tasks:

1. Validate that post-action update/partial/remove/newTurn/setCurrentPlayer paths mutate model state correctly.
2. Ensure question-wrapped payloads are consistently processed in message loop/model manager.
3. Add targeted handling for any missing message tags observed during action flows.

Deliverable:

- Deterministic state transitions in FreeColGame + GameStateManager after gameplay actions.

### 4. Selection-Driven UX Wiring

Goal: Keep map selection and action enablement coherent.

Tasks:

1. Use selectedUnitId and selectedTileId as single source of selection truth.
2. Gate UI controls by computed legality flags (example: canMove, canEndTurn, canBuildColony).
3. Auto-clear or re-resolve stale selection when referenced objects are removed/invalidated by server updates.

Deliverable:

- No stale-selection action sends after remove/update cycles.

### 5. Colony Founding Flow

Goal: Make founding a colony reliable from selected unit.

Tasks:

1. Validate selected unit can found (local checks where possible).
2. Send buildColony with required attributes.
3. Confirm colony and unit/map updates are reflected after server response.
4. Surface server-side denial reasons via existing error message channel.

Deliverable:

- Found-colony action works end-to-end in a live session.

### 6. Turn Progression Guardrails

Goal: Keep end-turn legal and state driven.

Tasks:

1. Allow endTurn only for local current player.
2. On newTurn/setCurrentPlayer updates, refresh local turn ownership derived state.
3. Prevent duplicate endTurn sends while awaiting server transition.

Deliverable:

- End turn is only possible when legal; turn owner changes are visible immediately.

## Execution Order

1. Action contract alignment (server parity checks).
2. GameState hardening for move/endTurn/buildColony.
3. Model sync fixes for post-action updates.
4. Selection consistency and UI legality wiring.
5. Colony founding end-to-end validation.
6. Turn progression stabilization and duplicate-send prevention.

## Validation Plan

Primary checks:

- swift build --target FreeColApp
- swift run FreeColProtocolCLI

Manual integration checks against Java server:

1. Connect/login, enter in-game state.
2. Select local unit and move to valid destination.
3. Attempt illegal move and verify user-visible error handling.
4. Found colony from valid unit/tile and verify model/UI updates.
5. End turn as local player and verify turn owner change.
6. Confirm end-turn action is blocked when not local player turn.

## Acceptance Criteria

- Movement action works for legal targets and rejects illegal attempts without desync.
- End-turn can only be sent on local turn and transitions correctly on server updates.
- Colony founding works from UI with correct server update reflection.
- Selection state remains consistent after remove/update messages.
- No regression in existing login/lobby flow.

## Risks And Mitigations

- Risk: Server requires additional hidden attributes for some actions.
  Mitigation: Validate tags/attributes against Java handling before coding each action path.

- Risk: Question-wrapped responses create partial state updates.
  Mitigation: Enforce unified payload processing path and add regression checks for wrapped/unwrapped forms.

- Risk: Stale selected IDs after model mutations cause invalid sends.
  Mitigation: Re-validate selection before each send and clear invalid references on updates.

## Definition Of Done

- All acceptance criteria pass.
- Build and CLI regression checks are green.
- Manual Java-server action flow is verified.
- Any newly required protocol messages are generated and registered, not hand-written.

## Manual Java-Server E2E Validation (2026-07-16)

Environment:

- Java server started via `docker-compose -f docker/docker-compose.yml up -d` in sibling `freecol/` repository.
- Endpoint reachable on `127.0.0.1:3541`.

Executed checks:

1. Wire-level handshake probe against Java server returned `gameState state="PRE_GAME"`.
2. Added opt-in real-server smoke check to `FreeColProtocolCLI` (env-gated by `REAL_SERVER_E2E=1`).
3. Ran `REAL_SERVER_E2E=1 swift run FreeColProtocolCLI` against `127.0.0.1:3541`.
4. Smoke check performed:
  - connect
  - initial `gameState` verification
  - login using available nation slot (or default fallback)
  - pre-game action send (`ready`, `requestLaunch`) or `endTurn` when already in-game

Observed result:

- CLI run succeeded with `38 passed, 0 failed`.
- Real Java-server test case `real Java server connect/login smoke` passed.

Conclusion:

- Core action transport and session flow are validated against the real Java FreeCol server for connect/login and initial action dispatch paths.

Additional deep probe (same date):

- Added env-gated deep validation `REAL_SERVER_DEEP_E2E=1` in `FreeColProtocolCLI`.
- Probe flow: connect -> login -> pre-game `ready` + `requestLaunch` via ask/reply -> short event observation -> opportunistic `endTurn` ask when in-game.
- Result on clean server state: `39 passed, 0 failed`.

Notes from deep probe:

- The Java server can disconnect/rotate connections around lobby/game transitions; observation-phase disconnects were treated as non-fatal for this transport-level probe.
- Deterministic deep runs require a clean server data volume (`docker-compose down -v` then `up -d`) to avoid stale-user/login-state interference.

## Compatibility Notes (Verified Against Java Source)

- `moveTo` uses attributes `unit` and `destination` (`MoveToMessage`).
- `move` uses attributes `unit` and `direction` (`MoveMessage`).
- `buildColony` uses attributes `name` and `unit` (`BuildColonyMessage`).
- `endTurn` is a trivial message without attributes (`EndTurnMessage`).
- In Java `ServerAPI`, all core actions above are sent via ask/query-response semantics.
- Current Swift implementation keeps a push/message-loop model; action results are synchronized by incoming server updates (`update`, `partial`, `remove`, `newTurn`, `setCurrentPlayer`) and question/reply payload processing.

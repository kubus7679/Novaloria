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

- swift build --target Novaloria
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
- In Java `ServerAPI`, `move`, `moveTo`, `buildColony`, and `endTurn` use ask/query-response semantics.
- Remote Swift gameplay actions now use `client.ask`; the central message loop applies reply-contained state deltas before returning the reply to `GameState`.
- Local games retain fire-and-forget transport because the local `MockServer` currently supports only the corresponding push path; their local model mutations remain unchanged.
- The CLI integration check validates `<question>` wrappers, action attributes, and matching `<reply>` IDs for all four core action tags.
- Map movement legality now requires the selected unit itself to occupy a map tile; embarked units cannot send standalone `move` requests.
- Regression tests cover local-turn gating, adjacent versus distant movement, colony-founding eligibility, embarked-unit movement rejection, and selection recovery/blocking after a unit is removed.

## Core-Action Ask/Reply Implementation (2026-10-13)

- Centralized the remote/local transport choice in `GameState.sendCoreGameplayAction`.
- `move`, `moveTo`, `buildColony`, and `endTurn` now await Java-server replies in remote sessions; server rejection reasons are surfaced through `errorMessage`.
- Updated the CLI integration probe to validate question wrappers, request attributes, and reply correlation for all core action tags.
- Validation passed: `swift build --target Novaloria`, `swift test` (78 tests), `swift run FreeColProtocolCLI` (132 checks), and `Tools/e2e-java-server.sh` (Smoke/Deep/Gameplay each 1/0).

## Movement Legality And Selection Regression Follow-Up (2026-10-13)

- Normal `move` eligibility now requires the selected unit to be located directly on a map tile. Embarked units cannot issue standalone movement orders; `moveTo` remains the route for high-seas travel.
- Added regression coverage for local-turn gating, adjacent movement versus path-followed destinations, colony-founding eligibility, embarked-unit movement rejection, and stale selection after server removal.
- Validation passed: `swift build --target Novaloria`, `swift test` (78 tests), `swift run FreeColProtocolCLI` (132 checks), and `Tools/e2e-java-server.sh` (Smoke/Deep/Gameplay each 1/0).

## End-Turn Duplicate-Request Guard Follow-Up (2026-10-13)

- Remote `endTurn` keeps its pending lock longer than the 30-second ask timeout, so the safety unlock cannot permit a duplicate request while the original ask is still in flight.
- Local MockServer turns keep the shorter safety retry interval because local turn changes arrive through the push path.
- `canEndTurn` disables the UI control while a request is pending and becomes available again after server turn synchronization.
- Regression checks cover both timeout policies and a local-game integration test proving duplicate endTurn calls advance only one turn.
- Validation passed: `swift build --target Novaloria`, `swift test` (78 tests), and `swift run FreeColProtocolCLI` (132 checks).

## Local Rejection Feedback (2026-10-13)

- Illegal `move` (no moves left) and `buildColony` (empty name, unit without moves) are rejected before any request is built, set a user-facing `errorMessage`, and leave the model unchanged.
- Covered by `testIllegalCoreActionsSetUserFacingErrorsWithoutSending`.
- Validation passed: `swift build --target Novaloria`, `swift test` (79 tests), and `swift run FreeColProtocolCLI` (132 checks).

## Live Java Rejection Capture (2026-10-13)

- New env-gated probe `REAL_SERVER_REJECT_E2E=1` in `FreeColProtocolCLI`, wired into `Tools/e2e-java-server.sh` as a fourth step.
- It sends a `move` for a non-existent unit to the real Java server and requires a `serverError` reply, then verifies the client model (unit count and turn) is unchanged.
- Captured Java text: `Not a net.sf.freecol.server.model.ServerUnit: unit:does-not-exist/null`. This is a raw server exception message and is shown verbatim via `errorMessage`; it is not a localized FreeCol template.
- Validation passed: `Tools/e2e-java-server.sh` (Smoke/Deep/Gameplay/Rejection each 1/0), `swift build --target Novaloria`, `swift test` (79 tests), and `swift run FreeColProtocolCLI` (132 checks).

## User-Facing Java Rejection Messages (2026-10-13)

- `GameState.sendCoreGameplayAction` maps `serverError` replies to German messages via `GameState.userFacingServerError`, for example `Die Einheit ist auf dem Server nicht bekannt.` for the captured `ServerUnit` text.
- Unknown server texts are kept verbatim after the prefix `Der Server hat die Aktion abgelehnt:`, so no information is lost.
- Covered by `testJavaRejectionTextsMapToUserFacingMessages`, which uses the captured Java text.
- Validation passed: `swift build --target Novaloria`, `swift test` (80 tests), and `swift run FreeColProtocolCLI` (132 checks). The Java rejection probe reads raw `FreeColProtocolError` values from the CLI client path and is unaffected by this change; it was not rerun against Docker.

## Acceptance Status (2026-10-13)

| Criterion | Evidence | Status |
|---|---|---|
| Movement works for legal targets, rejects illegal ones without desync | `testCoreGameplayActionGuardsRejectIllegalSelectionAndTurn`, `testIllegalCoreActionsSetUserFacingErrorsWithoutSending`, Java gameplay probe (move), Java rejection probe (model unchanged) | Met |
| End-turn only on local turn, transitions on server updates | `testCoreGameplayActionGuards…` (not local turn: `canEndTurn` false, `endTurn()` rejected), `testLocalEndTurnRejectsDuplicateUntilTurnAdvances`, Java gameplay probe (turn advances, local turn returns) | Met for model and local game; Java "not local turn" rejection not captured live |
| Colony founding works with correct server update | Java gameplay probe (colony founded, renamed, warehouse updated) | Met at protocol/model level |
| Selection consistent after remove/update | `testSelectionRecoversAfterSelectedUnitIsRemoved` | Met |
| No regression in login/lobby | Java smoke and deep probes; CLI integration tests | Met |

Definition of Done:

- Build, XCTest (80), CLI (132), and Java E2E (Smoke/Deep/Gameplay/Rejection each 1/0) are green.
- Java-server action flow verified through the protocol client. **Not verified:** a manual click-through of the SwiftUI controls against the live server; no GUI automation exists in this repository.
- No new protocol messages were hand-written; all actions reuse existing tags.

Open gap: the "end turn blocked when not local player" case is verified at the model level only. Reaching it against Java would require a second player session, which the current E2E harness does not provide.

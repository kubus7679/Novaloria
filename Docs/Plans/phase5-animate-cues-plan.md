# Phase 5 Implementation Plan - Animate Event Cues MVP

## Objective

Show minimal visual cues for server-sent animation events:
- animateMove
- animateAttack

## Scope

- Parse animation events in GameState session message handling.
- Keep a short-lived map cue state for rendering.
- Render lightweight line/marker cues in MapView.
- Add CLI integration regression that verifies animate events reach the delegate path.

## Execution Steps

1. [x] Add GameState cue model and short-lived lifecycle handling.
2. [x] Handle `animateMove` and `animateAttack` in session messages.
3. [x] Render map visual cues for move/attack events.
4. [x] Add CLI regression for animate event forwarding in message loop.
5. [x] Validate with build + CLI suite.

## Validation

- swift build --target Novaloria
- swift run FreeColProtocolCLI

## Expected Result

When animation events arrive from server, the map briefly shows clear movement/combat cues without changing core gameplay flow.

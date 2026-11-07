# Phase 4 Implementation Plan - Goods Load/Unload MVP

## Objective

Add minimal colony-related goods transfer actions to the Swift client:
- loadGoods
- unloadGoods

## Scope

- Add guarded goods transfer actions in GameState.
- Extend ColonyPanelView with compact goods controls.
- Keep implementation focused on protocol-correct outbound messages.
- Add protocol CLI integration regression for both tags.

## Execution Steps

1. [x] Confirm Java-compatible attribute contract for `loadGoods` and `unloadGoods`.
2. [x] Add GameState helpers for selecting a carrier in selected colony context.
3. [x] Add GameState action methods for load/unload goods messages.
4. [x] Extend ColonyPanelView and GameView wiring with goods action controls.
5. [x] Add CLI integration regression for outbound `loadGoods` and `unloadGoods`.
6. [x] Validate with build + CLI suite.

## Validation

- swift build --target Novaloria
- swift run FreeColProtocolCLI

## Expected Result

When a manageable colony and carrier are selected, the client can emit protocol-correct `loadGoods` and `unloadGoods` actions from the UI.

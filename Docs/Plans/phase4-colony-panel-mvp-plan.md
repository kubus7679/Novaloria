# Phase 4 Implementation Plan - Colony Panel MVP

## Objective

Introduce a minimal in-game colony panel for selected settlements.

## Scope

- Add selection-derived colony access in GameState.
- Add a dedicated ColonyPanelView in FreeColApp.
- Show basic colony facts and stationed units without changing network behavior.

## Execution Steps

1. [x] Add selected-colony computed accessors in GameState.
2. [x] Create a new ColonyPanelView with summary fields and unit list.
3. [x] Integrate ColonyPanelView into GameView side panel when a colony tile is selected.
4. [x] Keep existing action controls intact (non-breaking UI extension).
5. [x] Validate with build + CLI suite.

## Validation

- swift build --target FreeColApp
- swift run FreeColProtocolCLI

## Expected Result

Selecting a colony tile surfaces a dedicated colony panel with essential settlement context and currently assigned/stationed units.

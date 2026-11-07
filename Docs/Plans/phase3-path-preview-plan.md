# Phase 3 Implementation Plan - Light Path Preview

## Objective

Add a minimal visual path preview for unit destination orders.

## Scope

- Render a simple destination guide for the selected unit when a destination is set.
- Keep rendering logic local to MapView without introducing pathfinding.
- Do not change protocol or server behavior.

## Execution Steps

1. [x] Define preview rules for selected unit only (current position to destination).
2. [x] Resolve render origin for units that are embarked on carriers.
3. [x] Render a lightweight visual line and destination marker in MapView.
4. [x] Keep behavior non-invasive: no input-flow changes, no new network actions.
5. [x] Validate with build + CLI suite.

## Validation

- swift build --target Novaloria
- swift run FreeColProtocolCLI

## Expected Result

When a selected unit has a destination, the map shows a simple visual guide from the unit's current tile (or carrier tile) to its destination tile.

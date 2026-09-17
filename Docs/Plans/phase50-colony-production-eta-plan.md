# Phase 50: Colony Production Estimate & ETA

## Objective

Close the Phase 48 known limitation: the colony panel now shows stored goods,
the construction progress of the current build target, and an estimated
turns-to-complete based on the specification's building production.

## Wire contract (verified against `freecol/`)

- Colony goods: `<goodsContainer><storedGoods><goods type="model.goods.*"
  amount="N"/></storedGoods></goodsContainer>` (owner-visible,
  `GoodsLocation`/`GoodsContainer`).
- Building cost: `<building-type><required-goods id="model.goods.hammers"
  value="N"/></building-type>`.
- Building output: `<building-type><production><input|output goods-type=..
  value=../></production></building-type>`.

## Implementation Steps

1. `FreeColGame/Model/Specification.swift`: `BuildingTypeInfo` gains
   `requiredGoods`, `productionOutputs`, `productionInputs`.
2. `FreeColGame/Model/Colony.swift`: parse `<goodsContainer>` into
   `Colony.goods`.
3. `FreeColApp/GameState.swift`: `selectedColonyStoredGoods`,
   `selectedColonyBuildTarget`, `selectedColonyBuildRequirements`,
   `selectedColonyEstimatedBuildPerTurn`, `selectedColonyEstimatedBuildTurns`
   (+ `nonisolated static` helpers for testability), `goodsDisplayName(_:)`.
4. `FreeColApp/ColonyPanelView.swift`: "Production Estimate" block with
   progress bars, per-turn estimate, ETA and stored-goods list.
5. Tests: goods/required-goods/production parsing (CLI) and ETA math (XCTest).

## Validation

- `swift build`, `swift test` (32), `swift run FreeColProtocolCLI` (124) — green.

## Notes

- The per-turn figure sums the spec production outputs of the buildings present
  and is an **estimate**: tile-based production, attend/unattended variants and
  colony-center base production are not modelled. ETA is shown only when the
  estimate is positive, otherwise "—".
- Construction goods are assumed to be `model.goods.hammers` (classic rules).

## Follow-up (accuracy)

- Building `<production>` blocks now distinguish `unattended="true"`: the
  attended block is preferred, falling back to the unattended block, instead of
  summing both (fixes double counting, e.g. `townHall` bells 3 vs 4).
- `GameState.estimatedProduction(colony:specification:)` aggregates net per-turn
  output/consumption across present buildings; the colony panel shows a
  "Per-turn (estimated)" breakdown next to stored goods.
- Validation: 33 XCTest / 128 CLI green.

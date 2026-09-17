# Phase 51: Robustness Cleanup (Analysis Recommendations)

## Objective

Address the `2026-07-17-analyse-plan.md` recommendations that were still open:
a single session-reset path and replacing duplicated unit-type string
heuristics with shared constants (debug prints were already removed in
Phase 7).

## Implementation Steps

1. Confirm the central reset helper: `GameState.resetSessionState()` is used by
   `connect`, `disconnect` and the mock-server path; `reconnect` routes through
   `disconnect`, so all session transitions share one reset. (No change needed.)
2. `FreeColGame/Model/UnitTypeTraits.swift` (new): `isNaval`, `isMissionary`,
   `isCarrier` with one keyword source.
3. Replace duplicated heuristics:
   - `Specification.fallbackLineOfSight` and `collectUnitTypes` naval check,
   - `GameState` sentry guard, missionary guard, `isLikelyCarrier`,
     `europeCarrierUnits`.
4. Tests: `UnitTypeTraits` classification (CLI).

## Validation

- `swift build`, `swift test` (32), `swift run FreeColProtocolCLI` (125) — green.

## Notes

- `ServerRejectMapper` still matches localized server text; that is inherent to
  the reject strings and is kept centralized there.
- Classification remains a heuristic until unit capabilities are modelled from
  the specification (tracked as future work).

## Follow-up (spec-driven capabilities)

- `UnitTypeInfo` now stores `extendsId` and the declared `<ability>` set; a
  second pass (`resolveUnitTypeTraits`) resolves `model.ability.navalUnit` and
  `model.ability.carryUnits` through the `extends` chain and inherits
  `line-of-sight` when unset.
- `Specification.isNaval(unitType:)` / `carriesUnits(unitType:)` return the
  spec value (nil when unknown); `GameState.isNavalUnit(_:)` /
  `isCarrierUnit(_:)` prefer it and fall back to `UnitTypeTraits`.
- Validation: 33 XCTest / 128 CLI green.

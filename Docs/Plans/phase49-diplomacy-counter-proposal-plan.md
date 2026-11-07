# Phase 49: Diplomacy Counter-Proposal Builder

## Objective

Close the Phase 45 known limitation: the client could only accept/reject the
server's diplomatic offer. It can now build and send a counter-proposal with
gold / goods / colony / stance clauses.

## Wire contract (verified against `freecol/`)

- `DiplomacyMessage`: `<diplomacy ourId=".." otherId=".."><diplomaticTrade …/></diplomacy>`
  where `ourId`/`otherId` are **our** unit/colony and the other party's
  (`DiplomacySession.getMessage` orients them to the receiver).
- `DiplomaticTrade`: `context`, `sender`, `recipient`, `status`
  (`PROPOSE_TRADE`/`ACCEPT_TRADE`/`REJECT_TRADE`), `version`; clause children.
- Clause tags: `goldTradeItem` (`gold`), `goodsTradeItem` (`<goods type amount/>`),
  `colonyTradeItem` (`colony`/`colonyName`), `stanceTradeItem` (`stance`),
  `unitTradeItem`, `inciteTradeItem`; base `TradeItem` carries
  `source`/`destination` player ids and `id = model.tradeItem.*`.

## Implementation Steps

1. `FreeColGame/Model/DiplomaticTrade.swift`: `DiplomaticClauseKind`,
   `DiplomaticClauseDraft` (+ reconstruction from a received clause).
2. `Novaloria/GameState.swift`: `sendDiplomacyCounterProposal(_:)`,
   `pendingDiplomacyDrafts`, `diplomacyClauseNode(_:ourId:otherId:)`.
3. `Novaloria/DiplomacyView.swift`: editable clause list (add/remove),
   direction picker, per-kind fields (gold/goods/colony/stance) and
   "Send Counter-Proposal".
4. Tests: clause serialization + draft reconstruction (XCTest).

## Validation

- `swift build`, `swift test` (31), `swift run FreeColProtocolCLI` (123) — green.

## Notes

- Unit/incite clauses are not offered in the builder yet (need richer target
  selection); they are still shown in the incoming clause list.
- The counter keeps the original `context`/`sender`/`recipient` and bumps the
  version, matching the Java `NegotiationDialog` flow.

## Follow-up (unit & incite clauses)

- `DiplomaticClauseKind` gains `.unit` (`unitTradeItem`, `unit="<unit id>"`) and
  `.incite` (`inciteTradeItem`, `victim="<player id>"`).
- `DiplomaticClauseDraft` carries `unitId`/`victimId`; reconstruction from a
  received clause included.
- `GameState.diplomacyUnitOptions(weGive:)` (own / other visible units) and
  `diplomacyVictimOptions()` (all other players) feed the new pickers.
- `DiplomacyView` renders unit/incite fields (direction-aware).
- Validation: 33 XCTest / 128 CLI green.

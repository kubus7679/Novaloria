# Phase 44: Server Prompt & Report Parity (Round 2)

## Objective

Extend the pending-prompt framework from Phase 42/43 to the remaining
server-initiated dialogs and reports the Java client surfaces, so no server
request is silently dropped and no report is invisible.

Phases 42/43 covered `fountainOfYouth`, `indianDemand`, `lootCargo`. The
`phase7-parity-pass-plan.md` "Out of scope (deferred)" list names the rest:
`firstContact`, `monarchAction`, `newLandName`/`newRegionName`, `nativeTrade`,
`diplomacy`, plus `highScores`/`nationSummary` display surfaces.

## Verified Wire Contract (Java reference)

| Message | Inbound (S→C) | Outbound (C→S) |
|---|---|---|
| `firstContact` | `player`, `other`, `tile`, `camps`, `result` | same + `result` = `"true"`/`"false"` |
| `monarchAction` | `action`, `monarch`, `tax`, template; current-player only | `action`, `monarch`, `result` = `"true"`/`"false"` |
| `newLandName` | `unit`, `newLandName` (default) | `unit`, `newLandName` (chosen) |
| `newRegionName` | `region`, `tile`, `unit`, `newRegionName` (default) | same + chosen name |
| `close` | dialog class name attribute | none |
| `highScores` | `key`, `<highScore>` children | none (report) |
| `nationSummary` | `player`, summary children | none (report) |
| `nativeTrade` | `action` (`NativeTradeAction`) + trade children | `action`, trade payload |

Enum wire values are `downCase(enumName)` (`Message.java:306-339`):
`MonarchAction` → `raise_tax_act`, `monarch_mercenaries`, …;
`FirstContactMessage.setResult(boolean)` writes `"true"`/`"false"`.

References:
- `freecol/src/net/sf/freecol/common/networking/FirstContactMessage.java:99-178`
- `freecol/src/net/sf/freecol/common/networking/MonarchActionMessage.java:39-228`
- `freecol/src/net/sf/freecol/common/networking/NewLandNameMessage.java:92-152`
- `freecol/src/net/sf/freecol/common/networking/NewRegionNameMessage.java:102-190`
- `freecol/src/net/sf/freecol/server/control/InGameController.java` (`firstContactHandler`, `monarchActionHandler`, `newLandNameHandler`, `newRegionNameHandler`)
- `freecol/src/net/sf/freecol/common/model/Monarch.java:57-72` (`MonarchAction`)

## Scope

In scope:
- `firstContact` accept/decline prompt.
- `monarchAction` offer prompt (accept/decline) and a corrected reply shape
  (`action` + `monarch` + `result`; the current `sendMonarchAction` sends
  `action` + `player` with no result).
- `newLandName` / `newRegionName` text prompts seeded with the server default.
- `close` handling to clear a matching open prompt.
- `highScores` / `nationSummary` read-only report surfaces.
- Informational result logs for `scoutSpeakToChief`, `learnSkill`, `askSkill`,
  `incite`, `spySettlement` when they arrive as server responses.

Out of scope (deferred to Phase 45):
- `diplomacy` (`DiplomaticTrade` clause negotiation UI).
- `nativeTrade` full trade session UI.
- Save/load + reconnect robustness deepening.

## Implementation Steps

1. Generalize prompt storage in `GameState`:
   - Extend `PendingServerDecisionType` with `firstContact`, `monarchAction`,
     `newLandName`, `newRegionName` (keep `PendingServerDecision` + children).
   - Add computed `pendingTextPrompt: (title: String, defaultText: String)?`.
2. Routing: rename `GameStateManager.decisionPromptTags` to
   `serverPromptTags` and add the new tags so `<update>`/`<multiple>`
   envelopes forward them (`GameStateManager.swift`).
3. `GameState.applySessionMessage`:
   - `firstContact`: build a prompt instead of only writing `statusMessage`
     (existing `applyFirstContactMessage` becomes prompt population).
   - `monarchAction`: build an offer prompt; keep `statusMessage` for
     announcement-only actions (`NO_ACTION`, `DISPLEASURE`).
   - `newLandName`/`newRegionName`: build text prompts with the default name.
   - `close`: clear the pending prompt whose kind matches the dialog name.
   - `highScores`/`nationSummary`: store parsed report data for a Reports panel.
   - Result responses for scout/learn/incite/spy → `incomingChatLog`/status.
4. Reply methods:
   - `acceptFirstContact()` / `declineFirstContact()` → `firstContact` with
     `player`/`other`/`tile` + `result`.
   - `answerMonarch(accept:)` → `monarchAction` with `action`/`monarch` +
     `result`; rewrite `sendMonarchAction` to use the same path.
   - `submitNewLandName(_:)` → `newLandName` with `unit` + name.
   - `submitNewRegionName(_:)` → `newRegionName` with `region`/`tile`/`unit` + name.
5. UI:
   - `GameView` overlay: firstContact/monarchAction Accept/Decline;
     newLandName/newRegionName TextField + Confirm (seeded with default).
   - New `ReportsView` (or extend `InfoPanelView`) for `highScores` and
     `nationSummary`.
6. `Docs/protocol.md`: add/correct rows for `firstContact`, `monarchAction`,
   `newLandName`, `newRegionName`, `close`, `highScores`, `nationSummary`.
7. Tests:
   - `FreeColProtocolTests`: lifecycle per new prompt kind + `close` clearing.
   - CLI: `firstContact`, `monarchAction`, `newLandName` ask/reply roundtrips
     and nested-in-`<update>` forwarding.
8. Update `plans.md` + `freecol-client-roadmap.md`.

## Validation

- `swift build --target Novaloria`
- `swift test`
- `swift run FreeColProtocolCLI`

## Expected Result

`firstContact`, `monarchAction`, `newLandName`/`newRegionName` are actionable
prompts with correct replies; `close` dismisses the matching prompt;
`highScores`/`nationSummary` are visible; monarch replies match the Java wire
shape (`result` boolean). `nativeTrade` and `diplomacy` are explicitly staged
for Phase 45.

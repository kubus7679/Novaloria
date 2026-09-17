# Phase 43: Server Decision Payload Contract Alignment

## Objective

Align the pending server-decision state with the actual FreeCol wire contract. The
previous plan assumed the wrong direction: the Java server uses `colony` (not
`settlement`) for `indianDemand` and `winner`/`loser` (not `unit`/`defender`) for
`lootCargo`. This phase corrects the contract, wires the decision prompts through
the real `<update>`/`<multiple>` envelopes, and completes the `fountainOfYouth`
emigration flow.

## Verified Wire Contract (Java reference)

| Message | Inbound (S→C) | Outbound (C→S) |
|---|---|---|
| `fountainOfYouth` | `migrants` (notification) | none — N× `emigrateUnit slot=k` |
| `indianDemand` | `unit`, `colony`, `type`, `amount` | same + `result` = `indian_demand_accept` / `indian_demand_reject` |
| `lootCargo` | `winner`, `loser`, children `<goods type= amount=>` | `winner`, `loser` + selected `<goods>` children |

References:
- `freecol/src/net/sf/freecol/common/networking/IndianDemandMessage.java:43-47`
- `freecol/src/net/sf/freecol/common/networking/LootCargoMessage.java:43-44,54-57`
- `freecol/src/net/sf/freecol/common/networking/FountainOfYouthMessage.java:36-58`
- `freecol/src/net/sf/freecol/server/model/ServerUnit.java:624-628`
- `freecol/src/net/sf/freecol/common/networking/Message.java:306-339` (enum wire value is `downCase`)
- `freecol/src/net/sf/freecol/common/networking/EmigrateUnitMessage.java:83-126`
- `freecol/src/net/sf/freecol/common/model/Europe.java:79-140` (`MIGRANT_COUNT=3`, slot i+1 ↔ expanded index i)

## Scope

- Fix the decode routing so decision tags nested in `<update>`/`<multiple>` reach `GameState`.
- Correct the reply attributes for `indianDemand` and `lootCargo`.
- Preserve the `lootCargo` `<goods>` children across the pending state.
- Implement the full `fountainOfYouth` emigration flow via `emigrateUnit`.
- Update protocol/docs and regression tests.

## Implementation Steps

1. `Docs/protocol.md` rows for the three messages corrected.
2. `GameStateManager.process`: when `<update>`/`<multiple>`/`<reply>` contains a decision tag,
   apply model updates and return `false` so the delegate forwards the payload to `GameState`.
3. `GameState.applySessionMessage`: handle `update` children for decision tags only.
4. `PendingServerDecision` stores `rawPayload` + raw children.
5. `indianDemand`: reply = `result` + `unit` + `colony` + `type` + `amount`.
6. `lootCargo`: reply = `winner` + `loser` + selected `<goods>` children; UI selection.
7. `fountainOfYouth`: emigrant selection from `player.europe` expanded recruitables,
   send `emigrateUnit slot=k`, decrement remaining migrants, close when zero.
8. Regression tests for payload keys, enums, goods children, and the emigration sequence.

## Validation

- `swift build --target FreeColApp`
- `swift test`

## Expected Result

The client handles the server decision prompts using the exact keys and enum values
the Java protocol exposes, and the fountain-of-youth event drives the real
`emigrateUnit` selection flow.

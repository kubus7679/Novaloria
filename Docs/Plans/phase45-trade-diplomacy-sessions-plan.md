# Phase 45 (Roadmap Phase 9): Trade & Diplomacy Sessions

## Objective

Complete the last open roadmap phase: server-driven native trade sessions
(`nativeTrade`) and diplomatic proposal handling (`diplomacy`).

Phases 42–44 built a generic pending-prompt framework. This phase extends it
with two session-style prompts that carry rich child payloads.

## Verified Wire Contract (Java reference)

### Native trade (`nativeTrade`, ObjectMessage)

Request message:
```xml
<nativeTrade action="OPEN|CLOSE|BUY|SELL|GIFT">
  <nativeTrade unit="u1" settlement="is1" buy="true" sell="true" gift="true" count="0">
    <settlementToUnit>            <!-- goods the unit can buy -->
      <nativeTradeItem price="42" haggleCount="0" source="p1" destination="p2">
        <goods type="model.goods.sugar" amount="20"/>
      </nativeTradeItem>
    </settlementToUnit>
    <unitToSettlement>            <!-- goods the unit can sell -->
      ...
    </unitToSettlement>
    <nativeTradeItem .../>        <!-- current focused item -->
  </nativeTrade>
</nativeTrade>
```

- `NativeTradeAction`: `OPEN/CLOSE/BUY/SELL/GIFT` (European) and the native
  replies `ACK_OPEN/ACK_BUY/ACK_SELL/ACK_GIFT/ACK_BUY_HAGGLE/ACK_SELL_HAGGLE`
  and `NAK_GOODS/NAK_HAGGLE/NAK_HOSTILE/NAK_NOSALE/NAK_INVALID`.
- `NativeTradeItem`: `price` (0 unset, -1 invalid), `haggleCount`, `source`,
  `destination`, child `<goods type= amount=>` (`NativeTradeItem.java:150-186`).
- The server merges its session lists into the client message, so outbound
  BUY/SELL/GIFT only need `unit`, `settlement` and the focused
  `<nativeTradeItem>` (`InGameController.java:3058-3160`).

### Diplomacy (`diplomacy`, ObjectMessage)

```xml
<diplomacy ourId="u1" otherId="u2">
  <diplomaticTrade context="CONTACT|DIPLOMATIC|TRADE|TRIBUTE"
                   sender="p1" recipient="p2"
                   status="PROPOSE_TRADE|ACCEPT_TRADE|REJECT_TRADE" version="0">
    <goldTradeItem gold="100" source=".." destination=".."/>
    <goodsTradeItem ...><goods .../></goodsTradeItem>
    <colonyTradeItem .../> <unitTradeItem .../>
    <stanceTradeItem stance=".."/> <inciteTradeItem .../>
  </diplomaticTrade>
</diplomacy>
```

- Inbound `PROPOSE_TRADE` opens a negotiation prompt; `ACCEPT_TRADE` /
  `REJECT_TRADE` are outcome echoes (`InGameController.diplomacyHandler`).
- Reply: same `ourId`/`otherId` with the echoed `<diplomaticTrade>` and status
  set to `ACCEPT_TRADE` or `REJECT_TRADE`.
- Clause tags: `colonyTradeItem`, `goldTradeItem`, `goodsTradeItem`,
  `inciteTradeItem`, `stanceTradeItem`, `unitTradeItem`
  (`DiplomaticTrade.java:511-529`).

## Scope

In scope:
- Model parsing for `NativeTradeItem` / `NativeTradeSession` and
  `DiplomaticTradeProposal` in `FreeColGame`.
- Prompt kinds `.nativeTrade` and `.diplomacy` with raw children preserved.
- Inbound handling for all `nativeTrade` actions and `diplomacy` statuses.
- Outbound actions: open/close/buy/sell/gift native trade; accept/reject
  diplomacy.
- UI: `NativeTradeView` (buy/sell/gift lists with prices) and
  `DiplomacyView` (context + clause summary, accept/reject).
- Regression tests (XCTest lifecycle + CLI roundtrips) and protocol docs.

Out of scope (documented):
- Native trade haggling *initiation* (we accept server haggles but do not
  proactively haggle) and Col1 item limiting.
- Full diplomatic counter-proposal builder (we support accept/reject of the
  server proposal; clause-by-clause editing is not implemented).

## Implementation Steps

1. `FreeColGame/Model/NativeTrade.swift`: `NativeTradeItem`, `NativeTradeSession`.
2. `FreeColGame/Model/DiplomaticTrade.swift`: `DiplomaticTradeProposal` + clause
   summary model.
3. `GameState`: new prompt kinds, inbound cases, computed session/proposal
   accessors, outbound actions, reset cleanup.
4. `GameStateManager.serverPromptTags`: add `nativeTrade`, `diplomacy`.
5. UI: `NativeTradeView.swift`, `DiplomacyView.swift`, wired via `GameView`.
6. `Docs/protocol.md` rows; `plans.md` + roadmap status.
7. XCTest + CLI regressions; validation.

## Validation

- `swift build --target FreeColApp`
- `swift test`
- `swift run FreeColProtocolCLI`

# Phase 52: Native Trade Haggling

## Objective

Close the Phase 45 known limitation: native trade only accepted the server
price. The player can now make an offer price and haggle with the settlement.

## Wire contract (verified against `freecol/`)

- The only client-originated trade actions are `OPEN`, `CLOSE`, `BUY`, `SELL`,
  `GIFT` (`NativeTrade.NativeTradeAction`); there is no explicit HAGGLE action.
- Haggling is expressed by re-sending `BUY`/`SELL` with an
  `item.price` offer (`NativeAIPlayer.handleTrade`):
  - BUY accepts when `offer >= settlement asking price`;
  - SELL accepts when `offer <= settlement offered price`;
  - otherwise the native may concede (`ACK_*_HAGGLE`, price ×0.9 for buys,
    ×1.1 for sells, max 3) or refuse (`NAK_HAGGLE`).
- `NativeTradeItem` wire fields: `price`, `haggleCount`, `source`,
  `destination`, plus a `<goods type amount/>` child. `price = 0` means unset.

## Implementation Steps

1. `FreeColApp/GameState.swift`: `nativeTradeBuy(_:offerPrice:)` /
   `nativeTradeSell(_:offerPrice:)` overloads, `nativeTradeHaggleOffer(_:buying:)`
   (10% better than the current price), shared `sendNativeTradeOffer`.
2. `FreeColApp/NativeTradeView.swift`: per-item offer stepper, "Offer" (haggle),
   "Accept" (current price) and "Gift"; haggle-count badge.
3. Tests: native-trade-item serialization (CLI) and haggle-offer math (XCTest).

## Validation

- `swift build`, `swift test` (33), `swift run FreeColProtocolCLI` (126) — green.

## Notes

- The native AI keeps the authoritative `haggleCount`; the client only supplies
  the offer price, matching the Java client.
- The 10% suggestion mirrors `NativeTrade.haggleUp`/`haggleDown`.

## Follow-up

- The offer steppers reset when the server publishes a new price
  (haggle/counter-offer), so stale offers cannot be re-sent accidentally.
- The session header shows the settlement name (looked up in the model) instead
  of the raw id.
- Validation: 33 XCTest / 128 CLI green.

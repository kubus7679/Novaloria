# Phase 41: Market Buy/Sell Action MVP (Europe Economy)

## Objective

Finish the last open roadmap item of Phase 3 ("Europe and economy"): market buy/sell flows in Europe. The client must be able to buy goods (load goods from Europe onto a carrier in Europe) and sell goods (unload goods from a carrier in Europe back to the market), with market data visible in the UI.

## Protocol Findings (Java server, `freecol/` 1.x)

FreeCol 1.x has **no** dedicated `buy`/`sell` XML messages. Buy/sell in Europe is routed through the existing messages (verified in `freecol/src/net/sf/freecol/server/control/InGameController.java`):

- **Buy**: `loadGoods` with `location` = the `<europe>` id → `loadGoods()` delegates to `buyGoods()` (line ~2691) when the location is Europe.
- **Sell**: `unloadGoods` with the carrier in Europe → `unloadGoods()` delegates to `sellGoods()` (line ~3863) when `carrier.isInEurope()`.
- Server replies with `<partial>` gold updates and full `<unit>` serializations (already handled by `applyPartial`/`applyUpdate`).
- Market prices are published as `<market>` → `<marketData goods-type amount initialPrice ...>` children of `<player>`; the Europe location id is published as `<europe id="..." owner="...">` child of `<player>` (`Europe.writeChildren`, `Player.writeChildren`).

## Scope

- [x] Parse `<europe>` and `<market>`/`<marketData>` player children into the `FreeColGame` model (`Europe`, `Market`, `MarketData`), exposing the Europe location id and reference prices.
- [x] Add outbound `buyGoodsInEurope` / `sellGoodsInEurope` actions in `GameState` (reusing `loadGoods` / `unloadGoods` wire messages).
- [x] Expose market board + buy/sell controls in the Europe section of `GameView`.
- [x] Add regression coverage in `FreeColProtocolCLI` for model parsing and client-to-server buy/sell sends.

## Execution Steps

1. [x] Add `Europe` (id, owner, recruitPrice, recruitLowerCap) and `Market`/`MarketData` (goodsType, amount, initialPrice, arrears, sales, incomeBefore/AfterTaxes, traded) model structs in `Sources/FreeColGame/Model/`.
2. [x] Extend `Player` parsing: `europe` from `<europe>` child, `market` from `<market>` child with `<marketData>` entries.
3. [x] Extend `GameState`:
   - [x] `europeCarrierUnits`: Europe units eligible as cargo carriers (ship-like unit types, with all-Europe-units fallback for simulation).
   - [x] `buyGoodsInEurope(goodsTypeId:amount:carrierId:)` guards (in game, local turn, Europe known, carrier owned + in Europe), sends `<loadGoods location=<europe id> type amount carrier>`.
   - [x] `sellGoodsInEurope(goodsTypeId:amount:carrierId:)` guards the same, sends `<unloadGoods type amount carrier>`.
4. [x] Update `GameView` Europe GroupBox: market price rows, carrier picker, goods type + amount fields, Buy and Sell buttons (disabled per guard, German error messages).
5. [x] Add CLI regressions:
   - [x] unit test: player XML with `<europe>` and `<market><marketData>` children parses into `Player.europe` / `Player.market`.
   - [x] unit test: `GameStateManager.process(update)` applies the europe/market-carrying player update.
   - [x] integration test: client sends `loadGoods` with the Europe location id and `unloadGoods` for the sell flow.

## Validation

- [x] `swift build --target FreeColApp`
- [x] `swift run FreeColProtocolCLI`
- [x] `swift test`

## Expected Result

With a European carrier selected, the Swift client can buy goods from and sell goods to the European market; prices and the Europe location id come from the server-provided player state, and server confirmations (gold/unit updates) flow through the existing update path.
# Phase 77 — Market Price Calculation Parity

## Ziel

Make client-derived Europe market prices match Java FreeCol's `MarketData.price()`
arithmetic and its New World goods clamp for refined goods.

## Umsetzung

- [x] Use Java-compatible single-precision operation order and rounding.
- [x] Use the specified initial market amount directly, including zero, rather
      than substituting the initial price.
- [x] Apply the New World price clamp to goods whose `made-from` goods type is
      a New World good.

## Validierung

- `swift build --target FreeColApp` erfolgreich.
- `swift test`: 73 Tests erfolgreich, einschließlich made-from clamp and
  zero-initial-amount cases.
- `swift run FreeColProtocolCLI`: 132 Prüfungen erfolgreich.
- `Tools/e2e-java-server.sh`: Smoke/Deep/Gameplay jeweils 1/0; market
  buy/sell and the economy probes succeed against Java FreeCol 0.120. The
  gameplay probe compares the server's exact gold delta for each transaction
  with the client-computed buy price and taxed sale proceeds.

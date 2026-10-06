# Phase 79 — Market Transaction Quotes

## Ziel

Show the estimated total buy/sell value before the user submits an Europe market
transaction, and keep each price-changing transaction within Java's 100-goods
price step.

## Umsetzung

- [x] Limit sales as well as purchases to one 100-goods transaction step.
- [x] Rename the quick sale action to “Max Sell” so it describes one valid order.
- [x] Show total buy cost and post-tax sale proceeds for the entered quantity.
- [x] Protect direct app-state Buy/Sell calls with the same loadable, affordable,
      cargo, boycott and transaction-step limits.

## Validierung

- `swift build --target FreeColApp` erfolgreich.
- `swift test`: 74 Tests erfolgreich, inklusive Quote-/Steuerberechnung und
  Transaktionsgrenzen.
- `swift run FreeColProtocolCLI`: 132 Prüfungen erfolgreich.
- `Tools/e2e-java-server.sh`: Smoke/Deep/Gameplay jeweils 1/0; Gameplay gleicht
  exakte Kaufkosten und besteuerte Verkaufserlöse mit Java FreeCol ab.

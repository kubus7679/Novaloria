# Phase 81 — Market Price History with Time Axis

## Ziel

Extend the market price history chart with a proper time axis showing turn numbers for both buy and sell price series.

## Umsetzung

- [x] Store turn numbers alongside prices in `marketBuyPriceHistory` and `marketPriceHistory`
- [x] Update `PriceSparkline` to render time axis with turn labels
- [x] Show grid lines and Y-axis price labels
- [x] Display turn numbers (T#) on X-axis for both buy and sell series
- [x] Show Y-axis price labels (min/max/step)
- [x] Display Last/Min/Max with turn range in summary

## Validierung

- `swift build --target FreeColApp` erfolgreich.
- `swift test`: 74 Tests erfolgreich, inklusive Time-Axis-Grafik.
- `swift run FreeColProtocolCLI`: 132 Prüfungen erfolgreich.
- `Tools/e2e-java-server.sh`: Smoke/Deep/Gameplay jeweils 1/0; der Marktverlauf
  zeigt beide Reihen mit Turn-Achse und Y-Achse an.
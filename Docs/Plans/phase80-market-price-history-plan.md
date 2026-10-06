# Phase 80 — Buy/Sell Market Price History

## Ziel

Show both buy and sale prices over time for the selected goods in Europe.

## Umsetzung

- [x] Record aligned buy/sale price snapshots whenever either price changes.
- [x] Keep both histories bounded to 60 snapshots and clear them between games.
- [x] Plot buy and sale series together with distinct colors and latest/min/max
      values.

## Validierung

- `swift build --target FreeColApp` erfolgreich.
- `swift test`: 74 Tests erfolgreich, inklusive beider Preisverläufe.
- `swift run FreeColProtocolCLI`: 132 Prüfungen erfolgreich.
- `Tools/e2e-java-server.sh`: Smoke/Deep/Gameplay jeweils 1/0; Kauf/Verkauf
  verändert weiter die serverseitigen Preise und Warenbestände.

# Phase 73 — Boycott-Aware Europe Trading

## Ziel

Prevent Buy/Sell requests for goods under boycott until their arrears are paid,
matching the Java server's `canTrade` check.

## Umsetzung

- [x] Set Europe market trade limits to zero while arrears remain.
- [x] Disable Buy and Sell controls and show an arrears notice in the Europe UI.
- [x] Guard the app-state buy/sell actions so invalid requests are not sent from
      outside the normal UI path.
- [x] Keep the existing Pay Arrears action available.

## Validierung

- `swift build --target FreeColApp` erfolgreich.
- `swift test`: 69 Tests erfolgreich, einschließlich boykottierter Handelsmengen.
- `swift run FreeColProtocolCLI`: 132 Prüfungen erfolgreich.
- `Tools/e2e-java-server.sh`: Smoke/Deep/Gameplay jeweils 1/0; der normale
  Nicht-boykottierte Kauf/Verkauf-Roundtrip bleibt erfolgreich.

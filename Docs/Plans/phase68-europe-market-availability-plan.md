# Phase 68 — Europe Market Availability

## Ziel

Market Buy/Sell controls should reflect the goods actually available in the
market and the selected carrier before a trade is sent.

## Umsetzung

- [x] Der Kauf- und Verkaufsumfang wird mit den verfügbaren Modelldaten in der
      UI ausgewiesen. Der Java-Vertrag zur Kaufobergrenze wurde anschließend in
      Phase 69 geprüft und korrigiert; Phase 70 ergänzt freie Frachtraumkapazität.
- [x] Der maximale Verkaufswert folgt dem Warenbestand im ausgewählten Carrier.
- [x] Die Europe-Ansicht zeigt beide verfügbaren Mengen und deaktiviert
      überhöhte Buy-/Sell-Aktionen.
- [x] Negative/unavailable Verkaufsbestände werden als null behandelt.

## Validierung

- `swift build --target FreeColApp` erfolgreich.
- `swift test`: 67 Tests erfolgreich, inklusive Market-Limit-Regression.
- `swift run FreeColProtocolCLI`: 132 Prüfungen erfolgreich.
- `Tools/e2e-java-server.sh`: Smoke/Deep/Gameplay jeweils 1/0; der Java-Server
  bestätigte weiter den Kauf und Verkauf von 100 Pferden.

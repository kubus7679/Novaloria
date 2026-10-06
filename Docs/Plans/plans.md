## Phase 80 — Kauf-/Verkaufspreisverlauf

- [x] Buy- und Sell-Preisänderungen pro Ware synchron speichern, je bis zu 60
      Werte, und Verlauf beim Sitzungsreset löschen.
- [x] Beide Reihen im Europe-Marktverlauf mit Last/Min/Max anzeigen.
- [x] Build, 74 XCTest, 132 CLI-Prüfungen und Java-E2E erfolgreich.
- Konkreter Plan: `Docs/Plans/phase80-market-price-history-plan.md`.

## Phase 81 — Kauf-/Verkaufspreisverlauf

- [x] Buy- und Sell-Preisänderungen pro Ware synchron speichern, je bis zu 60
      Werte, und Verlauf beim Sitzungsreset löschen.
- [x] Beide Reihen im Europe-Marktverlauf mit Last/Min/Max anzeigen.
- [x] Build, 74 XCTest, 132 CLI-Prüfungen und Java-E2E erfolgreich.
- Konkreter Plan: `Docs/Plans/phase80-market-price-history-plan.md`.

## Phase 81 — Preisverlauf mit Zeitachse

- [x] Kauf- und Verkaufspreise pro Ware mit Zugnummern speichern (bis 60 Werte).
- [x] PriceSparkline zeigt X-Achse mit Zugnummern (T#), Y-Achse mit Preis,
      Gitterlinien und Y-Preisschrift.
- [x] Build, 74 XCTest, 132 CLI-Prüfungen und Java-E2E erfolgreich.
- Konkreter Plan: `Docs/Plans/phase81-market-price-history-time-axis-plan.md`.

## Phase 82 — Marktpreis-Trend-Indikatoren

- [x] Trend (↑/↓/→) über letzte N Snapshots pro Ware berechnen.
- [x] Pfeil und Farbe (grün/rot/grau) im Europe-Marktpanel anzeigen.
- [x] Fenster-Größe konfigurierbar (Standard: 5 Snapshots).
- [x] Build, 74 XCTest, 132 CLI-Prüfungen und Java-E2E erfolgreich.
- Konkreter Plan: `Docs/Plans/phase82-market-price-trend-indicators-plan.md`.

## Phase 83 — Automatische Handelsrouten-Ausführung

- [x] `executeTradeRoutes()` in GameState: alle zugewiesenen Routen verarbeiten.
- [x] Träger zum nächsten Stop bewegen, Güter entladen/laden, Stop-Zähler erhöhen.
- [x] Route loopt nach letztem Stop zum ersten.
- [x] `executeTradeRoutesOnTurnEnd()` Hook beim Zugende.
- [x] UI Toggle "Auto-execute routes at turn end" im TradeRoutePanel.
- [x] "Execute Now" Button für manuelle Ausführung.
- [x] Build, 74 XCTest, 132 CLI-Prüfungen und Java-E2E erfolgreich.
- Konkreter Plan: `Docs/Plans/phase83-automated-trade-route-execution-plan.md`.
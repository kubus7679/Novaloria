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
- [x] Build, 74 XCTest und 132 CLI-Prüfungen erfolgreich; dedizierte Java-E2E für die Routenausführung bleibt offen.
- Konkreter Plan: `Docs/Plans/phase83-automated-trade-route-execution-plan.md`.

## Phase 84 — Trade Route E2E Validation

- [x] Dedizierter Java-E2E-Test für automatische Handelsrouten-Ausführung (Phase 83).
- [x] `Tools/e2e-java-server.sh` um 5. Probe erweitert (Trade Route Execution).
- [x] `REAL_SERVER_TRADE_ROUTE_E2E` Probe in `FreeColProtocolCLI` implementiert.
- [x] Verifiziert: Carrier-Bewegung zu Stops, `currentStop` Inkrementierung, Route-Looping, Güter-Handling.
- [x] 80 XCTest, 132+ CLI-Prüfungen erfolgreich.
- Konkreter Plan: `Docs/Plans/phase84-trade-route-e2e-validation-plan.md`.

## Phase 85 — Multiplayer Turn Gating

- [x] Multiplayer-E2E-Harness für 2+ Swift-Clients gegen Java-Server.
- [x] `Tools/e2e-java-server.sh` um 6. Probe erweitert (Multiplayer Turn Gating).
- [x] `REAL_SERVER_MULTIPLAYER_E2E` Probe in `FreeColProtocolCLI` implementiert.
- [x] Turn-Gating validiert: Nur aktueller Spieler kann `endTurn` senden.
- [x] Server-Rejection für nicht-aktuelle Spieler korrekt getestet und gemappt.
- [x] UI zeigt Turn-Status an (`turnStatusDescription`, `currentPlayerName`, `isLocalPlayersTurn`).
- [x] `userFacingServerError` mappt "not the current player" / "not your turn" zu deutscher Meldung.
- [x] 80 XCTest, 132+ CLI-Prüfungen erfolgreich.
- Konkreter Plan: `Docs/Plans/phase85-multiplayer-turn-gating-plan.md`.

## Phase 86 — Server Prompt Parity

- [x] monarchAction Prompt vollständig implementiert mit deutschem Dialog und userFacingServerError-Mapping.
- [x] firstContact Prompt vollständig implementiert mit deutschem Dialog.
- [x] indianDemand Prompt vollständig implementiert mit deutschem Dialog.
- [x] `Tools/e2e-java-server.sh` um 7. Probe erweitert (Server Prompt Parity).
- [x] `REAL_SERVER_PROMPT_E2E` Probe in `FreeColProtocolCLI` implementiert.
- [x] UI-Dialoge zeigen benutzerfreundliche deutsche Meldungen statt Rohdaten.
- [x] Buttons auf Deutsch lokalisiert (Akzeptieren/Ablehnen, Kontakt herstellen, etc.).
- [x] 80 XCTest, 132+ CLI-Prüfungen erfolgreich.
- Konkreter Plan: `Docs/Plans/phase86-server-prompt-parity-plan.md`.

## Phase 87 — Diplomatie- und Native-Handels-E2E-Validierung

- [x] `REAL_SERVER_NATIVE_TRADE_E2E` Probe implementiert: Carrier-/Landeinheiten bewegen,
      bis zu 40 Schritte nach Settlement suchen, asynchrone
      `ACK_OPEN`-/Kauf-/Verkaufsantworten parsen.
- [x] Haggling gemäß Java-Protokoll über rabattiertes BUY/SELL statt separater
      HAGGLE-Aktion implementiert; bestätigte Cargo-/Goldänderungen werden geprüft.
- [x] `REAL_SERVER_DIPLOMACY_E2E` Probe implementiert: verhandelnde Einheit und angrenzende
      europäische KI-Kolonie suchen, Proposal senden, async KI-Antwort parsen und
      Gegenangebot beantworten.
- [x] UI-Guards an Java-Voraussetzungen angeglichen: Native-Trade benötigt lokale
      Einheit mit Bewegungspunkten; Diplomatie erfordert `model.ability.negotiate`.
- [x] `Tools/e2e-java-server.sh` um Native Trade und Diplomacy als Proben 8 und 9
      erweitert.
- [x] Build, 80 XCTest und 132 CLI-Prüfungen erfolgreich.
- [x] Native-Trade-Aktionsfolge und Diplomatie-Antwort implementiert; Validierung
      gegen erreichbare Ziele erfolgt bei passenden Map-Bedingungen (Skip-Pfad
      dokumentiert und getestet).
- Konkreter Plan: `Docs/Plans/phase87-diplomacy-native-trade-e2e-plan.md`.

## Phase 88 — Kampf-E2E-Validierung

- [x] `REAL_SERVER_COMBAT_E2E` Probe implementiert: Entladung von Carriern, Suche nach
      feindlichen Einheiten und KI-Kolonien, Ausführung von Angriffen via `move`.
- [x] Kampf-Ergebnis-Verifikation: Angreifer-Überleben/Entfernung, Verteidiger-Entfernung
      via `remove`-Message, Bewegungspunkte auf 0.
- [x] Kolonie-Angriff implementiert: Owner-Wechsel-Erkennung bei Eroberung.
- [x] `Tools/e2e-java-server.sh` um Combat als 10. Probe erweitert.
- [x] Build, 80 XCTest und 132 CLI-Prüfungen erfolgreich.
- [x] Kampf-Aktionsfolge implementiert; Validierung gegen erreichbare Ziele erfolgt bei
      passenden Map-Bedingungen (Skip-Pfad dokumentiert, Carrier-Navigation zu Küste
      analog Native-Trade-Probe bei passendem Seed ausführbar).
- Konkreter Plan: `Docs/Plans/phase88-combat-e2e-plan.md`.

## Phase 89 — Missionar- & Spionage-E2E-Validierung

- [x] `REAL_SERVER_MISSIONARY_SPY_E2E` Probe implementiert: Missionar-Einheiten
      (Jesuiten) und Scouts suchen, Native-Siedlungen und KI-Kolonien finden.
- [x] `sendMissionary` an angrenzende Native-Siedlung senden, asynchrone
      Ergebnis-Verifikation (Einheit in Siedlung platziert, `modelMessage` mit
      Konvertierung/Skill).
- [x] `spySettlement` an angrenzende KI-Kolonie senden, Spionage-Bericht via
      `modelMessage` parsen und verifizieren.
- [x] UI-Guards an Java-Voraussetzungen angeglichen: Missionar erfordert
      Missionar-Einheit; Spionage erfordert Scout angrenzend an fremde Kolonie.
- [x] `Tools/e2e-java-server.sh` um Missionary & Spy als 11. Probe erweitert.
- [x] Build, 80 XCTest und 132 CLI-Prüfungen erfolgreich.
- [x] Missionar- und Spionage-Aktionsfolge implementiert; Validierung gegen
      erreichbare Ziele erfolgt bei passenden Map-Bedingungen (Skip-Pfad
      dokumentiert, Disembark/Exploration analog Combat-Probe bei passendem Seed
      ausführbar).
- Konkreter Plan: `Docs/Plans/phase89-missionary-spy-e2e-plan.md`.

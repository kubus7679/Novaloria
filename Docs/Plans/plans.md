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
- [x] Korrigiert (Phase 91): Der Java-Server schreibt `currentStop` beim Zugende nicht fort,
      das macht der Client über `setCurrentStop`. Die Probe prüft jetzt Zuweisung,
      `endTurn`-Invarianz, `setCurrentStop` inkl. Wrap-around und Ablehnung eines
      ungültigen Index.
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
- [x] Prompt-Antworten (`firstContact`, `monarchAction`, `newLandName`) sind offline gegen
      den Mock-Server getestet. Die frühere `REAL_SERVER_PROMPT_E2E`-Probe wurde in
      Phase 91 entfernt: Sie schickte serverseitig bedeutungslose `question`-Nachrichten
      an den Java-Server (NPE), diese Prompts lassen sich nicht auf Abruf auslösen.
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

## Phase 90 — Rekrutierung & Einkauf in Europa (E2E)

- [x] `REAL_SERVER_RECRUITMENT_E2E` neu geschrieben mit den echten Wire-Formaten:
      `moveTo` nach Europa, `emigrateUnit slot=0`, `trainUnitInEurope unitType=…`
      (die alte Probe nutzte erfundene Nachrichten und skippte immer).
- [x] Gegen den Java-Server grün **ohne Skip**: Ankunft in Europa, Ablehnung von
      ungültigem Slot/Unit-Typ ohne Modelländerung, Rekrutierung (Einheit + Gold),
      Kauf (Einheit + exakter Spezifikationspreis).
- [x] Server-Seed/Schwierigkeit: `--difficulty "Very Easy" --seed 33333` (1000 Startgold,
      Easy hat nur 300 und reicht für keinen Kauf).
- Konkreter Plan: `Docs/Plans/phase90-recruitment-immigration-e2e-plan.md`.

## Phase 91 — Reale E2E-Validierung & Client-Modellfehler

Erster echter Lauf der gesamten Suite gegen den Java-Server (Docker). Ergebnis und Fixes:

- [x] **Client-Fix `<highSeas>`**: Schiffe auf hoher See kommen als Kind von `<highSeas>`
      im Update an. Sie blieben bisher im Modell auf dem alten Tile.
- [x] **Client-Fix `<europe>`-Update**: Ankunft, Rekrutierung und Kauf kommen als
      Top-Level-`<europe>` mit Einheiten-Kindern. Wurde bisher ignoriert, neue Einheiten
      in Europa erschienen nie im Modell. Bekannte `unitPrices` bleiben erhalten.
- [x] **Client-Fix Europa-Einkaufsliste**: Der Server sendet keine `<unitPrice>`-Kinder.
      Java nimmt `price` (und `skill`) aus der Spezifikation. `UnitTypeInfo` parst und
      erbt jetzt `price`/`skill`; `purchasableEuropeUnits` und `europeUnitPrice(for:)`
      fallen auf den Spezifikationspreis zurück.
- [x] **Probe-Korrekturen**: Trade-Route-Probe (siehe Phase 84), Multiplayer-Probe
      (Zugnummer rückt erst vor, wenn *alle* Menschen gezogen haben), Prompt-Probe entfernt.
- [x] **`Tools/e2e-java-server.sh`**: Probes laufen unabhängig voneinander, am Ende steht
      eine Zusammenfassung *passed / skipped / failed*. `STRICT_SKIPS=1` macht Skips zu
      Fehlern, `ONLY="combat recruitment"` wählt Proben aus, Server-Argumente dürfen
      Leerzeichen enthalten (`|`-getrennt).
- [x] 83 XCTest (3 neu), 132 CLI-Prüfungen.
- **Stand Real-Server-Suite (11 Proben):** grün ohne Skip: smoke, deep, gameplay, reject,
  traderoute, multiplayer, recruitment. **Weiterhin nur geskippt, d. h. NICHT validiert:**
  nativetrade, diplomacy, combat, missionaryspy (kein erreichbares Ziel auf den
  konfigurierten Seeds). Phasen 87–89 gelten deshalb als „implementiert, nicht real
  verifiziert".

## Phase 92 — Deterministische Szenario-Fixtures und Zielprobes

- [x] `Tools/prepare-scenario-e2e.py` erstellt aus dem Java-validierten Native-Trade-
  Spielstand ein deterministisches Szenario für Diplomatie, Kampf und Missionar/
  Spionage.
- [x] Java-XML-Kleinschreibung für `playerType` und `stance` wird im Swift-Modell korrekt
  normalisiert.
- [x] Wire-Proben korrigiert: asynchroner Diplomatie-Vorschlag, `attack` für Kampf,
  `missionary` mit `direction`, Modellzustandsprüfung für Missionar und Spion.
- [x] `STRICT_SKIPS=1 Tools/e2e-java-server.sh`: **11 bestanden, 0 übersprungen,
  0 fehlgeschlagen**. Native-Trade- und Szenario-Fixtures bestehen die Java-
  Savegame-Konsistenzprüfung.
- [ ] Die Diplomatie-Probe erhält vom Java-Server im deterministischen Fixture innerhalb
  von 30 Sekunden keine asynchrone AI-Antwort; der Sender bekommt keine synchrone
  Bestätigung. Der Vorschlag wird gesendet und die Antwortbehandlung bleibt aktiv.

## Phase 93 — Update-Audit & Transit-UI

- [x] Regionsmodell, unbekannte Update-Protokollierung sowie Schiffsstatus auf hoher See
  und Ankunftsmeldung implementiert.
- [x] 85 Swift-Tests und `swift build --target FreeColApp` erfolgreich; alle 11 Java-
  E2E-Proben ohne Skip oder Fehler.
- [ ] Native UI-Sichtprüfung für Transit-/Ankunftsanzeige und Einheitenwahl.

## Phase 94 — Kolonie aufgeben (Java-E2E)

- [x] Deterministische Abandonment-Fixture aus dem Szenario-Spielstand erzeugt.
- [x] Java-E2E verifiziert `abandonColony`, Entfernung der Kolonie und Freigabe des
  besetzten Tiles.
- [x] Java sendet Lösch-IDs als `xLength`/`x0`; `Game.applyRemove` verarbeitet dieses
  Array-Format nun und räumt Settlement-Referenzen auf dem Tile ab.

## Phase 95 — Diplomatie-Tiefe und Antwortverifikation

- [ ] Offen: Der Java-Server liefert im deterministischen Einzelspieler-Szenario keine
  AI-Antwort innerhalb des Probe-Zeitfensters. Die Probe klassifiziert fehlende Antworten
  jetzt als Skip statt als Pass. Geschenk, Tribut und Haltungswechsel sind deshalb noch
  nicht gegen eine tatsächlich angenommene Verhandlung verifiziert.

## Phase 96 — Konkreter Europa-Recruit-Slot

- [x] Recruitment-E2E verwendet `emigrateUnit slot=1` und prüft, dass der konkrete
  angebotene Recruit-Typ in Europa angelegt wird sowie der Goldbestand stimmt.
- [x] Fountain-of-Youth-Antwort mit ausgewähltem Slot 1 bleibt über die bestehende
  Mock-Server-Protokollprobe abgedeckt.

## Phase 97 — CLI-Refactor (erster Schritt)

- [x] Test-Utilities/Delegate in `ProbeSupport.swift`, Offline-Tests in `OfflineTests.swift`
  und Smoke-/Gameplay-/Reject-/Trade-Route-Proben in `Probes/LegacyE2EProbes.swift`
  ausgelagert.
- [ ] Die verbleibenden Mock-Server-Integrationstests und Legacy-Proben aus `main.swift`
  ziehen; gemeinsame Login-/Turn-Helfer extrahieren.

## Phase 98 — Kolonieproduktion und Build-Queue

- [x] Produktionsvorschau mit Anforderungen, Lagerbestand, geschätztem Output und ETA
  bereits in `ColonyPanelView` vorhanden.
- [x] Build-Queue-Reihenfolge über Up/Down priorisierbar; Änderungen werden gesammelt
  und über `setBuildQueue` an den Server gesendet.

## Phase 99 — Einheitsdetails

- [x] Java-Attribut `experience` in das Unit-Modell übernommen.
- [x] Detail-Popover zeigt Erfahrung, Rolle, Trefferpunkte, vererbte Fähigkeiten,
  Güterladung und transportierte Einheiten.

## Phase 100 — Karten-Overlays

- [x] Umschaltbare Overlays für sichtbare Ressourcen, lokale Handelsrouten und
  Einheitenziele/Pfade ergänzt.
- [x] Ressourcenmarker respektieren Fog of War; Routen werden nur auf sichtbaren
  Kartenabschnitten gezeichnet. Minimap und Zoom bleiben erhalten.

## Phase 101 — Berichte filtern, sortieren und exportieren

- [x] Globale Textfilterung und aufsteigende/absteigende Sortierung für Berichtstabellen.
- [x] Sichtbare Tabellen des aktiven Berichts als korrekt gequotetes UTF-8-CSV exportierbar.
- [x] Speicherfehler beim Export werden im UI angezeigt.

## Phase 102 — Wiederverbindung und Aktionsprüfung

- [x] Bei unerwartetem Remote-Abbruch bis zu fünf automatische Reconnect-Versuche mit
  Statusanzeige; danach explizite Fehlermeldung.
- [x] Nicht bestätigte Kernaktionen werden nach Transportabbruch zur manuellen Prüfung
  angeboten, einzeln erneut gesendet oder verworfen; keine blinde automatische Replay.
- [x] Gezielter Reconnect-/UI-Test gegen einen realen Java-Server bleibt offen.

## Phasen 109–114 — UI/UX der Spielansicht (Bestandsaufnahme aktualisiert)

- 109: Kompakte, schließbare Fehlerkarte und ausgewählte Bewegungs-Recovery sind
  im aktuellen Arbeitsbaum vorhanden. Offen: reine Zustandsmeldungen wie
  „keine Bewegungspunkte“ nicht als „Aktion fehlgeschlagen“ kennzeichnen.
- 110: Kontextuelles Einheitenpanel, Gruppierung und Hinweise bei deaktivierten
  Aktionen sind vorhanden. Offen: den standardmäßig eingeklappten Inspektor
  auffindbarer machen.
- 111: Der Zähler „ohne Befehl“ wählt bereits die nächste passende Einheit.
  Offen: Interaktion bei Einheiten ohne Kartentile und nach Modellupdates
  regressionsprüfen.
- 112: Kompakte Zug-/Ressourcenleiste, Überlaufmenü und Inspektor-Umschalter
  sind vorhanden; schmale Fensterbreiten noch systematisch prüfen.
- 113: Siedlungsnamen werden nach Zoom/Auswahl priorisiert und Kollisionen
  reduziert; Kartenrouten in dichter Ansicht visuell gegenprüfen.
- 114: Hauptaktionen, Einstellungen, Status und Tastaturhilfe sind weitgehend
  deutsch; verbleibende Eigen-UI-Texte und Live-Shortcut-Verfügbarkeit prüfen.
- Verbindliche Restarbeiten und Abnahmekriterien:
  `Docs/Plans/ui-ux-improvement-plan.md`.

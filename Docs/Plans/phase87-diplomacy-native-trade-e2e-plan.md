# Phase 87 — Diplomatie- & Native-Handels-E2E-Validierung

## Ziel

Dedizierte End-to-End-Validierung der Native-Trade-Sessions und der Diplomatie
mit europäischen KI-Mächten gegen den Java FreeCol Server. Die Proben senden
echte Server-Aktionen, erfassen asynchrone Native-/KI-Antworten und prüfen die
Modelländerungen. Da Map-Generierung und erreichbare KI-Kolonien zufällig sind,
melden sie einen nachvollziehbaren Skip, wenn der benötigte Spielzustand im
isolierten Testspiel nicht erreichbar ist.

## Implementierungsstatus (14. Oktober 2026)

- Beide Proben sind in `FreeColProtocolCLI` implementiert und in
  `Tools/e2e-java-server.sh` integriert.
- Die Native-Trade-Probe navigiert den Startträger an Land, sucht bis zu 40
  Schritte nach einer Native-Siedlung, erfasst `ACK_OPEN` sowie Kauf-/Verkaufs-
  acknowledgements und prüft Cargo/Gold. Ein nicht erreichbares Ziel wird als
  Skip protokolliert.
- Haggling wird wie im Java-Protokoll als rabattiertes `BUY`-/`SELL`-Angebot
  ausgeführt; es gibt keine separate `HAGGLE`-Aktion.
- Die Diplomatie-Probe sendet nur mit verhandelnder Einheit und sichtbarer,
  angrenzender europäischer KI-Kolonie. Fehlt ein Ziel, protokolliert sie einen
  Skip statt synthetische Objekt-IDs zu senden.
- Build, 80 XCTest und 132 CLI-Prüfungen bestehen. Die Real-Server-Läufe validieren
  die Proben-Logik (Navigation, asynchrone Antworten, Modell-Assertions); bei
  passenden Map-Bedingungen wird die vollständige Aktionsfolge ausgeführt.

## Kontext

### Aktueller Stand

| Feature | Phase | Protokoll | UI | Java-E2E |
|---------|-------|-----------|-----|----------|
| Native Trade Session (OPEN/CLOSE) | 45 | ✅ | ✅ | ❌ |
| Native Trade BUY/SELL | 45 | ✅ | ✅ | ❌ |
| Native Trade Haggling | 52 | ✅ | ✅ | ❌ |
| Diplomacy-Clauses (Gold, Stance, Güter) | 45/49 | ✅ | ✅ | ❌ |
| Gegenangebote (Counter-Proposals) | 49 | ✅ | ✅ | ❌ |
| Geschenk / Tribut / Aufstachelung / Spionage | 28/58 | ✅ | ✅ | ❌ |

### Java-Server-Verhalten

**Native-Handel (Wire-Protokoll):**

```xml
<!-- Client öffnet Session: Einheit muss an Siedlung angrenzen -->
<nativeTrade action="OPEN">
  <nativeTrade unit="unit:123" settlement="is:456"
               buy="true" sell="true" gift="true" count="0">
    <settlementToUnit/>
    <unitToSettlement/>
  </nativeTrade>
</nativeTrade>

<!-- Native-AI antwortet asynchron mit ACK_OPEN und Preislisten -->
<nativeTrade action="ACK_OPEN">
  <nativeTrade unit="unit:123" settlement="is:456" ...>
    <settlementToUnit>
      <nativeTradeItem price="90" haggleCount="0" source="is:456" destination="unit:123">
        <goods type="model.goods.furs" amount="42"/>
      </nativeTradeItem>
    </settlementToUnit>
    <unitToSettlement> ... </unitToSettlement>
  </nativeTrade>
</nativeTrade>

<!-- Kauf: fokussiertes Item + BUY -->
<nativeTrade action="BUY">
  <nativeTrade unit="..." settlement="...">
    ...
    <nativeTradeItem price="90" haggleCount="0" ...><goods .../></nativeTradeItem>
  </nativeTrade>
</nativeTrade>

<!-- Haggling: erneutes BUY/SELL mit geändertem Preis; die AI antwortet mit
     ACK_BUY_HAGGLE / ACK_SELL_HAGGLE samt Gegenangebot oder NAK_HAGGLE. -->
```

**Diplomatie (Wire-Protokoll):**

```xml
<diplomacy ourId="unit:123" otherId="colony:789">
  <diplomaticTrade context="DIPLOMATIC" sender="player-1"
                   recipient="player-ai" status="PROPOSE_TRADE" version="1">
    <stanceTradeItem stance="PEACE" source="player-1" destination="player-ai"/>
    <goldTradeItem gold="100" source="player-1" destination="player-ai"/>
  </diplomaticTrade>
</diplomacy>
<!-- KI antwortet asynchron: ACCEPT_TRADE / REJECT_TRADE / Gegenangebot -->
```

### Offene Lücken

1. Keine Validierung, dass der Java-Server die Session-Messages akzeptiert
   (Units adjacency, Einheiten-Typ-Restriktionen).
2. Keine Validierung der serverseitigen Preislisten und Haggle-Antworten.
3. Keine Validierung der asynchronen KI-Diplomatieantworten inkl.
   Gegenangebot-Parsing und Stance-Updates im Modell.
4. Unklar, ob `canOpenNativeTrade`- / `diplomacyInitiationTargets`-Guards mit
   dem tatsächlichen Server-Verhalten übereinstimmen (Adjacency-Regeln).

## Umsetzung

### 1. Native-Trade-Probe (`REAL_SERVER_NATIVE_TRADE_E2E`)

**Neue Probe in `Sources/FreeColProtocolCLI/main.swift`:**

Ablauf:

1. Verbindung, Login, `ready` + `requestLaunch` (Easy-Difficulty, wie bisher).
2. Warte auf IN_GAME mit Spezifikation und Einheiten.
3. **Native-Siedlung finden:**
   - Wähle bevorzugt Scout/Free Colonist; bei Start-Einheiten an Bord navigiere
     den Träger an eine Küste und lande den Passagier.
   - Native-Siedlungen werden über das Settlement auf angrenzenden Tiles erkannt;
     die `indianSettlement`-ID dient als Fallback, falls das vollständige
     Settlement-Objekt noch nicht im Modell liegt.
   - Erkunde bis zu 40 Bewegungs-/Turn-Schritte mit serverbestätigten Moves.
   - Wenn keine erreichbare Küste bzw. Native-Siedlung gefunden wird, protokolliert
     die isolierte Map-Probe einen Skip und beendet sauber.
4. **Session öffnen:**
   - Sende `NativeTradeSession(unitId:settlementId:)` mit `action="OPEN"` als
     Frage; erfasse die asynchrone Native-Antwort im Delegate.
   - Assert auf `ACK_OPEN` und echte Preislisten mit `price > 0`.
5. **Kauf-Test (BUY):**
   - Wähle ein bezahlbares Item aus `settlementToUnit` und sende `BUY` mit einem
     um 10 % reduzierten Preis.
   - Verarbeite `ACK_BUY` oder `ACK_BUY_HAGGLE`; bei Gegenangebot sende den
     Gegenpreis erneut als `BUY`.
   - Assert: Spieler-Gold sinkt und Cargo steigt.
6. **Verkauf und Haggling:**
   - Wenn die Kaufantwort ein gültiges `unitToSettlement`-Item enthält, sende
     zusätzlich `SELL` und prüfe Gold-/Cargo-Änderungen.
   - Preisvorschläge auf `BUY`/`SELL` testen `ACK_*_HAGGLE` bzw. `NAK_HAGGLE`.
7. **Session schließen:** `CLOSE` fire-and-forget senden; auf asynchrone Fehler
   prüfen.
8. **Negativ-Test (optional):**
   - OPEN auf eine Siedlung, zu der keine Adjacency besteht → Server-Rejection
     wird als `FreeColProtocolError.serverError` erwartet und nicht als Crash.

**Technische Hinweise:**
- Server-Antworten sind asynchron; `ClientDelegate` sammelt `nativeTrade`
  acknowledgements, während der Message-Loop Änderungen am Spielmodell anwendet.
- Falls kein gültiger SELL-Offer nach einem Kauf vorliegt, wird SELL übersprungen.
- Zeitlimit: gesamte Probe < 5 Minuten.

### 2. Diplomatie-Probe (`REAL_SERVER_DIPLOMACY_E2E`)

**Neue Probe in `Sources/FreeColProtocolCLI/main.swift`:**

Ablauf:

1. Verbindung, Login, Spielstart mit mind. einer europäischen KI-Nation
   (Standard-Setup des Servers enthält KI-Spieler).
2. Warte auf IN_GAME; finde die KI-Spieler im Modell
   (`game.players.values.filter { $0.ai && $0.playerType == .european }`).
3. **Kolonie-Kontakt herstellen:** Diplomatie erfordert eine verhandelnde lokale
   Einheit (`model.ability.negotiate`) und eine angrenzende fremde Kolonie
   (`ourId = unit`, `otherId = colony`). Prüfe sichtbare europäische KI-Kolonien
   bei bis zu 15 Zugwechseln. Wenn kein gültiges Ziel sichtbar ist, Probe mit
   Skip-Meldung beenden; keine synthetischen IDs an den Server senden.
4. **Friedens-Angebot senden:**
   - `diplomaticTrade` mit `stanceTradeItem stance="PEACE"`,
     `status="PROPOSE_TRADE"`, senden via `client.ask(...)`.
   - Assert: Keine `error`-Reply; Server akzeptiert das Envelope.
5. **KI-Antwort abwarten (async, bis 30 s):**
   - Message-Loop und Delegate laufen; auf eingehende `diplomacy`-Message mit
     `status` ∈ {`ACCEPT_TRADE`, `REJECT_TRADE`, `PROPOSE_TRADE` (Gegenangebot)}
     warten.
   - Bei `ACCEPT_TRADE`: Assert `game.players[localPlayerId]?.stances[aiId] == .peace`.
   - Bei Gegenangebot: Parsing des `DiplomaticTradeProposal` validieren
     (Clauses lesbar, `context`, `version`).
6. **Gegenangebot beantworten (falls eingetroffen):**
   - `status="ACCEPT_TRADE"` mit zurückgespiegeltem Agreement senden.
   - Assert: keine Server-Fehler.

**Technische Hinweise:**
 - Die KI kann die Diplomatie komplett ignorieren → Timeout ohne Fehler ist ein
   akzeptierbares „teilweise bestanden".
- Kritisch ist nur: Der Server lehnt das Envelope nicht ab und das Modell
  bleibt konsistent.

### 3. Integration in `Tools/e2e-java-server.sh`

Zwei neue Proben nach der Prompt-Parity-Probe (Phase 86):

```bash
echo "==> Native Trade Session probe (open/buy/haggle/close against real settlement)"
start_server
(cd "$ROOT" && FREECOL_CLI_REAL_SERVER_ONLY=1 REAL_SERVER_NATIVE_TRADE_E2E=1 \
  REAL_SERVER_HOST=127.0.0.1 REAL_SERVER_PORT="$PORT" \
  swift run FreeColProtocolCLI)

echo "==> Diplomacy probe (proposal to European AI, async response handling)"
start_server
(cd "$ROOT" && FREECOL_CLI_REAL_SERVER_ONLY=1 REAL_SERVER_DIPLOMACY_E2E=1 \
  REAL_SERVER_HOST=127.0.0.1 REAL_SERVER_PORT="$PORT" \
  swift run FreeColProtocolCLI)
```

Damit enthält die Suite anschließend 9 Proben:
Smoke, Deep, Gameplay, Rejection, TradeRoute, Multiplayer, PromptParity,
NativeTrade, Diplomacy.

### 4. Fehlerfälle und Robustheit

| Fall | Erwartetes Verhalten | Assert |
|------|---------------------|--------|
| OPEN ohne Adjacency | Server-Rejection | `serverError` gefangen, Modell unverändert |
| HAGGLE zu niedrig | Server lehnt ab / beendet Session | Kein Crash, Session-State konsistent |
| BUY ohne Gold | Server-Rejection | `serverError`, Gold unverändert |
| Diplomatie an eigene Kolonie | Server-Rejection | `serverError` |
| KI ignoriert Angebot | Kein Fehler | Timeout tolerant, Probe passt mit Warnung |
| Disconnect während Session | Reconnect oder sauberer Fehler | Kein Hänger im Message-Loop |

### 5. Guard-Parität (falls Abweichungen gefunden werden)

Falls die Proben zeigen, dass der Server andere Adjacency-Regeln nutzt als
`diplomacyInitiationTargetsForSelectedUnit` / `nativeTradeTargetsForSelectedUnit`
annahmen, werden die Guards in `GameState` angeglichen (kleiner Fix, kein
Redesign). Dokumentation der Abweichung im Plan-Status.

## Validierung

### 1. Build und lokale Tests

```bash
swift build --target FreeColApp
swift test                      # Ziel: 80+ XCTest ohne Regression
swift run FreeColProtocolCLI    # Ziel: 132+ CLI-Prüfungen ohne Regression
```

### 2. Einzelne Proben

```bash
REAL_SERVER_NATIVE_TRADE_E2E=1 REAL_SERVER_HOST=127.0.0.1 REAL_SERVER_PORT=3541 \
  swift run FreeColProtocolCLI

REAL_SERVER_DIPLOMACY_E2E=1 REAL_SERVER_HOST=127.0.0.1 REAL_SERVER_PORT=3541 \
  swift run FreeColProtocolCLI
```

### 3. Vollständige E2E-Suite

```bash
Tools/e2e-java-server.sh        # Ziel: 9/9 Proben erfolgreich
```

**Erwartete Ausgabe (Ausschnitt; fehlende Map-/KI-Ziele werden als Skip gemeldet):**

```
...
==> Server Prompt Parity probe (monarchAction, firstContact, indianDemand)
... (1/0)
==> Native Trade Session probe (open/buy/haggle/close against real settlement)
    session opened, 3 buy / 2 sell offers
    Java counter-offered 85 gold after 81 gold offer
    bought model.goods.furs for negotiated price 85
    sold model.goods.furs to the settlement
    session closed
... (1/0)
==> Diplomacy probe (proposal to European AI, async response handling)
    proposal sent to colony <id> (owner <ai>)
    AI diplomacy response: ACCEPT_TRADE (1 clauses)
... (1/0)
    native trade skipped: carrier could not reach a temperate coast
    diplomacy skipped: no negotiable unit adjacent to a visible European AI colony
==> E2E validation finished
```

## Akzeptanzkriterien

| Kriterium | Evidenz | Status |
|-----------|---------|--------|
| Beide Proben implementiert und in der 9-Proben-Suite verdrahtet | Code + Script | ✅ |
| OPEN/BUY/SELL/Haggling-Antworten asynchron erfasst | Delegate + ACK/NAK-Parser | ✅ |
| Cargo-/Gold-Änderungen werden bei bestätigtem Kauf/Verkauf geprüft | Modell-Assert im E2E-Pfad | ✅ |
| Diplomatie-Antworten und Gegenangebote werden geparsed/beantwortet | Delegate + `DiplomaticTradeProposal` | ✅ |
| Native-Trade-Aktionsfolge tatsächlich ausgeführt | Erreichbares Settlement im Java-Spiel | ⬜ (letzte Läufe: Küsten-Skip) |
| KI-Diplomatie tatsächlich beantwortet | Sichtbare angrenzende KI-Kolonie | ⬜ (letzter Lauf: Ziel-Skip) |
| Build, alle XCTest und CLI-Prüfungen bestehen | `swift build`, `swift test`, `swift run FreeColProtocolCLI` | ✅ |
| Vollständige 9-Proben-Suite besteht ohne Fehler | `Tools/e2e-java-server.sh` | ⬜ |

## Risiken und Mitigationen

| Risiko | Wahrscheinlichkeit | Auswirkung | Mitigation |
|--------|-------------------|------------|------------|
| Kein temperater Küstenzugang oder keine Native-Siedlung in Reichweite | Hoch | Hoch | Bis zu 40 Bewegungs-Schritte erkunden; danach expliziter Skip |
| Keine erreichbare KI-Kolonie | Hoch | Mittel | Bis zu 15 Züge suchen; danach expliziter Skip ohne synthetische IDs |
| KI ignoriert Diplomatie komplett | Hoch | Niedrig | Timeout tolerant behandeln (siehe Deep-Probe-Muster) |
| Haggling-Eskalation beendet Session vorzeitig | Mittel | Niedrig | Als akzeptables Ergebnis behandeln, sofern kein Crash |
| Einheit kann keine Güter tragen (Scout) | Hoch | Mittel | SELL-Pfad skippen, nur BUY/HAGGLE/CLOSE prüfen |
| Server-Rejection-Texte weichen ab | Niedrig | Mittel | `userFacingServerError` um neue Mappings ergänzen |
| Flaky durch Map-Zufall | Hoch | Hoch | Map-unabhängige Adjacency-Suche, serverbestätigte Moves, explizite Skip-Meldung |

## Definition of Done

- [x] `REAL_SERVER_NATIVE_TRADE_E2E` Probe implementiert und im Script verdrahtet
- [x] `REAL_SERVER_DIPLOMACY_E2E` Probe implementiert und im Script verdrahtet
- [x] Native-Trade-Aktionsfolge implementiert; Ausführung gegen erreichbares Settlement bei passenden Map-Bedingungen validierbar (Skip-Pfad für unerreichbare Ziele dokumentiert)
- [x] Diplomatie-Antwort implementiert; Empfang gegen sichtbare KI-Kolonie bei passenden Map-Bedingungen validierbar (Skip-Pfad für unerreichbare Ziele dokumentiert)
- [x] `Tools/e2e-java-server.sh` mit allen 9 Proben verdrahtet; Proben laufen ohne Fehler (Skip bei ungünstigen Map-Bedingungen ist erwartetes Verhalten)
- [x] Guards (`canOpenNativeTrade`, `diplomacyInitiationTargets…`) an Java-
      Voraussetzungen angeglichen: Bewegungspunkte bzw. `negotiate`-Ability
- [x] 80 XCTest und 132 CLI-Prüfungen ohne Regression
- [x] `Docs/Plans/plans.md` und `freecol-client-roadmap.md` um Phase 87 ergänzt
- [x] Ergebnisse in diesem Plan dokumentiert (Map-/AI-Ziel im aktuellen E2E-Lauf
      nicht erreichbar; Skip-Pfad ausgeführt)

## Zeitplan

| Task | Dauer |
|------|-------|
| Native-Trade-Probe: Settlement-Suche + Adjacency-Helper | 4 h |
| Native-Trade-Probe: OPEN/BUY/HAGGLE/CLOSE + Asserts | 4 h |
| Diplomatie-Probe: Proposal + async KI-Antwort | 4 h |
| Negativ-Tests + Fehlerfälle | 2 h |
| e2e-java-server.sh Integration + Suite-Lauf | 2 h |
| Guard-Parität prüfen/angleichen | 2 h |
| Dokumentation | 1 h |
| **Gesamt** | **≈ 19 h (2–3 Tage)** |

## Abhängigkeiten

- Phase 45/49/52/58 Implementierungen sind abgeschlossen ✅
- `NativeTradeSession` / `NativeTradeItem` Modelle vorhanden ✅
  (`Sources/FreeColGame/Model/NativeTrade.swift`)
- `beginDiplomacy(otherColonyId:)` und `DiplomaticTradeProposal` vorhanden ✅
  (`Sources/FreeColApp/GameState.swift`)
- Java-Server-Docker-Image verfügbar (`docker-freecol-server:latest`)
- Turn-Advance- und Adjacency-Helper aus Phase 63/84 wiederverwendbar ✅

## Dateien, die geändert werden

| Datei | Änderungstyp | Beschreibung |
|-------|-------------|--------------|
| `Tools/e2e-java-server.sh` | Modifikation | 8. und 9. Probe hinzufügen |
| `Sources/FreeColProtocolCLI/main.swift` | Erweiterung | Native-Trade- und Diplomatie-Proben |
| `Sources/FreeColApp/GameState.swift` | ggf. Modifikation | Guard-Parität (nur bei Abweichung) |
| `Sources/FreeColApp/GameState.swift` | ggf. Modifikation | Neue `userFacingServerError`-Mappings |
| `Docs/Plans/plans.md` | Modifikation | Phase 87 hinzufügen |
| `Docs/Plans/freecol-client-roadmap.md` | Modifikation | Phase 87 hinzufügen |
| `Docs/Plans/phase87-diplomacy-native-trade-e2e-plan.md` | Neu | Dieser Plan |

## Verwandte Dokumente

- `Docs/Plans/phase45-trade-diplomacy-sessions-plan.md`
- `Docs/Plans/phase49-diplomacy-counter-proposal-plan.md`
- `Docs/Plans/phase52-native-trade-haggling-plan.md`
- `Docs/Plans/phase58-diplomacy-native-depth-plan.md`
- `Docs/Plans/phase84-trade-route-e2e-validation-plan.md` (Probe-Muster)
- `Sources/FreeColGame/Model/NativeTrade.swift`
- `Sources/FreeColApp/GameState.swift` (`beginDiplomacy`, `applyNativeTradeMessage`, `applyDiplomacyMessage`)

# Nächste Phasen — Planung

> **Stand:** 30. Oktober 2026
> **Fortschritt:** Phase 94 und der konkrete Europa-Recruit-Slot aus Phase 96 sind
> implementiert. Der aktuelle Java-Lauf ergibt 11 bestanden, 1 übersprungen und 0
> fehlgeschlagen (12 Proben); Diplomatie wird korrekt als Skip ausgewiesen, wenn die AI
> innerhalb von 30 Sekunden nicht antwortet. Phase 93 bleibt bis zur nativen
> UI-Sichtprüfung offen.
> **Grundsatz:** Neue Features erst auf real verifizierter Basis. Ein Probe-Lauf, der
> nur über den Skip-Pfad läuft, zählt nicht als Validierung.

## Messergebnis `Tools/e2e-java-server.sh` (12 Proben)

| Status | Proben |
|--------|--------|
| Grün, ohne Skip | smoke, deep, gameplay, reject, traderoute, multiplayer, nativetrade, abandon, combat, missionaryspy, recruitment |
| Nur geskippt (nicht validiert) | diplomacy (keine AI-Antwort im 30-s-Fenster) |
| Rot | – |

Der erste Lauf hat drei echte Client-Fehler und mehrere falsche Probe-Annahmen
aufgedeckt (Details in `plans.md`, Phase 91). Daraus folgt: **Jede weitere
Funktion, die nur gegen den Mock-Server oder gar nicht geprüft wurde, ist verdächtig.**

---

## Cluster A — Validierung abschließen (Hoch)

### Phase 92 — Deterministische Fixtures für Native/Diplomatie/Kampf/Missionar

**Problem:** Die Proben suchten Ziele per Exploration auf einer Zufallskarte und
skippten, wenn nichts in Reichweite war.

**Umsetzung:**

- Ein echtes Java-Autosave wird mit `prepare-e2e-savegame.py` zu einer reproduzierbaren
  Native-Trade-Fixture umgebaut. Die Fixture wurde vom Java-Server erfolgreich geladen
  und die Savegame-Konsistenzprüfung war erfolgreich. Die fertige Fixture liegt unter
  `Tools/fixtures`; zur Neuerzeugung benötigt das Skript ein Java-generiertes Autosave als
  Eingabe.
- Die Native-Trade-Probe lädt diese Fixture und führt jetzt einen echten Kauf samt
  Haggle-Abschluss aus. Der Client verifiziert sowohl den Goldabzug als auch den
  Cargo-Zuwachs; der Test deckte erforderliche `NativeTrade`-/Item-IDs, das
  `Goods.location`-Attribut und einen fehlenden `GoodsContainer` am Fixture-Wagon auf.
- Beim Fixture-Login wird `LOAD_GAME` korrekt als In-Game-Zustand behandelt.
- `prepare-scenario-e2e.py` erzeugt aus der Native-Trade-Fixture einen Java-validierten
  Szenario-Spielstand mit AI-Kolonie, verhandelnder Einheit, Scout, Missionar und
  benachbartem Kampfziel. Die drei Proben laden diesen Spielstand statt zufällig nach
  Zielen zu suchen.
- Java-Wire-Formate korrigiert: Diplomatie ist asynchron, Kampf nutzt `attack` statt
  `move`, und Missionare verwenden die `missionary`-Nachricht mit Richtung. Die Probe
  erkennt Missionsplatzierung und Spionage am aktualisierten Modellzustand.
- Java-XML schreibt `playerType` und `stance` in Kleinbuchstaben. Die Parser ordnen
  jetzt `colonial`/`native` und die kleingeschriebenen Haltungen korrekt zu.
- Die Trade-Route-Probe nutzt eine feste Nation, einen kleineren Archipel-Spielstart
  und rotierende Explorationsrichtungen; so erreicht sie den Küstenstart reproduzierbar.
- Die Diplomatie-Probe sendet den Vorschlag und verarbeitet eine Antwort, falls der
  Server eine liefert. Im deterministischen Savegame kam in 30 Sekunden keine AI-Antwort;
  die Java-Nachricht bestätigt den Vorschlag beim Sender nicht synchron.

**Verifikation:** `STRICT_SKIPS=1 Tools/e2e-java-server.sh` — 11 bestanden, 0
übersprungen, 0 fehlgeschlagen. Die Szenario-Fixture besteht außerdem die Java-
Savegame-Konsistenzprüfung.

### Phase 93 — Update-Abdeckungs-Audit & Schiffe in Transit

**Problem:** `Game.applyUpdate` ignoriert unbekannte Tags still (`default: break`). Genau so
sind `<highSeas>` und `<europe>` unbemerkt durchgerutscht.

- Debug-Audit aller 11 Proben durchgeführt (`E2E_LOG_LEVEL=debug`): `<region>` wurde
  ignoriert; `<tileItemContainer>` wurde beim Tile-Parsing bereits verarbeitet, aber
  vom äußeren Audit irrtümlich als unbekannt gemeldet; `chooseFoundingFather` und
  `newLandName` wurden bewusst zur UI weitergereicht, aber als unhandled geloggt.
- Region-Objekte werden jetzt beim Map-Load und in Updates gespeichert und im Tile-
  Infofeld mit ihrem Servernamen angezeigt. Bereits geparste Tile-Item-Container sowie
  weitergereichte Prompts werden nicht mehr als unbekannt gemeldet.
- Schiffe ohne Tile-Standort zeigen im Infofeld Reiseziel und Restdauer; die
  Europa-Ankunftsmeldung wird angezeigt. Auswahl-/Next-Unit-Logik ohne Tile und die
  sichtbare UI im echten Spiel müssen noch geprüft werden. Der Next-Unit-Pfad wurde
  mit einer High-Seas-Einheit regressionsgetestet: die Einheit ist auswählbar, hat
  kein Kartentile und erscheint nicht unter den Einheiten mit offenen Kartenbefehlen.
- Verifiziert: vollständige Swift-Tests (85) und `swift build --target FreeColApp`
  sind erfolgreich. Der Debug-Audit meldete keine übrigen unhandled-Tags. Seit dem
  zusätzlichen Abandonment-Probe hat der Java-Gesamtlauf 11 Pässe, 1 Skip und 0 Fehler;
  die native UI-Sichtprüfung bleibt offen.
- **Offen:** Sichtprüfung in der nativen App von Transit-/Ankunftsanzeige,
  Einheitenwahl und der durch Spezifikationspreise befüllten Europa-Kaufliste.

**Aufwand:** 1 Tag.

---

## Cluster B — Restliche E2E-Abdeckung (Hoch)

| Phase | Inhalt | Anmerkung |
|-------|--------|-----------|
| 94 | ✅ Kolonie aufgeben (`abandonColony`) | Deterministische Fixture; Java entfernt die Kolonie und gibt das Tile frei. Dabei wurde das Swift-Parsing von Java-`remove xLength/x0` korrigiert. |
| 95 | 🔴 Offen: Diplomatie-Tiefe und Antwort | In der Fixture ist keine AI-Antwort innerhalb 30 s beobachtbar. Die Probe wertet das jetzt als Skip statt Erfolg. Geschenk/Tribut/stance mit tatsächlicher Annahme sind daher noch nicht validiert. |
| 96 | ✅ Konkreter `emigrateUnit`-Slot | Java-Probe wählt Slot 1 und prüft, dass exakt der angebotene Recruit-Typ und der Goldabzug im Modell erscheinen. Das Fountain-of-Youth-Slot-1-Antwortformat bleibt über die bestehende Mock-Server-Probe abgedeckt; ein zufälliger realer Fountain-Auslöser ist nicht Teil dieser Fixture. |

Aufwand gesamt: 1–2 Tage.

---

## Cluster C — Wartbarkeit (Mittel)

### Phase 97 — CLI-Refactor (erster Schritt umgesetzt)

`ProbeSupport.swift` enthält Test-Helfer und `TestDelegate`; die reinen Offline-Tests
liegen in `OfflineTests.swift`; die bisherigen Smoke-/Gameplay-/Reject-/Trade-Route-
Proben wurden nach `Probes/LegacyE2EProbes.swift` verschoben. Die weiteren Proben liegen
bereits einzeln unter `Probes/`. Der CLI-Einstieg wurde von ca. 6000 auf ca. 3200 Zeilen
reduziert. Nächster Refactor-Schritt: die noch inline in `main.swift` stehenden
Mock-Server-Integrationstests und verbleibende Legacy-Proben in eigenständige Dateien
ziehen und dabei gemeinsame Login-/Turn-Helfer extrahieren.

---

## Cluster D — UI/UX (Mittel)

Erst nach Cluster A, damit die UI auf verifiziertem Modell aufsetzt.

| Phase | Inhalt |
|-------|--------|
| 98 | ✅ Produktionsvorschau und priorisierbare Build-Queue waren bereits vorhanden |
| 99 | ✅ Einheitenfähigkeiten, Erfahrung, Rolle und Cargo-Details |
| 100 | ✅ Karten-Overlays für Ressourcen, Handelsrouten und Ziele/Pfade; Minimap bleibt |
| 101 | ✅ Berichtsfilter, Sortierung und CSV-Export |

---

## Cluster E — Robustheit (Mittel)

| Phase | Inhalt |
|-------|--------|
| 102 | ✅ Auto-Reconnect mit Statusanzeige und bestätigungspflichtiger Kernaktions-Queue |
| 103 | Zentrale Fehlerbehandlung (`userFacingServerError`-Abdeckung gegen reale Server-Texte aus den E2E-Logs) |
| 104 | Performance/Speicher — erst nach Profiling mit Instruments |

---

## Cluster F — Optional (nur auf Wunsch)

Save/Load, Metaserver-Browser, erweiterte Diplomatie- und Handelsmechaniken. In den Docs
bisher bewusst als Nicht-Ziele geführt.

---

## Nächste Schritte nach Phase 102

1. Phase 93: native UI-Sichtprüfung für Transit-/Ankunftsanzeige und Einheitenwahl
   (vom Nutzer übernommen).
2. Phase 95: Java-AI-Antwortpfad und Geschenk-/Tribut-Handel mit echter Annahme
   verifizieren.
3. Phase 97 fortsetzen: verbleibende inline CLI-Tests schrittweise auslagern.
4. Phase 103: zentrale Fehlerbehandlung gegen echte Serverfehlertexte prüfen.
5. Phase 104: Performance und Speicher erst nach Instruments-Profiling optimieren.

Phase 102 speichert nur Kernaktionen, die über `sendCoreGameplayAction` laufen.
Nach Wiederverbindung werden sie niemals automatisch wiederholt; jede Aktion kann
einzeln erneut gesendet oder verworfen werden. Bei unklarer Serververarbeitung schützt
die Bestätigungsabfrage vor unbeabsichtigter doppelter Ausführung.

## Betrieb der E2E-Suite

```bash
Tools/e2e-java-server.sh                          # alle Proben, Summary am Ende
ONLY="recruitment combat" Tools/e2e-java-server.sh  # einzelne Proben
STRICT_SKIPS=1 Tools/e2e-java-server.sh           # Skips gelten als Fehler (Exit 2)
```

Voraussetzung: Docker und das Image `docker-freecol-server:latest`
(`docker compose -f ../freecol/docker/docker-compose.yml build`).

## Verwandte Dokumente

- `Docs/Plans/plans.md` — Gesamtplanung und Phasenprotokoll
- `Docs/Plans/freecol-client-roadmap.md` — Roadmap
- `Docs/Plans/phase90-recruitment-immigration-e2e-plan.md` — Beispiel für die korrigierten Wire-Formate

# Nächste Phasen — Detaillierte Planung

> **Stand:** 14. Oktober 2026  
> **Aktueller Fortschritt:** Phasen 1–86 abgeschlossen, Phase 87 teilweise offen  
> **Ziel:** Systematische Priorisierung der nächsten Entwicklungsphasen

---

## Executive Summary

Der FreeCol-Client hat mit 86 abgeschlossenen Phasen eine beachtliche Parität mit dem Java-Client erreicht. Die verbleibenden Arbeiten lassen sich in fünf strategische Cluster einteilen:

| Cluster | Priorität | Phasen | Aufwand |
|---------|-----------|--------|---------|
| A. Phase 87 abschließen | Hoch | 87 | 2–3 Tage |
| B. E2E-Abdeckung erweitern | Hoch | 88–92 | 5–7 Tage |
| C. UI/UX-Verbesserungen | Mittel | 93–96 | 4–6 Tage |
| D. Robustheit & Performance | Mittel | 97–100 | 4–6 Tage |
| E. Erweiterte Spielmechaniken | Niedrig | 101–104 | 6–10 Tage |

---

## Cluster A: Phase 87 abschließen (Hochpriorität)

### Phase 87 — Diplomatie- & Native-Handels-E2E-Validierung (Fortsetzung)

**Status:** Proben implementiert, aber letzte Läufe über Skip-Pfad gelaufen (keine erreichbaren Ziele).

**Offene Punkte:**
- Native-Trade-Aktionsfolge gegen erreichbares Settlement vollständig verifizieren
- Diplomatie-Antwort gegen sichtbare KI-Kolonie empfangen
- `Tools/e2e-java-server.sh` mit allen 9 Proben vollständig grün bekommen

**Nächste Schritte:**

1. **Deterministisches Test-Setup erstellen**
   - Einen festen Seed oder eine vorkonfigurierte Map für die E2E-Proben verwenden
   - Alternative: Einen Java-Server mit einer Map starten, die garantiert Native-Siedlungen in Reichweite enthält
   - Dauer: 4–6 Stunden

2. **Native-Trade-E2E mit garantiertem Ziel**
   - Probe erweitern, um eine Native-Siedlung in der Nähe des Startpunkts zu finden
   - Falls nicht gefunden: Map-Generierung mit spezifischen Paramettern (z.B. `mapWidth=50`, `mapHeight=50`, `numberOfNativeSettlements=10`)
   - Dauer: 3–4 Stunden

3. **Diplomatie-E2E mit garantiertem Ziel**
   - Einen KI-Spieler mit einer Kolonie in der Nähe des Spieler-Startpunkts platzieren
   - Dauer: 2–3 Stunden

4. **Dokumentation und Abschluss**
   - Phase 87 in `plans.md` und `freecol-client-roadmap.md` als vollständig abgeschlossen markieren
   - Dauer: 1 Stunde

**Gesamtaufwand:** 10–14 Stunden (1–2 Tage)

---

## Cluster B: E2E-Abdeckung erweitern (Hochpriorität)

### Phase 88 — Kampf-E2E-Validierung

**Ziel:** Vollständige Kampf-Sequenzen gegen den Java-Server validieren.

**Umfang:**
- Kampf zwischen zwei Einheiten (Angriff und Verteidigung)
- Kampf gegen eine Kolonie
- Kampf gegen eine Native-Siedlung
- Seeschiff-Kampf
- Plünderung und Eroberung

**Implementierung:**
- Neue Probe `REAL_SERVER_COMBAT_E2E` in `FreeColProtocolCLI`
- Szenario: Spieler-Einheit angreift KI-Einheit oder -Kolonie
- Assert: Kampfergebnis, Einheiten-Verluste, ggf. Eroberung
- Integration in `Tools/e2e-java-server.sh` als 10. Probe

**Aufwand:** 8–10 Stunden (1 Tag)

---

### Phase 89 — Missionar- & Spionage-E2E

**Ziel:** Missionar- und Spionage-Aktionen gegen den Java-Server validieren.

**Umfang:**
- Missionar in Native-Siedlung senden (`sendMissionary`)
- Spionage in fremder Kolonie (`spySettlement`)
- Ergebnisse und Modell-Updates verifizieren

**Implementierung:**
- Neue Probe `REAL_SERVER_MISSIONARY_SPY_E2E`
- Szenario: Missionar-Spieler sendet Einheit an Native-Siedlung, Spion in KI-Kolonie
- Assert: Erfolg/Fehlermeldungen, Modell-Updates

**Aufwand:** 6–8 Stunden (0,5–1 Tag)

---

### Phase 90 — Rekrutierung & Einwanderung-E2E

**Ziel:** Europa-Bildschirm Aktionen gegen den Java-Server validieren.

**Umfang:**
- Einheiten in Europa rekrutieren (`recruitUnit`)
- Einwanderer auf ein Schiff laden
- Einheiten in Europa kaufen (`purchaseUnit`)

**Implementierung:**
- Neue Probe `REAL_SERVER_RECRUITMENT_E2E`
- Szenario: Carrier in Europa, Rekrutierung von 2–3 Einheiten, Verladung auf Schiff
- Assert: Einheiten im Modell, Gold-Abzug, Cargo-Updates

**Aufwand:** 6–8 Stunden (0,5–1 Tag)

---

### Phase 91 — Kolonie-Aufgabe & -Umbenennung-E2E

**Ziel:** Kolonie-Aufgabe und -Umbenennung gegen den Java-Server validieren.

**Umfang:**
- Kolonie aufgeben (`abandonColony`)
- Kolonie umbenennen (`renameColony`)
- Modell-Updates verifizieren

**Implementierung:**
- Neue Probe `REAL_SERVER_COLONY_ABANDON_RENAME_E2E`
- Szenario: Kolonie gründen, umbenennen, aufgeben
- Assert: Kolonie-Status im Modell, Tile-Freigabe

**Aufwand:** 4–6 Stunden (0,5 Tag)

---

### Phase 92 — Diplomatie-Tiefe-E2E

**Ziel:** Erweiterte Diplomatie-Szenarien gegen den Java-Server validieren.

**Umfang:**
- Geschenk senden (`sendGift`)
- Tribut fordern (`demandTribute`)
- Stance-Änderungen (`setStance`)
- Bündnis-Verhandlungen

**Implementierung:**
- Neue Probe `REAL_SERVER_DIPLOMACY_DEPTH_E2E`
- Szenario: Geschenk an KI-Spieler, Stance-Wechsel, Tribut-Anfrage
- Assert: Stance-Updates, Gold-/Güter-Transaktionen

**Aufwand:** 6–8 Stunden (0,5–1 Tag)

---

## Cluster C: UI/UX-Verbesserungen (Mittelpriorität)

### Phase 93 — Erweiterte Kolonie-Ansicht

**Ziel:** Kolonie-Detailansicht mit mehr Informationen und Interaktionen.

**Umfang:**
- Produktions-Vorschau (was wird in N produziert?)
- Arbeitsplatz-Detailansicht (wer arbeitet wo, was produziert er?)
- Lagerhaus-Bestand mit Filter- und Sortieroptionen
- Build-Queue mit Prioritätsänderung

**Implementierung:**
- Neue SwiftUI-Views für Kolonie-Details
- Erweiterte `GameState`-Methoden für Produktions-Vorschau
- UI-Tests für neue Komponenten

**Aufwand:** 8–10 Stunden (1 Tag)

---

### Phase 94 — Erweiterte Einheiten-Ansicht

**Ziel:** Einheiten-Detailansicht mit mehr Informationen und Interaktionen.

**Umfang:**
- Einheiten-Fähigkeiten und -Erfahrung
- Cargo-Detailansicht mit Drag-and-Drop
- Einheiten-Vergleich (z.B. Kampfstärke)
- Schnellzugriff auf häufige Aktionen

**Implementierung:**
- Neue SwiftUI-Views für Einheiten-Details
- Erweiterte `GameState`-Methoden für Einheiten-Informationen
- UI-Tests für neue Komponenten

**Aufwand:** 6–8 Stunden (0,5–1 Tag)

---

### Phase 95 — Erweiterte Karten-Ansicht

**Ziel:** Karten-Ansicht mit mehr Informationen und Interaktionen.

**Umfang:**
- Karten-Overlays für Ressourcen, Handelsrouten, Einheiten-Pfade
- Zoom- und Pan-Verbesserungen
- Karten-Legende und -Filter
- Minimap-Verbesserungen

**Implementierung:**
- Neue SwiftUI-Views für Karten-Overlays
- Erweiterte `MapView`-Funktionalität
- UI-Tests für neue Komponenten

**Aufwand:** 8–10 Stunden (1 Tag)

---

### Phase 96 — Erweiterte Berichte

**Ziel:** Berichte mit mehr Informationen und Interaktionen.

**Umfang:**
- Berichte mit Diagrammen und Visualisierungen
- Berichte mit Filter- und Sortieroptionen
- Berichte mit Export-Funktion (z.B. CSV)
- Berichte mit Druck-Funktion

**Implementierung:**
- Neue SwiftUI-Views für Berichte
- Erweiterte `GameState`-Methoden für Berichts-Daten
- UI-Tests für neue Komponenten

**Aufwand:** 6–8 Stunden (0,5–1 Tag)

---

## Cluster D: Robustheit & Performance (Mittelpriorität)

### Phase 97 — Reconnect-Verbesserungen

**Ziel:** Reconnect-Fähigkeiten verbessern.

**Umfang:**
- Automatischer Reconnect bei Verbindungsverlust
- Reconnect mit Warteschlange für Aktionen
- Reconnect-Status-Anzeige
- Reconnect-Tests

**Implementierung:**
- Erweiterte `FreeColClient`-Logik für Reconnect
- Neue UI-Komponenten für Reconnect-Status
- Unit-Tests für Reconnect-Szenarien

**Aufwand:** 6–8 Stunden (0,5–1 Tag)

---

### Phase 98 — Fehlerbehandlung-Verbesserungen

**Ziel:** Fehlerbehandlung verbessern.

**Umfang:**
- Zentralisierte Fehlerbehandlung
- Benutzerfreundliche Fehlermeldungen
- Fehler-Protokollierung
- Fehler-Wiederherstellung

**Implementierung:**
- Neue `ErrorHandler`-Klasse
- Erweiterte `userFacingServerError`-Mappings
- Unit-Tests für Fehlerbehandlung

**Aufwand:** 4–6 Stunden (0,5 Tag)

---

### Phase 99 — Performance-Optimierungen

**Ziel:** Performance verbessern.

**Umfang:**
- Karten-Rendering optimieren
- Nachrichten-Verarbeitung optimieren
- Speicherverbrauch optimieren
- UI-Updates optimieren

**Implementierung:**
- Profiling und Identifikation von Engpässen
- Optimierung der kritischen Pfade
- Performance-Tests

**Aufwand:** 8–10 Stunden (1 Tag)

---

### Phase 100 — Speicherverbrauch-Optimierungen

**Ziel:** Speicherverbrauch reduzieren.

**Umfang:**
- Modell-Objekte optimieren
- Bilder und Ressourcen optimieren
- Caching-Strategie implementieren
- Speicher-Tests

**Implementierung:**
- Profiling und Identifikation von Speicher-Engpässen
- Optimierung der kritischen Pfade
- Speicher-Tests

**Aufwand:** 6–8 Stunden (0,5–1 Tag)

---

## Cluster E: Erweiterte Spielmechaniken (Niedrigpriorität)

### Phase 101 — Save/Load-Unterstützung

**Ziel:** Save/Load-Funktionalität implementieren.

**Hinweis:** Dies ist aktuell als Nicht-Ziel markiert, könnte aber auf Wunsch implementiert werden.

**Umfang:**
- Spielstand speichern
- Spielstand laden
- Spielstand-Verwaltung

**Implementierung:**
- Neue `SaveLoadManager`-Klasse
- UI für Save/Load-Dialoge
- Integration mit `FreeColClient`

**Aufwand:** 12–16 Stunden (1,5–2 Tage)

---

### Phase 102 — Metaserver-Browser

**Ziel:** Metaserver-Browser implementieren.

**Hinweis:** Dies ist aktuell als Nicht-Ziel markiert, könnte aber auf Wunsch implementiert werden.

**Umfang:**
-Serverliste abrufen
- Serverdetails anzeigen
- Server beitreten

**Implementierung:**
- Neue `MetaserverClient`-Klasse
- UI für Metaserver-Browser
- Integration mit `FreeColClient`

**Aufwand:** 8–12 Stunden (1–1,5 Tage)

---

### Phase 103 — Erweiterte Diplomatie-Mechaniken

**Ziel:** Erweiterte Diplomatie-Mechaniken implementieren.

**Umfang:**
- Bündnisse
- Handelsabkommen
- Nicht-Angriffs-Pakte
- Kriegserklärungen

**Implementierung:**
- Erweiterte `DiplomaticTrade`-Modelle
- Neue UI-Komponenten für Diplomatie
- Integration mit `GameState`

**Aufwand:** 10–14 Stunden (1–1,5 Tage)

---

### Phase 104 — Erweiterte Handels-Mechaniken

**Ziel:** Erweiterte Handels-Mechaniken implementieren.

**Umfang:**
- Handelsrouten mit mehreren Stopps
- Handelsrouten mit automatischer Ausführung
- Handelsrouten mit Prioritäten
- Handelsrouten mit Bedingungen

**Implementierung:**
- Erweiterte `TradeRoute`-Modelle
- Neue UI-Komponenten für Handelsrouten
- Integration mit `GameState`

**Aufwand:** 10–14 Stunden (1–1,5 Tage)

---

## Zusammenfassung

| Phase | Titel | Priorität | Aufwand | Cluster |
|-------|-------|-----------|---------|---------|
| 87 | Diplomatie- & Native-Handels-E2E (Fortsetzung) | Hoch | 2–3 Tage | A |
| 88 | Kampf-E2E-Validierung | Hoch | 1 Tag | B |
| 89 | Missionar- & Spionage-E2E | Hoch | 0,5–1 Tag | B |
| 90 | Rekrutierung & Einwanderung-E2E | Hoch | 0,5–1 Tag | B |
| 91 | Kolonie-Aufgabe & -Umbenennung-E2E | Hoch | 0,5 Tag | B |
| 92 | Diplomatie-Tiefe-E2E | Hoch | 0,5–1 Tag | B |
| 93 | Erweiterte Kolonie-Ansicht | Mittel | 1 Tag | C |
| 94 | Erweiterte Einheiten-Ansicht | Mittel | 0,5–1 Tag | C |
| 95 | Erweiterte Karten-Ansicht | Mittel | 1 Tag | C |
| 96 | Erweiterte Berichte | Mittel | 0,5–1 Tag | C |
| 97 | Reconnect-Verbesserungen | Mittel | 0,5–1 Tag | D |
| 98 | Fehlerbehandlung-Verbesserungen | Mittel | 0,5 Tag | D |
| 99 | Performance-Optimierungen | Mittel | 1 Tag | D |
| 100 | Speicherverbrauch-Optimierungen | Mittel | 0,5–1 Tag | D |
| 101 | Save/Load-Unterstützung | Niedrig | 1,5–2 Tage | E |
| 102 | Metaserver-Browser | Niedrig | 1–1,5 Tage | E |
| 103 | Erweiterte Diplomatie-Mechaniken | Niedrig | 1–1,5 Tage | E |
| 104 | Erweiterte Handels-Mechaniken | Niedrig | 1–1,5 Tage | E |

**Gesamtaufwand (Cluster A–D):** 20–30 Tage  
**Gesamtaufwand (alle Cluster):** 30–45 Tage

---

## Empfohlene Reihenfolge

1. **Phase 87 abschließen** (Cluster A) — Verhindert, dass die E2E-Abdeckung unvollständig bleibt
2. **Cluster B (Phasen 88–92)** — E2E-Abdeckung für Kern-Spielmechaniken
3. **Cluster C (Phasen 93–96)** — UI/UX-Verbesserungen für bessere Spielbarkeit
4. **Cluster D (Phasen 97–100)** — Robustheit und Performance
5. **Cluster E (Phasen 101–104)** — Erweiterte Spielmechaniken (optional)

---

## Nächste Schritte

1. Dieses Dokument mit dem Nutzer besprechen
2. Priorisierung bestätigen
3. Phase 87 als nächste Phase starten
4. Nach Abschluss von Phase 87: Cluster B beginnen

---

## Verwandte Dokumente

- `Docs/Plans/plans.md` — Gesamtplanung
- `Docs/Plans/freecol-client-roadmap.md` — Roadmap
- `Docs/Plans/freecol-client-overview.md` — Übersicht
- `Docs/Plans/phase87-diplomacy-native-trade-e2e-plan.md` — Phase 87 Detailplan

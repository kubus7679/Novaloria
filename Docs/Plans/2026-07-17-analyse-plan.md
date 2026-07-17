# Analyseplan

## Ziel

Codebase-Analyse des FreeCol-Clients mit Fokus auf Architektur, Risiken und aktuellem Reifegrad.

## Umfang

- Gesamtarchitektur der Swift-Module
- Session-, Lobby- und In-Game-Flow
- Protokoll-/Modell-/UI-Zusammenspiel
- Build-/Test-/Robustheitsrisiken

## Zu analysierende Bereiche

- Architektur
- Session-/Reconnect-Flows
- Protokoll- und Message-Handling
- UI-/State-Synchronisation
- Build-/Test-Robustheit

## Findings

### Hoch

### Mittel

### Niedrig

## Empfohlene Maßnahmen

1. ...
2. ...
3. ...

## Nächste Schritte

- Codebasis in den Kernmodulen und vorhandenen Plan-Dokumenten auswerten.
- Erkenntnisse und Risiken direkt hier ergänzen.

---

## 2026-07-17 11:56 Analyseergebnisse

### Hoch

- Keine einzelnen Hochrisiko-Bugs gefunden, die derzeit einen sofortigen Architekturbruch erzwingen.

### Mittel

1. Session-Zustand ist über `GameState`, `FreeColClient`, `GameStateManager` und `Game` verteilt. Reconnect-/Reload-/Selection-Recovery funktioniert, hängt aber an mehreren Reset- und Reconcile-Pfaden.
2. Viele Spielregeln und Reject-Pfade werden über String-Heuristiken klassifiziert (`ship`, `missionary`, `can not ...`, `server.reject`). Das ist praktisch, aber fragil gegen neue Einheiten, neue Servertexte oder lokalisierte Antworten.
3. Map-/Path-/Visibility-Logik arbeitet an mehreren Stellen mit linearen Scans über Tiles und Units. Für die aktuelle Größe okay, bei größeren Karten aber ein klarer Performance-Hotspot.

### Niedrig

1. In `MapView` und `LoginView` existieren weiterhin Debug-Ausgaben bzw. sichtbare Debug-Texte, die Produktionslogs und UX unnötig belasten.
2. Der Code besitzt Modell-Load-Fähigkeiten, aber noch keinen echten, durchgängigen Save/Load-Produktionsfluss auf UI-Ebene.

## Empfohlene Maßnahmen

1. Einen zentralen Session-State-Reset-/Recovery-Helfer einführen, damit Disconnect, Reconnect, Login und Snapshot-Load identisch behandelt werden.
2. String-Heuristiken schrittweise durch gemeinsame Konstanten, Modellflags oder Protokollfelder ersetzen.
3. Häufig genutzte Tile-/Unit-Lookups für MapView und Pfad-/Sichtbarkeitslogik indexieren oder cachen.
4. Debug-Prints und Debug-UI-Texte vor einem Stabilitätsrelease entfernen oder hinter eine Logger-Policy hängen.
5. Save/Load auf UI-/Workflow-Ebene vervollständigen, falls der nächste Meilenstein tatsächlich persistente Sessions verlangt.

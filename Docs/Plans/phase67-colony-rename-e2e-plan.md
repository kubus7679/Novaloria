# Phase 67 — Colony Rename E2E

## Ziel

Den Colony-Rename-Flow in `GameState` gegen den echten Java-Server validieren,
einschließlich der zurückgelieferten Modelländerung.

## Umsetzung

- [x] Nach der erfolgreichen Gründungsprobe `<rename nameable=... name=...>` an
      den Java-Server senden.
- [x] Name, Owner und Tile der bestehenden Kolonie nach der Antwort im Client-
      Modell prüfen.
- [x] Die Gameplay-Probe bei fehlender oder abgelehnter Umbenennung fehlschlagen
      lassen.

## Validierung

- `Tools/e2e-java-server.sh`: Smoke, Deep und Gameplay jeweils 1/0.
- Gameplay gründete und benannte eine Kolonie um, kaufte und verkaufte danach
  100 Pferde in Europa.
- `swift build --target Novaloria`, `swift test` (66 Tests) und
  `swift run FreeColProtocolCLI` (132 Prüfungen) erfolgreich.

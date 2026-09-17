# Phase 60 — Model-Tiefe (Implementiert)

Ziel: Verbleibende serverseitige Modelldaten sichtbar/nutzbar machen, die
zuvor still verworfen wurden.

## Umfang

### 1. Tile-Ressourcen & Lost City
- `Tile` parst `<resource id type quantity>` (`TileResource`) und
  `<lostCityRumour id type name>` (`lostCityRumourType`/`lostCityName`).
- `InfoPanelView` zeigt Ressourcen, Verbesserungen und Lost-City-Hinweise.

### 2. NationOptions & Cibola
- `Game.load` wendet `<nationOptions><nationOption id state/></nationOptions>`
  auf `nationStates` an (statt `break // not yet handled`).
- `<cibola id>` wird in `Game.cibolaCities` gesammelt.
- `<areas>` bleibt bewusst unmodelliert (nur Kommentar).

### 3. featureChange
- `Game.applyFeatureChange` verarbeitet `<featureChange id add>`: `ability`
  (`Player.abilities`) und `modelMessage` (Event-Log) werden übernommen;
  andere Feature-Arten werden geloggt, aber nicht modelliert.
- Verdrahtet in `Game.applyUpdate` (verschachtelt) und `GameStateManager`
  (Top-Level).

## Tests

- XCTest (+3, gesamt 65): Tile-Ressourcen/Lost-City, NationOptions/Cibola,
  `featureChange` (Fähigkeit + ModelMessage).
- CLI: 130 grün.

## Bekannte Grenzen

- Es gibt keine Modifier-/History-/LastSale-Engine client-seitig; nur
  Fähigkeiten und ModelMessages werden übernommen.
- `<areas>` (Land/See-Gruppen) wird nicht modelliert.

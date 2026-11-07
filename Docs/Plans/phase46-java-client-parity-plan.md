# Phase 46: Java-Client Parity (Map, Menus, Reports)

## Objective

Close the most visible gaps between the SwiftUI client and the Java client,
starting from the in-game screenshot (turn 3: almost the whole map is clouded,
minimap nearly black, no menu bar / reports).

Phases 1-9 (roadmap) delivered protocol, actions and dialogs. What is missing
now is **presentation parity**: the model already carries most data, but the UI
does not surface it the way the Java client does.

## Gap Analysis (screenshot + source comparison)

| Area | Java client | Swift client today | Impact |
|------|-------------|--------------------|--------|
| Fog of war | `explored` (`Tile.type != null`) vs `visible` (`Player.canSee`) | only a local `radius: 1` heuristic (`Game.visibleTileIds`) | **P0** — explored terrain hidden, whole map looks unexplored |
| Minimap | shows all explored terrain + viewport rect | reuses `visibleTileIds` → near-black | **P0** |
| View toggles | grid / borders / fog-of-war / tile text wired | `showMapGrid` / `showFogOfWar` in `GameState` never read by `MapView` | **P1** — dead toggles |
| Menu bar | Game / View / Orders / Report / Colopedia (`InGameMenuBar`) | single top bar + floating buttons | **P1** |
| Reports | ~16 panels (`Report*Panel`) | only `highScores` + `nationSummary` (`ReportsView`) | **P1** |
| Tile info / context | `TilePopup` + rich `InfoPanel` | tile highlight only | **P2** |
| Chat | `ChatPanel` (in + out) | inbound log only (`sendChatMessage` exists) | **P2** |
| Preferences / reconnect / save-load | `PreferencesAction`, `Reconnect`, `Save/Load` | reconnect partial, no UI for prefs/save | **P2** |
| Find settlement | `FindSettlementPanel` | none | **P3** |
| Colopedia | full in-game help | none | **P3** |

Key evidence:
- Java `Tile.toXML` only writes `type` for explored tiles → `explored == (type != nil)`.
- Java `MapViewer` draws clouds only on `!tile.isExplored()`, and dims
  explored-but-not-visible tiles with a `RescaleOp(0.8)` + 20% black overlay.
- Java `MapViewer` skips units/settlements for `!isExplored()` and applies the
  fog `RescaleOp` when `!player.canSee(tile)`.
- Java sight radius comes from `UnitType.getLineOfSight()` (default 1; ships 2;
  some units 3 — see `data/rules/classic/specification.xml`).

## Phase 46A — Fog of War & Visibility (P0)

### Scope

- Distinguish **explored** from **currently visible** everywhere.
- Render explored-but-not-visible as dimmed terrain (Java parity), clouds only
  for never-explored tiles.
- Show units/settlements only on currently visible tiles.
- Fix the minimap to render the explored map.
- Wire the existing `showFogOfWar` toggle (and `showMapGrid` while here).

### Implementation Steps

1. `FreeColGame/Model/Game.swift`
   - Add `isExplored(_ tileId:) -> Bool { tiles[tileId]?.type != nil }` and
     `exploredTileIds` (memoized).
   - Rework `visibleTileIds(for:radius:)`:
     - per-unit sight radius from the specification; fallback land 1 / naval 2.
     - keep colony and owned-tile sources.
     - mark the sighted tiles as **explored** (enables a client-side
       `exploredTileIds` even before the server resends a `partial`).
   - Add a `firstSighting`/`seen` set so explored state survives moves.
2. `FreeColGame/Model/Specification.swift`
   - Parse `<unit-type id= line-of-sight=>` into `unitTypes[id].lineOfSight`
     (the spec is already received at login; currently only 3 scalar fields
     are read).
3. `Novaloria/MapView.swift`
   - Compute `explored` and `visible` sets once per render (avoid per-tile
     `contains` scans by precomputing).
   - Unexplored → cloud texture (unchanged).
   - Explored & !visible → terrain fill + 20% black overlay (Java `0.2f`),
     still draw owner border/settlement name.
   - Visible → terrain + units + settlements (unchanged).
   - Respect `state.showFogOfWar` (no fog overlay when false) and
     `state.showMapGrid` (grid stroke).
4. `Novaloria/MiniMapView.swift`
   - Terrain from `exploredTileIds`; clouds only unexplored.
   - Units/settlements only when visible.
   - Keep aspect-fit scale and viewport-rect tracking from the previous fix.
5. Tests
   - CLI/XCTest: explored classification, sight radius lookup, minimap colour
     selection (pure helper extracted for testability).

### Validation

- `swift build --target Novaloria`
- `swift test`
- `swift run FreeColProtocolCLI`
- Manual: reconnect to the running Java server → explored area is visible,
  newly scouted tiles appear dimmed at the edge, minimap shows the continent.

## Phase 46B — In-Game Menu Bar & Reports (P1)

### Scope

- Menu structure mirroring `InGameMenuBar`: **Game / View / Orders / Report**.
- Report sheet covering the high-value `Report*Panel`s.
- Chat panel (outbound `sendChatMessage` already exists).

### Implementation Steps

1. `Novaloria/GameMenuBar.swift` (new): `Menu`s wired into `GameView.topBar`
   (SwiftUI `.commands` cannot host in-canvas state easily; use in-view menus).
   - Game: End Turn, Chat, Declare Independence, Retire, High Scores.
   - View: Grid, Borders, Fog of War, Tile Text, Zoom +/-.
   - Orders: Wait, Skip, Sentry, Fortify, Build Colony, Disband, Clear orders.
   - Report: entry points for the report sheet.
2. `Novaloria/ReportPanelView.swift` (new) + concrete report models derived
   from the game model (no new protocol needed):
   - Colony, Cargo, Trade, Labour/Production, Education, Military, Naval,
     Foreign Affairs, Indian, Exploration, Turn, History, Requirements,
     Continental Congress.
   - Reuse `ReportsView` for `highScores`/`nationSummary`.
3. `Novaloria/ChatPanelView.swift` (new): transcript of `incomingChatLog`
   + text field calling `sendChatMessage`.
4. `GameState`: add a `reportSelection`/`showReport` enum; expose computed
   report data (units by type, goods in colonies, stances, etc.).

## Phase 46C — Tile Info & Context Menu (P2)

- Extend `InfoPanelView` tile mode (terrain name, resource, region, owner,
  settlement, defending units, move cost).
- Right-click tile context menu (`TilePopup` parity): Goto, Fortify, Sentry,
  Build colony, Trade with settlement, Deliver gift, Demand tribute.
- `FindSettlementPanel` equivalent (jump camera to a settlement).

## Phase 46D — Unit / Colony UI Breadth (P2)

- Dedicated `UnitPanel` / `CargoPanel` / `InPortPanel` beyond the current
  floating quick-actions card.
- `TradeRoutePanel` (create/edit/assign routes; `assignTradeRoute` exists).
- Colony panel gaps: `BuildQueuePanel`, `WorkProductionPanel`, `BuildingPanel`.

## Phase 46E — Colopedia & Preferences (P3)

- In-game help browser for unit/goods/building types from the specification.
- Preferences sheet backed by `ClientOptions`-style local settings
  (display toggles, animation, autosave).

## Suggested Order

1. **46A Fog of War & Visibility** — highest visual impact, fixes the screenshot.
2. **46B Menu Bar & Reports** — unlocks the rest of the UI surface.
3. **46C Tile Info & Context Menu**.
4. **46D Unit / Colony UI breadth**.
5. **46E Colopedia & Preferences**.

## Open Questions

- Sight radius trusts the server spec (`line-of-sight`) with a name heuristic
  fallback (`UnitTypeTraits`), as planned. (Resolved.)
- Reports needing data not yet parsed (e.g. financial history) are derived from
  existing model state — see the `financial` report (Phase 53). (Resolved.)

## Status (implemented)

- 46A: `Game.isExplored` / `exploredTileIds` / `visibleTileIds` (per-unit
  `line-of-sight` from `Specification`, naval-name fallback), `MapView` dims
  explored-but-not-visible tiles and clouds only unexplored ones, `MiniMapView`
  renders explored terrain, grid/borders/fog toggles wired.
- 46B: `GameMenuBar` (Game/View/Orders/Report/Colopedia), `ReportPanelView`
  (colonies, units, cargo, military, naval, trade, foreign, indian,
  exploration, turn, high scores), `ChatPanelView`.
- 46C: richer `InfoPanelView` tile mode (explored/owner/region/settlement/units
  + destination actions), find-settlement navigator.
- 46D: cargo report added; dedicated panels deferred, trade-route editor
  delivered in Phase 47 (`Docs/Plans/phase47-trade-route-editor-plan.md`).
- 46E: `ColopediaView` (spec unit/goods browser), `PreferencesView`.
- Validation: `swift build --target Novaloria`, `swift test` (26),
  `swift run FreeColProtocolCLI` (118) — all green.

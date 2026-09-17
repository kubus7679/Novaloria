# Phase 47: Trade Route Editor

## Objective

Close the remaining roadmap Phase 13 gap (`Trade-route editor`) by implementing
the Java `TradeRoutePanel` workflow: list/create/edit/delete trade routes and
assign them to carriers, all driven by the existing wire messages.

## Wire contract (verified against `freecol/`)

- `NewTradeRouteMessage` — empty `<newTradeRoute/>` request. Server creates a
  route on the server player and answers with a ChangeSet containing
  `<newTradeRoute><tradeRoute .../></newTradeRoute>`
  (`server/control/InGameController.newTradeRoute`).
- `UpdateTradeRouteMessage` — client sends
  `<updateTradeRoute><tradeRoute id name owner silent><tradeRouteStop location><cargo id/>...</tradeRouteStop></tradeRoute></updateTradeRoute>`.
  Server copies in the route and broadcasts the object back
  (`server/control/InGameController.updateTradeRoute`).
- `DeleteTradeRouteMessage` — `<deleteTradeRoute tradeRoute=".."/>`; the server
  removes it and replies with a full player update.
- `AssignTradeRouteMessage` — `<assignTradeRoute unit=".." tradeRoute=".."/>`
  (already implemented).
- Inbound on login: `<player>` children include `<tradeRoute>` with
  `<tradeRouteStop location=..>` + `<cargo id=..>` children
  (`common/model/TradeRoute.java`, `TradeRouteStop.java`).

## Implementation Steps

1. `FreeColGame/Model/TradeRoute.swift` (new): `TradeRoute` (`id`, `name`,
   `owner`, `silent`, `stops`) + `TradeRouteStop` (`locationId`, `cargoTypeIds`),
   `GameObject`/`PartiallyUpdatable`, XML parsing of children.
2. `FreeColGame/Model/Game.swift`: `tradeRoutes` store, parsing from `<player>`
   children and top-level `<tradeRoute>` records, `addTradeRoute` /
   `removeTradeRoute` / `tradeRoutes(forPlayer:)` helpers.
3. `FreeColGame/Model/Player.swift`: parse `<tradeRoute>` children into the game.
4. `FreeColGame/State/GameStateManager.swift`: handle inbound `newTradeRoute`,
   `updateTradeRoute`, `deleteTradeRoute` (top-level and nested in `<update>`).
5. `FreeColApp/GameState.swift`: `tradeRoutes`, `tradeRouteStopCandidates`
   (owned colonies + Europe), `createTradeRoute()`, `saveTradeRoute(_:)`,
   `deleteTradeRoute(id:)`, guard on local turn.
6. `FreeColApp/TradeRoutePanelView.swift` (new): route list + editor
   (name, stop list with location picker and cargo toggles, add/remove stop),
   save/delete, assign to selected carrier.
7. `FreeColApp/GameMenuBar.swift` + `GameView.swift`: Orders menu entry
   ("Trade Routes…") + sheet wiring.
8. Tests: model round-trip parse of `<tradeRoute>`, `GameStateManager` inbound
   `newTradeRoute`/`updateTradeRoute`/`deleteTradeRoute`, outbound
   `updateTradeRoute` serialization.

## Validation

- `swift build --target FreeColApp`
- `swift test`
- `swift run FreeColProtocolCLI`

## Notes

- The generated `NewTradeRouteMessage`/`UpdateTradeRouteMessage` encode no
  children (codegen gap for object-carrying ObjectMessages), so GameState builds
  the `<tradeRoute>` `ParsedMessage` explicitly; generated files stay untouched.
- Optimistic local updates + server broadcast keeps the panel responsive; route
  removal relies on the optimistic local delete until a full player resend.

## Status (implemented)

- Model: `TradeRoute`/`TradeRouteStop`, `Game.tradeRoutes` + helpers, parsing in
  `Player`/`load`/`applyUpdate`/`applyPartial`/`applyRemove`.
- State: `GameStateManager` inbound `newTradeRoute`/`updateTradeRoute`/
  `deleteTradeRoute`; `GameState.createTradeRoute`/`saveTradeRoute`/
  `deleteTradeRoute` + stop/goods candidates + `tradeRouteMessage` serializer.
- UI: `TradeRoutePanelView` (route list, name, stops with location picker and
  cargo checkboxes, save/delete, assign/clear on selected unit) wired through
  the Orders menu ("Trade Routes…").
- Validation: `swift build`, `swift test` (28), `swift run FreeColProtocolCLI`
  (122) — green.

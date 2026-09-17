# FreeCol Client Development Plan

## Goal

Implement the macOS client in this repository so it can connect to the Java FreeCol server in `freecol/`, authenticate, receive game state, and drive core gameplay actions from the SwiftUI app.

## Reference Docs

- [Gesamtuebersicht](./freecol-client-overview.md)
- [Roadmap](./freecol-client-roadmap.md)

## Working Assumptions

- The Java server source is available in the sibling `freecol/` directory and is the protocol reference.
- The client should keep using the existing Swift Package / SwiftUI structure.
- Generated protocol message files should continue to come from `Tools/codegen.py` rather than being hand-written.

## Planned Phases

### 1. Protocol and session foundation

- Verify the connection and handshake flow against the Java server.
- Keep `FreeColProtocol` as the canonical boundary for XML/TCP encoding and decoding.
- Confirm the message registry covers the messages needed for login and initial game state.

### 2. Game state sync

- Ensure server updates are applied consistently in `FreeColGame` and `GameStateManager`.
- Align the Swift model with the message shapes used by the Java server.
- Add missing decode paths only when they are needed by the client flow.

### 3. Core gameplay actions

- Implement the minimum action set needed for normal play from the UI.
- Prioritize movement, turn progression, colony founding, and selection-driven actions.
- Compare behavior against the server-side message definitions in `freecol/` before adding new client actions.

### 4. UI and player flow

- Keep the SwiftUI app focused on login, map interaction, and state feedback.
- Add incremental UI for missing actions instead of redesigning the app wholesale.
- Preserve the current modular split between `FreeColApp`, `FreeColClient`, `FreeColGame`, and `FreeColProtocol`.

### 5. Testing and validation

- Test against the Java server from `freecol/` for end-to-end behavior.
- Add or extend unit tests in `Tests/FreeColProtocolTests/` for protocol regressions.
- Validate generated message changes after every regeneration.

## Current Gaps To Close

- Mock server coverage is still limited.
- Error handling and reconnect flows are incomplete.
- Several action messages and UI affordances are still missing.

## Implementation Rule

- Before every implementation, save the concrete plan in `Docs/Plans/` and keep it close to the work being done.

## Immediate Implementation Step

- [x] Centralize login-state loading in `GameStateManager` and clear stale handshake data before a new connection attempt.
- [x] Propagate server `gameState` messages into `GameState` so UI phase and status stay in sync after login.
- [x] Make the initial handshake collect both `gameState` and `vacantPlayers`, and feed the mock server with usable nation slots for login testing.
- [x] Stop blocking connect on optional `vacantPlayers`, and add a manual nation-id fallback in the login view when no slots are advertised.
- [x] Map `PRE_GAME` to a dedicated lobby phase so the app reflects the waiting state after login instead of staying on the login form.

## Current Implementation Status

- The message loop now keeps lobby-to-game transitions visible to the UI via `gameState` and `startGame`.
- Initial handshake handling now captures `vacantPlayers` sent immediately after `gameState`, while still allowing connect to complete when no vacant slots are advertised.
- Login-state loading is routed through `GameStateManager` instead of being split between the client actor and the model layer.
- Regression coverage for the current sync path is running through `swift run FreeColProtocolCLI`.
- `Package.swift` registers `FreeColProtocolTests` as a SwiftPM test target, and `swift test` is now working in this environment (`14 tests, 0 failures`).
- `swift run FreeColProtocolCLI` remains the active regression path and is green (`100 passed, 0 failed`), including env-gated real Java server checks: smoke (`REAL_SERVER_E2E=1`) and deep pregame/in-game probe (`REAL_SERVER_DEEP_E2E=1`).
- Phase-2 implementation started with Embark/Disembark/JoinColony action cluster (GameState action API + GameView controls + CLI regressions).
- Phase-2 tactical unit-state actions (`changeState`: active/fortify/sentry) are implemented in app state and UI, with protocol regression coverage.
- Phase-2 disband action (`disbandUnit`) is implemented with guard logic, in-game UI control, and protocol regression coverage.
- Phase-3 destination orders (`setDestination`: set/clear) are implemented in app state and UI, with protocol regression coverage.
- Phase-3 light path preview for selected unit destination is implemented in map rendering and validated.
- Phase-3 order-cycle robustness hardening (destination lifecycle + remove cleanup + sync reconcile) is implemented with added model regressions and validated.
- Phase-4 colony panel MVP is implemented (selected colony context + stationed units) and validated.
- Phase-4 colony actions MVP (`changeWorkType`, `rearrangeColony`, `setBuildQueue`) is implemented in state/UI with protocol regression coverage and validated.
- Phase-4 goods load/unload MVP is implemented in state/UI with protocol regression coverage and validated.
- Phase-5 combat actions MVP (`attack`, `attackRanged`) is implemented in state/UI with protocol regression coverage and validated.
- Phase-5 animate event cues (`animateMove`, `animateAttack`) are implemented in map rendering with regression coverage and validated.
- Phase-6 unit skip action MVP (`changeState` to `SKIPPED`) is implemented in state/UI with protocol regression coverage and validated.
- Phase-7 colony worker egress action MVP (`putOutsideColony`) is implemented in state/UI with protocol regression coverage and validated.
- Phase-8 colony worker work action MVP (`work`) is implemented in state/UI with protocol regression coverage and validated.
- Phase-9 colony rename action MVP (`rename`) is implemented in state/UI with protocol regression coverage and validated.
- Phase-6 save/load robustness now clears stale game state before loading a new snapshot, and lobby nation selection self-heals when the advertised nation list changes.
- Embarked units are now blocked from direct map-move orders, and the server reject path maps `MOVE_NO_ACCESS_EMBARK` to a clear disembark-first message.
- Phase-10 pay-for-building action MVP (`payForBuilding`) is implemented in state/UI with protocol regression coverage and validated.
- Phase-11 abandon-colony action MVP (`abandonColony`) is implemented in state/UI with protocol regression coverage and validated.
- Phase-12 set-goods-levels action MVP (`setGoodsLevels`) is implemented in state/UI with protocol regression coverage and validated.
- Phase-13 clear-speciality action MVP (`clearSpeciality`) is implemented in state/UI with protocol regression coverage and validated.
- Phase-14 assign-trade-route action MVP (`assignTradeRoute`) is implemented in state/UI with protocol regression coverage and validated.
- Phase-15 set-current-stop action MVP (`setCurrentStop`) is implemented in state/UI with protocol regression coverage and validated.
- Phase-16 assign-teacher action MVP (`assignTeacher`) is implemented in state/UI with protocol regression coverage and validated.
- Phase-17 change-work-improvement-type action MVP (`changeWorkImprovementType`) is implemented in state/UI with protocol regression coverage and validated.
- Phase-18 cash-in-treasure-train action MVP (`cashInTreasureTrain`) is implemented in state/UI with protocol regression coverage and validated.
- Phase-19 set-nation lobby action MVP (`setNation`) is implemented in state/UI with protocol regression coverage and validated.
- Phase-20 set-nation-type lobby action MVP (`setNationType`) is implemented in state/UI with protocol regression coverage and validated.
- Phase-21 set-color lobby action MVP (`setColor`) is implemented in state/UI with protocol regression coverage and validated.
- Phase-22 update-game-options lobby action MVP (`updateGameOptions`) is implemented in state/UI with protocol regression coverage and validated.
- Phase-23 update-map-generator-options lobby action MVP (`updateMapGeneratorOptions`) is implemented in state/UI with protocol regression coverage and validated.
- Phase-24 choose-founding-father lobby action MVP (`chooseFoundingFather`) is implemented in state/UI with protocol regression coverage and validated.
- Phase-25 continue action MVP (`continue`) is implemented in state/UI with protocol regression coverage and validated.
- Phase-26 retire action MVP (`retire`) is implemented in state/UI with protocol regression coverage and validated.
- Phase-27 enter-revenge-mode action MVP (`enterRevengeMode`) is implemented in state/UI with protocol regression coverage and validated.
- Phase-28 decline-mounds action MVP (`declineMounds`) is implemented in state/UI with protocol regression coverage and validated.
- Phase-29 monarch-action MVP (`monarchAction`) is implemented in state/UI with protocol regression coverage and validated.
- Phase-30 set-ai action MVP (`setAI`) is implemented in state/UI with protocol regression coverage and validated.
- Phase-31 set-available action MVP (`setAvailable`) is implemented in state/UI with protocol regression coverage and validated.
- Phase-32 set-stance action MVP (`setStance`) is implemented in state/UI with protocol regression coverage and validated.
- Phase-33 declare-independence action MVP (`declareIndependence`) is implemented in state/UI with protocol regression coverage and validated.
- Phase-34 chat action MVP (`chat`) is implemented in state/UI with protocol regression coverage and validated.
- Phase-35 set-dead action MVP (`setDead`) is implemented in state/UI with protocol regression coverage and validated.
- Phase-36 claim-land action MVP (`claimLand`) is implemented in state/UI with protocol regression coverage and validated.
- Phase-37 equip-for-role action MVP (`equipForRole`), Phase-38 learn-skill (`learnSkill`), Phase-39 new-land-name (`newLandName`), Phase-40 new-region-name (`newRegionName`) are implemented in state/UI with protocol regression coverage and validated.
- Phase-41 market buy/sell MVP (buy = `loadGoods` with Europe location, sell = `unloadGoods`) is implemented in state/UI with Europe/Market model parsing and protocol regression coverage and validated.
- Phase-7 parity pass (server-driven change handlers): `setStance`/`setAI`/`setDead`/`setNation`/`setNationType`/`setColor`/`setAvailable`/`logout` model+manager handlers (top-level and nested in `<update>`), `Player.stances` + `<stance>` parsing, inbound `chat` log, `gameEnded`, status placeholders for `fountainOfYouth`/`indianDemand`/`lootCargo`; outbound parity fixes for `setColor` (nation+RGB) and `setAvailable` (nation+state); MapView/LoginView debug-UI cleanup — validated (113 CLI / 14 swift tests green).

## Next Implementation Plan (Pre-Game Ready And Launch)

### Objective

Unblock game launch in PRE_GAME by implementing ready-state synchronization and launch requests in the Swift client.

### Scope

- [x] Handle inbound `ready` messages in `GameStateManager` so player readiness is reflected in the model.
- [x] Add outbound `ready` and `requestLaunch` actions in app state.
- [x] Expose lobby controls in SwiftUI for setting ready and triggering launch.
- [x] Add regression checks in CLI tests for inbound ready processing and outbound ready/requestLaunch sends.

### Execution Steps

1. [x] Extend message processing in `GameStateManager.process(_:)` with `case "ready"` and update `Player.ready` by `player` + `value` attributes.
2. [x] Extend `GameState` with lobby action methods:
	- [x] `setReady(_:)` sends `<ready value="..."/>`
	- [x] `requestLaunch()` sends `<requestLaunch/>`
3. [x] Keep a local ready flag in `GameState` for UI binding and sync it from incoming `ready` updates that match the logged-in player.
4. [x] Update `LoginView` lobby section with:
	- [x] a `Ready` toggle
	- [x] a `Start Game` button for lobby phase
5. [x] Add protocol regression coverage in `FreeColProtocolCLI`:
	- [x] unit test for `GameStateManager` handling of `ready`
	- [x] integration test that verifies the client sends `ready` and `requestLaunch`

### Validation

- [x] `swift build --target FreeColApp`
- [x] `swift run FreeColProtocolCLI`

### Expected Result

When connected in PRE_GAME, the Swift client can mark itself ready and send a launch request; incoming ready updates are visible in model/state, enabling compatibility with server-side all-ready launch conditions.

## Next TODO (In-Game Turn Sync)

### Objective

Stabilize in-game turn progression so end-turn actions are only sent when legal and server-driven turn-owner changes are always reflected in client state.

### Scope

- [x] Keep question-wrapped server updates synchronized to model/UI.
- [x] Guard end-turn action by local turn ownership in app state and UI.
- [x] Continue validating against Java server reconnect and active in-game sessions.

### Validation

- [x] `swift build --target FreeColApp`
- [x] `swift run FreeColProtocolCLI`
- [x] Manual reconnect + end-turn test path covered via integration regressions (`reconnect reaches UI delegate during message loop`, `endTurn applies server-driven turn sync`) plus env-gated Java-server checks in CLI.

## Next Implementation Plan (In-Game Turn Sync)

- Detailed plan saved in `Docs/Plans/in-game-turn-sync-plan.md`.

## Next Implementation Plan (Core Gameplay Actions)

- Detailed plan saved in `Docs/Plans/core-gameplay-actions-plan.md`.

## Next Implementation Plan (Phase 2 Action Cluster)

- Detailed plan saved in `Docs/Plans/phase2-embark-disembark-join-colony-plan.md`.

## Next Implementation Plan (Phase 2 Disband Action)

- Detailed plan saved in `Docs/Plans/phase2-disband-unit-plan.md`.

## Next Implementation Plan (Phase 3 Goto / SetDestination)

- Detailed plan saved in `Docs/Plans/phase3-set-destination-plan.md`.

## Next Implementation Plan (Phase 3 Light Path Preview)

- Detailed plan saved in `Docs/Plans/phase3-path-preview-plan.md`.

## Next Implementation Plan (Phase 3 Order Cycle Robustness)

- Detailed plan saved in `Docs/Plans/phase3-order-cycle-robustness-plan.md`.

## Next Implementation Plan (Phase 4 Colony Panel MVP)

- Detailed plan saved in `Docs/Plans/phase4-colony-panel-mvp-plan.md`.

## Next Implementation Plan (Phase 4 Colony Actions MVP)

- Detailed plan saved in `Docs/Plans/phase4-colony-actions-plan.md`.

## Next Implementation Plan (Phase 4 Goods Load/Unload MVP)

- Detailed plan saved in `Docs/Plans/phase4-goods-load-unload-plan.md`.

## Next Implementation Plan (Phase 5 Combat Actions MVP)

- Detailed plan saved in `Docs/Plans/phase5-combat-actions-plan.md`.

## Next Implementation Plan (Phase 5 Animate Event Cues MVP)

- Detailed plan saved in `Docs/Plans/phase5-animate-cues-plan.md`.

## Next Implementation Plan (Phase 6 Unit Skip Action MVP)

- Detailed plan saved in `Docs/Plans/phase6-unit-skip-plan.md`.

## Next Implementation Plan (Phase 7 Put Outside Colony Action MVP)

- Detailed plan saved in `Docs/Plans/phase7-put-outside-colony-plan.md`.

## Next Implementation Plan (Phase 8 Work Action MVP)

- Detailed plan saved in `Docs/Plans/phase8-work-action-plan.md`.

## Next Implementation Plan (Phase 9 Colony Rename Action MVP)

- Detailed plan saved in `Docs/Plans/phase9-colony-rename-plan.md`.

## Next Implementation Plan (Phase 10 Pay For Building Action MVP)

- Detailed plan saved in `Docs/Plans/phase10-pay-for-building-plan.md`.

## Next Implementation Plan (Phase 11 Abandon Colony Action MVP)

- Detailed plan saved in `Docs/Plans/phase11-abandon-colony-plan.md`.

## Next Implementation Plan (Phase 12 Set Goods Levels Action MVP)

- Detailed plan saved in `Docs/Plans/phase12-set-goods-levels-plan.md`.

## Next Implementation Plan (Phase 13 Clear Speciality Action MVP)

- Detailed plan saved in `Docs/Plans/phase13-clear-speciality-plan.md`.

## Next Implementation Plan (Phase 14 Assign Trade Route Action MVP)

- Detailed plan saved in `Docs/Plans/phase14-assign-trade-route-plan.md`.

## Next Implementation Plan (Phase 15 Set Current Stop Action MVP)

- Detailed plan saved in `Docs/Plans/phase15-set-current-stop-plan.md`.

## Next Implementation Plan (Phase 16 Assign Teacher Action MVP)

- Detailed plan saved in `Docs/Plans/phase16-assign-teacher-plan.md`.

## Next Implementation Plan (Phase 17 Work Improvement Type Action MVP)

- Detailed plan saved in `Docs/Plans/phase17-work-improvement-type-plan.md`.

## Next Implementation Plan (Phase 18 Cash In Treasure Train Action MVP)

- Detailed plan saved in `Docs/Plans/phase18-cash-in-treasure-plan.md`.

## Next Implementation Plan (Phase 19 Set Nation Lobby Action MVP)

- Detailed plan saved in `Docs/Plans/phase19-set-nation-plan.md`.

## Next Implementation Plan (Phase 20 Set NationType Lobby Action MVP)

- Detailed plan saved in `Docs/Plans/phase20-set-nation-type-plan.md`.

## Next Implementation Plan (Phase 21 Set Color Lobby Action MVP)

- Detailed plan saved in `Docs/Plans/phase21-set-color-plan.md`.

## Next Implementation Plan (Phase 22 Update GameOptions Lobby Action MVP)

- Detailed plan saved in `Docs/Plans/phase22-update-game-options-plan.md`.

## Next Implementation Plan (Phase 23 Update MapGeneratorOptions Lobby Action MVP)

- Detailed plan saved in `Docs/Plans/phase23-update-map-generator-options-plan.md`.

## Next Implementation Plan (Phase 24 Choose FoundingFather Lobby Action MVP)

- Detailed plan saved in `Docs/Plans/phase24-choose-founding-father-plan.md`.

## Next Implementation Plan (Phase 25 Continue Action MVP)

- Detailed plan saved in `Docs/Plans/phase25-continue-action-plan.md`.

## Next Implementation Plan (Phase 26 Retire Action MVP)

- Detailed plan saved in `Docs/Plans/phase26-retire-action-plan.md`.

## Next Implementation Plan (Phase 27 Enter Revenge Mode Action MVP)

- Detailed plan saved in `Docs/Plans/phase27-enter-revenge-mode-plan.md`.

## Next Implementation Plan (Phase 28 Decline Mounds Action MVP)

- Detailed plan saved in `Docs/Plans/phase28-decline-mounds-action-plan.md`.

## Next Implementation Plan (Phase 29 Monarch Action MVP)

- Detailed plan saved in `Docs/Plans/phase29-monarch-action-plan.md`.

## Next Implementation Plan (Phase 30 Set AI Action MVP)

- Detailed plan saved in `Docs/Plans/phase30-set-ai-action-plan.md`.

## Next Implementation Plan (Phase 31 Set Available Action MVP)

- Detailed plan saved in `Docs/Plans/phase31-set-available-action-plan.md`.

## Next Implementation Plan (Phase 32 Set Stance Action MVP)

- Detailed plan saved in `Docs/Plans/phase32-set-stance-action-plan.md`.

## Next Implementation Plan (Phase 33 Declare Independence Action MVP)

- Detailed plan saved in `Docs/Plans/phase33-declare-independence-action-plan.md`.

## Next Implementation Plan (Phase 34 Chat Action MVP)

- Detailed plan saved in `Docs/Plans/phase34-chat-action-plan.md`.

## Next Implementation Plan (Phase 35 Set Dead Action MVP)

- Detailed plan saved in `Docs/Plans/phase35-set-dead-action-plan.md`.

## Next Implementation Plan (Phase 36 Claim Land Action MVP)

- Detailed plan saved in `Docs/Plans/phase36-claim-land-action-plan.md`.

## Next Implementation Plan (Phase 37 EquipForRole Action MVP)

- [x] Generated EquipForRoleMessage from Java protocol source
- [x] Implemented equipSelectedUnitForRole() action in GameState
- [x] Added unit test for message serialization/deserialization
- [x] Added integration test for client-to-server action sending
- [x] Verified all tests pass (73 passed, 0 failed)
- Detailed plan saved in `Docs/Plans/phase37-equip-for-role-plan.md`.

## Next Implementation Plan (Phase 38 LearnSkill Action MVP)

- [x] Verified LearnSkillMessage is in MessageRegistry
- [x] Implemented learnSkillAtSelectedUnit(direction:) action in GameState
- [x] Added unit test for message serialization/deserialization
- [x] Added integration test for client-to-server action sending
- [x] Verified all tests pass (75 passed, 0 failed)
- Detailed plan saved in `Docs/Plans/phase38-learn-skill-plan.md`.

## Next Implementation Plan (Phase 39 NewLandName Action MVP)

- [x] Verified NewLandNameMessage is in MessageRegistry
- [x] Implemented nameNewLandWithSelectedUnit(name:) action in GameState
- [x] Added unit test for message serialization/deserialization
- [x] Added integration test for client-to-server action sending
- [x] Verified all tests pass (77 passed, 0 failed)
- Detailed plan saved in `Docs/Plans/phase39-new-land-name-plan.md`.

## Next Implementation Plan (Phase 40 NewRegionName Action MVP)

- [x] Verified NewRegionNameMessage is in MessageRegistry
- [x] Implemented nameNewRegionWithSelectedUnit(regionId:tileId:regionName:) action in GameState
- [x] Added unit test for message serialization/deserialization
- [x] Added integration test for client-to-server action sending
- [x] Verified all tests pass (79 passed, 0 failed)
- Detailed plan saved in `Docs/Plans/phase40-new-region-name-plan.md`.

## Next Implementation Plan (Phase 41 Market Buy/Sell Action MVP)

- [x] Verified the Java server routes buy/sell through `loadGoods`/`unloadGoods` with the Europe location id (`freecol/` InGameController buyGoods/sellGoods delegation).
- [x] Parsed `<europe>` and `<market>`/`<marketData>` player children into `Europe`, `Market`, `MarketData` models (Europe location id + reference prices).
- [x] Implemented `buyGoodsInEurope` / `sellGoodsInEurope` actions in GameState (loadGoods with Europe location / unloadGoods).
- [x] Exposed market board, carrier picker, and buy/sell controls in the Europe section of GameView.
- [x] Added model-parse, GameStateManager-update, and client-to-server integration regressions in FreeColProtocolCLI.
- [x] Verified validation commands pass.
- Detailed plan saved in `Docs/Plans/phase41-market-buy-sell-plan.md`.

## Next Implementation Plan (Phase 7 Java-Client Parity Pass)

- [x] Gap analysis: 31 receive-path candidates; 11 high-impact handlers implemented (see `Docs/Plans/phase7-parity-pass-plan.md`).
- [x] Verified Java wire shapes for change records (`setStance` first/second/stance, `setAI` player/ai, `setColor` nation/color-RGB, `setAvailable` nation/state, ...).
- [x] `Player.stances` dict + `<stance>` child parsing; `Game` nationStates/nationColors maps; nested change-record application in `applyUpdate`.
- [x] GameStateManager top-level handlers: `setStance`, `setAI`, `setDead`, `setNation`, `setNationType`, `setColor`, `setAvailable`, `logout`.
- [x] Inbound `chat` log, `gameEnded` (turn actions blocked), `logout` status, `fountainOfYouth`/`indianDemand`/`lootCargo` status placeholders in GameState/UI.
- [x] Outbound parity fixes: `setColor` (`nation` + RGB int), `setAvailable` (`nation` + `state` toggle); CLI tests updated.
- [x] Debug/UX cleanup: MapView per-render prints removed, LoginView DEBUG line removed.
- [x] CLI regressions (8 new: model/GMS unit tests + inbound loop integration test) and validation passed.
- Detailed plan saved in `Docs/Plans/phase7-parity-pass-plan.md`.

## Next Implementation Plan (Phase 42 Server Decision Dialogs)

- [x] Pending-decision model in `GameState` for `fountainOfYouth`/`indianDemand`/`lootCargo`.
- [x] Game-overlay shell in `GameView` preserving the status bar.
- [x] Lifecycle regression coverage scaffolded.
- Detailed plan saved in `Docs/Plans/phase42-server-decision-dialogs-plan.md`.

## Next Implementation Plan (Phase 43 Server Decision Payload Contract)

- [x] Corrected the wire-contract direction (`colony` not `settlement`; `winner`/`loser` not `unit`/`defender`;
      `fountainOfYouth` is a notification, answered with `emigrateUnit`).
- [x] Routed decision tags nested in `<update>`/`<multiple>` through to `GameState`.
- [x] `indianDemand` reply uses `indian_demand_accept`/`indian_demand_reject` plus `unit`/`colony`/`type`/`amount`.
- [x] `lootCargo` preserves `winner`/`loser` and `<goods>` children with selection UI.
- [x] Full `fountainOfYouth` emigration flow via `emigrateUnit`.
- Detailed plan saved in `Docs/Plans/phase43-server-decision-payload-contract-plan.md`.

## Next Implementation Plan (Phase 44 Server Prompt & Report Parity)

- [x] `firstContact` accept/decline prompt mit `result`-Boolean.
- [x] `monarchAction` Offer-Prompt (Accept/Decline) und korrigierter Reply-Shape
      (`action` + `result`; `sendMonarchAction` sendet jetzt `result`).
- [x] `newLandName`/`newRegionName` Text-Prompts mit Server-Default.
- [x] `close` räumt den passenden Prompt ab (Panel-Matching).
- [x] `highScores`/`nationSummary` in `GameState` + `ReportsView`.
- [x] Ergebnis-Logs für `scoutSpeakToChief`/`learnSkill`/`askSkill`/`incite`/`spySettlement`.
- [x] Routing über `GameStateManager.serverPromptTags` (auch verschachtelt in `<update>`).
- [x] Regressions: XCTest-Lifecycle + CLI-Roundtrips (22 XCTest / 115 CLI grün).
- `nativeTrade` (Trade-Session-UI) und `diplomacy` (`DiplomaticTrade`-Klauseln)
  sind bewusst nach Phase 45 verschoben.
- Detailed plan saved in `Docs/Plans/phase44-server-prompt-dialog-parity-plan.md`.

## Next Implementation Plan (Phase 45 / Roadmap Phase 9 Trade & Diplomacy Sessions)

- [x] `NativeTradeSession`/`NativeTradeItem` Modell + Parsing (`FreeColGame`).
- [x] `DiplomaticTradeProposal`/`DiplomaticTradeClause` Modell + Parsing (`FreeColGame`).
- [x] GameState: Prompt-Kinds `.nativeTrade`/`.diplomacy`, Inbound-Handling für
      alle `ACK_*`/`NAK_*`-Actions und `PROPOSE/ACCEPT/REJECT`, Outbound-Actions
      (open/close/buy/sell/gift, accept/reject diplomacy).
- [x] UI: `NativeTradeView` + `DiplomacyView`, Entry-Point im `InfoPanelView`.
- [x] Regressions: 24 XCTest / 116 CLI grün.
- ~~Known limitations~~ aufgelöst: proaktives Feilschen (Phase 52),
  Counter-Proposal-Builder (Phase 49).
- Detailed plan saved in `Docs/Plans/phase45-trade-diplomacy-sessions-plan.md`.

## Next Implementation Plan (Phase 46 Java-Client Parity: Map, Menus, Reports)

Gap-Analyse Screenshot vs. Java-Client: Die Karte zeigt nur den `radius: 1`-
Sichtbereich statt allen erkundeten Terrains, die Minikarte ist dadurch fast
schwarz, und Menüleiste/Reports fehlen. Die View-Toggles (`showFogOfWar`,
`showMapGrid`) sind im State vorhanden, aber in `MapView` ungenutzt.

Priorisierte Teilphasen:

- [x] **46A Fog of War & Visibility (P0)** — `explored` (`Tile.type != null`)
      vs. `visible` getrennt; Java-Rendering-Parität (20% Black-Overlay);
      Minikarte auf erkundetes Terrain; View-Toggles verdrahtet;
      Sight-Radius aus der Spec (`line-of-sight`) mit Namens-Fallback.
- [x] **46B Menüleiste & Reports (P1)** — Game/View/Orders/Report/Colopedia-Menü
      plus Report-Browser (Colonies, Units, Cargo, Military, Naval, Trade,
      Foreign, Indian, Exploration, Turn, High Scores) und Chat-Panel.
- [x] **46C Tile-Info & Kontextaktionen (P2)** — Tile-Details (explored, owner,
      region, settlement, units) plus Ziel-Aktionen und Find-Settlement.
- [x] **46D Unit-/Colony-UI-Breite (P2)** — Cargo-Report; Trade-Route-Editor
      (Phase 47) sowie Native-Settlement-Aktionen/Cargo-Liste (Phase 53).
- [x] **46E Colopedia & Preferences (P3)** — Spec-Browser + Display-Optionen.
- Tests: 26 XCTest / 118 CLI grün.
- Detailed plan saved in `Docs/Plans/phase46-java-client-parity-plan.md`.

## Next Implementation Plan (Phase 47 Trade Route Editor / Roadmap Phase 13)

- [x] `TradeRoute`/`TradeRouteStop` Modell + Parsing (`<player>`-Kinder,
      `newTradeRoute`/`updateTradeRoute` ChangeRecords).
- [x] `Game.tradeRoutes` Store + `addTradeRoute`/`removeTradeRoute`/
      `tradeRoutes(forPlayer:)`; `Player`/`load`/`applyUpdate`/`applyPartial`
      und `applyRemove` integriert.
- [x] `GameStateManager` Inbound-Handling `newTradeRoute`/`updateTradeRoute`/
      `deleteTradeRoute` (auch verschachtelt in `<update>`).
- [x] GameState-Actions `createTradeRoute`/`saveTradeRoute`/`deleteTradeRoute`
      plus Stop-/Goods-Kandidaten und expliziter `<tradeRoute>`-Serialisierung.
- [x] UI `TradeRoutePanelView` (Liste, Name, Stops mit Ort + Cargo, Speichern,
      Löschen, Zuweisung an ausgewählte Einheit), Entry-Point im Orders-Menü.
- [x] Regressionen: 28 XCTest / 122 CLI grün.
- ~~Known limitations~~ aufgelöst: Stop-Reihenfolge per Up/Down und
  „Current Stop"-Stepper im Panel (Phase 53).
- Detailed plan saved in `Docs/Plans/phase47-trade-route-editor-plan.md`.

## Next Implementation Plan (Phase 48 Colony Build Queue & Buildings Panel)

- [x] `BuildingTypeInfo` + `Specification.buildingTypes` (upkeep,
      required-population, upgrades-from, extends, displayName).
- [x] `Colony` parst `buildQueueItem`/`populationQueueItem`/`building`-Kinder
      in geordnete Queues + `buildings`.
- [x] GameState: `selectedColonyBuildableCandidates`, `selectedColonyBuildings`,
      `selectedColonyBuildQueue`, `buildingDisplayName(_:)`.
- [x] `ColonyPanelView`: Gebäudeliste, Build-Queue-Picker mit Add/Up/Down/Remove,
      Set/Reset und Sync bei server-seitiger Queue-Änderung.
- [x] Regressionen: 29 XCTest / 123 CLI grün.
- ~~Known limitations~~ aufgelöst: Upgrade-Voraussetzung (`upgrades-from`) und
  Kostenanzeige in der Bauliste (Phase 53).
- Detailed plan saved in `Docs/Plans/phase48-colony-build-panel-plan.md`.

## Next Implementation Plan (Phase 49 Diplomacy Counter-Proposal Builder)

- [x] `DiplomaticClauseKind`/`DiplomaticClauseDraft` Modell (+ Rekonstruktion
      aus empfangenen Klauseln).
- [x] GameState `sendDiplomacyCounterProposal(_:)` / `pendingDiplomacyDrafts` /
      `diplomacyClauseNode(...)`.
- [x] `DiplomacyView`: editierbare Klauseln (Gold/Waren/Kolonie/Stance),
      Richtungs-Picker, Senden.
- [x] Regressionen: 31 XCTest / 123 CLI grün.
- ~~Known limitations~~ aufgelöst: Unit-/Incite-Klauseln im Builder (Phase 49
  Follow-up).
- Detailed plan saved in `Docs/Plans/phase49-diplomacy-counter-proposal-plan.md`.

## Next Implementation Plan (Phase 50 Colony Production Estimate & ETA)

- [x] `BuildingTypeInfo` erweitert um `requiredGoods`/`productionOutputs`/
      `productionInputs`.
- [x] `Colony.goods` aus `<goodsContainer><storedGoods>` geparst.
- [x] GameState: Stored Goods, Build-Ziel, Requirements, `estimatedBuildPerTurn`
      und `estimatedBuildTurns` (testbare `nonisolated static`-Helfer).
- [x] `ColonyPanelView`: „Production Estimate" mit Fortschrittsbalken, ETA und
      Stored-Goods-Liste.
- [x] Regressionen: 32 XCTest / 124 CLI grün.
- ~~Known limitations~~ aufgelöst: attended/unattended getrennt, Zentralkachel
  einbezogen (Phasen 50 Follow-up / 53).
- Detailed plan saved in `Docs/Plans/phase50-colony-production-eta-plan.md`.

## Next Implementation Plan (Phase 51 Robustness Cleanup)

- [x] Zentraler Session-Reset (`GameState.resetSessionState`) von connect/
      disconnect/mock/reconnect genutzt (bereits vorhanden, verifiziert).
- [x] `UnitTypeTraits` (`isNaval`/`isMissionary`/`isCarrier`) als einzige
      Keyword-Quelle; `Specification`/`GameState` darauf umgestellt.
- [x] Keine Debug-Prints mehr (bereits in Phase 7 entfernt).
- [x] Regressionen: 32 XCTest / 125 CLI grün.
- Detailed plan saved in `Docs/Plans/phase51-robustness-cleanup-plan.md`.

## Next Implementation Plan (Phase 52 Native Trade Haggling)

- [x] `nativeTradeBuy`/`nativeTradeSell` mit `offerPrice`, `nativeTradeHaggleOffer`
      (±10 % Vorschlag) und gemeinsamem `sendNativeTradeOffer`.
- [x] `NativeTradeView`: Offer-Stepper, „Offer" (feilschen), „Accept" und
      „Gift" pro Warenposten plus Haggle-Zähler.
- [x] Regressionen: 33 XCTest / 126 CLI grün.
- Java-Parität: das native AI führt den `haggleCount` autoritativ; der Client
  liefert nur den Angebotspreis.
- Detailed plan saved in `Docs/Plans/phase52-native-trade-haggling-plan.md`.

## Follow-up zu Phasen 49–52 (Known Limitations abgebaut)

- [x] **49:** Unit-/Incite-Klauseln im Diplomatie-Builder (`unitTradeItem`
      `unit=`, `inciteTradeItem` `victim=`), Unit-/Viktim-Auswahllisten,
      Draft-Rekonstruktion.
- [x] **50:** attended/unattended-Produktion korrekt getrennt (kein Doppel-
      zählen), `estimatedProduction`-Aufschlüsselung pro Runde im Panel.
- [x] **51:** Spec-getriebene Fähigkeiten — `UnitTypeInfo.extendsId`/`abilities`,
      Auflösung von `navalUnit`/`carryUnits` über die `extends`-Kette,
      `line-of-sight`-Vererbung, `Specification.isNaval/carriesUnits` mit
      Heuristik-Fallback.
- [x] **52:** Offer-Stepper werden bei neuem Serverpreis zurückgesetzt,
      Siedlungsname statt ID.
- [x] Regressionen: 33 XCTest / 128 CLI grün.

## Next Implementation Plan (Phase 53 Offene Punkte)

- [x] **MockServer**: lokale Spiele beantworten `endTurn` (Turn-Wechsel via
      `<newTurn>`/`<setCurrentPlayer>`) und `chat` (Echo) →
      `GameState.startLocalServerLoop`; End Turn funktioniert im lokalen Spiel.
- [x] **46C/46D UI**: Native-Settlement-Menü in `unitQuickActions`
      (Trade, Deliver Gift, Demand Tribute, Spy, Scout, Incite) plus Cargo-Liste
      mit Auswahl eingeschiffter Einheiten; `directionToAdjacentSettlement(_:)`.
- [x] **Phase 48**: `buildableBuildingCandidates` verlangt bei Upgrades das
      Vorhandensein des `upgrades-from`-Gebäudes.
- [x] **Phase 50**: `<tile-type>`-Produktion (`TileTypeInfo`) und Einbeziehung
      der Kolonie-Zentralkachel in die Produktions-/ETA-Schätzung.
- [x] **Zusatz**: Financial-Report (`ReportKind.financial`), Trade-Route-Stop-
      Reihenfolge (Up/Down) + „Current Stop"-Stepper, Kostenanzeige in der
      Kolonie-Bauliste.
- [x] **Analyse-Empfehlung #3 (Performance)** bewertet: Tile-/Unit-Lookups sind
      bei aktuellen Kartengrößen unkritisch; Indizes werden pro Render/Report
      lokal gebildet, kein persistenter Cache nötig.
- [x] Regressionen: 36 XCTest / 129 CLI grün.
- Detailed plan saved in `Docs/Plans/phase53-open-points-cleanup-plan.md`.

## Status-Korrektur (nach Java-Gegenprüfung)

Die obigen `[x]`-Markierungen (Phasen 1–53) bedeuten „protokoll-/UI-seitig
angebunden", **nicht** „wie der Java-Client spielbar". Eine systematische
Gegenprüfung gegen `/Users/marcel/projects/freecol` (104/104 Message-Tags
vorhanden, ~60 von ~70 `ServerAPI`-Actions) listet die verifizierten
Restlücken in `Docs/Plans/playability-roadmap-54-57.md`.

## Phase 54 — Inbound-Blocker (Spielbarkeit zuerst)

- [x] `chooseFoundingFather` eingehend: Pending-Typ, Angebotsliste
      (`trade/exploration/military/political/religious`), In-Game-Dialog,
      Outbound-Guard entkoppelt (lobby **und** inGame).
- [x] `setDead` lokale Niederlage: Niederlage-Overlay + „Enter Revenge Mode".
- [x] Lokaler `logout`: an die UI durchgereicht (Session-Ende erreichbar).
- [x] `gameEnded`: Sieg-Overlay mit „Continue Playing"/„Retire".
- [x] `incite` (Bestätigung), `spySettlement` (Kolonie-Panel),
      `scoutSpeakToChief` (Info) eingehend behandelt.
- [x] `updateGameOptions`/`updateMapGeneratorOptions`-Echo in
      `Game.optionValues` gemergt.
- [x] Regressionen: 43 XCTest / 130 CLI grün.
- Detailed plan saved in `Docs/Plans/phase54-inbound-blockers-plan.md`.

## Offene Arbeit (Phasen 55–57)

- [ ] **55 Kolonie-Ökonomie**: `<exportData>`/Warehouse-Levels, echtes
      `rearrangeColony`, Worker-Picker, Marktpreise, `payArrears`.
- [ ] **56 Karte/Einheiten**: `moveTo`, Clear Orders/Next-Unit/EndTurn-Dialog,
      TilePopup, Pionier-Improvements auf der Karte.
- [ ] **57 Founding Fathers & Reports**: FF-Daten/Congress-Report, fehlende
      Reports, `modelMessage`-Event-Log, Score/Summary-Requests, Colopedia.
- Backlog (58–61): Diplomatie/Native-Tiefe, Europe-Tiefe, Model-Tiefe,
  Meta (Save/Load via embedded Server) — siehe
  `Docs/Plans/playability-roadmap-54-57.md`.

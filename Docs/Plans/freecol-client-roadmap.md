# FreeCol Client - Roadmap

> **Hinweis (Status):** Die folgenden Phasen 1–14 sind *protokoll-/UI-seitig*
> angebunden. „Spielbar wie der Java-Client" ist damit noch nicht erreicht.
> Die verifizierten Restlücken stehen in
> `Docs/Plans/playability-roadmap-54-57.md` (Phasen 54–57).

## Phase 1: Colony and Unit UX completion

- [x] Finalize cargo controls for embarked units.
- [x] Improve colony founding and colony entry flows.
- [x] Add clearer unit location/status indicators.

## Phase 2: Colony management parity

- [x] Worker assignment and production details.
- [x] Build queue, goods thresholds, specialists, and improvements.
- [x] Colony abandonment / rename / upkeep edge cases.

## Phase 3: Europe and economy

- [x] Europe screen / recruit / immigration.
- [x] Market buy/sell flows.
- [x] Treasure, trade routes, and cargo/economy polish.

## Phase 4: Diplomacy and native gameplay

- [x] First contact, stance changes, gifts, tribute, missionary flows.
- [x] Scout/chief/skill dialogs.
- [x] Event handling and message-driven UI prompts.

## Phase 5: Combat and map polish

- [x] Better combat feedback and result handling.
- [x] Pathfinding / goto improvements.
- [x] Fog of war, visibility, and map overlays.

## Phase 6: Session stability

- [x] Reconnect flows and stale-selection recovery.
- [x] Error handling for all server reject cases.
- [x] Save/load, lobby robustness, and end-to-end regressions.

## Phase 7: Java-client parity pass

- [x] Compare remaining dialogs and actions against the Java client.
- [x] Fill in missing message handlers.
- [x] Remove temporary debug output and tighten UX.

## Phase 8: Server prompt & report parity

- [x] `firstContact` / `monarchAction` accept-decline prompts with correct replies.
- [x] `newLandName` / `newRegionName` text prompts seeded with server defaults.
- [x] `close` dismisses the matching prompt.
- [x] `highScores` / `nationSummary` report surfaces.
- [x] Informational result logs (scout / learn / incite / spy).

## Phase 9: Trade & diplomacy sessions

- [x] `nativeTrade` trade-session UI (open/close/buy/sell/gift, prices, haggle display).
- [x] `diplomacy` (`DiplomaticTrade` clause parsing + accept/reject).

## Phase 10: Map visibility parity

- [x] Distinguish explored (`Tile.type != null`) from currently visible.
- [x] Render explored-but-not-visible tiles dimmed; clouds only for unexplored.
- [x] Correct minimap to render explored terrain.
- [x] Wire grid / borders / fog-of-war view toggles.

## Phase 11: In-game menus & reports

- [x] Game / View / Orders / Report menu structure.
- [x] Report panels (colony, units, cargo, trade, military, naval, foreign,
      indian, exploration, turn, high scores).
- [x] Chat panel with outbound messages.

## Phase 12: Tile info & context menu

- [x] Rich tile details in the info panel.
- [x] Tile action controls (set/clear destination).
- [x] Find-settlement navigation.

## Phase 13: Unit & colony UI breadth

- [x] Cargo report (carriers + embarked units).
- [x] Trade-route editor.
- [x] Colony build-queue / production / building panels.

## Phase 14: Colopedia & preferences

- [x] In-game help browser.
- [x] Preferences sheet (display/animation).

## Phase 15: Playability completion (54–57)

- [x] **54 Inbound blockers** — `chooseFoundingFather` in-game dialog,
      `setDead` defeat/revenge, local `logout`, `gameEnded` victory screen,
      `incite`/`spySettlement`/`scoutSpeakToChief` prompts, lobby option echo.
- [x] **55 Colony economy** — export-data/warehouse levels, real
      `rearrangeColony`, worker pickers, market buy/sell prices, `payArrears`.
- [x] **56 Map/unit orders** — `moveTo`, clear orders, next-unit cycle,
      end-turn dialog, tile popup, map pioneer improvements.
- [x] **57 Founding Fathers & reports** — FF data/Congress report, missing
      reports, `modelMessage` event log, score/summary requests, Colopedia.
- [x] **58 Diplomacy/Native depth** — active diplomacy, native settlement
      details, ask/learn skill, pre-combat confirm, tension/mission bans.
- [x] **59 Europe depth** — purchase units, recruit slots, cargo/dump,
      market price history.
- [x] **60 Model depth** — featureChange abilities/messages, tile resources,
      lost city, nation options, Cibola.
- Backlog: 61 meta (save/load via embedded server).

## Suggested order

1. Colony management parity
2. Europe and economy
3. Diplomacy and native gameplay
4. Combat and map polish
5. Session stability
6. Java-client parity pass
7. Server prompt & report parity
8. Trade & diplomacy sessions
9. Map visibility parity
10. In-game menus & reports
11. Tile info & context menu
12. Unit & colony UI breadth
13. Colopedia & preferences

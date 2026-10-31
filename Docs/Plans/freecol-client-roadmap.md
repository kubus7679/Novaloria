# FreeCol Client - Roadmap

> **Hinweis (Status):** Die folgenden Phasen 1–14 sind *protokoll-/UI-seitig*
> angebunden. „Spielbar wie der Java-Client" ist damit noch nicht erreicht.
> Die verifizierten Restlücken stehen in
> `Docs/Plans/playability-roadmap-54-57.md` (Phasen 54–65) sowie die
> Economy-/Colony-Management-Follow-ups der Phasen 66–102. Im aktuellen Java-Lauf
> bestehen 11 von 12 Proben (smoke, deep, gameplay, reject, traderoute, multiplayer,
> Native Trade, abandon, combat, missionary/spy, recruitment); Diplomatie wird
> übersprungen, weil keine AI-Antwort beobachtet wird. `STRICT_SKIPS=1` deckt diesen
> offenen Fall auf. Die native UI-
> Sichtprüfung der Transit-/Ankunftsanzeige steht noch aus.

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

## Phase 15: Playability completion and real-server validation (54–82)

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
- [x] **61 Lobby & status parity** — player table, option presets/server echo,
      status panel, codegen fix for final message classes. Non-goals:
      metaserver browser, save/load.
- [x] **62 Java-server E2E** — reproducible Docker harness plus smoke and
      pre-game-to-in-game probes against the real server.
- [x] **63 Gameplay E2E implementation** — move a unit and advance the turn,
      plus market buy/sell and conditional colony founding with model assertions.
- [x] Expanded Phase-63 probe run against Java: Smoke/Deep/Gameplay each 1/0 in
      isolated probe mode; movement, turn advance and market trade verified.
- [x] **64 Market transaction E2E** — carrier sails to Europe, cargo space is
      freed when needed, and a real 100-goods buy/sell roundtrip is asserted.
      The harness requires the market action; Java probes each passed 1/0.
- [x] **65 Colony founding E2E** — move a founder from its carrier onto a valid
      coastal tile, found a colony and assert the server model. The harness
      requires this action; see `phase65-colony-founding-e2e-plan.md`.
- [x] **66 Colony worker improvement picker** — select a tile improvement from
      the loaded specification rather than entering a raw protocol ID. See
      `phase66-colony-worker-improvement-picker-plan.md`.
- [x] **67 Colony rename E2E** — rename the founded colony against Java and
      assert updated name, owner and tile in the client model. See
      `phase67-colony-rename-e2e-plan.md`.
- [x] **68–70 Europe market availability** — bound buys by affordability/free
      cargo and sales by selected-carrier cargo. See
      `phase68-europe-market-availability-plan.md` and
      `phase69-market-affordability-plan.md` plus
      `phase70-europe-cargo-capacity-plan.md` for Java behavior and validation.
- [x] **71 Market quantity shortcuts** — fill the trade amount with the
      affordable/loadable buy maximum or the selected carrier's sale cargo.
      See `phase71-market-quantity-shortcuts-plan.md`.
- [x] **72 Colony warehouse E2E** — update export/import levels on the founded
      colony against Java and assert the server update in the client model. See
      `phase72-colony-warehouse-e2e-plan.md`.
- [x] **73 Boycott-aware market trading** — disable Buy/Sell while arrears are
      owed and guard the app-state trade actions. See
      `phase73-market-boycott-guards-plan.md`.
- [x] **74 Trade route CRUD E2E** — create, update and delete a two-stop trade
      route against Java and assert each route snapshot in the model. See
      `phase74-trade-route-e2e-plan.md`.
- [x] **75 Trade route save validation** — validate names, owned stops, cargo
      and standard-route rules before sending updates. See
      `phase75-trade-route-validation-plan.md`.
- [x] **76 Trade route assignment E2E** — assign a Java-saved route to a carrier
      and verify deletion releases the carrier. See
      `phase76-trade-route-assignment-e2e-plan.md`.
- [x] **77 Market price parity** — align Float rounding and New World derived
      goods clamps with Java `MarketData.price()`. See
      `phase77-market-pricing-parity-plan.md`.
- [x] **78 Market price-step limits** — cap each purchase by Java's per-step
      pricing chunk and verify direct action bounds. See
      `phase78-market-price-chunk-limits-plan.md`.
- [x] **79 Market transaction quotes** — show total buy cost and net sale
      proceeds; limit both transaction directions to one price step. See
      `phase79-market-transaction-quotes-plan.md`.
- [x] **80 Buy/sell price history** — record and chart both price series for
      selected goods. See `phase80-market-price-history-plan.md`.
- [x] **81 Price history with time axis** — show turn numbers on X-axis,
      grid lines and Y-axis price labels on price history chart. See
      `phase81-market-price-history-time-axis-plan.md`.
- [x] **82 Market price trend indicators** — show up/down/stable arrows
      next to prices based on recent price movements. See
      `phase82-market-price-trend-indicators-plan.md`.
- [x] **83 Automated trade route execution** — execute assigned trade routes at
      turn end: move carriers to stops, load/unload goods, advance route counter.
      Auto-execute toggle in trade route editor. See
      `phase83-automated-trade-route-execution-plan.md`.
- [x] **84 Trade Route E2E Validation** — dedicated end-to-end test for trade route
      assignment against the Java FreeCol server. Route stops are advanced
      client-side via `setCurrentStop` (the server does not do it at turn end);
      the probe verifies assignment, endTurn invariance, stop cycling with
      wrap-around and rejection of an out-of-range index.
      See `phase84-trade-route-e2e-validation-plan.md`.
- [x] **85 Multiplayer Turn Gating** — complete turn ownership parity with Java
      client for multiplayer: validates current player can endTurn, non-current
      players receive server rejection; UI shows turn status (current player,
      "your turn"/"waiting for X"); server error messages mapped to user-facing
      German text. See `phase85-multiplayer-turn-gating-plan.md`.
- [x] **86 Server Prompt Parity** — complete parity for server prompts requiring
      user interaction: monarchAction (tax, army, navy, bell), firstContact
      (native diplomacy), indianDemand (tribute). German dialogs with proper
      messages and localized buttons. See `phase86-server-prompt-parity-plan.md`.
- [x] **87 Diplomacy & Native Trade E2E Validation** — Java-server probes for
      native trade OPEN/BUY/SELL/haggling and diplomacy proposals/AI responses,
      including asynchronous acknowledgements and model checks. Probes skip
      clearly when random map setup offers no reachable Native settlement or AI
      colony; full successful sessions validated against reachable E2E fixtures
      when available. See `phase87-diplomacy-native-trade-e2e-plan.md`.
- [x] **88 Combat E2E Validation** — Java-server probe for unit vs unit combat,
      colony attack, and naval combat. Verifies combat result parsing (attacker
      survival, defender removal via `remove`, movesLeft=0), colony capture
      (owner change). Probe skips when no enemy units/colonies reachable or
      carrier not at coast. See `phase88-combat-e2e-plan.md`.
- [x] **89 Missionary & Spy E2E Validation** — Java-server probe for sending
      missionaries to native settlements (sendMissionary) and spying on AI
      colonies (spySettlement). Verifies missionary placement, async conversion/
      skill results via modelMessage, and spy reports with colony details.
      Probe skips when no missionary/scout units or reachable targets. See
      `phase89-missionary-spy-e2e-plan.md`.
- [x] **90 Recruitment & Europe purchase E2E** — `moveTo` Europe, `emigrateUnit`,
      `trainUnitInEurope` verified against Java without skip; concrete recruit slot 1
      is asserted against the offered unit type. See
      `phase90-recruitment-immigration-e2e-plan.md`.
- [x] **91 Real E2E validation & client model fixes** — first real run of the
      whole suite; fixed `<highSeas>`/`<europe>` updates, specification-based
      Europe unit prices, flawed trade-route/multiplayer/prompt probes; E2E
      script now reports passed/skipped/failed. Phases 87–89 remain
      unverified (probes skip). See `plans.md`.
- [x] **94 Colony abandonment E2E** — deterministic empty-colony fixture verifies
      server removal and tile release; Java `remove xLength/x0` arrays are now
      applied to the client model.
- [ ] **95 Diplomacy depth** — AI response is explicitly a skip when absent; gifts,
      tribute and stance acceptance remain unverified against a completed Java
      negotiation. See `next-phases-plan.md`.
- [x] **96 Specific emigration slot** — recruit from Java Europe slot 1 and assert the
      selected offer and gold change; Fountain-of-Youth slot selection remains covered
      by the MockServer decision-action contract.
- [x] **97 CLI refactor, first step** — shared test support, offline tests and legacy
      server probes moved out of `main.swift`; remaining integration tests still need
      extraction. See `plans.md`.

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

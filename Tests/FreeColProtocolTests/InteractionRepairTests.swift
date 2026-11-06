import XCTest
import FreeColClient
import FreeColGame
import FreeColProtocol
@testable import FreeColApp

final class InteractionRepairTests: XCTestCase {
    @MainActor
    func testLobbyOnlyOffersServerAvailableNations() throws {
        let state = GameState()
        let game = Game()
        try game.load(from: XMLDecoder.decode("""
        <game id="lobby">
          <nationOptions>
            <nationOption id="model.nation.french" state="AVAILABLE"/>
            <nationOption id="model.nation.dutch" state="AVAILABLE"/>
            <nationOption id="model.nation.english" state="NOT_AVAILABLE"/>
            <nationOption id="model.nation.spanish" state="AI_ONLY"/>
            <nationOption id="model.nation.portuguese"/>
          </nationOptions>
        </game>
        """))
        state.installGame(game)
        XCTAssertTrue(state.availableLobbyNationIds.isEmpty)
        state.phase = .lobby
        XCTAssertEqual(state.availableLobbyNationIds, ["model.nation.dutch", "model.nation.french"])
        state.installGame(Game())
        XCTAssertTrue(state.availableLobbyNationIds.isEmpty)
        state.installGame(game)
        state.phase = .inGame
        XCTAssertTrue(state.availableLobbyNationIds.isEmpty)
    }

    @MainActor
    func testLobbyBackgroundIsBundledAndDecodable() throws {
        let image = try XCTUnwrap(LoginView.backgroundImage)
        XCTAssertEqual(image.size.width, 1600)
        XCTAssertEqual(image.size.height, 1200)
    }

    @MainActor
    func testColonyWarningsAndExperienceMessagesAreReadable() throws {
        let game = Game()
        try game.load(from: XMLDecoder.decode("""
        <game id="game-1" clientUserName="Alice">
          <player id="player-1" username="Alice">
            <modelMessage id="model.colony.famineFeared" source="colony-1" messageType="WARNING">
              <pair value="%colony%"><stringTemplate id="Boston" templateType="NAME"/></pair>
              <pair value="%number%"><stringTemplate id="2" templateType="NAME"/></pair>
            </modelMessage>
            <modelMessage id="model.unit.experience" source="colony-1" messageType="UNIT_IMPROVED">
              <pair value="%colony%"><stringTemplate id="Boston" templateType="NAME"/></pair>
              <pair value="%oldName%"><stringTemplate id="model.unit.freeColonist" templateType="KEY"/></pair>
              <pair value="%unit%"><stringTemplate id="model.unit.expertFarmer" templateType="KEY"/></pair>
            </modelMessage>
          </player>
          <colony id="colony-1" name="Boston" owner="player-1"/>
        </game>
        """))

        let state = GameState()
        state.installGame(game)
        let messages = try XCTUnwrap(game.players["player-1"]?.modelMessages)
        XCTAssertEqual(messages[0].replacements["%number%"], "2")
        XCTAssertEqual(
            state.modelMessageText(messages[0]),
            "In Boston wird eine Hungersnot befürchtet. Die Nahrung reicht nur noch für 2 Züge."
        )
        XCTAssertEqual(
            state.modelMessageText(messages[1]),
            "Ein Freier Kolonist in Boston ist durch Erfahrung zum Experten (Erfahrener Bauer) geworden."
        )
    }

    @MainActor
    func testLostCityRumourResultsFromServerAreReadable() throws {
        let game = Game()
        try game.load(from: XMLDecoder.decode("""
        <game id="game-1" clientUserName="Alice">
          <player id="player-1" username="Alice"/>
        </game>
        """))
        let state = GameState()
        state.installGame(game)
        let response = try XMLDecoder.decode("""
        <multiple>
          <featureChange id="player-1" add="true">
            <modelMessage id="model.lostCityRumour.ruins.description" source="unit-1" messageType="LOST_CITY_RUMOUR">
              <pair value="%money%"><stringTemplate id="600" templateType="NAME"/></pair>
            </modelMessage>
            <modelMessage id="model.lostCityRumour.nothing.0.description" source="unit-1" messageType="LOST_CITY_RUMOUR"/>
            <modelMessage id="model.lostCityRumour.learn.description" source="unit-1" messageType="LOST_CITY_RUMOUR">
              <pair value="%unit%"><stringTemplate id="model.unit.freeColonist" templateType="KEY"/></pair>
              <pair value="%type%"><stringTemplate id="model.unit.expertFarmer" templateType="KEY"/></pair>
            </modelMessage>
          </featureChange>
        </multiple>
        """)

        XCTAssertTrue(try GameStateManager(game: game).process(response))
        let messages = state.localPlayerModelMessages
        XCTAssertEqual(messages.count, 3)
        XCTAssertEqual(
            state.modelMessageText(messages[0]),
            "Ihr habt Ruinen mit Schätzen im Wert von 600 Gold entdeckt."
        )
        XCTAssertEqual(
            state.modelMessageText(messages[1]),
            "Das Gerücht über eine verlorene Stadt war nichts als ein Gerücht."
        )
        XCTAssertEqual(
            state.modelMessageText(messages[2]),
            "Freier Kolonist hat Erfahrung gesammelt und ist jetzt Erfahrener Bauer."
        )
    }

    @MainActor
    func testLocalStartPreservesSelectedNationAndGold() async throws {
        let state = GameState()
        defer { state.disconnect() }
        state.setGameOption("model.option.startingMoney", value: "4200")
        state.startLocal(userName: "Alice", nationId: "model.nation.french")
        try await waitUntil { state.phase == .inGame || state.errorMessage != nil }
        XCTAssertNil(state.errorMessage)
        XCTAssertEqual(state.localPlayer?.nationId, "model.nation.french")
        XCTAssertEqual(state.localPlayer?.gold, 4200)
    }

    @MainActor
    func testLocalStartUsesClassicEquippedStartingUnits() async throws {
        let state = GameState()
        defer { state.disconnect() }
        state.startLocal(userName: "Alice", nationId: "model.nation.dutch")
        try await waitUntil { state.phase == .inGame || state.errorMessage != nil }
        XCTAssertNil(state.errorMessage)

        let game = try XCTUnwrap(state.game)
        XCTAssertEqual(game.units.count, 3)
        XCTAssertEqual(game.units["unit-caravel"]?.unitType, "model.unit.caravel")
        XCTAssertEqual(game.units["unit-caravel"]?.location, "tile-4-1")

        let soldier = try XCTUnwrap(game.units["unit-veteran-soldier"])
        XCTAssertEqual(soldier.unitType, "model.unit.veteranSoldier")
        XCTAssertEqual(soldier.location, "unit-caravel")
        XCTAssertEqual(soldier.role, "model.role.soldier")
        XCTAssertEqual(soldier.roleCount, 1)
        XCTAssertEqual(soldier.state, .sentry)

        let pioneer = try XCTUnwrap(game.units["unit-hardy-pioneer"])
        XCTAssertEqual(pioneer.unitType, "model.unit.hardyPioneer")
        XCTAssertEqual(pioneer.location, "unit-caravel")
        XCTAssertEqual(pioneer.role, "model.role.pioneer")
        XCTAssertEqual(pioneer.roleCount, 1)
        XCTAssertEqual(pioneer.state, .sentry)
    }

    @MainActor
    func testTradeRouteAssignmentRequiresOwnedGoodsCarrierAndServerConfirmation() async throws {
        let server = MockServer()
        let state = GameState()
        let routeXML = """
        <tradeRoute id="route-1" name="Boston–Europa" owner="player-1">
          <tradeRouteStop location="colony-1"><cargo id="model.goods.grain"/></tradeRouteStop>
          <tradeRouteStop location="europe-1"/>
        </tradeRoute>
        <tradeRoute id="foreign-route" name="Andere Route" owner="player-2"/>
        """
        let xml = Self.gameXML.replacingOccurrences(of: "</game>", with: "\(routeXML)</game>")
            .replacingOccurrences(of: "\n", with: " ")
        let serverTask = Task {
            try await server.doHandshake(gameResponse: xml)
            for response in [
                #"<error message="Trade route rejected"/>"#,
                #"<partial id="wagon" tradeRoute="route-1"/>"#,
                #"<partial id="wagon" currentStop="1"/>"#,
                #"<partial id="wagon" tradeRoute=""/>"#,
            ] {
                let question = try XMLDecoder.decode(await server.nextLine())
                XCTAssertEqual(question.children.first?.tag,
                               response.contains("currentStop") ? "setCurrentStop" : "assignTradeRoute")
                XCTAssertEqual(question.children.first?.attributes["unit"], "wagon")
                let id = try XCTUnwrap(question.attributes["networkReplyId"])
                try await Task.sleep(nanoseconds: 80_000_000)
                await server.send("<reply networkReplyId=\"\(id)\">\(response)</reply>")
                await server.flush()
            }
        }
        defer { state.disconnect(); serverTask.cancel(); Task { await server.stop() } }
        state.connect(host: "127.0.0.1", port: server.port)
        try await waitUntil { state.phase == .login }
        state.login(userName: "Alice", nationId: "model.nation.dutch")
        try await waitUntil { state.phase == .inGame && state.game != nil }
        state.selectUnit("outside-worker", onTile: "tile-2-2")
        XCTAssertFalse(state.canAssignSelectedUnitTradeRoute("route-1"))
        state.selectUnit("ship", onTile: "tile-2-2")
        XCTAssertFalse(state.canAssignSelectedUnitTradeRoute("route-1"),
                       "A passenger-only carrier must not receive goods routes")
        state.selectUnit("wagon", onTile: "tile-2-2")
        XCTAssertFalse(state.canAssignSelectedUnitTradeRoute("foreign-route"))
        XCTAssertFalse(state.canAssignSelectedUnitTradeRoute("missing"))
        XCTAssertTrue(state.canAssignSelectedUnitTradeRoute("route-1"))
        state.assignSelectedUnitTradeRoute("route-1")
        XCTAssertFalse(state.canAssignSelectedUnitTradeRoute("route-1"))
        XCTAssertNil(state.selectedUnit?.tradeRoute)
        try await waitUntil { state.movingUnitId == nil }
        XCTAssertNotNil(state.errorMessage)
        XCTAssertNil(state.selectedUnit?.tradeRoute)
        state.assignSelectedUnitTradeRoute("route-1")
        try await waitUntil { state.movingUnitId == nil }
        XCTAssertEqual(state.selectedUnit?.tradeRoute, "route-1")
        XCTAssertFalse(state.canAssignSelectedUnitTradeRoute("route-1"))
        for invalid in ["-1", "2", "abc"] {
            state.setSelectedUnitCurrentStop(invalid)
            XCTAssertNotNil(state.errorMessage)
            XCTAssertEqual(state.selectedUnit?.currentStop, 0)
            XCTAssertNil(state.movingUnitId)
        }
        state.setSelectedUnitCurrentStop("1")
        XCTAssertEqual(state.selectedUnit?.currentStop, 0)
        try await waitUntil { state.movingUnitId == nil }
        XCTAssertEqual(state.selectedUnit?.currentStop, 1)
        state.clearSelectedUnitTradeRoute()
        XCTAssertEqual(state.selectedUnit?.tradeRoute, "route-1")
        try await waitUntil { state.movingUnitId == nil }
        XCTAssertNil(state.selectedUnit?.tradeRoute)
        XCTAssertNil(state.errorMessage)
        XCTAssertEqual(state.statusMessage, "Routenzuweisung entfernt.")
        try await serverTask.value
        state.game?.currentPlayerId = "player-2"
        state.gameUpdateID += 1
        XCTAssertFalse(state.canAssignSelectedUnitTradeRoute("route-1"))
    }

    @MainActor
    func testTradeRouteGoodsAndEuropeUseGermanLabels() throws {
        let state = try makeState()
        XCTAssertEqual(state.tradeRouteStopCandidates.first?.label, "Europa")
        XCTAssertEqual(state.tradeRouteGoodsTypes.first(where: { $0.id == "model.goods.grain" })?.label, "Getreidekörner")
        XCTAssertEqual(state.tradeRouteGoodsTypes.first(where: { $0.id == "model.goods.hammers" })?.label,
                       GameLabels.name("model.goods.hammers"))
    }

    @MainActor
    func testDisconnectedTradeRouteAssignmentDoesNotChangeOrQueueOrders() async throws {
        let state = try makeState()
        state.game?.addTradeRoute(TradeRoute(id: "route-1", name: "Versorgung", owner: "player-1"))
        state.gameUpdateID += 1
        state.selectUnit("wagon", onTile: "tile-2-2")
        state.assignSelectedUnitTradeRoute("route-1")
        try await waitUntil { state.movingUnitId == nil }
        XCTAssertNil(state.selectedUnit?.tradeRoute)
        XCTAssertNotNil(state.errorMessage)
        XCTAssertTrue(state.queuedGameplayActions.isEmpty)
    }

    @MainActor
    func testTradeRouteCarrierEligibilityUsesGoodsAbilityInsteadOfNavalHeuristic() throws {
        let state = try makeState()
        state.game?.addTradeRoute(TradeRoute(id: "route-1", name: "Versorgung", owner: "player-1"))
        state.game?.specification = Specification(parsed: try XMLDecoder.decode("""
        <freecol-specification id="spec"><unit-types>
          <unit-type id="goods-carrier"><ability id="model.ability.carryGoods"/></unit-type>
          <unit-type id="model.unit.caravel" extends="goods-carrier">
            <ability id="model.ability.navalUnit"/>
          </unit-type>
        </unit-types></freecol-specification>
        """))
        state.gameUpdateID += 1
        state.selectUnit("ship", onTile: "tile-2-2")
        XCTAssertTrue(state.canAssignSelectedUnitTradeRoute("route-1"))
        state.game?.specification = nil
        state.gameUpdateID += 1
        XCTAssertFalse(state.canAssignSelectedUnitTradeRoute("route-1"))
    }

    @MainActor
    func testDestinationChangesAndCancellationRequireServerConfirmation() async throws {
        let server = MockServer()
        let state = GameState()
        let serverTask = Task {
            try await server.doHandshake(gameResponse: Self.gameXML.replacingOccurrences(of: "\n", with: " "))
            for response in [
                #"<error message="Destination blocked"/>"#,
                #"<partial id="outside-worker" destination="tile-4-2"/>"#,
                #"<partial id="outside-worker" destination=""/>"#,
                #"<partial id="outside-worker" destination=""/>"#,
                #"<partial id="outside-worker" state="active"/>"#,
            ] {
                let question = try XMLDecoder.decode(await server.nextLine())
                let expectedTag = response.contains("state=") ? "changeState" : "setDestination"
                XCTAssertEqual(question.children.first?.tag, expectedTag)
                let id = try XCTUnwrap(question.attributes["networkReplyId"])
                try await Task.sleep(nanoseconds: 80_000_000)
                await server.send("<reply networkReplyId=\"\(id)\">\(response)</reply>")
                await server.flush()
            }
        }
        defer { state.disconnect(); serverTask.cancel(); Task { await server.stop() } }
        state.connect(host: "127.0.0.1", port: server.port)
        try await waitUntil { state.phase == .login }
        state.login(userName: "Alice", nationId: "model.nation.dutch")
        try await waitUntil { state.phase == .inGame && state.game != nil }
        state.selectUnit("outside-worker", onTile: "tile-2-2")
        state.setSelectedUnitDestination(to: "tile-4-2")
        XCTAssertNil(state.selectedUnit?.destination)
        XCTAssertFalse(state.canSetSelectedUnitDestination(to: "tile-3-2"))
        try await waitUntil { state.movingUnitId == nil }
        XCTAssertNotNil(state.errorMessage)
        XCTAssertNil(state.selectedUnit?.destination)
        state.setSelectedUnitDestination(to: "tile-4-2")
        try await waitUntil { state.movingUnitId == nil }
        XCTAssertEqual(state.selectedUnit?.destination, "tile-4-2")
        state.clearSelectedUnitDestination()
        XCTAssertEqual(state.selectedUnit?.destination, "tile-4-2")
        XCTAssertFalse(state.canClearSelectedUnitDestination)
        try await waitUntil { state.movingUnitId == nil }
        XCTAssertNil(state.selectedUnit?.destination)
        XCTAssertTrue(state.movementPath(for: try XCTUnwrap(state.selectedUnit)).isEmpty)
        XCTAssertNil(state.errorMessage)
        try state.game?.applyPartial(XMLDecoder.decode("""
        <partial id="outside-worker" destination="tile-4-2" state="sentry"/>
        """))
        state.gameUpdateID += 1
        state.clearSelectedUnitOrders()
        try await waitUntil { state.movingUnitId == nil }
        XCTAssertNil(state.selectedUnit?.destination)
        XCTAssertEqual(state.selectedUnit?.state, .active)
        XCTAssertEqual(state.statusMessage, "Befehle gelöscht.")
        try await serverTask.value
    }

    @MainActor
    func testFirstContactUsesPlayerNamesAndGermanNationFallback() throws {
        let state = try makeState()
        state.applySessionMessage(ParsedMessage(
            tag: "firstContact", attributes: ["player": "player-1", "other": "player-2", "camps": "2"],
            children: []
        ))
        XCTAssertEqual(state.pendingDecisionTitle, "Erstkontakt")
        XCTAssertTrue(state.firstContactMessage.contains("Alice"))
        XCTAssertTrue(state.firstContactMessage.contains("Bob"))
        XCTAssertFalse(state.firstContactMessage.contains("player-"))
        XCTAssertEqual(state.pendingDecisionSummary, state.firstContactMessage)
        try state.game?.applyUpdate(XMLDecoder.decode("""
        <update><player id="native" nationId="model.nation.aztec"/></update>
        """))
        state.applySessionMessage(ParsedMessage(
            tag: "firstContact", attributes: ["player": "player-1", "other": "native", "camps": "1"],
            children: []
        ))
        XCTAssertTrue(state.firstContactMessage.contains(GameLabels.name("model.nation.aztec")))
        XCTAssertTrue(state.firstContactMessage.contains("1 Siedlung."))
    }

    @MainActor
    func testUnitOrdersHideInapplicableColonyWorkAndEuropeTravel() throws {
        let state = try makeState()
        state.selectUnit("ship", onTile: "tile-2-2")
        XCTAssertFalse(state.showsColonyWorkOrder)
        XCTAssertFalse(state.canJoinSelectedColony)
        XCTAssertTrue(state.showsEuropeTravelOrder)
        state.selectUnit("outside-worker", onTile: "tile-2-2")
        XCTAssertTrue(state.showsColonyWorkOrder)
        XCTAssertTrue(state.canJoinSelectedColony)
        XCTAssertFalse(state.showsEuropeTravelOrder)
        XCTAssertFalse(state.canSendSelectedUnitToEurope)
        state.selectUnit("wagon", onTile: "tile-2-2")
        XCTAssertFalse(state.showsColonyWorkOrder)
        XCTAssertFalse(state.showsEuropeTravelOrder)
        state.selectUnit(nil, onTile: "tile-2-2")
        XCTAssertFalse(state.showsColonyWorkOrder)
        XCTAssertFalse(state.showsEuropeTravelOrder)
    }

    @MainActor
    func testColonyBuildChoicesUseGermanNamesAndPreserveCosts() throws {
        let state = try makeState()
        let game = try XCTUnwrap(state.game)
        let colony = try XCTUnwrap(game.colonies["colony-1"])
        let specification = Specification(parsed: try XMLDecoder.decode("""
        <freecol-specification>
          <building-type id="model.building.warehouse">
            <required-goods id="model.goods.hammers" value="80"/>
          </building-type>
          <building-type id="model.building.docks"/>
        </freecol-specification>
        """))
        let choices = GameState.buildableBuildingCandidates(
            colony: colony, specification: specification, population: 10
        )
        XCTAssertEqual(choices.first(where: { $0.id == "model.building.warehouse" })?.label,
                       "Lagerhaus – 80")
        XCTAssertEqual(choices.first(where: { $0.id == "model.building.docks" })?.label,
                       GameLabels.name("model.building.docks"))
    }

    @MainActor
    func testSavedMovementResumesNextTurnWithoutChangingSelectionAndClearsAtArrival() async throws {
        let server = MockServer()
        let state = GameState()
        let serverTask = Task {
            try await server.doHandshake(gameResponse: Self.gameXML.replacingOccurrences(of: "\n", with: " "))
            let replies = [
                ("setDestination", #"<partial id="outside-worker" destination="tile-4-2"/>"#),
                ("move", #"<partial id="outside-worker" location="tile-3-2" movesLeft="0"/>"#),
                ("move", #"<partial id="outside-worker" location="tile-4-2" movesLeft="0"/>"#),
                ("setDestination", #"<partial id="outside-worker" destination=""/>"#),
            ]
            for (tag, response) in replies {
                let question = try XMLDecoder.decode(await server.nextLine())
                XCTAssertEqual(question.children.first?.tag, tag)
                XCTAssertEqual(question.children.first?.attributes["unit"], "outside-worker")
                let id = try XCTUnwrap(question.attributes["networkReplyId"])
                await server.send("<reply networkReplyId=\"\(id)\">\(response)</reply>")
                await server.flush()
            }
        }
        defer { state.disconnect(); serverTask.cancel(); Task { await server.stop() } }
        state.connect(host: "127.0.0.1", port: server.port)
        try await waitUntil { state.phase == .login }
        state.login(userName: "Alice", nationId: "model.nation.dutch")
        try await waitUntil { state.phase == .inGame && state.game != nil }
        state.selectUnit("outside-worker", onTile: "tile-2-2")
        state.rightClickMapTile("tile-4-2")
        try await waitUntil { state.movingUnitId == nil && state.selectedUnit?.movesLeft == 0 }
        let game = try XCTUnwrap(state.game)
        XCTAssertEqual(game.units["outside-worker"]?.destination, "tile-4-2")
        XCTAssertEqual(state.movementPath(for: try XCTUnwrap(game.units["outside-worker"])),
                       ["tile-3-2", "tile-4-2"])
        state.selectUnit("ship", onTile: "tile-2-2")
        game.currentPlayerId = "player-2"
        state.syncAfterModelUpdate()
        try game.applyPartial(XMLDecoder.decode(#"<partial id="outside-worker" movesLeft="3"/>"#))
        game.turn = Turn(2)
        state.syncAfterModelUpdate()
        XCTAssertNil(state.movingUnitId, "Never continue during the opponent's turn")
        game.currentPlayerId = "player-1"
        state.syncAfterModelUpdate()
        state.syncAfterModelUpdate()
        try await waitUntil { state.movingUnitId == nil && game.units["outside-worker"]?.location == "tile-4-2" }
        XCTAssertNil(game.units["outside-worker"]?.destination)
        XCTAssertEqual(state.selectedUnitId, "ship")
        XCTAssertNil(state.errorMessage)
        try await serverTask.value
    }

    @MainActor
    func testAmericaDepartureWaitsForServerAndKeepsCargoOnRejection() async throws {
        let server = MockServer()
        let state = GameState()
        let xml = Self.gameXML.replacingOccurrences(
            of: #"location="tile-2-2" movesLeft="6""#,
            with: #"location="europe-1" movesLeft="0""#
        ).replacingOccurrences(of: "\n", with: " ")
        let serverTask = Task {
            try await server.doHandshake(gameResponse: xml)
            for response in [
                #"<error message="HighSeas does not connect to: map-1"/>"#,
                #"<partial id="ship" location="highSeas:1" destination="map-1" workLeft="3" movesLeft="0"/>"#,
            ] {
                let question = try XMLDecoder.decode(await server.nextLine())
                let action = try XCTUnwrap(question.children.first)
                XCTAssertEqual(action.tag, "moveTo")
                XCTAssertEqual(action.attributes["unit"], "ship")
                XCTAssertEqual(action.attributes["destination"], "map-1")
                let id = try XCTUnwrap(question.attributes["networkReplyId"])
                try await Task.sleep(nanoseconds: 80_000_000)
                await server.send("<reply networkReplyId=\"\(id)\">\(response)</reply>")
                await server.flush()
            }
        }
        defer { state.disconnect(); serverTask.cancel(); Task { await server.stop() } }
        state.connect(host: "127.0.0.1", port: server.port)
        try await waitUntil { state.phase == .login }
        state.login(userName: "Alice", nationId: "model.nation.dutch")
        try await waitUntil { state.phase == .inGame && state.game != nil }
        let game = try XCTUnwrap(state.game)
        try game.applyPartial(XMLDecoder.decode(#"<partial id="europe-worker" location="ship"/>"#))
        state.gameUpdateID += 1
        XCTAssertTrue(state.canSendShipToAmerica("ship"), "Departure from Europe needs no moves")
        XCTAssertFalse(state.canSendShipToAmerica("europe-worker"))
        game.currentPlayerId = "player-2"
        state.gameUpdateID += 1
        XCTAssertFalse(state.canSendShipToAmerica("ship"))
        game.currentPlayerId = "player-1"
        state.gameUpdateID += 1
        state.sendShipToAmerica("ship")
        XCTAssertFalse(state.canSendShipToAmerica("ship"), "Do not send duplicate requests")
        XCTAssertEqual(game.units["ship"]?.location, "europe-1")
        try await waitUntil { state.movingUnitId == nil && state.errorMessage != nil }
        XCTAssertEqual(game.units["ship"]?.location, "europe-1")
        XCTAssertEqual(game.units["europe-worker"]?.location, "ship")
        state.sendShipToAmerica("ship")
        try await waitUntil { state.movingUnitId == nil && game.units["ship"]?.location == "highSeas:1" }
        XCTAssertNil(state.errorMessage)
        XCTAssertFalse(state.canSendShipToAmerica("ship"))
        XCTAssertEqual(game.units["europe-worker"]?.location, "ship")
        XCTAssertEqual(state.unitTravelStatus(try XCTUnwrap(game.units["ship"])),
                       "Überfahrt: Neue Welt (3 Runden)")
        try await serverTask.value
    }

    @MainActor
    func testSaveGameIsDisabledWithoutAdministratorOrActiveSession() throws {
        let state = try makeState()
        XCTAssertFalse(state.canSaveGame)
        try state.game?.applyPartial(XMLDecoder.decode(#"<partial id="player-1" admin="true"/>"#))
        state.gameUpdateID += 1
        XCTAssertTrue(state.canSaveGame)
        state.phase = .reconnecting
        XCTAssertFalse(state.canSaveGame)
        state.phase = .disconnected
        XCTAssertFalse(state.canSaveGame)
    }

    func testSavegameReplyRejectsMissingCorruptAndNonArchivePayloads() throws {
        for attributes in [
            [:],
            ["encoding": "base64", "data": "invalid!"],
            ["encoding": "base64", "data": Data("not a save".utf8).base64EncodedString()],
            ["encoding": "text", "data": "UEsDBA=="],
        ] {
            XCTAssertThrowsError(try ServerSavegame.decode(ParsedMessage(
                tag: "saveGame", attributes: attributes, children: []
            )))
        }
        XCTAssertThrowsError(try ServerSavegame.decode(ParsedMessage(tag: "reply", attributes: [:], children: [])))
    }

    @MainActor
    func testSaveGameWritesConfirmedServerArchiveAndKeepsExistingFileOnFailure() async throws {
        let server = MockServer()
        let state = GameState()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        let destination = directory.appendingPathComponent("test.fsg")
        let original = Data("existing file".utf8)
        try original.write(to: destination)
        defer { try? FileManager.default.removeItem(at: directory) }
        let archive = Data([0x50, 0x4b, 0x03, 0x04, 0x00, 0x01])
        let xml = Self.gameXML.replacingOccurrences(
            of: #"username="Alice" nationId"#, with: #"username="Alice" admin="true" nationId"#
        ).replacingOccurrences(of: "\n", with: " ")
        let serverTask = Task {
            try await server.doHandshake(gameResponse: xml)
            for response in [
                #"<error message="Server could not create the savegame"/>"#,
                "<saveGame encoding=\"base64\" data=\"\(archive.base64EncodedString())\"/>",
            ] {
                let question = try XMLDecoder.decode(await server.nextLine())
                XCTAssertEqual(question.children.first?.tag, "saveGame")
                let id = try XCTUnwrap(question.attributes["networkReplyId"])
                try await Task.sleep(nanoseconds: 80_000_000)
                await server.send("<reply networkReplyId=\"\(id)\">\(response)</reply>")
                await server.flush()
            }
        }
        defer { state.disconnect(); serverTask.cancel(); Task { await server.stop() } }
        state.connect(host: "127.0.0.1", port: server.port)
        try await waitUntil { state.phase == .login }
        state.login(userName: "Alice", nationId: "model.nation.dutch")
        try await waitUntil { state.phase == .inGame && state.game != nil }
        XCTAssertTrue(state.canSaveGame)
        state.saveGame(to: destination)
        XCTAssertTrue(state.isSavingGame)
        XCTAssertFalse(state.canEndTurn)
        XCTAssertEqual(try Data(contentsOf: destination), original)
        try await waitUntil { !state.isSavingGame }
        XCTAssertNotNil(state.errorMessage)
        XCTAssertEqual(try Data(contentsOf: destination), original)
        state.saveGame(to: destination)
        try await waitUntil { !state.isSavingGame }
        XCTAssertNil(state.errorMessage)
        XCTAssertEqual(try Data(contentsOf: destination), archive)
        XCTAssertTrue(state.statusMessage.contains("Spiel gespeichert"))
        try await serverTask.value
        state.game?.currentPlayerId = "player-2"
        state.gameUpdateID += 1
        XCTAssertFalse(state.canSaveGame)
    }

    @MainActor
    func testEuropeEmbarkChecksCapacityWithoutRequiringMovesOrActiveState() throws {
        let state = try makeState()
        let game = try XCTUnwrap(state.game)
        game.specification = Specification(parsed: try XMLDecoder.decode("""
        <freecol-specification>
          <unit-type id="model.unit.caravel" space="2"><ability id="model.ability.navalUnit"/><ability id="model.ability.carryUnits"/></unit-type>
          <unit-type id="model.unit.freeColonist"/>
        </freecol-specification>
        """))
        try game.applyPartial(XMLDecoder.decode(#"<partial id="ship" location="europe-1"/>"#))
        try game.applyPartial(XMLDecoder.decode(#"<partial id="europe-worker" movesLeft="0" state="sentry"/>"#))
        state.gameUpdateID += 1
        XCTAssertTrue(state.canEmbarkUnit("europe-worker", onCarrier: "ship"))
        state.selectUnit("europe-worker", onTile: nil)
        XCTAssertTrue(state.canEmbarkSelectedUnit(onCarrier: "ship"))
        XCTAssertFalse(state.canEmbarkUnit("ship", onCarrier: "ship"))
        XCTAssertFalse(state.canEmbarkUnit("europe-worker", onCarrier: "wagon"))
        try game.applyUpdate(XMLDecoder.decode("""
        <update><unit id="ship" owner="player-1" unitType="model.unit.caravel" location="europe-1">
          <goodsContainer><storedGoods><goods type="model.goods.tools" amount="101"/></storedGoods></goodsContainer>
        </unit></update>
        """))
        XCTAssertFalse(state.canEmbarkUnit("europe-worker", onCarrier: "ship"), "Partial goods stacks occupy whole holds")
        game.removeUnitGoods(unitId: "ship", typeId: "model.goods.tools", amount: 101)
        try game.applyUpdate(XMLDecoder.decode("""
        <update><unit id="cargo" unitType="model.unit.freeColonist" owner="player-1" location="ship"/></update>
        """))
        XCTAssertTrue(state.canEmbarkUnit("europe-worker", onCarrier: "ship"))
        try game.applyUpdate(XMLDecoder.decode("""
        <update><unit id="cargo2" unitType="model.unit.freeColonist" owner="player-1" location="ship"/></update>
        """))
        XCTAssertFalse(state.canEmbarkUnit("europe-worker", onCarrier: "ship"))
        try game.applyPartial(XMLDecoder.decode(#"<partial id="ship" location="highSeas:1"/>"#))
        XCTAssertFalse(state.canEmbarkUnit("europe-worker", onCarrier: "ship"))
    }

    @MainActor
    func testEuropeEmbarkWaitsForServerAndPreservesLocationOnRejection() async throws {
        let server = MockServer()
        let state = GameState()
        let xml = Self.gameXML.replacingOccurrences(
            of: #"location="tile-2-2" movesLeft="6""#,
            with: #"location="europe-1" movesLeft="0""#).replacingOccurrences(of: "\n", with: " ")
        let serverTask = Task {
            try await server.doHandshake(gameResponse: xml)
            for response in [
                #"<error message="Carrier is full"/>"#,
                #"<partial id="europe-worker" location="ship" movesLeft="0" state="sentry"/>"#,
            ] {
                let question = try XMLDecoder.decode(await server.nextLine())
                let message = try XCTUnwrap(question.children.first)
                XCTAssertEqual(message.tag, "embark")
                XCTAssertEqual(message.attributes["unit"], "europe-worker")
                XCTAssertEqual(message.attributes["carrier"], "ship")
                let id = try XCTUnwrap(question.attributes["networkReplyId"])
                try await Task.sleep(nanoseconds: 80_000_000)
                await server.send("<reply networkReplyId=\"\(id)\">\(response)</reply>")
                await server.flush()
            }
        }
        defer { state.disconnect(); serverTask.cancel(); Task { await server.stop() } }
        state.connect(host: "127.0.0.1", port: server.port)
        try await waitUntil { state.phase == .login }
        state.login(userName: "Alice", nationId: "model.nation.dutch")
        try await waitUntil { state.phase == .inGame && state.game != nil }
        state.selectUnit("europe-worker", onTile: nil)
        state.embarkSelectedUnit(onCarrier: "ship")
        XCTAssertEqual(state.selectedUnit?.location, "europe-1")
        try await waitUntil { state.errorMessage != nil && state.movingUnitId == nil }
        XCTAssertEqual(state.game?.units["europe-worker"]?.location, "europe-1")
        state.embarkSelectedUnit(onCarrier: "ship")
        try await waitUntil { state.game?.units["europe-worker"]?.location == "ship" && state.movingUnitId == nil }
        XCTAssertNil(state.errorMessage)
        try await serverTask.value
    }

    @MainActor
    func testEmbarkFromAdjacentCoastalTileSendsDirection() async throws {
        let server = MockServer()
        let state = GameState()
        let xml = Self.gameXML.replacingOccurrences(
            of: #"id="ship" owner="player-1" unitType="model.unit.caravel" location="tile-2-2""#,
            with: #"id="ship" owner="player-1" unitType="model.unit.caravel" location="tile-2-4""#
        ).replacingOccurrences(of: "\n", with: " ")
        let serverTask = Task {
            try await server.doHandshake(gameResponse: xml)
            let question = try XMLDecoder.decode(await server.nextLine())
            let message = try XCTUnwrap(question.children.first)
            XCTAssertEqual(message.tag, "embark")
            XCTAssertEqual(message.attributes["unit"], "outside-worker")
            XCTAssertEqual(message.attributes["carrier"], "ship")
            XCTAssertEqual(message.attributes["direction"], "S")
            let replyId = try XCTUnwrap(question.attributes["networkReplyId"])
            await server.send("<reply networkReplyId=\"\(replyId)\"><animateMove oldTile=\"tile-2-2\" newTile=\"tile-2-4\" unit=\"outside-worker\"/></reply>")
            await server.flush()
        }
        defer { state.disconnect(); serverTask.cancel(); Task { await server.stop() } }
        state.connect(host: "127.0.0.1", port: server.port)
        try await waitUntil { state.phase == .login }
        state.login(userName: "Alice", nationId: "model.nation.dutch")
        try await waitUntil { state.phase == .inGame && state.game != nil }

        state.selectUnit("outside-worker", onTile: "tile-2-2")
        XCTAssertTrue(state.embarkCarrierOptions.contains { $0.id == "ship" })
        XCTAssertTrue(state.canEmbarkSelectedUnit(onCarrier: "ship"))
        state.embarkSelectedUnit(onCarrier: "ship")
        try await waitUntil { state.game?.units["outside-worker"]?.location == "ship" && state.movingUnitId == nil }
        XCTAssertNil(state.errorMessage)
        XCTAssertEqual(state.game?.units["outside-worker"]?.movesLeft, 0)
        XCTAssertNil(state.game?.tiles[state.game?.units["outside-worker"]?.location ?? ""])
        state.selectUnit("ship", onTile: "tile-2-4")
        XCTAssertEqual(state.selectedUnitCargoUnits.map(\.id), ["outside-worker"])
        try await serverTask.value
        await server.stop()
    }

    @MainActor
    func testEuropeDepartureRequiresHighSeasExitAndOwnShipOnOwnTurn() throws {
        let state = try makeState()
        let game = try XCTUnwrap(state.game)
        state.selectUnit("ship", onTile: "tile-2-2")
        XCTAssertFalse(state.canSendSelectedUnitToEurope, "A harbor is not a high-seas exit")
        state.sendSelectedUnitToEurope()
        XCTAssertTrue(state.errorMessage?.contains("Hochsee-Ausfahrtsfeld") == true)
        XCTAssertNil(game.units["ship"]?.destination)

        try game.applyPartial(XMLDecoder.decode(#"<partial id="ship" location="tile-2-4"/>"#))
        state.gameUpdateID += 1
        XCTAssertFalse(state.canSendSelectedUnitToEurope, "Ordinary ocean is not an exit")

        for (type, override, expected) in [
            ("model.tile.highSeas", "", true),
            ("model.tile.highSeas", "moveToEurope=\"false\"", false),
            ("model.tile.ocean", "moveToEurope=\"true\"", true),
        ] {
            let xml = Self.gameXML.replacingOccurrences(
                of: #"type="model.tile.plains" owner="player-1"/>"#,
                with: "type=\"\(type)\" \(override) owner=\"player-1\"/>")
            let candidate = Game()
            try candidate.load(from: XMLDecoder.decode(xml))
            state.installGame(candidate)
            state.selectUnit("ship", onTile: "tile-2-2")
            XCTAssertEqual(state.canSendSelectedUnitToEurope, expected)
            state.selectUnit("outside-worker", onTile: "tile-2-2")
            XCTAssertFalse(state.canSendSelectedUnitToEurope)
            state.selectUnit("ship", onTile: "tile-2-2")
            candidate.currentPlayerId = "player-2"
            state.gameUpdateID += 1
            XCTAssertFalse(state.canSendSelectedUnitToEurope)
        }
    }

    @MainActor
    func testGoToEuropeIsAvailableWhenShipCanReachAHighSeasExit() throws {
        let state = try makeState()
        state.selectUnit("ship", onTile: "tile-2-2")
        XCTAssertFalse(state.canGoSelectedShipToEurope)

        let xml = Self.gameXML.replacingOccurrences(
            of: #"id="tile-2-4" x="2" y="4" type="model.tile.ocean" owner="player-1""#,
            with: #"id="tile-2-4" x="2" y="4" type="model.tile.highSeas" moveToEurope="true" owner="player-1""#
        )
        let game = Game()
        try game.load(from: XMLDecoder.decode(xml))
        state.installGame(game)
        state.selectUnit("ship", onTile: "tile-2-2")
        XCTAssertTrue(state.canGoSelectedShipToEurope)

        game.currentPlayerId = "player-2"
        state.gameUpdateID += 1
        XCTAssertFalse(state.canGoSelectedShipToEurope, "The order is only available during the local turn")
    }

    @MainActor
    func testGoToEuropeMovesToExitThenStartsTheEuropeCrossing() async throws {
        let server = MockServer()
        let state = GameState()
        let gameXML = Self.gameXML
            .replacingOccurrences(
                of: #"id="tile-2-4" x="2" y="4" type="model.tile.ocean" owner="player-1""#,
                with: #"id="tile-2-4" x="2" y="4" type="model.tile.highSeas" moveToEurope="true" owner="player-1""#
            )
            .replacingOccurrences(of: "\n", with: " ")
        let serverTask = Task {
            try await server.doHandshake(gameResponse: gameXML)
            let responses = [
                #"<partial id="ship" destination="tile-2-4"/>"#,
                #"<partial id="ship" location="tile-2-4" movesLeft="3"/>"#,
                #"<partial id="ship" location="highSeas:1" destination="europe-1" state="TO_EUROPE" workLeft="3"/>"#,
            ]
            var requests: [ParsedMessage] = []
            for response in responses {
                let question = try XMLDecoder.decode(await server.nextLine())
                let replyId = try XCTUnwrap(question.attributes["networkReplyId"])
                requests.append(try XCTUnwrap(question.children.first))
                await server.send("<reply networkReplyId=\"\(replyId)\">\(response)</reply>")
                await server.flush()
            }
            return requests
        }
        defer {
            state.disconnect()
            serverTask.cancel()
            Task { await server.stop() }
        }
        state.connect(host: "127.0.0.1", port: server.port)
        try await waitUntil { state.phase == .login }
        state.login(userName: "Alice", nationId: "model.nation.dutch")
        try await waitUntil { state.phase == .inGame && state.game != nil }

        state.selectUnit("ship", onTile: "tile-2-2")
        XCTAssertTrue(state.canGoSelectedShipToEurope)
        state.goSelectedShipToEurope()
        try await waitUntil {
            state.movingUnitId == nil && state.game?.units["ship"]?.location == "highSeas:1"
        }

        let requests = try await serverTask.value
        XCTAssertEqual(requests.map(\.tag), ["setDestination", "move", "moveTo"])
        XCTAssertEqual(requests[0].attributes["destination"], "tile-2-4")
        XCTAssertEqual(requests[1].attributes["direction"], "S")
        XCTAssertEqual(requests[2].attributes["destination"], "europe-1")
        XCTAssertEqual(state.game?.units["ship"]?.destination, "europe-1")
        XCTAssertNil(state.errorMessage)
        await server.stop()
    }

    func testEuropeExitUsesTerrainAbilityUnlessTileOverridesIt() throws {
        let game = Game()
        let xml = Self.gameXML.replacingOccurrences(
            of: #"<tile-type id="model.tile.plains">"#,
            with: """
            <tile-type id="model.tile.plains">
              <ability id="model.ability.moveToEurope" value="true"/>
            """)
        try game.load(from: XMLDecoder.decode(xml))
        XCTAssertEqual(game.tiles["tile-0-0"]?.moveToEurope, true)
        let blocked = try Tile(id: "blocked", attributes: [
            "type": "model.tile.plains", "moveToEurope": "false",
        ], children: [], game: game)
        XCTAssertFalse(blocked.moveToEurope)
    }

    @MainActor
    func testDisembarkDistinguishesLandingHarborEuropeAndExhaustedPassenger() throws {
        let state = try makeState()
        let game = try XCTUnwrap(state.game)
        try game.applyPartial(XMLDecoder.decode("""
        <partial id="ship" location="tile-2-4"/>
        """))
        try game.applyPartial(XMLDecoder.decode("""
        <partial id="outside-worker" location="ship" state="sentry" movesLeft="3"/>
        """))
        state.gameUpdateID += 1
        state.selectUnit("outside-worker", onTile: "tile-2-4")
        XCTAssertEqual(state.selectedUnit?.state, .sentry, "Java uses lowercase unit states")
        XCTAssertTrue(state.canChooseMoveDestination)
        XCTAssertTrue(state.canMoveSelectedUnit(to: "tile-2-2"))
        XCTAssertTrue(state.canDisembarkSelectedUnit)
        state.disembarkSelectedUnit()
        XCTAssertTrue(state.isChoosingMoveDestination, "At sea the button must request a landing tile, not send disembark")
        XCTAssertEqual(state.selectedUnit?.location, "ship")
        state.cancelChoosingMoveDestination()
        try game.applyPartial(XMLDecoder.decode("""
        <partial id="outside-worker" movesLeft="0"/>
        """))
        state.gameUpdateID += 1
        XCTAssertFalse(state.canDisembarkSelectedUnit)
        XCTAssertFalse(state.canChooseMoveDestination)
        state.rightClickMapTile("tile-2-2")
        XCTAssertTrue(state.errorMessage?.contains("keine Bewegungspunkte") == true)
        XCTAssertTrue(state.selectedUnitDisembarkHint?.contains("nächsten Zug") == true)
        try game.applyPartial(XMLDecoder.decode("""
        <partial id="ship" location="tile-2-2"/>
        """))
        state.gameUpdateID += 1
        XCTAssertTrue(state.canDisembarkSelectedUnit, "Unloading in port needs no passenger moves")
        try game.applyPartial(XMLDecoder.decode("""
        <partial id="ship" location="europe-1"/>
        """))
        state.gameUpdateID += 1
        XCTAssertTrue(state.canDisembarkSelectedUnit, "Europe docks also accept exhausted sentries")
        try game.applyPartial(XMLDecoder.decode("""
        <partial id="ship" location="highSeas:1"/>
        """))
        state.gameUpdateID += 1
        XCTAssertFalse(state.canDisembarkSelectedUnit)
        XCTAssertFalse(state.canChooseMoveDestination)
        game.currentPlayerId = "player-2"
        try game.applyPartial(XMLDecoder.decode("""
        <partial id="ship" location="europe-1"/>
        """))
        state.gameUpdateID += 1
        XCTAssertFalse(state.canDisembarkSelectedUnit)
        state.selectUnit("field-worker", onTile: "tile-2-2")
        XCTAssertFalse(state.canChooseMoveDestination, "Workplace units must not become map-movable")
    }

    @MainActor
    func testCoastalLandingUsesPassengerMoveAndWaitsForServerConfirmation() async throws {
        let server = MockServer()
        let state = GameState()
        let xml = Self.gameXML.replacingOccurrences(of: "</game>", with: """
          <unit id="passenger" owner="player-1" unitType="model.unit.freeColonist"
                location="ship" movesLeft="3" state="sentry"/>
        </game>
        """).replacingOccurrences(of: #"id="ship" owner="player-1" unitType="model.unit.caravel" location="tile-2-2""#,
                                  with: #"id="ship" owner="player-1" unitType="model.unit.caravel" location="tile-2-4""#)
            .replacingOccurrences(of: "\n", with: " ")
        let serverTask = Task {
            try await server.doHandshake(gameResponse: xml)
            var requests: [ParsedMessage] = []
            let responses = [
                #"<error message="Illegal move for: passenger type: MOVE_NO_MOVES"/>"#,
                #"<partial id="passenger" location="tile-2-2" state="active" movesLeft="0"/>"#,
            ]
            for response in responses {
                let question = try XMLDecoder.decode(await server.nextLine())
                XCTAssertEqual(question.tag, "question")
                requests.append(try XCTUnwrap(question.children.first))
                let id = try XCTUnwrap(question.attributes["networkReplyId"])
                if requests.count == 2 {
                    try await Task.sleep(nanoseconds: 80_000_000)
                }
                await server.send("<reply networkReplyId=\"\(id)\">\(response)</reply>")
                await server.flush()
            }
            return requests
        }
        defer { state.disconnect(); serverTask.cancel(); Task { await server.stop() } }
        state.connect(host: "127.0.0.1", port: server.port)
        try await waitUntil { state.phase == .login }
        state.login(userName: "Alice", nationId: "model.nation.dutch")
        try await waitUntil { state.phase == .inGame && state.game != nil }
        state.selectUnit("passenger", onTile: "tile-2-4")
        state.rightClickMapTile("tile-2-2")
        try await waitUntil { state.errorMessage != nil && state.movingUnitId == nil }
        XCTAssertEqual(state.errorMessage, "Diese Einheit hat keine Bewegungspunkte mehr.")
        XCTAssertEqual(state.selectedUnit?.location, "ship", "A rejected landing must not be simulated locally")
        XCTAssertEqual(state.selectedUnit?.movesLeft, 3)
        try state.game?.applyPartial(XMLDecoder.decode("""
        <partial id="passenger" movesLeft="3"/>
        """))
        state.gameUpdateID += 1
        state.disembarkSelectedUnit()
        XCTAssertTrue(state.isChoosingMoveDestination)
        state.selectMapTile("tile-2-2")
        XCTAssertEqual(state.selectedUnit?.location, "ship", "Location must wait for the Java reply")
        try await waitUntil { state.movingUnitId == nil }
        XCTAssertNil(state.errorMessage)
        XCTAssertEqual(state.selectedUnit?.location, "tile-2-2")
        XCTAssertEqual(state.selectedUnit?.state, .active)
        XCTAssertEqual(state.selectedUnitTileId, "tile-2-2")
        XCTAssertEqual(state.game?.units["ship"]?.location, "tile-2-4")
        let requests = try await serverTask.value
        XCTAssertEqual(requests.map(\.tag), ["move", "move"])
        XCTAssertTrue(requests.allSatisfy { $0.attributes["unit"] == "passenger" && $0.attributes["direction"] == "N" })
        await server.stop()
    }

    @MainActor
    func testEuropeDisembarkWaitsForReplyAndSurfacesFailureWithZeroMoves() async throws {
        let server = MockServer()
        let state = GameState()
        let xml = Self.gameXML.replacingOccurrences(of: "</game>", with: """
          <unit id="passenger" owner="player-1" unitType="model.unit.freeColonist"
                location="ship" movesLeft="0" state="sentry"/>
        </game>
        """).replacingOccurrences(of: #"id="ship" owner="player-1" unitType="model.unit.caravel" location="tile-2-2""#,
                                  with: #"id="ship" owner="player-1" unitType="model.unit.caravel" location="europe-1""#)
            .replacingOccurrences(of: "\n", with: " ")
        let serverTask = Task {
            try await server.doHandshake(gameResponse: xml)
            var requests: [ParsedMessage] = []
            for response in [
                #"<error message="Test: Ausschiffen abgelehnt"/>"#,
                #"<partial id="passenger" location="europe-1" movesLeft="0"/>"#,
            ] {
                let question = try XMLDecoder.decode(await server.nextLine())
                XCTAssertEqual(question.tag, "question")
                let id = try XCTUnwrap(question.attributes["networkReplyId"])
                requests.append(try XCTUnwrap(question.children.first))
                await server.send("<reply networkReplyId=\"\(id)\">\(response)</reply>")
                await server.flush()
            }
            return requests
        }
        defer { state.disconnect(); serverTask.cancel(); Task { await server.stop() } }
        state.connect(host: "127.0.0.1", port: server.port)
        try await waitUntil { state.phase == .login }
        state.login(userName: "Alice", nationId: "model.nation.dutch")
        try await waitUntil { state.phase == .inGame && state.game != nil }
        state.selectUnit("passenger", onTile: nil)
        XCTAssertTrue(state.canDisembarkSelectedUnit)
        state.disembarkSelectedUnit()
        try await waitUntil { state.errorMessage != nil }
        XCTAssertTrue(state.errorMessage?.contains("Ausschiffen abgelehnt") == true)
        XCTAssertEqual(state.selectedUnit?.location, "ship")
        state.disembarkSelectedUnit()
        try await waitUntil { state.selectedUnit?.location == "europe-1" }
        XCTAssertNil(state.errorMessage)
        XCTAssertTrue(state.europeUnits.contains { $0.id == "passenger" })
        XCTAssertFalse(state.canDisembarkSelectedUnit)
        let requests = try await serverTask.value
        XCTAssertEqual(requests.map(\.tag), ["disembark", "disembark"])
        XCTAssertTrue(requests.allSatisfy { $0.attributes["unit"] == "passenger" })
        await server.stop()
    }

    @MainActor
    func testEuropeanTributeUsesArmedLandUnitAndAppliesPaymentReply() async throws {
        let server = MockServer()
        let state = GameState()
        let xml = Self.gameXML.replacingOccurrences(of: "</game>", with: """
          <colony id="foreign-colony" owner="player-2" tile="tile-2-0" name="Quebec"/>
          <colony id="not-adjacent" owner="player-2" tile="tile-3-1" name="Montreal"/>
        </game>
        """).replacingOccurrences(of: "\n", with: " ")
        let serverTask = Task {
            try await server.doHandshake(gameResponse: xml)
            let question = try XMLDecoder.decode(await server.nextLine())
            let id = try XCTUnwrap(question.attributes["networkReplyId"])
            let message = try XCTUnwrap(question.children.first)
            await server.send("""
            <reply networkReplyId="\(id)">
              <partial id="player-1" gold="100"/>
              <diplomacy ourId="outside-worker" otherId="foreign-colony">
                <diplomaticTrade id="" context="tribute" status="accept_trade" sender="player-1" recipient="player-2" version="1"/>
              </diplomacy>
            </reply>
            """.replacingOccurrences(of: "\n", with: " "))
            await server.flush()
            return message
        }
        defer { state.disconnect(); serverTask.cancel(); Task { await server.stop() } }
        state.connect(host: "127.0.0.1", port: server.port)
        try await waitUntil { state.phase == .login }
        state.login(userName: "Alice", nationId: "model.nation.dutch")
        try await waitUntil { state.phase == .inGame && state.game != nil }
        let game = try XCTUnwrap(state.game)
        state.selectUnit("outside-worker", onTile: "tile-2-2")
        XCTAssertTrue(state.diplomacyInitiationTargetsForSelectedUnit.isEmpty)
        try game.applyPartial(XMLDecoder.decode("""
        <partial id="outside-worker" role="model.role.soldier"/>
        """))
        state.gameUpdateID += 1
        XCTAssertEqual(state.diplomacyContextForSelectedUnit, "TRIBUTE")
        XCTAssertEqual(state.diplomacyInitiationTargetsForSelectedUnit.map(\.id), ["foreign-colony"])
        state.selectUnit("ship", onTile: "tile-2-2")
        XCTAssertTrue(state.diplomacyInitiationTargetsForSelectedUnit.isEmpty)
        state.selectUnit("outside-worker", onTile: "tile-2-2")
        game.currentPlayerId = "player-2"
        state.gameUpdateID += 1
        XCTAssertTrue(state.diplomacyInitiationTargetsForSelectedUnit.isEmpty)
        game.currentPlayerId = "player-1"
        try game.applyPartial(XMLDecoder.decode("""
        <partial id="outside-worker" movesLeft="0"/>
        """))
        state.gameUpdateID += 1
        XCTAssertTrue(state.diplomacyInitiationTargetsForSelectedUnit.isEmpty)
        try game.applyPartial(XMLDecoder.decode("""
        <partial id="outside-worker" movesLeft="3"/>
        """))
        state.gameUpdateID += 1
        state.beginDiplomacy(otherColonyId: "foreign-colony")
        XCTAssertEqual(state.pendingDiplomacy?.context, "TRIBUTE")
        XCTAssertFalse(state.pendingDiplomacyIsIncoming)
        XCTAssertEqual(state.pendingDiplomacyClauseKinds, [.gold, .stance, .incite])
        let drafts = state.pendingDiplomacyDrafts
        XCTAssertEqual(drafts.count, 2)
        XCTAssertEqual(drafts.last?.weGive, false)
        XCTAssertEqual(drafts.last?.goldAmount, 100)
        state.sendDiplomacyCounterProposal([DiplomaticClauseDraft(kind: .colony)])
        XCTAssertTrue(state.errorMessage?.contains("nicht verfügbar") == true)
        state.sendDiplomacyCounterProposal(drafts)
        try await waitUntil { state.statusMessage == "Diplomatie: Angebot angenommen." }
        XCTAssertEqual(state.localPlayer?.gold, 100)
        XCTAssertNil(state.pendingDiplomacy)
        let message = try await serverTask.value
        XCTAssertEqual(message.tag, "diplomacy")
        XCTAssertEqual(message.attributes["ourId"], "outside-worker")
        let trade = try XCTUnwrap(message.children.first)
        XCTAssertEqual(trade.attributes["context"], "TRIBUTE")
        let payment = try XCTUnwrap(trade.children.first { $0.tag == "goldTradeItem" })
        XCTAssertEqual(payment.attributes["source"], "player-2")
        XCTAssertEqual(payment.attributes["destination"], "player-1")
        XCTAssertEqual(payment.attributes["gold"], "100")
        await server.stop()
    }

    func testSharedServerErrorsPreserveSpecificReasonsAndUnknownDetails() throws {
        let cases = [
            ("Illegal move for: unit:1 type: MOVE_NO_MOVES", "Diese Einheit hat keine Bewegungspunkte mehr."),
            ("Not at a trade location: unit:5842", "Zum Warenhandel muss der Transporter in Europa oder einer geeigneten Siedlung sein."),
            ("Work location is not in colony colony:1", "Dieser Arbeitsplatz gehört nicht zur Kolonie."),
            ("Can not pay for tile: tile:1", "Für den Kauf dieses Feldes fehlt Gold."),
            ("Unit lacks ability to negotiate: [unit:1]", "Diese Einheit kann nicht diplomatisch verhandeln."),
            ("server.userNameInUse", "Dieser Spielername wird bereits verwendet."),
            ("It is not a valid colony", "Der Server hat die Aktion abgelehnt: It is not a valid colony"),
            ("Can not add ServerUnit unit:1", "Die Einheit kann an diesem Arbeitsplatz nicht eingesetzt werden."),
        ]
        for (raw, expected) in cases {
            XCTAssertEqual(ServerErrorMessage.userFacing(raw), expected)
            XCTAssertEqual(ServerErrorMessage.description(for: FreeColProtocolError.serverError(raw)), expected)
            XCTAssertEqual(ServerRejectMapper.userFacingMessage(for: ParsedMessage(
                tag: "error", attributes: ["message": raw], children: []
            )), expected)
        }
        let template = try XMLDecoder.decode("""
        <error message=""><stringTemplate id="server.notAllReady"/></error>
        """)
        XCTAssertEqual(ServerRejectMapper.userFacingMessage(for: template), "Nicht alle Spieler sind bereit.")
        XCTAssertEqual(ServerErrorMessage.userFacing("server.notAllReady"), "Nicht alle Spieler sind bereit.")
        XCTAssertTrue(ServerErrorMessage.description(for: FreeColProtocolError.timeout).contains("Spielstand prüfen"))
    }

    func testEmptyServerErrorUsesStringTemplateInQuestionReply() async throws {
        let server = MockServer()
        let connection = Connection(host: "127.0.0.1", port: server.port)
        let serverTask = Task {
            let question = try XMLDecoder.decode(await server.nextLine())
            let id = try XCTUnwrap(question.attributes["networkReplyId"])
            await server.send("""
            <reply networkReplyId="\(id)"><error message=""><stringTemplate id="server.notAllReady"/></error></reply>
            """)
            await server.flush()
        }
        defer { serverTask.cancel(); Task { await connection.disconnect(); await server.stop() } }
        try await connection.connect()
        do {
            _ = try await connection.ask(message: ParsedMessage(tag: "launch", attributes: [:], children: []), timeout: 3)
            XCTFail("Server rejection must not appear successful")
        } catch FreeColProtocolError.serverError(let raw) {
            XCTAssertEqual(raw, "server.notAllReady")
            XCTAssertEqual(ServerRejectMapper.userFacingMessage(forServerMessage: raw), "Nicht alle Spieler sind bereit.")
        }
        try await serverTask.value
        await connection.disconnect()
        await server.stop()
    }

    @MainActor
    func testDiplomacyUsesPlayerClauseIdsAndPreservesCounterOffersInReplies() async throws {
        let server = MockServer()
        let state = GameState()
        let xml = Self.gameXML.replacingOccurrences(
            of: #"<unit-type id="model.unit.freeColonist" extends="colonist"/>"#,
            with: #"<unit-type id="model.unit.freeColonist" extends="colonist"><ability id="model.ability.negotiate"/></unit-type>"#
        ).replacingOccurrences(of: "</game>", with: """
        <colony id="foreign-colony" owner="player-2" tile="tile-3-2" name="Quebec"/></game>
        """).replacingOccurrences(of: "\n", with: " ")
        let serverTask = Task {
            try await server.doHandshake(gameResponse: xml)
            var requests: [ParsedMessage] = []
            for status in ["propose_trade", "accept_trade", "reject_trade"] {
                let question = try XMLDecoder.decode(await server.nextLine())
                XCTAssertEqual(question.tag, "question")
                let replyId = try XCTUnwrap(question.attributes["networkReplyId"])
                requests.append(try XCTUnwrap(question.children.first))
                await server.send("""
                <reply networkReplyId="\(replyId)"><diplomacy ourId="outside-worker" otherId="foreign-colony">
                  <diplomaticTrade id="" context="diplomatic" status="\(status)" sender="player-1" recipient="player-2" version="3">
                    <goldTradeItem id="model.tradeItem.gold" source="player-1" destination="player-2" gold="50"/>
                  </diplomaticTrade>
                </diplomacy></reply>
                """.replacingOccurrences(of: "\n", with: " "))
                await server.flush()
            }
            return requests
        }
        defer {
            state.disconnect()
            serverTask.cancel()
            Task { await server.stop() }
        }
        state.connect(host: "127.0.0.1", port: server.port)
        try await waitUntil { state.phase == .login }
        state.login(userName: "Alice", nationId: "model.nation.dutch")
        try await waitUntil { state.phase == .inGame && state.game != nil }
        state.selectUnit("outside-worker", onTile: "tile-2-2")
        state.beginDiplomacy(otherColonyId: "foreign-colony")
        XCTAssertEqual(state.pendingDiplomacy?.raw.attributes["id"], "")
        XCTAssertFalse(state.pendingDiplomacyIsIncoming)
        state.sendDiplomacyCounterProposal([DiplomaticClauseDraft(kind: .gold, goldAmount: 50)])
        try await waitUntil { state.pendingDiplomacy?.version == 3 }
        XCTAssertEqual(state.pendingDiplomacy?.context, "DIPLOMATIC")
        XCTAssertEqual(state.pendingDiplomacy?.status, "PROPOSE_TRADE")
        XCTAssertTrue(state.pendingDiplomacyIsIncoming, "Java keeps our sender ID even in a counteroffer")
        XCTAssertEqual(state.pendingDiplomacyDrafts.first?.weGive, true)
        state.acceptDiplomacy()
        try await waitUntil { state.statusMessage == "Diplomatie: Angebot angenommen." }
        XCTAssertNil(state.pendingDiplomacy)
        state.applySessionMessage(try XMLDecoder.decode("""
        <diplomacy ourId="outside-worker" otherId="foreign-colony">
          <diplomaticTrade id="" context="diplomatic" status="propose_trade"
                          sender="player-2" recipient="player-1" version="4"/>
        </diplomacy>
        """))
        state.rejectDiplomacy()
        try await waitUntil { state.statusMessage == "Diplomatie: Angebot abgelehnt." }
        XCTAssertNil(state.pendingDiplomacy)
        let requests = try await serverTask.value
        let offer = try XCTUnwrap(requests.first?.children.first)
        XCTAssertEqual(offer.attributes["id"], "")
        XCTAssertEqual(offer.attributes["version"], "0")
        XCTAssertEqual(offer.attributes["sender"], "player-1")
        XCTAssertEqual(offer.attributes["recipient"], "player-2")
        XCTAssertEqual(offer.children.first?.attributes["source"], "player-1")
        XCTAssertEqual(offer.children.first?.attributes["destination"], "player-2")
        XCTAssertEqual(requests[1].children.first?.attributes["status"], "ACCEPT_TRADE")
        XCTAssertEqual(requests.last?.children.first?.attributes["status"], "REJECT_TRADE")
        await server.stop()
    }

    @MainActor
    func testShipTravelStatusUpdatesAndEuropeArrivalIsLocalized() throws {
        let state = try makeState()
        let game = try XCTUnwrap(state.game)
        try game.applyPartial(XMLDecoder.decode("""
        <partial id="ship" location="highSeas:1" destination="europe-1" state="SAILING" workLeft="2"/>
        """))
        state.gameUpdateID += 1
        state.selectUnit("ship", onTile: nil)
        XCTAssertEqual(state.unitTravelStatus(try XCTUnwrap(state.selectedUnit)), "Überfahrt: Europa (2 Runden)")
        XCTAssertNil(state.selectedUnitTileId)
        XCTAssertFalse(state.unitsAwaitingOrders.contains { $0.id == "ship" })
        try game.applyPartial(XMLDecoder.decode("""
        <partial id="ship" destination="tile-2-2" workLeft="1"/>
        """))
        state.gameUpdateID += 1
        XCTAssertEqual(state.unitTravelStatus(try XCTUnwrap(state.selectedUnit)), "Überfahrt: Neue Welt (1 Runde)")
        try game.applyPartial(XMLDecoder.decode("""
        <partial id="ship" destination="" workLeft="-1"/>
        """))
        state.gameUpdateID += 1
        XCTAssertEqual(state.unitTravelStatus(try XCTUnwrap(state.selectedUnit)), "Überfahrt: Ziel unbekannt (0 Runden)")
        try game.applyPartial(XMLDecoder.decode("""
        <partial id="ship" location="europe-1" state="ACTIVE" name="Seestern"/>
        """))
        game.applyFeatureChange(try XMLDecoder.decode("""
        <featureChange id="player-1" add="true">
          <modelMessage id="model.unit.arriveInEurope" source="ship" messageType="UNIT_ADDED"/>
        </featureChange>
        """))
        state.gameUpdateID += 1
        state.syncAfterModelUpdate()
        XCTAssertEqual(state.unitTravelStatus(try XCTUnwrap(state.selectedUnit)), "In Europa")
        XCTAssertEqual(state.statusMessage, "Seestern ist in Europa eingetroffen.")
        XCTAssertTrue(state.europeCarrierUnits.contains { $0.id == "ship" })
        state.statusMessage = "Weiter"
        state.syncAfterModelUpdate()
        XCTAssertEqual(state.statusMessage, "Weiter", "Repeated UI updates must not repeat the arrival notice")
    }

    @MainActor
    func testColonyWorkersAreExcludedFromCyclingAndTurnWarnings() async throws {
        let server = MockServer()
        let state = GameState()
        let serverTask = Task {
            try await server.doHandshake(gameResponse: Self.gameXML.replacingOccurrences(of: "\n", with: " "))
            let question = try XMLDecoder.decode(await server.nextLine())
            XCTAssertEqual(question.tag, "question")
            XCTAssertEqual(question.children.first?.tag, "endTurn")
            let replyId = try XCTUnwrap(question.attributes["networkReplyId"])
            await server.send("""
            <reply networkReplyId="\(replyId)"><newTurn turn="2"/><setCurrentPlayer player="player-1"/></reply>
            """)
            await server.flush()
        }
        defer {
            state.disconnect()
            serverTask.cancel()
            Task { await server.stop() }
        }
        state.connect(host: "127.0.0.1", port: server.port)
        try await waitUntil { state.phase == .login }
        state.login(userName: "Alice", nationId: "model.nation.dutch")
        try await waitUntil { state.phase == .inGame && state.game != nil }
        let game = try XCTUnwrap(state.game)
        try game.applyUpdate(XMLDecoder.decode("""
        <update>
          <unit id="colony-worker" owner="player-1" unitType="model.unit.freeColonist"
                location="colony-1" state="ACTIVE" movesLeft="3"/>
        </update>
        """))
        for id in ["field-worker", "building-worker"] {
            try game.applyPartial(XMLDecoder.decode("<partial id=\"\(id)\" state=\"ACTIVE\" movesLeft=\"3\"/>"))
        }
        state.gameUpdateID += 1
        let workerIds: Set<String> = ["colony-worker", "field-worker", "building-worker"]
        XCTAssertTrue(workerIds.isSubset(of: Set(state.selectableLocalUnits.map(\.id))))
        XCTAssertTrue(workerIds.isDisjoint(with: state.cyclingLocalUnits.map(\.id)))
        XCTAssertTrue(workerIds.isDisjoint(with: state.unitsAwaitingOrders.map(\.id)))
        XCTAssertTrue(state.hasUnmovedLocalUnits)
        state.requestEndTurn()
        XCTAssertTrue(state.showEndTurnDialog, "Outdoor active units must still trigger the warning")
        state.dismissEndTurnDialog()
        state.selectUnit("field-worker", onTile: "tile-2-2")
        for _ in 0..<state.cyclingLocalUnits.count + 1 {
            state.selectNextUnit()
            XCTAssertFalse(workerIds.contains(state.selectedUnitId ?? ""))
            state.selectPreviousUnit()
            XCTAssertFalse(workerIds.contains(state.selectedUnitId ?? ""))
        }
        for id in ["outside-worker", "ship", "wagon"] {
            try game.applyPartial(XMLDecoder.decode("<partial id=\"\(id)\" movesLeft=\"0\"/>"))
        }
        state.gameUpdateID += 1
        XCTAssertTrue(state.unitsAwaitingOrders.isEmpty)
        XCTAssertFalse(state.hasUnmovedLocalUnits)
        XCTAssertTrue(state.canEndTurn)
        state.selectUnit("building-worker", onTile: "tile-2-2")
        XCTAssertEqual(state.selectedColonyWorkerUnitId, "building-worker")
        let turn = game.turn.number
        state.requestEndTurn()
        XCTAssertFalse(state.showEndTurnDialog)
        try await waitUntil { (state.game?.turn.number ?? turn) > turn && state.canEndTurn }
        try await serverTask.value

        try game.applyPartial(XMLDecoder.decode("""
        <partial id="field-worker" location="tile-2-2" state="ACTIVE" movesLeft="3"/>
        """))
        state.gameUpdateID += 1
        XCTAssertTrue(state.cyclingLocalUnits.contains { $0.id == "field-worker" })
        XCTAssertEqual(state.unitsAwaitingOrders.map(\.id), ["field-worker"])
        await server.stop()
    }

    @MainActor
    func testUnitsWithSavedDestinationsAreExcludedFromTurnWarning() throws {
        let state = try makeState()
        let game = try XCTUnwrap(state.game)
        try game.applyPartial(XMLDecoder.decode("""
        <partial id="outside-worker" destination="tile-3-2"/>
        """))
        state.gameUpdateID += 1

        XCTAssertFalse(state.unitsAwaitingOrders.contains { $0.id == "outside-worker" })
        XCTAssertEqual(Set(state.unitsAwaitingOrders.map(\.id)), ["ship", "wagon"])

        try game.applyPartial(XMLDecoder.decode("""
        <partial id="outside-worker" destination=""/>
        """))
        state.gameUpdateID += 1
        XCTAssertTrue(state.unitsAwaitingOrders.contains { $0.id == "outside-worker" })
    }

    @MainActor
    func testNestedColonyWorkersAndSelectionSurviveUpdates() throws {
        let state = try makeState()
        XCTAssertNotNil(state.game?.units["field-worker"])
        XCTAssertNotNil(state.game?.units["building-worker"])
        state.selectUnit("field-worker", onTile: "tile-2-2")
        state.syncAfterModelUpdate()
        XCTAssertEqual(state.selectedColonyWorkerUnitId, "field-worker")
        XCTAssertEqual(state.selectedTileId, "tile-2-2")
        XCTAssertEqual(state.game?.resolvedTileId(for: try XCTUnwrap(state.selectedUnit)), "tile-2-2")
        XCTAssertEqual(state.colonyPopulation(try XCTUnwrap(state.selectedColony)), 2)
        XCTAssertEqual(state.selectedColonyWorkTypeCandidates.map(\.id), ["model.goods.grain"])
        state.selectUnit("building-worker", onTile: "tile-2-2")
        XCTAssertEqual(state.selectedColonyWorkTypeCandidates.map(\.id), ["model.goods.hammers"])
        try state.game?.applyUpdate(XMLDecoder.decode("""
        <update><tile id="tile-2-2" x="2" y="2" type="model.tile.plains">
          <colony id="colony-1" name="Neuer Name" owner="player-1">
            <building id="building-1" buildingType="model.building.carpenterHouse">
              <unit id="building-worker" unitType="model.unit.freeColonist" owner="player-1"
                    location="building-1" movesLeft="0"/>
            </building>
            <colonyTile id="field-east" workTile="tile-3-2"/>
          </colony>
        </tile></update>
        """))
        state.gameUpdateID += 1
        state.syncAfterModelUpdate()
        XCTAssertEqual(state.selectedColony?.name, "Neuer Name")
        XCTAssertEqual(state.selectedColony?.tileId, "tile-2-2")
        XCTAssertEqual(state.selectedColony?.workTiles.first?.id, "field-east")
        XCTAssertEqual(state.selectedUnitId, "building-worker")
        XCTAssertEqual(state.selectedTileId, "tile-2-2")
        for _ in 0..<5 {
            state.selectMapTile("tile-2-2")
            XCTAssertTrue(["outside-worker", "ship", "wagon"].contains(state.selectedUnitId ?? ""))
        }
    }

    @MainActor
    func testColonyTerrainUsesRealWorkLocationsAndGuardsAssignments() throws {
        let state = try makeState()
        state.selectUnit("field-worker", onTile: "tile-2-2")
        XCTAssertEqual(state.selectedColonyTerrain.count, 9)
        let east = try XCTUnwrap(state.selectedColonyTerrain.first { $0.id == "tile-3-2" })
        XCTAssertEqual(east.workLocationId, "field-east")
        XCTAssertEqual(east.workers.map(\.id), ["field-worker"])
        XCTAssertNil(east.unavailableReason)
        XCTAssertEqual(east.offset.x, 1)
        XCTAssertEqual(east.offset.y, 0)
        XCTAssertNotNil(state.selectedColonyTerrain.first { $0.id == "tile-2-2" }?.unavailableReason)
        XCTAssertNotNil(state.colonyWorkLocationUnavailableReason("field-water"))
        state.assignSelectedColonyWorker(to: "field-center")
        XCTAssertNotNil(state.errorMessage)
        state.assignSelectedColonyWorker(to: "foreign-work-location")
        XCTAssertNotNil(state.errorMessage)
        state.selectUnit("ship", onTile: "tile-2-2")
        XCTAssertNotEqual(state.selectedColonyWorkerUnitId, "ship")
        state.selectUnit("wagon", onTile: "tile-2-2")
        XCTAssertFalse(state.canUnitWorkInColony(try XCTUnwrap(state.selectedUnit)))
    }

    @MainActor
    func testTerrainProductionUsesSelectedServerOutputsAndTracksUpdates() throws {
        let state = try makeState()
        state.selectUnit("field-worker", onTile: "tile-2-2")
        var east = try XCTUnwrap(state.selectedColonyTerrain.first { $0.id == "tile-3-2" })
        XCTAssertEqual(east.production.map(\.goodsType), ["model.goods.grain"])
        XCTAssertEqual(east.production.first?.baseAmount, 3)
        let center = try XCTUnwrap(state.selectedColonyTerrain.first { $0.id == "tile-2-2" })
        XCTAssertEqual(center.production.map(\.goodsType), ["model.goods.grain", "model.goods.hammers"])
        XCTAssertEqual(center.production.map(\.baseAmount), [2, 1])
        XCTAssertTrue(state.selectedColonyTerrain.first { $0.id == "tile-1-2" }?.production.isEmpty == true)
        try state.game?.applyUpdate(XMLDecoder.decode("""
        <update><colonyTile id="field-east" colony="colony-1">
          <production><output goods-type="model.goods.grain" value="5"/></production>
        </colonyTile></update>
        """))
        state.gameUpdateID += 1
        east = try XCTUnwrap(state.selectedColonyTerrain.first { $0.id == "tile-3-2" })
        XCTAssertEqual(east.production.first?.baseAmount, 5)
        XCTAssertEqual(state.selectedColony?.workTiles.first { $0.id == "field-east" }?.tileId, "tile-3-2")
        try state.game?.applyUpdate(XMLDecoder.decode("""
        <update><colonyTile id="field-east"><production/></colonyTile></update>
        """))
        state.gameUpdateID += 1
        east = try XCTUnwrap(state.selectedColonyTerrain.first { $0.id == "tile-3-2" })
        XCTAssertNil(east.production.first?.baseAmount, "An empty server production must not use a spec fallback")
    }

    @MainActor
    func testMissionaryEquipmentRequiresPersonAndSuitableLocation() throws {
        let state = try makeState()
        state.selectUnit("ship", onTile: "tile-2-2")
        XCTAssertFalse(state.canEquipSelectedUnitForRole)
        state.equipSelectedUnitForRole("model.role.missionary", count: 1)
        XCTAssertNotNil(state.errorMessage)
        state.selectUnit("wagon", onTile: "tile-2-2")
        XCTAssertFalse(state.canEquipSelectedUnitForRole)
        state.selectUnit("outside-worker", onTile: "tile-2-2")
        XCTAssertFalse(state.canEquipSelectedUnitForRole, "A colony without a church cannot equip missionaries")
        state.selectUnit("europe-worker", onTile: nil)
        XCTAssertTrue(state.canEquipSelectedUnitForRole)
        try state.game?.applyUpdate(XMLDecoder.decode("""
        <update><unit id="europe-worker" owner="player-1" unitType="model.unit.freeColonist"
                      role="model.role.missionary" location="europe-1"/></update>
        """))
        state.gameUpdateID += 1
        XCTAssertFalse(state.canEquipSelectedUnitForRole)
    }

    @MainActor
    func testPioneerEquipmentUsesToolsAndImprovementConsumesRoleEquipment() throws {
        let game = Game()
        try game.load(from: XMLDecoder.decode("""
        <game id="pioneering" clientUserName="Alice" currentPlayer="player-1">
          <freecol-specification>
            <unit-type id="model.unit.freeColonist">
              <ability id="model.ability.person" value="true"/>
              <ability id="model.ability.canBeEquipped" value="true"/>
            </unit-type>
            <goods-type id="model.goods.tools">
              <market initial-amount="1000" initial-price="2" price-difference="1"/>
            </goods-type>
            <role id="model.role.pioneer" maximum-count="5">
              <required-goods id="model.goods.tools" value="20"/>
              <required-ability id="model.ability.canBeEquipped" value="true"/>
            </role>
            <tile-improvement-type id="model.improvement.road"
                                   required-role="model.role.pioneer" expended-amount="1"/>
          </freecol-specification>
          <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="5000">
            <europe id="europe-1"/>
            <market owner="player-1">
              <marketData goods-type="model.goods.tools" amount="150" initialPrice="2"/>
            </market>
          </player>
          <map id="map-1" width="1" height="1">
            <tile id="tile-0" x="0" y="0" type="model.tile.plains" owner="player-1"/>
          </map>
          <colony id="colony-1" name="Boston" owner="player-1" tile="tile-0">
            <goodsContainer><storedGoods><goods type="model.goods.tools" amount="19"/></storedGoods></goodsContainer>
          </colony>
          <unit id="europe-worker" owner="player-1" unitType="model.unit.freeColonist" location="europe-1"/>
          <unit id="colony-worker" owner="player-1" unitType="model.unit.freeColonist"
                location="tile-0" movesLeft="3"/>
        </game>
        """))

        let state = GameState()
        state.phase = .inGame
        state.installGame(game)

        state.selectUnit("europe-worker", onTile: nil)
        XCTAssertTrue(state.canEquipSelectedUnitAsPioneer,
                      "Europe can buy the 20 tools required for a pioneer")
        XCTAssertEqual(state.pioneerToolsPerRoleCount, 20)

        state.selectUnit("colony-worker", onTile: "tile-0")
        XCTAssertFalse(state.canEquipSelectedUnitAsPioneer,
                       "A colony needs 20 stored tools to equip a pioneer")
        try game.applyUpdate(XMLDecoder.decode("""
        <update><colony id="colony-1" name="Boston" owner="player-1" tile="tile-0">
          <goodsContainer><storedGoods><goods type="model.goods.tools" amount="40"/></storedGoods></goodsContainer>
        </colony></update>
        """))
        state.gameUpdateID += 1
        XCTAssertTrue(state.canEquipSelectedUnitAsPioneer)

        try game.applyPartial(XMLDecoder.decode("""
        <partial id="colony-worker" role="model.role.pioneer" roleCount="1"/>
        """))
        state.gameUpdateID += 1
        XCTAssertEqual(state.selectedUnitImprovementCandidates.map(\.id), ["model.improvement.road"])
        XCTAssertEqual(state.selectedUnitImprovementToolCost(for: "model.improvement.road"), 20)

        // The Java server reports tool use by lowering roleCount when work finishes.
        try game.applyPartial(XMLDecoder.decode("""
        <partial id="colony-worker" role="model.role.default" roleCount="0"/>
        """))
        state.gameUpdateID += 1
        XCTAssertTrue(state.selectedUnitImprovementCandidates.isEmpty)
    }

    @MainActor
    func testEquippingPioneerSendsRoleAndAppliesServerEquipmentUpdate() async throws {
        let server = MockServer()
        let state = GameState()
        let serverTask = Task {
            try await server.doHandshake(gameResponse: Self.gameXML.replacingOccurrences(of: "\n", with: " "))
            let question = try XMLDecoder.decode(await server.nextLine())
            let action = try XCTUnwrap(question.children.first)
            XCTAssertEqual(action.tag, "equipForRole")
            XCTAssertEqual(action.attributes["unit"], "europe-worker")
            XCTAssertEqual(action.attributes["role"], "model.role.pioneer")
            XCTAssertEqual(action.attributes["count"], "1")
            let replyId = try XCTUnwrap(question.attributes["networkReplyId"])
            await server.send("<reply networkReplyId=\"\(replyId)\"><partial id=\"europe-worker\" role=\"model.role.pioneer\" roleCount=\"1\"/></reply>")
            await server.flush()
        }
        defer { state.disconnect(); serverTask.cancel(); Task { await server.stop() } }
        state.connect(host: "127.0.0.1", port: server.port)
        try await waitUntil { state.phase == .login }
        state.login(userName: "Alice", nationId: "model.nation.dutch")
        try await waitUntil { state.phase == .inGame && state.game != nil }

        state.selectUnit("europe-worker", onTile: nil)
        XCTAssertTrue(state.canEquipSelectedUnitAsPioneer)
        state.equipSelectedUnitForRole("model.role.pioneer", count: 1)
        try await waitUntil { state.game?.units["europe-worker"]?.role == "model.role.pioneer" }
        XCTAssertEqual(state.game?.units["europe-worker"]?.roleCount, 1)
        XCTAssertNil(state.errorMessage)
        try await serverTask.value
        await server.stop()
    }

    @MainActor
    func testImprovementsRequireAnOutdoorEquippedWorker() throws {
        let state = try makeState()
        for id in ["ship", "wagon", "field-worker", "building-worker", "outside-worker"] {
            state.selectUnit(id, onTile: "tile-2-2")
            XCTAssertTrue(state.selectedUnitImprovementCandidates.isEmpty)
            XCTAssertFalse(state.canChangeSelectedUnitWorkImprovement)
        }
        try state.game?.applyPartial(XMLDecoder.decode("""
        <partial id="outside-worker" role="model.role.pioneer" roleCount="1"/>
        """))
        state.gameUpdateID += 1
        XCTAssertEqual(state.selectedUnitImprovementCandidates.map(\.id), ["model.improvement.road"])
        XCTAssertTrue(state.canChangeSelectedUnitWorkImprovement)
        state.changeSelectedUnitWorkImprovement("model.improvement.unknown")
        XCTAssertNotNil(state.errorMessage)
    }

    @MainActor
    func testRemoteColonyActionsUseQuestionsApplyRepliesAndSurfaceErrors() async throws {
        let server = MockServer()
        let state = GameState()
        let serverTask = Task {
            try await server.doHandshake(gameResponse: Self.gameXML.replacingOccurrences(of: "\n", with: " "))
            let responses = [
                #"<partial id="colony-1" name="Neu-Boston"/>"#,
                #"<update><unit id="field-worker" owner="player-1" unitType="model.unit.freeColonist" location="field-west" workType="model.goods.grain" movesLeft="0"/></update>"#,
                #"<update><unit id="field-worker" owner="player-1" unitType="model.unit.freeColonist" location="building-1" movesLeft="0"/><unit id="building-worker" owner="player-1" unitType="model.unit.freeColonist" location="field-west" movesLeft="0"/></update>"#,
                #"<error message="Test: Umbenennen abgelehnt"/>"#,
            ]
            var requests: [ParsedMessage] = []
            for response in responses {
                let request = try XMLDecoder.decode(await server.nextLine())
                XCTAssertEqual(request.tag, "question", "Java actions must await a ChangeSet reply")
                let replyId = try XCTUnwrap(request.attributes["networkReplyId"])
                requests.append(try XCTUnwrap(request.children.first))
                await server.send("<reply networkReplyId=\"\(replyId)\">\(response)</reply>")
                await server.flush()
            }
            return requests
        }
        defer {
            state.disconnect()
            serverTask.cancel()
            Task { await server.stop() }
        }
        state.connect(host: "127.0.0.1", port: server.port)
        try await waitUntil { state.phase == .login }
        state.login(userName: "Alice", nationId: "model.nation.dutch")
        try await waitUntil { state.phase == .inGame && state.game != nil }
        state.selectUnit("field-worker", onTile: "tile-2-2")
        state.openColonyPanel()
        state.renameSelectedColony(to: "Neu-Boston")
        try await waitUntil { state.selectedColony?.name == "Neu-Boston" }
        state.assignSelectedColonyWorker(to: "field-west")
        try await waitUntil { state.game?.units["field-worker"]?.location == "field-west" }
        XCTAssertEqual(state.selectedColonyWorkerUnitId, "field-worker")
        XCTAssertTrue(state.showColonyPanel)
        state.selectUnit("building-worker", onTile: "tile-2-2")
        state.assignSelectedColonyWorker(to: "field-west")
        try await waitUntil { state.game?.units["building-worker"]?.location == "field-west" }
        state.renameSelectedColony(to: "Abgelehnt")
        try await waitUntil { state.errorMessage?.contains("abgelehnt") == true }
        XCTAssertEqual(state.selectedColony?.name, "Neu-Boston")
        let requests = try await serverTask.value
        XCTAssertEqual(requests.map(\.tag), ["rename", "work", "rearrangeColony", "rename"])
        XCTAssertEqual(requests[0].attributes, ["nameable": "colony-1", "name": "Neu-Boston"])
        XCTAssertEqual(requests[1].attributes, ["unit": "field-worker", "workLocation": "field-west"])
        XCTAssertEqual(requests[2].attributes["xLength"], "2")
        XCTAssertEqual(requests[2].attributes["x0work"], "model.goods.hammers")
        XCTAssertEqual(requests[2].attributes["x1work"], "model.goods.grain")
        XCTAssertEqual(requests[2].attributes["x1role"], "model.role.default")
        XCTAssertEqual(requests[2].attributes["x1count"], "0")
        await server.stop()
    }

    @MainActor
    func testRemoteRightClickWaitsForEachMovementReply() async throws {
        let server = MockServer()
        let state = GameState()
        let serverTask = Task {
            try await server.doHandshake(gameResponse: Self.gameXML.replacingOccurrences(of: "\n", with: " "))
            let responses = [
                #"<partial id="outside-worker" destination="tile-4-2"/>"#,
                #"<partial id="outside-worker" location="tile-3-2" movesLeft="2"/>"#,
                #"<partial id="outside-worker" location="tile-4-2" movesLeft="1"/>"#,
                #"<partial id="outside-worker" destination=""/>"#,
            ]
            var requests: [ParsedMessage] = []
            for response in responses {
                let question = try XMLDecoder.decode(await server.nextLine())
                XCTAssertEqual(question.tag, "question")
                let replyId = try XCTUnwrap(question.attributes["networkReplyId"])
                requests.append(try XCTUnwrap(question.children.first))
                await server.send("<reply networkReplyId=\"\(replyId)\">\(response)</reply>")
                await server.flush()
            }
            return requests
        }
        defer {
            state.disconnect()
            serverTask.cancel()
            Task { await server.stop() }
        }
        state.connect(host: "127.0.0.1", port: server.port)
        try await waitUntil { state.phase == .login }
        state.login(userName: "Alice", nationId: "model.nation.dutch")
        try await waitUntil { state.phase == .inGame && state.game != nil }
        state.selectUnit("outside-worker", onTile: "tile-2-2")
        state.rightClickMapTile("tile-4-2")
        try await waitUntil {
            state.movingUnitId == nil && state.selectedUnit?.location == "tile-4-2"
        }
        let requests = try await serverTask.value
        XCTAssertEqual(requests.map(\.tag), ["setDestination", "move", "move", "setDestination"])
        XCTAssertEqual(requests.filter { $0.tag == "move" }.map { $0.attributes["direction"] }, ["E", "E"])
        XCTAssertEqual(state.selectedUnit?.movesLeft, 1)
        XCTAssertNil(state.errorMessage)
        await server.stop()
    }

    @MainActor
    func testRightClickMovesMultipleStepsAndPreservesSelection() async throws {
        let state = GameState()
        defer { state.disconnect() }
        state.startLocal(userName: "Alice", nationId: "model.nation.dutch")
        try await waitUntil { state.phase == .inGame }
        let game = Game()
        try game.load(from: XMLDecoder.decode(Self.gameXML))
        state.installGame(game)
        state.selectUnit("outside-worker", onTile: "tile-2-2")
        state.rightClickMapTile("tile-4-2")
        XCTAssertNil(state.tileActionTileId)
        XCTAssertEqual(state.movingUnitId, "outside-worker")
        XCTAssertFalse(state.canEndTurn)
        try await waitUntil { state.movingUnitId == nil }
        XCTAssertNil(state.errorMessage)
        XCTAssertEqual(game.units["outside-worker"]?.location, "tile-4-2")
        XCTAssertEqual(game.units["outside-worker"]?.movesLeft, 1)
        XCTAssertEqual(state.selectedUnitId, "outside-worker")
        XCTAssertEqual(state.selectedTileId, "tile-4-2")
        state.rightClickMapTile("tile-0-2", showMenu: true)
        XCTAssertEqual(state.tileActionTileId, "tile-0-2")
        XCTAssertNil(state.movingUnitId)
        state.selectUnit("outside-worker", onTile: "tile-4-2")
        state.rightClickMapTile("tile-0-2")
        try await waitUntil { state.movingUnitId == nil }
        XCTAssertEqual(game.units["outside-worker"]?.movesLeft, 0)
        XCTAssertEqual(game.units["outside-worker"]?.destination, "tile-0-2")
        XCTAssertNotEqual(game.units["outside-worker"]?.location, "tile-0-2")
    }

    @MainActor
    func testRightClickRejectsWaterForeignTurnAndIndoorWorker() throws {
        let state = try makeState()
        state.selectUnit("outside-worker", onTile: "tile-2-2")
        state.rightClickMapTile("tile-2-4")
        XCTAssertNil(state.movingUnitId)
        XCTAssertNotNil(state.errorMessage)
        state.selectUnit("field-worker", onTile: "tile-2-2")
        state.rightClickMapTile("tile-3-2")
        XCTAssertNil(state.movingUnitId)
        state.selectUnit("outside-worker", onTile: "tile-2-2")
        state.game?.currentPlayerId = "player-2"
        state.gameUpdateID += 1
        state.rightClickMapTile("tile-3-2")
        XCTAssertNil(state.movingUnitId)
        XCTAssertNotNil(state.errorMessage)
    }

    @MainActor
    private func makeState() throws -> GameState {
        let game = Game()
        try game.load(from: XMLDecoder.decode(Self.gameXML))
        let state = GameState()
        state.phase = .inGame
        state.installGame(game)
        return state
    }

    @MainActor
    private func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(5)
        while !condition(), Date() < deadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        guard condition() else {
            XCTFail("Timed out waiting for the expected game state")
            throw FreeColProtocolError.timeout
        }
    }

    static var gameXML: String {
        let tiles = (0..<6).flatMap { y in
            (0..<5).map { x in
                let type = x == 2 && y == 4 ? "ocean" : "plains"
                return "<tile id=\"tile-\(x)-\(y)\" x=\"\(x)\" y=\"\(y)\" type=\"model.tile.\(type)\" owner=\"player-1\"/>"
            }
        }.joined()
        return """
        <game id="game-1" clientUserName="Alice" currentPlayer="player-1">
          <freecol-specification>
            <unit-type id="colonist"><ability id="model.ability.person"/><ability id="model.ability.canBeEquipped"/></unit-type>
            <unit-type id="model.unit.freeColonist" extends="colonist"/>
            <unit-type id="model.unit.caravel"><ability id="model.ability.navalUnit"/><ability id="model.ability.carryUnits"/></unit-type>
            <unit-type id="model.unit.wagonTrain"><ability id="model.ability.carryGoods"/></unit-type>
            <goods-type id="model.goods.grain"/><goods-type id="model.goods.hammers"/>
            <tile-improvement-type id="model.improvement.road" required-role="model.role.pioneer"/>
            <tile-type id="model.tile.plains">
              <production><output goods-type="model.goods.grain" value="3"/></production>
            </tile-type>
            <building-type id="model.building.carpenterHouse">
              <production><output goods-type="model.goods.hammers" value="3"/></production>
            </building-type>
          </freecol-specification>
          <player id="player-1" username="Alice" nationId="model.nation.dutch"><europe id="europe-1"/></player>
          <player id="player-2" username="Bob"/>
          <map id="map-1" width="5" height="6">\(tiles)</map>
          <colony id="colony-1" name="Boston" owner="player-1" tile="tile-2-2">
            <building id="building-1" buildingType="model.building.carpenterHouse">
              <unit id="building-worker" unitType="model.unit.freeColonist" owner="player-1" location="building-1" movesLeft="0"/>
            </building>
            <colonyTile id="field-east" workTile="tile-3-2">
              <unit id="field-worker" unitType="model.unit.freeColonist" owner="player-1" location="field-east"
                    workType="model.goods.grain" movesLeft="0"/>
            </colonyTile>
            <colonyTile id="field-west" workTile="tile-1-2"/>
            <colonyTile id="field-center" workTile="tile-2-2">
              <production unattended="true">
                <output goods-type="model.goods.grain" value="2"/>
                <output goods-type="model.goods.hammers" value="1"/>
              </production>
            </colonyTile>
            <colonyTile id="field-water" workTile="tile-2-4"/>
          </colony>
          <unit id="outside-worker" owner="player-1" unitType="model.unit.freeColonist" location="tile-2-2" movesLeft="3"/>
          <unit id="ship" owner="player-1" unitType="model.unit.caravel" location="tile-2-2" movesLeft="6"/>
          <unit id="wagon" owner="player-1" unitType="model.unit.wagonTrain" location="tile-2-2" movesLeft="3"/>
          <unit id="europe-worker" owner="player-1" unitType="model.unit.freeColonist" location="europe-1"/>
        </game>
        """
    }
}

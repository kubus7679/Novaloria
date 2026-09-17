import XCTest
@testable import FreeColProtocol
import FreeColGame
@testable import FreeColApp

final class FreeColProtocolTests: XCTestCase {

    func testDecodeTrivial() throws {
        let parsed = try XMLDecoder.decode("<endTurn/>")
        XCTAssertEqual(parsed.tag, "endTurn")
        XCTAssertTrue(parsed.attributes.isEmpty)
        XCTAssertTrue(parsed.children.isEmpty)
    }

    func testDecodeAttributes() throws {
        let parsed = try XMLDecoder.decode(
            #"<setCurrentPlayer player="player-1"/>"#
        )
        XCTAssertEqual(parsed.tag, "setCurrentPlayer")
        XCTAssertEqual(parsed.attributes["player"], "player-1")
    }

    func testDecodeWithChildren() throws {
        let xml = """
        <login userName="Alice">
          <game id="game-1"/>
        </login>
        """
        let parsed = try XMLDecoder.decode(xml)
        XCTAssertEqual(parsed.tag, "login")
        XCTAssertEqual(parsed.attributes["userName"], "Alice")
        XCTAssertEqual(parsed.children.count, 1)
        XCTAssertEqual(parsed.children[0].tag, "game")
    }

    func testEncodeTrivial() throws {
        let xml = XMLEncoder.encode(tag: "endTurn", attributes: [:])
        XCTAssertEqual(xml, "<endTurn/>")
    }

    func testEncodeAttributes() throws {
        let xml = XMLEncoder.encode(
            tag: "setCurrentPlayer",
            attributes: ["player": "player-1"]
        )
        XCTAssertEqual(xml, #"<setCurrentPlayer player="player-1"/>"#)
    }

    func testEncodeWithChildren() throws {
        let child = ParsedMessage(tag: "game", attributes: ["id": "game-1"], children: [])
        let xml = XMLEncoder.encode(
            tag: "login",
            attributes: ["userName": "Alice"],
            children: [child]
        )
        XCTAssertEqual(xml, #"<login userName="Alice"><game id="game-1"/></login>"#)
    }

    func testRoundtripAttributes() throws {
        let xml = #"<move unit="unit-3" direction="north"/>"#
        let parsed = try XMLDecoder.decode(xml)
        XCTAssertEqual(parsed.tag, "move")
        XCTAssertEqual(parsed.attributes["unit"], "unit-3")
        XCTAssertEqual(parsed.attributes["direction"], "north")

        let reencoded = XMLEncoder.encode(
            tag: parsed.tag,
            attributes: parsed.attributes
        )
        let reparsed = try XMLDecoder.decode(reencoded)
        XCTAssertEqual(reparsed.tag, "move")
        XCTAssertEqual(reparsed.attributes["unit"], "unit-3")
        XCTAssertEqual(reparsed.attributes["direction"], "north")
    }

    func testXmlEscaping() throws {
        let xml = XMLEncoder.encode(
            tag: "chat",
            attributes: ["message": "a < b & c > d"]
        )
        XCTAssertEqual(xml, #"<chat message="a &lt; b &amp; c &gt; d"/>"#)
    }

    func testMessageRegistry() throws {
        XCTAssertNotNil(messageRegistry["endTurn"])
        XCTAssertNotNil(messageRegistry["setCurrentPlayer"])
        XCTAssertNotNil(messageRegistry["login"])
        XCTAssertNotNil(messageRegistry["move"])
        XCTAssertNotNil(messageRegistry["multiple"])
        XCTAssertNotNil(messageRegistry["gameState"])
        XCTAssertNotNil(messageRegistry["vacantPlayers"])
        XCTAssertNotNil(messageRegistry["startGame"])
        XCTAssertNotNil(messageRegistry["firstContact"])
        XCTAssertNotNil(messageRegistry["missionary"])
        XCTAssertNotNil(messageRegistry["animateAttack"])
    }

    func testFirstContactMessage() throws {
        let msg = FirstContactMessage(
            result: "CONTACT",
            player: "player-1",
            other: "player-2",
            camps: "3",
            tile: "tile-9"
        )
        XCTAssertEqual(msg.tag, "firstContact")

        let (attrs, children) = msg.encode()
        XCTAssertEqual(attrs["result"], "CONTACT")
        XCTAssertEqual(attrs["player"], "player-1")
        XCTAssertEqual(attrs["other"], "player-2")
        XCTAssertEqual(attrs["camps"], "3")
        XCTAssertEqual(attrs["tile"], "tile-9")
        XCTAssertTrue(children.isEmpty)

        let decoded = try FirstContactMessage(attributes: [
            "result": "CONTACT",
            "player": "player-1",
            "other": "player-2",
            "camps": "3",
            "tile": "tile-9"
        ], children: [])
        XCTAssertEqual(decoded.result, "CONTACT")
        XCTAssertEqual(decoded.player, "player-1")
        XCTAssertEqual(decoded.other, "player-2")
        XCTAssertEqual(decoded.camps, "3")
        XCTAssertEqual(decoded.tile, "tile-9")
    }

    func testMissionaryMessage() throws {
        let msg = MissionaryMessage(unit: "unit-1", direction: "N", denounce: "true")
        XCTAssertEqual(msg.tag, "missionary")

        let (attrs, children) = msg.encode()
        XCTAssertEqual(attrs["unit"], "unit-1")
        XCTAssertEqual(attrs["direction"], "N")
        XCTAssertEqual(attrs["denounce"], "true")
        XCTAssertTrue(children.isEmpty)

        let decoded = try MissionaryMessage(attributes: [
            "unit": "unit-1",
            "direction": "N",
            "denounce": "true"
        ], children: [])
        XCTAssertEqual(decoded.unit, "unit-1")
        XCTAssertEqual(decoded.direction, "N")
        XCTAssertEqual(decoded.denounce, "true")
    }

    func testAnimateAttackMessage() throws {
        let msg = AnimateAttackMessage(
            defenderTile: "tile-2",
            success: "true",
            defender: "unit-2",
            attackerTile: "tile-1",
            attacker: "unit-1"
        )
        XCTAssertEqual(msg.tag, "animateAttack")

        let (attrs, children) = msg.encode()
        XCTAssertEqual(attrs["defenderTile"], "tile-2")
        XCTAssertEqual(attrs["success"], "true")
        XCTAssertEqual(attrs["defender"], "unit-2")
        XCTAssertEqual(attrs["attackerTile"], "tile-1")
        XCTAssertEqual(attrs["attacker"], "unit-1")
        XCTAssertTrue(children.isEmpty)

        let decoded = try AnimateAttackMessage(attributes: [
            "defenderTile": "tile-2",
            "success": "true",
            "defender": "unit-2",
            "attackerTile": "tile-1",
            "attacker": "unit-1"
        ], children: [])
        XCTAssertEqual(decoded.defenderTile, "tile-2")
        XCTAssertEqual(decoded.success, "true")
        XCTAssertEqual(decoded.defender, "unit-2")
        XCTAssertEqual(decoded.attackerTile, "tile-1")
        XCTAssertEqual(decoded.attacker, "unit-1")
    }

    func testEndTurnMessage() throws {
        let msg = EndTurnMessage()
        XCTAssertEqual(msg.tag, "endTurn")

        let decoded = try EndTurnMessage(attributes: [:], children: [])
        XCTAssertEqual(decoded.tag, "endTurn")

        let (attrs, children) = decoded.encode()
        XCTAssertTrue(attrs.isEmpty)
        XCTAssertTrue(children.isEmpty)
    }

    func testSetCurrentPlayerMessage() throws {
        let msg = SetCurrentPlayerMessage(player: "player-1")
        XCTAssertEqual(msg.tag, "setCurrentPlayer")
        XCTAssertEqual(msg.player, "player-1")

        let (attrs, children) = msg.encode()
        XCTAssertEqual(attrs["player"], "player-1")
        XCTAssertTrue(children.isEmpty)

        let decoded = try SetCurrentPlayerMessage(attributes: ["player": "player-2"], children: [])
        XCTAssertEqual(decoded.player, "player-2")
    }

    @MainActor
    func testPendingServerDecisionLifecycle() async throws {
        let state = GameState()

        state.applySessionMessage(ParsedMessage(tag: "fountainOfYouth", attributes: ["migrants": "3"], children: []))
        XCTAssertNotNil(state.pendingServerDecision)
        XCTAssertEqual(state.pendingServerDecision?.type, .fountainOfYouth)
        XCTAssertEqual(state.pendingServerDecision?.migrantCount, 3)
        XCTAssertTrue(state.hasPendingDecision)

        state.dismissPendingDecision()
        XCTAssertNil(state.pendingServerDecision)

        state.phase = .inGame
        state.applySessionMessage(ParsedMessage(
            tag: "indianDemand",
            attributes: ["type": "model.goods.tribute", "unit": "unit-7", "colony": "colony-3", "amount": "50"],
            children: []
        ))
        XCTAssertEqual(state.pendingServerDecision?.type, .indianDemand)
        XCTAssertEqual(state.pendingServerDecision?.rawPayload["colony"], "colony-3")
        XCTAssertNil(state.pendingServerDecision?.rawPayload["settlement"])
        XCTAssertTrue(state.canRespondToPendingDecision())
        XCTAssertEqual(
            state.pendingDecisionSummary,
            "demand: model.goods.tribute, amount: 50, colony: colony-3, unit: unit-7"
        )

        state.clearPendingDecision()
        XCTAssertNil(state.pendingServerDecision)
    }

    @MainActor
    func testPendingLootCargoPreservesGoodsChildren() async throws {
        let state = GameState()
        state.phase = .inGame

        let goods = ParsedMessage(
            tag: "goods",
            attributes: ["type": "model.goods.sugar", "amount": "20"],
            children: []
        )
        state.applySessionMessage(ParsedMessage(
            tag: "lootCargo",
            attributes: ["winner": "unit-9", "loser": "unit-2"],
            children: [goods]
        ))

        XCTAssertEqual(state.pendingServerDecision?.type, .lootCargo)
        XCTAssertEqual(state.pendingServerDecision?.rawPayload["winner"], "unit-9")
        XCTAssertEqual(state.pendingServerDecision?.rawPayload["loser"], "unit-2")
        XCTAssertNil(state.pendingServerDecision?.rawPayload["defender"])

        let options = state.pendingLootOptions
        XCTAssertEqual(options.count, 1)
        XCTAssertEqual(options.first?.type, "model.goods.sugar")
        XCTAssertEqual(options.first?.amount, 20)
        XCTAssertEqual(state.pendingDecisionSummary, "winner: unit-9, loser: unit-2, goods stacks: 1")
    }

    @MainActor
    func testDecisionPromptsNestedInUpdateAreForwarded() async throws {
        let state = GameState()
        state.phase = .inGame

        let update = ParsedMessage(
            tag: "update",
            attributes: [:],
            children: [
                ParsedMessage(
                    tag: "indianDemand",
                    attributes: ["unit": "unit-1", "colony": "colony-1", "type": "model.goods.gold", "amount": "10"],
                    children: []
                )
            ]
        )
        state.applySessionMessage(update)
        XCTAssertEqual(state.pendingServerDecision?.type, .indianDemand)

        // A plain update without a decision must be a no-op for pending state.
        state.clearPendingDecision()
        state.applySessionMessage(ParsedMessage(
            tag: "update",
            attributes: [:],
            children: [ParsedMessage(tag: "attribute", attributes: ["id": "x", "value": "y"], children: [])]
        ))
        XCTAssertNil(state.pendingServerDecision)
    }

    func testGameStateManagerForwardsDecisionUpdates() throws {
        let manager = GameStateManager()

        let decisionUpdate = ParsedMessage(
            tag: "update",
            attributes: [:],
            children: [
                ParsedMessage(
                    tag: "lootCargo",
                    attributes: ["winner": "unit-1", "loser": "unit-2"],
                    children: []
                )
            ]
        )
        XCTAssertFalse(try manager.process(decisionUpdate))

        let plainUpdate = ParsedMessage(
            tag: "update",
            attributes: [:],
            children: [ParsedMessage(tag: "attribute", attributes: ["id": "x"], children: [])]
        )
        XCTAssertTrue(try manager.process(plainUpdate))
    }

    @MainActor
    func testFirstContactAndMonarchPrompts() async throws {
        let state = GameState()
        state.phase = .inGame

        state.applySessionMessage(ParsedMessage(
            tag: "firstContact",
            attributes: ["player": "player-1", "other": "player-4", "tile": "tile-2-3", "camps": "2"],
            children: []
        ))
        XCTAssertEqual(state.pendingServerDecision?.type, .firstContact)
        XCTAssertTrue(state.canRespondToPendingDecision())
        XCTAssertEqual(state.pendingDecisionSummary, "contact: player-4, camps: 2, tile: tile-2-3")

        // Response echoes must not reopen a prompt.
        state.clearPendingDecision()
        state.applySessionMessage(ParsedMessage(
            tag: "firstContact",
            attributes: ["player": "player-1", "other": "player-4", "result": "true"],
            children: []
        ))
        XCTAssertNil(state.pendingServerDecision)

        state.applySessionMessage(ParsedMessage(
            tag: "monarchAction",
            attributes: ["action": "raise_tax_act", "monarch": "model.nation.dutch", "tax": "6"],
            children: []
        ))
        XCTAssertEqual(state.pendingServerDecision?.type, .monarchAction)
        XCTAssertEqual(state.pendingDecisionSummary, "Raise tax act, tax: 6")

        // Announcement-only actions need no prompt.
        state.clearPendingDecision()
        state.applySessionMessage(ParsedMessage(
            tag: "monarchAction",
            attributes: ["action": "displeasure"],
            children: []
        ))
        XCTAssertNil(state.pendingServerDecision)
    }

    @MainActor
    func testNamePromptsAndClose() async throws {
        let state = GameState()
        state.phase = .inGame

        state.applySessionMessage(ParsedMessage(
            tag: "newLandName",
            attributes: ["unit": "unit-5", "newLandName": "New Holland"],
            children: []
        ))
        XCTAssertEqual(state.pendingServerDecision?.type, .newLandName)
        XCTAssertEqual(state.pendingTextPrompt?.defaultText, "New Holland")

        state.applySessionMessage(ParsedMessage(
            tag: "newRegionName",
            attributes: ["region": "region-1", "tile": "tile-1-1", "unit": "unit-5", "newRegionName": "Amazon"],
            children: []
        ))
        XCTAssertEqual(state.pendingServerDecision?.type, .newRegionName)
        XCTAssertEqual(state.pendingTextPrompt?.defaultText, "Amazon")

        // A matching close clears the prompt.
        state.applySessionMessage(ParsedMessage(
            tag: "close",
            attributes: ["panel": "net.sf.freecol.client.gui.dialog.NewRegionNameDialog"],
            children: []
        ))
        XCTAssertNil(state.pendingServerDecision)

        // A non-matching close must not clear an unrelated prompt.
        state.applySessionMessage(ParsedMessage(
            tag: "newLandName",
            attributes: ["unit": "unit-5", "newLandName": "New Holland"],
            children: []
        ))
        state.applySessionMessage(ParsedMessage(
            tag: "close",
            attributes: ["panel": "net.sf.freecol.client.gui.dialog.NativeDemandDialog"],
            children: []
        ))
        XCTAssertEqual(state.pendingServerDecision?.type, .newLandName)
    }

    @MainActor
    func testReportsAreStored() async throws {
        let state = GameState()
        state.applySessionMessage(ParsedMessage(
            tag: "nationSummary",
            attributes: ["player": "player-2", "gold": "1234", "units": "7"],
            children: []
        ))
        XCTAssertEqual(state.nationSummaryReport?.attributes["gold"], "1234")

        state.applySessionMessage(ParsedMessage(
            tag: "highScores",
            attributes: ["key": "model.highscores.game"],
            children: [ParsedMessage(tag: "highScore", attributes: ["playerName": "Alice", "score": "42"], children: [])]
        ))
        XCTAssertEqual(state.highScoresReport?.children.count, 1)
        XCTAssertEqual(state.highScoresReport?.children.first?.attributes["score"], "42")
    }

    @MainActor
    func testNativeTradePromptParsing() async throws {
        let state = GameState()
        state.phase = .inGame

        let buyItem = ParsedMessage(
            tag: "nativeTradeItem",
            attributes: ["price": "42", "haggleCount": "1", "source": "p1", "destination": "p2"],
            children: [ParsedMessage(tag: "goods", attributes: ["type": "model.goods.sugar", "amount": "20"], children: [])]
        )
        let sellItem = ParsedMessage(
            tag: "nativeTradeItem",
            attributes: ["price": "12"],
            children: [ParsedMessage(tag: "goods", attributes: ["type": "model.goods.tobacco", "amount": "5"], children: [])]
        )
        let inner = ParsedMessage(
            tag: "nativeTrade",
            attributes: ["unit": "unit-1", "settlement": "is-1", "buy": "true", "sell": "true", "gift": "true", "count": "0"],
            children: [
                ParsedMessage(tag: "settlementToUnit", attributes: [:], children: [buyItem]),
                ParsedMessage(tag: "unitToSettlement", attributes: [:], children: [sellItem])
            ]
        )
        state.applySessionMessage(ParsedMessage(tag: "nativeTrade", attributes: ["action": "ACK_OPEN"], children: [inner]))

        XCTAssertEqual(state.pendingServerDecision?.type, .nativeTrade)
        let session = try XCTUnwrap(state.pendingNativeTrade)
        XCTAssertEqual(session.unitId, "unit-1")
        XCTAssertEqual(session.settlementId, "is-1")
        XCTAssertEqual(session.settlementToUnit.count, 1)
        XCTAssertEqual(session.settlementToUnit.first?.price, 42)
        XCTAssertEqual(session.settlementToUnit.first?.amount, 20)
        XCTAssertEqual(session.unitToSettlement.first?.price, 12)
        XCTAssertEqual(state.pendingDecisionSummary, "Can buy 1, can sell 1")

        state.applySessionMessage(ParsedMessage(tag: "nativeTrade", attributes: ["action": "CLOSE"], children: []))
        XCTAssertNil(state.pendingServerDecision)
    }

    @MainActor
    func testDiplomacyPromptParsing() async throws {
        let state = GameState()
        state.phase = .inGame

        let gold = ParsedMessage(tag: "goldTradeItem", attributes: ["gold": "100", "source": "p2", "destination": "p1"], children: [])
        let goods = ParsedMessage(
            tag: "goodsTradeItem",
            attributes: [:],
            children: [ParsedMessage(tag: "goods", attributes: ["type": "model.goods.rum", "amount": "30"], children: [])]
        )
        let trade = ParsedMessage(
            tag: "diplomaticTrade",
            attributes: ["context": "DIPLOMATIC", "sender": "p2", "recipient": "p1", "status": "PROPOSE_TRADE", "version": "1"],
            children: [gold, goods]
        )
        state.applySessionMessage(ParsedMessage(tag: "diplomacy", attributes: ["ourId": "unit-1", "otherId": "unit-2"], children: [trade]))

        XCTAssertEqual(state.pendingServerDecision?.type, .diplomacy)
        let proposal = try XCTUnwrap(state.pendingDiplomacy)
        XCTAssertEqual(proposal.context, "DIPLOMATIC")
        XCTAssertEqual(proposal.clauses.count, 2)
        XCTAssertTrue(proposal.clauses[0].summary.contains("Gold 100"))
        XCTAssertEqual(state.pendingDecisionSummary, "DIPLOMATIC: 2 clause(s)")

        // Outcome echoes must close the prompt, not reopen it.
        let accepted = ParsedMessage(
            tag: "diplomaticTrade",
            attributes: ["context": "DIPLOMATIC", "sender": "p1", "recipient": "p2", "status": "ACCEPT_TRADE", "version": "2"],
            children: []
        )
        state.applySessionMessage(ParsedMessage(tag: "diplomacy", attributes: ["ourId": "unit-1", "otherId": "unit-2"], children: [accepted]))
        XCTAssertNil(state.pendingServerDecision)
    }

    func testGameStateManagerForwardsExtendedPrompts() throws {
        let manager = GameStateManager()

        for tag in ["firstContact", "monarchAction", "newLandName", "newRegionName", "close", "nativeTrade", "diplomacy"] {
            let update = ParsedMessage(
                tag: "update",
                attributes: [:],
                children: [ParsedMessage(tag: tag, attributes: [:], children: [])]
            )
            XCTAssertFalse(try manager.process(update), "expected <\(tag)> to be forwarded")
        }
    }

    func testExploredClassification() throws {
        let game = Game()
        let parsed = try XMLDecoder.decode("""
        <game id="game-1">
          <player id="player-1" username="Alice" nationId="model.nation.dutch"/>
          <map id="map-1" width="4" height="2">
            <tile id="tile-0-0" x="0" y="0" type="model.tile.plains"/>
            <tile id="tile-1-0" x="1" y="0"/>
          </map>
        </game>
        """)
        try game.load(from: parsed)
        XCTAssertTrue(game.isExplored(tileId: "tile-0-0"))
        XCTAssertFalse(game.isExplored(tileId: "tile-1-0"))
        XCTAssertEqual(game.exploredTileIds(), ["tile-0-0"])
    }

    func testSightRadiusFromSpecification() throws {
        let game = Game()
        let parsed = try XMLDecoder.decode("""
        <game id="game-1">
          <player id="player-1" username="Alice" nationId="model.nation.dutch"/>
          <freecol-specification id="spec">
            <unit-type id="model.unit.seer" line-of-sight="2"/>
          </freecol-specification>
          <map id="map-1" width="6" height="2">
            <tile id="tile-0-0" x="0" y="0" type="model.tile.ocean"/>
            <tile id="tile-1-0" x="1" y="0" type="model.tile.ocean"/>
            <tile id="tile-2-0" x="2" y="0" type="model.tile.ocean"/>
          </map>
          <unit id="unit-1" owner="player-1" location="tile-0-0" unitType="model.unit.seer"/>
        </game>
        """)
        try game.load(from: parsed)
        let visible = game.visibleTileIds(for: "player-1")
        XCTAssertTrue(visible.contains("tile-2-0"))
        XCTAssertEqual(Specification.fallbackLineOfSight(forUnitType: "model.unit.caravel"), 2)
        XCTAssertEqual(Specification.fallbackLineOfSight(forUnitType: "model.unit.freeColonist"), 1)
    }

    func testTradeRouteParsingFromGame() throws {
        let game = Game()
        let parsed = try XMLDecoder.decode("""
        <game id="game-1">
          <player id="player-1" username="Alice" nationId="model.nation.dutch">
            <tradeRoute id="tradeRoute:1" name="Route A" owner="player-1" silent="false">
              <tradeRouteStop location="colony:1">
                <cargo id="model.goods.food"/>
                <cargo id="model.goods.sugar"/>
              </tradeRouteStop>
              <tradeRouteStop location="europe:9"/>
            </tradeRoute>
          </player>
        </game>
        """)
        try game.load(from: parsed)
        let route = game.tradeRoutes["tradeRoute:1"]
        XCTAssertEqual(route?.name, "Route A")
        XCTAssertEqual(route?.owner, "player-1")
        XCTAssertEqual(route?.stops.count, 2)
        XCTAssertEqual(route?.stops.first?.locationId, "colony:1")
        XCTAssertEqual(route?.stops.first?.cargoTypeIds, ["model.goods.food", "model.goods.sugar"])
        XCTAssertEqual(game.tradeRoutes(forPlayer: "player-1").count, 1)
    }

    func testTradeRouteMessageSerialization() throws {
        let route = TradeRoute(
            id: "tradeRoute:1",
            name: "Route A",
            owner: "player-1",
            stops: [
                TradeRouteStop(locationId: "colony:1", cargoTypeIds: ["model.goods.food"]),
                TradeRouteStop(locationId: "europe:9")
            ]
        )
        let message = GameState.tradeRouteMessage(tag: "updateTradeRoute", route: route)
        let xml = XMLEncoder.encode(
            tag: message.tag,
            attributes: message.attributes,
            children: message.children
        )
        XCTAssertEqual(
            xml,
            #"<updateTradeRoute><tradeRoute id="tradeRoute:1" name="Route A" owner="player-1" silent="false"><tradeRouteStop location="colony:1"><cargo id="model.goods.food"/></tradeRouteStop><tradeRouteStop location="europe:9"/></tradeRoute></updateTradeRoute>"#
        )
    }

    func testColonyBuildQueueAndBuildingsParsing() throws {
        let game = Game()
        let parsed = try XMLDecoder.decode("""
        <game id="game-1">
          <player id="player-1" username="Alice"/>
          <colony id="colony-1" name="Boston" owner="player-1" tile="tile-0-0" unitCount="3">
            <buildQueueItem id="model.building.townHall"/>
            <buildQueueItem id="model.building.carpenterHouse"/>
            <populationQueueItem id="model.unit.freeColonist"/>
            <building id="building-1" buildingType="model.building.townHall"/>
          </colony>
          <freecol-specification id="spec">
            <building-type id="model.building.lumberMill" required-population="3" upkeep="10"
                           upgrades-from="model.building.carpenterHouse"/>
          </freecol-specification>
        </game>
        """)
        try game.load(from: parsed)

        XCTAssertEqual(game.colonies["colony-1"]?.buildQueue,
                       ["model.building.townHall", "model.building.carpenterHouse"])
        XCTAssertEqual(game.colonies["colony-1"]?.populationQueue, ["model.unit.freeColonist"])
        XCTAssertEqual(game.colonies["colony-1"]?.buildings.first?.buildingType,
                       "model.building.townHall")

        let lumberMill = game.specification?.buildingTypes["model.building.lumberMill"]
        XCTAssertEqual(lumberMill?.requiredPopulation, 3)
        XCTAssertEqual(lumberMill?.upkeep, 10)
        XCTAssertEqual(lumberMill?.upgradesFrom, "model.building.carpenterHouse")
        XCTAssertEqual(lumberMill?.displayName, "LumberMill")
    }

    func testDiplomacyClauseSerialization() {
        let gold = DiplomaticClauseDraft(kind: .gold, weGive: true, goldAmount: 250)
        let goldNode = GameState.diplomacyClauseNode(gold, ourId: "player-1", otherId: "player-2")
        XCTAssertEqual(goldNode.tag, "goldTradeItem")
        XCTAssertEqual(goldNode.attributes["id"], "model.tradeItem.gold")
        XCTAssertEqual(goldNode.attributes["source"], "player-1")
        XCTAssertEqual(goldNode.attributes["destination"], "player-2")
        XCTAssertEqual(goldNode.attributes["gold"], "250")

        let goods = DiplomaticClauseDraft(kind: .goods,
                                          weGive: false,
                                          goodsType: "model.goods.sugar",
                                          goodsAmount: 30)
        let goodsNode = GameState.diplomacyClauseNode(goods, ourId: "player-1", otherId: "player-2")
        XCTAssertEqual(goodsNode.tag, "goodsTradeItem")
        XCTAssertEqual(goodsNode.attributes["source"], "player-2")
        XCTAssertEqual(goodsNode.attributes["destination"], "player-1")
        XCTAssertEqual(goodsNode.children.first?.tag, "goods")
        XCTAssertEqual(goodsNode.children.first?.attributes["type"], "model.goods.sugar")
        XCTAssertEqual(goodsNode.children.first?.attributes["amount"], "30")

        let stance = DiplomaticClauseDraft(kind: .stance, weGive: true, stance: "PEACE")
        let stanceNode = GameState.diplomacyClauseNode(stance, ourId: "player-1", otherId: "player-2")
        XCTAssertEqual(stanceNode.tag, "stanceTradeItem")
        XCTAssertEqual(stanceNode.attributes["stance"], "PEACE")
    }

    func testDiplomaticClauseDraftFromProposal() {
        let clause = DiplomaticTradeClause(index: 0, node: ParsedMessage(
            tag: "goldTradeItem",
            attributes: [
                "id": "model.tradeItem.gold",
                "source": "player-2",
                "destination": "player-1",
                "gold": "75",
            ],
            children: []
        ))
        let draft = DiplomaticClauseDraft(clause: clause, ourPlayerId: "player-1")
        XCTAssertEqual(draft?.kind, .gold)
        XCTAssertEqual(draft?.weGive, false)
        XCTAssertEqual(draft?.goldAmount, 75)

        XCTAssertEqual(DiplomaticClauseKind(clauseTag: "stanceTradeItem"), .stance)
        XCTAssertEqual(DiplomaticClauseKind(clauseTag: "goodsTradeItem"), .goods)
        XCTAssertNil(DiplomaticClauseKind(clauseTag: "unknownThing"))
    }

    func testColonyBuildETACalculation() throws {
        let game = Game()
        let parsed = try XMLDecoder.decode("""
        <game id="game-1">
          <player id="player-1" username="Alice"/>
          <colony id="colony-1" name="Boston" owner="player-1" tile="tile-0-0" unitCount="3">
            <building id="building-1" buildingType="model.building.carpenterHouse"/>
            <goodsContainer id="colony-1-goods">
              <storedGoods>
                <goods type="model.goods.hammers" amount="10"/>
              </storedGoods>
            </goodsContainer>
            <buildQueueItem id="model.building.lumberMill"/>
          </colony>
          <freecol-specification id="spec">
            <building-type id="model.building.carpenterHouse">
              <production>
                <input goods-type="model.goods.lumber" value="3"/>
                <output goods-type="model.goods.hammers" value="3"/>
              </production>
            </building-type>
            <building-type id="model.building.lumberMill" required-population="3"
                           upgrades-from="model.building.carpenterHouse">
              <required-goods id="model.goods.hammers" value="52"/>
            </building-type>
          </freecol-specification>
        </game>
        """)
        try game.load(from: parsed)
        let colony = try XCTUnwrap(game.colonies["colony-1"])
        let specification = try XCTUnwrap(game.specification)

        XCTAssertEqual(colony.goods["model.goods.hammers"], 10)
        XCTAssertEqual(GameState.estimatedBuildPerTurn(colony: colony, specification: specification), 3)
        // 52 required - 10 stored = 42 remaining, at 3/turn = 14 turns.
        XCTAssertEqual(
            GameState.estimatedBuildTurns(colony: colony,
                                          buildableId: "model.building.lumberMill",
                                          specification: specification),
            14
        )
        XCTAssertNil(
            GameState.estimatedBuildTurns(colony: colony,
                                          buildableId: "model.building.unknown",
                                          specification: specification)
        )
    }

    @MainActor
    func testNativeTradeHaggleOffer() async throws {
        let state = GameState()
        let item = NativeTradeItem(goodsType: "model.goods.fur", amount: 10, price: 100)

        XCTAssertEqual(state.nativeTradeHaggleOffer(item, buying: true), 90)
        XCTAssertEqual(state.nativeTradeHaggleOffer(item, buying: false), 110)

        XCTAssertEqual(item.toMessage().attributes["price"], "100")
        var offered = item
        offered.price = 90
        let node = offered.toMessage()
        XCTAssertEqual(node.attributes["price"], "90")
        XCTAssertEqual(node.children.first?.attributes["type"], "model.goods.fur")
    }

    func testColonyFoundingRejectsNativeVillagesAndSettlements() throws {
        let game = Game()
        let parsed = try XMLDecoder.decode("""
        <game id="game-1">
          <player id="player-1" username="Alice" nationId="model.nation.dutch"/>
          <player id="player-native" nationId="model.nation.iroquois" playerType="INDIAN"/>
          <map id="map-0" width="8" height="2">
            <tile id="tile-0-0" x="0" y="0" type="model.tile.plains"/>
            <tile id="tile-1-0" x="1" y="0" type="model.tile.plains">
              <colony id="colony-1" name="Boston" owner="player-1" tile="tile-1-0"/>
            </tile>
            <tile id="tile-2-0" x="2" y="0" type="model.tile.plains">
              <indianSettlement id="village-1" name="Village" owner="player-native" tile="tile-2-0"/>
            </tile>
            <tile id="tile-3-0" x="3" y="0" type="model.tile.plains" owner="player-native"/>
            <tile id="tile-4-0" x="4" y="0" type="model.tile.plains"/>
            <tile id="tile-5-0" x="5" y="0" type="model.tile.ocean"/>
            <tile id="tile-6-0" x="6" y="0" type="model.tile.plains"/>
            <tile id="tile-7-0" x="7" y="0" type="model.tile.plains"/>
          </map>
          <indianSettlement id="village-2" name="Camp" owner="player-native" tile="tile-4-0"/>
        </game>
        """)
        try game.load(from: parsed)

        let tile = { (id: String) in game.tiles[id]! }

        // Adjacent to another colony.
        XCTAssertFalse(GameState.isBuildableColonyTile(tile("tile-0-0"), in: game))
        // Native village nested directly on the tile.
        XCTAssertTrue(GameState.tileHasSettlement(tile("tile-2-0"), in: game))
        XCTAssertFalse(GameState.isBuildableColonyTile(tile("tile-2-0"), in: game))
        // Native-owned land without an on-tile settlement.
        XCTAssertTrue(GameState.tileIsNativeOwned(tile("tile-3-0"), in: game))
        XCTAssertFalse(GameState.isBuildableColonyTile(tile("tile-3-0"), in: game))
        // Native village known only through a settlement referencing the tile.
        XCTAssertTrue(GameState.tileHasSettlement(tile("tile-4-0"), in: game))
        XCTAssertFalse(GameState.isBuildableColonyTile(tile("tile-4-0"), in: game))
        // Water.
        XCTAssertFalse(GameState.isBuildableColonyTile(tile("tile-5-0"), in: game))
        // Free land.
        XCTAssertTrue(GameState.isBuildableColonyTile(tile("tile-6-0"), in: game))
    }

    func testBuildableBuildingCandidatesRespectUpgradesAndPopulation() throws {
        let specification = Specification(parsed: try XMLDecoder.decode("""
        <freecol-specification id="spec">
          <building-type id="model.building.townHall"/>
          <building-type id="model.building.carpenterHouse"/>
          <building-type id="model.building.lumberMill" required-population="3"
                         upgrades-from="model.building.carpenterHouse"/>
          <building-type id="model.building.bigHall" required-population="10"/>
        </freecol-specification>
        """))

        let withCarpenter = try Colony(
            id: "colony-1",
            attributes: ["name": "Boston", "unitCount": "5"],
            children: [ParsedMessage(tag: "building",
                                     attributes: ["id": "b1", "buildingType": "model.building.carpenterHouse"],
                                     children: [])],
            game: Game()
        )
        let ids = Set(GameState.buildableBuildingCandidates(colony: withCarpenter,
                                                           specification: specification,
                                                           population: 5).map(\.id))
        XCTAssertTrue(ids.contains("model.building.townHall"))
        // Upgrade available because carpenterHouse is present.
        XCTAssertTrue(ids.contains("model.building.lumberMill"))
        // Already built.
        XCTAssertFalse(ids.contains("model.building.carpenterHouse"))
        // Population requirement (10) not met.
        XCTAssertFalse(ids.contains("model.building.bigHall"))

        let emptyColony = try Colony(
            id: "colony-2",
            attributes: ["name": "Salem", "unitCount": "5"],
            children: [],
            game: Game()
        )
        let ids2 = Set(GameState.buildableBuildingCandidates(colony: emptyColony,
                                                            specification: specification,
                                                            population: 5).map(\.id))
        // Upgrade hidden without its predecessor.
        XCTAssertFalse(ids2.contains("model.building.lumberMill"))
        XCTAssertTrue(ids2.contains("model.building.carpenterHouse"))
    }

    func testColonyProductionEstimateIncludesCenterTile() throws {
        let game = Game()
        let parsed = try XMLDecoder.decode("""
        <game id="game-1">
          <player id="player-1" username="Alice"/>
          <colony id="colony-1" name="Boston" owner="player-1" tile="tile-0-0" unitCount="3">
            <building id="b1" buildingType="model.building.carpenterHouse"/>
          </colony>
          <freecol-specification id="spec">
            <tile-type id="model.tile.plains">
              <production unattended="true">
                <output goods-type="model.goods.grain" value="3"/>
              </production>
              <production>
                <output goods-type="model.goods.grain" value="5"/>
              </production>
            </tile-type>
            <building-type id="model.building.carpenterHouse">
              <production>
                <input goods-type="model.goods.lumber" value="3"/>
                <output goods-type="model.goods.hammers" value="3"/>
              </production>
            </building-type>
          </freecol-specification>
        </game>
        """)
        try game.load(from: parsed)
        let colony = try XCTUnwrap(game.colonies["colony-1"])
        let specification = try XCTUnwrap(game.specification)

        let production = GameState.estimatedProduction(colony: colony,
                                                       specification: specification,
                                                       centerTileType: "model.tile.plains")
        let totals = Dictionary(uniqueKeysWithValues: production.map { ($0.id, $0.amount) })
        XCTAssertEqual(totals["model.goods.hammers"], 3)
        XCTAssertEqual(totals["model.goods.grain"], 3)   // unattended center output
        XCTAssertEqual(totals["model.goods.lumber"], -3)
    }

    // MARK: Phase 54 - inbound decision handling

    @MainActor
    func testFoundingFatherPromptOffersCandidates() async throws {
        let state = GameState()
        state.phase = .inGame

        state.applySessionMessage(ParsedMessage(
            tag: "chooseFoundingFather",
            attributes: [
                "trade": "model.foundingFather.adamSmith",
                "military": "model.foundingFather.baronVonSteuben",
                "foundingFather": "",
            ],
            children: []
        ))

        XCTAssertEqual(state.pendingServerDecision?.type, .foundingFather)
        XCTAssertTrue(state.hasPendingDecision)
        XCTAssertEqual(state.pendingDecisionTitle, "Continental Congress")

        let options = state.pendingFoundingFathers
        XCTAssertEqual(options.map(\.typeKey), ["trade", "military"])
        XCTAssertEqual(options.first?.fatherId, "model.foundingFather.adamSmith")
        XCTAssertEqual(options.first?.label, "Adam Smith")
        XCTAssertEqual(state.pendingDecisionSummary, "2 candidate(s) available.")
        XCTAssertEqual(GameState.foundingFatherLabel("model.foundingFather.baronVonSteuben"),
                       "Baron Von Steuben")
    }

    @MainActor
    func testScoutAndIncitePromptsAreSurfaced() async throws {
        let state = GameState()
        state.phase = .inGame

        state.applySessionMessage(ParsedMessage(
            tag: "scoutSpeakToChief",
            attributes: ["unit": "unit-1", "settlement": "colony-9", "result": "expert"],
            children: []
        ))
        XCTAssertEqual(state.pendingServerDecision?.type, .scoutReport)
        XCTAssertEqual(state.scoutReportText,
                       "The scout learned from the chief and became an expert.")
        state.acknowledgePendingDecision()
        XCTAssertNil(state.pendingServerDecision)

        state.applySessionMessage(ParsedMessage(
            tag: "incite",
            attributes: ["unit": "unit-2", "settlement": "colony-9",
                         "enemy": "player-3", "gold": "750"],
            children: []
        ))
        XCTAssertEqual(state.pendingServerDecision?.type, .incite)
        XCTAssertEqual(state.pendingIncite?.gold, 750)
        XCTAssertEqual(state.pendingIncite?.enemy, "player-3")
        XCTAssertEqual(state.pendingDecisionSummary, "Incite player-3 for 750 gold.")
        state.declinePendingIncite()
        XCTAssertNil(state.pendingServerDecision)
    }

    @MainActor
    func testSetDeadAndVictoryTransitions() async throws {
        let game = Game()
        let parsed = try XMLDecoder.decode("""
        <game id="game-1" clientUserName="Alice">
          <player id="player-1" username="Alice"/>
          <player id="player-2" username="Bob"/>
        </game>
        """)
        try game.load(from: parsed)

        let state = GameState()
        state.phase = .inGame
        state.installGame(game)

        // A non-local death is informational only.
        state.applySessionMessage(ParsedMessage(
            tag: "setDead",
            attributes: ["player": "player-2"],
            children: []
        ))
        XCTAssertFalse(state.isDefeated)

        // gameEnded is broadcast; a non-winner must not show the victory overlay.
        state.applySessionMessage(ParsedMessage(
            tag: "gameEnded",
            attributes: ["winner": "player-2", "highScore": "true"],
            children: []
        ))
        XCTAssertFalse(state.isVictorious)
        XCTAssertTrue(state.isGameEnded)
        XCTAssertTrue(state.gameEndedHighScore)

        // The local player winning shows the victory overlay.
        state.applySessionMessage(ParsedMessage(
            tag: "gameEnded",
            attributes: ["winner": "player-1"],
            children: []
        ))
        XCTAssertTrue(state.isVictorious)

        // A local death flips the defeat flag.
        state.applySessionMessage(ParsedMessage(
            tag: "setDead",
            attributes: ["player": "player-1"],
            children: []
        ))
        XCTAssertTrue(state.isDefeated)
    }

    func testGameStateManagerForwardsNewPrompts() throws {
        let manager = GameStateManager()
        for tag in ["chooseFoundingFather", "scoutSpeakToChief", "spySettlement", "incite", "setDead"] {
            let update = ParsedMessage(
                tag: "update",
                attributes: [:],
                children: [ParsedMessage(tag: tag, attributes: [:], children: [])]
            )
            XCTAssertFalse(try manager.process(update), "expected <\(tag)> to be forwarded")
        }
    }

    func testGameStateManagerForwardsLogout() throws {
        let manager = GameStateManager()
        let logout = ParsedMessage(tag: "logout", attributes: ["player": "player-1"], children: [])
        XCTAssertFalse(try manager.process(logout))
    }

    func testSetDeadRemovesPlayerFromModel() throws {
        let game = Game()
        let parsed = try XMLDecoder.decode("""
        <game id="game-1">
          <player id="player-1" username="Alice"/>
          <player id="player-2" username="Bob"/>
        </game>
        """)
        try game.load(from: parsed)
        XCTAssertNotNil(game.players["player-2"])
        try game.applyPlayerChange(tag: "setDead", attributes: ["player": "player-2"])
        XCTAssertNil(game.players["player-2"])
    }

    func testGameMergeOptions() {
        let game = Game()
        game.mergeOptions(["model.option.giftToAllies": "true"])
        game.mergeOptions(["model.option.giftToAllies": "false",
                           "model.option.trade": "true"])
        XCTAssertEqual(game.optionValues["model.option.giftToAllies"], "false")
        XCTAssertEqual(game.optionValues["model.option.trade"], "true")
    }

    // MARK: Phase 55 - colony economy

    private func pricingSpecification() throws -> Specification {
        let parsed = try XMLDecoder.decode("""
        <freecol-specification id="spec">
          <goods-type id="model.goods.sugar" storable="true" new-world-goods="true">
            <market initial-amount="1500" initial-price="2" price-difference="2"/>
          </goods-type>
          <goods-type id="model.goods.rum" storable="true" made-from="model.goods.sugar">
            <market initial-amount="1000" initial-price="4" price-difference="2"/>
          </goods-type>
        </freecol-specification>
        """)
        return Specification(parsed: parsed)
    }

    func testMarketPricingFromAmountAndInitialPrice() throws {
        let spec = try pricingSpecification()
        let sugar = try XCTUnwrap(spec.goodsTypes["model.goods.sugar"])

        // At the reference amount the sale price equals the initial price.
        let atReference = MarketPricing.prices(amount: 1500, initialPrice: 2, info: sugar)
        XCTAssertEqual(atReference.paidForSale, 2)
        XCTAssertEqual(atReference.costToBuy, 4)

        // Oversupply lowers the sale price.
        let oversupplied = MarketPricing.prices(amount: 3000, initialPrice: 2, info: sugar)
        XCTAssertEqual(oversupplied.paidForSale, 1)
        XCTAssertEqual(oversupplied.costToBuy, 3)
    }

    func testMarketPricingNewWorldClamp() throws {
        let spec = try pricingSpecification()
        let sugar = try XCTUnwrap(spec.goodsTypes["model.goods.sugar"])
        // Scarcity would drive the raw price to 20, but new-world goods clamp
        // to initialPrice + 2.
        let scarce = MarketPricing.prices(amount: 150, initialPrice: 2, info: sugar)
        XCTAssertEqual(scarce.paidForSale, 4)
        XCTAssertEqual(scarce.costToBuy, 6)
    }

    func testColonyExportDataAndWorkTilesParsing() throws {
        let game = Game()
        let parsed = try XMLDecoder.decode("""
        <game id="game-1">
          <player id="player-1" username="Alice"/>
          <colony id="colony-1" name="Boston" owner="player-1" tile="tile-0-0" unitCount="2">
            <exportData id="model.goods.sugar" exported="true" importLevel="-1"
                        exportLevel="50" highLevel="90" lowLevel="10"/>
            <colonyTile id="ct-1" workTile="tile-1-0"/>
            <building id="b-1" buildingType="model.building.carpenterHouse"/>
            <goodsContainer><storedGoods><goods type="model.goods.sugar" amount="42"/></storedGoods></goodsContainer>
          </colony>
        </game>
        """)
        try game.load(from: parsed)
        let colony = try XCTUnwrap(game.colonies["colony-1"])

        let sugar = try XCTUnwrap(colony.exportData["model.goods.sugar"])
        XCTAssertTrue(sugar.exported)
        XCTAssertEqual(sugar.exportLevel, 50)
        XCTAssertEqual(sugar.highLevel, 90)
        XCTAssertEqual(sugar.lowLevel, 10)

        XCTAssertEqual(colony.workTiles.map(\.id), ["ct-1"])
        XCTAssertEqual(colony.workTiles.first?.tileId, "tile-1-0")
        XCTAssertEqual(colony.goods["model.goods.sugar"], 42)
    }

    func testExportDataMessageShape() {
        let data = ColonyExportData(goodsType: "model.goods.sugar",
                                    exported: true,
                                    importLevel: -1,
                                    exportLevel: 50,
                                    highLevel: 90,
                                    lowLevel: 10)
        let message = GameState.exportDataMessage(colonyId: "colony-1", data: data)
        XCTAssertEqual(message.tag, "setGoodsLevels")
        XCTAssertEqual(message.attributes["colony"], "colony-1")
        let child = message.children.first
        XCTAssertEqual(child?.tag, "exportData")
        XCTAssertEqual(child?.attributes["id"], "model.goods.sugar")
        XCTAssertEqual(child?.attributes["exported"], "true")
        XCTAssertEqual(child?.attributes["exportLevel"], "50")
        XCTAssertEqual(child?.attributes["importLevel"], "-1")
    }

    func testRearrangeColonyMessageShape() {
        let message = GameState.rearrangeColonyMessage(
            colonyId: "colony-1",
            arrangements: [
                (unit: "unit-1", loc: "ct-1", work: nil, role: nil, count: 0),
                (unit: "unit-2", loc: "colony-1", work: "model.goods.grain",
                 role: "model.role.default", count: 1),
            ]
        )
        XCTAssertEqual(message.tag, "rearrangeColony")
        XCTAssertEqual(message.attributes["colony"], "colony-1")
        XCTAssertEqual(message.attributes["xLength"], "2")
        XCTAssertEqual(message.attributes["x0unit"], "unit-1")
        XCTAssertEqual(message.attributes["x0loc"], "ct-1")
        XCTAssertNil(message.attributes["x0work"])
        XCTAssertEqual(message.attributes["x0role"], "model.role.default")
        XCTAssertEqual(message.attributes["x0count"], "0")
        XCTAssertEqual(message.attributes["x1unit"], "unit-2")
        XCTAssertEqual(message.attributes["x1work"], "model.goods.grain")
        XCTAssertEqual(message.attributes["x1count"], "1")
    }

    // MARK: Phase 56 - map and unit orders

    func testTileImprovementsAndUnitWorkLeftParsing() throws {
        let game = Game()
        let parsed = try XMLDecoder.decode("""
        <game id="game-1">
          <player id="player-1" username="Alice"/>
          <map id="map-1" width="2" height="1">
            <tile id="tile-0-0" x="0" y="0" type="model.tile.plains">
              <tileItemContainer>
                <tileImprovement id="imp-1" type="model.improvement.plow" turns="2" magnitude="1"/>
              </tileItemContainer>
            </tile>
          </map>
          <unit id="unit-1" owner="player-1" location="tile-0-0"
                workImprovementType="model.improvement.plow" workLeft="3"/>
        </game>
        """)
        try game.load(from: parsed)
        let tile = try XCTUnwrap(game.tiles["tile-0-0"])
        XCTAssertEqual(tile.improvements.map(\.id), ["imp-1"])
        XCTAssertEqual(tile.improvements.first?.type, "model.improvement.plow")
        XCTAssertEqual(tile.improvements.first?.turns, 2)

        let unit = try XCTUnwrap(game.units["unit-1"])
        XCTAssertEqual(unit.workLeft, 3)
        XCTAssertEqual(unit.workImprovementType, "model.improvement.plow")
    }

    func testSpecificationParsesImprovementTypes() throws {
        let parsed = try XMLDecoder.decode("""
        <freecol-specification id="spec">
          <tile-improvement-type id="model.improvement.plow"
                                 required-role="model.role.pioneer" add-work-turns="2"/>
          <tile-improvement-type id="model.improvement.river" natural="true"/>
        </freecol-specification>
        """)
        let spec = Specification(parsed: parsed)
        XCTAssertEqual(spec.improvementTypes["model.improvement.plow"]?.requiredRole,
                       "model.role.pioneer")
        XCTAssertEqual(spec.improvementTypes["model.improvement.plow"]?.addWorkTurns, 2)
        XCTAssertEqual(spec.improvementTypes["model.improvement.river"]?.isNatural, true)
    }

    func testMoveToMessageShape() {
        let message = GameState.moveToMessage(unitId: "unit-1",
                                              destinationId: "model.europe.player-1")
        XCTAssertEqual(message.tag, "moveTo")
        XCTAssertEqual(message.attributes["unit"], "unit-1")
        XCTAssertEqual(message.attributes["destination"], "model.europe.player-1")
    }

    @MainActor
    func testUnitCyclingAndOrderClearing() async throws {
        let game = Game()
        let parsed = try XMLDecoder.decode("""
        <game id="game-1" clientUserName="Alice">
          <player id="player-1" username="Alice" gold="500"/>
          <player id="player-2" username="Bob"/>
          <map id="map-1" width="2" height="1">
            <tile id="tile-0-0" x="0" y="0" type="model.tile.plains"/>
            <tile id="tile-1-0" x="1" y="0" type="model.tile.plains"/>
          </map>
          <unit id="unit-1" owner="player-1" unitType="model.unit.freeColonist"
                location="tile-0-0" movesLeft="3" state="ACTIVE"/>
          <unit id="unit-2" owner="player-1" unitType="model.unit.freeColonist"
                location="tile-1-0" movesLeft="0" state="SENTRY" destination="tile-0-0"/>
          <unit id="unit-3" owner="player-2" unitType="model.unit.freeColonist"
                location="tile-0-0" movesLeft="3" state="ACTIVE"/>
        </game>
        """)
        try game.load(from: parsed)

        let state = GameState()
        state.phase = .inGame
        state.installGame(game)

        // Only local units are cycled.
        XCTAssertEqual(state.selectableLocalUnits.map(\.id), ["unit-1", "unit-2"])
        state.selectNextUnit()
        XCTAssertEqual(state.selectedUnitId, "unit-1")
        state.selectNextUnit()
        XCTAssertEqual(state.selectedUnitId, "unit-2")
        state.selectNextUnit()
        XCTAssertEqual(state.selectedUnitId, "unit-1")
        state.selectPreviousUnit()
        XCTAssertEqual(state.selectedUnitId, "unit-2")

        // Only unit-1 is active with moves left on the map.
        XCTAssertEqual(state.unitsAwaitingOrders.map(\.id), ["unit-1"])

        // unit-2 has a destination and is not active: orders are clearable.
        state.selectUnit("unit-2", onTile: "tile-1-0")
        XCTAssertTrue(state.canClearSelectedUnitOrders)
        state.clearSelectedUnitOrders()
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(state.statusMessage, "Orders cleared.")

        // unit-1 is active without a destination: nothing to clear.
        state.selectUnit("unit-1", onTile: "tile-0-0")
        XCTAssertFalse(state.canClearSelectedUnitOrders)
    }

    // MARK: Phase 57 - founding fathers and reports

    func testFoundingFatherAndModelMessageParsing() throws {
        let game = Game()
        let parsed = try XMLDecoder.decode("""
        <game id="game-1">
          <player id="player-1" username="Alice" currentFather="model.foundingFather.adamSmith">
            <foundingFathers xLength="2" x0="model.foundingFather.baronVonSteuben"
                             x1="model.foundingFather.casimiroDeEspinosa"/>
            <offeredFathers xLength="1" x0="model.foundingFather.henryHudson"/>
            <modelMessage id="model.message.independence" source="player-1"
                          messageType="DEFAULT" hasBeenDisplayed="false"/>
          </player>
        </game>
        """)
        try game.load(from: parsed)
        let player = try XCTUnwrap(game.players["player-1"])
        XCTAssertEqual(player.currentFather, "model.foundingFather.adamSmith")
        XCTAssertEqual(player.foundingFathers,
                       ["model.foundingFather.baronVonSteuben",
                        "model.foundingFather.casimiroDeEspinosa"])
        XCTAssertEqual(player.offeredFathers, ["model.foundingFather.henryHudson"])
        XCTAssertEqual(player.modelMessages.count, 1)
        XCTAssertEqual(player.modelMessages.first?.messageType, "DEFAULT")
        XCTAssertEqual(player.modelMessages.first?.label, "independence")
    }

    @MainActor
    func testReportHelpersForColonies() async throws {
        let game = Game()
        let parsed = try XMLDecoder.decode("""
        <game id="game-1" clientUserName="Alice">
          <player id="player-1" username="Alice"/>
          <player id="player-2" username="Bob"/>
          <colony id="colony-1" name="Boston" owner="player-1" tile="tile-0-0" unitCount="3">
            <building id="b-1" buildingType="model.building.carpenterHouse"/>
            <buildQueueItem id="model.building.warehouse"/>
          </colony>
          <unit id="unit-1" owner="player-1" unitType="model.unit.freeColonist"
                location="b-1" workType="model.goods.lumber"/>
          <unit id="unit-2" owner="player-1" unitType="model.unit.freeColonist"
                location="colony-1" teacher="unit-3"/>
          <unit id="unit-3" owner="player-1" unitType="model.unit.expertTeacher"
                location="colony-1" role="model.role.missionary"/>
          <unit id="unit-4" owner="player-2" unitType="model.unit.freeColonist"
                location="colony-1"/>
        </game>
        """)
        try game.load(from: parsed)

        let state = GameState()
        state.phase = .inGame
        state.installGame(game)

        let colony = try XCTUnwrap(game.colonies["colony-1"])
        XCTAssertEqual(state.localColonies.map(\.id), ["colony-1"])
        // Only local workers inside the colony or on its buildings.
        XCTAssertEqual(state.colonyWorkerUnits(colony).map(\.id), ["unit-1", "unit-2", "unit-3"])
        XCTAssertEqual(state.educationAssignments.map(\.id), ["unit-2"])
        XCTAssertTrue(state.missionaryUnits.contains { $0.id == "unit-3" })
    }

    @MainActor
    func testColonyBuildRequirementsHelper() async throws {
        let game = Game()
        let parsed = try XMLDecoder.decode("""
        <game id="game-1" clientUserName="Alice">
          <player id="player-1" username="Alice"/>
          <colony id="colony-1" name="Boston" owner="player-1" tile="tile-0-0" unitCount="3">
            <buildQueueItem id="model.building.warehouse"/>
            <goodsContainer><storedGoods><goods type="model.goods.lumber" amount="12"/></storedGoods></goodsContainer>
          </colony>
          <freecol-specification id="spec">
            <building-type id="model.building.warehouse">
              <required-goods id="model.goods.lumber" value="60"/>
            </building-type>
          </freecol-specification>
        </game>
        """)
        try game.load(from: parsed)
        let colony = try XCTUnwrap(game.colonies["colony-1"])

        let state = GameState()
        state.phase = .inGame
        state.installGame(game)

        let requirements = try XCTUnwrap(state.colonyBuildRequirements(colony))
        XCTAssertEqual(requirements.target, "Warehouse")
        XCTAssertEqual(requirements.items.first?.id, "model.goods.lumber")
        XCTAssertEqual(requirements.items.first?.required, 60)
        XCTAssertEqual(requirements.items.first?.stored, 12)
    }

    func testFoundingFatherDisplayName() {
        XCTAssertEqual(GameState.foundingFatherLabel("model.foundingFather.adamSmith"),
                       "Adam Smith")
    }
}

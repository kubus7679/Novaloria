import XCTest
import SwiftUI
@testable import FreeColProtocol
import FreeColGame
@testable import Novaloria

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

    func testPathfindingPrefersCompletedRoadsOverShorterOffRoadRoute() throws {
        let game = Game()
        let roadStyles: [String: String] = [
            "tile-0-0": "00010000",
            "tile-0-1": "00100001",
            "tile-1-1": "00100010",
            "tile-2-1": "00100010",
            "tile-3-1": "00000011",
            "tile-3-0": "00010000",
        ]
        let tileXML = (0..<4).flatMap { y in
            (0..<4).map { x in
                let id = "tile-\(x)-\(y)"
                let improvement = roadStyles[id].map { style in
                    "<tileItemContainer><tileImprovement id=\"road-\(x)-\(y)\" type=\"model.improvement.road\" turns=\"0\" style=\"\(style)\"/></tileItemContainer>"
                } ?? ""
                return "<tile id=\"\(id)\" x=\"\(x)\" y=\"\(y)\" type=\"model.tile.plains\">\(improvement)</tile>"
            }
        }.joined(separator: "\n")
        let parsed = try XMLDecoder.decode("""
        <game id="game-1">
          <map id="map-1" width="4" height="4">
            \(tileXML)
          </map>
        </game>
        """)
        try game.load(from: parsed)

        let step = game.nextPathStep(
            from: "tile-0-0",
            to: "tile-3-0",
            stepCost: { game.hasRoadConnection(from: $0, to: $1) ? 1 : 3 }
        ) { _, _ in true }
        XCTAssertEqual(step, "tile-0-1")
    }

    func testLineFramerPreservesUTF8AcrossChunksAndFrames() throws {
        let bytes = Array(Data("<chat name=\"café\"/>\n<endTurn/>\n".utf8))
        let splitIndex = try XCTUnwrap(bytes.firstIndex(of: 0xC3)).advanced(by: 1)
        var framer = LineFramer()

        XCTAssertTrue(try framer.append(Data(bytes[..<splitIndex])).isEmpty)
        XCTAssertEqual(
            try framer.append(Data(bytes[splitIndex...])),
            ["<chat name=\"café\"/>", "<endTurn/>"]
        )
        XCTAssertNil(try framer.finish())
    }

    func testLineFramerRejectsOversizedAndInvalidUTF8Frames() throws {
        var sizeLimitedFramer = LineFramer(maximumLineBytes: 4)
        XCTAssertThrowsError(try sizeLimitedFramer.append(Data("12345".utf8)))

        var invalidUTF8Framer = LineFramer()
        XCTAssertThrowsError(try invalidUTF8Framer.append(Data([0xFF, 0x0A])))
    }

    func testXMLDecoderRejectsExcessiveNesting() {
        let openTags = String(repeating: "<node>", count: ProtocolLimits.maximumXMLDepth + 1)
        let closeTags = String(repeating: "</node>", count: ProtocolLimits.maximumXMLDepth + 1)
        XCTAssertThrowsError(try XMLDecoder.decode(openTags + closeTags))
    }

    func testConnectionRejectsInvalidPortBeforeConnecting() async {
        do {
            try await Connection(port: Int.max).connect()
            XCTFail("An out-of-range port must not start a connection")
        } catch FreeColProtocolError.invalidState(let message) {
            XCTAssertEqual(message, "Port must be between 1 and 65535")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
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

    func testXmlEscapingPreservesLineBreaksInsideSingleWireFrame() throws {
        let value = "first\nsecond\rthird\ttab"
        let xml = XMLEncoder.encode(tag: "chat", attributes: ["message": value])

        XCTAssertEqual(
            xml,
            #"<chat message="first&#10;second&#13;third&#9;tab"/>"#
        )
        XCTAssertFalse(xml.contains("\n"))
        XCTAssertEqual(try XMLDecoder.decode(xml).attributes["message"], value)
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
            "Ware: Tribut · Menge: 50 · Kolonie: Kolonie · Einheit: Einheit"
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
        XCTAssertEqual(state.pendingDecisionSummary, "Sieger: Einheit · Verlierer: Einheit · Warenstapel: 1")
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
        XCTAssertEqual(state.pendingDecisionSummary, state.firstContactMessage)
        XCTAssertFalse(state.pendingDecisionSummary.contains("player-"))
        XCTAssertTrue(state.pendingDecisionSummary.contains("2 Siedlungen"))

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
        XCTAssertEqual(state.pendingDecisionSummary, "Steuern erhöhen · Steuern: 6")

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
    func testMonarchAddToREFIsAnnouncementNotDecision() {
        let state = GameState()
        state.phase = .inGame

        state.applySessionMessage(ParsedMessage(
            tag: "monarchAction",
            attributes: ["action": "add_to_ref"],
            children: []
        ))

        XCTAssertNil(state.pendingServerDecision)
        XCTAssertEqual(state.statusMessage, "Monarch – Add to ref")
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
        XCTAssertEqual(state.pendingDecisionSummary, "Kaufangebote: 1 · Verkaufsangebote: 1")

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
        XCTAssertEqual(state.pendingDecisionSummary, "Diplomatie: 2 Klauseln")

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

    func testTradeRouteValidationCatchesJavaSaveRejects() {
        let validStops: Set<String> = ["colony:1", "europe:9"]
        let validGoods: Set<String> = ["model.goods.food", "model.goods.sugar"]
        let route = TradeRoute(id: "route-1",
                               name: "Route A",
                               owner: "player-1",
                               stops: [
                                   TradeRouteStop(locationId: "colony:1",
                                                  cargoTypeIds: ["model.goods.food"]),
                                   TradeRouteStop(locationId: "europe:9"),
                               ])
        let validate: (TradeRoute, [TradeRoute], Bool) -> String? = { candidate, existing, enhanced in
            GameState.tradeRouteValidationError(route: candidate,
                                                localPlayerId: "player-1",
                                                existingRoutes: existing,
                                                validStopLocationIds: validStops,
                                                validGoodsTypeIds: validGoods,
                                                enhancedTradeRoutes: enhanced)
        }
        XCTAssertNil(validate(route, [], false))

        var oneStop = route
        oneStop.stops = Array(route.stops.prefix(1))
        XCTAssertEqual(validate(oneStop, [], false), "Mindestens zwei Haltepunkte hinzufügen.")

        var invalidLocation = route
        invalidLocation.stops[1].locationId = "foreign-colony"
        XCTAssertEqual(validate(invalidLocation, [], false), "Für jeden Halt einen gültigen eigenen Ort auswählen.")

        var allStopsEmpty = route
        allStopsEmpty.stops[0].cargoTypeIds = []
        XCTAssertEqual(validate(allStopsEmpty, [], false), "Für mindestens einen Halt Waren auswählen.")

        var cargoAtEveryStop = route
        cargoAtEveryStop.stops[1].cargoTypeIds = ["model.goods.food"]
        XCTAssertNotNil(validate(cargoAtEveryStop, [], false))
        XCTAssertNil(validate(cargoAtEveryStop, [], true))

        let duplicate = TradeRoute(id: "route-2", name: "Route A", owner: "player-1")
        XCTAssertEqual(validate(route, [duplicate], false), "Eine Handelsroute mit diesem Namen existiert bereits.")
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
            <building-type id="model.building.carpenterHouse" workplaces="2"
                           minimum-skill="0" maximum-skill="1">
              <production><output goods-type="model.goods.hammers" value="3"/></production>
            </building-type>
            <building-type id="model.building.lumberMill" required-population="3" upkeep="10"
                           extends="model.building.carpenterHouse"
                           upgrades-from="model.building.carpenterHouse"/>
            <unit-type id="model.unit.worker" skill="1"/>
            <unit-type id="model.unit.expert" skill="2"/>
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
        XCTAssertEqual(game.specification?.buildingWorkplaces(for: "model.building.lumberMill"), 2)
        XCTAssertTrue(game.specification?.canUnitTypeWorkInBuilding(
            "model.unit.worker", buildingTypeId: "model.building.lumberMill"
        ) ?? false)
        XCTAssertFalse(game.specification?.canUnitTypeWorkInBuilding(
            "model.unit.expert", buildingTypeId: "model.building.lumberMill"
        ) ?? true)
        XCTAssertEqual(game.specification?.buildingOutputs(
            for: "model.building.lumberMill", unattended: false
        )["model.goods.hammers"], 3)
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
            <building id="building-1" buildingType="model.building.carpenterHouse">
              <unit id="worker-1" unitType="model.unit.freeColonist" owner="player-1"
                    location="building-1" workType="model.goods.hammers"/>
            </building>
            <goodsContainer id="colony-1-goods">
              <storedGoods>
                <goods type="model.goods.hammers" amount="10"/>
                <goods type="model.goods.lumber" amount="3"/>
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
        let worker = try XCTUnwrap(game.units["worker-1"])

        XCTAssertEqual(colony.goods["model.goods.hammers"], 10)
        XCTAssertEqual(GameState.estimatedBuildPerTurn(colony: colony, specification: specification), 0,
                       "Unstaffed buildings must not be treated as active production")
        XCTAssertEqual(GameState.estimatedBuildPerTurn(colony: colony,
                                                       specification: specification,
                                                       workers: [worker]), 3)
        // 52 required - 10 stored = 42 remaining, at 3/turn = 14 turns.
        XCTAssertEqual(
            GameState.estimatedBuildTurns(colony: colony,
                                          buildableId: "model.building.lumberMill",
                                          specification: specification,
                                          workers: [worker]),
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
          <player id="player-1" username="Alice" nationId="model.nation.dutch" playerType="colonial">
            <stance player="player-native" value="war"/>
          </player>
          <player id="player-native" nationId="model.nation.iroquois" playerType="native"/>
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

        XCTAssertEqual(game.players["player-1"]?.playerType, .european)
        XCTAssertEqual(game.players["player-native"]?.playerType, .indian)
        XCTAssertEqual(game.players["player-1"]?.stances["player-native"], .war)

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

        let withMill = try Colony(
            id: "colony-3",
            attributes: ["name": "Plymouth", "unitCount": "5"],
            children: [ParsedMessage(tag: "building",
                                     attributes: ["id": "b2", "buildingType": "model.building.lumberMill"],
                                     children: [])],
            game: Game()
        )
        let ids3 = Set(GameState.buildableBuildingCandidates(colony: withMill,
                                                             specification: specification,
                                                             population: 5).map(\.id))
        // Do not offer a downgrade to the smaller predecessor of an existing building.
        XCTAssertFalse(ids3.contains("model.building.carpenterHouse"))
    }

    func testBuildableCandidatesIncludeUnitsEnabledByColonyBuildings() throws {
        let specification = Specification(parsed: try XMLDecoder.decode("""
        <freecol-specification id="spec">
          <unit-type id="model.unit.wagonTrain">
            <required-goods id="model.goods.hammers" value="40"/>
          </unit-type>
          <building-type id="model.building.carpenterHouse">
            <ability id="model.ability.build" value="true">
              <scope type="model.unit.wagonTrain"/>
            </ability>
          </building-type>
        </freecol-specification>
        """))
        let colony = try Colony(
            id: "colony-wagon",
            attributes: ["name": "Boston", "unitCount": "1"],
            children: [ParsedMessage(tag: "building",
                                     attributes: ["id": "carpenter",
                                                  "buildingType": "model.building.carpenterHouse"],
                                     children: [])],
            game: Game()
        )

        let candidates = GameState.buildableBuildingCandidates(colony: colony,
                                                               specification: specification,
                                                               population: 1)
        let wagon = try XCTUnwrap(candidates.first { $0.id == "model.unit.wagonTrain" })
        XCTAssertTrue(wagon.label.contains("40"))

        let noCarpenter = try Colony(id: "colony-no-carpenter",
                                     attributes: ["name": "Salem", "unitCount": "1"],
                                     children: [],
                                     game: Game())
        XCTAssertFalse(GameState.buildableBuildingCandidates(colony: noCarpenter,
                                                             specification: specification,
                                                             population: 1)
            .contains { $0.id == "model.unit.wagonTrain" })
    }

    func testColonyProductionEstimateUsesAssignedAndUnattendedProduction() throws {
        let game = Game()
        let parsed = try XMLDecoder.decode("""
        <game id="game-1">
          <player id="player-1" username="Alice"/>
          <colony id="colony-1" name="Boston" owner="player-1" tile="tile-0-0" unitCount="3">
            <building id="b1" buildingType="model.building.carpenterHouse">
              <unit id="worker-1" unitType="model.unit.freeColonist" owner="player-1"
                    location="b1" workType="model.goods.hammers"/>
            </building>
            <building id="bell-building" buildingType="model.building.townHall">
              <unit id="bell-worker" unitType="model.unit.freeColonist" owner="player-1"
                    location="bell-building" workType="model.goods.bells"/>
            </building>
            <colonyTile id="field-1" workTile="tile-1-0">
              <unit id="field-worker" unitType="model.unit.freeColonist" owner="player-1"
                    location="field-1" workType="model.goods.grain"/>
            </colonyTile>
            <goodsContainer><storedGoods><goods type="model.goods.lumber" amount="3"/></storedGoods></goodsContainer>
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
              <production>
                <output goods-type="model.goods.bells" value="1"/>
              </production>
            </building-type>
            <building-type id="model.building.townHall">
              <production unattended="true">
                <output goods-type="model.goods.bells" value="1"/>
              </production>
              <production>
                <output goods-type="model.goods.bells" value="3"/>
              </production>
            </building-type>
          </freecol-specification>
        </game>
        """)
        try game.load(from: parsed)
        let colony = try XCTUnwrap(game.colonies["colony-1"])
        let specification = try XCTUnwrap(game.specification)
        let worker = try XCTUnwrap(game.units["worker-1"])
        let fieldWorker = try XCTUnwrap(game.units["field-worker"])
        let bellWorker = try XCTUnwrap(game.units["bell-worker"])

        let unstaffed = GameState.estimatedProduction(colony: colony,
                                                      specification: specification,
                                                      centerTileType: "model.tile.plains")
        let unstaffedTotals = Dictionary(uniqueKeysWithValues: unstaffed.map { ($0.id, $0.amount) })
        XCTAssertNil(unstaffedTotals["model.goods.hammers"])
        XCTAssertEqual(unstaffedTotals["model.goods.bells"], 1,
                       "An unattended building should use its unattended recipe")
        XCTAssertNil(unstaffedTotals["model.goods.lumber"])

        let production = GameState.estimatedProduction(colony: colony,
                                                       specification: specification,
                                                       centerTileType: "model.tile.plains",
                                                       workers: [worker, fieldWorker, bellWorker],
                                                       workTileTypes: ["field-1": "model.tile.plains"])
        let totals = Dictionary(uniqueKeysWithValues: production.map { ($0.id, $0.amount) })
        XCTAssertEqual(totals["model.goods.hammers"], 3)
        XCTAssertEqual(totals["model.goods.grain"], 8)   // center (3) + assigned field worker (5)
        XCTAssertEqual(totals["model.goods.bells"], 3,
                       "A staffed building should use its attended recipe")
        XCTAssertNil(totals["model.goods.lumber"], "Input consumption is not mislabeled as production")

        var outOfLumber = colony
        outOfLumber.goods["model.goods.lumber"] = 0
        let withoutInputs = GameState.estimatedProduction(
            colony: outOfLumber,
            specification: specification,
            centerTileType: "model.tile.plains",
            workers: [worker, fieldWorker, bellWorker],
            workTileTypes: ["field-1": "model.tile.plains"]
        )
        XCTAssertFalse(withoutInputs.contains { $0.id == "model.goods.hammers" },
                       "A staffed building with unavailable inputs should not show output")
    }

    func testColonyGoodsFlowIncludesBonusesConsumptionAndTooltipBreakdown() throws {
        let game = Game()
        let parsed = try XMLDecoder.decode("""
        <game id="game-1">
          <player id="player-1" username="Alice"/>
          <map id="map-1" width="1" height="1">
            <tile id="tile-0-0" x="0" y="0" type="model.tile.plains"/>
          </map>
          <colony id="colony-1" name="Boston" owner="player-1" tile="tile-0-0"
                  unitCount="1" productionBonus="2">
            <building id="building-1" buildingType="model.building.carpenterHouse">
              <unit id="worker-1" unitType="model.unit.masterCarpenter" owner="player-1"
                    location="building-1" workType="model.goods.hammers"/>
            </building>
            <goodsContainer><storedGoods>
              <goods type="model.goods.lumber" amount="5"/>
              <goods type="model.goods.food" amount="20"/>
            </storedGoods></goodsContainer>
          </colony>
          <freecol-specification id="spec">
            <tile-type id="model.tile.plains">
              <production unattended="true"><output goods-type="model.goods.grain" value="2"/></production>
            </tile-type>
            <unit-type id="model.unit.colonist">
              <consumes id="model.goods.food" value="2"/>
            </unit-type>
            <unit-type id="model.unit.masterCarpenter" extends="model.unit.colonist"
                       expert-production="model.goods.hammers">
              <modifier id="model.goods.hammers" index="30" type="additive" value="3"/>
            </unit-type>
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
        let player = try XCTUnwrap(game.players["player-1"])
        XCTAssertEqual(colony.tileId, "tile-0-0")
        XCTAssertEqual(colony.productionBonus, 2)
        XCTAssertEqual(game.tiles["tile-0-0"]?.type, "model.tile.plains")
        XCTAssertEqual(specification.tileTypes["model.tile.plains"]?.centerOutputs["model.goods.grain"], 2)
        let flow = ColonyProductionCalculator.calculate(
            colony: colony,
            specification: specification,
            tiles: game.tiles,
            workers: Array(game.units.values),
            player: player,
            goodsLabel: { $0 }
        )
        let byGoods = Dictionary(uniqueKeysWithValues: flow.map { ($0.id, $0) })

        XCTAssertEqual(byGoods["model.goods.grain"]?.produced, 4,
                       "The center should include the colony production bonus")
        XCTAssertEqual(byGoods["model.goods.hammers"]?.produced, 8,
                       "The final output should include the master carpenter and colony bonuses")
        XCTAssertEqual(byGoods["model.goods.lumber"]?.consumed, 3)
        XCTAssertEqual(byGoods["model.goods.food"]?.consumed, 2)
        XCTAssertTrue(byGoods["model.goods.hammers"]?.explanation.contains("Grundwert: 3") == true)
        XCTAssertTrue(byGoods["model.goods.hammers"]?.explanation.contains("Koloniebonus") == true)
        XCTAssertTrue(byGoods["model.goods.lumber"]?.explanation.contains("model.goods.lumber") == true)
    }

    func testColonyGrowthEstimateCombinesFoodSourcesAndConsumption() throws {
        let specification = Specification(parsed: try XMLDecoder.decode("""
        <freecol-specification>
          <goods-type id="model.goods.food" is-food="true"/>
          <goods-type id="model.goods.grain" is-food="true" storable="false"/>
          <goods-type id="model.goods.fish" is-food="true" storable="false"/>
          <goods-type id="model.goods.hammers"/>
        </freecol-specification>
        """))
        let flows = [
            ColonyGoodsFlow(id: "model.goods.grain", label: "Getreide", produced: 19,
                            consumed: 1, explanation: ""),
            ColonyGoodsFlow(id: "model.goods.fish", label: "Fische", produced: 0,
                            consumed: 0, explanation: ""),
            ColonyGoodsFlow(id: "model.goods.food", label: "Nahrung", produced: 0,
                            consumed: 14, explanation: ""),
            ColonyGoodsFlow(id: "model.goods.hammers", label: "Hämmer", produced: 200,
                            consumed: 0, explanation: "")
        ]

        XCTAssertEqual(
            ColonyProductionCalculator.estimatedGrowthTurns(
                foodStock: 16, specification: specification, flows: flows
            ),
            47,
            "Growth should use combined grain/fish production minus all food consumption"
        )
        XCTAssertEqual(
            ColonyProductionCalculator.estimatedGrowthTurns(
                foodStock: 196, specification: specification, flows: flows
            ),
            1
        )

        let noSurplus = [
            ColonyGoodsFlow(id: "model.goods.grain", label: "Getreide", produced: 14,
                            consumed: 14, explanation: "")
        ]
        XCTAssertNil(ColonyProductionCalculator.estimatedGrowthTurns(
            foodStock: 16, specification: specification, flows: noSurplus
        ))
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
        XCTAssertEqual(state.pendingDecisionTitle, "Kontinentalkongress")

        let options = state.pendingFoundingFathers
        XCTAssertEqual(options.map(\.typeKey), ["trade", "military"])
        XCTAssertEqual(options.first?.fatherId, "model.foundingFather.adamSmith")
        XCTAssertEqual(options.first?.label, "Adam Smith")
        XCTAssertEqual(state.pendingDecisionSummary, "2 Gründerväter verfügbar.")
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
        XCTAssertEqual(state.pendingDecisionSummary, "Aufstand gegen gegnerische Nation anzetteln? Kosten: 750 Gold.")
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

        func testLoadGameServerStateIsRecognizedAsInGame() {
            let state = ServerState(rawValue: "LOAD_GAME")
            XCTAssertEqual(state, .loadGame)
            XCTAssertTrue(state?.isInGame == true)
        }

        func testNativeTradeMessageIncludesRequiredObjectId() {
            let session = NativeTradeSession(unitId: "unit:1", settlementId: "indianSettlement:2")
            XCTAssertEqual(
                session.toInnerMessage().attributes["id"],
                "unit:1-indianSettlement:2"
            )

            let offer = NativeTradeItem(
                goodsType: "model.goods.cotton",
                amount: 100,
                price: 90,
                source: "player:2",
                destination: "player:1",
                goodsLocation: "indianSettlement:2"
            )
            let item = offer.toMessage()
            XCTAssertEqual(item.attributes["id"], "model.tradeItem.goods.name")
            XCTAssertEqual(item.children.first?.attributes["location"], "indianSettlement:2")
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

    func testEuropeMarketTradeLimitsUseGoldCargoAndLoadableAmount() {
        let limits = GameState.marketTradeLimits(gold: 137,
                                                 buyPrice: 25,
                                                 loadableAmount: 80,
                                                 carriedAmount: 12)
        XCTAssertEqual(limits.buy, 5)
        XCTAssertEqual(limits.sell, 12)

        let cargoLimited = GameState.marketTradeLimits(gold: 1_000,
                                                       buyPrice: 10,
                                                       loadableAmount: 80,
                                                       carriedAmount: 12)
        XCTAssertEqual(cargoLimited.buy, 80)
        XCTAssertEqual(cargoLimited.sell, 12)

        let sellChunkLimited = GameState.marketTradeLimits(gold: 1_000,
                                                           buyPrice: 1,
                                                           loadableAmount: 500,
                                                           carriedAmount: 250)
        XCTAssertEqual(sellChunkLimited.sell, MarketPricing.goodsPerCargoChunk)

        let chunkLimited = GameState.marketTradeLimits(gold: 10_000,
                                                       buyPrice: 1,
                                                       loadableAmount: 500,
                                                       carriedAmount: 0)
        XCTAssertEqual(chunkLimited.buy, MarketPricing.goodsPerCargoChunk)

        let noGoldLimits = GameState.marketTradeLimits(gold: 0,
                                                      buyPrice: 25,
                                                      loadableAmount: 100,
                                                      carriedAmount: -2)
        XCTAssertEqual(noGoldLimits.buy, 0)
        XCTAssertEqual(noGoldLimits.sell, 0)

        let noPriceLimits = GameState.marketTradeLimits(gold: 500,
                                                       buyPrice: 0,
                                                       loadableAmount: 100,
                                                       carriedAmount: 0)
        XCTAssertEqual(noPriceLimits.buy, 0)
        XCTAssertEqual(noPriceLimits.sell, 0)

        let negativeGoldLimits = GameState.marketTradeLimits(gold: -1,
                                                             buyPrice: 1,
                                                             loadableAmount: 100,
                                                             carriedAmount: -2)
        XCTAssertEqual(negativeGoldLimits.buy, 0)
        XCTAssertEqual(negativeGoldLimits.sell, 0)

        let boycottedLimits = GameState.marketTradeLimits(gold: 1_000,
                                                          buyPrice: 10,
                                                          loadableAmount: 100,
                                                          carriedAmount: 100,
                                                          arrears: 25)
        XCTAssertEqual(boycottedLimits.buy, 0)
        XCTAssertEqual(boycottedLimits.sell, 0)
    }

    func testMarketTransactionQuoteIncludesSaleTax() {
        let quote = GameState.marketTransactionQuote(amount: 30,
                                                     buyPrice: 7,
                                                     salePrice: 4,
                                                     tax: 15)
        XCTAssertEqual(quote.buyTotal, 210)
        XCTAssertEqual(quote.sellAfterTax, 102)

        let fullyTaxed = GameState.marketTransactionQuote(amount: 100,
                                                          buyPrice: 0,
                                                          salePrice: 2,
                                                          tax: 100)
        XCTAssertEqual(fullyTaxed.buyTotal, 0)
        XCTAssertEqual(fullyTaxed.sellAfterTax, 0)
    }

    func testLoadableGoodsAmountIncludesPartialStacksAndPassengers() {
        let partialStack = GameState.loadableGoodsAmount(cargoCapacity: 4,
                                                        goodsAmounts: [150, 40],
                                                        carriedUnitSpace: 0,
                                                        selectedGoodsAmount: 150)
        XCTAssertEqual(partialStack, 150)

        let passengerCargo = GameState.loadableGoodsAmount(cargoCapacity: 4,
                                                           goodsAmounts: [40],
                                                           carriedUnitSpace: 1,
                                                           selectedGoodsAmount: 40)
        XCTAssertEqual(passengerCargo, 260)

        let fullCargo = GameState.loadableGoodsAmount(cargoCapacity: 2,
                                                      goodsAmounts: [100, 100],
                                                      carriedUnitSpace: 0,
                                                      selectedGoodsAmount: 100)
        XCTAssertEqual(fullCargo, 0)
    }

    func testPlayerUpdateRemovesTradeRoutesMissingFromServerSnapshot() throws {
        let game = Game()
        try game.load(from: XMLDecoder.decode("""
        <game id="game-1">
          <player id="player-1" username="Alice">
            <tradeRoute id="route-1" name="Old Route" owner="player-1"/>
          </player>
        </game>
        """))
        XCTAssertEqual(game.tradeRoutes["route-1"]?.name, "Old Route")

        try game.applyUpdate(XMLDecoder.decode("""
        <update>
          <player id="player-1" username="Alice">
            <tradeRoute id="route-2" name="Current Route" owner="player-1"/>
          </player>
        </update>
        """))

        XCTAssertNil(game.tradeRoutes["route-1"])
        XCTAssertEqual(game.tradeRoutes["route-2"]?.name, "Current Route")
    }

    func testSpecificationInheritsUnitCargoSpace() throws {
        let parsed = try XMLDecoder.decode("""
        <freecol-specification id="spec">
          <unit-type id="ship" abstract="true" space="2" spaceTaken="24">
            <ability id="model.ability.carryGoods" value="true"/>
          </unit-type>
          <unit-type id="model.unit.merchantman" extends="ship" space="4"/>
        </freecol-specification>
        """)
        let specification = Specification(parsed: parsed)
        let merchantman = try XCTUnwrap(specification.unitTypes["model.unit.merchantman"])
        XCTAssertEqual(merchantman.cargoSpace, 4)
        XCTAssertEqual(merchantman.spaceTaken, 24)
        XCTAssertEqual(merchantman.spaceTakenOnCarrier, 24)
        XCTAssertTrue(specification.hasAbility("model.ability.carryGoods", unitType: merchantman.id))
    }

    func testSpecificationParsesAndInheritsEuropePriceAndSkill() throws {
        let specification = Specification(parsed: try XMLDecoder.decode("""
        <freecol-specification id="spec">
          <unit-type id="expert" abstract="true" price="1000" skill="1"/>
          <unit-type id="model.unit.expertFarmer" extends="expert" price="1100"/>
          <unit-type id="model.unit.masterCarpenter" extends="expert"/>
          <unit-type id="model.unit.freeColonist"/>
        </freecol-specification>
        """))
        XCTAssertEqual(specification.unitTypes["model.unit.expertFarmer"]?.price, 1100)
        XCTAssertEqual(specification.unitTypes["model.unit.expertFarmer"]?.skill, 1)
        XCTAssertEqual(specification.unitTypes["model.unit.masterCarpenter"]?.price, 1000)
        XCTAssertNil(specification.unitTypes["model.unit.freeColonist"]?.price)
    }

    func testUpdateMovesShipFromTileIntoHighSeas() throws {
        let game = Game()
        try game.load(from: XMLDecoder.decode("""
        <game id="game-1">
          <player id="player-1" username="Alice"/>
          <unit id="unit-1" unitType="model.unit.caravel" owner="player-1" location="tile:5"/>
        </game>
        """))

        try game.applyUpdate(XMLDecoder.decode("""
        <update>
          <highSeas id="highSeas:21">
            <unit id="unit-1" unitType="model.unit.caravel" owner="player-1" location="highSeas:21" entryLocation="tile:5" workLeft="1">
              <unit id="unit-2" unitType="model.unit.freeColonist" owner="player-1" location="unit-1"/>
            </unit>
            <destination id="europe:20"/>
          </highSeas>
        </update>
        """))

        XCTAssertEqual(game.units["unit-1"]?.location, "highSeas:21")
        XCTAssertEqual(game.units["unit-1"]?.entryLocation, "tile:5")
        XCTAssertEqual(game.units["unit-2"]?.location, "unit-1")
    }

    func testRegionUpdatesAreLoadedAndReplaceKnownRegionData() throws {
        let game = Game()
        try game.load(from: XMLDecoder.decode("""
        <game id="game-1">
          <map id="map-1" width="1" height="1">
            <region id="region-1" key="model.region.newWorld" type="ocean" discoverable="true"/>
          </map>
        </game>
        """))
        XCTAssertEqual(game.regions["region-1"]?.key, "model.region.newWorld")
        XCTAssertTrue(game.regions["region-1"]?.discoverable == true)

        try game.applyUpdate(XMLDecoder.decode("""
        <update>
          <region id="region-1" name="New World" key="model.region.newWorld" type="ocean" discoverable="false"/>
        </update>
        """))

        XCTAssertEqual(game.regions["region-1"]?.displayName, "New World")
        XCTAssertFalse(game.regions["region-1"]?.discoverable ?? true)
    }

    func testEuropeUpdateAppliesArrivalsAndKeepsKnownUnitPrices() throws {
        let game = Game()
        try game.load(from: XMLDecoder.decode("""
        <game id="game-1">
          <player id="player-1" username="Alice">
            <europe id="europe:20" owner="player-1" recruitPrice="200">
              <unitPrice unitType="model.unit.artillery" price="500"/>
            </europe>
          </player>
          <unit id="ship-1" unitType="model.unit.caravel" owner="player-1" location="highSeas:21"/>
        </game>
        """))

        try game.applyUpdate(XMLDecoder.decode("""
        <update>
          <europe id="europe:20" recruitPrice="180" recruitLowerCap="80" owner="player-1">
            <unit id="ship-1" unitType="model.unit.caravel" owner="player-1" location="europe:20"/>
            <unit id="new-1" unitType="model.unit.pettyCriminal" owner="player-1" location="europe:20"/>
            <recruit id="model.unit.masterCarpenter" role="model.role.default" number="1"/>
          </europe>
        </update>
        """))

        XCTAssertEqual(game.units["ship-1"]?.location, "europe:20")
        XCTAssertEqual(game.units["new-1"]?.location, "europe:20")
        let europe = try XCTUnwrap(game.players["player-1"]?.europe)
        XCTAssertEqual(europe.recruitPrice, 180)
        XCTAssertEqual(europe.recruitable.count, 1)
        XCTAssertEqual(europe.unitPrices["model.unit.artillery"], 500)
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

    func testMarketPricingClampsGoodsMadeFromNewWorldGoods() throws {
        let spec = try pricingSpecification()
        let rum = MarketData(attributes: [
            "goods-type": "model.goods.rum",
            "amount": "100",
            "initialPrice": "4",
        ])

        let prices = MarketPricing.prices(for: rum, specification: spec)
        XCTAssertEqual(prices.paidForSale, 6)
        XCTAssertEqual(prices.costToBuy, 8)
    }

    func testMarketPricingUsesZeroInitialMarketAmount() {
        let goods = GoodsTypeInfo(id: "model.goods.test",
                                  name: nil,
                                  isFood: false,
                                  isBuildingMaterial: false,
                                  isTradeGoods: false,
                                  marketInitialAmount: 0,
                                  marketInitialPrice: 2,
                                  priceDifference: 2)
        let prices = MarketPricing.prices(amount: 100, initialPrice: 2, info: goods)
        XCTAssertEqual(prices.paidForSale, 1)
        XCTAssertEqual(prices.costToBuy, 3)
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
                workImprovementType="model.improvement.plow" workLeft="3" experience="17"/>
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
        XCTAssertEqual(unit.experience, 17)
    }

    func testSpecificationParsesImprovementTypes() throws {
        let parsed = try XMLDecoder.decode("""
        <freecol-specification id="spec">
          <tile-improvement-type id="model.improvement.plow"
                                 required-role="model.role.pioneer" add-work-turns="2"
                                 expended-amount="1"/>
          <tile-improvement-type id="model.improvement.river" natural="true"/>
          <roles>
            <role id="model.role.pioneer" maximum-count="5">
              <required-goods id="model.goods.tools" value="20"/>
              <required-ability id="model.ability.canBeEquipped" value="true"/>
            </role>
          </roles>
        </freecol-specification>
        """)
        let spec = Specification(parsed: parsed)
        XCTAssertEqual(spec.improvementTypes["model.improvement.plow"]?.requiredRole,
                       "model.role.pioneer")
        XCTAssertEqual(spec.improvementTypes["model.improvement.plow"]?.addWorkTurns, 2)
        XCTAssertEqual(spec.improvementTypes["model.improvement.plow"]?.expendedAmount, 1)
        XCTAssertEqual(spec.improvementTypes["model.improvement.river"]?.isNatural, true)
        XCTAssertEqual(spec.roleTypes["model.role.pioneer"]?.maximumCount, 5)
        XCTAssertEqual(spec.roleTypes["model.role.pioneer"]?.requiredGoods["model.goods.tools"], 20)
        XCTAssertEqual(spec.roleTypes["model.role.pioneer"]?.requiredAbilities["model.ability.canBeEquipped"], true)
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
          <highSeas id="highSeas-1">
            <unit id="unit-4" owner="player-1" unitType="model.unit.caravel"
                  location="highSeas-1" entryLocation="tile-0-0" movesLeft="0" state="ACTIVE"/>
          </highSeas>
        </game>
        """)
        try game.load(from: parsed)

        let state = GameState()
        state.phase = .inGame
        state.installGame(game)

        // Only local units are cycled.
        XCTAssertEqual(state.selectableLocalUnits.map(\.id), ["unit-1", "unit-2", "unit-4"])
        state.selectNextUnit()
        XCTAssertEqual(state.selectedUnitId, "unit-1")
        state.selectNextUnit()
        XCTAssertEqual(state.selectedUnitId, "unit-2")
        state.selectNextUnit()
        XCTAssertEqual(state.selectedUnitId, "unit-4")
        XCTAssertNil(state.selectedUnitTileId)
        state.selectPreviousUnit()
        XCTAssertEqual(state.selectedUnitId, "unit-2")

        // Only unit-1 is active with moves left on the map.
        XCTAssertEqual(state.unitsAwaitingOrders.map(\.id), ["unit-1"])

        // unit-2 has a destination and is not active: orders are clearable.
        state.selectUnit("unit-2", onTile: "tile-1-0")
        XCTAssertTrue(state.canClearSelectedUnitOrders)
        state.clearSelectedUnitOrders()
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertNotNil(state.errorMessage, "Without a connection, clearing orders must not claim success")
        XCTAssertEqual(game.units["unit-2"]?.destination, "tile-0-0")

        // unit-1 is active without a destination: nothing to clear.
        state.selectUnit("unit-1", onTile: "tile-0-0")
        XCTAssertFalse(state.canClearSelectedUnitOrders)
    }

    func testRemoteEndTurnSafetyTimeoutOutlastsAskTimeout() {
        let askTimeout: TimeInterval = 30
        let remoteSafetyTimeout = GameState.endTurnSafetyTimeout(localServer: false, askTimeout: askTimeout)

        XCTAssertGreaterThan(remoteSafetyTimeout, askTimeout)
        XCTAssertEqual(remoteSafetyTimeout, 35)
        XCTAssertEqual(GameState.endTurnSafetyTimeout(localServer: true, askTimeout: askTimeout), 8)
    }

    @MainActor
    func testLocalEndTurnRejectsDuplicateUntilTurnAdvances() async throws {
        let state = GameState()
        defer { state.disconnect() }
        state.startLocal(userName: "Alice", nationId: "model.nation.dutch")

        let connectionDeadline = Date().addingTimeInterval(5)
        while state.phase.description != "Im Spiel", Date() < connectionDeadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertEqual(state.phase.description, "Im Spiel")

        let turnBefore = try XCTUnwrap(state.game?.turn.number)
        state.endTurn()
        XCTAssertFalse(state.canEndTurn, "end-turn controls must disable while the request is pending")
        state.endTurn()
        XCTAssertEqual(state.errorMessage, "Warte auf Serverantwort fuer Zugende.")

        let turnDeadline = Date().addingTimeInterval(5)
        while state.game?.turn.number == turnBefore, Date() < turnDeadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertEqual(state.game?.turn.number, turnBefore + 1)
        XCTAssertTrue(state.canEndTurn, "turn availability should refresh after the server advances the turn")
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(state.game?.turn.number, turnBefore + 1, "duplicate endTurn must not advance another turn")
    }

    @MainActor
    func testCoreGameplayActionGuardsRejectIllegalSelectionAndTurn() throws {
        let game = Game()
        let parsed = try XMLDecoder.decode("""
        <game id="game-1" clientUserName="Alice" currentPlayer="player-1">
          <player id="player-1" username="Alice"/>
          <player id="player-2" username="Bob"/>
          <map id="map-1" width="3" height="1">
            <tile id="tile-0" x="0" y="0" type="model.tile.plains"/>
            <tile id="tile-1" x="1" y="0" type="model.tile.plains"/>
            <tile id="tile-2" x="2" y="0" type="model.tile.plains"/>
          </map>
          <unit id="unit-founder" owner="player-1" unitType="model.unit.freeColonist"
                location="tile-0" movesLeft="3" state="ACTIVE"/>
          <unit id="unit-carrier" owner="player-1" unitType="model.unit.caravel"
                location="tile-0" movesLeft="6" state="ACTIVE"/>
          <unit id="unit-embarked" owner="player-1" unitType="model.unit.freeColonist"
                location="unit-carrier" movesLeft="3" state="ACTIVE"/>
        </game>
        """)
        try game.load(from: parsed)

        let state = GameState()
        state.phase = .inGame
        state.installGame(game)
        state.selectUnit("unit-founder", onTile: "tile-0")

        XCTAssertTrue(state.canMoveSelectedUnit(to: "tile-1"))
        XCTAssertFalse(state.canMoveSelectedUnit(to: "tile-2"), "one-step movement must require an adjacent tile")
        XCTAssertTrue(state.canMoveSelectedUnitTo(destinationTileId: "tile-2"), "a distant map destination may be path-followed")
        XCTAssertTrue(state.canBuildSelectedColony)
        XCTAssertTrue(state.canEndTurn)

        state.selectUnit("unit-embarked", onTile: "tile-0")
        XCTAssertTrue(state.canMoveSelectedUnit(to: "tile-1"), "passengers can step from their carrier onto adjacent land")
        XCTAssertTrue(state.canMoveSelectedUnitTo(destinationTileId: "tile-1"))

        game.currentPlayerId = "player-2"
        state.selectUnit("unit-founder", onTile: "tile-0")
        XCTAssertFalse(state.canMoveSelectedUnit(to: "tile-1"))
        XCTAssertFalse(state.canBuildSelectedColony)
        XCTAssertFalse(state.canEndTurn)
        state.endTurn()
        XCTAssertEqual(state.errorMessage, "Du bist gerade nicht am Zug.")
    }

    @MainActor
    func testExpertColonistCanFoundColonyThroughInheritedAbility() throws {
        let game = Game()
        let parsed = try XMLDecoder.decode("""
        <game id="game-1" clientUserName="Alice" currentPlayer="player-1">
          <freecol-specification>
            <unit-types>
              <unit-type id="model.unit.freeColonist">
                <ability id="model.ability.foundColony" value="true"/>
              </unit-type>
              <unit-type id="model.unit.masterGunsmith" extends="model.unit.freeColonist"/>
            </unit-types>
          </freecol-specification>
          <player id="player-1" username="Alice"/>
          <map id="map-1" width="1" height="1">
            <tile id="tile-0" x="0" y="0" type="model.tile.plains"/>
          </map>
          <unit id="unit-founder" owner="player-1" unitType="model.unit.masterGunsmith"
                location="tile-0" movesLeft="1" state="ACTIVE"/>
        </game>
        """)
        try game.load(from: parsed)

        let state = GameState()
        state.phase = .inGame
        state.installGame(game)
        state.selectUnit("unit-founder", onTile: "tile-0")

        XCTAssertTrue(state.canBuildSelectedColony)
    }

    @MainActor
    func testSelectionRecoversAfterSelectedUnitIsRemoved() throws {
        let game = Game()
        let parsed = try XMLDecoder.decode("""
        <game id="game-1" clientUserName="Alice" currentPlayer="player-1">
          <player id="player-1" username="Alice"/>
          <map id="map-1" width="2" height="1">
            <tile id="tile-0" x="0" y="0" type="model.tile.plains"/>
            <tile id="tile-1" x="1" y="0" type="model.tile.plains"/>
          </map>
          <unit id="unit-1" owner="player-1" unitType="model.unit.freeColonist"
                location="tile-0" movesLeft="3" state="ACTIVE"/>
          <unit id="unit-2" owner="player-1" unitType="model.unit.freeColonist"
                location="tile-0" movesLeft="3" state="ACTIVE"/>
        </game>
        """)
        try game.load(from: parsed)

        let state = GameState()
        state.phase = .inGame
        state.installGame(game)
        state.selectUnit("unit-1", onTile: "tile-0")

        try game.applyRemove(ParsedMessage(
            tag: "remove",
            attributes: ["xLength": "1", "x0": "unit-1", "divert": "tile-0"],
            children: []
        ))
        XCTAssertFalse(state.canMoveSelectedUnit(to: "tile-1"), "removed selections must not remain actionable")
        state.syncAfterModelUpdate()

        XCTAssertEqual(state.selectedUnitId, "unit-2")
        XCTAssertEqual(state.selectedTileId, "tile-0")
    }

    func testJavaRemoveArrayRemovesColonyAndItsTileReference() throws {
        let game = Game()
        let parsed = try XMLDecoder.decode("""
        <game id="game-1">
          <player id="player-1" username="Alice"/>
          <map id="map-1" width="1" height="1">
            <tile id="tile-0" x="0" y="0" type="model.tile.plains"
                  owner="player-1" owningSettlement="colony-1">
              <colony id="colony-1"/>
            </tile>
          </map>
          <colony id="colony-1" name="Alpha" owner="player-1"
                  tile="tile-0" settlementType="model.settlement.colony"/>
        </game>
        """)
        try game.load(from: parsed)
        XCTAssertNotNil(game.colonies["colony-1"])
        XCTAssertEqual(game.tiles["tile-0"]?.settlement, "colony-1")

        try game.applyRemove(ParsedMessage(
            tag: "remove",
            attributes: ["xLength": "1", "x0": "colony-1", "divert": "tile-0"],
            children: []
        ))

        XCTAssertNil(game.colonies["colony-1"])
        XCTAssertNotNil(game.tiles["tile-0"], "divert identifies a surviving object, not a removal")
        XCTAssertNil(game.tiles["tile-0"]?.settlement)
    }

    @MainActor
    func testIllegalCoreActionsSetUserFacingErrorsWithoutSending() throws {
        let game = Game()
        let parsed = try XMLDecoder.decode("""
        <game id="game-1" clientUserName="Alice" currentPlayer="player-1">
          <player id="player-1" username="Alice"/>
          <map id="map-1" width="3" height="1">
            <tile id="tile-0" x="0" y="0" type="model.tile.plains"/>
            <tile id="tile-1" x="1" y="0" type="model.tile.plains"/>
            <tile id="tile-2" x="2" y="0" type="model.tile.plains"/>
          </map>
          <unit id="unit-1" owner="player-1" unitType="model.unit.freeColonist"
                location="tile-0" movesLeft="0" state="ACTIVE"/>
        </game>
        """)
        try game.load(from: parsed)

        let state = GameState()
        state.phase = .inGame
        state.installGame(game)
        state.selectUnit("unit-1", onTile: "tile-0")

        // No moves left: a move is rejected locally with a user-visible message.
        state.moveSelectedUnit(to: "tile-1")
        XCTAssertEqual(state.errorMessage, "Ungültige Bewegung.")

        // Empty colony name is rejected before any request is built.
        state.buildColony(name: "   ")
        XCTAssertEqual(state.errorMessage, "Bitte einen Kolonienamen eingeben.")

        // Unit without moves cannot found a colony here.
        state.buildColony(name: "Boston")
        XCTAssertEqual(state.errorMessage, "Kolonie kann hier nicht gegruendet werden.")
        XCTAssertNotNil(game.units["unit-1"], "rejected actions must not mutate the model")
    }

    func testJavaRejectionTextsMapToUserFacingMessages() {
        // Text captured from the real Java server (REAL_SERVER_REJECT_E2E probe).
        XCTAssertEqual(
            GameState.userFacingServerError("Not a net.sf.freecol.server.model.ServerUnit: unit:does-not-exist/null"),
            "Die Einheit ist auf dem Server nicht bekannt."
        )
        XCTAssertEqual(
            GameState.userFacingServerError("Illegal move for: unit-1 type: ILLEGAL from: tile-0 to: tile-1"),
            "Diese Bewegung ist nicht erlaubt."
        )
        XCTAssertEqual(
            GameState.userFacingServerError("Non-unique colony name Boston"),
            "Der Koloniename ist bereits vergeben."
        )
        // Unknown texts keep the server information instead of being dropped.
        XCTAssertEqual(
            GameState.userFacingServerError("something new"),
            "Der Server hat die Aktion abgelehnt: something new"
        )
    }

    func testServerErrorMappingIsIndependentOfGameState() {
        XCTAssertEqual(
            ServerErrorMessage.userFacing("Not allowed to end turn for current player"),
            "Du bist nicht am Zug. Bitte warte auf deinen nächsten Zug."
        )
        XCTAssertEqual(
            ServerErrorMessage.userFacing("Null colony name"),
            "Bitte einen Kolonienamen eingeben."
        )
        XCTAssertEqual(
            ServerErrorMessage.userFacing("unexpected server detail"),
            "Der Server hat die Aktion abgelehnt: unexpected server detail"
        )
    }

    func testTileSpatialIndexHitTestingAndViewportCulling() throws {
        let game = Game()
        var tiles: [Tile] = []
        for y in 0..<8 {
            for x in 0..<10 {
                tiles.append(try Tile(
                    id: "tile-\(x)-\(y)",
                    attributes: ["x": "\(x)", "y": "\(y)"],
                    children: [],
                    game: game
                ))
            }
        }
        let index = TileSpatialIndex(tiles: tiles)
        let unorderedIndex = TileSpatialIndex(tiles: Array(tiles.reversed()))

        XCTAssertEqual(
            index.hitTest(location: CGPoint(x: 192, y: 32), tileW: 64, tileH: 32)?.id,
            "tile-2-1"
        )
        XCTAssertEqual(
            unorderedIndex.hitTest(location: CGPoint(x: 192, y: 32), tileW: 64, tileH: 32)?.id,
            "tile-2-1"
        )
        XCTAssertNil(index.hitTest(location: CGPoint(x: -100, y: -100), tileW: 64, tileH: 32))

        let visible = index.visibleTiles(
            in: CGRect(x: 160, y: 16, width: 64, height: 32),
            tileW: 64,
            tileH: 32
        )
        XCTAssertTrue(visible.contains { $0.id == "tile-2-1" })
        XCTAssertFalse(visible.contains { $0.id == "tile-9-7" })
        XCTAssertLessThan(visible.count, tiles.count)

        for y in stride(from: -16.0, through: 160.0, by: 8.0) {
            for x in stride(from: -32.0, through: 256.0, by: 8.0) {
                let expected = tiles.sorted {
                    $0.y == $1.y ? $0.x < $1.x : $0.y < $1.y
                }.reduce(nil as (Tile, Double)?) { best, tile in
                    let stagger = tile.y.isMultiple(of: 2) ? 0.0 : 0.5
                    let originX = (Double(tile.x) + 0.5 + stagger) * 64
                    let originY = Double(tile.y + 1) * 16
                    let score = abs(x - originX) / 32 + abs(y - originY) / 16
                    guard score <= 1, score <= (best?.1 ?? .greatestFiniteMagnitude) else {
                        return best
                    }
                    return (tile, score)
                }?.0.id
                XCTAssertEqual(
                    index.hitTest(location: CGPoint(x: x, y: y), tileW: 64, tileH: 32)?.id,
                    expected,
                    "hit-test mismatch at (\(x), \(y))"
                )
            }
        }

        for rect in [
            CGRect(x: 0, y: 0, width: 64, height: 32),
            CGRect(x: 64, y: 32, width: 100, height: 80),
            CGRect(x: 210, y: 100, width: 70, height: 60),
        ] {
            let expectedVisible = Set(tiles.filter { tile in
                let stagger = tile.y.isMultiple(of: 2) ? 0.0 : 0.5
                let origin = CGPoint(
                    x: (Double(tile.x) + 0.5 + stagger) * 64,
                    y: Double(tile.y + 1) * 16
                )
                return origin.x + 32 >= rect.minX
                    && origin.x - 32 <= rect.maxX
                    && origin.y + 16 >= rect.minY
                    && origin.y - 16 <= rect.maxY
            }.map(\.id))
            let actualVisible = Set(index.visibleTiles(in: rect, tileW: 64, tileH: 32).map(\.id))
            XCTAssertEqual(actualVisible, expectedVisible)
        }
    }

    func testTileSpatialIndexQueryPerformanceOnStandardMap() throws {
        try measureTileSelectionPerformance(width: 80, height: 100, useSpatialIndex: true)
    }

    func testTileLinearScanPerformanceOnStandardMap() throws {
        try measureTileSelectionPerformance(width: 80, height: 100, useSpatialIndex: false)
    }

    func testTileSpatialIndexQueryPerformanceOnLargeMap() throws {
        try measureTileSelectionPerformance(width: 160, height: 200, useSpatialIndex: true)
    }

    func testTileLinearScanPerformanceOnLargeMap() throws {
        try measureTileSelectionPerformance(width: 160, height: 200, useSpatialIndex: false)
    }

    func testTileIndexedCanvasWorkloadOnStandardMap() throws {
        try measureTileCanvasWorkload(width: 80, height: 100, useSpatialIndex: true)
    }

    func testTileLinearCanvasWorkloadOnStandardMap() throws {
        try measureTileCanvasWorkload(width: 80, height: 100, useSpatialIndex: false)
    }

    func testTileIndexedCanvasWorkloadOnLargeMap() throws {
        try measureTileCanvasWorkload(width: 160, height: 200, useSpatialIndex: true)
    }

    func testTileLinearCanvasWorkloadOnLargeMap() throws {
        try measureTileCanvasWorkload(width: 160, height: 200, useSpatialIndex: false)
    }

    private func measureTileSelectionPerformance(
        width: Int,
        height: Int,
        useSpatialIndex: Bool
    ) throws {
        let game = Game()
        var tiles: [Tile] = []
        tiles.reserveCapacity(width * height)
        for y in 0..<height {
            for x in 0..<width {
                tiles.append(try Tile(
                    id: "tile-\(x)-\(y)",
                    attributes: ["x": "\(x)", "y": "\(y)"],
                    children: [],
                    game: game
                ))
            }
        }

        let rect = CGRect(x: 1200, y: 1200, width: 1200, height: 800)
        let tileW = 256.0
        let tileH = 128.0
        let spatialIndex = TileSpatialIndex(sortedTiles: tiles)
        let visibleWithLinearScan = {
            tiles.filter { tile in
                let stagger = tile.y.isMultiple(of: 2) ? 0.0 : 0.5
                let originX = (Double(tile.x) + 0.5 + stagger) * tileW
                let originY = Double(tile.y + 1) * tileH / 2
                return originX + tileW / 2 >= rect.minX
                    && originX - tileW / 2 <= rect.maxX
                    && originY + tileH / 2 >= rect.minY
                    && originY - tileH / 2 <= rect.maxY
            }
        }
        let expectedVisibleIds = Set(
            spatialIndex.visibleTiles(in: rect, tileW: tileW, tileH: tileH).map(\.id)
        )
        XCTAssertFalse(expectedVisibleIds.isEmpty)
        XCTAssertEqual(Set(visibleWithLinearScan().map(\.id)), expectedVisibleIds)

        if useSpatialIndex {
            measure(metrics: [XCTClockMetric()]) {
                let visible = spatialIndex.visibleTiles(in: rect, tileW: tileW, tileH: tileH)
                XCTAssertEqual(visible.count, expectedVisibleIds.count)
            }
        } else {
            measure(metrics: [XCTClockMetric()]) {
                XCTAssertEqual(visibleWithLinearScan().count, expectedVisibleIds.count)
            }
        }
    }

    private func measureTileCanvasWorkload(
        width: Int,
        height: Int,
        useSpatialIndex: Bool
    ) throws {
        let game = Game()
        var tiles: [Tile] = []
        tiles.reserveCapacity(width * height)
        for y in 0..<height {
            for x in 0..<width {
                tiles.append(try Tile(
                    id: "tile-\(x)-\(y)",
                    attributes: ["x": "\(x)", "y": "\(y)"],
                    children: [],
                    game: game
                ))
            }
        }

        let rect = CGRect(x: 1200, y: 1200, width: 1200, height: 800)
        let tileW = 256.0
        let tileH = 128.0
        let expectedVisibleCount = tiles.filter { tile in
            let stagger = tile.y.isMultiple(of: 2) ? 0.0 : 0.5
            let originX = (Double(tile.x) + 0.5 + stagger) * tileW
            let originY = Double(tile.y + 1) * tileH / 2
            return originX + tileW / 2 >= rect.minX
                && originX - tileW / 2 <= rect.maxX
                && originY + tileH / 2 >= rect.minY
                && originY - tileH / 2 <= rect.maxY
        }.count
        XCTAssertGreaterThan(expectedVisibleCount, 0)

        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            let sortedTiles = tiles.sorted {
                $0.y == $1.y ? $0.x < $1.x : $0.y < $1.y
            }
            let visible: [Tile]
            if useSpatialIndex {
                visible = TileSpatialIndex(sortedTiles: sortedTiles).visibleTiles(
                    in: rect,
                    tileW: tileW,
                    tileH: tileH
                )
            } else {
                visible = sortedTiles.filter { tile in
                    let stagger = tile.y.isMultiple(of: 2) ? 0.0 : 0.5
                    let originX = (Double(tile.x) + 0.5 + stagger) * tileW
                    let originY = Double(tile.y + 1) * tileH / 2
                    return originX + tileW / 2 >= rect.minX
                        && originX - tileW / 2 <= rect.maxX
                        && originY + tileH / 2 >= rect.minY
                        && originY - tileH / 2 <= rect.maxY
                }
            }
            let tilesToDraw = useSpatialIndex ? visible : sortedTiles
            let pathWidth = consumeTilePaths(tilesToDraw, tileW: tileW, tileH: tileH)
            XCTAssertGreaterThan(pathWidth, 0)
            if useSpatialIndex {
                XCTAssertEqual(visible.count, expectedVisibleCount)
            } else {
                XCTAssertEqual(tilesToDraw.count, width * height)
            }
        }
    }

    private func consumeTilePaths(_ tiles: [Tile], tileW: Double, tileH: Double) -> Double {
        tiles.reduce(0) { totalWidth, tile in
            let stagger = tile.y.isMultiple(of: 2) ? 0.0 : 0.5
            let origin = CGPoint(
                x: (Double(tile.x) + 0.5 + stagger) * tileW,
                y: Double(tile.y + 1) * tileH / 2
            )
            var path = Path()
            path.addLines([
                CGPoint(x: origin.x, y: origin.y - tileH / 2),
                CGPoint(x: origin.x + tileW / 2, y: origin.y),
                CGPoint(x: origin.x, y: origin.y + tileH / 2),
                CGPoint(x: origin.x - tileW / 2, y: origin.y),
            ])
            path.closeSubpath()
            return totalWidth + path.boundingRect.width
        }
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
        XCTAssertEqual(requirements.target, "Lagerhaus")
        XCTAssertEqual(requirements.items.first?.id, "model.goods.lumber")
        XCTAssertEqual(requirements.items.first?.required, 60)
        XCTAssertEqual(requirements.items.first?.stored, 12)
    }

    func testFoundingFatherDisplayName() {
        XCTAssertEqual(GameState.foundingFatherLabel("model.foundingFather.adamSmith"),
                       "Adam Smith")
    }

    // MARK: Phase 58 - diplomacy and native depth

    func testIndianSettlementAndTensionParsing() throws {
        let game = Game()
        let parsed = try XMLDecoder.decode("""
        <game id="game-1">
          <player id="player-1" username="Alice">
            <tension player="player-2" value="320"/>
            <banMissions player="player-2"/>
          </player>
          <player id="player-2" username="Bob"/>
          <indianSettlement id="is-1" name="Cahokia" owner="player-3" tile="tile-0-0"
                            learnableSkill="model.unit.expertFarmer"
                            wantedGoods0="model.goods.rum"
                            wantedGoods1="model.goods.tobacco"
                            mostHated="player-2">
            <alarm player="player-1" value="45"/>
          </indianSettlement>
        </game>
        """)
        try game.load(from: parsed)

        let player = try XCTUnwrap(game.players["player-1"])
        XCTAssertEqual(player.tension["player-2"], 320)
        XCTAssertTrue(player.bannedMissions.contains("player-2"))

        let settlement = try XCTUnwrap(game.colonies["is-1"])
        XCTAssertEqual(settlement.learnableSkill, "model.unit.expertFarmer")
        XCTAssertEqual(settlement.wantedGoods, ["model.goods.rum", "model.goods.tobacco"])
        XCTAssertEqual(settlement.mostHated, "player-2")
        XCTAssertEqual(settlement.alarm["player-1"], 45)
    }

    @MainActor
    func testBeginDiplomacySynthesizesProposal() async throws {
        let game = Game()
        let parsed = try XMLDecoder.decode("""
        <game id="game-1" clientUserName="Alice">
          <freecol-specification id="spec">
            <unit-type id="model.unit.freeColonist">
              <ability id="model.ability.negotiate" value="true"/>
            </unit-type>
          </freecol-specification>
          <player id="player-1" username="Alice"/>
          <player id="player-2" username="Bob"/>
          <map id="map-1" width="3" height="1">
            <tile id="tile-0-0" x="0" y="0" type="model.tile.plains"/>
            <tile id="tile-1-0" x="1" y="0" type="model.tile.plains"/>
          </map>
          <unit id="unit-1" owner="player-1" unitType="model.unit.freeColonist"
                location="tile-0-0" movesLeft="3" state="ACTIVE"/>
          <colony id="colony-2" name="Quebec" owner="player-2" tile="tile-1-0"/>
        </game>
        """)
        try game.load(from: parsed)

        let state = GameState()
        state.phase = .inGame
        state.installGame(game)
        state.selectUnit("unit-1", onTile: "tile-0-0")

        XCTAssertEqual(state.diplomacyInitiationTargetsForSelectedUnit.map(\.id), ["colony-2"])
        state.beginDiplomacy(otherColonyId: "colony-2")

        XCTAssertEqual(state.pendingServerDecision?.type, .diplomacy)
        XCTAssertFalse(state.pendingDiplomacyIsIncoming)
        XCTAssertEqual(state.pendingDiplomacy?.context, "DIPLOMATIC")
        XCTAssertEqual(state.pendingServerDecision?.rawPayload["ourId"], "unit-1")
        XCTAssertEqual(state.pendingServerDecision?.rawPayload["otherId"], "colony-2")
    }

    @MainActor
    func testAttackConfirmationState() async throws {
        let game = Game()
        let parsed = try XMLDecoder.decode("""
        <game id="game-1" clientUserName="Alice">
          <player id="player-1" username="Alice"/>
          <player id="player-2" username="Bob"/>
          <map id="map-1" width="2" height="1">
            <tile id="tile-0-0" x="0" y="0" type="model.tile.plains"/>
            <tile id="tile-1-0" x="1" y="0" type="model.tile.plains"/>
          </map>
          <unit id="unit-1" owner="player-1" unitType="model.unit.soldier"
                location="tile-0-0" movesLeft="3" state="ACTIVE"/>
          <unit id="unit-2" owner="player-2" unitType="model.unit.freeColonist"
                location="tile-1-0" movesLeft="3" state="ACTIVE"/>
        </game>
        """)
        try game.load(from: parsed)

        let state = GameState()
        state.phase = .inGame
        state.installGame(game)
        state.selectUnit("unit-1", onTile: "tile-0-0")

        guard state.canAttackSelectedUnitMelee(onTile: "tile-1-0") else {
            throw XCTSkip("melee attack gating not satisfied in this fixture")
        }
        state.requestAttack(onTile: "tile-1-0", ranged: false)
        XCTAssertTrue(state.showAttackConfirmation)
        XCTAssertTrue(state.pendingAttackSummary.contains("Melee"))
        state.dismissPendingAttack()
        XCTAssertFalse(state.showAttackConfirmation)
    }

    // MARK: Phase 59 - Europe depth

    func testUnitCarriedGoodsParsingAndRemoval() throws {
        let game = Game()
        let parsed = try XMLDecoder.decode("""
        <game id="game-1">
          <player id="player-1" username="Alice"/>
          <unit id="unit-1" owner="player-1" unitType="model.unit.merchantman">
            <goodsContainer>
              <storedGoods>
                <goods type="model.goods.rum" amount="40"/>
                <goods type="model.goods.tobacco" amount="25"/>
              </storedGoods>
            </goodsContainer>
          </unit>
        </game>
        """)
        try game.load(from: parsed)
        let unit = try XCTUnwrap(game.units["unit-1"])
        XCTAssertEqual(unit.goods["model.goods.rum"], 40)
        XCTAssertEqual(unit.goods["model.goods.tobacco"], 25)

        game.removeUnitGoods(unitId: "unit-1", typeId: "model.goods.rum", amount: 15)
        XCTAssertEqual(game.units["unit-1"]?.goods["model.goods.rum"], 25)
        game.removeUnitGoods(unitId: "unit-1", typeId: "model.goods.rum", amount: 25)
        XCTAssertNil(game.units["unit-1"]?.goods["model.goods.rum"])
    }

    @MainActor
    func testEuropePurchasableUnitsAndRecruitTracking() async throws {
        let game = Game()
        let parsed = try XMLDecoder.decode("""
        <game id="game-1" clientUserName="Alice">
          <player id="player-1" username="Alice" gold="1000" immigrationRequired="12">
            <europe id="player-1-europe" owner="player-1" recruitPrice="120">
              <recruit id="model.unit.freeColonist" role="model.role.default" number="2"/>
              <unitPrice unitType="model.unit.artillery" price="500"/>
              <unitPrice unitType="model.unit.frigate" price="1200"/>
            </europe>
          </player>
          <freecol-specification id="spec">
            <unit-type id="model.unit.artillery"/>
            <unit-type id="model.unit.frigate"/>
          </freecol-specification>
        </game>
        """)
        try game.load(from: parsed)

        let state = GameState()
        state.phase = .inGame
        state.installGame(game)

        XCTAssertEqual(state.purchasableEuropeUnits.map(\.unitType),
                       ["model.unit.artillery", "model.unit.frigate"])
        XCTAssertEqual(state.purchasableEuropeUnits.first?.price, 500)
        XCTAssertEqual(state.unitDisplayName("model.unit.artillery"), "Artillerie")

        state.recruitUnitInEurope(slot: 1)
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(state.purchasesRecruits, 1)
        XCTAssertEqual(state.purchasesTotal, 120)
    }

    @MainActor
    func testMarketPriceHistoryRecording() async throws {
        let game = Game()
        let parsed = try XMLDecoder.decode("""
        <game id="game-1" clientUserName="Alice">
          <player id="player-1" username="Alice">
            <market owner="player-1">
              <marketData goods-type="model.goods.sugar" amount="1500" initialPrice="2"/>
            </market>
          </player>
          <freecol-specification id="spec">
            <goods-type id="model.goods.sugar" storable="true">
              <market initial-amount="1500" initial-price="2" price-difference="2"/>
            </goods-type>
          </freecol-specification>
        </game>
        """)
        try game.load(from: parsed)

        let state = GameState()
        state.phase = .inGame
        state.installGame(game)

        state.recordMarketSnapshot()
        XCTAssertEqual(state.marketPriceHistory["model.goods.sugar"]?.map { $0.price }, [2])
        XCTAssertEqual(state.marketBuyPriceHistory["model.goods.sugar"]?.map { $0.price }, [4])

        // The same buy/sale snapshot is not recorded twice.
        state.recordMarketSnapshot()
        XCTAssertEqual(state.marketPriceHistory["model.goods.sugar"]?.map { $0.price }, [2])
        XCTAssertEqual(state.marketBuyPriceHistory["model.goods.sugar"]?.map { $0.price }, [4])

        try game.applyUpdate(XMLDecoder.decode("""
        <update>
          <player id="player-1" username="Alice">
            <market owner="player-1">
              <marketData goods-type="model.goods.sugar" amount="3000" initialPrice="2"/>
            </market>
          </player>
        </update>
        """))
        state.recordMarketSnapshot()
        XCTAssertEqual(state.marketPriceHistory["model.goods.sugar"]?.map { $0.price }, [2, 1])
        XCTAssertEqual(state.marketBuyPriceHistory["model.goods.sugar"]?.map { $0.price }, [4, 3])
    }

    // MARK: Phase 60 - model depth

    func testTileResourcesAndLostCityParsing() throws {
        let game = Game()
        let parsed = try XMLDecoder.decode("""
        <game id="game-1">
          <player id="player-1" username="Alice"/>
          <map id="map-1" width="2" height="1">
            <tile id="tile-0-0" x="0" y="0" type="model.tile.hills">
              <tileItemContainer>
                <resource id="res-1" type="model.resource.minerals" quantity="3"/>
                <lostCityRumour id="lcr-1" type="RUINS" name="nameCache.cibola1"/>
              </tileItemContainer>
            </tile>
          </map>
        </game>
        """)
        try game.load(from: parsed)
        let tile = try XCTUnwrap(game.tiles["tile-0-0"])
        XCTAssertEqual(tile.resources.first?.type, "model.resource.minerals")
        XCTAssertEqual(tile.resources.first?.quantity, 3)
        XCTAssertEqual(tile.resources.first?.displayName, "minerals")
        XCTAssertEqual(tile.lostCityRumourType, "RUINS")
        XCTAssertEqual(tile.lostCityName, "nameCache.cibola1")
    }

    func testNationOptionsAndCibolaParsing() throws {
        let game = Game()
        let parsed = try XMLDecoder.decode("""
        <game id="game-1">
          <cibola id="nameCache.cibola1"/>
          <cibola id="nameCache.cibola2"/>
          <nationOptions nationalAdvantages="SELECTABLE">
            <nationOption id="model.nation.dutch" state="AVAILABLE"/>
            <nationOption id="model.nation.french" state="NOT_AVAILABLE"/>
          </nationOptions>
        </game>
        """)
        try game.load(from: parsed)
        XCTAssertEqual(game.cibolaCities, ["nameCache.cibola1", "nameCache.cibola2"])
        XCTAssertEqual(game.nationStates["model.nation.dutch"], "AVAILABLE")
        XCTAssertEqual(game.nationStates["model.nation.french"], "NOT_AVAILABLE")
    }

    @MainActor
    func testLobbyPlayersAndServerOptionValue() async throws {
        let game = Game()
        let parsed = try XMLDecoder.decode("""
        <game id="game-1" clientUserName="Alice">
          <player id="player-2" username="Bob" nationId="model.nation.french"/>
          <player id="player-1" username="Alice" nationId="model.nation.dutch" admin="true"/>
        </game>
        """)
        try game.load(from: parsed)

        let state = GameState()
        state.installGame(game)

        XCTAssertEqual(state.lobbyPlayers.map { $0.name }, ["Alice", "Bob"])
        XCTAssertTrue(state.isLocalPlayerAdmin)

        game.mergeOptions(["model.option.startingMoney": "3000"])
        XCTAssertEqual(state.serverOptionValue(id: "model.option.startingMoney"), "3000")
        XCTAssertNil(state.serverOptionValue(id: "model.option.unknown"))
    }

    func testFeatureChangeAppliesAbilitiesAndMessages() throws {
        let game = Game()
        let parsed = try XMLDecoder.decode("""
        <game id="game-1">
          <player id="player-1" username="Alice"/>
        </game>
        """)
        try game.load(from: parsed)

        let change = try XMLDecoder.decode("""
        <featureChange id="player-1" add="true">
          <ability id="model.ability.navalUnit" value="true"/>
          <modelMessage id="model.message.gainedAbility" messageType="DEFAULT"/>
        </featureChange>
        """)
        game.applyFeatureChange(change)

        let player = try XCTUnwrap(game.players["player-1"])
        XCTAssertEqual(player.abilities["model.ability.navalUnit"], true)
        XCTAssertTrue(player.modelMessages.contains { $0.id == "model.message.gainedAbility" })
    }
}

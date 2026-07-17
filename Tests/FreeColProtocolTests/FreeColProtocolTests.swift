import XCTest
@testable import FreeColProtocol

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
}

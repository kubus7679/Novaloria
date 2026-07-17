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

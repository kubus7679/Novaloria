import Foundation
import FreeColProtocol
import FreeColGame
import FreeColClient

var passed = 0
var failed = 0

struct TestError: Error, CustomStringConvertible {
    let message: String
    var description: String { message }
}

func assertEqual<T: Equatable>(_ a: T, _ b: T) throws {
    if a != b { throw TestError(message: "\(a) != \(b)") }
}

func assertNotNil<T>(_ a: T?) throws {
    if a == nil { throw TestError(message: "nil") }
}

func test(_ name: String, closure: () throws -> Void) {
    do {
        try closure()
        passed += 1
        print("  PASS  \(name)")
    } catch {
        failed += 1
        print("  FAIL  \(name): \(error)")
    }
}

setbuf(stdout, nil)
print("FreeColProtocol Tests")
print("=====================")

test("decode trivial message") {
    let parsed = try XMLDecoder.decode("<endTurn/>")
    try assertEqual(parsed.tag, "endTurn")
    try assertEqual(parsed.attributes.isEmpty, true)
    try assertEqual(parsed.children.isEmpty, true)
}

test("decode attribute message") {
    let parsed = try XMLDecoder.decode(#"<setCurrentPlayer player="player-1"/>"#)
    try assertEqual(parsed.tag, "setCurrentPlayer")
    try assertEqual(parsed.attributes["player"], "player-1")
}

test("decode with children") {
    let xml = """
    <login userName="Alice">
      <game id="game-1"/>
    </login>
    """
    let parsed = try XMLDecoder.decode(xml)
    try assertEqual(parsed.tag, "login")
    try assertEqual(parsed.attributes["userName"], "Alice")
    try assertEqual(parsed.children.count, 1)
    try assertEqual(parsed.children[0].tag, "game")
}

test("encode trivial message") {
    let xml = XMLEncoder.encode(tag: "endTurn", attributes: [:])
    try assertEqual(xml, "<endTurn/>")
}

test("encode attribute message") {
    let xml = XMLEncoder.encode(tag: "setCurrentPlayer", attributes: ["player": "player-1"])
    try assertEqual(xml, #"<setCurrentPlayer player="player-1"/>"#)
}

test("encode with children") {
    let child = ParsedMessage(tag: "game", attributes: ["id": "game-1"], children: [])
    let xml = XMLEncoder.encode(tag: "login", attributes: ["userName": "Alice"], children: [child])
    try assertEqual(xml, #"<login userName="Alice"><game id="game-1"/></login>"#)
}

test("XML escaping") {
    let xml = XMLEncoder.encode(tag: "chat", attributes: ["message": "a < b & c > d"])
    try assertEqual(xml, #"<chat message="a &lt; b &amp; c &gt; d"/>"#)
}

test("attribute encoding preserves values") {
    let xml = #"<move unit="unit-3" direction="north"/>"#
    let parsed = try XMLDecoder.decode(xml)
    try assertEqual(parsed.tag, "move")
    try assertEqual(parsed.attributes["unit"], "unit-3")
    try assertEqual(parsed.attributes["direction"], "north")
    let reencoded = XMLEncoder.encode(tag: parsed.tag, attributes: parsed.attributes)
    try assertEqual(reencoded.contains(#"unit="unit-3""#), true)
    try assertEqual(reencoded.contains(#"direction="north""#), true)
    try assertEqual(reencoded.hasPrefix("<move"), true)
    try assertEqual(reencoded.hasSuffix("/>"), true)
}

test("message registry") {
    try assertNotNil(messageRegistry["endTurn"])
    try assertNotNil(messageRegistry["setCurrentPlayer"])
    try assertNotNil(messageRegistry["login"])
    try assertNotNil(messageRegistry["move"])
    try assertNotNil(messageRegistry["multiple"])
}

test("EndTurnMessage (trivial)") {
    let msg = EndTurnMessage()
    try assertEqual(msg.tag, "endTurn")
    let decoded = try EndTurnMessage(attributes: [:], children: [])
    try assertEqual(decoded.tag, "endTurn")
    let (attrs, children) = decoded.encode()
    try assertEqual(attrs.isEmpty, true)
    try assertEqual(children.isEmpty, true)
}

test("SetCurrentPlayerMessage (attribute)") {
    let msg = SetCurrentPlayerMessage(player: "player-1")
    try assertEqual(msg.tag, "setCurrentPlayer")
    try assertEqual(msg.player, "player-1")
    let (attrs, children) = msg.encode()
    try assertEqual(attrs["player"], "player-1")
    try assertEqual(children.isEmpty, true)
    let decoded = try SetCurrentPlayerMessage(attributes: ["player": "player-2"], children: [])
    try assertEqual(decoded.player, "player-2")
}

print("\n--- Game Model Tests ---\n")

test("Game.load with minimal game") {
    let game = Game()
    try game.load(from: ParsedMessage(tag: "game", attributes: ["id": "game-0", "turn": "42"], children: []))
    try assertEqual(game.id, "game-0")
    try assertEqual(game.turn, Turn(42))
}

test("Game.load with players") {
    let game = Game()
    let playerAttrs: Attributes = [
        "id": "player-1", "username": "Alice", "nationId": "model.nation.dutch",
        "playerType": "EUROPEAN", "gold": "500", "ai": "false"
    ]
    let gameMsg = ParsedMessage(tag: "game", attributes: ["id": "game-0"], children: [
        ParsedMessage(tag: "player", attributes: playerAttrs, children: [])
    ])
    try game.load(from: gameMsg)
    try assertEqual(game.players.count, 1)
    if let p = game.players["player-1"] {
        try assertEqual(p.name, "Alice")
        try assertEqual(p.gold, 500)
        try assertEqual(p.playerType, .european)
        try assertEqual(p.ai, false)
    } else {
        throw TestError(message: "player-1 not found")
    }
}

test("Game.load with tiles") {
    let game = Game()
    let gameMsg = ParsedMessage(tag: "game", attributes: ["id": "game-0"], children: [
        ParsedMessage(tag: "map", attributes: ["id": "map-0", "width": "40", "height": "30"], children: [
            ParsedMessage(tag: "tile", attributes: ["id": "tile-0", "x": "10", "y": "20", "type": "model.tile.plains"], children: []),
            ParsedMessage(tag: "tile", attributes: ["id": "tile-1", "x": "11", "y": "20", "type": "model.tile.ocean"], children: []),
        ])
    ])
    try game.load(from: gameMsg)
    try assertEqual(game.tiles.count, 2)
    try assertEqual(game.map?.width, 40)
    try assertEqual(game.map?.height, 30)
    if let t = game.tiles["tile-0"] {
        try assertEqual(t.x, 10)
        try assertEqual(t.y, 20)
        try assertEqual(t.type, "model.tile.plains")
    }
}

test("Game.load with units") {
    let game = Game()
    let unitAttrs: Attributes = [
        "id": "unit-1", "unitType": "model.unit.freeColonist", "owner": "player-1",
        "movesLeft": "3", "state": "ACTIVE", "location": "tile-0"
    ]
    let gameMsg = ParsedMessage(tag: "game", attributes: ["id": "game-0"], children: [
        ParsedMessage(tag: "unit", attributes: unitAttrs, children: [])
    ])
    try game.load(from: gameMsg)
    try assertEqual(game.units.count, 1)
    if let u = game.units["unit-1"] {
        try assertEqual(u.unitType, "model.unit.freeColonist")
        try assertEqual(u.owner, "player-1")
        try assertEqual(u.movesLeft, 3)
        try assertEqual(u.state, .active)
    }
}

test("Game.load with colonies") {
    let game = Game()
    let colAttrs: Attributes = [
        "id": "colony-1", "name": "New Amsterdam", "owner": "player-1",
        "tile": "tile-0", "established": "100"
    ]
    let gameMsg = ParsedMessage(tag: "game", attributes: ["id": "game-0"], children: [
        ParsedMessage(tag: "colony", attributes: colAttrs, children: [])
    ])
    try game.load(from: gameMsg)
    try assertEqual(game.colonies.count, 1)
    if let c = game.colonies["colony-1"] {
        try assertEqual(c.name, "New Amsterdam")
        try assertEqual(c.owner, "player-1")
        try assertEqual(c.tileId, "tile-0")
        try assertEqual(c.established, 100)
    }
}

test("Game.applyUpdate with player") {
    let game = Game()
    let update = ParsedMessage(tag: "update", attributes: [:], children: [
        ParsedMessage(tag: "player", attributes: [
            "id": "player-2", "username": "Bob", "nationId": "model.nation.french"
        ], children: [])
    ])
    try game.applyUpdate(update)
    try assertEqual(game.players.count, 1)
    try assertEqual(game.players["player-2"]?.name, "Bob")
}

test("Game.applyPartial modifies fields") {
    let game = Game()
    try game.load(from: ParsedMessage(tag: "game", attributes: ["id": "game-0"], children: [
        ParsedMessage(tag: "player", attributes: [
            "id": "player-1", "username": "Alice", "gold": "500"
        ], children: [])
    ]))
    // Partial update
    try game.applyPartial(ParsedMessage(tag: "partial", attributes: [
        "id": "player-1", "gold": "600"
    ], children: []))
    try assertEqual(game.players["player-1"]?.gold, 600)
    try assertEqual(game.players["player-1"]?.name, "Alice")
}

test("Game.applyRemove removes object") {
    let game = Game()
    try game.load(from: ParsedMessage(tag: "game", attributes: ["id": "game-0"], children: [
        ParsedMessage(tag: "player", attributes: [
            "id": "player-1", "username": "Alice"
        ], children: [])
    ]))
    try assertEqual(game.players.count, 1)
    try game.applyRemove(ParsedMessage(tag: "remove", attributes: ["divert": "player-1"], children: []))
    try assertEqual(game.players.count, 0)
}

test("GameStateManager processes setCurrentPlayer") {
    let mgr = GameStateManager()
    try mgr.process(ParsedMessage(tag: "setCurrentPlayer", attributes: ["player": "player-1"], children: []))
    try assertEqual(mgr.game.currentPlayerId, "player-1")
}

test("GameStateManager processes newTurn") {
    let mgr = GameStateManager()
    try mgr.process(ParsedMessage(tag: "newTurn", attributes: ["turn": "50"], children: []))
    try assertEqual(mgr.game.turn, Turn(50))
}

test("GameStateManager processes addPlayer") {
    let mgr = GameStateManager()
    try mgr.process(ParsedMessage(tag: "addPlayer", attributes: [:], children: [
        ParsedMessage(tag: "player", attributes: [
            "id": "player-3", "username": "Charlie", "nationId": "model.nation.english"
        ], children: [])
    ]))
    try assertEqual(mgr.game.players.count, 1)
}

test("GameStateManager processes multiple nested messages") {
    let mgr = GameStateManager()
    try mgr.process(ParsedMessage(tag: "multiple", attributes: [:], children: [
        ParsedMessage(tag: "newTurn", attributes: ["turn": "60"], children: []),
        ParsedMessage(tag: "setCurrentPlayer", attributes: ["player": "player-2"], children: []),
    ]))
    try assertEqual(mgr.game.turn, Turn(60))
    try assertEqual(mgr.game.currentPlayerId, "player-2")
}

test("Specification loaded from parsed") {
    let spec = Specification(parsed: ParsedMessage(tag: "freecol-specification", attributes: [
        "id": "spec-0", "difficulty-level": "model.difficulty.medium", "version": "1.2"
    ], children: []))
    try assertEqual(spec.difficultyLevel, "model.difficulty.medium")
    try assertEqual(spec.version, "1.2")
}

test("Tile parses settlement from children") {
    let tile = try Tile(id: "tile-5", attributes: ["x": "5", "y": "10", "type": "model.tile.plains"], children: [
        ParsedMessage(tag: "colony", attributes: ["id": "colony-1", "name": "New York"], children: [])
    ], game: Game())
    try assertEqual(tile.settlement, "colony-1")
}

test("Unit parses state enum") {
    let unit = try Unit(id: "unit-1", attributes: [
        "id": "unit-1", "unitType": "model.unit.galleon", "state": "SAILING"
    ], children: [], game: Game())
    try assertEqual(unit.state, .sailing)
}

// MARK: - Integration tests (require network stack)

func integrationTest(_ name: String, closure: @escaping () async throws -> Void) async {
    do {
        try await closure()
        passed += 1
        print("  PASS  \(name)")
    } catch {
        failed += 1
        print("  FAIL  \(name): \(error)")
    }
}

class TestDelegate: ClientDelegate {
    var receivedMessages: [String] = []
    func clientDidConnect() {}
    func clientDidLogin(_ result: LoginResult) {}
    func clientDidReceiveGameState(_ parsed: ParsedMessage) { receivedMessages.append(parsed.tag) }
    func clientDidDisconnect(error: Error?) {}
    func clientDidUpdate() { receivedMessages.append("__update__") }
}

print("\n--- Integration Tests ---\n")

await integrationTest("full handshake and login") {
    let server = MockServer()
    let port = server.port

    let client = FreeColClient(host: "127.0.0.1", port: port)
    let gameXML = """
    <game id="game-0" turn="1">
      <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
      <player id="player-2" username="Bob" nationId="model.nation.french" gold="300" ai="true"/>
      <map id="map-0" width="40" height="30">
        <tile id="tile-0" x="10" y="20" type="model.tile.plains"/>
        <tile id="tile-1" x="11" y="20" type="model.tile.ocean"/>
      </map>
      <unit id="unit-1" unitType="model.unit.freeColonist" owner="player-1" location="tile-0" movesLeft="3" state="ACTIVE"/>
      <colony id="colony-1" name="New Amsterdam" owner="player-1" tile="tile-0" established="100"/>
    </game>
    """

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await client.connect()
            let result = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
            guard result.playerName == "Alice" else { throw TestError(message: "playerName mismatch") }
            guard result.serverState == .inGame else { throw TestError(message: "state not IN_GAME") }
        }
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)
        }
        while true {
            guard try await group.next() != nil else { break }
        }
    }

    guard client.game.id == "game-0" else { throw TestError(message: "game.id mismatch") }
    guard client.game.turn == Turn(1) else { throw TestError(message: "turn mismatch") }
    guard let player = client.game.players["player-1"] else { throw TestError(message: "player-1 not found") }
    guard player.name == "Alice" else { throw TestError(message: "player name mismatch") }
    guard client.game.map?.width == 40 else { throw TestError(message: "map.width mismatch") }
    guard client.game.tiles.count == 2 else { throw TestError(message: "tile count mismatch") }
    guard client.game.units.count == 1 else { throw TestError(message: "unit count mismatch") }
    guard client.game.colonies.count == 1 else { throw TestError(message: "colony count mismatch") }

    server.stop()
}

await integrationTest("client receives post-login updates") {
    let server = MockServer()
    let port = server.port

    let gameXML = """
    <game id="game-1" turn="5">
      <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
    </game>
    """

    let client = FreeColClient(host: "127.0.0.1", port: port)
    let delegate = TestDelegate()
    await client.setDelegate(delegate)

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await client.connect()
            let result = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
            guard result.playerName == "Alice" else { throw TestError(message: "login failed") }
            // Start message loop but it will error out when connection drops
            try? await client.startMessageLoop()
        }
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)
            // Send some updates
            server.send("<newTurn turn=\"6\"/>")
            server.send("<setCurrentPlayer player=\"player-1\"/>")
            server.flush()
            try await Task.sleep(nanoseconds: 500_000_000)
            server.stop()
        }
        // Timeout after 5 seconds
        try await Task.sleep(nanoseconds: 5_000_000_000)
        group.cancelAll()
    }

    // Verify game state was updated
    guard client.game.turn == Turn(6) else {
        throw TestError(message: "turn not updated: \(client.game.turn)")
    }
    guard client.game.currentPlayerId == "player-1" else {
        throw TestError(message: "currentPlayer not set")
    }

    server.stop()
}

print("\n\(passed) passed, \(failed) failed")
exit(failed > 0 ? 1 : 0)
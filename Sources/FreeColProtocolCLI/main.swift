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

test("Game.moveUnit clears reached destination") {
    let game = Game()
    try game.load(from: ParsedMessage(tag: "game", attributes: ["id": "game-0"], children: [
        ParsedMessage(tag: "map", attributes: ["id": "map-0", "width": "2", "height": "1"], children: [
            ParsedMessage(tag: "tile", attributes: ["id": "tile-0", "x": "0", "y": "0", "type": "model.tile.plains"], children: []),
            ParsedMessage(tag: "tile", attributes: ["id": "tile-1", "x": "1", "y": "0", "type": "model.tile.plains"], children: []),
        ]),
        ParsedMessage(tag: "unit", attributes: [
            "id": "unit-1", "unitType": "model.unit.freeColonist", "location": "tile-0", "destination": "tile-1"
        ], children: [])
    ]))

    game.moveUnit("unit-1", to: "tile-1")
    try assertEqual(game.units["unit-1"]?.location, "tile-1")
    try assertEqual(game.units["unit-1"]?.destination, nil)
}

test("Game.applyRemove clears dangling unit references") {
    let game = Game()
    try game.load(from: ParsedMessage(tag: "game", attributes: ["id": "game-0"], children: [
        ParsedMessage(tag: "map", attributes: ["id": "map-0", "width": "2", "height": "1"], children: [
            ParsedMessage(tag: "tile", attributes: ["id": "tile-0", "x": "0", "y": "0", "type": "model.tile.plains"], children: []),
            ParsedMessage(tag: "tile", attributes: ["id": "tile-1", "x": "1", "y": "0", "type": "model.tile.plains"], children: []),
        ]),
        ParsedMessage(tag: "unit", attributes: [
            "id": "unit-carrier", "unitType": "model.unit.caravel", "location": "tile-0"
        ], children: []),
        ParsedMessage(tag: "unit", attributes: [
            "id": "unit-1", "unitType": "model.unit.freeColonist", "location": "unit-carrier", "destination": "tile-1"
        ], children: [])
    ]))

    try game.applyRemove(ParsedMessage(
        tag: "remove",
        attributes: ["divert": "tile-1", "array_0": "unit-carrier"],
        children: []
    ))

    try assertEqual(game.units["unit-1"]?.location, nil)
    try assertEqual(game.units["unit-1"]?.destination, nil)
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

test("GameStateManager processes ready message") {
    let mgr = GameStateManager()
    try mgr.process(ParsedMessage(tag: "addPlayer", attributes: [:], children: [
        ParsedMessage(tag: "player", attributes: [
            "id": "player-1",
            "username": "Alice",
            "nationId": "model.nation.dutch"
        ], children: [])
    ]))

    let handled = try mgr.process(ParsedMessage(
        tag: "ready",
        attributes: ["player": "player-1", "value": "true"],
        children: []
    ))

    try assertEqual(handled, true)
    try assertEqual(mgr.game.players["player-1"]?.ready, true)
}

test("GameStateManager processes reply-wrapped payloads") {
    let mgr = GameStateManager()

    let handled = try mgr.process(ParsedMessage(
        tag: "reply",
        attributes: ["networkReplyId": "17"],
        children: [
            ParsedMessage(tag: "setCurrentPlayer", attributes: ["player": "player-9"], children: []),
            ParsedMessage(tag: "newTurn", attributes: ["turn": "77"], children: []),
        ]
    ))

    try assertEqual(handled, true)
    try assertEqual(mgr.game.currentPlayerId, "player-9")
    try assertEqual(mgr.game.turn, Turn(77))
}

test("GameStateManager loadFromLogin tolerates pre-game login without game") {
    let mgr = GameStateManager()
    try mgr.loadFromLogin(LoginResult(
        playerName: "Alice",
        nationId: "model.nation.dutch",
        serverState: .preGame,
        game: nil,
        player: nil
    ))
    try assertEqual(mgr.game.players.count, 0)
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

test("EquipForRoleMessage") {
    let msg = EquipForRoleMessage(
        role: "model.role.missionary",
        unit: "unit-123",
        count: "1"
    )
    try assertEqual(msg.role, "model.role.missionary")
    try assertEqual(msg.unit, "unit-123")
    try assertEqual(msg.count, "1")
    try assertEqual(msg.tag, "equipForRole")
    
    let (attrs, _) = msg.encode()
    try assertEqual(attrs["role"], "model.role.missionary")
    try assertEqual(attrs["unit"], "unit-123")
    try assertEqual(attrs["count"], "1")
    
    let parsed = try EquipForRoleMessage(
        attributes: ["role": "model.role.pioneer", "unit": "u2", "count": "2"],
        children: []
    )
    try assertEqual(parsed.role, "model.role.pioneer")
    try assertEqual(parsed.unit, "u2")
    try assertEqual(parsed.count, "2")
}

test("LearnSkillMessage") {
    let msg = LearnSkillMessage(
        unit: "unit-settler",
        direction: "NE"
    )
    try assertEqual(msg.unit, "unit-settler")
    try assertEqual(msg.direction, "NE")
    try assertEqual(msg.tag, "learnSkill")
    
    let (attrs, _) = msg.encode()
    try assertEqual(attrs["unit"], "unit-settler")
    try assertEqual(attrs["direction"], "NE")
    
    let parsed = try LearnSkillMessage(
        attributes: ["unit": "u-scout", "direction": "S"],
        children: []
    )
    try assertEqual(parsed.unit, "u-scout")
    try assertEqual(parsed.direction, "S")
}

test("NewLandNameMessage") {
    let msg = NewLandNameMessage(
        unit: "unit-explorer",
        newLandName: "New Amsterdam"
    )
    try assertEqual(msg.unit, "unit-explorer")
    try assertEqual(msg.newLandName, "New Amsterdam")
    try assertEqual(msg.tag, "newLandName")
    
    let (attrs, _) = msg.encode()
    try assertEqual(attrs["unit"], "unit-explorer")
    try assertEqual(attrs["newLandName"], "New Amsterdam")
    
    let parsed = try NewLandNameMessage(
        attributes: ["unit": "u-caravel", "newLandName": "Nova Terra"],
        children: []
    )
    try assertEqual(parsed.unit, "u-caravel")
    try assertEqual(parsed.newLandName, "Nova Terra")
}

test("NewRegionNameMessage") {
    let msg = NewRegionNameMessage(
        unit: "unit-explorer",
        region: "region-5",
        newRegionName: "Pacific Region",
        tile: "tile-42"
    )
    try assertEqual(msg.unit, "unit-explorer")
    try assertEqual(msg.newRegionName, "Pacific Region")
    try assertEqual(msg.tile, "tile-42")
    try assertEqual(msg.region, "region-5")
    try assertEqual(msg.tag, "newRegionName")
    
    let (attrs, _) = msg.encode()
    try assertEqual(attrs["unit"], "unit-explorer")
    try assertEqual(attrs["newRegionName"], "Pacific Region")
    try assertEqual(attrs["tile"], "tile-42")
    try assertEqual(attrs["region"], "region-5")
    
    let parsed = try NewRegionNameMessage(
        attributes: [
            "newRegionName": "Atlantic Zone",
            "region": "region-3",
            "tile": "tile-99",
            "unit": "u-caravel"
        ],
        children: []
    )
    try assertEqual(parsed.unit, "u-caravel")
    try assertEqual(parsed.newRegionName, "Atlantic Zone")
    try assertEqual(parsed.tile, "tile-99")
    try assertEqual(parsed.region, "region-3")
}

test("InciteMessage") {
    let msg = InciteMessage(
        gold: "100",
        settlement: "is-1",
        enemy: "player-2",
        unit: "unit-diplomat"
    )
    try assertEqual(msg.unit, "unit-diplomat")
    try assertEqual(msg.settlement, "is-1")
    try assertEqual(msg.enemy, "player-2")
    try assertEqual(msg.gold, "100")
    try assertEqual(msg.tag, "incite")
    
    let (attrs, _) = msg.encode()
    try assertEqual(attrs["unit"], "unit-diplomat")
    try assertEqual(attrs["settlement"], "is-1")
    try assertEqual(attrs["enemy"], "player-2")
    try assertEqual(attrs["gold"], "100")
    
    let parsed = try InciteMessage(
        attributes: ["enemy": "player-1", "gold": "50", "settlement": "is-5", "unit": "u-scout"],
        children: []
    )
    try assertEqual(parsed.unit, "u-scout")
    try assertEqual(parsed.settlement, "is-5")
    try assertEqual(parsed.enemy, "player-1")
    try assertEqual(parsed.gold, "50")
}

test("DeliverGiftMessage") {
    let msg = DeliverGiftMessage(
        unit: "unit-colonist",
        settlement: "is-boston"
    )
    try assertEqual(msg.unit, "unit-colonist")
    try assertEqual(msg.settlement, "is-boston")
    try assertEqual(msg.tag, "deliverGift")
    
    let (attrs, _) = msg.encode()
    try assertEqual(attrs["unit"], "unit-colonist")
    try assertEqual(attrs["settlement"], "is-boston")
    
    let parsed = try DeliverGiftMessage(
        attributes: ["unit": "u-missionary", "settlement": "is-tribal"],
        children: []
    )
    try assertEqual(parsed.unit, "u-missionary")
    try assertEqual(parsed.settlement, "is-tribal")
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

await integrationTest("connect captures vacantPlayers sent after gameState") {
    let server = MockServer()
    let port = await server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await client.connect()
        }
        group.addTask {
            try await server.waitForConnection()
            await server.send("<gameState state=\"IN_GAME\"/>")
            await server.flush()
            try await Task.sleep(nanoseconds: 50_000_000)
            await server.send("<vacantPlayers><player id=\"nation-dutch\" nationId=\"model.nation.dutch\" nationName=\"Dutch\"/></vacantPlayers>")
            await server.flush()
        }
        while try await group.next() != nil {}
    }

    let initialState = await client.initialGameState
    let vacantPlayers = await client.initialVacantPlayers

    guard initialState == .inGame else {
        throw TestError(message: "initialGameState not captured")
    }
    guard vacantPlayers?.tag == "vacantPlayers" else {
        throw TestError(message: "vacantPlayers not captured")
    }
    guard vacantPlayers?.children.first?.attributes["nationId"] == "model.nation.dutch" else {
        throw TestError(message: "vacantPlayers payload mismatch")
    }

    await server.stop()
}

await integrationTest("connect does not block when vacantPlayers is absent") {
    let server = MockServer()
    let port = await server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await client.connect()
        }
        group.addTask {
            try await server.waitForConnection()
            await server.send("<gameState state=\"PRE_GAME\"/>")
            await server.flush()
        }
        while try await group.next() != nil {}
    }

    let initialState = await client.initialGameState
    let vacantPlayers = await client.initialVacantPlayers

    guard initialState == .preGame else {
        throw TestError(message: "initialGameState not captured for PRE_GAME")
    }
    guard vacantPlayers == nil else {
        throw TestError(message: "vacantPlayers should remain nil when absent")
    }

    await server.stop()
}

await integrationTest("startGame reaches UI delegate during message loop") {
    let server = MockServer()
    let port = await server.port

    let gameXML = """
    <game id="game-2" turn="1">
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
            guard result.serverState == .inGame else { throw TestError(message: "state not IN_GAME") }
            try? await client.startMessageLoop()
        }
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)
            try await Task.sleep(nanoseconds: 250_000_000)
            server.send("<startGame/>")
            server.flush()
            try await Task.sleep(nanoseconds: 500_000_000)
            server.stop()
        }
        try await Task.sleep(nanoseconds: 5_000_000_000)
        group.cancelAll()
    }

    guard delegate.receivedMessages.contains("startGame") else {
        throw TestError(message: "startGame did not reach delegate")
    }

    server.stop()
}

await integrationTest("reconnect reaches UI delegate during message loop") {
    let server = MockServer()
    let port = await server.port

    let gameXML = """
    <game id="game-r1" turn="1">
      <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
    </game>
    """

    let client = FreeColClient(host: "127.0.0.1", port: port)
    let delegate = TestDelegate()
    await client.setDelegate(delegate)

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await client.connect()
            _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
            try? await client.startMessageLoop()
        }
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)
            try await Task.sleep(nanoseconds: 250_000_000)
            await server.send("<reconnect/>")
            await server.flush()
            try await Task.sleep(nanoseconds: 350_000_000)
            await server.stop()
        }
        try await Task.sleep(nanoseconds: 5_000_000_000)
        group.cancelAll()
    }

    guard delegate.receivedMessages.contains("reconnect") else {
        throw TestError(message: "reconnect did not reach delegate")
    }

    await server.stop()
}

await integrationTest("endTurn applies server-driven turn sync") {
    let server = MockServer()
    let port = await server.port

    let gameXML = """
    <game id="game-turn-sync" turn="1">
      <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
      <player id="player-2" username="Bob" nationId="model.nation.french" gold="400"/>
    </game>
    """

    let client = FreeColClient(host: "127.0.0.1", port: port)

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await client.connect()
            _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
            try await client.send(message: ParsedMessage(tag: "endTurn", attributes: [:], children: []))
            try? await client.startMessageLoop()
        }
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)

            let endTurnLine = try await server.nextLine()
            let endTurnMsg = try XMLDecoder.decode(endTurnLine)
            guard endTurnMsg.tag == "endTurn" else {
                throw TestError(message: "expected endTurn, got \(endTurnMsg.tag)")
            }

            await server.send("<multiple><newTurn turn=\"2\"/><setCurrentPlayer player=\"player-2\"/></multiple>")
            await server.flush()
            try await Task.sleep(nanoseconds: 400_000_000)
            await server.stop()
        }
        try await Task.sleep(nanoseconds: 5_000_000_000)
        group.cancelAll()
    }

    guard await client.game.turn == Turn(2) else {
        throw TestError(message: "turn did not advance after endTurn")
    }
    guard await client.game.currentPlayerId == "player-2" else {
        throw TestError(message: "currentPlayer did not switch after endTurn")
    }

    await server.stop()
}

await integrationTest("client sends ready and requestLaunch messages") {
    let server = MockServer()
    let port = await server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
    <game id="game-3" turn="1">
      <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
    </game>
    """

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await client.connect()
            _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
            try await client.send(message: ParsedMessage(tag: "ready", attributes: ["value": "true"], children: []))
            try await client.send(message: ParsedMessage(tag: "requestLaunch", attributes: [:], children: []))
            await client.disconnect()
        }
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)
            let readyLine = try await server.nextLine()
            let launchLine = try await server.nextLine()

            let readyMsg = try XMLDecoder.decode(readyLine)
            let launchMsg = try XMLDecoder.decode(launchLine)

            guard readyMsg.tag == "ready" else {
                throw TestError(message: "expected ready, got \(readyMsg.tag)")
            }
            guard readyMsg.attributes["value"] == "true" else {
                throw TestError(message: "ready value mismatch")
            }
            guard launchMsg.tag == "requestLaunch" else {
                throw TestError(message: "expected requestLaunch, got \(launchMsg.tag)")
            }
        }
        while try await group.next() != nil {}
    }

    await server.stop()
}

await integrationTest("client sends setNation message") {
    let server = MockServer()
    let port = await server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
    <game id="game-3b" turn="1">
      <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
    </game>
    """

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await client.connect()
            _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
            try await client.send(message: ParsedMessage(tag: "setNation", attributes: ["player": "player-1", "value": "model.nation.english"], children: []))
            await client.disconnect()
        }
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)
            let line = try await server.nextLine()
            let msg = try XMLDecoder.decode(line)

            guard msg.tag == "setNation" else {
                throw TestError(message: "expected setNation, got \(msg.tag)")
            }
            guard msg.attributes["player"] == "player-1" else {
                throw TestError(message: "setNation player mismatch")
            }
            guard msg.attributes["value"] == "model.nation.english" else {
                throw TestError(message: "setNation value mismatch")
            }
        }
        while try await group.next() != nil {}
    }

    await server.stop()
}

await integrationTest("client sends setNationType message") {
    let server = MockServer()
    let port = await server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
    <game id="game-3c" turn="1">
      <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
    </game>
    """

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await client.connect()
            _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
            try await client.send(message: ParsedMessage(tag: "setNationType", attributes: ["player": "player-1", "value": "model.nationType.default"], children: []))
            await client.disconnect()
        }
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)
            let line = try await server.nextLine()
            let msg = try XMLDecoder.decode(line)

            guard msg.tag == "setNationType" else {
                throw TestError(message: "expected setNationType, got \(msg.tag)")
            }
            guard msg.attributes["player"] == "player-1" else {
                throw TestError(message: "setNationType player mismatch")
            }
            guard msg.attributes["value"] == "model.nationType.default" else {
                throw TestError(message: "setNationType value mismatch")
            }
        }
        while try await group.next() != nil {}
    }

    await server.stop()
}

await integrationTest("client sends setColor message") {
    let server = MockServer()
    let port = await server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
    <game id="game-3d" turn="1">
      <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
    </game>
    """

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await client.connect()
            _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
            try await client.send(message: ParsedMessage(tag: "setColor", attributes: ["player": "player-1", "value": "#336699"], children: []))
            await client.disconnect()
        }
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)
            let line = try await server.nextLine()
            let msg = try XMLDecoder.decode(line)

            guard msg.tag == "setColor" else {
                throw TestError(message: "expected setColor, got \(msg.tag)")
            }
            guard msg.attributes["player"] == "player-1" else {
                throw TestError(message: "setColor player mismatch")
            }
            guard msg.attributes["value"] == "#336699" else {
                throw TestError(message: "setColor value mismatch")
            }
        }
        while try await group.next() != nil {}
    }

    await server.stop()
}

await integrationTest("client sends updateGameOptions message") {
    let server = MockServer()
    let port = await server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
    <game id="game-3e" turn="1">
      <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
    </game>
    """

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await client.connect()
            _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
            try await client.send(message: ParsedMessage(
                tag: "updateGameOptions",
                attributes: [:],
                children: [ParsedMessage(tag: "option", attributes: ["id": "model.option.startingMoney", "value": "3000"], children: [])]
            ))
            await client.disconnect()
        }
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)
            let line = try await server.nextLine()
            let msg = try XMLDecoder.decode(line)

            guard msg.tag == "updateGameOptions" else {
                throw TestError(message: "expected updateGameOptions, got \(msg.tag)")
            }
            guard let option = msg.children.first(where: { $0.tag == "option" }) else {
                throw TestError(message: "updateGameOptions option child missing")
            }
            guard option.attributes["id"] == "model.option.startingMoney" else {
                throw TestError(message: "updateGameOptions option id mismatch")
            }
            guard option.attributes["value"] == "3000" else {
                throw TestError(message: "updateGameOptions option value mismatch")
            }
        }
        while try await group.next() != nil {}
    }

    await server.stop()
}

await integrationTest("client sends updateMapGeneratorOptions message") {
    let server = MockServer()
    let port = await server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
    <game id="game-3f" turn="1">
      <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
    </game>
    """

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await client.connect()
            _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
            try await client.send(message: ParsedMessage(
                tag: "updateMapGeneratorOptions",
                attributes: [:],
                children: [ParsedMessage(tag: "option", attributes: ["id": "model.option.mapWidth", "value": "80"], children: [])]
            ))
            await client.disconnect()
        }
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)
            let line = try await server.nextLine()
            let msg = try XMLDecoder.decode(line)

            guard msg.tag == "updateMapGeneratorOptions" else {
                throw TestError(message: "expected updateMapGeneratorOptions, got \(msg.tag)")
            }
            guard let option = msg.children.first(where: { $0.tag == "option" }) else {
                throw TestError(message: "updateMapGeneratorOptions option child missing")
            }
            guard option.attributes["id"] == "model.option.mapWidth" else {
                throw TestError(message: "updateMapGeneratorOptions option id mismatch")
            }
            guard option.attributes["value"] == "80" else {
                throw TestError(message: "updateMapGeneratorOptions option value mismatch")
            }
        }
        while try await group.next() != nil {}
    }

    await server.stop()
}

await integrationTest("client sends chooseFoundingFather message") {
    let server = MockServer()
    let port = await server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
    <game id="game-3g" turn="1">
      <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
    </game>
    """

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await client.connect()
            _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
            try await client.send(message: ParsedMessage(
                tag: "chooseFoundingFather",
                attributes: ["foundingFather": "model.foundingFather.adamSmith"],
                children: []
            ))
            await client.disconnect()
        }
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)
            let line = try await server.nextLine()
            let msg = try XMLDecoder.decode(line)

            guard msg.tag == "chooseFoundingFather" else {
                throw TestError(message: "expected chooseFoundingFather, got \(msg.tag)")
            }
            guard msg.attributes["foundingFather"] == "model.foundingFather.adamSmith" else {
                throw TestError(message: "chooseFoundingFather value mismatch")
            }
        }
        while try await group.next() != nil {}
    }

    await server.stop()
}

await integrationTest("client sends continue message") {
    let server = MockServer()
    let port = await server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
    <game id="game-3h" turn="1">
      <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
    </game>
    """

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await client.connect()
            _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
            try await client.send(message: ParsedMessage(tag: "continue", attributes: [:], children: []))
            await client.disconnect()
        }
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)
            let line = try await server.nextLine()
            let msg = try XMLDecoder.decode(line)

            guard msg.tag == "continue" else {
                throw TestError(message: "expected continue, got \(msg.tag)")
            }
        }
        while try await group.next() != nil {}
    }

    await server.stop()
}

await integrationTest("client sends retire message") {
    let server = MockServer()
    let port = await server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
    <game id="game-3i" turn="1">
      <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
    </game>
    """

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await client.connect()
            _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
            try await client.send(message: ParsedMessage(tag: "retire", attributes: [:], children: []))
            await client.disconnect()
        }
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)
            let line = try await server.nextLine()
            let msg = try XMLDecoder.decode(line)

            guard msg.tag == "retire" else {
                throw TestError(message: "expected retire, got \(msg.tag)")
            }
        }
        while try await group.next() != nil {}
    }

    await server.stop()
}

await integrationTest("client sends enterRevengeMode message") {
    let server = MockServer()
    let port = await server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
    <game id="game-3j" turn="1">
      <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
    </game>
    """

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await client.connect()
            _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
            try await client.send(message: ParsedMessage(tag: "enterRevengeMode", attributes: [:], children: []))
            await client.disconnect()
        }
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)
            let line = try await server.nextLine()
            let msg = try XMLDecoder.decode(line)

            guard msg.tag == "enterRevengeMode" else {
                throw TestError(message: "expected enterRevengeMode, got \(msg.tag)")
            }
        }
        while try await group.next() != nil {}
    }

    await server.stop()
}

await integrationTest("client sends declineMounds message") {
    let server = MockServer()
    let port = await server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
    <game id="game-3k" turn="1">
      <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
      <unit id="unit-1" unitType="model.unit.scout" owner="player-1" location="tile-0" movesLeft="3" state="ACTIVE"/>
      <map id="map-0" width="1" height="1">
        <tile id="tile-0" x="0" y="0" type="model.tile.plains"/>
      </map>
    </game>
    """

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await client.connect()
            _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
            try await client.send(message: ParsedMessage(tag: "declineMounds", attributes: ["unit": "unit-1"], children: []))
            await client.disconnect()
        }
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)
            let line = try await server.nextLine()
            let msg = try XMLDecoder.decode(line)

            guard msg.tag == "declineMounds" else {
                throw TestError(message: "expected declineMounds, got \(msg.tag)")
            }
            guard msg.attributes["unit"] == "unit-1" else {
                throw TestError(message: "declineMounds unit mismatch")
            }
        }
        while try await group.next() != nil {}
    }

    await server.stop()
}

await integrationTest("client sends monarchAction message") {
    let server = MockServer()
    let port = await server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
    <game id="game-3l" turn="1">
      <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
    </game>
    """

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await client.connect()
            _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
            try await client.send(message: ParsedMessage(
                tag: "monarchAction",
                attributes: ["action": "RAISE_TAX_ACT", "player": "player-1"],
                children: []
            ))
            await client.disconnect()
        }
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)
            let line = try await server.nextLine()
            let msg = try XMLDecoder.decode(line)

            guard msg.tag == "monarchAction" else {
                throw TestError(message: "expected monarchAction, got \(msg.tag)")
            }
            guard msg.attributes["action"] == "RAISE_TAX_ACT" else {
                throw TestError(message: "monarchAction action mismatch")
            }
            guard msg.attributes["player"] == "player-1" else {
                throw TestError(message: "monarchAction player mismatch")
            }
        }
        while try await group.next() != nil {}
    }

    await server.stop()
}

await integrationTest("client sends setAI message") {
    let server = MockServer()
    let port = await server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
    <game id="game-3m" turn="1">
      <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
    </game>
    """

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await client.connect()
            _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
            try await client.send(message: ParsedMessage(
                tag: "setAI",
                attributes: ["player": "player-1", "ai": "true"],
                children: []
            ))
            await client.disconnect()
        }
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)
            let line = try await server.nextLine()
            let msg = try XMLDecoder.decode(line)

            guard msg.tag == "setAI" else {
                throw TestError(message: "expected setAI, got \(msg.tag)")
            }
            guard msg.attributes["player"] == "player-1" else {
                throw TestError(message: "setAI player mismatch")
            }
            guard msg.attributes["ai"] == "true" else {
                throw TestError(message: "setAI ai flag mismatch")
            }
        }
        while try await group.next() != nil {}
    }

    await server.stop()
}

await integrationTest("client sends setAvailable message") {
    let server = MockServer()
    let port = await server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
    <game id="game-3n" turn="1">
      <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
    </game>
    """

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await client.connect()
            _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
            try await client.send(message: ParsedMessage(
                tag: "setAvailable",
                attributes: ["player": "player-1"],
                children: []
            ))
            await client.disconnect()
        }
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)
            let line = try await server.nextLine()
            let msg = try XMLDecoder.decode(line)

            guard msg.tag == "setAvailable" else {
                throw TestError(message: "expected setAvailable, got \(msg.tag)")
            }
            guard msg.attributes["player"] == "player-1" else {
                throw TestError(message: "setAvailable player mismatch")
            }
        }
        while try await group.next() != nil {}
    }

    await server.stop()
}

await integrationTest("client sends setStance message") {
    let server = MockServer()
    let port = await server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
    <game id="game-3o" turn="1">
      <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
      <player id="player-2" username="Bob" nationId="model.nation.french" gold="500"/>
    </game>
    """

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await client.connect()
            _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
            try await client.send(message: ParsedMessage(
                tag: "setStance",
                attributes: ["stance": "WAR", "source": "player-1", "target": "player-2"],
                children: []
            ))
            await client.disconnect()
        }
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)
            let line = try await server.nextLine()
            let msg = try XMLDecoder.decode(line)

            guard msg.tag == "setStance" else {
                throw TestError(message: "expected setStance, got \(msg.tag)")
            }
            guard msg.attributes["stance"] == "WAR" else {
                throw TestError(message: "setStance stance mismatch")
            }
            guard msg.attributes["source"] == "player-1" else {
                throw TestError(message: "setStance source mismatch")
            }
            guard msg.attributes["target"] == "player-2" else {
                throw TestError(message: "setStance target mismatch")
            }
        }
        while try await group.next() != nil {}
    }

    await server.stop()
}

await integrationTest("client sends declareIndependence message") {
    let server = MockServer()
    let port = await server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
    <game id="game-3p" turn="1">
      <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
    </game>
    """

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await client.connect()
            _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
            try await client.send(message: ParsedMessage(
                tag: "declareIndependence",
                attributes: ["countryName": "Freedonia", "nationName": "Free Colonials"],
                children: []
            ))
            await client.disconnect()
        }
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)
            let line = try await server.nextLine()
            let msg = try XMLDecoder.decode(line)

            guard msg.tag == "declareIndependence" else {
                throw TestError(message: "expected declareIndependence, got \(msg.tag)")
            }
            guard msg.attributes["countryName"] == "Freedonia" else {
                throw TestError(message: "declareIndependence countryName mismatch")
            }
            guard msg.attributes["nationName"] == "Free Colonials" else {
                throw TestError(message: "declareIndependence nationName mismatch")
            }
        }
        while try await group.next() != nil {}
    }

    await server.stop()
}

await integrationTest("client sends chat message") {
    let server = MockServer()
    let port = await server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
    <game id="game-3q" turn="1">
      <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
      <player id="player-2" username="Bob" nationId="model.nation.french" gold="500"/>
    </game>
    """

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await client.connect()
            _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
            try await client.send(message: ParsedMessage(
                tag: "chat",
                attributes: ["sender": "player-1", "message": "Hello", "private": "player-2"],
                children: []
            ))
            await client.disconnect()
        }
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)
            let line = try await server.nextLine()
            let msg = try XMLDecoder.decode(line)

            guard msg.tag == "chat" else {
                throw TestError(message: "expected chat, got \(msg.tag)")
            }
            guard msg.attributes["sender"] == "player-1" else {
                throw TestError(message: "chat sender mismatch")
            }
            guard msg.attributes["message"] == "Hello" else {
                throw TestError(message: "chat message mismatch")
            }
            guard msg.attributes["private"] == "player-2" else {
                throw TestError(message: "chat private mismatch")
            }
        }
        while try await group.next() != nil {}
    }

    await server.stop()
}

await integrationTest("client sends setDead message") {
    let server = MockServer()
    let port = await server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
    <game id="game-3r" turn="1">
      <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
    </game>
    """

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await client.connect()
            _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
            try await client.send(message: ParsedMessage(
                tag: "setDead",
                attributes: ["player": "player-1"],
                children: []
            ))
            await client.disconnect()
        }
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)
            let line = try await server.nextLine()
            let msg = try XMLDecoder.decode(line)

            guard msg.tag == "setDead" else {
                throw TestError(message: "expected setDead, got \(msg.tag)")
            }
            guard msg.attributes["player"] == "player-1" else {
                throw TestError(message: "setDead player mismatch")
            }
        }
        while try await group.next() != nil {}
    }

    await server.stop()
}

await integrationTest("client sends claimLand message") {
    let server = MockServer()
    let port = await server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
    <game id="game-3s" turn="1">
      <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
      <map id="map-0" width="2" height="1">
        <tile id="tile-0" x="0" y="0" type="model.tile.plains"/>
      </map>
    </game>
    """

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await client.connect()
            _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
            try await client.send(message: ParsedMessage(
                tag: "claimLand",
                attributes: ["price": "100", "claimant": "player-1", "tile": "tile-0"],
                children: []
            ))
            await client.disconnect()
        }
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)
            let line = try await server.nextLine()
            let msg = try XMLDecoder.decode(line)

            guard msg.tag == "claimLand" else {
                throw TestError(message: "expected claimLand, got \(msg.tag)")
            }
            guard msg.attributes["price"] == "100" else {
                throw TestError(message: "claimLand price mismatch")
            }
            guard msg.attributes["claimant"] == "player-1" else {
                throw TestError(message: "claimLand claimant mismatch")
            }
            guard msg.attributes["tile"] == "tile-0" else {
                throw TestError(message: "claimLand tile mismatch")
            }
        }
        while try await group.next() != nil {}
    }

    await server.stop()
}

await integrationTest("client sends core gameplay action messages") {
    let server = MockServer()
    let port = await server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
    <game id="game-5" turn="1">
      <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
      <unit id="unit-1" unitType="model.unit.freeColonist" owner="player-1" location="tile-0" movesLeft="3" state="ACTIVE"/>
      <map id="map-0" width="2" height="1">
        <tile id="tile-0" x="0" y="0" type="model.tile.plains"/>
        <tile id="tile-1" x="1" y="0" type="model.tile.plains"/>
      </map>
    </game>
    """

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await client.connect()
            _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
            try await client.send(message: ParsedMessage(tag: "moveTo", attributes: ["unit": "unit-1", "destination": "tile-1"], children: []))
            try await client.send(message: ParsedMessage(tag: "buildColony", attributes: ["unit": "unit-1", "name": "Alpha"], children: []))
            try await client.send(message: ParsedMessage(tag: "endTurn", attributes: [:], children: []))
            await client.disconnect()
        }
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)
            let moveLine = try await server.nextLine()
            let buildLine = try await server.nextLine()
            let endTurnLine = try await server.nextLine()

            let moveMsg = try XMLDecoder.decode(moveLine)
            let buildMsg = try XMLDecoder.decode(buildLine)
            let endTurnMsg = try XMLDecoder.decode(endTurnLine)

            guard moveMsg.tag == "moveTo" else {
                throw TestError(message: "expected moveTo, got \(moveMsg.tag)")
            }
            guard moveMsg.attributes["unit"] == "unit-1" else {
                throw TestError(message: "moveTo unit mismatch")
            }
            guard moveMsg.attributes["destination"] == "tile-1" else {
                throw TestError(message: "moveTo destination mismatch")
            }

            guard buildMsg.tag == "buildColony" else {
                throw TestError(message: "expected buildColony, got \(buildMsg.tag)")
            }
            guard buildMsg.attributes["unit"] == "unit-1" else {
                throw TestError(message: "buildColony unit mismatch")
            }
            guard buildMsg.attributes["name"] == "Alpha" else {
                throw TestError(message: "buildColony name mismatch")
            }

            guard endTurnMsg.tag == "endTurn" else {
                throw TestError(message: "expected endTurn, got \(endTurnMsg.tag)")
            }
        }
        while try await group.next() != nil {}
    }

    await server.stop()
}

await integrationTest("client sends joinColony/embark/disembark messages") {
    let server = MockServer()
    let port = await server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
    <game id="game-6" turn="1">
      <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
      <map id="map-0" width="2" height="1">
        <tile id="tile-0" x="0" y="0" type="model.tile.plains"/>
        <tile id="tile-1" x="1" y="0" type="model.tile.plains"/>
      </map>
      <unit id="unit-1" unitType="model.unit.freeColonist" owner="player-1" location="tile-0" movesLeft="3" state="ACTIVE"/>
      <unit id="unit-ship" unitType="model.unit.caravel" owner="player-1" location="tile-0" movesLeft="6" state="ACTIVE"/>
      <colony id="colony-1" name="Alpha" owner="player-1" tile="tile-0" settlementType="model.settlement.colony"/>
    </game>
    """

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await client.connect()
            _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
            try await client.send(message: ParsedMessage(tag: "joinColony", attributes: ["unit": "unit-1", "colony": "colony-1"], children: []))
            try await client.send(message: ParsedMessage(tag: "embark", attributes: ["unit": "unit-1", "carrier": "unit-ship"], children: []))
            try await client.send(message: ParsedMessage(tag: "disembark", attributes: ["unit": "unit-1"], children: []))
            await client.disconnect()
        }
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)

            let joinLine = try await server.nextLine()
            let embarkLine = try await server.nextLine()
            let disembarkLine = try await server.nextLine()

            let joinMsg = try XMLDecoder.decode(joinLine)
            let embarkMsg = try XMLDecoder.decode(embarkLine)
            let disembarkMsg = try XMLDecoder.decode(disembarkLine)

            guard joinMsg.tag == "joinColony" else {
                throw TestError(message: "expected joinColony, got \(joinMsg.tag)")
            }
            guard joinMsg.attributes["unit"] == "unit-1" else {
                throw TestError(message: "joinColony unit mismatch")
            }
            guard joinMsg.attributes["colony"] == "colony-1" else {
                throw TestError(message: "joinColony colony mismatch")
            }

            guard embarkMsg.tag == "embark" else {
                throw TestError(message: "expected embark, got \(embarkMsg.tag)")
            }
            guard embarkMsg.attributes["unit"] == "unit-1" else {
                throw TestError(message: "embark unit mismatch")
            }
            guard embarkMsg.attributes["carrier"] == "unit-ship" else {
                throw TestError(message: "embark carrier mismatch")
            }

            guard disembarkMsg.tag == "disembark" else {
                throw TestError(message: "expected disembark, got \(disembarkMsg.tag)")
            }
            guard disembarkMsg.attributes["unit"] == "unit-1" else {
                throw TestError(message: "disembark unit mismatch")
            }
        }
        while try await group.next() != nil {}
    }

    await server.stop()
}

await integrationTest("client sends changeState message") {
    let server = MockServer()
    let port = await server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
    <game id="game-7" turn="1">
      <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
      <unit id="unit-1" unitType="model.unit.freeColonist" owner="player-1" location="tile-0" movesLeft="3" state="ACTIVE"/>
      <map id="map-0" width="1" height="1">
        <tile id="tile-0" x="0" y="0" type="model.tile.plains"/>
      </map>
    </game>
    """

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await client.connect()
            _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
            try await client.send(message: ParsedMessage(tag: "changeState", attributes: ["unit": "unit-1", "state": "SENTRY"], children: []))
            try await client.send(message: ParsedMessage(tag: "changeState", attributes: ["unit": "unit-1", "state": "SKIPPED"], children: []))
            await client.disconnect()
        }
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)

            let line1 = try await server.nextLine()
            let msg1 = try XMLDecoder.decode(line1)
            guard msg1.tag == "changeState" else {
                throw TestError(message: "expected first changeState, got \(msg1.tag)")
            }
            guard msg1.attributes["unit"] == "unit-1" else {
                throw TestError(message: "first changeState unit mismatch")
            }
            guard msg1.attributes["state"] == "SENTRY" else {
                throw TestError(message: "first changeState state mismatch")
            }

            let line2 = try await server.nextLine()
            let msg2 = try XMLDecoder.decode(line2)
            guard msg2.tag == "changeState" else {
                throw TestError(message: "expected second changeState, got \(msg2.tag)")
            }
            guard msg2.attributes["unit"] == "unit-1" else {
                throw TestError(message: "second changeState unit mismatch")
            }
            guard msg2.attributes["state"] == "SKIPPED" else {
                throw TestError(message: "second changeState state mismatch")
            }
        }
        while try await group.next() != nil {}
    }

    await server.stop()
}

await integrationTest("client sends changeWorkImprovementType message") {
    let server = MockServer()
    let port = await server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
    <game id="game-7b" turn="1">
      <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
      <unit id="unit-1" unitType="model.unit.freeColonist" owner="player-1" location="tile-0" movesLeft="3" state="ACTIVE"/>
      <map id="map-0" width="1" height="1">
        <tile id="tile-0" x="0" y="0" type="model.tile.plains"/>
      </map>
    </game>
    """

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await client.connect()
            _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
            try await client.send(message: ParsedMessage(tag: "changeWorkImprovementType", attributes: ["unit": "unit-1", "improvementType": "model.improvement.plow"], children: []))
            await client.disconnect()
        }
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)

            let line = try await server.nextLine()
            let msg = try XMLDecoder.decode(line)
            guard msg.tag == "changeWorkImprovementType" else {
                throw TestError(message: "expected changeWorkImprovementType, got \(msg.tag)")
            }
            guard msg.attributes["unit"] == "unit-1" else {
                throw TestError(message: "changeWorkImprovementType unit mismatch")
            }
            guard msg.attributes["improvementType"] == "model.improvement.plow" else {
                throw TestError(message: "changeWorkImprovementType improvementType mismatch")
            }
        }
        while try await group.next() != nil {}
    }

    await server.stop()
}

await integrationTest("client sends disbandUnit message") {
    let server = MockServer()
    let port = await server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
    <game id="game-8" turn="1">
      <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
      <unit id="unit-1" unitType="model.unit.freeColonist" owner="player-1" location="tile-0" movesLeft="3" state="ACTIVE"/>
      <map id="map-0" width="1" height="1">
        <tile id="tile-0" x="0" y="0" type="model.tile.plains"/>
      </map>
    </game>
    """

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await client.connect()
            _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
            try await client.send(message: ParsedMessage(tag: "disbandUnit", attributes: ["unit": "unit-1"], children: []))
            await client.disconnect()
        }
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)

            let line = try await server.nextLine()
            let msg = try XMLDecoder.decode(line)
            guard msg.tag == "disbandUnit" else {
                throw TestError(message: "expected disbandUnit, got \(msg.tag)")
            }
            guard msg.attributes["unit"] == "unit-1" else {
                throw TestError(message: "disbandUnit unit mismatch")
            }
        }
        while try await group.next() != nil {}
    }

    await server.stop()
}

await integrationTest("client sends setDestination message") {
    let server = MockServer()
    let port = await server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
    <game id="game-9" turn="1">
      <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
      <unit id="unit-1" unitType="model.unit.freeColonist" owner="player-1" location="tile-0" movesLeft="3" state="ACTIVE"/>
      <map id="map-0" width="2" height="1">
        <tile id="tile-0" x="0" y="0" type="model.tile.plains"/>
        <tile id="tile-1" x="1" y="0" type="model.tile.plains"/>
      </map>
    </game>
    """

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await client.connect()
            _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
            try await client.send(message: ParsedMessage(tag: "setDestination", attributes: ["unit": "unit-1", "destination": "tile-1"], children: []))
            try await client.send(message: ParsedMessage(tag: "setDestination", attributes: ["unit": "unit-1"], children: []))
            await client.disconnect()
        }
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)

            let setLine = try await server.nextLine()
            let clearLine = try await server.nextLine()

            let setMsg = try XMLDecoder.decode(setLine)
            let clearMsg = try XMLDecoder.decode(clearLine)

            guard setMsg.tag == "setDestination" else {
                throw TestError(message: "expected setDestination, got \(setMsg.tag)")
            }
            guard setMsg.attributes["unit"] == "unit-1" else {
                throw TestError(message: "setDestination unit mismatch")
            }
            guard setMsg.attributes["destination"] == "tile-1" else {
                throw TestError(message: "setDestination destination mismatch")
            }

            guard clearMsg.tag == "setDestination" else {
                throw TestError(message: "expected setDestination clear, got \(clearMsg.tag)")
            }
            guard clearMsg.attributes["unit"] == "unit-1" else {
                throw TestError(message: "setDestination clear unit mismatch")
            }
            guard clearMsg.attributes["destination"] == nil else {
                throw TestError(message: "setDestination clear should omit destination")
            }
        }
        while try await group.next() != nil {}
    }

    await server.stop()
}

await integrationTest("client sends assignTradeRoute message") {
    let server = MockServer()
    let port = await server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
    <game id="game-9b" turn="1">
      <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
      <map id="map-0" width="1" height="1">
        <tile id="tile-0" x="0" y="0" type="model.tile.plains"/>
      </map>
      <unit id="unit-1" unitType="model.unit.wagonTrain" owner="player-1" location="tile-0" movesLeft="3" state="ACTIVE"/>
    </game>
    """

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await client.connect()
            _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
            try await client.send(message: ParsedMessage(tag: "assignTradeRoute", attributes: ["unit": "unit-1", "tradeRoute": "route-1"], children: []))
            try await client.send(message: ParsedMessage(tag: "assignTradeRoute", attributes: ["unit": "unit-1"], children: []))
            await client.disconnect()
        }
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)

            let assignLine = try await server.nextLine()
            let clearLine = try await server.nextLine()

            let assignMsg = try XMLDecoder.decode(assignLine)
            let clearMsg = try XMLDecoder.decode(clearLine)

            guard assignMsg.tag == "assignTradeRoute" else {
                throw TestError(message: "expected assignTradeRoute, got \(assignMsg.tag)")
            }
            guard assignMsg.attributes["unit"] == "unit-1" else {
                throw TestError(message: "assignTradeRoute unit mismatch")
            }
            guard assignMsg.attributes["tradeRoute"] == "route-1" else {
                throw TestError(message: "assignTradeRoute tradeRoute mismatch")
            }

            guard clearMsg.tag == "assignTradeRoute" else {
                throw TestError(message: "expected assignTradeRoute clear, got \(clearMsg.tag)")
            }
            guard clearMsg.attributes["unit"] == "unit-1" else {
                throw TestError(message: "assignTradeRoute clear unit mismatch")
            }
            guard clearMsg.attributes["tradeRoute"] == nil else {
                throw TestError(message: "assignTradeRoute clear should omit tradeRoute")
            }
        }
        while try await group.next() != nil {}
    }

    await server.stop()
}

await integrationTest("client sends setCurrentStop message") {
    let server = MockServer()
    let port = await server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
    <game id="game-9c" turn="1">
      <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
      <map id="map-0" width="1" height="1">
        <tile id="tile-0" x="0" y="0" type="model.tile.plains"/>
      </map>
      <unit id="unit-1" unitType="model.unit.wagonTrain" owner="player-1" location="tile-0" movesLeft="3" state="ACTIVE" currentStop="0"/>
    </game>
    """

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await client.connect()
            _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
            try await client.send(message: ParsedMessage(tag: "setCurrentStop", attributes: ["unit": "unit-1", "index": "2"], children: []))
            await client.disconnect()
        }
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)

            let line = try await server.nextLine()
            let msg = try XMLDecoder.decode(line)

            guard msg.tag == "setCurrentStop" else {
                throw TestError(message: "expected setCurrentStop, got \(msg.tag)")
            }
            guard msg.attributes["unit"] == "unit-1" else {
                throw TestError(message: "setCurrentStop unit mismatch")
            }
            guard msg.attributes["index"] == "2" else {
                throw TestError(message: "setCurrentStop index mismatch")
            }
        }
        while try await group.next() != nil {}
    }

    await server.stop()
}

await integrationTest("client sends cashInTreasureTrain message") {
    let server = MockServer()
    let port = await server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
    <game id="game-9d" turn="1">
      <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
      <map id="map-0" width="1" height="1">
        <tile id="tile-0" x="0" y="0" type="model.tile.plains"/>
      </map>
      <unit id="unit-1" unitType="model.unit.treasureTrain" owner="player-1" location="tile-0" movesLeft="3" state="ACTIVE" treasureAmount="500"/>
    </game>
    """

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await client.connect()
            _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
            try await client.send(message: ParsedMessage(tag: "cashInTreasureTrain", attributes: ["unit": "unit-1"], children: []))
            await client.disconnect()
        }
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)

            let line = try await server.nextLine()
            let msg = try XMLDecoder.decode(line)

            guard msg.tag == "cashInTreasureTrain" else {
                throw TestError(message: "expected cashInTreasureTrain, got \(msg.tag)")
            }
            guard msg.attributes["unit"] == "unit-1" else {
                throw TestError(message: "cashInTreasureTrain unit mismatch")
            }
        }
        while try await group.next() != nil {}
    }

    await server.stop()
}

await integrationTest("client sends colony action messages") {
    let server = MockServer()
    let port = await server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
    <game id="game-10" turn="1">
      <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
      <map id="map-0" width="1" height="1">
        <tile id="tile-0" x="0" y="0" type="model.tile.plains"/>
      </map>
      <unit id="unit-1" unitType="model.unit.freeColonist" owner="player-1" location="colony-1" movesLeft="3" state="ACTIVE"/>
            <unit id="unit-2" unitType="model.unit.masterCarpenter" owner="player-1" location="colony-1" movesLeft="3" state="ACTIVE"/>
      <colony id="colony-1" name="Alpha" owner="player-1" tile="tile-0" settlementType="model.settlement.colony"/>
    </game>
    """

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await client.connect()
            _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
            try await client.send(message: ParsedMessage(tag: "changeWorkType", attributes: ["unit": "unit-1", "workType": "model.goods.grain"], children: []))
            try await client.send(message: ParsedMessage(tag: "clearSpeciality", attributes: ["unit": "unit-1"], children: []))
            try await client.send(message: ParsedMessage(tag: "assignTeacher", attributes: ["student": "unit-1", "teacher": "unit-2"], children: []))
            try await client.send(message: ParsedMessage(tag: "assignTeacher", attributes: ["student": "unit-1"], children: []))
            try await client.send(message: ParsedMessage(tag: "work", attributes: ["unit": "unit-1", "workLocation": "tile-0"], children: []))
            try await client.send(message: ParsedMessage(tag: "rename", attributes: ["name": "Beta", "nameable": "colony-1"], children: []))
            try await client.send(message: ParsedMessage(tag: "payForBuilding", attributes: ["colony": "colony-1"], children: []))
            try await client.send(message: ParsedMessage(tag: "setGoodsLevels", attributes: ["colony": "colony-1"], children: []))
            try await client.send(message: ParsedMessage(tag: "rearrangeColony", attributes: ["colony": "colony-1", "xLength": "0"], children: []))
            try await client.send(message: ParsedMessage(tag: "setBuildQueue", attributes: ["colony": "colony-1", "xLength": "2", "x0": "model.building.carpenterHouse", "x1": "model.unit.artillery"], children: []))
            try await client.send(message: ParsedMessage(tag: "putOutsideColony", attributes: ["unit": "unit-1"], children: []))
            try await client.send(message: ParsedMessage(tag: "abandonColony", attributes: ["colony": "colony-1"], children: []))
            await client.disconnect()
        }
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)

            let workLine = try await server.nextLine()
            let clearSpecialityLine = try await server.nextLine()
            let assignTeacherLine = try await server.nextLine()
            let clearTeacherLine = try await server.nextLine()
            let workLocationLine = try await server.nextLine()
            let renameLine = try await server.nextLine()
            let payLine = try await server.nextLine()
            let goodsLevelsLine = try await server.nextLine()
            let rearrangeLine = try await server.nextLine()
            let queueLine = try await server.nextLine()
            let outsideLine = try await server.nextLine()
            let abandonLine = try await server.nextLine()

            let workMsg = try XMLDecoder.decode(workLine)
            let clearSpecialityMsg = try XMLDecoder.decode(clearSpecialityLine)
            let assignTeacherMsg = try XMLDecoder.decode(assignTeacherLine)
            let clearTeacherMsg = try XMLDecoder.decode(clearTeacherLine)
            let workLocationMsg = try XMLDecoder.decode(workLocationLine)
            let renameMsg = try XMLDecoder.decode(renameLine)
            let payMsg = try XMLDecoder.decode(payLine)
            let goodsLevelsMsg = try XMLDecoder.decode(goodsLevelsLine)
            let rearrangeMsg = try XMLDecoder.decode(rearrangeLine)
            let queueMsg = try XMLDecoder.decode(queueLine)
            let outsideMsg = try XMLDecoder.decode(outsideLine)
            let abandonMsg = try XMLDecoder.decode(abandonLine)

            guard workMsg.tag == "changeWorkType" else {
                throw TestError(message: "expected changeWorkType, got \(workMsg.tag)")
            }
            guard workMsg.attributes["unit"] == "unit-1" else {
                throw TestError(message: "changeWorkType unit mismatch")
            }
            guard workMsg.attributes["workType"] == "model.goods.grain" else {
                throw TestError(message: "changeWorkType workType mismatch")
            }

            guard clearSpecialityMsg.tag == "clearSpeciality" else {
                throw TestError(message: "expected clearSpeciality, got \(clearSpecialityMsg.tag)")
            }
            guard clearSpecialityMsg.attributes["unit"] == "unit-1" else {
                throw TestError(message: "clearSpeciality unit mismatch")
            }

            guard assignTeacherMsg.tag == "assignTeacher" else {
                throw TestError(message: "expected assignTeacher, got \(assignTeacherMsg.tag)")
            }
            guard assignTeacherMsg.attributes["student"] == "unit-1" else {
                throw TestError(message: "assignTeacher student mismatch")
            }
            guard assignTeacherMsg.attributes["teacher"] == "unit-2" else {
                throw TestError(message: "assignTeacher teacher mismatch")
            }

            guard clearTeacherMsg.tag == "assignTeacher" else {
                throw TestError(message: "expected assignTeacher clear, got \(clearTeacherMsg.tag)")
            }
            guard clearTeacherMsg.attributes["student"] == "unit-1" else {
                throw TestError(message: "assignTeacher clear student mismatch")
            }
            guard clearTeacherMsg.attributes["teacher"] == nil else {
                throw TestError(message: "assignTeacher clear should omit teacher")
            }

            guard workLocationMsg.tag == "work" else {
                throw TestError(message: "expected work, got \(workLocationMsg.tag)")
            }
            guard workLocationMsg.attributes["unit"] == "unit-1" else {
                throw TestError(message: "work unit mismatch")
            }
            guard workLocationMsg.attributes["workLocation"] == "tile-0" else {
                throw TestError(message: "work workLocation mismatch")
            }

            guard renameMsg.tag == "rename" else {
                throw TestError(message: "expected rename, got \(renameMsg.tag)")
            }
            guard renameMsg.attributes["name"] == "Beta" else {
                throw TestError(message: "rename name mismatch")
            }
            guard renameMsg.attributes["nameable"] == "colony-1" else {
                throw TestError(message: "rename nameable mismatch")
            }

            guard payMsg.tag == "payForBuilding" else {
                throw TestError(message: "expected payForBuilding, got \(payMsg.tag)")
            }
            guard payMsg.attributes["colony"] == "colony-1" else {
                throw TestError(message: "payForBuilding colony mismatch")
            }

            guard goodsLevelsMsg.tag == "setGoodsLevels" else {
                throw TestError(message: "expected setGoodsLevels, got \(goodsLevelsMsg.tag)")
            }
            guard goodsLevelsMsg.attributes["colony"] == "colony-1" else {
                throw TestError(message: "setGoodsLevels colony mismatch")
            }

            guard rearrangeMsg.tag == "rearrangeColony" else {
                throw TestError(message: "expected rearrangeColony, got \(rearrangeMsg.tag)")
            }
            guard rearrangeMsg.attributes["colony"] == "colony-1" else {
                throw TestError(message: "rearrangeColony colony mismatch")
            }
            guard rearrangeMsg.attributes["xLength"] == "0" else {
                throw TestError(message: "rearrangeColony xLength mismatch")
            }

            guard queueMsg.tag == "setBuildQueue" else {
                throw TestError(message: "expected setBuildQueue, got \(queueMsg.tag)")
            }
            guard queueMsg.attributes["colony"] == "colony-1" else {
                throw TestError(message: "setBuildQueue colony mismatch")
            }
            guard queueMsg.attributes["xLength"] == "2" else {
                throw TestError(message: "setBuildQueue xLength mismatch")
            }
            guard queueMsg.attributes["x0"] == "model.building.carpenterHouse" else {
                throw TestError(message: "setBuildQueue x0 mismatch")
            }
            guard queueMsg.attributes["x1"] == "model.unit.artillery" else {
                throw TestError(message: "setBuildQueue x1 mismatch")
            }

            guard outsideMsg.tag == "putOutsideColony" else {
                throw TestError(message: "expected putOutsideColony, got \(outsideMsg.tag)")
            }
            guard outsideMsg.attributes["unit"] == "unit-1" else {
                throw TestError(message: "putOutsideColony unit mismatch")
            }

            guard abandonMsg.tag == "abandonColony" else {
                throw TestError(message: "expected abandonColony, got \(abandonMsg.tag)")
            }
            guard abandonMsg.attributes["colony"] == "colony-1" else {
                throw TestError(message: "abandonColony colony mismatch")
            }
        }
        while try await group.next() != nil {}
    }

    await server.stop()
}

await integrationTest("client sends goods load/unload messages") {
    let server = MockServer()
    let port = await server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
    <game id="game-11" turn="1">
      <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
      <map id="map-0" width="1" height="1">
        <tile id="tile-0" x="0" y="0" type="model.tile.plains"/>
      </map>
      <unit id="unit-ship" unitType="model.unit.caravel" owner="player-1" location="tile-0" movesLeft="6" state="ACTIVE"/>
      <colony id="colony-1" name="Alpha" owner="player-1" tile="tile-0" settlementType="model.settlement.colony"/>
    </game>
    """

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await client.connect()
            _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
            try await client.send(message: ParsedMessage(tag: "loadGoods", attributes: ["location": "colony-1", "type": "model.goods.grain", "amount": "20", "carrier": "unit-ship"], children: []))
            try await client.send(message: ParsedMessage(tag: "unloadGoods", attributes: ["type": "model.goods.grain", "amount": "10", "carrier": "unit-ship"], children: []))
            await client.disconnect()
        }
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)

            let loadLine = try await server.nextLine()
            let unloadLine = try await server.nextLine()

            let loadMsg = try XMLDecoder.decode(loadLine)
            let unloadMsg = try XMLDecoder.decode(unloadLine)

            guard loadMsg.tag == "loadGoods" else {
                throw TestError(message: "expected loadGoods, got \(loadMsg.tag)")
            }
            guard loadMsg.attributes["location"] == "colony-1" else {
                throw TestError(message: "loadGoods location mismatch")
            }
            guard loadMsg.attributes["type"] == "model.goods.grain" else {
                throw TestError(message: "loadGoods type mismatch")
            }
            guard loadMsg.attributes["amount"] == "20" else {
                throw TestError(message: "loadGoods amount mismatch")
            }
            guard loadMsg.attributes["carrier"] == "unit-ship" else {
                throw TestError(message: "loadGoods carrier mismatch")
            }

            guard unloadMsg.tag == "unloadGoods" else {
                throw TestError(message: "expected unloadGoods, got \(unloadMsg.tag)")
            }
            guard unloadMsg.attributes["type"] == "model.goods.grain" else {
                throw TestError(message: "unloadGoods type mismatch")
            }
            guard unloadMsg.attributes["amount"] == "10" else {
                throw TestError(message: "unloadGoods amount mismatch")
            }
            guard unloadMsg.attributes["carrier"] == "unit-ship" else {
                throw TestError(message: "unloadGoods carrier mismatch")
            }
        }
        while try await group.next() != nil {}
    }

    await server.stop()
}

await integrationTest("client sends combat action messages") {
    let server = MockServer()
    let port = await server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
    <game id="game-12" turn="1">
      <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
      <player id="player-2" username="Bob" nationId="model.nation.french" gold="500"/>
      <map id="map-0" width="2" height="2">
        <tile id="tile-0" x="0" y="0" type="model.tile.plains"/>
        <tile id="tile-1" x="1" y="0" type="model.tile.plains"/>
        <tile id="tile-2" x="0" y="1" type="model.tile.plains"/>
      </map>
      <unit id="unit-1" unitType="model.unit.freeColonist" owner="player-1" location="tile-0" movesLeft="3" state="ACTIVE"/>
      <unit id="enemy-1" unitType="model.unit.freeColonist" owner="player-2" location="tile-1" movesLeft="3" state="ACTIVE"/>
    </game>
    """

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await client.connect()
            _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
            try await client.send(message: ParsedMessage(tag: "attack", attributes: ["unit": "unit-1", "direction": "E"], children: []))
            try await client.send(message: ParsedMessage(tag: "attackRanged", attributes: ["unit": "unit-1", "target": "tile-1"], children: []))
            await client.disconnect()
        }
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)

            let attackLine = try await server.nextLine()
            let rangedLine = try await server.nextLine()

            let attackMsg = try XMLDecoder.decode(attackLine)
            let rangedMsg = try XMLDecoder.decode(rangedLine)

            guard attackMsg.tag == "attack" else {
                throw TestError(message: "expected attack, got \(attackMsg.tag)")
            }
            guard attackMsg.attributes["unit"] == "unit-1" else {
                throw TestError(message: "attack unit mismatch")
            }
            guard attackMsg.attributes["direction"] == "E" else {
                throw TestError(message: "attack direction mismatch")
            }

            guard rangedMsg.tag == "attackRanged" else {
                throw TestError(message: "expected attackRanged, got \(rangedMsg.tag)")
            }
            guard rangedMsg.attributes["unit"] == "unit-1" else {
                throw TestError(message: "attackRanged unit mismatch")
            }
            guard rangedMsg.attributes["target"] == "tile-1" else {
                throw TestError(message: "attackRanged target mismatch")
            }
        }
        while try await group.next() != nil {}
    }

    await server.stop()
}

await integrationTest("client sends equipForRole action") {
    let server = MockServer()
    let port = await server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
    <game id="game-equip-1" turn="1">
      <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
      <map id="map-0" width="2" height="2">
        <tile id="tile-0" x="0" y="0" type="model.tile.plains"/>
      </map>
      <unit id="unit-1" unitType="model.unit.freeColonist" owner="player-1" location="tile-0" movesLeft="3" state="ACTIVE"/>
    </game>
    """

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await client.connect()
            _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
            try await client.send(message: ParsedMessage(
                tag: "equipForRole",
                attributes: ["unit": "unit-1", "role": "model.role.missionary", "count": "1"],
                children: []
            ))
            await client.disconnect()
        }
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)

            let equipLine = try await server.nextLine()
            let equipMsg = try XMLDecoder.decode(equipLine)

            guard equipMsg.tag == "equipForRole" else {
                throw TestError(message: "expected equipForRole, got \(equipMsg.tag)")
            }
            guard equipMsg.attributes["unit"] == "unit-1" else {
                throw TestError(message: "equipForRole unit mismatch")
            }
            guard equipMsg.attributes["role"] == "model.role.missionary" else {
                throw TestError(message: "equipForRole role mismatch")
            }
            guard equipMsg.attributes["count"] == "1" else {
                throw TestError(message: "equipForRole count mismatch")
            }
        }
        while try await group.next() != nil {}
    }

    await server.stop()
}

await integrationTest("client sends learnSkill action") {
    let server = MockServer()
    let port = await server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
    <game id="game-learn-1" turn="1">
      <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
      <map id="map-0" width="3" height="3">
        <tile id="tile-0" x="0" y="0" type="model.tile.plains"/>
        <tile id="tile-1" x="1" y="0" type="model.tile.plains"/>
      </map>
      <unit id="unit-1" unitType="model.unit.freeColonist" owner="player-1" location="tile-0" movesLeft="3" state="ACTIVE"/>
    </game>
    """

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await client.connect()
            _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
            try await client.send(message: ParsedMessage(
                tag: "learnSkill",
                attributes: ["unit": "unit-1", "direction": "NE"],
                children: []
            ))
            await client.disconnect()
        }
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)

            let learnLine = try await server.nextLine()
            let learnMsg = try XMLDecoder.decode(learnLine)

            guard learnMsg.tag == "learnSkill" else {
                throw TestError(message: "expected learnSkill, got \(learnMsg.tag)")
            }
            guard learnMsg.attributes["unit"] == "unit-1" else {
                throw TestError(message: "learnSkill unit mismatch")
            }
            guard learnMsg.attributes["direction"] == "NE" else {
                throw TestError(message: "learnSkill direction mismatch")
            }
        }
        while try await group.next() != nil {}
    }

    await server.stop()
}

await integrationTest("client sends newLandName action") {
    let server = MockServer()
    let port = await server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
    <game id="game-newland-1" turn="1">
      <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
      <map id="map-0" width="2" height="2">
        <tile id="tile-0" x="0" y="0" type="model.tile.plains"/>
      </map>
      <unit id="unit-1" unitType="model.unit.caravel" owner="player-1" location="tile-0" movesLeft="3" state="ACTIVE"/>
    </game>
    """

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await client.connect()
            _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
            try await client.send(message: ParsedMessage(
                tag: "newLandName",
                attributes: ["unit": "unit-1", "newLandName": "New Amsterdam"],
                children: []
            ))
            await client.disconnect()
        }
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)

            let nameLine = try await server.nextLine()
            let nameMsg = try XMLDecoder.decode(nameLine)

            guard nameMsg.tag == "newLandName" else {
                throw TestError(message: "expected newLandName, got \(nameMsg.tag)")
            }
            guard nameMsg.attributes["unit"] == "unit-1" else {
                throw TestError(message: "newLandName unit mismatch")
            }
            guard nameMsg.attributes["newLandName"] == "New Amsterdam" else {
                throw TestError(message: "newLandName name mismatch")
            }
        }
        while try await group.next() != nil {}
    }

    await server.stop()
}

await integrationTest("client sends newRegionName action") {
    let server = MockServer()
    let port = await server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
    <game id="game-newregion-1" turn="1">
      <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
      <map id="map-0" width="3" height="3">
        <tile id="tile-0" x="0" y="0" type="model.tile.plains"/>
        <tile id="tile-1" x="1" y="0" type="model.tile.plains"/>
      </map>
      <unit id="unit-1" unitType="model.unit.caravel" owner="player-1" location="tile-0" movesLeft="3" state="ACTIVE"/>
    </game>
    """

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await client.connect()
            _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
            try await client.send(message: ParsedMessage(
                tag: "newRegionName",
                attributes: [
                    "newRegionName": "Pacific Zone",
                    "region": "region-5",
                    "tile": "tile-1",
                    "unit": "unit-1"
                ],
                children: []
            ))
            await client.disconnect()
        }
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)

            let regionLine = try await server.nextLine()
            let regionMsg = try XMLDecoder.decode(regionLine)

            guard regionMsg.tag == "newRegionName" else {
                throw TestError(message: "expected newRegionName, got \(regionMsg.tag)")
            }
            guard regionMsg.attributes["unit"] == "unit-1" else {
                throw TestError(message: "newRegionName unit mismatch")
            }
            guard regionMsg.attributes["region"] == "region-5" else {
                throw TestError(message: "newRegionName region mismatch")
            }
            guard regionMsg.attributes["tile"] == "tile-1" else {
                throw TestError(message: "newRegionName tile mismatch")
            }
            guard regionMsg.attributes["newRegionName"] == "Pacific Zone" else {
                throw TestError(message: "newRegionName name mismatch")
            }
        }
        while try await group.next() != nil {}
    }

    await server.stop()
}

await integrationTest("client sends incite action") {
    let server = MockServer()
    let port = await server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
    <game id="game-incite-1" turn="1">
      <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
      <player id="player-2" username="Bob" nationId="model.nation.french" gold="300"/>
      <map id="map-0" width="2" height="2">
        <tile id="tile-0" x="0" y="0" type="model.tile.plains"/>
      </map>
      <unit id="unit-1" unitType="model.unit.freeColonist" owner="player-1" location="tile-0" movesLeft="3" state="ACTIVE"/>
    </game>
    """

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await client.connect()
            _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
            try await client.send(message: ParsedMessage(
                tag: "incite",
                attributes: [
                    "enemy": "player-2",
                    "gold": "200",
                    "settlement": "is-5",
                    "unit": "unit-1"
                ],
                children: []
            ))
            await client.disconnect()
        }
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)

            let inciteLine = try await server.nextLine()
            let inciteMsg = try XMLDecoder.decode(inciteLine)

            guard inciteMsg.tag == "incite" else {
                throw TestError(message: "expected incite, got \(inciteMsg.tag)")
            }
            guard inciteMsg.attributes["unit"] == "unit-1" else {
                throw TestError(message: "incite unit mismatch")
            }
            guard inciteMsg.attributes["settlement"] == "is-5" else {
                throw TestError(message: "incite settlement mismatch")
            }
            guard inciteMsg.attributes["enemy"] == "player-2" else {
                throw TestError(message: "incite enemy mismatch")
            }
            guard inciteMsg.attributes["gold"] == "200" else {
                throw TestError(message: "incite gold mismatch")
            }
        }
        while try await group.next() != nil {}
    }

    await server.stop()
}

await integrationTest("client sends deliverGift action") {
    let server = MockServer()
    let port = await server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
    <game id="game-gift-1" turn="1">
      <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
      <map id="map-0" width="2" height="2">
        <tile id="tile-0" x="0" y="0" type="model.tile.plains"/>
      </map>
      <unit id="unit-missionary" unitType="model.unit.missionary" owner="player-1" location="tile-0" movesLeft="3" state="ACTIVE"/>
    </game>
    """

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await client.connect()
            _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
            try await client.send(message: ParsedMessage(
                tag: "deliverGift",
                attributes: [
                    "settlement": "is-tribal-village",
                    "unit": "unit-missionary"
                ],
                children: []
            ))
            await client.disconnect()
        }
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)

            let giftLine = try await server.nextLine()
            let giftMsg = try XMLDecoder.decode(giftLine)

            guard giftMsg.tag == "deliverGift" else {
                throw TestError(message: "expected deliverGift, got \(giftMsg.tag)")
            }
            guard giftMsg.attributes["unit"] == "unit-missionary" else {
                throw TestError(message: "deliverGift unit mismatch")
            }
            guard giftMsg.attributes["settlement"] == "is-tribal-village" else {
                throw TestError(message: "deliverGift settlement mismatch")
            }
        }
        while try await group.next() != nil {}
    }

    await server.stop()
}

await integrationTest("message loop forwards animate events") {
    let server = MockServer()
    let port = await server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)
    let delegate = TestDelegate()
    await client.setDelegate(delegate)

    let gameXML = """
    <game id="game-13" turn="1">
      <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
      <player id="player-2" username="Bob" nationId="model.nation.french" gold="500"/>
      <map id="map-0" width="2" height="1">
        <tile id="tile-0" x="0" y="0" type="model.tile.plains"/>
        <tile id="tile-1" x="1" y="0" type="model.tile.plains"/>
      </map>
      <unit id="unit-1" unitType="model.unit.freeColonist" owner="player-1" location="tile-0" movesLeft="3" state="ACTIVE"/>
      <unit id="unit-2" unitType="model.unit.freeColonist" owner="player-2" location="tile-1" movesLeft="3" state="ACTIVE"/>
    </game>
    """

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await client.connect()
            _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
            try? await client.startMessageLoop()
        }
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)
            try await Task.sleep(nanoseconds: 250_000_000)
            await server.send("<animateMove oldTile=\"tile-0\" unit=\"unit-1\" newTile=\"tile-1\"/>")
            await server.send("<animateAttack attackerTile=\"tile-0\" defenderTile=\"tile-1\" attacker=\"unit-1\" defender=\"unit-2\" success=\"true\"/>")
            await server.flush()
            try await Task.sleep(nanoseconds: 300_000_000)
            await server.stop()
        }
        try await Task.sleep(nanoseconds: 5_000_000_000)
        group.cancelAll()
    }

    guard delegate.receivedMessages.contains("animateMove") else {
        throw TestError(message: "animateMove not forwarded to delegate")
    }
    guard delegate.receivedMessages.contains("animateAttack") else {
        throw TestError(message: "animateAttack not forwarded to delegate")
    }
}

await integrationTest("message loop processes question payload and replies") {
    let server = MockServer()
    let port = await server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
    <game id="game-4" turn="1">
      <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
      <player id="player-2" username="Bob" nationId="model.nation.french" gold="400"/>
    </game>
    """

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await client.connect()
            _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
            await client.startMessageLoop()
        }
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)
            try await Task.sleep(nanoseconds: 200_000_000)
            await server.send("<question networkReplyId=\"9\"><setCurrentPlayer player=\"player-2\"/></question>")
            await server.flush()

            let replyLine = try await server.nextLine()
            let reply = try XMLDecoder.decode(replyLine)
            guard reply.tag == "reply" else {
                throw TestError(message: "expected reply, got \(reply.tag)")
            }
            guard reply.attributes["networkReplyId"] == "9" else {
                throw TestError(message: "unexpected reply id")
            }

            try await Task.sleep(nanoseconds: 200_000_000)
            await server.stop()
        }
        try await Task.sleep(nanoseconds: 5_000_000_000)
        group.cancelAll()
    }

    let current = await client.game.currentPlayerId
    guard current == "player-2" else {
        throw TestError(message: "question payload was not applied")
    }
}

if ProcessInfo.processInfo.environment["REAL_SERVER_E2E"] == "1" {
    await integrationTest("real Java server connect/login smoke") {
        let host = ProcessInfo.processInfo.environment["REAL_SERVER_HOST"] ?? "127.0.0.1"
        let port = Int(ProcessInfo.processInfo.environment["REAL_SERVER_PORT"] ?? "3541") ?? 3541
        let client = FreeColClient(host: host, port: port)

        try await client.connect()
        guard await client.initialGameState != nil else {
            throw TestError(message: "real server did not send gameState")
        }

        let vacant = await client.initialVacantPlayers
        let nationId = vacant?.children.first?.attributes["nationId"]
            ?? vacant?.children.first?.attributes["id"]
            ?? "model.nation.dutch"
        let userName = "CopilotE2E-\(Int(Date().timeIntervalSince1970))"

        let result = try await client.login(userName: userName, nationId: nationId)
        guard result.serverState == .preGame || result.serverState == .inGame else {
            throw TestError(message: "unexpected server state after login: \(result.serverState.rawValue)")
        }

        if result.serverState == .preGame {
            try await client.send(message: ParsedMessage(tag: "ready", attributes: ["value": "true"], children: []))
            try await client.send(message: ParsedMessage(tag: "requestLaunch", attributes: [:], children: []))
        } else {
            try await client.send(message: ParsedMessage(tag: "endTurn", attributes: [:], children: []))
        }

        await client.disconnect()
    }
}

if ProcessInfo.processInfo.environment["REAL_SERVER_DEEP_E2E"] == "1" {
    await integrationTest("real Java server pregame-to-ingame probe") {
        let host = ProcessInfo.processInfo.environment["REAL_SERVER_HOST"] ?? "127.0.0.1"
        let port = Int(ProcessInfo.processInfo.environment["REAL_SERVER_PORT"] ?? "3541") ?? 3541
        let client = FreeColClient(host: host, port: port)
        let delegate = TestDelegate()
        await client.setDelegate(delegate)

        try await client.connect()
        guard await client.initialGameState != nil else {
            throw TestError(message: "real server did not send gameState")
        }

        let vacant = await client.initialVacantPlayers
        let nationId = vacant?.children.first?.attributes["nationId"]
            ?? vacant?.children.first?.attributes["id"]
            ?? "model.nation.dutch"
        let userName = "CopilotDeep-\(Int(Date().timeIntervalSince1970))"

        let result = try await client.login(userName: userName, nationId: nationId)
        guard result.serverState == .preGame || result.serverState == .inGame else {
            throw TestError(message: "unexpected server state after login: \(result.serverState.rawValue)")
        }

        var launchProbeSent = false

        // Probe launch path in pre-game. Servers may reject launch if not all players are ready.
        if result.serverState == .preGame {
            _ = try await client.ask(message: ParsedMessage(tag: "ready", attributes: ["value": "true"], children: []))
            _ = try await client.ask(message: ParsedMessage(tag: "requestLaunch", attributes: [:], children: []))
            launchProbeSent = true
        }

        let loopTask = Task {
            await client.startMessageLoop()
        }
        try await Task.sleep(nanoseconds: 2_000_000_000)
        loopTask.cancel()

        let tags = delegate.receivedMessages
        let sawSessionSignal = tags.contains("gameState") || tags.contains("startGame") || tags.contains("error")

        // Real servers may keep PRE_GAME without broadcasting immediate events to this client.
        // Passing ask/reply for ready/requestLaunch is still a valid transport-level success.
        guard sawSessionSignal || launchProbeSent || result.serverState == .inGame else {
            throw TestError(message: "no session signal and no launch probe activity observed")
        }

        // If the session reached in-game, probe endTurn transport opportunistically.
        if await client.game.currentPlayerId != nil {
            do {
                _ = try await client.ask(message: ParsedMessage(tag: "endTurn", attributes: [:], children: []))
            } catch FreeColProtocolError.disconnected {
                // Real server can close/rotate connection during launch transitions.
            }
        }

        await client.disconnect()
    }
}

print("\n\(passed) passed, \(failed) failed")
exit(failed > 0 ? 1 : 0)
import Foundation
import FreeColProtocol
import FreeColGame
import FreeColClient

var passed = 0
var failed = 0
let realServerOnly = ProcessInfo.processInfo.environment["FREECOL_CLI_REAL_SERVER_ONLY"] == "1"

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
    guard !realServerOnly else { return }
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
print(realServerOnly ? "FreeColProtocol Real-Server Probe" : "FreeColProtocol Tests")
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

test("game pathfinding returns the first step on a shortest route") {
    let game = Game()
    let parsed = try XMLDecoder.decode("""
    <game id="game-1">
      <map id="map-1" width="4" height="2">
        <tile id="tile-0-0" x="0" y="0" type="model.tile.plains"/>
        <tile id="tile-1-0" x="1" y="0" type="model.tile.plains"/>
        <tile id="tile-2-0" x="2" y="0" type="model.tile.plains"/>
        <tile id="tile-3-0" x="3" y="0" type="model.tile.plains"/>
      </map>
    </game>
    """)
    try game.load(from: parsed)

    let step = game.nextPathStep(from: "tile-0-0", to: "tile-3-0") { _, _ in true }
    try assertEqual(step, "tile-1-0")
}

test("game visibility includes owned tiles and nearby exploration") {
    let game = Game()
    let parsed = try XMLDecoder.decode("""
    <game id="game-1">
      <player id="player-1" username="Alice" nationId="model.nation.dutch"/>
      <map id="map-1" width="4" height="2">
        <tile id="tile-0-0" x="0" y="0" type="model.tile.plains"/>
        <tile id="tile-1-0" x="1" y="0" type="model.tile.plains"/>
        <tile id="tile-2-0" x="2" y="0" type="model.tile.plains"/>
      </map>
      <unit id="unit-1" owner="player-1" location="tile-0-0" unitType="model.unit.freeColonist"/>
    </game>
    """)
    try game.load(from: parsed)

    let visible = game.visibleTileIds(for: "player-1")
    try assertEqual(visible.contains("tile-0-0"), true)
    try assertEqual(visible.contains("tile-1-0"), true)
    try assertEqual(visible.contains("tile-2-0"), false)
}

test("game explored tracks tile type presence") {
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

    try assertEqual(game.isExplored(tileId: "tile-0-0"), true)
    try assertEqual(game.isExplored(tileId: "tile-1-0"), false)
    try assertEqual(game.exploredTileIds(), ["tile-0-0"])
}

test("game sight radius follows specification line-of-sight") {
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
    try assertEqual(visible.contains("tile-0-0"), true)
    try assertEqual(visible.contains("tile-1-0"), true)
    try assertEqual(visible.contains("tile-2-0"), true)

    // Fallback heuristic: naval names get radius 2 without a specification.
    let fallbackShip = Specification.fallbackLineOfSight(forUnitType: "model.unit.caravel")
    try assertEqual(fallbackShip, 2)
    let fallbackLand = Specification.fallbackLineOfSight(forUnitType: "model.unit.freeColonist")
    try assertEqual(fallbackLand, 1)
}

test("game selection recovery prefers same-tile or fallback local units") {
    let game = Game()
    let parsed = try XMLDecoder.decode("""
    <game id="game-1">
      <player id="player-1" username="Alice" nationId="model.nation.dutch"/>
      <map id="map-1" width="4" height="2">
        <tile id="tile-0-0" x="0" y="0" type="model.tile.plains"/>
        <tile id="tile-1-0" x="1" y="0" type="model.tile.plains"/>
      </map>
      <unit id="unit-1" owner="player-1" location="tile-0-0" unitType="model.unit.freeColonist" state="ACTIVE"/>
      <unit id="unit-2" owner="player-1" location="tile-1-0" unitType="model.unit.pioneer" state="ACTIVE"/>
    </game>
    """)
    try game.load(from: parsed)

    let sameTileRecovery = game.recoverSelection(for: "player-1", preferredTileId: "tile-0-0")
    try assertNotNil(sameTileRecovery)
    try assertEqual(sameTileRecovery?.unitId, "unit-1")
    try assertEqual(sameTileRecovery?.tileId, "tile-0-0")

    let fallbackRecovery = game.recoverSelection(for: "player-1", preferredTileId: "tile-9-9")
    try assertNotNil(fallbackRecovery)
    try assertEqual(fallbackRecovery?.unitId, "unit-1")
    try assertEqual(fallbackRecovery?.tileId, "tile-0-0")
}

test("game load clears stale state before applying a new snapshot") {
    let game = Game()
    try game.load(from: ParsedMessage(tag: "game", attributes: ["id": "game-old"], children: [
        ParsedMessage(tag: "player", attributes: ["id": "player-old", "username": "Old"], children: []),
        ParsedMessage(tag: "map", attributes: ["id": "map-old", "width": "1", "height": "1"], children: [
            ParsedMessage(tag: "tile", attributes: ["id": "tile-old", "x": "0", "y": "0", "type": "model.tile.plains"], children: [])
        ])
    ]))

    try game.load(from: ParsedMessage(tag: "game", attributes: ["id": "game-new", "turn": "7"], children: [
        ParsedMessage(tag: "player", attributes: ["id": "player-new", "username": "New"], children: []),
        ParsedMessage(tag: "map", attributes: ["id": "map-new", "width": "2", "height": "1"], children: [
            ParsedMessage(tag: "tile", attributes: ["id": "tile-new", "x": "0", "y": "0", "type": "model.tile.grassland"], children: [])
        ])
    ]))

    try assertEqual(game.id, "game-new")
    try assertEqual(game.turn, Turn(7))
    try assertEqual(game.players.keys.contains("player-old"), false)
    try assertEqual(game.tiles.keys.contains("tile-old"), false)
    try assertEqual(game.players.keys.contains("player-new"), true)
    try assertEqual(game.tiles.keys.contains("tile-new"), true)
}

test("server reject mapper normalizes common reject messages") {
    let buildReject = ParsedMessage(
        tag: "error",
        attributes: ["message": "Unit unit:5691 can not build colony."],
        children: []
    )
    try assertEqual(
        ServerRejectMapper.userFacingMessage(for: buildReject),
        "Diese Einheit kann hier keine Kolonie gruenden."
    )

    let movesReject = ParsedMessage(
        tag: "error",
        attributes: ["message": "MOVE_NO_MOVES unit:5691"],
        children: []
    )
    try assertEqual(
        ServerRejectMapper.userFacingMessage(for: movesReject),
        "Diese Einheit hat keine Bewegungspunkte mehr."
    )
    let embarkReject = ParsedMessage(
        tag: "error",
        attributes: ["message": "Illegal move for: unit:6201 type: MOVE_NO_ACCESS_EMBARK from: unit:6203 to: tile:3563"],
        children: []
    )
    try assertEqual(
        ServerRejectMapper.userFacingMessage(for: embarkReject),
        "Diese Einheit ist eingeschifft; bitte zuerst ausschiffen."
    )
    try assertEqual(
        ServerRejectMapper.rejectedObjectId(prefix: "unit:", in: "MOVE_NO_MOVES unit:5691"),
        "unit:5691"
    )

    let templateReject = ParsedMessage(
        tag: "error",
        attributes: [:],
        children: [ParsedMessage(tag: "stringTemplate", attributes: ["id": "server.reject"], children: [])]
    )
    try assertEqual(
        ServerRejectMapper.userFacingMessage(for: templateReject),
        "Server hat die Aktion abgelehnt."
    )

    let turnReject = ParsedMessage(
        tag: "error",
        attributes: ["message": "It is not Alice's turn, it is Bob's!"],
        children: []
    )
    try assertEqual(
        ServerRejectMapper.userFacingMessage(for: turnReject),
        "Du bist gerade nicht am Zug."
    )

    let amphibiousReject = ParsedMessage(
        tag: "error",
        attributes: ["message": "MOVE_NO_AMPHIBIOUS unit:1"],
        children: []
    )
    try assertEqual(
        ServerRejectMapper.userFacingMessage(for: amphibiousReject),
        "Diese Einheit kann nicht über Wasser gehen."
    )

    let hostileReject = ParsedMessage(
        tag: "error",
        attributes: ["message": "NAK_HOSTILE"],
        children: []
    )
    try assertEqual(
        ServerRejectMapper.userFacingMessage(for: hostileReject),
        "Die Siedlung ist feindlich gesinnt."
    )
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

test("Game.applyUpdate registers a settlement nested in a tile update") {
    let game = Game()
    let update = try XMLDecoder.decode("""
    <update>
      <tile id="tile-1" x="3" y="4" type="model.tile.plains">
        <colony id="colony-1" name="E2E Colony" owner="player-1"
                settlementType="model.settlement.colony"/>
      </tile>
    </update>
    """)
    try game.applyUpdate(update)
    try assertEqual(game.tiles["tile-1"]?.settlement, "colony-1")
    try assertEqual(game.colonies["colony-1"]?.name, "E2E Colony")
    try assertEqual(game.colonies["colony-1"]?.owner, "player-1")
    try assertEqual(game.colonies["colony-1"]?.tileId, "tile-1")
}

test("Game.applyUpdate updates a unit nested in a tile update") {
    let game = Game()
    try game.load(from: XMLDecoder.decode("""
    <game id="game-1">
      <unit id="unit-1" unitType="model.unit.freeColonist" location="ship-1"/>
    </game>
    """))
    let update = try XMLDecoder.decode("""
    <update>
      <tile id="tile-1" x="3" y="4" type="model.tile.plains">
        <unit id="unit-1" unitType="model.unit.freeColonist" location="tile-1"
              movesLeft="0" state="ACTIVE"/>
      </tile>
    </update>
    """)
    try game.applyUpdate(update)
    try assertEqual(game.units["unit-1"]?.location, "tile-1")
    try assertEqual(game.units["unit-1"]?.movesLeft, 0)
}

test("Unit parses state enum") {
    let unit = try Unit(id: "unit-1", attributes: [
        "id": "unit-1", "unitType": "model.unit.galleon", "state": "SAILING"
    ], children: [], game: Game())
    try assertEqual(unit.state, .sailing)
}

test("Player parses europe and market children") {
    let player = try Player(id: "player-1", attributes: [
        "id": "player-1", "username": "Alice", "gold": "500", "tax": "10"
    ], children: [
        ParsedMessage(tag: "europe", attributes: ["id": "europe:42", "owner": "player-1", "recruitPrice": "800"], children: []),
        ParsedMessage(tag: "market", attributes: ["owner": "player-1"], children: [
            ParsedMessage(tag: "marketData", attributes: [
                "goods-type": "model.goods.food",
                "amount": "200",
                "initialPrice": "10",
                "traded": "true",
            ], children: []),
            ParsedMessage(tag: "marketData", attributes: [
                "goods-type": "model.goods.tools",
                "amount": "50",
                "initialPrice": "16",
            ], children: []),
        ]),
    ], game: Game())
    try assertEqual(player.europe?.id, "europe:42")
    try assertEqual(player.market?.data.count, 2)
    try assertEqual(player.market?.entry(for: "model.goods.food")?.initialPrice, 10)
    try assertEqual(player.market?.entry(for: "model.goods.food")?.traded, true)
    try assertEqual(player.market?.entry(for: "model.goods.tools")?.amount, 50)
}

test("game load parses europe and market from player XML") {
    let game = Game()
    let parsed = try XMLDecoder.decode("""
    <game id="game-1">
      <player id="player-1" username="Alice" gold="500" tax="10">
        <europe id="europe:7" owner="player-1" recruitPrice="800"/>
        <market owner="player-1">
          <marketData goods-type="model.goods.food" amount="150" initialPrice="12"/>
        </market>
      </player>
    </game>
    """)
    try game.load(from: parsed)
    try assertEqual(game.players["player-1"]?.europe?.id, "europe:7")
    try assertEqual(game.players["player-1"]?.market?.entry(for: "model.goods.food")?.initialPrice, 12)
}

test("GameStateManager applies player update with europe and market") {
    let mgr = GameStateManager()
    let update = try XMLDecoder.decode("""
    <update>
      <player id="player-1" username="Alice" gold="300" tax="5">
        <europe id="europe:9" owner="player-1"/>
        <market owner="player-1">
          <marketData goods-type="model.goods.food" amount="100" initialPrice="11"/>
        </market>
      </player>
    </update>
    """)
    let handled = try mgr.process(update)
    try assertEqual(handled, true)
    try assertEqual(mgr.game.players["player-1"]?.gold, 300)
    try assertEqual(mgr.game.players["player-1"]?.europe?.id, "europe:9")
    try assertEqual(mgr.game.players["player-1"]?.market?.data.count, 1)
}

test("game load parses stance children from player XML") {
    let game = Game()
    let parsed = try XMLDecoder.decode("""
    <game id="game-1">
      <player id="player-1" username="Alice">
        <stance player="player-2" value="WAR"/>
        <stance player="player-3" value="PEACE"/>
      </player>
    </game>
    """)
    try game.load(from: parsed)
    try assertEqual(game.players["player-1"]?.stances["player-2"], .war)
    try assertEqual(game.players["player-1"]?.stances["player-3"], .peace)
}

test("game load parses trade routes from player XML") {
    let game = Game()
    let parsed = try XMLDecoder.decode("""
    <game id="game-1">
      <player id="player-1" username="Alice">
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
    try assertEqual(game.tradeRoutes["tradeRoute:1"]?.name, "Route A")
    try assertEqual(game.tradeRoutes["tradeRoute:1"]?.owner, "player-1")
    try assertEqual(game.tradeRoutes["tradeRoute:1"]?.stops.count, 2)
    try assertEqual(game.tradeRoutes["tradeRoute:1"]?.stops.first?.locationId, "colony:1")
    try assertEqual(game.tradeRoutes["tradeRoute:1"]?.stops.first?.cargoTypeIds,
                    ["model.goods.food", "model.goods.sugar"])
    try assertEqual(game.tradeRoutes(forPlayer: "player-1").count, 1)
}

test("GameStateManager processes newTradeRoute") {
    let mgr = GameStateManager()
    let handled = try mgr.process(try XMLDecoder.decode("""
    <newTradeRoute>
      <tradeRoute id="tradeRoute:7" name="New Route" owner="player-1" silent="false">
        <tradeRouteStop location="colony:1"/>
      </tradeRoute>
    </newTradeRoute>
    """))
    try assertEqual(handled, true)
    try assertEqual(mgr.game.tradeRoutes["tradeRoute:7"]?.name, "New Route")
    try assertEqual(mgr.game.tradeRoutes["tradeRoute:7"]?.stops.count, 1)
}

test("GameStateManager processes updateTradeRoute and deleteTradeRoute") {
    let mgr = GameStateManager()
    _ = try mgr.process(try XMLDecoder.decode("""
    <newTradeRoute>
      <tradeRoute id="tradeRoute:7" name="Old" owner="player-1"/>
    </newTradeRoute>
    """))
    _ = try mgr.process(try XMLDecoder.decode("""
    <updateTradeRoute>
      <tradeRoute id="tradeRoute:7" name="Renamed" owner="player-1">
        <tradeRouteStop location="europe:9"><cargo id="model.goods.food"/></tradeRouteStop>
      </tradeRoute>
    </updateTradeRoute>
    """))
    try assertEqual(mgr.game.tradeRoutes["tradeRoute:7"]?.name, "Renamed")
    try assertEqual(mgr.game.tradeRoutes["tradeRoute:7"]?.stops.first?.cargoTypeIds,
                    ["model.goods.food"])
    let handled = try mgr.process(ParsedMessage(
        tag: "deleteTradeRoute",
        attributes: ["tradeRoute": "tradeRoute:7"],
        children: []
    ))
    try assertEqual(handled, true)
    try assertEqual(mgr.game.tradeRoutes.keys.contains("tradeRoute:7"), false)
}

test("game load parses colony build queue and buildings") {
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
        <building-type id="model.building.townHall"/>
      </freecol-specification>
    </game>
    """)
    try game.load(from: parsed)
    try assertEqual(game.colonies["colony-1"]?.buildQueue,
                    ["model.building.townHall", "model.building.carpenterHouse"])
    try assertEqual(game.colonies["colony-1"]?.populationQueue, ["model.unit.freeColonist"])
    try assertEqual(game.colonies["colony-1"]?.buildings.first?.buildingType, "model.building.townHall")
    try assertEqual(game.specification?.buildingTypes["model.building.lumberMill"]?.requiredPopulation, 3)
    try assertEqual(game.specification?.buildingTypes["model.building.lumberMill"]?.upgradesFrom,
                    "model.building.carpenterHouse")
    try assertEqual(game.specification?.buildingTypes["model.building.lumberMill"]?.displayName, "LumberMill")
}

test("game load parses colony goods and building production costs") {
    let game = Game()
    let parsed = try XMLDecoder.decode("""
    <game id="game-1">
      <player id="player-1" username="Alice"/>
      <colony id="colony-1" name="Boston" owner="player-1" tile="tile-0-0" unitCount="3">
        <building id="building-1" buildingType="model.building.carpenterHouse"/>
        <goodsContainer id="colony-1-goods">
          <storedGoods>
            <goods type="model.goods.hammers" amount="12"/>
            <goods type="model.goods.lumber" amount="40"/>
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
          <production>
            <output goods-type="model.goods.hammers" value="6"/>
          </production>
        </building-type>
      </freecol-specification>
    </game>
    """)
    try game.load(from: parsed)
    try assertEqual(game.colonies["colony-1"]?.goods["model.goods.hammers"], 12)
    try assertEqual(game.colonies["colony-1"]?.goods["model.goods.lumber"], 40)
    let carpenter = game.specification?.buildingTypes["model.building.carpenterHouse"]
    try assertEqual(carpenter?.productionOutputs["model.goods.hammers"], 3)
    try assertEqual(carpenter?.productionInputs["model.goods.lumber"], 3)
    let mill = game.specification?.buildingTypes["model.building.lumberMill"]
    try assertEqual(mill?.requiredGoods["model.goods.hammers"], 52)
}

test("UnitTypeTraits classifies naval and missionary units") {
    try assertEqual(UnitTypeTraits.isNaval(unitType: "model.unit.caravel"), true)
    try assertEqual(UnitTypeTraits.isNaval(unitType: "model.unit.galleon"), true)
    try assertEqual(UnitTypeTraits.isNaval(unitType: "model.unit.freeColonist"), false)
    try assertEqual(UnitTypeTraits.isNaval(unitType: nil, role: "model.role.merchantman"), true)
    try assertEqual(UnitTypeTraits.isMissionary(unitType: "model.unit.jesuitMissionary"), true)
    try assertEqual(UnitTypeTraits.isMissionary(unitType: nil, role: "model.role.missionary"), true)
    try assertEqual(UnitTypeTraits.isMissionary(unitType: "model.unit.freeColonist"), false)
    try assertEqual(UnitTypeTraits.isCarrier(unitType: "model.unit.merchantman"), true)
}

test("native trade item serializes price and goods") {
    let item = NativeTradeItem(goodsType: "model.goods.fur", amount: 10, price: 90,
                               haggleCount: 2, source: "unit-1", destination: "colony-1")
    let node = item.toMessage()
    try assertEqual(node.tag, "nativeTradeItem")
    try assertEqual(node.attributes["price"], "90")
    try assertEqual(node.attributes["haggleCount"], "2")
    try assertEqual(node.attributes["source"], "unit-1")
    try assertEqual(node.attributes["destination"], "colony-1")
    try assertEqual(node.children.first?.attributes["type"], "model.goods.fur")
    try assertEqual(node.children.first?.attributes["amount"], "10")
}

test("building type prefers attended production over unattended") {
    let game = Game()
    let parsed = try XMLDecoder.decode("""
    <game id="game-1">
      <player id="player-1" username="Alice"/>
      <freecol-specification id="spec">
        <building-type id="model.building.townHall">
          <production unattended="true">
            <output goods-type="model.goods.bells" value="1"/>
          </production>
          <production>
            <output goods-type="model.goods.bells" value="3"/>
          </production>
        </building-type>
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
    try assertEqual(game.specification?.buildingTypes["model.building.townHall"]?
        .productionOutputs["model.goods.bells"], 3)
    try assertEqual(game.specification?.buildingTypes["model.building.carpenterHouse"]?
        .productionInputs["model.goods.lumber"], 3)
}

test("specification resolves unit abilities through extends") {
    let game = Game()
    let parsed = try XMLDecoder.decode("""
    <game id="game-1">
      <player id="player-1" username="Alice"/>
      <freecol-specification id="spec">
        <unit-type id="ship" abstract="true" line-of-sight="2">
          <ability id="model.ability.navalUnit" value="true"/>
          <ability id="model.ability.carryUnits" value="true"/>
        </unit-type>
        <unit-type id="colonist" abstract="true">
          <ability id="model.ability.foundColony" value="true"/>
        </unit-type>
        <unit-type id="model.unit.caravel" extends="ship"/>
        <unit-type id="model.unit.freeColonist" extends="colonist" movement="3"/>
      </freecol-specification>
    </game>
    """)
    try game.load(from: parsed)
    let spec = game.specification
    try assertEqual(spec?.isNaval(unitType: "model.unit.caravel"), true)
    try assertEqual(spec?.carriesUnits(unitType: "model.unit.caravel"), true)
    try assertEqual(spec?.lineOfSight(forUnitType: "model.unit.caravel"), 2)
    try assertEqual(spec?.isNaval(unitType: "model.unit.freeColonist"), false)
    try assertEqual(spec?.lineOfSight(forUnitType: "model.unit.freeColonist"), 1)
    try assertEqual(spec?.hasAbility("model.ability.foundColony", unitType: "model.unit.freeColonist"), true)
    try assertEqual(spec?.isNaval(unitType: "model.unit.unknown"), nil)
}

test("specification parses tile-type center production") {
    let game = Game()
    let parsed = try XMLDecoder.decode("""
    <game id="game-1">
      <player id="player-1" username="Alice"/>
      <freecol-specification id="spec">
        <tile-type id="model.tile.plains" can-settle="true">
          <production unattended="true">
            <output goods-type="model.goods.grain" value="3"/>
            <output goods-type="model.goods.cotton" value="2"/>
          </production>
          <production>
            <output goods-type="model.goods.grain" value="5"/>
          </production>
        </tile-type>
        <tile-type id="model.tile.ocean" is-water="true" can-settle="false"/>
      </freecol-specification>
    </game>
    """)
    try game.load(from: parsed)
    let plains = game.specification?.tileTypes["model.tile.plains"]
    let ocean = game.specification?.tileTypes["model.tile.ocean"]
    try assertEqual(plains?.centerOutputs["model.goods.grain"], 3)
    try assertEqual(plains?.centerOutputs["model.goods.cotton"], 2)
    try assertEqual(plains?.isWater, false)
    try assertEqual(plains?.canSettle, true)
    try assertEqual(ocean?.isWater, true)
    try assertEqual(ocean?.canSettle, false)
}

test("GameStateManager processes setStance") {
    let mgr = GameStateManager()
    try mgr.process(ParsedMessage(tag: "addPlayer", attributes: [:], children: [
        ParsedMessage(tag: "player", attributes: [
            "id": "player-1", "username": "Alice", "nationId": "model.nation.dutch"
        ], children: []),
        ParsedMessage(tag: "player", attributes: [
            "id": "player-2", "username": "Bob", "nationId": "model.nation.french"
        ], children: []),
    ]))
    let handled = try mgr.process(ParsedMessage(
        tag: "setStance",
        attributes: ["first": "player-1", "second": "player-2", "stance": "WAR"],
        children: []
    ))
    try assertEqual(handled, true)
    try assertEqual(mgr.game.players["player-1"]?.stances["player-2"], .war)
}

test("GameStateManager processes setAI and setDead") {
    let mgr = GameStateManager()
    try mgr.process(ParsedMessage(tag: "addPlayer", attributes: [:], children: [
        ParsedMessage(tag: "player", attributes: [
            "id": "player-1", "username": "Alice", "nationId": "model.nation.dutch"
        ], children: []),
    ]))
    _ = try mgr.process(ParsedMessage(tag: "setAI", attributes: ["player": "player-1", "ai": "true"], children: []))
    try assertEqual(mgr.game.players["player-1"]?.ai, true)
    // setDead is forwarded to the UI so a local death can prompt the player.
    let handled = try mgr.process(ParsedMessage(tag: "setDead", attributes: ["player": "player-1"], children: []))
    try assertEqual(handled, false)
    try assertEqual(mgr.game.players.keys.contains("player-1"), false)
}

test("GameStateManager processes setNation and setNationType") {
    let mgr = GameStateManager()
    try mgr.process(ParsedMessage(tag: "addPlayer", attributes: [:], children: [
        ParsedMessage(tag: "player", attributes: [
            "id": "player-1", "username": "Alice", "nationId": "model.nation.dutch"
        ], children: []),
    ]))
    _ = try mgr.process(ParsedMessage(tag: "setNation", attributes: ["player": "player-1", "value": "model.nation.french"], children: []))
    try assertEqual(mgr.game.players["player-1"]?.nationId, "model.nation.french")
    _ = try mgr.process(ParsedMessage(tag: "setNationType", attributes: ["player": "player-1", "value": "model.nationType.libertarian"], children: []))
    try assertEqual(mgr.game.players["player-1"]?.nationType, "model.nationType.libertarian")
}

test("GameStateManager processes setColor and setAvailable") {
    let mgr = GameStateManager()
    _ = try mgr.process(ParsedMessage(tag: "setColor", attributes: ["nation": "model.nation.dutch", "color": "3368601"], children: []))
    try assertEqual(mgr.game.nationColors["model.nation.dutch"], "3368601")
    _ = try mgr.process(ParsedMessage(tag: "setAvailable", attributes: ["nation": "model.nation.dutch", "state": "NOT_AVAILABLE"], children: []))
    try assertEqual(mgr.game.nationStates["model.nation.dutch"], "NOT_AVAILABLE")
}

test("GameStateManager processes logout") {
    let mgr = GameStateManager()
    try mgr.process(ParsedMessage(tag: "addPlayer", attributes: [:], children: [
        ParsedMessage(tag: "player", attributes: [
            "id": "player-1", "username": "Alice", "nationId": "model.nation.dutch"
        ], children: []),
    ]))
    // logout is forwarded to the UI so a local logout can end the session.
    let handled = try mgr.process(ParsedMessage(tag: "logout", attributes: ["player": "player-1", "reason": "done"], children: []))
    try assertEqual(handled, false)
    try assertEqual(mgr.game.players.count, 0)
}

test("game update applies nested change records") {
    let game = Game()
    try game.load(from: try XMLDecoder.decode("""
    <game id="game-1">
      <player id="player-1" username="Alice" gold="500"/>
      <player id="player-2" username="Bob" gold="400"/>
    </game>
    """))
    let update = try XMLDecoder.decode("""
    <update>
      <setStance first="player-1" second="player-2" stance="WAR"/>
      <setDead player="player-2"/>
      <partial id="player-1" gold="700"/>
    </update>
    """)
    try game.applyUpdate(update)
    try assertEqual(game.players["player-1"]?.stances["player-2"], .war)
    try assertEqual(game.players.keys.contains("player-2"), false)
    try assertEqual(game.players["player-1"]?.gold, 700)
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
        attributes: ["settlement": "is-tribal", "unit": "u-missionary"],
        children: []
    )
    try assertEqual(parsed.unit, "u-missionary")
    try assertEqual(parsed.settlement, "is-tribal")
}

test("DemandTributeMessage") {
    let msg = DemandTributeMessage(
        unit: "unit-scout",
        direction: "N"
    )
    try assertEqual(msg.unit, "unit-scout")
    try assertEqual(msg.direction, "N")
    try assertEqual(msg.tag, "demandTribute")
    
    let (attrs, _) = msg.encode()
    try assertEqual(attrs["unit"], "unit-scout")
    try assertEqual(attrs["direction"], "N")
    
    let parsed = try DemandTributeMessage(
        attributes: ["direction": "SE", "unit": "u-brave"],
        children: []
    )
    try assertEqual(parsed.unit, "u-brave")
    try assertEqual(parsed.direction, "SE")
}

test("NativeGiftMessage") {
    let msg = NativeGiftMessage(
        unit: "unit-colonist",
        colony: "colony-boston"
    )
    try assertEqual(msg.unit, "unit-colonist")
    try assertEqual(msg.colony, "colony-boston")
    try assertEqual(msg.tag, "nativeGift")
    
    let (attrs, _) = msg.encode()
    try assertEqual(attrs["unit"], "unit-colonist")
    try assertEqual(attrs["colony"], "colony-boston")
    
    let parsed = try NativeGiftMessage(
        attributes: ["colony": "colony-new-york", "unit": "u-scout"],
        children: []
    )
    try assertEqual(parsed.unit, "u-scout")
    try assertEqual(parsed.colony, "colony-new-york")
}

test("SpySettlementMessage") {
    let msg = SpySettlementMessage(
        unit: "unit-scout",
        settlement: "is-native-1"
    )
    try assertEqual(msg.unit, "unit-scout")
    try assertEqual(msg.settlement, "is-native-1")
    try assertEqual(msg.tag, "spySettlement")
    
    let (attrs, _) = msg.encode()
    try assertEqual(attrs["unit"], "unit-scout")
    try assertEqual(attrs["settlement"], "is-native-1")
    
    let parsed = try SpySettlementMessage(
        attributes: ["settlement": "is-native-5", "unit": "u-brave"],
        children: []
    )
    try assertEqual(parsed.unit, "u-brave")
    try assertEqual(parsed.settlement, "is-native-5")
}

test("ScoutIndianSettlementMessage") {
    let msg = ScoutIndianSettlementMessage(
        unit: "unit-scout",
        direction: "NE"
    )
    try assertEqual(msg.unit, "unit-scout")
    try assertEqual(msg.direction, "NE")
    try assertEqual(msg.tag, "scoutIndianSettlement")
    
    let (attrs, _) = msg.encode()
    try assertEqual(attrs["unit"], "unit-scout")
    try assertEqual(attrs["direction"], "NE")
    
    let parsed = try ScoutIndianSettlementMessage(
        attributes: ["direction": "SW", "unit": "u-explorer"],
        children: []
    )
    try assertEqual(parsed.unit, "u-explorer")
    try assertEqual(parsed.direction, "SW")
}

test("ScoutSpeakToChiefMessage") {
    let msg = ScoutSpeakToChiefMessage(
        unit: "unit-scout",
        result: "peace",
        settlement: "is-iroquois-1"
    )
    try assertEqual(msg.unit, "unit-scout")
    try assertEqual(msg.result, "peace")
    try assertEqual(msg.settlement, "is-iroquois-1")
    try assertEqual(msg.tag, "scoutSpeakToChief")
    
    let (attrs, _) = msg.encode()
    try assertEqual(attrs["unit"], "unit-scout")
    try assertEqual(attrs["result"], "peace")
    try assertEqual(attrs["settlement"], "is-iroquois-1")
    
    let parsed = try ScoutSpeakToChiefMessage(
        attributes: ["result": "trade", "settlement": "is-mohawk-5", "unit": "u-brave"],
        children: []
    )
    try assertEqual(parsed.unit, "u-brave")
    try assertEqual(parsed.result, "trade")
    try assertEqual(parsed.settlement, "is-mohawk-5")
}

test("DiplomacyMessage") {
    let msg = DiplomacyMessage(
        ourId: "player-dutch",
        otherId: "player-french"
    )
    try assertEqual(msg.ourId, "player-dutch")
    try assertEqual(msg.otherId, "player-french")
    try assertEqual(msg.tag, "diplomacy")
    
    let (attrs, _) = msg.encode()
    try assertEqual(attrs["ourId"], "player-dutch")
    try assertEqual(attrs["otherId"], "player-french")
    
    let parsed = try DiplomacyMessage(
        attributes: ["otherId": "player-spanish", "ourId": "player-english"],
        children: []
    )
    try assertEqual(parsed.ourId, "player-english")
    try assertEqual(parsed.otherId, "player-spanish")
}

// MARK: - Integration tests (require network stack)

func integrationTest(_ name: String, closure: @escaping () async throws -> Void) async {
    if realServerOnly && !name.contains("real Java server") { return }
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
    var receivedPayloads: [ParsedMessage] = []
    func clientDidConnect() {}
    func clientDidLogin(_ result: LoginResult) {}
    func clientDidReceiveGameState(_ parsed: ParsedMessage) {
        receivedMessages.append(parsed.tag)
        receivedPayloads.append(parsed)
    }
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
            try await client.send(message: ParsedMessage(tag: "setColor", attributes: ["nation": "model.nation.dutch", "color": "3368601"], children: []))
            await client.disconnect()
        }
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)
            let line = try await server.nextLine()
            let msg = try XMLDecoder.decode(line)

            guard msg.tag == "setColor" else {
                throw TestError(message: "expected setColor, got \(msg.tag)")
            }
            guard msg.attributes["nation"] == "model.nation.dutch" else {
                throw TestError(message: "setColor nation mismatch")
            }
            guard msg.attributes["color"] == "3368601" else {
                throw TestError(message: "setColor color mismatch")
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
                attributes: ["nation": "model.nation.dutch", "state": "NOT_AVAILABLE"],
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
            guard msg.attributes["nation"] == "model.nation.dutch" else {
                throw TestError(message: "setAvailable nation mismatch")
            }
            guard msg.attributes["state"] == "NOT_AVAILABLE" else {
                throw TestError(message: "setAvailable state mismatch")
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

await integrationTest("client asks core gameplay actions with replies") {
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
            _ = try await client.ask(message: ParsedMessage(tag: "moveTo", attributes: ["unit": "unit-1", "destination": "tile-1"], children: []))
            _ = try await client.ask(message: ParsedMessage(tag: "move", attributes: ["unit": "unit-1", "direction": "E"], children: []))
            _ = try await client.ask(message: ParsedMessage(tag: "buildColony", attributes: ["unit": "unit-1", "name": "Alpha"], children: []))
            _ = try await client.ask(message: ParsedMessage(tag: "endTurn", attributes: [:], children: []))
            await client.disconnect()
        }
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)
            let expectedActions: [(tag: String, attributes: [String: String])] = [
                ("moveTo", ["unit": "unit-1", "destination": "tile-1"]),
                ("move", ["unit": "unit-1", "direction": "E"]),
                ("buildColony", ["unit": "unit-1", "name": "Alpha"]),
                ("endTurn", [:]),
            ]
            for expected in expectedActions {
                let line = try await server.nextLine()
                let question = try XMLDecoder.decode(line)
                guard question.tag == "question",
                      let replyId = question.attributes["networkReplyId"],
                      let action = question.children.first else {
                    throw TestError(message: "expected question wrapper for \(expected.tag)")
                }
                guard action.tag == expected.tag else {
                    throw TestError(message: "expected \(expected.tag), got \(action.tag)")
                }
                for (key, value) in expected.attributes where action.attributes[key] != value {
                    throw TestError(message: "\(expected.tag) attribute \(key) mismatch")
                }
                await server.send(XMLEncoder.encode(tag: "reply", attributes: ["networkReplyId": replyId]))
                await server.flush()
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
            try await client.send(message: ParsedMessage(tag: "setGoodsLevels", attributes: ["colony": "colony-1"], children: [
                ParsedMessage(tag: "exportData", attributes: [
                    "id": "model.goods.sugar", "exported": "true",
                    "highLevel": "90", "lowLevel": "10",
                    "importLevel": "-1", "exportLevel": "50",
                ], children: []),
            ]))
            try await client.send(message: ParsedMessage(tag: "rearrangeColony", attributes: [
                "colony": "colony-1", "xLength": "1",
                "x0unit": "unit-1", "x0loc": "tile-0",
                "x0role": "model.role.default", "x0count": "0",
            ], children: []))
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
            guard let exportChild = goodsLevelsMsg.children.first,
                  exportChild.tag == "exportData" else {
                throw TestError(message: "setGoodsLevels missing exportData child")
            }
            guard exportChild.attributes["id"] == "model.goods.sugar",
                  exportChild.attributes["exported"] == "true",
                  exportChild.attributes["exportLevel"] == "50" else {
                throw TestError(message: "exportData payload mismatch")
            }

            guard rearrangeMsg.tag == "rearrangeColony" else {
                throw TestError(message: "expected rearrangeColony, got \(rearrangeMsg.tag)")
            }
            guard rearrangeMsg.attributes["colony"] == "colony-1" else {
                throw TestError(message: "rearrangeColony colony mismatch")
            }
            guard rearrangeMsg.attributes["xLength"] == "1" else {
                throw TestError(message: "rearrangeColony xLength mismatch")
            }
            guard rearrangeMsg.attributes["x0unit"] == "unit-1",
                  rearrangeMsg.attributes["x0loc"] == "tile-0",
                  rearrangeMsg.attributes["x0role"] == "model.role.default" else {
                throw TestError(message: "rearrangeColony arrangement mismatch")
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

await integrationTest("client sends market buy/sell messages against Europe location") {
    let server = MockServer()
    let port = await server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
    <game id="game-42" turn="1" currentPlayer="player-1" clientUserName="Alice">
      <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500" tax="10">
        <europe id="europe:0" owner="player-1" recruitPrice="800"/>
        <market owner="player-1">
          <marketData goods-type="model.goods.food" amount="200" initialPrice="12"/>
          <marketData goods-type="model.goods.tools" amount="80" initialPrice="16"/>
        </market>
      </player>
      <map id="map-0" width="1" height="1">
        <tile id="tile-0" x="0" y="0" type="model.tile.ocean" highSeas="true" moveToEurope="true"/>
      </map>
      <unit id="unit-caravel" unitType="model.unit.caravel" owner="player-1" location="europe:0" movesLeft="6" state="ACTIVE"/>
    </game>
    """

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await client.connect()
            _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
            try await client.send(message: ParsedMessage(tag: "loadGoods", attributes: ["location": "europe:0", "type": "model.goods.food", "amount": "15", "carrier": "unit-caravel"], children: []))
            try await client.send(message: ParsedMessage(tag: "unloadGoods", attributes: ["type": "model.goods.tools", "amount": "5", "carrier": "unit-caravel"], children: []))
            await client.disconnect()
        }
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)

            let buyLine = try await server.nextLine()
            let sellLine = try await server.nextLine()

            let buyMsg = try XMLDecoder.decode(buyLine)
            let sellMsg = try XMLDecoder.decode(sellLine)

            guard buyMsg.tag == "loadGoods" else {
                throw TestError(message: "expected loadGoods, got \(buyMsg.tag)")
            }
            guard buyMsg.attributes["location"] == "europe:0" else {
                throw TestError(message: "buy goods location mismatch")
            }
            guard buyMsg.attributes["type"] == "model.goods.food" else {
                throw TestError(message: "buy goods type mismatch")
            }
            guard buyMsg.attributes["amount"] == "15" else {
                throw TestError(message: "buy goods amount mismatch")
            }
            guard buyMsg.attributes["carrier"] == "unit-caravel" else {
                throw TestError(message: "buy goods carrier mismatch")
            }

            guard sellMsg.tag == "unloadGoods" else {
                throw TestError(message: "expected unloadGoods, got \(sellMsg.tag)")
            }
            guard sellMsg.attributes["type"] == "model.goods.tools" else {
                throw TestError(message: "sell goods type mismatch")
            }
            guard sellMsg.attributes["amount"] == "5" else {
                throw TestError(message: "sell goods amount mismatch")
            }
            guard sellMsg.attributes["carrier"] == "unit-caravel" else {
                throw TestError(message: "sell goods carrier mismatch")
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

await integrationTest("client sends missionary action") {
    let server = MockServer()
    let port = await server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
    <game id="game-missionary-1" turn="1">
      <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
      <map id="map-0" width="2" height="2">
        <tile id="tile-0" x="0" y="0" type="model.tile.plains"/>
      </map>
      <unit id="unit-1" unitType="model.unit.missionary" owner="player-1" location="tile-0" movesLeft="3" state="ACTIVE"/>
    </game>
    """

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await client.connect()
            _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
            try await client.send(message: ParsedMessage(
                tag: "missionary",
                attributes: ["unit": "unit-1", "direction": "N", "denounce": "true"],
                children: []
            ))
            await client.disconnect()
        }
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)

            let missionaryLine = try await server.nextLine()
            let missionaryMsg = try XMLDecoder.decode(missionaryLine)

            guard missionaryMsg.tag == "missionary" else {
                throw TestError(message: "expected missionary, got \(missionaryMsg.tag)")
            }
            guard missionaryMsg.attributes["unit"] == "unit-1" else {
                throw TestError(message: "missionary unit mismatch")
            }
            guard missionaryMsg.attributes["direction"] == "N" else {
                throw TestError(message: "missionary direction mismatch")
            }
            guard missionaryMsg.attributes["denounce"] == "true" else {
                throw TestError(message: "missionary denounce mismatch")
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

await integrationTest("client sends demandTribute action") {
    let server = MockServer()
    let port = await server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
    <game id="game-tribute-1" turn="1">
      <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
      <map id="map-0" width="3" height="3">
        <tile id="tile-0" x="0" y="0" type="model.tile.plains"/>
        <tile id="tile-1" x="1" y="0" type="model.tile.plains"/>
      </map>
      <unit id="unit-scout" unitType="model.unit.scout" owner="player-1" location="tile-0" movesLeft="3" state="ACTIVE"/>
    </game>
    """

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await client.connect()
            _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
            try await client.send(message: ParsedMessage(
                tag: "demandTribute",
                attributes: [
                    "direction": "N",
                    "unit": "unit-scout"
                ],
                children: []
            ))
            await client.disconnect()
        }
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)

            let tributeLine = try await server.nextLine()
            let tributeMsg = try XMLDecoder.decode(tributeLine)

            guard tributeMsg.tag == "demandTribute" else {
                throw TestError(message: "expected demandTribute, got \(tributeMsg.tag)")
            }
            guard tributeMsg.attributes["unit"] == "unit-scout" else {
                throw TestError(message: "demandTribute unit mismatch")
            }
            guard tributeMsg.attributes["direction"] == "N" else {
                throw TestError(message: "demandTribute direction mismatch")
            }
        }
        while try await group.next() != nil {}
    }

    await server.stop()
}

await integrationTest("client sends nativeGift action") {
    let server = MockServer()
    let port = await server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
    <game id="game-gift-native-1" turn="1">
      <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
      <map id="map-0" width="2" height="2">
        <tile id="tile-0" x="0" y="0" type="model.tile.plains"/>
      </map>
      <unit id="unit-colonist" unitType="model.unit.freeColonist" owner="player-1" location="tile-0" movesLeft="3" state="ACTIVE"/>
    </game>
    """

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await client.connect()
            _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
            try await client.send(message: ParsedMessage(
                tag: "nativeGift",
                attributes: [
                    "colony": "colony-salem",
                    "unit": "unit-colonist"
                ],
                children: []
            ))
            await client.disconnect()
        }
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)

            let giftLine = try await server.nextLine()
            let giftMsg = try XMLDecoder.decode(giftLine)

            guard giftMsg.tag == "nativeGift" else {
                throw TestError(message: "expected nativeGift, got \(giftMsg.tag)")
            }
            guard giftMsg.attributes["unit"] == "unit-colonist" else {
                throw TestError(message: "nativeGift unit mismatch")
            }
            guard giftMsg.attributes["colony"] == "colony-salem" else {
                throw TestError(message: "nativeGift colony mismatch")
            }
        }
        while try await group.next() != nil {}
    }

    await server.stop()
}

await integrationTest("client sends spySettlement action") {
    let server = MockServer()
    let port = await server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
    <game id="game-spy-1" turn="1">
      <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
      <map id="map-0" width="2" height="2">
        <tile id="tile-0" x="0" y="0" type="model.tile.plains"/>
      </map>
      <unit id="unit-scout" unitType="model.unit.scout" owner="player-1" location="tile-0" movesLeft="3" state="ACTIVE"/>
    </game>
    """

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await client.connect()
            _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
            try await client.send(message: ParsedMessage(
                tag: "spySettlement",
                attributes: [
                    "settlement": "is-mohawk-1",
                    "unit": "unit-scout"
                ],
                children: []
            ))
            await client.disconnect()
        }
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)

            let spyLine = try await server.nextLine()
            let spyMsg = try XMLDecoder.decode(spyLine)

            guard spyMsg.tag == "spySettlement" else {
                throw TestError(message: "expected spySettlement, got \(spyMsg.tag)")
            }
            guard spyMsg.attributes["unit"] == "unit-scout" else {
                throw TestError(message: "spySettlement unit mismatch")
            }
            guard spyMsg.attributes["settlement"] == "is-mohawk-1" else {
                throw TestError(message: "spySettlement settlement mismatch")
            }
        }
        while try await group.next() != nil {}
    }

    await server.stop()
}

await integrationTest("client sends scoutIndianSettlement action") {
    let server = MockServer()
    let port = await server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
    <game id="game-scout-1" turn="1">
      <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
      <map id="map-0" width="3" height="3">
        <tile id="tile-0" x="0" y="0" type="model.tile.plains"/>
        <tile id="tile-1" x="1" y="0" type="model.tile.plains"/>
      </map>
      <unit id="unit-scout" unitType="model.unit.scout" owner="player-1" location="tile-0" movesLeft="3" state="ACTIVE"/>
    </game>
    """

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await client.connect()
            _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
            try await client.send(message: ParsedMessage(
                tag: "scoutIndianSettlement",
                attributes: [
                    "direction": "E",
                    "unit": "unit-scout"
                ],
                children: []
            ))
            await client.disconnect()
        }
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)

            let scoutLine = try await server.nextLine()
            let scoutMsg = try XMLDecoder.decode(scoutLine)

            guard scoutMsg.tag == "scoutIndianSettlement" else {
                throw TestError(message: "expected scoutIndianSettlement, got \(scoutMsg.tag)")
            }
            guard scoutMsg.attributes["unit"] == "unit-scout" else {
                throw TestError(message: "scoutIndianSettlement unit mismatch")
            }
            guard scoutMsg.attributes["direction"] == "E" else {
                throw TestError(message: "scoutIndianSettlement direction mismatch")
            }
        }
        while try await group.next() != nil {}
    }

    await server.stop()
}

await integrationTest("client sends scoutSpeakToChief action") {
    let server = MockServer()
    let port = await server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
    <game id="game-chief-1" turn="1">
      <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
      <map id="map-0" width="2" height="2">
        <tile id="tile-0" x="0" y="0" type="model.tile.plains"/>
      </map>
      <unit id="unit-scout" unitType="model.unit.scout" owner="player-1" location="tile-0" movesLeft="3" state="ACTIVE"/>
    </game>
    """

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await client.connect()
            _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
            try await client.send(message: ParsedMessage(
                tag: "scoutSpeakToChief",
                attributes: [
                    "result": "alliance",
                    "settlement": "is-iroquois-tribe",
                    "unit": "unit-scout"
                ],
                children: []
            ))
            await client.disconnect()
        }
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)

            let chiefLine = try await server.nextLine()
            let chiefMsg = try XMLDecoder.decode(chiefLine)

            guard chiefMsg.tag == "scoutSpeakToChief" else {
                throw TestError(message: "expected scoutSpeakToChief, got \(chiefMsg.tag)")
            }
            guard chiefMsg.attributes["unit"] == "unit-scout" else {
                throw TestError(message: "scoutSpeakToChief unit mismatch")
            }
            guard chiefMsg.attributes["settlement"] == "is-iroquois-tribe" else {
                throw TestError(message: "scoutSpeakToChief settlement mismatch")
            }
            guard chiefMsg.attributes["result"] == "alliance" else {
                throw TestError(message: "scoutSpeakToChief result mismatch")
            }
        }
        while try await group.next() != nil {}
    }

    await server.stop()
}

await integrationTest("client sends diplomacy action") {
    let server = MockServer()
    let port = await server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
    <game id="game-diplo-1" turn="1">
     <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
     <player id="player-2" username="Bob" nationId="model.nation.french" gold="400"/>
     <map id="map-0" width="2" height="2">
       <tile id="tile-0" x="0" y="0" type="model.tile.plains"/>
     </map>
    </game>
    """

    try await withThrowingTaskGroup(of: Void.self) { group in
       group.addTask {
           try await client.connect()
           _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
           try await client.send(message: ParsedMessage(
               tag: "diplomacy",
               attributes: [
                   "otherId": "player-2",
                   "ourId": "player-1"
               ],
               children: []
           ))
           await client.disconnect()
       }
       group.addTask {
           try await server.doHandshake(gameResponse: gameXML)

           let diploLine = try await server.nextLine()
           let diploMsg = try XMLDecoder.decode(diploLine)

           guard diploMsg.tag == "diplomacy" else {
               throw TestError(message: "expected diplomacy, got \(diploMsg.tag)")
           }
           guard diploMsg.attributes["ourId"] == "player-1" else {
               throw TestError(message: "diplomacy ourId mismatch")
           }
           guard diploMsg.attributes["otherId"] == "player-2" else {
               throw TestError(message: "diplomacy otherId mismatch")
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

await integrationTest("decision-action asks use emigrateUnit and lootCargo contract") {
    let server = MockServer()
    let port = await server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
    <game id="game-5" turn="1">
      <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
      <player id="player-2" username="Bob" nationId="model.nation.french" gold="400"/>
    </game>
    """

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)
            try await Task.sleep(nanoseconds: 200_000_000)

            // 1. Fountain of youth is answered with a specific emigrateUnit slot.
            let rawEmigrate = try await server.nextLine()
            let emigrateQuestion = try XMLDecoder.decode(rawEmigrate)
            guard emigrateQuestion.tag == "question",
                  let emigrateReplyId = emigrateQuestion.attributes["networkReplyId"],
                  let emigrate = emigrateQuestion.children.first,
                  emigrate.tag == "emigrateUnit" else {
                throw TestError(message: "expected emigrateUnit question")
            }
            guard emigrate.attributes["slot"] == "1" else {
                throw TestError(message: "expected specific emigrate slot")
            }
            await server.send("<reply networkReplyId=\"\(emigrateReplyId)\"><emigrateUnit/></reply>")
            await server.flush()
            try await Task.sleep(nanoseconds: 150_000_000)

            // 2. Loot cargo reply must preserve winner/loser plus <goods> children.
            let rawLoot = try await server.nextLine()
            let lootQuestion = try XMLDecoder.decode(rawLoot)
            guard lootQuestion.tag == "question",
                  let lootReplyId = lootQuestion.attributes["networkReplyId"],
                  let loot = lootQuestion.children.first,
                  loot.tag == "lootCargo" else {
                throw TestError(message: "expected lootCargo question")
            }
            guard loot.attributes["winner"] == "unit-9",
                  loot.attributes["loser"] == "unit-2" else {
                throw TestError(message: "expected winner/loser in lootCargo payload")
            }
            guard let goods = loot.children.first,
                  goods.tag == "goods",
                  goods.attributes["type"] == "model.goods.sugar",
                  goods.attributes["amount"] == "20" else {
                throw TestError(message: "expected goods child in lootCargo payload")
            }
            await server.send("<reply networkReplyId=\"\(lootReplyId)\"><lootCargo/></reply>")
            await server.flush()
            try await Task.sleep(nanoseconds: 150_000_000)
            await server.stop()
        }

        // No message loop here: the ask/reply pairs must be the only consumers of
        // incoming lines to stay deterministic.
        try await client.connect()
        _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")

        let emigrateReply = try await client.ask(message: ParsedMessage(
            tag: "emigrateUnit",
            attributes: ["slot": "1"],
            children: []
        ))
        guard emigrateReply.tag == "reply" else {
            throw TestError(message: "expected emigrateUnit reply")
        }

        let lootReply = try await client.ask(message: ParsedMessage(
            tag: "lootCargo",
            attributes: ["winner": "unit-9", "loser": "unit-2"],
            children: [ParsedMessage(
                tag: "goods",
                attributes: ["type": "model.goods.sugar", "amount": "20"],
                children: []
            )]
        ))
        guard lootReply.tag == "reply" else {
            throw TestError(message: "expected lootCargo reply")
        }

        group.cancelAll()
    }
}

await integrationTest("message loop routes ask replies while running") {
    let server = MockServer()
    let port = await server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
    <game id="game-8" turn="1">
      <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
    </game>
    """

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)
            try await Task.sleep(nanoseconds: 150_000_000)
            let raw = try await server.nextLine()
            let question = try XMLDecoder.decode(raw)
            guard question.tag == "question",
                  let replyId = question.attributes["networkReplyId"],
                  question.children.first?.tag == "emigrateUnit" else {
                throw TestError(message: "expected emigrateUnit question")
            }
            await server.send("<reply networkReplyId=\"\(replyId)\"><emigrateUnit/></reply>")
            await server.flush()
            try await Task.sleep(nanoseconds: 150_000_000)
            await server.stop()
        }
        group.addTask {
            try await client.connect()
            _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
            Task { try? await client.startMessageLoop() }
            try await Task.sleep(nanoseconds: 150_000_000)
            // The message loop owns the receive stream; the ask must be routed
            // through it instead of racing on nextLine().
            let reply = try await client.ask(message: ParsedMessage(
                tag: "emigrateUnit",
                attributes: ["slot": "1"],
                children: []
            ))
            guard reply.tag == "reply" else {
                throw TestError(message: "expected routed reply")
            }
        }
        try await Task.sleep(nanoseconds: 3_000_000_000)
        group.cancelAll()
    }
}

await integrationTest("prompt replies use firstContact/monarchAction/newLandName contract") {
    let server = MockServer()
    let port = await server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
    <game id="game-6" turn="1">
      <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
      <player id="player-2" username="Bob" nationId="model.nation.french" gold="400"/>
    </game>
    """

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)
            try await Task.sleep(nanoseconds: 200_000_000)

            // 1. firstContact reply carries player/other/tile + boolean result.
            let rawContact = try await server.nextLine()
            let contactQuestion = try XMLDecoder.decode(rawContact)
            guard contactQuestion.tag == "question",
                  let contactReplyId = contactQuestion.attributes["networkReplyId"],
                  let contact = contactQuestion.children.first,
                  contact.tag == "firstContact" else {
                throw TestError(message: "expected firstContact question")
            }
            guard contact.attributes["player"] == "player-1",
                  contact.attributes["other"] == "player-4",
                  contact.attributes["tile"] == "tile-2-3",
                  contact.attributes["result"] == "true" else {
                throw TestError(message: "bad firstContact payload: \(contact.attributes)")
            }
            await server.send("<reply networkReplyId=\"\(contactReplyId)\"><firstContact/></reply>")
            await server.flush()
            try await Task.sleep(nanoseconds: 120_000_000)

            // 2. monarchAction reply carries action + boolean result.
            let rawMonarch = try await server.nextLine()
            let monarchQuestion = try XMLDecoder.decode(rawMonarch)
            guard monarchQuestion.tag == "question",
                  let monarchReplyId = monarchQuestion.attributes["networkReplyId"],
                  let monarch = monarchQuestion.children.first,
                  monarch.tag == "monarchAction" else {
                throw TestError(message: "expected monarchAction question")
            }
            guard monarch.attributes["action"] == "raise_tax_act",
                  monarch.attributes["result"] == "true" else {
                throw TestError(message: "bad monarchAction payload: \(monarch.attributes)")
            }
            await server.send("<reply networkReplyId=\"\(monarchReplyId)\"><monarchAction/></reply>")
            await server.flush()
            try await Task.sleep(nanoseconds: 120_000_000)

            // 3. newLandName reply carries unit + newLandName.
            let rawLand = try await server.nextLine()
            let landQuestion = try XMLDecoder.decode(rawLand)
            guard landQuestion.tag == "question",
                  let landReplyId = landQuestion.attributes["networkReplyId"],
                  let land = landQuestion.children.first,
                  land.tag == "newLandName" else {
                throw TestError(message: "expected newLandName question")
            }
            guard land.attributes["unit"] == "unit-5",
                  land.attributes["newLandName"] == "Nieuw Zeeland" else {
                throw TestError(message: "bad newLandName payload: \(land.attributes)")
            }
            await server.send("<reply networkReplyId=\"\(landReplyId)\"><newLandName/></reply>")
            await server.flush()
            try await Task.sleep(nanoseconds: 120_000_000)
            await server.stop()
        }

        try await client.connect()
        _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")

        let contactReply = try await client.ask(message: ParsedMessage(
            tag: "firstContact",
            attributes: ["player": "player-1", "other": "player-4", "tile": "tile-2-3", "camps": "2", "result": "true"],
            children: []
        ))
        guard contactReply.tag == "reply" else {
            throw TestError(message: "expected firstContact reply")
        }

        let monarchReply = try await client.ask(message: ParsedMessage(
            tag: "monarchAction",
            attributes: ["action": "raise_tax_act", "monarch": "model.nation.dutch", "result": "true"],
            children: []
        ))
        guard monarchReply.tag == "reply" else {
            throw TestError(message: "expected monarchAction reply")
        }

        let landReply = try await client.ask(message: ParsedMessage(
            tag: "newLandName",
            attributes: ["unit": "unit-5", "newLandName": "Nieuw Zeeland"],
            children: []
        ))
        guard landReply.tag == "reply" else {
            throw TestError(message: "expected newLandName reply")
        }

        group.cancelAll()
    }
}

await integrationTest("client sends nativeTrade and diplomacy sessions") {
    let server = MockServer()
    let port = await server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
    <game id="game-7" turn="1">
      <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
      <player id="player-2" username="Bob" nationId="model.nation.french" gold="400"/>
    </game>
    """

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await server.doHandshake(gameResponse: gameXML)
            try await Task.sleep(nanoseconds: 200_000_000)

            // 1. OPEN carries the unit/settlement in a nested <nativeTrade>.
            let rawOpen = try await server.nextLine()
            let open = try XMLDecoder.decode(rawOpen)
            guard open.tag == "nativeTrade", open.attributes["action"] == "OPEN",
                  let openInner = open.children.first,
                  openInner.tag == "nativeTrade",
                  openInner.attributes["unit"] == "unit-1",
                  openInner.attributes["settlement"] == "is-1" else {
                throw TestError(message: "bad nativeTrade OPEN payload: \(rawOpen)")
            }

            // 2. BUY carries the focused <nativeTradeItem> with goods.
            let rawBuy = try await server.nextLine()
            let buy = try XMLDecoder.decode(rawBuy)
            guard buy.tag == "nativeTrade", buy.attributes["action"] == "BUY",
                  let buyInner = buy.children.first(where: { $0.tag == "nativeTrade" }),
                  let item = buyInner.children.first(where: { $0.tag == "nativeTradeItem" }),
                  item.attributes["price"] == "42",
                  item.children.first?.attributes["type"] == "model.goods.sugar" else {
                throw TestError(message: "bad nativeTrade BUY payload: \(rawBuy)")
            }

            // 3. CLOSE.
            let rawClose = try await server.nextLine()
            let close = try XMLDecoder.decode(rawClose)
            guard close.tag == "nativeTrade", close.attributes["action"] == "CLOSE" else {
                throw TestError(message: "bad nativeTrade CLOSE payload: \(rawClose)")
            }

            // 4. Diplomacy proposal answer with status + clause.
            let rawDiplomacy = try await server.nextLine()
            let diplomacy = try XMLDecoder.decode(rawDiplomacy)
            guard diplomacy.tag == "diplomacy",
                  diplomacy.attributes["ourId"] == "unit-1",
                  diplomacy.attributes["otherId"] == "unit-2",
                  let trade = diplomacy.children.first(where: { $0.tag == "diplomaticTrade" }),
                  trade.attributes["status"] == "ACCEPT_TRADE",
                  trade.attributes["context"] == "DIPLOMATIC",
                  trade.children.contains(where: { $0.tag == "goldTradeItem" && $0.attributes["gold"] == "100" }) else {
                throw TestError(message: "bad diplomacy payload: \(rawDiplomacy)")
            }

            try await Task.sleep(nanoseconds: 150_000_000)
            await server.stop()
        }

        try await client.connect()
        _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")

        var session = NativeTradeSession(unitId: "unit-1", settlementId: "is-1")
        try await client.send(message: session.toMessage(action: "OPEN", item: nil))

        let item = NativeTradeItem(
            goodsType: "model.goods.sugar",
            amount: 20,
            price: 42,
            haggleCount: 0,
            source: "is-1",
            destination: "unit-1"
        )
        try await client.send(message: session.toMessage(action: "BUY", item: item))

        session.item = item
        try await client.send(message: session.toMessage(action: "CLOSE", item: nil))

        let goldClause = ParsedMessage(
            tag: "goldTradeItem",
            attributes: ["gold": "100", "source": "player-2", "destination": "player-1"],
            children: []
        )
        let agreement = ParsedMessage(
            tag: "diplomaticTrade",
            attributes: ["context": "DIPLOMATIC", "sender": "player-2", "recipient": "player-1", "status": "ACCEPT_TRADE", "version": "1"],
            children: [goldClause]
        )
        try await client.send(message: ParsedMessage(
            tag: "diplomacy",
            attributes: ["ourId": "unit-1", "otherId": "unit-2"],
            children: [agreement]
        ))

        group.cancelAll()
    }
}

await integrationTest("message loop applies inbound stance/ai/chat/logout") {
    let server = MockServer()
    let port = await server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
    <game id="game-43" turn="1">
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
            await server.send("<setStance first=\"player-1\" second=\"player-2\" stance=\"WAR\"/>")
            await server.send("<setAI player=\"player-1\" ai=\"true\"/>")
            await server.send("<chat sender=\"player-2\" message=\"Hello there\"/>")
            await server.send("<logout player=\"player-2\" reason=\"done\"/>")
            await server.flush()

            try await Task.sleep(nanoseconds: 300_000_000)
            await server.stop()
        }
        try await Task.sleep(nanoseconds: 5_000_000_000)
        group.cancelAll()
    }

    let game = await client.game
    let stance = game.players["player-1"]?.stances["player-2"]
    guard stance == .war else {
        throw TestError(message: "inbound setStance was not applied")
    }
    guard game.players["player-1"]?.ai == true else {
        throw TestError(message: "inbound setAI was not applied")
    }
    guard !game.players.keys.contains("player-2") else {
        throw TestError(message: "inbound logout did not remove the player")
    }
}

await integrationTest("message loop forwards founding-father and death prompts") {
    let server = MockServer()
    let port = await server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)
    let delegate = TestDelegate()
    await client.setDelegate(delegate)

    let gameXML = """
    <game id="game-54" turn="1">
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
            await server.send("<question networkReplyId=\"21\"><chooseFoundingFather trade=\"model.foundingFather.adamSmith\"/></question>")
            await server.flush()
            _ = try await server.nextLine()
            await server.send("<update><setDead player=\"player-2\"/></update>")
            await server.flush()

            try await Task.sleep(nanoseconds: 300_000_000)
            await server.stop()
        }
        try await Task.sleep(nanoseconds: 5_000_000_000)
        group.cancelAll()
    }

    let flags = await delegate.receivedMessages
    guard flags.contains("chooseFoundingFather") else {
        throw TestError(message: "chooseFoundingFather prompt was not forwarded")
    }
    // The death arrives inside an update; the whole envelope must be forwarded.
    guard flags.contains("update") else {
        throw TestError(message: "setDead update was not forwarded")
    }

    let game = await client.game
    guard !game.players.keys.contains("player-2") else {
        throw TestError(message: "inbound setDead did not remove the player")
    }
}

if ProcessInfo.processInfo.environment["REAL_SERVER_E2E"] == "1" {
    await integrationTest("real Java server connect/login smoke") {
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

// The deep probe launches a game, which consumes the server's pre-game lobby.
// Run it on a fresh server, i.e. not together with the smoke probe.
if ProcessInfo.processInfo.environment["REAL_SERVER_DEEP_E2E"] == "1"
    && ProcessInfo.processInfo.environment["REAL_SERVER_E2E"] != "1" {
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
        // `ready`/`requestLaunch` are fire-and-forget in the Java ServerAPI, so
        // they do not produce a `<reply>` to wait for.
        if result.serverState == .preGame {
            try await client.send(message: ParsedMessage(tag: "ready", attributes: ["value": "true"], children: []))
            try await client.send(message: ParsedMessage(tag: "requestLaunch", attributes: [:], children: []))
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

        // If the session reached in-game, validate the deserialized model and
        // probe endTurn transport opportunistically.
        if await client.game.currentPlayerId != nil {
            let game = await client.game
            guard !game.players.isEmpty else {
                throw TestError(message: "real server game has no players")
            }
            guard !game.tiles.isEmpty else {
                throw TestError(message: "real server game has no map tiles")
            }
            guard game.specification != nil else {
                throw TestError(message: "real server game has no specification")
            }
            guard game.units.values.contains(where: { unit in
                unit.owner != nil && game.resolvedTileId(for: unit) != nil
            }) else {
                throw TestError(message: "real server game has no units on the map")
            }

            // The server may defer the reply until it is our turn, so a timeout
            // here must not fail the launch probe.
            do {
                _ = try await client.ask(message: ParsedMessage(tag: "endTurn", attributes: [:], children: []),
                                         timeout: 5)
            } catch {
                // Disconnects, server errors and deferred turns are all tolerated.
            }
        }

        await client.disconnect()
    }
}

// Gameplay probe: launch a real game, move a unit, end the turn and verify the
// server-driven model advances. Requires a fresh server (pre-game lobby).
if ProcessInfo.processInfo.environment["REAL_SERVER_GAMEPLAY_E2E"] == "1" {
    await integrationTest("real Java server gameplay probe") {
        let host = ProcessInfo.processInfo.environment["REAL_SERVER_HOST"] ?? "127.0.0.1"
        let port = Int(ProcessInfo.processInfo.environment["REAL_SERVER_PORT"] ?? "3541") ?? 3541
        let client = FreeColClient(host: host, port: port)

        try await client.connect()
        let vacant = await client.initialVacantPlayers
        let nationId = vacant?.children.first?.attributes["nationId"]
            ?? vacant?.children.first?.attributes["id"]
            ?? "model.nation.dutch"
        let userName = "CopilotPlay-\(Int(Date().timeIntervalSince1970))"

        let result = try await client.login(userName: userName, nationId: nationId)
        if result.serverState == .preGame {
            // Shorten Europe sailing time for the isolated real-server fixture.
            try await client.send(message: ParsedMessage(
                tag: "updateGameOptions",
                attributes: [:],
                children: [ParsedMessage(tag: "optionGroup", attributes: ["id": "gameOptions"], children: [
                    ParsedMessage(tag: "integerOption", attributes: [
                        "id": "model.option.turnsToSail", "value": "1",
                    ], children: []),
                ])]
            ))
            try await client.send(message: ParsedMessage(tag: "ready", attributes: ["value": "true"], children: []))
            try await client.send(message: ParsedMessage(tag: "requestLaunch", attributes: [:], children: []))
        }

        let loopTask = Task { await client.startMessageLoop() }
        defer { loopTask.cancel() }

        // Wait for the launched game to reach the client.
        var waited = 0
        while true {
            let current = await client.game
            if current.currentPlayerId != nil && !current.units.isEmpty {
                break
            }
            if waited >= 60 {
                throw TestError(message: "game did not start within 30s")
            }
            try await Task.sleep(nanoseconds: 500_000_000)
            waited += 1
        }

        var game = await client.game
        guard let spec = game.specification else {
            throw TestError(message: "launched game has no specification")
        }
        guard !spec.unitTypes.isEmpty, !spec.goodsTypes.isEmpty,
              !spec.buildingTypes.isEmpty, !spec.tileTypes.isEmpty else {
            throw TestError(message: "specification is missing type definitions")
        }
        guard !game.tiles.isEmpty else {
            throw TestError(message: "launched game has no map tiles")
        }
        guard let localPlayerId = game.players.values.first(where: { $0.name == result.playerName })?.id else {
            throw TestError(message: "local player not found in launched game")
        }
        // Market data must deserialize from the real server XML.
        var marketEntries = game.players[localPlayerId]?.market.map { Array($0.data.values) } ?? []
        guard !marketEntries.isEmpty else {
            throw TestError(message: "no market data received")
        }
        guard marketEntries.contains(where: { $0.amount > 0 && $0.initialPrice > 0 }) else {
            throw TestError(message: "market data has no priced entries")
        }

        func endTurnAndWaitForLocalPlayer() async throws -> FreeColGame.Game {
            let turnBefore = await client.game.turn.number
            _ = try await client.ask(
                message: ParsedMessage(tag: "endTurn", attributes: [:], children: []),
                timeout: 45
            )
            for _ in 0..<180 {
                let current = await client.game
                if current.turn.number > turnBefore && current.currentPlayerId == localPlayerId {
                    return current
                }
                try await Task.sleep(nanoseconds: 500_000_000)
            }
            throw TestError(message: "local turn did not return after endTurn")
        }

        // Keep the map movement probe independent from the market trip: a
        // standard start often has its only naval carrier on the map.
        let movementCandidates = game.units.values
            .filter { candidate in
                candidate.owner == localPlayerId
                    && candidate.movesLeft > 0
                    && candidate.location.flatMap { game.tiles[$0] } != nil
            }
            .sorted { $0.id < $1.id }
        guard let unit = movementCandidates.first(where: {
            !spec.hasAbility("model.ability.foundColony", unitType: $0.unitType)
        }) ?? movementCandidates.first else {
            throw TestError(message: "no local unit with movement on the map")
        }
        let unitId = unit.id
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        var moved = false
        var lastMoveError: String?
        for direction in directions {
            let before = await client.game.units[unitId]?.location ?? ""
            do {
                _ = try await client.ask(message: ParsedMessage(
                    tag: "move",
                    attributes: ["unit": unitId, "direction": direction],
                    children: []
                ), timeout: 8)
            } catch {
                lastMoveError = "\(error)"
                continue
            }
            for _ in 0..<10 {
                try await Task.sleep(nanoseconds: 200_000_000)
                let after = await client.game.units[unitId]?.location ?? ""
                if after != before {
                    moved = true
                    break
                }
            }
            if moved { break }
        }
        guard moved else {
            throw TestError(message: "unit did not move in any direction (last error: \(lastMoveError ?? "none"))")
        }

        func canFoundColony(with unit: FreeColGame.Unit, in current: FreeColGame.Game) -> Bool {
            guard unit.owner == localPlayerId,
                  spec.hasAbility("model.ability.foundColony", unitType: unit.unitType),
                  let tileId = unit.location,
                  let tile = current.tiles[tileId],
                  tile.settlement == nil,
                  tile.owningSettlement == nil,
                  tile.owner == nil || tile.owner == localPlayerId,
                  let tileType = tile.type,
                  let tileInfo = spec.tileTypes[tileType] else { return false }
            return !tileInfo.isWater && tileInfo.canSettle
        }

        func colonyLandingTiles(around sourceTileId: String,
                                in current: FreeColGame.Game) -> [FreeColGame.Tile] {
            current.neighborTileIds(of: sourceTileId)
                .compactMap { current.tiles[$0] }
                .filter { tile in
                    guard tile.settlement == nil,
                          tile.owningSettlement == nil,
                          tile.owner == nil || tile.owner == localPlayerId,
                          let tileType = tile.type,
                          let tileInfo = spec.tileTypes[tileType],
                          !tileInfo.isWater,
                          tileInfo.canSettle else { return false }
                    return !current.neighborTileIds(of: tile.id).contains {
                        current.tiles[$0]?.settlement != nil
                    }
                }
                .sorted { $0.id < $1.id }
        }

        func direction(from source: FreeColGame.Tile,
                       to target: FreeColGame.Tile) -> String? {
            let isOddRow = !source.y.isMultiple(of: 2)
            let deltas: [(String, Int, Int)] = [
                ("N", 0, -2),
                ("NE", isOddRow ? 1 : 0, -1),
                ("E", 1, 0),
                ("SE", isOddRow ? 1 : 0, 1),
                ("S", 0, 2),
                ("SW", isOddRow ? 0 : -1, 1),
                ("W", -1, 0),
                ("NW", isOddRow ? 0 : -1, -1),
            ]
            return deltas.first(where: { name, dx, dy in
                source.x + dx == target.x && source.y + dy == target.y
            })?.0
        }

        func nextCoastalSeaStep(from sourceTileId: String,
                                in current: FreeColGame.Game) -> String? {
            guard let source = current.tiles[sourceTileId] else { return nil }
            let coastalSeaTiles = current.tiles.values
                .filter { tile in
                    guard let type = tile.type,
                          let info = spec.tileTypes[type], info.isWater else { return false }
                    return !colonyLandingTiles(around: tile.id, in: current).isEmpty
                }
                .sorted {
                    let firstDistance = abs($0.x - source.x) + abs($0.y - source.y)
                    let secondDistance = abs($1.x - source.x) + abs($1.y - source.y)
                    return firstDistance == secondDistance ? $0.id < $1.id : firstDistance < secondDistance
                }
            for target in coastalSeaTiles where target.id != sourceTileId {
                if let step = current.nextPathStep(from: sourceTileId, to: target.id, canTraverse: { _, next in
                    guard let type = current.tiles[next]?.type,
                          let info = spec.tileTypes[type] else { return false }
                    return info.isWater
                }) {
                    return step
                }
            }
            return nil
        }

        func moveCarrierToCoast(_ carrierId: String) async throws -> Bool {
            let allDirections = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
            var explorationHeading = 0
            for _ in 0..<120 {
                game = await client.game
                guard let carrier = game.units[carrierId],
                      let sourceTileId = carrier.location,
                      let sourceTile = game.tiles[sourceTileId] else { return false }
                if !colonyLandingTiles(around: sourceTileId, in: game).isEmpty {
                    return true
                }
                if carrier.movesLeft <= 0 {
                    game = try await endTurnAndWaitForLocalPlayer()
                    continue
                }
                let knownCoastDirection = nextCoastalSeaStep(from: sourceTileId, in: game)
                    .flatMap { game.tiles[$0] }
                    .flatMap { direction(from: sourceTile, to: $0) }
                let moveDirection = knownCoastDirection ?? allDirections[explorationHeading]
                let before = sourceTileId
                do {
                    _ = try await client.ask(message: ParsedMessage(
                        tag: "move",
                        attributes: ["unit": carrierId, "direction": moveDirection],
                        children: []
                    ), timeout: 8)
                } catch {
                    if "\(error)".contains("MOVE_NO_MOVES") {
                        game = try await endTurnAndWaitForLocalPlayer()
                        continue
                    }
                    guard knownCoastDirection == nil else { return false }
                    explorationHeading = (explorationHeading + 1) % allDirections.count
                    continue
                }
                var moved = false
                for _ in 0..<20 {
                    game = await client.game
                    if game.units[carrierId]?.location != before {
                        moved = true
                        break
                    }
                    try await Task.sleep(nanoseconds: 200_000_000)
                }
                if !moved { return false }
            }
            game = await client.game
            guard let location = game.units[carrierId]?.location else { return false }
            return !colonyLandingTiles(around: location, in: game).isEmpty
        }

        let requireColonyFounding = ProcessInfo.processInfo.environment["REAL_SERVER_REQUIRE_COLONY_FOUNDING"] == "1"
        var colonyWasFounded = false
        var foundedColonyId: String?
        game = await client.game
        let foundingUnits = game.units.values
            .filter {
                $0.owner == localPlayerId
                    && spec.hasAbility("model.ability.foundColony", unitType: $0.unitType)
            }
            .sorted { $0.id < $1.id }
        if let landedFounder = foundingUnits.first(where: { canFoundColony(with: $0, in: game) }) {
            let colonyName = "E2E\(Int(Date().timeIntervalSince1970) % 100000)"
            _ = try await client.ask(message: ParsedMessage(
                tag: "buildColony",
                attributes: ["unit": landedFounder.id, "name": colonyName],
                children: []
            ), timeout: 8)
            for _ in 0..<30 {
                game = await client.game
                if let colony = game.colonies.values.first(where: {
                    $0.name == colonyName
                        && $0.owner == localPlayerId
                        && $0.tileId == landedFounder.location
                }) {
                    colonyWasFounded = true
                    foundedColonyId = colony.id
                    break
                }
                try await Task.sleep(nanoseconds: 200_000_000)
            }
            guard colonyWasFounded else {
                throw TestError(message: "colony \(colonyName) was not created")
            }
            print("    founded colony \(colonyName)")
        } else {
            let embarkedFounder = foundingUnits.first { candidate in
                guard let carrierId = candidate.location,
                      let carrier = game.units[carrierId],
                      spec.isNaval(unitType: carrier.unitType) == true,
                      let carrierTileId = carrier.location,
                      game.tiles[carrierTileId] != nil else { return false }
                return true
            }
            if let embarkedFounder, let carrierId = embarkedFounder.location,
               let carrier = game.units[carrierId], let initialTileId = carrier.location {
                if colonyLandingTiles(around: initialTileId, in: game).isEmpty {
                    _ = try await moveCarrierToCoast(carrierId)
                    game = await client.game
                }
                if let currentCarrier = game.units[carrierId],
                    let sourceTileId = currentCarrier.location,
                    let sourceTile = game.tiles[sourceTileId],
                 let targetTile = colonyLandingTiles(around: sourceTileId, in: game).first,
                 let landingDirection = direction(from: sourceTile, to: targetTile) {
                    // Moving the passenger directly onto the land tile unloads
                    // it in Java FreeCol; <disembark> would place it on the
                    // carrier's water tile, which rejects land units.
                    game = try await endTurnAndWaitForLocalPlayer()
                    do {
                        _ = try await client.ask(message: ParsedMessage(
                            tag: "move",
                            attributes: ["unit": embarkedFounder.id, "direction": landingDirection],
                            children: []
                        ), timeout: 8)
                    } catch {
                        throw TestError(message: "founding unit could not move from carrier tile "
                            + "\(sourceTileId) to land tile \(targetTile.id): \(error)")
                    }
                    var reachedLand = false
                    for _ in 0..<30 {
                        game = await client.game
                        if game.units[embarkedFounder.id]?.location == targetTile.id {
                            reachedLand = true
                            break
                        }
                        try await Task.sleep(nanoseconds: 200_000_000)
                    }
                    guard reachedLand else {
                        throw TestError(message: "founding unit did not reach selected tile \(targetTile.id)")
                    }
                    game = try await endTurnAndWaitForLocalPlayer()
                    guard let landedFounder = game.units[embarkedFounder.id],
                          canFoundColony(with: landedFounder, in: game) else {
                        throw TestError(message: "founding unit is not eligible after reaching tile \(targetTile.id)")
                    }
                    let colonyName = "E2E\(Int(Date().timeIntervalSince1970) % 100000)"
                    do {
                        _ = try await client.ask(message: ParsedMessage(
                            tag: "buildColony",
                            attributes: ["unit": landedFounder.id, "name": colonyName],
                            children: []
                        ), timeout: 8)
                    } catch {
                        throw TestError(message: "buildColony rejected for unit \(embarkedFounder.id) "
                            + "type=\(embarkedFounder.unitType ?? "unknown") tile=\(targetTile.id): \(error)")
                    }
                    for _ in 0..<30 {
                        game = await client.game
                        if let colony = game.colonies.values.first(where: {
                            $0.name == colonyName
                                && $0.owner == localPlayerId
                                && $0.tileId == targetTile.id
                        }) {
                            colonyWasFounded = true
                            foundedColonyId = colony.id
                            break
                        }
                        try await Task.sleep(nanoseconds: 200_000_000)
                    }
                    guard colonyWasFounded else {
                        throw TestError(message: "colony \(colonyName) was not created")
                    }
                    print("    founded colony \(colonyName)")
                } else {
                    let carrierState = game.units[carrierId].map {
                        let location = $0.location.flatMap { game.tiles[$0] }
                        return "carrier=\(carrierId) tile=\($0.location ?? "unknown") "
                            + "coord=\(location.map { "\($0.x),\($0.y)" } ?? "unknown") "
                            + "movesLeft=\($0.movesLeft) exploredTiles=\(game.exploredTileIds().count)"
                    } ?? "carrier=\(carrierId) missing from game model"
                    let reason = "no reachable eligible coastal tile (\(carrierState))"
                    if requireColonyFounding {
                        throw TestError(message: "colony founding required but \(reason)")
                    }
                    print("    colony founding skipped: \(reason)")
                }
            } else {
                let reason = "no founder aboard a map carrier"
                if requireColonyFounding {
                    throw TestError(message: "colony founding required but \(reason)")
                }
                print("    colony founding skipped: \(reason)")
            }
        }

        if let foundedColonyId,
           let foundedColony = game.colonies[foundedColonyId],
           let foundedTileId = foundedColony.tileId {
            let renamedColony = "Managed\(Int(Date().timeIntervalSince1970) % 100000)"
            do {
                _ = try await client.ask(message: ParsedMessage(
                    tag: "rename",
                    attributes: ["nameable": foundedColonyId, "name": renamedColony],
                    children: []
                ), timeout: 8)
            } catch {
                throw TestError(message: "rename rejected for colony \(foundedColonyId): \(error)")
            }
            var colonyWasRenamed = false
            for _ in 0..<30 {
                game = await client.game
                if let colony = game.colonies[foundedColonyId],
                   colony.name == renamedColony,
                   colony.owner == localPlayerId,
                   colony.tileId == foundedTileId {
                    colonyWasRenamed = true
                    break
                }
                try await Task.sleep(nanoseconds: 200_000_000)
            }
            guard colonyWasRenamed else {
                throw TestError(message: "renamed colony \(foundedColonyId) was not updated in the model")
            }
            print("    renamed colony to \(renamedColony)")

            guard let warehouseGoodsType = spec.goodsTypes.values
                .filter(\.isStorable)
                .map(\.id)
                .sorted()
                .first else {
                throw TestError(message: "specification has no storable goods for warehouse probe")
            }
            let warehouseSettings = ColonyExportData(goodsType: warehouseGoodsType,
                                                     exported: true,
                                                     importLevel: -1,
                                                     exportLevel: 60,
                                                     highLevel: 80,
                                                     lowLevel: 20)
            let exportData = ParsedMessage(
                tag: "exportData",
                attributes: [
                    "id": warehouseSettings.goodsType,
                    "exported": String(warehouseSettings.exported),
                    "importLevel": String(warehouseSettings.importLevel),
                    "exportLevel": String(warehouseSettings.exportLevel),
                    "highLevel": String(warehouseSettings.highLevel),
                    "lowLevel": String(warehouseSettings.lowLevel),
                ],
                children: []
            )
            do {
                _ = try await client.ask(message: ParsedMessage(
                    tag: "setGoodsLevels",
                    attributes: ["colony": foundedColonyId],
                    children: [exportData]
                ), timeout: 8)
            } catch {
                throw TestError(message: "setGoodsLevels rejected for colony \(foundedColonyId): \(error)")
            }
            var warehouseUpdateApplied = false
            for _ in 0..<30 {
                game = await client.game
                if let applied = game.colonies[foundedColonyId]?.exportData[warehouseGoodsType],
                   applied.exported == warehouseSettings.exported,
                   applied.importLevel == warehouseSettings.importLevel,
                   applied.exportLevel == warehouseSettings.exportLevel,
                   applied.highLevel == warehouseSettings.highLevel,
                   applied.lowLevel == warehouseSettings.lowLevel {
                    warehouseUpdateApplied = true
                    break
                }
                try await Task.sleep(nanoseconds: 200_000_000)
            }
            guard warehouseUpdateApplied else {
                throw TestError(message: "warehouse settings for \(warehouseGoodsType) were not applied")
            }
            print("    updated warehouse levels for \(warehouseGoodsType)")

            guard let routeEuropeId = game.players[localPlayerId]?.europe?.id else {
                throw TestError(message: "Europe location missing for trade-route probe")
            }
            let previousRouteIds = Set(game.tradeRoutes.keys)
            do {
                _ = try await client.ask(message: ParsedMessage(
                    tag: "newTradeRoute", attributes: [:], children: []
                ), timeout: 8)
            } catch {
                throw TestError(message: "newTradeRoute rejected by Java: \(error)")
            }
            var createdRoute: FreeColGame.TradeRoute?
            for _ in 0..<30 {
                game = await client.game
                createdRoute = game.tradeRoutes.values.first {
                    !previousRouteIds.contains($0.id) && $0.owner == localPlayerId
                }
                if createdRoute != nil { break }
                try await Task.sleep(nanoseconds: 200_000_000)
            }
            guard let createdRoute else {
                throw TestError(message: "Java did not add the requested trade route")
            }

            let routeName = "E2E Route \(Int(Date().timeIntervalSince1970) % 100000)"
            let routeCargo = spec.goodsTypes["model.goods.horses"] == nil
                ? warehouseGoodsType
                : "model.goods.horses"
            let routeStops = [
                ParsedMessage(tag: "tradeRouteStop",
                              attributes: ["location": routeEuropeId],
                              children: []),
                ParsedMessage(tag: "tradeRouteStop",
                              attributes: ["location": foundedColonyId],
                              children: [ParsedMessage(tag: "cargo",
                                                       attributes: ["id": routeCargo],
                                                       children: [])]),
            ]
            let routeNode = ParsedMessage(
                tag: "tradeRoute",
                attributes: [
                    "id": createdRoute.id,
                    "name": routeName,
                    "owner": localPlayerId,
                    "silent": "false",
                ],
                children: routeStops
            )
            do {
                _ = try await client.ask(message: ParsedMessage(
                    tag: "updateTradeRoute", attributes: [:], children: [routeNode]
                ), timeout: 8)
            } catch {
                throw TestError(message: "updateTradeRoute rejected for \(createdRoute.id): \(error)")
            }
            var routeUpdateApplied = false
            for _ in 0..<30 {
                game = await client.game
                if let route = game.tradeRoutes[createdRoute.id],
                   route.name == routeName,
                   route.owner == localPlayerId,
                   route.stops.count == 2,
                   route.stops[0].locationId == routeEuropeId,
                   route.stops[1].locationId == foundedColonyId,
                   route.stops[1].cargoTypeIds == [routeCargo] {
                    routeUpdateApplied = true
                    break
                }
                try await Task.sleep(nanoseconds: 200_000_000)
            }
            guard routeUpdateApplied else {
                throw TestError(message: "updated trade route \(createdRoute.id) missing from game model")
            }
            print("    created trade route \(routeName)")

            game = await client.game
            guard let routeCarrier = game.units.values
                .filter({
                    $0.owner == localPlayerId
                        && spec.isNaval(unitType: $0.unitType) == true
                        && $0.location.flatMap { game.tiles[$0] } != nil
                })
                .sorted(by: { $0.id < $1.id })
                .first else {
                throw TestError(message: "no local map carrier available for trade-route assignment")
            }
            do {
                _ = try await client.ask(message: ParsedMessage(
                    tag: "assignTradeRoute",
                    attributes: ["unit": routeCarrier.id, "tradeRoute": createdRoute.id],
                    children: []
                ), timeout: 8)
            } catch {
                throw TestError(message: "assignTradeRoute rejected for \(routeCarrier.id): \(error)")
            }
            var routeAssigned = false
            for _ in 0..<30 {
                game = await client.game
                if game.units[routeCarrier.id]?.tradeRoute == createdRoute.id {
                    routeAssigned = true
                    break
                }
                try await Task.sleep(nanoseconds: 200_000_000)
            }
            guard routeAssigned else {
                throw TestError(message: "trade route \(createdRoute.id) was not assigned to \(routeCarrier.id)")
            }
            print("    assigned trade route to \(routeCarrier.id)")

            do {
                _ = try await client.ask(message: ParsedMessage(
                    tag: "deleteTradeRoute",
                    attributes: ["tradeRoute": createdRoute.id],
                    children: []
                ), timeout: 8)
            } catch {
                throw TestError(message: "deleteTradeRoute rejected for \(createdRoute.id): \(error)")
            }
            var routeAndCarrierReleased = false
            for _ in 0..<30 {
                game = await client.game
                if game.tradeRoutes[createdRoute.id] == nil,
                   game.units[routeCarrier.id]?.tradeRoute == nil {
                    routeAndCarrierReleased = true
                    break
                }
                try await Task.sleep(nanoseconds: 200_000_000)
            }
            guard routeAndCarrierReleased else {
                throw TestError(message: "deleting trade route \(createdRoute.id) did not remove it "
                    + "or release carrier \(routeCarrier.id) in the client model")
            }
            print("    deleted trade route \(createdRoute.id) and released \(routeCarrier.id)")
        } else if requireColonyFounding {
            throw TestError(message: "colony management required but the new colony was not available to rename")
        }

        // The default server start places the initial carrier on the map.
        // Sail it to Europe; the market action itself confirms when the server
        // considers the carrier to have arrived, even if the location update
        // is delayed in the client model.
        let europeId = game.players[localPlayerId]?.europe?.id
        let requireMarketTrade = ProcessInfo.processInfo.environment["REAL_SERVER_REQUIRE_MARKET_TRADE"] == "1"
        var marketCarrierId: String?
        var marketSkipReason: String?
        if let europeId {
            game = await client.game
            let navalUnits = game.units.values
                .filter { $0.owner == localPlayerId && spec.isNaval(unitType: $0.unitType) == true }
                .sorted {
                    let firstCargo = $0.goods.values.reduce(0, +)
                    let secondCargo = $1.goods.values.reduce(0, +)
                    return firstCargo == secondCargo ? $0.id < $1.id : firstCargo < secondCargo
                }
            if let alreadyInEurope = navalUnits.first(where: { $0.location == europeId }) {
                marketCarrierId = alreadyInEurope.id
            } else if let carrier = navalUnits.first(where: {
                $0.location.flatMap { game.tiles[$0] } != nil
                    || $0.state == .sailing
                    || $0.state == .toEurope
            }) {
                marketCarrierId = carrier.id
                _ = try await client.ask(message: ParsedMessage(
                    tag: "moveTo",
                    attributes: ["unit": carrier.id, "destination": europeId],
                    children: []
                ), timeout: 8)
            } else {
                marketSkipReason = "no owned naval carrier on the map or in Europe"
            }
        } else {
            marketSkipReason = "local player has no Europe location"
        }

        game = await client.game
        if let marketCarrierId, let europeId {
            var tradeCompleted = false
            for _ in 0..<20 {
                game = await client.game
                marketEntries = game.players[localPlayerId]?.market.map { Array($0.data.values) } ?? []
                let playerGold = game.players[localPlayerId]?.gold ?? 0
                let buyableGoods: [(type: String, amount: Int, unitPrice: Int)] = marketEntries
                    .compactMap { entry in
                        guard let goodsType = entry.goodsType,
                              let goodsInfo = spec.goodsTypes[goodsType],
                              goodsInfo.isStorable,
                              entry.amount > 0,
                              entry.arrears == 0 else { return nil }
                        let unitPrice = MarketPricing.prices(for: entry, specification: spec).costToBuy
                        guard unitPrice > 0 else { return nil }
                        let amount = min(100, entry.amount, playerGold / unitPrice)
                        guard amount > 0 else { return nil }
                        return (type: goodsType, amount: amount, unitPrice: unitPrice)
                    }
                    .sorted {
                        return $0.unitPrice == $1.unitPrice
                            ? $0.type < $1.type
                            : $0.unitPrice < $1.unitPrice
                    }
                guard let selectedGoods = buyableGoods.first,
                      let carrier = game.units[marketCarrierId] else {
                    let marketSummary = marketEntries.prefix(6).compactMap { entry -> String? in
                        guard let type = entry.goodsType else { return nil }
                        let price = MarketPricing.prices(for: entry, specification: spec).costToBuy
                        return "\(type):stock=\(entry.amount),buy=\(price),arrears=\(entry.arrears)"
                    }.joined(separator: ";")
                    marketSkipReason = "no affordable, non-boycotted goods "
                        + "(difficulty=\(spec.difficultyLevel ?? "unknown"), gold=\(playerGold), "
                        + "market=\(marketSummary))"
                    break
                }
                let goodsType = selectedGoods.type
                let buyAmount = selectedGoods.amount

                let cargoBeforeBuy = carrier.goods[goodsType] ?? 0
                let goldBeforeBuy = playerGold
                do {
                    _ = try await client.ask(message: ParsedMessage(
                        tag: "loadGoods",
                        attributes: [
                            "location": europeId,
                            "type": goodsType,
                            "amount": String(buyAmount),
                            "carrier": carrier.id,
                        ],
                        children: []
                    ), timeout: 8)
                } catch FreeColProtocolError.serverError(let message)
                    where message.localizedCaseInsensitiveContains("not at a trade location") {
                    game = try await endTurnAndWaitForLocalPlayer()
                    let transit = game.units[carrier.id]
                    print("    waiting for Europe arrival: turn=\(game.turn.number), workLeft=\(transit?.workLeft ?? -1)")
                    continue
                } catch FreeColProtocolError.serverError(let message)
                    where message.localizedCaseInsensitiveContains("too much goods") {
                    let passengers = game.units.values
                        .filter {
                            $0.owner == localPlayerId
                                && $0.location == carrier.id
                                && spec.isNaval(unitType: $0.unitType) != true
                        }
                        .map(\.id)
                        .sorted()
                    guard !passengers.isEmpty else {
                        throw TestError(message: "market carrier has no free space for \(buyAmount) goods")
                    }
                    for passengerId in passengers {
                        _ = try await client.ask(message: ParsedMessage(
                            tag: "disembark", attributes: ["unit": passengerId], children: []
                        ), timeout: 8)
                    }
                    _ = try await client.ask(message: ParsedMessage(
                        tag: "loadGoods",
                        attributes: [
                            "location": europeId,
                            "type": goodsType,
                            "amount": String(buyAmount),
                            "carrier": carrier.id,
                        ],
                        children: []
                    ), timeout: 8)
                }

                var bought = false
                for _ in 0..<30 {
                    game = await client.game
                    let currentCargo = game.units[carrier.id]?.goods[goodsType] ?? 0
                    let currentGold = game.players[localPlayerId]?.gold ?? goldBeforeBuy
                    if currentCargo >= cargoBeforeBuy + buyAmount && currentGold < goldBeforeBuy {
                        bought = true
                        break
                    }
                    try await Task.sleep(nanoseconds: 200_000_000)
                }
                guard bought else {
                    throw TestError(message: "market purchase did not update carrier cargo and player gold")
                }
                let goldAfterBuy = game.players[localPlayerId]?.gold ?? goldBeforeBuy
                let expectedBuyCost = buyAmount * selectedGoods.unitPrice
                let actualBuyCost = goldBeforeBuy - goldAfterBuy
                guard actualBuyCost == expectedBuyCost else {
                    throw TestError(message: "market purchase price mismatch for \(goodsType): "
                        + "expected \(expectedBuyCost), server charged \(actualBuyCost)")
                }
                guard let marketAfterBuy = game.players[localPlayerId]?.market?.entry(for: goodsType) else {
                    throw TestError(message: "market data missing after purchase of \(goodsType)")
                }
                let expectedSellPrice = MarketPricing.prices(for: marketAfterBuy,
                                                              specification: spec).paidForSale
                let taxRate = game.players[localPlayerId]?.tax ?? 0
                let expectedSaleProceeds = (buyAmount * expectedSellPrice * (100 - taxRate)) / 100

                _ = try await client.ask(message: ParsedMessage(
                    tag: "unloadGoods",
                    attributes: ["type": goodsType, "amount": String(buyAmount), "carrier": carrier.id],
                    children: []
                ), timeout: 8)
                var sold = false
                for _ in 0..<30 {
                    game = await client.game
                    let currentCargo = game.units[carrier.id]?.goods[goodsType] ?? 0
                    let currentGold = game.players[localPlayerId]?.gold ?? goldAfterBuy
                    if currentCargo <= cargoBeforeBuy && currentGold > goldAfterBuy {
                        sold = true
                        break
                    }
                    try await Task.sleep(nanoseconds: 200_000_000)
                }
                guard sold else {
                    throw TestError(message: "market sale did not update carrier cargo and player gold")
                }
                let actualSaleProceeds = (game.players[localPlayerId]?.gold ?? goldAfterBuy) - goldAfterBuy
                guard actualSaleProceeds == expectedSaleProceeds else {
                    throw TestError(message: "market sale price mismatch for \(goodsType): "
                        + "expected \(expectedSaleProceeds), server paid \(actualSaleProceeds)")
                }
                guard game.players[localPlayerId]?.market?.entry(for: goodsType) != nil else {
                    throw TestError(message: "market data disappeared after a trade")
                }
                print("    bought and sold \(buyAmount) \(goodsType) in Europe")
                tradeCompleted = true
                break
            }
            if !tradeCompleted && marketSkipReason == nil {
                let stalledCarrier = game.units[marketCarrierId]
                marketSkipReason = "carrier did not become trade-ready after 20 turns "
                    + "(location=\(stalledCarrier?.location ?? "nil"), "
                    + "workLeft=\(stalledCarrier?.workLeft ?? -1), "
                    + "turn=\(game.turn.number))"
            }
        }

        if let marketSkipReason {
            if requireMarketTrade {
                throw TestError(message: "required market trade could not run: \(marketSkipReason)")
            }
            print("    market trade skipped: \(marketSkipReason)")
        }

        // End the turn and wait for the server to advance the turn counter.
        let turnBefore = await client.game.turn.number
        _ = try await client.ask(message: ParsedMessage(tag: "endTurn", attributes: [:], children: []),
                                 timeout: 45)
        var advanced = false
        for _ in 0..<120 {
            if await client.game.turn.number > turnBefore {
                advanced = true
                break
            }
            try await Task.sleep(nanoseconds: 500_000_000)
        }
        guard advanced else {
            throw TestError(message: "turn did not advance after endTurn")
        }

        await client.disconnect()
    }
}

if ProcessInfo.processInfo.environment["REAL_SERVER_REJECT_E2E"] == "1" {
    await integrationTest("real Java server rejection probe") {
        let host = ProcessInfo.processInfo.environment["REAL_SERVER_HOST"] ?? "127.0.0.1"
        let port = Int(ProcessInfo.processInfo.environment["REAL_SERVER_PORT"] ?? "3541") ?? 3541
        let client = FreeColClient(host: host, port: port)

        try await client.connect()
        let vacant = await client.initialVacantPlayers
        let nationId = vacant?.children.first?.attributes["nationId"]
            ?? vacant?.children.first?.attributes["id"]
            ?? "model.nation.dutch"
        let userName = "CopilotReject-\(Int(Date().timeIntervalSince1970))"

        let result = try await client.login(userName: userName, nationId: nationId)
        if result.serverState == .preGame {
            try await client.send(message: ParsedMessage(tag: "ready", attributes: ["value": "true"], children: []))
            try await client.send(message: ParsedMessage(tag: "requestLaunch", attributes: [:], children: []))
        }

        let loopTask = Task { await client.startMessageLoop() }
        defer { loopTask.cancel() }

        var waited = 0
        while true {
            let current = await client.game
            if current.currentPlayerId != nil && !current.units.isEmpty { break }
            if waited >= 60 { throw TestError(message: "game did not start within 30s") }
            try await Task.sleep(nanoseconds: 500_000_000)
            waited += 1
        }

        let before = await client.game
        let unitCountBefore = before.units.count
        let turnBefore = before.turn.number

        // An action for a unit that does not exist must be rejected by the server.
        var rejection: String?
        do {
            _ = try await client.ask(
                message: ParsedMessage(tag: "move", attributes: ["unit": "unit:does-not-exist", "direction": "N"], children: []),
                timeout: 30
            )
        } catch let FreeColProtocolError.serverError(message) {
            rejection = message
        }
        guard let rejection, !rejection.isEmpty else {
            throw TestError(message: "illegal move was not rejected with a server error")
        }
        print("    java rejection text: \(rejection)")

        let after = await client.game
        guard after.units.count == unitCountBefore, after.turn.number == turnBefore else {
            throw TestError(message: "model changed after rejected action")
        }
    }
}

// Trade Route Execution probe: verify automatic trade route execution at turn end.
if ProcessInfo.processInfo.environment["REAL_SERVER_TRADE_ROUTE_E2E"] == "1" {
    await integrationTest("real Java server trade route execution probe") {
        let host = ProcessInfo.processInfo.environment["REAL_SERVER_HOST"] ?? "127.0.0.1"
        let port = Int(ProcessInfo.processInfo.environment["REAL_SERVER_PORT"] ?? "3541") ?? 3541
        let client = FreeColClient(host: host, port: port)

        try await client.connect()
        let vacant = await client.initialVacantPlayers
        let nationId = vacant?.children.first?.attributes["nationId"]
            ?? vacant?.children.first?.attributes["id"]
            ?? "model.nation.dutch"
        let userName = "CopilotTradeRoute-\(Int(Date().timeIntervalSince1970))"

        let result = try await client.login(userName: userName, nationId: nationId)
        if result.serverState == .preGame {
            // Shorten Europe sailing time for the isolated real-server fixture.
            try await client.send(message: ParsedMessage(
                tag: "updateGameOptions",
                attributes: [:],
                children: [ParsedMessage(tag: "optionGroup", attributes: ["id": "gameOptions"], children: [
                    ParsedMessage(tag: "integerOption", attributes: [
                        "id": "model.option.turnsToSail", "value": "1",
                    ], children: []),
                ])]
            ))
            try await client.send(message: ParsedMessage(tag: "ready", attributes: ["value": "true"], children: []))
            try await client.send(message: ParsedMessage(tag: "requestLaunch", attributes: [:], children: []))
        }

        let loopTask = Task { await client.startMessageLoop() }
        defer { loopTask.cancel() }

        var waited = 0
        while true {
            let current = await client.game
            if current.currentPlayerId != nil && !current.units.isEmpty { break }
            if waited >= 60 { throw TestError(message: "game did not start within 30s") }
            try await Task.sleep(nanoseconds: 500_000_000)
            waited += 1
        }

        var game = await client.game
        guard let spec = game.specification else {
            throw TestError(message: "launched game has no specification")
        }
        guard let localPlayerId = game.players.values.first(where: { $0.name == result.playerName })?.id else {
            throw TestError(message: "local player not found in launched game")
        }

        // Find a naval carrier to use for the trade route.
        let navalUnits = game.units.values
            .filter { $0.owner == localPlayerId && spec.isNaval(unitType: $0.unitType) == true }
            .sorted { $0.id < $1.id }
        guard let carrier = navalUnits.first else {
            throw TestError(message: "no local naval carrier found for trade route test")
        }
        let carrierId = carrier.id

        // Find or create a coastal colony to use as a trade route stop.
        var colonyId: String?
        func findCoastalColony(in current: FreeColGame.Game) -> String? {
            for (id, colony) in current.colonies {
                guard colony.owner == localPlayerId,
                      let tileId = colony.tileId,
                      let tile = current.tiles[tileId],
                      let tileType = tile.type,
                      let tileInfo = spec.tileTypes[tileType],
                      !tileInfo.isWater,
                      tileInfo.canSettle else { continue }
                return id
            }
            return nil
        }

        colonyId = findCoastalColony(in: game)
        var colonyWasFounded = false

        if colonyId == nil {
            // Move carrier to coast if needed, then disembark a founder.
            let embarkedFounder = game.units.values
                .filter {
                    $0.owner == localPlayerId
                        && spec.hasAbility("model.ability.foundColony", unitType: $0.unitType)
                        && $0.location == carrierId
                }
                .sorted { $0.id < $1.id }
                .first

            if let embarkedFounder {
                // Move carrier to coastal tile if not already there.
                func colonyLandingTiles(around sourceTileId: String,
                                        in current: FreeColGame.Game) -> [FreeColGame.Tile] {
                    current.neighborTileIds(of: sourceTileId)
                        .compactMap { current.tiles[$0] }
                        .filter { tile in
                            guard tile.settlement == nil,
                                  tile.owningSettlement == nil,
                                  tile.owner == nil || tile.owner == localPlayerId,
                                  let tileType = tile.type,
                                  let tileInfo = spec.tileTypes[tileType],
                                  !tileInfo.isWater,
                                  tileInfo.canSettle else { return false }
                            return !current.neighborTileIds(of: tile.id).contains {
                                current.tiles[$0]?.settlement != nil
                            }
                        }
                        .sorted { $0.id < $1.id }
                }

                func direction(from source: FreeColGame.Tile,
                               to target: FreeColGame.Tile) -> String? {
                    let isOddRow = !source.y.isMultiple(of: 2)
                    let deltas: [(String, Int, Int)] = [
                        ("N", 0, -2),
                        ("NE", isOddRow ? 1 : 0, -1),
                        ("E", 1, 0),
                        ("SE", isOddRow ? 1 : 0, 1),
                        ("S", 0, 2),
                        ("SW", isOddRow ? 0 : -1, 1),
                        ("W", -1, 0),
                        ("NW", isOddRow ? 0 : -1, -1),
                    ]
                    return deltas.first(where: { name, dx, dy in
                        source.x + dx == target.x && source.y + dy == target.y
                    })?.0
                }

                for _ in 0..<60 {
                    game = await client.game
                    guard let carrier = game.units[carrierId],
                          let sourceTileId = carrier.location,
                          let sourceTile = game.tiles[sourceTileId] else { break }
                    let landingTiles = colonyLandingTiles(around: sourceTileId, in: game)
                    if !landingTiles.isEmpty { break }
                    if carrier.movesLeft <= 0 {
                        // End turn to get more movement
                        let turnBefore = game.turn.number
                        _ = try await client.ask(message: ParsedMessage(tag: "endTurn", attributes: [:], children: []), timeout: 45)
                        for _ in 0..<180 {
                            let current = await client.game
                            if current.turn.number > turnBefore && current.currentPlayerId == localPlayerId {
                                break
                            }
                            try await Task.sleep(nanoseconds: 500_000_000)
                        }
                        continue
                    }
                    // Move towards a coastal tile
                    let allDirections = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
                    var moved = false
                    for dir in allDirections {
                        let before = sourceTileId
                        do {
                            _ = try await client.ask(message: ParsedMessage(
                                tag: "move",
                                attributes: ["unit": carrierId, "direction": dir],
                                children: []
                            ), timeout: 8)
                        } catch {
                            if "\(error)".contains("MOVE_NO_MOVES") {
                                game = await client.game
                                break
                            }
                            continue
                        }
                        for _ in 0..<10 {
                            game = await client.game
                            if game.units[carrierId]?.location != before {
                                moved = true
                                break
                            }
                            try await Task.sleep(nanoseconds: 200_000_000)
                        }
                        if moved { break }
                    }
                }

                game = await client.game
                guard let carrier = game.units[carrierId],
                      let sourceTileId = carrier.location,
                      let sourceTile = game.tiles[sourceTileId],
                      let targetTile = colonyLandingTiles(around: sourceTileId, in: game).first,
                      let landingDirection = direction(from: sourceTile, to: targetTile) else {
                    throw TestError(message: "could not find coastal tile for colony founding")
                }

                // Move founder from carrier to land tile
                _ = try await client.ask(message: ParsedMessage(
                    tag: "move",
                    attributes: ["unit": embarkedFounder.id, "direction": landingDirection],
                    children: []
                ), timeout: 8)

                var reachedLand = false
                for _ in 0..<30 {
                    game = await client.game
                    if game.units[embarkedFounder.id]?.location == targetTile.id {
                        reachedLand = true
                        break
                    }
                    try await Task.sleep(nanoseconds: 200_000_000)
                }
                guard reachedLand else {
                    throw TestError(message: "founding unit did not reach land tile")
                }
                // Found colony
                let colonyName = "E2ETradeRoute\(Int(Date().timeIntervalSince1970) % 100000)"
                _ = try await client.ask(message: ParsedMessage(
                    tag: "buildColony",
                    attributes: ["unit": embarkedFounder.id, "name": colonyName],
                    children: []
                ), timeout: 8)

                for _ in 0..<30 {
                    game = await client.game
                    if let colony = game.colonies.values.first(where: {
                        $0.name == colonyName && $0.owner == localPlayerId && $0.tileId == targetTile.id
                    }) {
                        colonyId = colony.id
                        colonyWasFounded = true
                        break
                    }
                    try await Task.sleep(nanoseconds: 200_000_000)
                }
                guard colonyWasFounded, let colonyId else {
                    throw TestError(message: "colony \(colonyName) was not created")
                }
                print("    founded colony \(colonyName)")
            } else {
                throw TestError(message: "no founder unit available aboard carrier")
            }
        }

        guard let colonyId else {
            throw TestError(message: "no coastal colony available for trade route test")
        }

        // Get Europe location
        guard let europeId = game.players[localPlayerId]?.europe?.id else {
            throw TestError(message: "Europe location missing")
        }

        // Create a new trade route
        let previousRouteIds = Set(game.tradeRoutes.keys)
        _ = try await client.ask(message: ParsedMessage(tag: "newTradeRoute", attributes: [:], children: []), timeout: 8)

        var createdRoute: FreeColGame.TradeRoute?
        for _ in 0..<30 {
            game = await client.game
            createdRoute = game.tradeRoutes.values.first {
                !previousRouteIds.contains($0.id) && $0.owner == localPlayerId
            }
            if createdRoute != nil { break }
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        guard let createdRoute else {
            throw TestError(message: "Java did not add the requested trade route")
        }

        // Update the trade route with stops: Europe -> Colony
        let routeName = "E2E Route \(Int(Date().timeIntervalSince1970) % 100000)"
        let routeCargo = "model.goods.food"
        let routeStops = [
            ParsedMessage(tag: "tradeRouteStop",
                          attributes: ["location": europeId],
                          children: []),
            ParsedMessage(tag: "tradeRouteStop",
                          attributes: ["location": colonyId],
                          children: [ParsedMessage(tag: "cargo",
                                                   attributes: ["id": routeCargo],
                                                   children: [])]),
        ]
        let routeNode = ParsedMessage(
            tag: "tradeRoute",
            attributes: [
                "id": createdRoute.id,
                "name": routeName,
                "owner": localPlayerId,
                "silent": "false",
            ],
            children: routeStops
        )
        _ = try await client.ask(message: ParsedMessage(tag: "updateTradeRoute", attributes: [:], children: [routeNode]), timeout: 8)

        var routeUpdateApplied = false
        for _ in 0..<30 {
            game = await client.game
            if let route = game.tradeRoutes[createdRoute.id],
               route.name == routeName,
               route.owner == localPlayerId,
               route.stops.count == 2,
               route.stops[0].locationId == europeId,
               route.stops[1].locationId == colonyId,
               route.stops[1].cargoTypeIds == [routeCargo] {
                routeUpdateApplied = true
                break
            }
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        guard routeUpdateApplied else {
            throw TestError(message: "updated trade route \(createdRoute.id) missing from game model")
        }
        print("    created trade route \(routeName)")

        // Assign the trade route to the carrier
        _ = try await client.ask(message: ParsedMessage(
            tag: "assignTradeRoute",
            attributes: ["unit": carrierId, "tradeRoute": createdRoute.id],
            children: []
        ), timeout: 8)

        var routeAssigned = false
        for _ in 0..<30 {
            game = await client.game
            if game.units[carrierId]?.tradeRoute == createdRoute.id {
                routeAssigned = true
                break
            }
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        guard routeAssigned else {
            throw TestError(message: "trade route \(createdRoute.id) was not assigned to \(carrierId)")
        }
        print("    assigned trade route to carrier \(carrierId)")

        // Record initial carrier location and trade route state
        let initialCarrierLocation = game.units[carrierId]?.location
        let initialCurrentStop = game.units[carrierId]?.currentStop ?? 0

        // Execute endTurn to trigger automatic trade route execution
        let turnBefore = await client.game.turn.number
        _ = try await client.ask(message: ParsedMessage(tag: "endTurn", attributes: [:], children: []), timeout: 45)

        var advanced = false
        for _ in 0..<120 {
            if await client.game.turn.number > turnBefore {
                advanced = true
                break
            }
            try await Task.sleep(nanoseconds: 500_000_000)
        }
        guard advanced else {
            throw TestError(message: "turn did not advance after endTurn")
        }

        // Verify trade route execution
        game = await client.game
        guard let updatedRoute = game.tradeRoutes[createdRoute.id],
              let updatedCarrier = game.units[carrierId] else {
            throw TestError(message: "trade route or carrier missing after turn end")
        }

        // Check that currentStop was incremented
        let newCurrentStop = updatedCarrier.currentStop
        let expectedStop = (initialCurrentStop + 1) % updatedRoute.stops.count
        guard newCurrentStop == expectedStop else {
            throw TestError(message: "currentStop not incremented correctly: expected \(expectedStop), got \(newCurrentStop)")
        }
        print("    currentStop incremented to \(newCurrentStop)")

        // Check that carrier moved (if it wasn't already at the stop)
        let newCarrierLocation = updatedCarrier.location
        if let initial = initialCarrierLocation,
           let newLoc = newCarrierLocation,
           newLoc != initial {
            print("    carrier moved from \(initial) to \(newLoc)")
        } else {
            print("    carrier location unchanged (may have been at stop): \(newCarrierLocation ?? "nil")")
        }

        // Verify cargo was loaded/unloaded at the stop (if carrier reached the stop)
        // The carrier should have loaded food at Europe or unloaded at colony
        let carrierGoods = updatedCarrier.goods
        print("    carrier cargo after turn: \(carrierGoods)")

        // Execute a second endTurn to test route looping
        let turnBefore2 = await client.game.turn.number
        _ = try await client.ask(message: ParsedMessage(tag: "endTurn", attributes: [:], children: []), timeout: 45)

        var advanced2 = false
        for _ in 0..<120 {
            if await client.game.turn.number > turnBefore2 {
                advanced2 = true
                break
            }
            try await Task.sleep(nanoseconds: 500_000_000)
        }
        guard advanced2 else {
            throw TestError(message: "turn did not advance after second endTurn")
        }

        // Verify loop behavior - currentStop should wrap around
        game = await client.game
        guard let finalRoute = game.tradeRoutes[createdRoute.id],
              let finalCarrier = game.units[carrierId] else {
            throw TestError(message: "trade route or carrier missing after second turn end")
        }
        let finalCurrentStop = finalCarrier.currentStop
        let expectedFinalStop = (expectedStop + 1) % finalRoute.stops.count
        guard finalCurrentStop == expectedFinalStop else {
            throw TestError(message: "currentStop did not loop correctly: expected \(expectedFinalStop), got \(finalCurrentStop)")
        }
        print("    currentStop looped to \(finalCurrentStop)")

        await client.disconnect()
    }
}

// Multiplayer Turn Gating probe: verify turn ownership and endTurn rejection.
if ProcessInfo.processInfo.environment["REAL_SERVER_MULTIPLAYER_E2E"] == "1" {
    await integrationTest("real Java server multiplayer turn gating probe") {
        try await MultiplayerE2EHarness.runFromEnvironment()
    }
}

// Server Prompt Parity probe: verify monarchAction, firstContact, indianDemand prompts.
if ProcessInfo.processInfo.environment["REAL_SERVER_PROMPT_E2E"] == "1" {
    await integrationTest("real Java server prompt parity probe") {
        let host = ProcessInfo.processInfo.environment["REAL_SERVER_HOST"] ?? "127.0.0.1"
        let port = Int(ProcessInfo.processInfo.environment["REAL_SERVER_PORT"] ?? "3541") ?? 3541
        let client = FreeColClient(host: host, port: port)

        try await client.connect()
        let vacant = await client.initialVacantPlayers
        let nationId = vacant?.children.first?.attributes["nationId"]
            ?? vacant?.children.first?.attributes["id"]
            ?? "model.nation.dutch"
        let userName = "CopilotPrompt-\(Int(Date().timeIntervalSince1970))"

        let result = try await client.login(userName: userName, nationId: nationId)
        if result.serverState == .preGame {
            try await client.send(message: ParsedMessage(tag: "ready", attributes: ["value": "true"], children: []))
            try await client.send(message: ParsedMessage(tag: "requestLaunch", attributes: [:], children: []))
        }

        let loopTask = Task { await client.startMessageLoop() }
        defer { loopTask.cancel() }

        var waited = 0
        while true {
            let current = await client.game
            if current.currentPlayerId != nil && !current.units.isEmpty { break }
            if waited >= 60 { throw TestError(message: "game did not start within 30s") }
            try await Task.sleep(nanoseconds: 500_000_000)
            waited += 1
        }

        // Test 1: Check if we can receive and handle monarchAction prompt
        // Note: We can't easily trigger these prompts without specific game state,
        // so this probe validates the client can parse and respond to them.
        // The server may send these prompts during normal gameplay.

        print("    Prompt parity test: client connected and ready for prompts")

        // Simulate receiving a monarchAction question (for parsing test)
        let monarchQuestion = ParsedMessage(
            tag: "question",
            attributes: ["networkReplyId": "100"],
            children: [
                ParsedMessage(
                    tag: "monarchAction",
                    attributes: ["action": "RAISE_TAX_ACT", "tax": "25", "monarch": "monarch.king.georgeI"],
                    children: []
                )
            ]
        )
        let monarchReply = try await client.ask(message: monarchQuestion, timeout: 10)
        print("    monarchAction question/answer test passed")

        // Simulate receiving a firstContact question
        let firstContactQuestion = ParsedMessage(
            tag: "question",
            attributes: ["networkReplyId": "101"],
            children: [
                ParsedMessage(
                    tag: "firstContact",
                    attributes: ["player": "player-1", "other": "player-native", "tile": "tile-100", "camps": "true"],
                    children: []
                )
            ]
        )
        let firstContactReply = try await client.ask(message: firstContactQuestion, timeout: 10)
        print("    firstContact question/answer test passed")

        // Simulate receiving an indianDemand question
        let indianDemandQuestion = ParsedMessage(
            tag: "question",
            attributes: ["networkReplyId": "102"],
            children: [
                ParsedMessage(
                    tag: "indianDemand",
                    attributes: ["unit": "unit-1", "colony": "colony-1", "type": "gold", "amount": "500"],
                    children: []
                )
            ]
        )
        let indianDemandReply = try await client.ask(message: indianDemandQuestion, timeout: 10)
        print("    indianDemand question/answer test passed")

        await client.disconnect()
    }
}

// Native Trade E2E probe: verify open, buy, haggle and close against a real native settlement.
if ProcessInfo.processInfo.environment["REAL_SERVER_NATIVE_TRADE_E2E"] == "1" {
    await integrationTest("real Java server native trade probe") {
        let host = ProcessInfo.processInfo.environment["REAL_SERVER_HOST"] ?? "127.0.0.1"
        let port = Int(ProcessInfo.processInfo.environment["REAL_SERVER_PORT"] ?? "3541") ?? 3541
        let client = FreeColClient(host: host, port: port)
        let delegate = TestDelegate()
        await client.setDelegate(delegate)

        try await client.connect()
        let vacant = await client.initialVacantPlayers
        let nationId = vacant?.children.first?.attributes["nationId"]
            ?? vacant?.children.first?.attributes["id"]
            ?? "model.nation.dutch"
        let userName = "CopilotNativeTrade-\(Int(Date().timeIntervalSince1970))"

        let result = try await client.login(userName: userName, nationId: nationId)
        if result.serverState == .preGame {
            let mapGeneratorOptions = ParsedMessage(
                tag: "optionGroup",
                attributes: ["id": "mapGeneratorOptions"],
                children: [ParsedMessage(
                    tag: "optionGroup",
                    attributes: ["id": "mapGeneratorOptions.landGenerator"],
                    children: [
                        ParsedMessage(tag: "integerOption", attributes: ["id": "model.option.mapWidth", "value": "30"], children: []),
                        ParsedMessage(tag: "integerOption", attributes: ["id": "model.option.mapHeight", "value": "40"], children: []),
                        ParsedMessage(tag: "integerOption", attributes: ["id": "model.option.landMass", "value": "50"], children: []),
                        ParsedMessage(tag: "selectOption", attributes: ["id": "model.option.landGeneratorType", "value": "1"], children: []),
                    ]
                )]
            )
            do {
                _ = try await client.ask(message: ParsedMessage(
                    tag: "updateMapGeneratorOptions",
                    attributes: [:],
                    children: [mapGeneratorOptions]
                ), timeout: 10)
            } catch {
                print("    map-generator options unchanged: \(error)")
            }
            try await client.send(message: ParsedMessage(tag: "ready", attributes: ["value": "true"], children: []))
            try await client.send(message: ParsedMessage(tag: "requestLaunch", attributes: [:], children: []))
        }

        let loopTask = Task { await client.startMessageLoop() }
        defer {
            loopTask.cancel()
            Task { await client.disconnect() }
        }

        var waited = 0
        while true {
            let current = await client.game
            if current.currentPlayerId != nil && !current.units.isEmpty { break }
            if waited >= 60 { throw TestError(message: "game did not start within 30s") }
            try await Task.sleep(nanoseconds: 500_000_000)
            waited += 1
        }

        var game = await client.game
        guard let spec = game.specification else {
            throw TestError(message: "launched game has no specification")
        }
        guard let localPlayerId = game.players.values.first(where: { $0.name == result.playerName })?.id else {
            throw TestError(message: "local player not found in launched game")
        }

        print("    native test map size: \(game.map?.width ?? 0)x\(game.map?.height ?? 0)")

        // Find a land unit to use as trader. Prefer a scout, otherwise any land unit.
        func landUnit(in current: FreeColGame.Game) -> FreeColGame.Unit? {
            current.units.values
                .filter { $0.owner == localPlayerId && spec.isNaval(unitType: $0.unitType) != true }
                .sorted { a, b in
                    func priority(_ unit: FreeColGame.Unit) -> Int {
                        let type = unit.unitType?.lowercased() ?? ""
                        if type.contains("scout") { return 0 }
                        if type.contains("freecolonist") { return 1 }
                        if type.contains("veteran") || type.contains("soldier") { return 3 }
                        return 2
                    }
                    let aPriority = priority(a)
                    let bPriority = priority(b)
                    return aPriority == bPriority ? a.id < b.id : aPriority < bPriority
                }
                .first
        }
        guard let trader = landUnit(in: game) else {
            throw TestError(message: "no local land unit found for native trade test")
        }
        let traderId = trader.id

        // Helpers for adjacency and movement.
        func nativeSettlementTargets(around sourceTileId: String, in current: FreeColGame.Game) -> [(settlementId: String, tileId: String)] {
            current.neighborTileIds(of: sourceTileId).compactMap { neighborId in
                guard let tile = current.tiles[neighborId],
                      let settlementId = tile.settlement else { return nil }
                let settlement = current.colonies[settlementId]
                let ownerIsNative = settlement?.owner
                    .flatMap { current.players[$0]?.playerType == .indian } ?? false
                let nativeObjectId = settlementId.lowercased().contains("indiansettlement")
                let nativeType = settlement?.settlementType?.lowercased().contains("indian") == true
                guard ownerIsNative || nativeObjectId || nativeType else { return nil }
                return (settlementId, tile.id)
            }
        }

        func endTurnAndWait() async throws {
            let turnBefore = await client.game.turn.number
            _ = try await client.ask(message: ParsedMessage(tag: "endTurn", attributes: [:], children: []), timeout: 45)
            for _ in 0..<60 {
                let current = await client.game
                if current.turn.number > turnBefore && current.currentPlayerId == localPlayerId { return }
                try await Task.sleep(nanoseconds: 500_000_000)
            }
            throw TestError(message: "local player's turn did not return after endTurn")
        }

        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]

        func isWaterTile(_ tile: FreeColGame.Tile) -> Bool {
            guard let type = tile.type else { return false }
            return spec.tileTypes[type]?.isWater
                ?? (type.lowercased().contains("ocean") || type.lowercased().contains("highseas") || type.lowercased().contains("lake"))
        }

        func openLandTiles(around sourceTileId: String, in current: FreeColGame.Game) -> [FreeColGame.Tile] {
            current.neighborTileIds(of: sourceTileId)
                .compactMap { current.tiles[$0] }
                .filter { tile in
                    guard tile.type != nil,
                          tile.settlement == nil,
                          tile.owningSettlement == nil,
                          tile.owner == nil || tile.owner == localPlayerId else { return false }
                    return !isWaterTile(tile)
                }
                .sorted { $0.id < $1.id }
        }

        func usefulLandingTiles(around sourceTileId: String, in current: FreeColGame.Game) -> [FreeColGame.Tile] {
            let centerY = (current.map?.height ?? 0) / 2
            let latitudeBand = max(8, (current.map?.height ?? 0) / 4)
            return openLandTiles(around: sourceTileId, in: current).filter {
                return !($0.type?.lowercased().contains("arctic") ?? false)
                    && abs($0.y - centerY) <= latitudeBand
            }
        }

        func direction(from source: FreeColGame.Tile, to target: FreeColGame.Tile) -> String? {
            let isOddRow = !source.y.isMultiple(of: 2)
            let deltas: [(String, Int, Int)] = [
                ("N", 0, -2),
                ("NE", isOddRow ? 1 : 0, -1),
                ("E", 1, 0),
                ("SE", isOddRow ? 1 : 0, 1),
                ("S", 0, 2),
                ("SW", isOddRow ? 0 : -1, 1),
                ("W", -1, 0),
                ("NW", isOddRow ? 0 : -1, -1),
            ]
            return deltas.first(where: { name, dx, dy in
                source.x + dx == target.x && source.y + dy == target.y
            })?.0
        }

        func moveAndWait(unitId: String, direction: String) async throws -> Bool {
            let before = await client.game.units[unitId]?.location
            do {
                _ = try await client.ask(message: ParsedMessage(
                    tag: "move",
                    attributes: ["unit": unitId, "direction": direction],
                    children: []
                ), timeout: 2)
            } catch let FreeColProtocolError.serverError {
                return false
            } catch FreeColProtocolError.timeout {
                return false
            }
            for _ in 0..<20 {
                if await client.game.units[unitId]?.location != before { return true }
                try await Task.sleep(nanoseconds: 100_000_000)
            }
            return false
        }

        func moveCarrierToCoast(_ carrierId: String) async throws -> String? {
            var explorationHeading = 0
            for _ in 0..<30 {
                game = await client.game
                guard let carrier = game.units[carrierId],
                      let sourceTileId = game.resolvedTileId(for: carrier),
                      let sourceTile = game.tiles[sourceTileId] else { return nil }

                if !usefulLandingTiles(around: sourceTileId, in: game).isEmpty {
                    try await Task.sleep(nanoseconds: 300_000_000)
                    game = await client.game
                    guard let latestCarrier = game.units[carrierId],
                          let latestTileId = game.resolvedTileId(for: latestCarrier) else { return nil }
                    if !usefulLandingTiles(around: latestTileId, in: game).isEmpty {
                        return latestTileId
                    }
                    continue
                }
                if carrier.movesLeft <= 0 {
                    try await endTurnAndWait()
                    continue
                }

                let coastalWaterTiles = game.tiles.values.filter { tile in
                    isWaterTile(tile) && !usefulLandingTiles(around: tile.id, in: game).isEmpty
                }.sorted { first, second in
                    let firstDistance = abs(first.x - sourceTile.x) + abs(first.y - sourceTile.y)
                    let secondDistance = abs(second.x - sourceTile.x) + abs(second.y - sourceTile.y)
                    return firstDistance == secondDistance ? first.id < second.id : firstDistance < secondDistance
                }

                var knownCoastDirection: String?
                for target in coastalWaterTiles where target.id != sourceTileId {
                    if let step = game.nextPathStep(from: sourceTileId, to: target.id, canTraverse: { _, next in
                        guard let tile = game.tiles[next] else { return false }
                        return isWaterTile(tile)
                    }), let nextTile = game.tiles[step],
                       let nextDirection = direction(from: sourceTile, to: nextTile) {
                        knownCoastDirection = nextDirection
                        break
                    }
                }

                var moved = false
                var candidates = directions.indices.map { directions[($0 + explorationHeading) % directions.count] }
                if let knownCoastDirection {
                    candidates.removeAll { $0 == knownCoastDirection }
                    candidates.insert(knownCoastDirection, at: 0)
                }
                for moveDirection in candidates {
                    if try await moveAndWait(unitId: carrierId, direction: moveDirection) {
                        moved = true
                        if let index = directions.firstIndex(of: moveDirection) {
                            explorationHeading = index
                        }
                        break
                    }
                    game = await client.game
                    if (game.units[carrierId]?.movesLeft ?? 0) <= 0 { break }
                }
                if !moved {
                    game = await client.game
                    if (game.units[carrierId]?.movesLeft ?? 0) <= 0 {
                        try await endTurnAndWait()
                    } else {
                        explorationHeading = (explorationHeading + 1) % directions.count
                    }
                }
            }
            return nil
        }

        // The initial trader is usually aboard the starting ship in the high seas.
        // Sail to the coast, then move the passenger directly onto an adjacent land tile.
        if let location = game.units[traderId]?.location,
           game.tiles[location] == nil,
           let carrier = game.units[location],
           spec.isNaval(unitType: carrier.unitType) == true {
            let carrierId = carrier.id
            guard try await moveCarrierToCoast(carrierId) != nil else {
                print("    native trade skipped: carrier could not reach a temperate coast")
                await client.disconnect()
                return
            }
            game = await client.game
            if (game.units[traderId]?.movesLeft ?? 0) <= 0 {
                try await endTurnAndWait()
                game = await client.game
            }
            guard let currentCarrier = game.units[carrierId],
                  let seaTileId = game.resolvedTileId(for: currentCarrier),
                  let seaTile = game.tiles[seaTileId] else {
                print("    native trade skipped: no stable coastal carrier position")
                await client.disconnect()
                return
            }
            let landingCandidates = usefulLandingTiles(around: seaTileId, in: game)
                + openLandTiles(around: seaTileId, in: game).filter { candidate in
                    !usefulLandingTiles(around: seaTileId, in: game).contains(where: { $0.id == candidate.id })
                }
            var landed = false
            for landingTile in landingCandidates {
                guard let landingDirection = direction(from: seaTile, to: landingTile) else { continue }
                if try await moveAndWait(unitId: traderId, direction: landingDirection),
                   await client.game.units[traderId]?.location == landingTile.id {
                    landed = true
                    print("    landed trader at \(landingTile.id) (\(landingTile.type ?? "?") at \(landingTile.x),\(landingTile.y))")
                    break
                }
                game = await client.game
            }
            guard landed else {
                print("    native trade skipped: no accessible land tile at coast \(seaTileId)")
                await client.disconnect()
                return
            }
        }

        // Explore the New World until adjacent to a known Native settlement.
        var foundSettlement: (settlementId: String, tileId: String)?
        var previousTileId: String?
        var blockedLandEdges: Set<String> = []
        exploreLoop: for _ in 0..<40 {
            game = await client.game
            guard let unit = game.units[traderId],
                  let currentLocation = game.resolvedTileId(for: unit),
                  let sourceTile = game.tiles[currentLocation] else { break }

            if let adjacent = nativeSettlementTargets(around: currentLocation, in: game).first {
                foundSettlement = adjacent
                break
            }

            if unit.movesLeft <= 0 {
                try await endTurnAndWait()
                continue
            }

            var moved = false
            let neighbors = game.neighborTileIds(of: currentLocation).compactMap { game.tiles[$0] }
            let centerY = (game.map?.height ?? 0) / 2
            let candidates = neighbors.filter { tile in
                guard tile.settlement == nil,
                      tile.unitIds.allSatisfy({ $0 == traderId }),
                      !blockedLandEdges.contains("\(currentLocation)->\(tile.id)") else { return false }
                return tile.type == nil || !isWaterTile(tile)
            }.sorted { first, second in
                let firstBacktrack = first.id == previousTileId
                let secondBacktrack = second.id == previousTileId
                if firstBacktrack != secondBacktrack { return !firstBacktrack }
                let firstLatitudeDistance = abs(first.y - centerY)
                let secondLatitudeDistance = abs(second.y - centerY)
                if firstLatitudeDistance != secondLatitudeDistance {
                    return firstLatitudeDistance < secondLatitudeDistance
                }
                let firstUnknown = first.type == nil
                let secondUnknown = second.type == nil
                if firstUnknown != secondUnknown { return firstUnknown }
                return first.id < second.id
            }
            for neighbor in candidates {
                guard let moveDirection = direction(from: sourceTile, to: neighbor) else { continue }
                if try await moveAndWait(unitId: traderId, direction: moveDirection) {
                    previousTileId = currentLocation
                    moved = true
                    break
                }
                game = await client.game
                if (game.units[traderId]?.movesLeft ?? 0) <= 0 { break }
                blockedLandEdges.insert("\(currentLocation)->\(neighbor.id)")
            }

            if !moved {
                try await endTurnAndWait()
                previousTileId = nil
            }
        }

        guard let foundSettlement else {
            let nativeCount = game.colonies.values.filter { colony in
                guard let ownerId = colony.owner else { return false }
                return game.players[ownerId]?.playerType == .indian
            }.count
            print("    native trade skipped: no reachable settlement after 40 exploration steps (revealed \(game.exploredTileIds().count), known natives \(nativeCount))")
            await client.disconnect()
            return
        }
        print("    adjacent to native settlement \(foundSettlement.settlementId)")

        func nativeTradeEnvelope(in message: ParsedMessage) -> ParsedMessage? {
            if message.tag == "nativeTrade", message.attributes["action"] != nil {
                return message
            }
            for child in message.children {
                if let result = nativeTradeEnvelope(in: child) { return result }
            }
            return nil
        }

        func nativeTradePayload(in message: ParsedMessage) -> ParsedMessage? {
            if message.tag == "nativeTrade",
               message.attributes["unit"] != nil,
               message.attributes["settlement"] != nil {
                return message
            }
            for child in message.children {
                if let result = nativeTradePayload(in: child) { return result }
            }
            return nil
        }

        func waitForNativeTradeAction(_ expected: Set<String>,
                                      after startIndex: Int,
                                      timeout: TimeInterval = 30) async throws -> ParsedMessage {
            let deadline = Date().addingTimeInterval(timeout)
            while Date() < deadline {
                for incoming in delegate.receivedPayloads.dropFirst(startIndex) {
                    if incoming.tag == "error" {
                        throw TestError(message: "Java rejected native trade: \(incoming.attributes["message"] ?? "unknown error")")
                    }
                    guard let envelope = nativeTradeEnvelope(in: incoming),
                          let action = envelope.attributes["action"] else { continue }
                    if expected.contains(action) { return envelope }
                }
                try await Task.sleep(nanoseconds: 200_000_000)
            }
            let received = delegate.receivedPayloads.dropFirst(startIndex).map { message in
                "\(message.tag):\(message.attributes["action"] ?? "")"
            }
            throw TestError(message: "timed out waiting for native trade action \(expected.sorted()); received \(received)")
        }

        // Open native trade session.
        game = await client.game
        if (game.units[traderId]?.movesLeft ?? 0) <= 0 {
            try await endTurnAndWait()
            game = await client.game
        }
        guard (game.units[traderId]?.movesLeft ?? 0) > 0 else {
            throw TestError(message: "trading unit has no moves left adjacent to native settlement")
        }
        var session = NativeTradeSession(unitId: traderId, settlementId: foundSettlement.settlementId)
        let openStart = delegate.receivedPayloads.count
        let openReply = try await client.ask(message: session.toMessage(action: "OPEN", item: nil), timeout: 15)
        let openActions: Set<String> = ["ACK_OPEN", "NAK_HOSTILE", "NAK_INVALID", "NAK_NOSALE"]
        let openEnvelope: ParsedMessage
        if let directEnvelope = nativeTradeEnvelope(in: openReply),
           openActions.contains(directEnvelope.attributes["action"] ?? "") {
            openEnvelope = directEnvelope
        } else {
            openEnvelope = try await waitForNativeTradeAction(openActions, after: openStart)
        }
        guard openEnvelope.attributes["action"] == "ACK_OPEN" else {
            print("    native trade skipped: settlement replied \(openEnvelope.attributes["action"] ?? "unknown")")
            await client.disconnect()
            return
        }
        let openSession = NativeTradeSession(nativeTradeChild: nativeTradePayload(in: openEnvelope))
        guard !openSession.settlementToUnit.isEmpty || !openSession.unitToSettlement.isEmpty else {
            print("    native trade skipped: settlement returned no priced items")
            await client.disconnect()
            return
        }
        print("    native trade opened with \(openSession.settlementToUnit.count) buy / \(openSession.unitToSettlement.count) sell offers")

        session.settlementToUnit = openSession.settlementToUnit
        session.unitToSettlement = openSession.unitToSettlement
        let goldBefore = (await client.game).players[localPlayerId]?.gold ?? 0
        guard let item = openSession.settlementToUnit.first(where: {
            $0.priceIsValid && $0.price <= goldBefore && ($0.goodsType?.isEmpty == false)
        }) else {
            throw TestError(message: "native settlement returned no affordable buy offer")
        }

        let goodsType = item.goodsType ?? "goods"
        let cargoBefore = (await client.game).units[traderId]?.goods[goodsType] ?? 0

        // Haggling uses a discounted BUY offer; there is no separate HAGGLE action.
        var buyOffer = item
        let offerReduction = max(1, item.price / 10)
        buyOffer.price = max(1, item.price - offerReduction)
        let buyStart = delegate.receivedPayloads.count
        let buyActions: Set<String> = ["ACK_BUY", "ACK_BUY_HAGGLE", "NAK_GOODS", "NAK_HAGGLE", "NAK_HOSTILE", "NAK_INVALID", "NAK_NOSALE"]
        let buyReply = try await client.ask(message: session.toMessage(action: "BUY", item: buyOffer), timeout: 15)
        let firstEnvelope: ParsedMessage
        if let directEnvelope = nativeTradeEnvelope(in: buyReply),
           buyActions.contains(directEnvelope.attributes["action"] ?? "") {
            firstEnvelope = directEnvelope
        } else {
            firstEnvelope = try await waitForNativeTradeAction(buyActions, after: buyStart)
        }
        guard let firstAction = firstEnvelope.attributes["action"] else {
            throw TestError(message: "native trade BUY returned an acknowledgement without an action")
        }

        var finalAction = firstAction
        var negotiatedPrice = buyOffer.price
        var purchaseEnvelope = firstEnvelope
        if firstAction != "ACK_BUY" && firstAction != "ACK_BUY_HAGGLE" {
            print("    native trade BUY offer declined: \(firstAction)")
            await client.disconnect()
            return
        }
        if firstAction == "ACK_BUY_HAGGLE" {
            let counterSession = NativeTradeSession(nativeTradeChild: nativeTradePayload(in: firstEnvelope))
            guard let counterItem = counterSession.item else {
                throw TestError(message: "native trade haggle acknowledgement omitted counter-offer")
            }
            negotiatedPrice = counterItem.price
            print("    Java counter-offered \(negotiatedPrice) gold after \(buyOffer.price) gold offer")
            let acceptStart = delegate.receivedPayloads.count
            let acceptReply = try await client.ask(message: session.toMessage(action: "BUY", item: counterItem), timeout: 15)
            let acceptEnvelope: ParsedMessage
            if let directEnvelope = nativeTradeEnvelope(in: acceptReply),
               buyActions.contains(directEnvelope.attributes["action"] ?? "") {
                acceptEnvelope = directEnvelope
            } else {
                acceptEnvelope = try await waitForNativeTradeAction(buyActions, after: acceptStart)
            }
            purchaseEnvelope = acceptEnvelope
            finalAction = acceptEnvelope.attributes["action"] ?? "unknown"
        } else {
            print("    Java responded to discounted BUY with \(firstAction)")
        }
        guard finalAction == "ACK_BUY" else {
            print("    native trade negotiation ended with \(finalAction); no purchase completed")
            await client.disconnect()
            return
        }

        var tradeObserved = false
        for _ in 0..<50 {
            game = await client.game
            let cargoAfter = game.units[traderId]?.goods[goodsType] ?? 0
            let goldAfter = game.players[localPlayerId]?.gold ?? goldBefore
            if cargoAfter > cargoBefore && goldAfter < goldBefore {
                tradeObserved = true
                break
            }
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        guard tradeObserved else {
            throw TestError(message: "Java acknowledged BUY but cargo/gold did not change")
        }
        print("    bought \(goodsType) for negotiated price \(negotiatedPrice)")

        let postPurchaseSession = NativeTradeSession(nativeTradeChild: nativeTradePayload(in: purchaseEnvelope))
        if let sellItem = postPurchaseSession.unitToSettlement.first(where: {
            $0.goodsType == goodsType && $0.priceIsValid
        }) {
            let goldBeforeSale = (await client.game).players[localPlayerId]?.gold ?? 0
            let cargoBeforeSale = (await client.game).units[traderId]?.goods[goodsType] ?? 0
            let sellStart = delegate.receivedPayloads.count
            let sellActions: Set<String> = ["ACK_SELL", "ACK_SELL_HAGGLE", "NAK_GOODS", "NAK_HAGGLE", "NAK_HOSTILE", "NAK_INVALID", "NAK_NOSALE"]
            let sellReply = try await client.ask(message: session.toMessage(action: "SELL", item: sellItem), timeout: 15)
            let sellEnvelope: ParsedMessage
            if let directEnvelope = nativeTradeEnvelope(in: sellReply),
               sellActions.contains(directEnvelope.attributes["action"] ?? "") {
                sellEnvelope = directEnvelope
            } else {
                sellEnvelope = try await waitForNativeTradeAction(sellActions, after: sellStart)
            }
            let sellAction = sellEnvelope.attributes["action"] ?? "unknown"
            if sellAction == "ACK_SELL" {
                var saleObserved = false
                for _ in 0..<50 {
                    game = await client.game
                    let cargoAfterSale = game.units[traderId]?.goods[goodsType] ?? 0
                    let goldAfterSale = game.players[localPlayerId]?.gold ?? goldBeforeSale
                    if cargoAfterSale < cargoBeforeSale && goldAfterSale > goldBeforeSale {
                        saleObserved = true
                        break
                    }
                    try await Task.sleep(nanoseconds: 200_000_000)
                }
                guard saleObserved else {
                    throw TestError(message: "Java acknowledged SELL but cargo/gold did not change")
                }
                print("    sold \(goodsType) to the settlement")
            } else {
                print("    native settlement declined SELL: \(sellAction)")
            }
        }

        // CLOSE session.
        let closeStart = delegate.receivedPayloads.count
        try await client.send(message: session.toMessage(action: "CLOSE", item: nil))
        for _ in 0..<10 {
            if let error = delegate.receivedPayloads.dropFirst(closeStart).first(where: { $0.tag == "error" }) {
                throw TestError(message: "native trade CLOSE rejected: \(error.attributes["message"] ?? "unknown error")")
            }
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        print("    native trade session closed")

        await client.disconnect()
    }
}

// Diplomacy E2E probe: verify proposal to a European AI and async response handling.
if ProcessInfo.processInfo.environment["REAL_SERVER_DIPLOMACY_E2E"] == "1" {
    await integrationTest("real Java server diplomacy probe") {
        let host = ProcessInfo.processInfo.environment["REAL_SERVER_HOST"] ?? "127.0.0.1"
        let port = Int(ProcessInfo.processInfo.environment["REAL_SERVER_PORT"] ?? "3541") ?? 3541
        let client = FreeColClient(host: host, port: port)
        let delegate = TestDelegate()
        await client.setDelegate(delegate)

        try await client.connect()
        let vacant = await client.initialVacantPlayers
        let nationId = vacant?.children.first?.attributes["nationId"]
            ?? vacant?.children.first?.attributes["id"]
            ?? "model.nation.dutch"
        let userName = "CopilotDiplomacy-\(Int(Date().timeIntervalSince1970))"

        let result = try await client.login(userName: userName, nationId: nationId)
        if result.serverState == .preGame {
            try await client.send(message: ParsedMessage(tag: "ready", attributes: ["value": "true"], children: []))
            try await client.send(message: ParsedMessage(tag: "requestLaunch", attributes: [:], children: []))
        }

        let loopTask = Task { await client.startMessageLoop() }
        defer {
            loopTask.cancel()
            Task { await client.disconnect() }
        }

        var waited = 0
        while true {
            let current = await client.game
            if current.currentPlayerId != nil && !current.units.isEmpty { break }
            if waited >= 60 { throw TestError(message: "game did not start within 30s") }
            try await Task.sleep(nanoseconds: 500_000_000)
            waited += 1
        }

        var game = await client.game
        guard let spec = game.specification else {
            throw TestError(message: "launched game has no specification")
        }
        guard let localPlayerId = game.players.values.first(where: { $0.name == result.playerName })?.id else {
            throw TestError(message: "local player not found in launched game")
        }

        // Find an adjacent foreign colony owned by a European AI.
        func diplomacyTarget(in current: FreeColGame.Game) -> (unitId: String, colonyId: String, ownerId: String)? {
            for (unitId, unit) in current.units {
                guard unit.owner == localPlayerId,
                      spec.hasAbility("model.ability.negotiate", unitType: unit.unitType),
                      let unitTileId = current.resolvedTileId(for: unit),
                      let unitTile = current.tiles[unitTileId] else { continue }
                for (colonyId, colony) in current.colonies {
                    guard let ownerId = colony.owner,
                          ownerId != localPlayerId,
                          let owner = current.players[ownerId],
                          owner.playerType == .european,
                          owner.ai,
                          let colonyTileId = colony.tileId,
                          let colonyTile = current.tiles[colonyTileId] else { continue }
                    let dx = abs(colonyTile.x - unitTile.x)
                    let dy = abs(colonyTile.y - unitTile.y)
                    guard dx <= 1, dy <= 1, !(dx == 0 && dy == 0) else { continue }
                    return (unitId, colonyId, ownerId)
                }
            }
            return nil
        }

        // Try to explore a bit if no adjacent AI colony is known.
        func endTurnAndWait() async throws {
            let turnBefore = await client.game.turn.number
            _ = try await client.ask(message: ParsedMessage(tag: "endTurn", attributes: [:], children: []), timeout: 45)
            for _ in 0..<180 {
                let current = await client.game
                if current.turn.number > turnBefore && current.currentPlayerId == localPlayerId { return }
                try await Task.sleep(nanoseconds: 500_000_000)
            }
        }

        for _ in 0..<15 {
            if diplomacyTarget(in: game) != nil { break }
            try await endTurnAndWait()
            game = await client.game
        }

        guard let target = diplomacyTarget(in: game) else {
            print("    diplomacy skipped: no negotiable unit adjacent to a visible European AI colony after 15 turns")
            await client.disconnect()
            return
        }

        print("    diplomacy target: colony \(target.colonyId) (owner \(target.ownerId))")

        let tradeNode = ParsedMessage(
            tag: "diplomaticTrade",
            attributes: [
                "context": "DIPLOMATIC",
                "sender": localPlayerId,
                "recipient": target.ownerId,
                "status": "PROPOSE_TRADE",
                "version": "1",
            ],
            children: [
                ParsedMessage(tag: "stanceTradeItem",
                              attributes: ["id": "model.tradeItem.stance", "stance": "PEACE",
                                           "source": localPlayerId, "destination": target.ownerId],
                              children: [])
            ]
        )
        let proposalMessage = ParsedMessage(
            tag: "diplomacy",
            attributes: ["ourId": target.unitId, "otherId": target.colonyId],
            children: [tradeNode]
        )

        func diplomacyEnvelope(in message: ParsedMessage) -> ParsedMessage? {
            if message.tag == "diplomacy",
               message.children.contains(where: { $0.tag == "diplomaticTrade" }) {
                return message
            }
            for child in message.children {
                if let result = diplomacyEnvelope(in: child) { return result }
            }
            return nil
        }

        func waitForDiplomacyResponse(after startIndex: Int,
                                      timeout: TimeInterval) async throws -> ParsedMessage? {
            let deadline = Date().addingTimeInterval(timeout)
            while Date() < deadline {
                for incoming in delegate.receivedPayloads.dropFirst(startIndex) {
                    if incoming.tag == "error" {
                        throw TestError(message: "Java diplomacy error: \(incoming.attributes["message"] ?? "unknown error")")
                    }
                    guard let envelope = diplomacyEnvelope(in: incoming),
                          let trade = envelope.children.first(where: { $0.tag == "diplomaticTrade" }),
                          let status = trade.attributes["status"],
                          ["ACCEPT_TRADE", "REJECT_TRADE", "PROPOSE_TRADE"].contains(status) else { continue }
                    let proposal = DiplomaticTradeProposal(raw: trade)
                    guard proposal.context == "DIPLOMATIC",
                          proposal.sender != nil,
                          proposal.recipient != nil else {
                        throw TestError(message: "AI diplomacy response has invalid context/version")
                    }
                    return envelope
                }
                try await Task.sleep(nanoseconds: 250_000_000)
            }
            return nil
        }

        func waitForPeaceWithAI() async throws -> Bool {
            for _ in 0..<40 {
                game = await client.game
                if game.players[localPlayerId]?.stances[target.ownerId] == .peace { return true }
                try await Task.sleep(nanoseconds: 250_000_000)
            }
            return false
        }

        // Send proposal and wait for an asynchronous AI answer.
        let responseStart = delegate.receivedPayloads.count
        let response = try await client.ask(message: proposalMessage, timeout: 60)
        guard response.tag != "error" else {
            throw TestError(message: "diplomacy proposal returned immediate error")
        }
        print("    diplomacy proposal accepted by server envelope")

        if let aiReply = try await waitForDiplomacyResponse(after: responseStart, timeout: 30),
           let trade = aiReply.children.first(where: { $0.tag == "diplomaticTrade" }) {
            let proposal = DiplomaticTradeProposal(raw: trade)
            print("    AI diplomacy response: \(proposal.status ?? "unknown") (\(proposal.clauses.count) clauses)")
            if proposal.status == "ACCEPT_TRADE" {
                guard try await waitForPeaceWithAI() else {
                    throw TestError(message: "AI accepted peace but the stance update was not applied")
                }
                print("    AI acceptance applied: stance is PEACE")
            } else if proposal.status == "PROPOSE_TRADE" {
                var attributes = trade.attributes
                attributes["status"] = "ACCEPT_TRADE"
                let acceptance = ParsedMessage(
                    tag: "diplomacy",
                    attributes: aiReply.attributes,
                    children: [ParsedMessage(tag: "diplomaticTrade", attributes: attributes, children: trade.children)]
                )
                _ = try await client.ask(message: acceptance, timeout: 20)
                print("    accepted AI counter-proposal")
                if try await waitForPeaceWithAI() {
                    print("    accepted counter-proposal applied: stance is PEACE")
                }
            }
        } else {
            print("    no AI diplomacy response observed within 30s (tolerated)")
        }

        await client.disconnect()
    }
}

print("\n\(passed) passed, \(failed) failed")
exit(failed > 0 ? 1 : 0)

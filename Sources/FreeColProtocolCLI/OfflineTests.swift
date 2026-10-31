import Foundation
import FreeColProtocol
import FreeColGame
import FreeColClient

func runOfflineTests() {
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
    try game.applyRemove(ParsedMessage(tag: "remove", attributes: [
        "xLength": "1", "x0": "player-1", "divert": "tile-1"
    ], children: []))
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
        attributes: [
            "xLength": "2",
            "x0": "unit-carrier",
            "x1": "tile-1",
            "divert": "tile-0",
        ],
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
}

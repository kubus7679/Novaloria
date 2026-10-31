import Foundation
import FreeColClient
import FreeColGame
import FreeColProtocol

func runClientLifecycleIntegrationTests() async {
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

    guard await client.game.id == "game-0" else { throw TestError(message: "game.id mismatch") }
    guard await client.game.turn == Turn(1) else { throw TestError(message: "turn mismatch") }
    guard let player = await client.game.players["player-1"] else {
      throw TestError(message: "player-1 not found")
    }
    guard player.name == "Alice" else { throw TestError(message: "player name mismatch") }
    guard await client.game.map?.width == 40 else { throw TestError(message: "map.width mismatch") }
    guard await client.game.tiles.count == 2 else {
      throw TestError(message: "tile count mismatch")
    }
    guard await client.game.units.count == 1 else {
      throw TestError(message: "unit count mismatch")
    }
    guard await client.game.colonies.count == 1 else {
      throw TestError(message: "colony count mismatch")
    }

    await server.stop()
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
        await client.startMessageLoop()
      }
      group.addTask {
        try await server.doHandshake(gameResponse: gameXML)
        // Send some updates
        await server.send("<newTurn turn=\"6\"/>")
        await server.send("<setCurrentPlayer player=\"player-1\"/>")
        await server.flush()
        try await Task.sleep(nanoseconds: 500_000_000)
        await server.stop()
      }
      // Timeout after 5 seconds
      try await Task.sleep(nanoseconds: 5_000_000_000)
      group.cancelAll()
    }

    // Verify game state was updated
    guard await client.game.turn == Turn(6) else {
      throw TestError(message: "turn not updated: \(await client.game.turn)")
    }
    guard await client.game.currentPlayerId == "player-1" else {
      throw TestError(message: "currentPlayer not set")
    }

    await server.stop()
  }

  await integrationTest("connect captures vacantPlayers sent after gameState") {
    let server = MockServer()
    let port = server.port
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
        await server.send(
          "<vacantPlayers><player id=\"nation-dutch\" nationId=\"model.nation.dutch\" nationName=\"Dutch\"/></vacantPlayers>"
        )
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
    let port = server.port
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
    let port = server.port

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
        await client.startMessageLoop()
      }
      group.addTask {
        try await server.doHandshake(gameResponse: gameXML)
        try await Task.sleep(nanoseconds: 250_000_000)
        await server.send("<startGame/>")
        await server.flush()
        try await Task.sleep(nanoseconds: 500_000_000)
        await server.stop()
      }
      try await Task.sleep(nanoseconds: 5_000_000_000)
      group.cancelAll()
    }

    guard delegate.receivedMessages.contains("startGame") else {
      throw TestError(message: "startGame did not reach delegate")
    }

    await server.stop()
  }

  await integrationTest("reconnect reaches UI delegate during message loop") {
    let server = MockServer()
    let port = server.port

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
        await client.startMessageLoop()
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
    let port = server.port

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
        await client.startMessageLoop()
      }
      group.addTask {
        try await server.doHandshake(gameResponse: gameXML)

        let endTurnLine = try await server.nextLine()
        let endTurnMsg = try XMLDecoder.decode(endTurnLine)
        guard endTurnMsg.tag == "endTurn" else {
          throw TestError(message: "expected endTurn, got \(endTurnMsg.tag)")
        }

        await server.send(
          "<multiple><newTurn turn=\"2\"/><setCurrentPlayer player=\"player-2\"/></multiple>")
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
}

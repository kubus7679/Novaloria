import Foundation
import FreeColProtocol
import FreeColGame
import NovaloriaClient

func abandonColonyE2EProbe() async throws {
    let host = ProcessInfo.processInfo.environment["REAL_SERVER_HOST"] ?? "127.0.0.1"
    let port = Int(ProcessInfo.processInfo.environment["REAL_SERVER_PORT"] ?? "3541") ?? 3541
    let client = NovaloriaClient(host: host, port: port)
    let delegate = TestDelegate()
    await client.setDelegate(delegate)

    try await client.connect()
    let vacant = await client.initialVacantPlayers
    let nationId = vacant?.children.first?.attributes["nationId"]
        ?? vacant?.children.first?.attributes["id"]
        ?? "model.nation.dutch"
    let result = try await client.login(
        userName: "FreeColE2ENativeTrade",
        nationId: nationId
    )

    let loopTask = Task { await client.startMessageLoop() }
    defer {
        loopTask.cancel()
        Task { await client.disconnect() }
    }

    var game = await client.game
    for _ in 0..<60 {
        if game.currentPlayerId != nil,
           game.players.values.contains(where: { $0.name == result.playerName }),
           game.colonies.values.contains(where: { $0.name == "E2E Abandonment" }) {
            break
        }
        try await Task.sleep(nanoseconds: 500_000_000)
        game = await client.game
    }
    guard let localPlayer = game.players.values.first(where: { $0.name == result.playerName }),
          let colony = game.colonies.values.first(where: {
              $0.owner == localPlayer.id && $0.name == "E2E Abandonment"
          }),
          let tileId = colony.tileId else {
        throw TestError(message: "fixture colony or its tile was not loaded")
    }
    guard game.tiles[tileId]?.settlement == colony.id else {
        throw TestError(message: "fixture colony is not attached to its tile")
    }
    guard colony.unitCount == 0 else {
        throw TestError(message: "fixture colony has \(colony.unitCount) units; expected an empty colony")
    }

    print("    abandoning colony \(colony.id) on \(tileId)")
    let response = try await client.ask(message: ParsedMessage(
        tag: "abandonColony",
        attributes: ["colony": colony.id],
        children: []
    ), timeout: 10)

    var abandoned = false
    for _ in 0..<40 {
        game = await client.game
        if game.colonies[colony.id] == nil,
           game.tiles[tileId] != nil,
           game.tiles[tileId]?.settlement == nil,
           game.tiles[tileId]?.owner == nil {
            abandoned = true
            break
        }
        try await Task.sleep(nanoseconds: 250_000_000)
    }
    guard abandoned else {
        let tile = game.tiles[tileId]
        func summary(_ message: ParsedMessage) -> String {
            let children = message.children.map(summary).joined(separator: ",")
            return "\(message.tag)\(message.attributes)[\(children)]"
        }
        throw TestError(message: "abandonment not reflected: colony=\(game.colonies[colony.id] != nil), settlement=\(tile?.settlement ?? "nil"), owner=\(tile?.owner ?? "nil"), response=\(summary(response))")
    }
    guard !delegate.receivedPayloads.contains(where: { $0.tag == "error" }) else {
        throw TestError(message: "server rejected colony abandonment")
    }
    print("    colony removed and tile \(tileId) released")
}

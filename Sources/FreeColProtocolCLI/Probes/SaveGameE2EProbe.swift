import Foundation
import FreeColProtocol
import FreeColClient

func saveGameE2EProbe() async throws {
    let environment = ProcessInfo.processInfo.environment
    let client = FreeColClient(
        host: environment["REAL_SERVER_HOST"] ?? "127.0.0.1",
        port: Int(environment["REAL_SERVER_PORT"] ?? "3541") ?? 3541
    )
    let result = try await connectAndLogin(
        client, userName: environment["REAL_SERVER_USERNAME"] ?? "FreeColE2ENativeTrade"
    )
    guard result.serverState != .preGame,
          let path = environment["REAL_SERVER_SAVE_PATH"] else {
        await client.disconnect()
        throw TestError(message: "save probe requires a loaded game and REAL_SERVER_SAVE_PATH")
    }
    defer {
        Task { await client.disconnect() }
    }
    let reply = try await client.ask(message: ParsedMessage(
        tag: "saveGame", attributes: [:], children: []
    ), timeout: 60)
    let data = try ServerSavegame.decode(reply)
    try data.write(to: URL(fileURLWithPath: path), options: .atomic)
    print("    full server save exported (\(data.count) bytes)")
    await client.disconnect()
}

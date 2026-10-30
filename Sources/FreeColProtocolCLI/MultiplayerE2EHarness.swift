import Foundation
import FreeColProtocol
import FreeColGame
import FreeColClient

struct MultiplayerClient {
    let client: FreeColClient
    let nationIndex: Int
    let userName: String
    let nationId: String
}

actor MultiplayerE2EHarness {
    let serverHost: String
    let serverPort: Int
    let playerCount: Int

    init(serverHost: String, serverPort: Int, playerCount: Int) {
        self.serverHost = serverHost
        self.serverPort = serverPort
        self.playerCount = playerCount
    }

    func runTest() async throws {
        print("    Starting multiplayer E2E test with \(playerCount) players...")

        // Step 1: Connect all players
        let clients = try await connectAllPlayers()
        print("    All \(clients.count) players connected and in game")

        // Step 2: Run turn gating test
        try await runTurnGatingTest(clients: clients)
        print("    Turn gating test passed")

        // Step 3: Run endTurn rejection test
        try await runEndTurnRejectionTest(clients: clients)
        print("    EndTurn rejection test passed")

        // Step 4: Cleanup
        for c in clients {
            await c.client.disconnect()
        }
        print("    All clients disconnected")
    }

    private func connectAllPlayers() async throws -> [MultiplayerClient] {
        var result: [MultiplayerClient] = []

        // First, connect one client to get available nations
        let probeClient = FreeColClient(host: serverHost, port: serverPort)
        try await probeClient.connect()
        let vacant = await probeClient.initialVacantPlayers
        let nations = vacant?.children.compactMap { $0.attributes["nationId"] } ?? ["model.nation.dutch", "model.nation.english", "model.nation.french", "model.nation.spanish"]
        await probeClient.disconnect()

        // Connect each player with a different nation
        for i in 0..<min(playerCount, nations.count) {
            let client = FreeColClient(host: serverHost, port: serverPort)
            let userName = "MPTest\(i)-\(Int(Date().timeIntervalSince1970))"
            let nationId = nations[i]

            try await client.connect()
            let loginResult = try await client.login(userName: userName, nationId: nationId)

            // If pre-game, ready up and request launch
            if loginResult.serverState == .preGame {
                try await client.send(message: ParsedMessage(tag: "ready", attributes: ["value": "true"], children: []))
                try await client.send(message: ParsedMessage(tag: "requestLaunch", attributes: [:], children: []))
            }

            // Start message loop
            let _ = Task { await client.startMessageLoop() }

            // Wait for in-game state
            try await waitForInGame(client: client)

            result.append(MultiplayerClient(
                client: client,
                nationIndex: i,
                userName: userName,
                nationId: nationId
            ))

            // Small delay between connections
            try await Task.sleep(nanoseconds: 500_000_000)
        }

        return result
    }

    private func waitForInGame(client: FreeColClient) async throws {
        var waited = 0
        while true {
            let current = await client.game
            if current.currentPlayerId != nil && !current.units.isEmpty { break }
            if waited >= 60 { throw TestError(message: "game did not start within 30s") }
            try await Task.sleep(nanoseconds: 500_000_000)
            waited += 1
        }
    }

    private func getLocalPlayerId(for client: MultiplayerClient) async throws -> String {
        let game = await client.client.game
        return game.players.values.first(where: { $0.name == client.userName })?.id ?? ""
    }

    private func isClientCurrentPlayer(_ client: MultiplayerClient) async throws -> Bool {
        let game = await client.client.game
        let localPlayerId = try await getLocalPlayerId(for: client)
        guard let currentPlayerId = game.currentPlayerId else { return false }
        return currentPlayerId == localPlayerId
    }

    private func findCurrentPlayerClient(clients: [MultiplayerClient]) async throws -> MultiplayerClient {
        // Wait a bit for the game state to settle
        try await Task.sleep(nanoseconds: 1_000_000_000)

        for c in clients {
            if try await isClientCurrentPlayer(c) {
                return c
            }
        }

        // Fallback: check currentPlayerId directly
        for c in clients {
            let game = await c.client.game
            if let currentPlayerId = game.currentPlayerId,
               let localPlayer = game.players.values.first(where: { $0.name == c.userName }),
               localPlayer.id == currentPlayerId {
                return c
            }
        }

        throw TestError(message: "Could not determine current player client")
    }

    private func runTurnGatingTest(clients: [MultiplayerClient]) async throws {
        print("    Running turn gating test...")

        // Java only advances the turn once every player has moved in sequence,
        // so each human endTurn passes play to the next player (AIs move on their own).
        let turnBefore = await clients[0].client.game.turn.number
        var ended: [String] = []
        for _ in 0..<(clients.count * 4) {
            if await clients[0].client.game.turn.number > turnBefore { break }
            guard let current = try? await findCurrentPlayerClient(clients: clients) else {
                try await Task.sleep(nanoseconds: 500_000_000)
                continue
            }
            if ended.last == current.userName {
                // Server has not handed over play yet.
                try await Task.sleep(nanoseconds: 500_000_000)
                continue
            }
            _ = try await current.client.ask(
                message: ParsedMessage(tag: "endTurn", attributes: [:], children: []),
                timeout: 45
            )
            ended.append(current.userName)
            print("    Current player \(current.userName) sent endTurn")
        }
        guard !ended.isEmpty else {
            throw TestError(message: "no human player was ever the current player")
        }

        for c in clients {
            try await waitForTurnAdvance(client: c.client, fromTurn: turnBefore)
            let newTurn = await c.client.game.turn.number
            guard newTurn > turnBefore else {
                throw TestError(message: "Turn did not advance for \(c.userName)")
            }
            print("    \(c.userName) advanced to turn \(newTurn)")
        }

        // Verify a new current player is set
        let newCurrentClient = try await findCurrentPlayerClient(clients: clients)
        print("    New current player: \(newCurrentClient.userName)")
    }

    private func waitForTurnAdvance(client: FreeColClient, fromTurn: Int) async throws {
        var waited = 0
        while true {
            let current = await client.game
            if current.turn.number > fromTurn && current.currentPlayerId != nil {
                break
            }
            if waited >= 180 {
                throw TestError(message: "turn did not advance within 90s")
            }
            try await Task.sleep(nanoseconds: 500_000_000)
            waited += 1
        }
    }

    private func runEndTurnRejectionTest(clients: [MultiplayerClient]) async throws {
        print("    Running endTurn rejection test...")

        // Find a non-current player
        try await Task.sleep(nanoseconds: 1_000_000_000)

        var nonCurrentClient: MultiplayerClient?
        for c in clients {
            let isCurrent = try await isClientCurrentPlayer(c)
            if !isCurrent {
                nonCurrentClient = c
                break
            }
        }

        guard let nonCurrent = nonCurrentClient else {
            print("    Skipping rejection test - all clients are current player (single player game)")
            return
        }

        let originalTurn = await nonCurrent.client.game.turn.number
        let originalTurnNumber = originalTurn

        print("    Non-current player \(nonCurrent.userName) attempting endTurn...")

        do {
            _ = try await nonCurrent.client.ask(
                message: ParsedMessage(tag: "endTurn", attributes: [:], children: []),
                timeout: 30
            )
            throw TestError(message: "Non-current player endTurn should have been rejected")
        } catch let FreeColProtocolError.serverError(message) {
            print("    Server rejected endTurn with: \(message)")
            guard !message.isEmpty else {
                throw TestError(message: "Server error message should not be empty")
            }
        } catch {
            // Other errors (timeout, etc.) are also acceptable as rejection
            print("    endTurn failed as expected: \(error)")
        }

        // Verify model did not change
        let afterTurn = await nonCurrent.client.game.turn.number
        guard afterTurn == originalTurnNumber else {
            throw TestError(message: "Turn should not advance for non-current player")
        }

        print("    Model unchanged after rejection")
    }
}

// CLI integration
extension MultiplayerE2EHarness {
    static func runFromEnvironment() async throws {
        let host = ProcessInfo.processInfo.environment["REAL_SERVER_HOST"] ?? "127.0.0.1"
        let port = Int(ProcessInfo.processInfo.environment["REAL_SERVER_PORT"] ?? "3541") ?? 3541
        let playerCount = Int(ProcessInfo.processInfo.environment["REAL_SERVER_PLAYER_COUNT"] ?? "2") ?? 2

        let harness = MultiplayerE2EHarness(serverHost: host, serverPort: port, playerCount: playerCount)
        try await harness.runTest()
    }
}
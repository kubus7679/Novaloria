import SwiftUI
import FreeColProtocol
import FreeColGame
import FreeColClient

@MainActor
@Observable
final class GameState {
    enum Phase: CustomStringConvertible {
        case disconnected
        case connecting
        case login
        case inGame

        var description: String {
            switch self {
            case .disconnected: return "Disconnected"
            case .connecting: return "Connecting…"
            case .login: return "Login"
            case .inGame: return "In Game"
            }
        }
    }

    var phase: Phase = .disconnected
    var statusMessage: String = ""
    var errorMessage: String?

    private(set) var client: FreeColClient?
    private var bridge: ClientBridge?
    private var server: MockServer?
    private var messageLoopTask: Task<Void, Never>?
    private(set) var cachedGame: Game?

    var game: Game? { cachedGame }

    func startLocal(userName: String, nationId: String) {
        guard case .disconnected = phase else { return }
        FreeColLogger.shared.info("Starting local game: user=\(userName) nation=\(nationId)")
        errorMessage = nil
        phase = .connecting
        statusMessage = "Starting local server…"

        let server = MockServer()
        self.server = server
        let bridge = ClientBridge(gameState: self)
        self.bridge = bridge

        Task {
            let actualPort = await server.port
            FreeColLogger.shared.info("MockServer on port \(actualPort)")
            let client = FreeColClient(host: "127.0.0.1", port: actualPort)
            self.client = client
            await client.setDelegate(bridge)
            do {
                async let serverHandshake: Void = runServerHandshake(
                    server: server, gameXML: makeGameXML())

                try await client.connect()
                statusMessage = "Connected, logging in…"
                _ = try await client.login(userName: userName, nationId: nationId)
                cachedGame = await client.game

                // Make sure handshake completed
                _ = try await serverHandshake

                phase = .inGame
                statusMessage = ""
                startMessageLoop(client: client, server: server)
            } catch {
                FreeColLogger.shared.error("Local game failed: \(error)")
                errorMessage = error.localizedDescription
                phase = .disconnected
                statusMessage = ""
            }
        }
    }

    private func runServerHandshake(server: MockServer, gameXML: String) async throws {
        try await server.waitForConnection()
        try await server.doHandshake(gameResponse: gameXML)
    }

    func connect(host: String, port: Int) {
        guard case .disconnected = phase else { return }
        FreeColLogger.shared.info("Connecting to \(host):\(port)...")
        errorMessage = nil
        phase = .connecting
        statusMessage = "Connecting to \(host):\(port)…"
        let client = FreeColClient(host: host, port: port)
        self.client = client
        let bridge = ClientBridge(gameState: self)
        self.bridge = bridge

        Task {
            await client.setDelegate(bridge)
            do {
                try await client.connect()
                phase = .login
                statusMessage = "Connected"
            } catch {
                FreeColLogger.shared.error("Connection failed: \(error)")
                errorMessage = error.localizedDescription
                phase = .disconnected
                statusMessage = ""
            }
        }
    }

    func login(userName: String, nationId: String) {
        guard case .login = phase, let client = client else { return }
        FreeColLogger.shared.info("Logging in: user=\(userName) nation=\(nationId)")
        errorMessage = nil
        phase = .connecting
        statusMessage = "Logging in…"

        Task {
            do {
                _ = try await client.login(userName: userName, nationId: nationId)
                cachedGame = await client.game
                phase = .inGame
                statusMessage = ""
                startMessageLoop(client: client, server: nil)
            } catch {
                FreeColLogger.shared.error("Login failed: \(error)")
                errorMessage = error.localizedDescription
                phase = .login
                statusMessage = "Login failed"
            }
        }
    }

    func disconnect() {
        messageLoopTask?.cancel()
        messageLoopTask = nil
        Task {
            await client?.disconnect()
            await server?.stop()
        }
        server = nil
        client = nil
        bridge = nil
        phase = .disconnected
        statusMessage = ""
    }

    func clearError() { errorMessage = nil }

    private func startMessageLoop(client: FreeColClient, server: MockServer? = nil) {
        messageLoopTask = Task {
            await client.startMessageLoop()
            if !Task.isCancelled {
                self.errorMessage = "Disconnected from server"
                self.disconnect()
            }
        }
    }
}

private func makeGameXML() -> String {
    """
    <game id="local-game" turn="1">
      <player id="player-european" username="Player" nationId="model.nation.dutch" gold="500"/>
      <player id="player-native-1" nationId="model.nation.iroquois" playerType="INDIAN"/>
      <map id="map-0" width="10" height="8">
        <tile id="tile-0-0" x="0" y="0" type="model.tile.ocean"/>
        <tile id="tile-1-0" x="1" y="0" type="model.tile.ocean"/>
        <tile id="tile-2-0" x="2" y="0" type="model.tile.ocean"/>
        <tile id="tile-3-0" x="3" y="0" type="model.tile.plains"/>
        <tile id="tile-4-0" x="4" y="0" type="model.tile.plains" owner="player-european"/>
        <tile id="tile-0-1" x="0" y="1" type="model.tile.ocean"/>
        <tile id="tile-1-1" x="1" y="1" type="model.tile.ocean"/>
        <tile id="tile-2-1" x="2" y="1" type="model.tile.grassland"/>
        <tile id="tile-3-1" x="3" y="1" type="model.tile.grassland" owner="player-european"/>
        <tile id="tile-4-1" x="4" y="1" type="model.tile.grassland" owner="player-european"/>
        <tile id="tile-0-2" x="0" y="2" type="model.tile.ocean"/>
        <tile id="tile-1-2" x="1" y="2" type="model.tile.ocean"/>
        <tile id="tile-2-2" x="2" y="2" type="model.tile.ocean"/>
        <tile id="tile-3-2" x="3" y="2" type="model.tile.ocean"/>
        <tile id="tile-4-2" x="4" y="2" type="model.tile.ocean"/>
        <tile id="tile-0-3" x="0" y="3" type="model.tile.ocean"/>
        <tile id="tile-1-3" x="1" y="3" type="model.tile.ocean"/>
        <tile id="tile-2-3" x="2" y="3" type="model.tile.ocean"/>
        <tile id="tile-3-3" x="3" y="3" type="model.tile.ocean"/>
        <tile id="tile-4-3" x="4" y="3" type="model.tile.ocean"/>
      </map>
      <unit id="unit-colonist" owner="player-european" unitType="model.unit.colonist" location="tile-4-1" movesLeft="3" state="ACTIVE"/>
      <colony id="colony-amsterdam" name="Amsterdam" owner="player-european" tile="tile-4-0" settlementType="model.settlement.colony"/>
    </game>
    """
}

private final class ClientBridge: ClientDelegate {
    weak var gameState: GameState?

    init(gameState: GameState) {
        self.gameState = gameState
    }

    nonisolated func clientDidConnect() {}

    nonisolated func clientDidLogin(_ result: LoginResult) {}

    nonisolated func clientDidReceiveGameState(_ parsed: ParsedMessage) {}

    nonisolated func clientDidDisconnect(error: Error?) {
        guard let gs = gameState else { return }
        Task { @MainActor in
            gs.errorMessage = error?.localizedDescription ?? "Disconnected"
            gs.disconnect()
        }
    }

    nonisolated func clientDidUpdate() {}
}

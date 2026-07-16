import Foundation
import FreeColProtocol
import FreeColGame

public protocol ClientDelegate: AnyObject {
    func clientDidConnect()
    func clientDidLogin(_ result: LoginResult)
    func clientDidReceiveGameState(_ parsed: ParsedMessage)
    func clientDidDisconnect(error: Error?)
    func clientDidUpdate()
}

/// High-level FreeCol client that manages connection, login, and game state.
public actor FreeColClient {
    private let connection: Connection
    private let stateManager: GameStateManager
    public weak var delegate: ClientDelegate?

    public var game: Game { stateManager.game }

    public init(host: String = "localhost", port: Int = 3541) {
        self.connection = Connection(host: host, port: port)
        self.stateManager = GameStateManager()
    }

    /// Set the delegate.
    public func setDelegate(_ delegate: ClientDelegate?) {
        self.delegate = delegate
    }

    /// Connect to the server.
    public func connect() async throws {
        FreeColLogger.shared.info("FreeColClient connecting...")
        try await connection.connect()
        await delegate?.clientDidConnect()
    }

    /// Disconnect.
    public func disconnect() async {
        FreeColLogger.shared.info("FreeColClient disconnecting...")
        await connection.disconnect()
    }

    /// Perform the full login handshake.
    public func login(userName: String, nationId: String) async throws -> LoginResult {
        FreeColLogger.shared.info("FreeColClient login: user=\(userName) nation=\(nationId)")
        let initial = try await Handshake.receiveInitialMessages(connection)
        FreeColLogger.shared.info("Received initial messages, state=\(initial.gameState.rawValue)")
        let result = try await Handshake.login(
            connection,
            userName: userName,
            nationId: nationId
        )

        // Load game state from login response
        if let gameParsed = result.game {
            FreeColLogger.shared.info("Loading game state from login reply")
            try stateManager.game.load(from: gameParsed)
        } else {
            FreeColLogger.shared.info("No game data in login reply (still PRE_GAME)")
        }

        await delegate?.clientDidLogin(result)
        return result
    }

    /// Start processing incoming messages (call this after login).
    public func startMessageLoop() async {
        FreeColLogger.shared.info("Starting message loop...")
        do {
            while true {
                let line = try await connection.nextLine()
                let parsed = try XMLDecoder.decode(line)
                let handled = try stateManager.process(parsed)
                if !handled {
                    await delegate?.clientDidReceiveGameState(parsed)
                } else {
                    await delegate?.clientDidUpdate()
                }
            }
        } catch {
            FreeColLogger.shared.error("Message loop ended: \(error)")
            await delegate?.clientDidDisconnect(error: error)
        }
    }

    /// Send an action as a question and wait for the reply.
    public func ask(message: ParsedMessage) async throws -> ParsedMessage {
        try await connection.ask(message: message)
    }

    /// Send a fire-and-forget message.
    public func send(message: ParsedMessage) async throws {
        try await connection.send(message: message)
    }
}

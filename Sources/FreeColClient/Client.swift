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

    // Store initial handshake data for UI use
    public var initialVacantPlayers: ParsedMessage?
    public var initialGameState: ServerState?

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
        // Establish TCP connection and read initial server messages (gameState and vacantPlayers)
        FreeColLogger.shared.info("FreeColClient connect: establishing TCP connection")
        stateManager.reset()
        initialVacantPlayers = nil
        initialGameState = nil
        try await connection.connect()
        // Read the initial handshake messages
        let initial = try await Handshake.receiveInitialMessages(connection)
        self.initialVacantPlayers = initial.vacantPlayers
        self.initialGameState = initial.gameState

        // Handshake completed – notify UI
        delegate?.clientDidConnect()
    }

    /// Disconnect.
    public func disconnect() async {
        FreeColLogger.shared.info("FreeColClient disconnecting...")
        await connection.disconnect()
        initialVacantPlayers = nil
        initialGameState = nil
    }

    /// Perform the full login handshake.
    public func login(userName: String, nationId: String) async throws -> LoginResult {
        FreeColLogger.shared.info("FreeColClient login: user=\(userName) nation=\(nationId)")
        // Initial messages (gameState + vacantPlayers) were already consumed by connect()
        let result = try await Handshake.login(
            connection,
            userName: userName,
            nationId: nationId
        )

        try stateManager.loadFromLogin(result)

        delegate?.clientDidLogin(result)
        return result
    }

    /// Start processing incoming messages (call this after login).
    public func startMessageLoop() async {
        FreeColLogger.shared.info("Starting message loop...")
        FreeColLogger.shared.info("Question wrapper handling enabled")
        do {
            while true {
                let line = try await connection.nextLine()
                let parsed = try XMLDecoder.decode(line)

                if parsed.tag == "question" {
                    try await handleQuestion(parsed)
                    continue
                }

                let handled = try stateManager.process(parsed)
                if !handled {
                    delegate?.clientDidReceiveGameState(parsed)
                } else {
                    delegate?.clientDidUpdate()
                }
            }
        } catch {
            FreeColLogger.shared.error("Message loop ended: \(error)")
            delegate?.clientDidDisconnect(error: error)
        }
    }

    private func handleQuestion(_ parsed: ParsedMessage) async throws {
        guard let replyId = parsed.attributes["networkReplyId"] else {
            FreeColLogger.shared.debug("Ignoring malformed <question> without networkReplyId")
            return
        }

        FreeColLogger.shared.debug("Handling <question> (replyId=\(replyId))")
        var replyChildren: [ParsedMessage] = []

        if let payload = parsed.children.first {
            do {
                let handled = try stateManager.process(payload)
                if !handled {
                    delegate?.clientDidReceiveGameState(payload)
                } else {
                    delegate?.clientDidUpdate()
                }
            } catch {
                FreeColLogger.shared.error("Failed to process question payload <\(payload.tag)>: \(error)")
                replyChildren = [ParsedMessage(tag: "error", attributes: ["message": "\(error)"], children: [])]
            }
        }

        let reply = ParsedMessage(
            tag: "reply",
            attributes: ["networkReplyId": replyId],
            children: replyChildren
        )
        try await connection.send(message: reply)
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

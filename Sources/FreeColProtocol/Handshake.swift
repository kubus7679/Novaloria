import Foundation

public enum ServerState: String {
    case preGame = "PRE_GAME"
    case inGame = "IN_GAME"
    case endGame = "END_GAME"
    case loadGame = "LOAD_GAME"

    public var isInGame: Bool {
        self == .inGame || self == .loadGame
    }
}

public struct LoginResult {
    public let playerName: String
    public let nationId: String
    public let serverState: ServerState
    public let game: ParsedMessage?
    public let player: ParsedMessage?

    public init(
        playerName: String,
        nationId: String,
        serverState: ServerState,
        game: ParsedMessage?,
        player: ParsedMessage?
    ) {
        self.playerName = playerName
        self.nationId = nationId
        self.serverState = serverState
        self.game = game
        self.player = player
    }
}

public struct InitialMessages {
    public let gameState: ServerState
    public let vacantPlayers: ParsedMessage?
}

public enum Handshake {
    private static let initialMessageGracePeriod: TimeInterval = 0.2

    public static func receiveInitialMessages(_ connection: Connection) async throws -> InitialMessages {
        FreeColLogger.shared.info("Waiting for initial messages from server...")
        var gameState: ServerState?
        var vacantPlayers: ParsedMessage?

        while gameState == nil {
            let line = try await connection.nextLine()
            let parsed = try XMLDecoder.decode(line)
            try applyInitialMessage(parsed, gameState: &gameState, vacantPlayers: &vacantPlayers)
        }

                if gameState == .inGame {
                        while vacantPlayers == nil,
                                    let line = try await connection.nextLine(timeout: initialMessageGracePeriod) {
                                let parsed = try XMLDecoder.decode(line)
                                try applyInitialMessage(parsed, gameState: &gameState, vacantPlayers: &vacantPlayers)
                        }
        }

        return InitialMessages(gameState: gameState!, vacantPlayers: vacantPlayers)
    }

    private static func applyInitialMessage(
        _ parsed: ParsedMessage,
        gameState: inout ServerState?,
        vacantPlayers: inout ParsedMessage?
    ) throws {
        FreeColLogger.shared.debug("Received initial message: <\(parsed.tag)>")
        switch parsed.tag {
        case "gameState":
            guard let raw = parsed.attributes["state"],
                  let state = ServerState(rawValue: raw) else {
                throw FreeColProtocolError.invalidState("Unknown game state")
            }
            FreeColLogger.shared.info("Server state: \(raw)")
            gameState = state
        case "vacantPlayers":
            FreeColLogger.shared.info("Vacant players: \(parsed.attributes)")
            vacantPlayers = parsed
        default:
            FreeColLogger.shared.debug("Ignoring unexpected initial message: <\(parsed.tag)>")
        }
    }

    public static func login(
        _ connection: Connection,
        userName: String,
        nationId: String,
        version: String = "1.2.0+git",
        singlePlayer: Bool = true,
        currentPlayer: Bool = false
    ) async throws -> LoginResult {
        FreeColLogger.shared.info("Sending login: user=\(userName) nation=\(nationId)")

        let loginMessage = ParsedMessage(
            tag: "login",
            attributes: [
                "userName": userName,
                "nationId": nationId,
                "version": version,
                "singlePlayer": singlePlayer ? "true" : "false",
                "currentPlayer": currentPlayer ? "true" : "false"
            ],
            children: []
        )

        let reply = try await connection.ask(message: loginMessage)

        guard let loginChild = reply.children.first, loginChild.tag == "login" else {
            FreeColLogger.shared.error("No <login> in reply, children: \(reply.children.map(\.tag))")
            throw FreeColProtocolError.invalidState("No login message in reply")
        }

        let attrs = loginChild.attributes
        guard let playerName = attrs["userName"],
              let nation = attrs["nationId"],
              let rawState = attrs["state"],
              let state = ServerState(rawValue: rawState) else {
            FreeColLogger.shared.error("Malformed login reply: attributes=\(attrs)")
            throw FreeColProtocolError.invalidState("Malformed login reply")
        }

        FreeColLogger.shared.info("Login result: player=\(playerName) nation=\(nation) state=\(rawState)")

        let game = loginChild.children.first { $0.tag == "game" }
        let player = loginChild.children.first { $0.tag == "player" }

        if game != nil {
            FreeColLogger.shared.info("Game data received in login reply")
        } else {
            FreeColLogger.shared.info("No game data in login reply (PRE_GAME)")
        }

        return LoginResult(
            playerName: playerName,
            nationId: nation,
            serverState: state,
            game: game,
            player: player
        )
    }
}

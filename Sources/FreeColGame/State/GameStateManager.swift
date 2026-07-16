import Foundation
import FreeColProtocol

/// Processes incoming server messages and applies them to the game state.
public final class GameStateManager: @unchecked Sendable {
    public let game: Game

    public init(game: Game = Game()) {
        self.game = game
    }

    /// Reset with a new game (e.g. after loading a save or reconnecting).
    public func reset() {
        // Game is a reference type; reassignment is handled by callers
    }

    /// Process a parsed message from the server.
    /// Returns true if the message was handled, false if it should be handled elsewhere.
    @discardableResult
    public func process(_ parsed: ParsedMessage) throws -> Bool {
        FreeColLogger.shared.debug("GameStateManager processing <\(parsed.tag)>")
        switch parsed.tag {
        case "multiple":
            for child in parsed.children {
                try process(child)
            }
            return true

        case "update":
            try game.applyUpdate(parsed)
            FreeColLogger.shared.debug("Applied update")
            return true

        case "partial":
            try game.applyPartial(parsed)
            FreeColLogger.shared.debug("Applied partial update")
            return true

        case "remove":
            try game.applyRemove(parsed)
            FreeColLogger.shared.debug("Applied remove")
            return true

        case "setCurrentPlayer":
            game.currentPlayerId = parsed.attributes["player"]
            FreeColLogger.shared.debug("Current player: \(parsed.attributes["player"] ?? "nil")")
            return true

        case "newTurn":
            let turnNumber = parsed.attributes.int("turn", default: 1)
            game.turn = Turn(turnNumber)
            FreeColLogger.shared.info("New turn: \(turnNumber)")
            return true

        case "addPlayer":
            for child in parsed.children {
                if child.tag == "player" {
                    let player = try Player(id: child.attributes["id"] ?? UUID().uuidString,
                                            attributes: child.attributes,
                                            children: child.children,
                                            game: game)
                    game.players[player.id] = player
                    FreeColLogger.shared.info("Added player: \(player.id)")
                }
            }
            return true

        case "startGame":
            FreeColLogger.shared.info("Game started!")
            return true

        case "gameState":
            FreeColLogger.shared.debug("GameState: \(parsed.attributes["state"] ?? "?")")
            return true

        default:
            FreeColLogger.shared.debug("Unhandled message: <\(parsed.tag)>")
            return false
        }
    }

    /// Load from a login response (full `<login>` message containing `<game>`).
    public func loadFromLogin(_ loginParsed: ParsedMessage) throws {
        // The login message's children contain the full game
        for child in loginParsed.children {
            if child.tag == "game" {
                try game.load(from: child)
                return
            }
        }
        throw GameError.noGameInLogin
    }

    public enum GameError: Error, CustomStringConvertible {
        case noGameInLogin
        public var description: String {
            switch self {
            case .noGameInLogin: return "No <game> element found in login reply"
            }
        }
    }
}

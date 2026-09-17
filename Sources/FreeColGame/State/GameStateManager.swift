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
        game.clear()
    }

    /// Load a full `<game>` object after login.
    public func loadGame(_ gameParsed: ParsedMessage) throws {
        try game.load(from: gameParsed)
    }

    /// Process a parsed message from the server.
    /// Returns true if the message was handled, false if it should be handled elsewhere.
    @discardableResult
    public func process(_ parsed: ParsedMessage) throws -> Bool {
        FreeColLogger.shared.debug("GameStateManager processing <\(parsed.tag)>")
        switch parsed.tag {
        case "question":
            // Defensive fallback: payload should normally be handled in FreeColClient.
            // If a wrapped question reaches the model layer, still apply its payload.
            if let payload = parsed.children.first {
                return try process(payload)
            }
            return false

        case "reply":
            // Some server flows return state deltas inside reply payloads.
            // Apply all children so model state does not depend on transport wrapping.
            var handledAny = false
            for child in parsed.children {
                if try process(child) {
                    handledAny = true
                }
            }
            // Decision responses must reach the UI layer to clear pending state.
            return containsDecisionPrompt(parsed) ? false : handledAny

        case "multiple":
            for child in parsed.children {
                try process(child)
            }
            // A ChangeSet may bundle a decision prompt with model updates. The
            // model part is applied above; forward the envelope so the UI can
            // surface the prompt.
            return containsDecisionPrompt(parsed) ? false : true

        case "update":
            try game.applyUpdate(parsed)
            FreeColLogger.shared.debug("Applied update")
            return containsDecisionPrompt(parsed) ? false : true

        case "featureChange":
            game.applyFeatureChange(parsed)
            FreeColLogger.shared.debug("Applied featureChange")
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

        case "ready":
            guard let playerId = parsed.attributes["player"] else {
                FreeColLogger.shared.debug("ready without player attribute")
                return false
            }
            let readyValue = parsed.attributes.bool("value", default: false)
            guard var player = game.players[playerId] else {
                FreeColLogger.shared.debug("ready for unknown player: \(playerId)")
                return false
            }
            player.ready = readyValue
            game.players[playerId] = player
            FreeColLogger.shared.debug("Player \(playerId) ready=\(readyValue)")
            return true

        case "setStance":
            guard game.players[parsed.attributes["first"] ?? ""] != nil else {
                FreeColLogger.shared.debug("setStance for unknown player")
                return false
            }
            try game.applySetStance(attributes: parsed.attributes)
            FreeColLogger.shared.debug("Applied setStance")
            return true

        case "setDead":
            try game.applyPlayerChange(tag: parsed.tag, attributes: parsed.attributes)
            FreeColLogger.shared.debug("Applied <setDead>")
            // Forward to the UI: a local death needs a defeat/revenge prompt.
            return false

        case "setAI", "setNation", "setNationType", "setColor", "setAvailable":
            try game.applyPlayerChange(tag: parsed.tag, attributes: parsed.attributes)
            FreeColLogger.shared.debug("Applied <\(parsed.tag)>")
            return true

        case "logout":
            if let playerId = parsed.attributes["player"] {
                game.removePlayer(playerId)
                FreeColLogger.shared.info("Player logged out: \(playerId)")
            }
            // Forward so the UI can end the session when it is the local player.
            return false

        case "newTradeRoute", "updateTradeRoute":
            var handledRoute = false
            for child in parsed.children where child.tag == "tradeRoute" {
                try game.loadTradeRoute(child)
                handledRoute = true
            }
            return handledRoute

        case "deleteTradeRoute":
            if let routeId = parsed.attributes["tradeRoute"] {
                game.removeTradeRoute(routeId)
                return true
            }
            return false

        case "animateMove":
            guard let unitId = parsed.attributes["unit"],
                  let newTile = parsed.attributes["newTile"] else {
                FreeColLogger.shared.debug("animateMove missing unit/newTile")
                return false
            }
            game.moveUnit(unitId, to: newTile)
            FreeColLogger.shared.debug("Applied animateMove unit=\(unitId) -> \(newTile)")
            // Return false so upper layers can still forward animation cues to the UI.
            return false

        case "animateAttack":
            // Animation/event only; no direct model mutation required here.
            return false

        case "startGame":
            FreeColLogger.shared.info("Game started!")
            return false

        case "gameState":
            FreeColLogger.shared.debug("GameState: \(parsed.attributes["state"] ?? "?")")
            return false

        case "error":
            return false

        default:
            FreeColLogger.shared.debug("Unhandled message: <\(parsed.tag)>")
            return false
        }
    }

    /// Tags that represent server-initiated prompts which need UI handling.
    private static let serverPromptTags: Set<String> = [
        "fountainOfYouth", "indianDemand", "lootCargo",
        "firstContact", "monarchAction", "newLandName", "newRegionName",
        "close", "highScores", "nationSummary", "nativeTrade", "diplomacy",
        "chooseFoundingFather", "scoutSpeakToChief", "spySettlement",
        "incite", "setDead"
    ]

    /// True if the message (or any nested child) carries a server prompt.
    private func containsDecisionPrompt(_ parsed: ParsedMessage) -> Bool {
        if Self.serverPromptTags.contains(parsed.tag) { return true }
        return parsed.children.contains { containsDecisionPrompt($0) }
    }

    /// Load from a login response (full `<login>` message containing `<game>`).
    public func loadFromLogin(_ loginParsed: ParsedMessage) throws {
        // The login message's children contain the full game
        for child in loginParsed.children {
            if child.tag == "game" {
                try loadGame(child)
                return
            }
        }
        throw GameError.noGameInLogin
    }

    /// Load from a decoded login result, if it carries a full `<game>` payload.
    public func loadFromLogin(_ result: LoginResult) throws {
        guard let gameParsed = result.game else {
            FreeColLogger.shared.info("No game data in login reply (still \(result.serverState.rawValue))")
            return
        }
        FreeColLogger.shared.info("Loading game state from login reply")
        try loadGame(gameParsed)
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

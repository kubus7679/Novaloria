import Foundation
import FreeColProtocol

public final class Game: @unchecked Sendable {
    public var id: String = "0"
    public var turn: Turn = Turn(1)
    public var currentPlayerId: String?
    public var uuid: String?
    public var clientUserName: String?

    public var map: GameMap?
    public var specification: Specification?

    public internal(set) var players: [String: Player] = [:]
    public internal(set) var tiles: [String: Tile] = [:]
    public internal(set) var units: [String: Unit] = [:]
    public internal(set) var colonies: [String: Colony] = [:]

    public init() {}

    /// Deserialize the full game from a `<game>` ParsedMessage (as received in login reply).
    public func load(from parsed: ParsedMessage) throws {
        guard parsed.tag == "game" else {
            throw GameError.invalidTag(parsed.tag)
        }
        id = parsed.attributes["id"] ?? "0"
        turn = Turn(parsed.attributes.int("turn", default: 1))
        currentPlayerId = parsed.attributes["currentPlayer"]
        uuid = parsed.attributes["UUID"]
        clientUserName = parsed.attributes["clientUserName"]

        for child in parsed.children {
            switch child.tag {
            case "freecol-specification":
                specification = Specification(parsed: child)
            case "map":
                try loadMap(child)
            case "player":
                let player = try Player(id: child.attributes["id"] ?? UUID().uuidString,
                                        attributes: child.attributes,
                                        children: child.children,
                                        game: self)
                players[player.id] = player
            case "unit":
                let unit = try Unit(id: child.attributes["id"] ?? UUID().uuidString,
                                    attributes: child.attributes,
                                    children: child.children,
                                    game: self)
                units[unit.id] = unit
            case "colony", "indianSettlement":
                let colony = try Colony(id: child.attributes["id"] ?? UUID().uuidString,
                                        attributes: child.attributes,
                                        children: child.children,
                                        game: self)
                colonies[colony.id] = colony
            case "cibola", "nationOptions", "areas":
                break // not yet handled
            default:
                break
            }
        }
    }

    /// Apply an `<update>` message (full object serializations).
    public func applyUpdate(_ parsed: ParsedMessage) throws {
        for child in parsed.children {
            switch child.tag {
            case "player":
                let player = try Player(id: child.attributes["id"] ?? UUID().uuidString,
                                        attributes: child.attributes,
                                        children: child.children,
                                        game: self)
                players[player.id] = player
            case "tile":
                let tile = try Tile(id: child.attributes["id"] ?? UUID().uuidString,
                                    attributes: child.attributes,
                                    children: child.children,
                                    game: self)
                tiles[tile.id] = tile
            case "unit":
                let unit = try Unit(id: child.attributes["id"] ?? UUID().uuidString,
                                    attributes: child.attributes,
                                    children: child.children,
                                    game: self)
                units[unit.id] = unit
            case "colony", "indianSettlement":
                let colony = try Colony(id: child.attributes["id"] ?? UUID().uuidString,
                                        attributes: child.attributes,
                                        children: child.children,
                                        game: self)
                colonies[colony.id] = colony
            case "game":
                try load(from: child)
            default:
                break
            }
        }
    }

    /// Apply a `<partial>` message (field-level updates).
    public func applyPartial(_ parsed: ParsedMessage) throws {
        guard let objectId = parsed.attributes["id"] else { return }
        let attrs = parsed.attributes

        if var player = players[objectId] {
            player.applyPartial(attributes: attrs)
            players[objectId] = player
        } else if var unit = units[objectId] {
            unit.applyPartial(attributes: attrs)
            units[objectId] = unit
        } else if var colony = colonies[objectId] {
            colony.applyPartial(attributes: attrs)
            colonies[objectId] = colony
        } else if objectId.hasPrefix("tile") {
            if let existing = tiles[objectId] {
                tiles[objectId] = existing
            }
        }
    }

    /// Apply a `<remove>` message.
    public func applyRemove(_ parsed: ParsedMessage) throws {
        let ids = extractRemoveIds(parsed)
        for objectId in ids {
            players.removeValue(forKey: objectId)
            units.removeValue(forKey: objectId)
            colonies.removeValue(forKey: objectId)
            tiles.removeValue(forKey: objectId)
        }
    }

    // MARK: - Helpers

    private func loadMap(_ parsed: ParsedMessage) throws {
        map = try GameMap(id: parsed.attributes["id"] ?? "map:0",
                           attributes: parsed.attributes,
                           children: parsed.children,
                           game: self)
        for child in parsed.children {
            if child.tag == "tile" {
                let tile = try Tile(id: child.attributes["id"] ?? UUID().uuidString,
                                    attributes: child.attributes,
                                    children: child.children,
                                    game: self)
                tiles[tile.id] = tile
            }
        }
    }

    private func extractRemoveIds(_ parsed: ParsedMessage) -> [String] {
        var ids: [String] = []
        for (key, value) in parsed.attributes {
            if key == "divert" {
                ids.append(value)
            } else if key.hasPrefix("array_") {
                ids.append(value)
            }
        }
        return ids
    }

    public enum GameError: Error, CustomStringConvertible {
        case invalidTag(String)
        case unknownObjectType(String)
        public var description: String {
            switch self {
            case .invalidTag(let tag): return "Invalid tag: \(tag)"
            case .unknownObjectType(let t): return "Unknown object type: \(t)"
            }
        }
    }
}

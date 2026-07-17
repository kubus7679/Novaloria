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

    /// Clear all server-derived state so the game can be reused for a new session.
    public func clear() {
        id = "0"
        turn = Turn(1)
        currentPlayerId = nil
        uuid = nil
        clientUserName = nil
        map = nil
        specification = nil
        players.removeAll()
        tiles.removeAll()
        units.removeAll()
        colonies.removeAll()
    }

    /// Deserialize the full game from a `<game>` ParsedMessage (as received in login reply).
    public func load(from parsed: ParsedMessage) throws {
        guard parsed.tag == "game" else {
            throw GameError.invalidTag(parsed.tag)
        }
        clear()
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
                // Units in Europe / high seas appear as direct children of <player>
                for playerChild in child.children where playerChild.tag == "unit" {
                    try loadUnitTree(playerChild)
                }
            case "unit":
                try loadUnitTree(child)
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
                try loadUnitTree(child)
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

            // Defensive cleanup: clear dangling references on remaining units.
            let unitIds = Array(units.keys)
            for unitId in unitIds {
                guard var unit = units[unitId] else { continue }
                var changed = false
                if unit.location == objectId {
                    unit.location = nil
                    changed = true
                }
                if unit.destination == objectId {
                    unit.destination = nil
                    changed = true
                }
                if changed {
                    units[unitId] = unit
                }
            }
        }
    }

    // MARK: - Local mutations

    /// Move a unit to a new tile (used for local simulations without a server).
    public func moveUnit(_ unitId: String, to destinationTileId: String) {
        guard var unit = units[unitId] else { return }
        unit.location = destinationTileId
        if unit.movesLeft > 0 {
            unit.movesLeft -= 1
        }
        if unit.destination == destinationTileId {
            unit.destination = nil
        }
        units[unitId] = unit
    }

    /// Build a colony locally (simulation without a server).
    public func buildColony(unitId: String, colonyName: String) {
        guard let unit = units[unitId],
              let tileId = unit.location,
              colonies.first(where: { $0.value.tileId == tileId }) == nil,
              let tile = tiles[tileId],
              let type = tile.type?.lowercased(),
              !type.contains("ocean"),
              !type.contains("highseas"),
              !type.contains("lake"),
              tile.settlement == nil else { return }
        let colonyId = "colony-\(colonyName.lowercased().replacingOccurrences(of: " ", with: "-"))"
        guard let colony = try? Colony(
            id: colonyId,
            attributes: [
                "name": colonyName,
                "owner": unit.owner ?? "",
                "tile": tileId,
                "settlementType": "model.settlement.colony",
            ],
            children: [],
            game: self
        ) else { return }
        colonies[colonyId] = colony
        // Mark the tile as having a settlement
        if var tile = tiles[tileId] {
            tile.settlement = colonyId
            tiles[tileId] = tile
        }
        units.removeValue(forKey: unitId)
    }

    /// Join an existing colony locally (simulation without a server).
    public func joinColony(unitId: String, colonyId: String) {
        guard let colony = colonies[colonyId],
              let tileId = colony.tileId,
              let unit = units[unitId],
              unit.location == tileId else {
            return
        }
        units.removeValue(forKey: unitId)
    }

    /// Embark a unit onto a carrier locally (simulation without a server).
    public func embarkUnit(unitId: String, carrierId: String) {
        guard var unit = units[unitId],
              let carrier = units[carrierId],
              let unitLoc = unit.location,
              let carrierLoc = carrier.location,
              unitLoc == carrierLoc,
              unitId != carrierId else {
            return
        }
        unit.location = carrierId
        units[unitId] = unit
    }

    /// Disembark a unit from a carrier locally (simulation without a server).
    public func disembarkUnit(unitId: String) {
        guard var unit = units[unitId],
              let carrierId = unit.location,
              let carrier = units[carrierId],
              let tileId = carrier.location else {
            return
        }
        unit.location = tileId
        units[unitId] = unit
    }

    /// Change a unit state locally (simulation without a server).
    public func changeUnitState(unitId: String, state: UnitState) {
        guard var unit = units[unitId] else { return }
        unit.state = state
        units[unitId] = unit
    }

    /// Disband a unit locally (simulation without a server).
    public func disbandUnit(unitId: String) {
        units.removeValue(forKey: unitId)
    }

    /// Set or clear a unit destination locally (simulation without a server).
    public func setUnitDestination(unitId: String, destinationId: String?) {
        guard var unit = units[unitId] else { return }
        unit.destination = destinationId
        units[unitId] = unit
    }

    /// Return the first tile on a shortest route between two tiles.
    public func nextPathStep(
        from startTileId: String,
        to destinationTileId: String,
        canTraverse: (String, String) -> Bool
    ) -> String? {
        guard startTileId != destinationTileId,
              tiles[startTileId] != nil,
              tiles[destinationTileId] != nil else {
            return nil
        }

        var queue: [String] = [startTileId]
        var head = 0
        var cameFrom: [String: String] = [:]
        var visited: Set<String> = [startTileId]

        while head < queue.count {
            let current = queue[head]
            head += 1

            if current == destinationTileId {
                break
            }

            for neighbor in neighboringTileIds(from: current) where !visited.contains(neighbor) {
                guard canTraverse(current, neighbor) else {
                    continue
                }
                visited.insert(neighbor)
                cameFrom[neighbor] = current
                queue.append(neighbor)
            }
        }

        guard visited.contains(destinationTileId) else {
            return nil
        }

        var step = destinationTileId
        while let previous = cameFrom[step], previous != startTileId {
            step = previous
        }
        return step
    }

    /// Return tiles that should be visible for a player using a small local heuristic.
    public func visibleTileIds(for playerId: String, radius: Int = 1) -> Set<String> {
        guard radius >= 0 else { return [] }

        var sources: Set<String> = []
        for tile in tiles.values where tile.owner == playerId {
            sources.insert(tile.id)
        }
        for colony in colonies.values where colony.owner == playerId {
            if let tileId = colony.tileId {
                sources.insert(tileId)
            }
        }
        for unit in units.values where unit.owner == playerId {
            if let tileId = resolvedTileId(for: unit) {
                sources.insert(tileId)
            }
        }

        var visible: Set<String> = []
        for source in sources {
            var frontier: Set<String> = [source]
            visible.insert(source)
            guard radius > 0 else { continue }

            for _ in 0..<radius {
                var nextFrontier: Set<String> = []
                for tileId in frontier {
                    for neighbor in neighboringTileIds(from: tileId) {
                        if visible.insert(neighbor).inserted {
                            nextFrontier.insert(neighbor)
                        }
                    }
                }
                frontier = nextFrontier
                if frontier.isEmpty {
                    break
                }
            }
        }
        return visible
    }

    /// Recover a sensible selection for a local player after the previously selected unit vanished.
    public func recoverSelection(
        for playerId: String,
        preferredTileId: String? = nil
    ) -> (unitId: String, tileId: String)? {
        if let preferredTileId,
           let unit = localUnit(on: preferredTileId, ownedBy: playerId) {
            return (unit.id, preferredTileId)
        }
        if let unit = firstActiveUnit(ownedBy: playerId),
           let tileId = resolvedTileId(for: unit) {
            return (unit.id, tileId)
        }
        return nil
    }

    /// Return the first active unit owned by a player, sorted by id.
    public func firstActiveUnit(ownedBy playerId: String) -> Unit? {
        units.values
            .filter { $0.owner == playerId && $0.state == .active }
            .sorted { $0.id < $1.id }
            .first
    }

    /// Return the local unit on a given tile, if any.
    public func localUnit(on tileId: String, ownedBy playerId: String) -> Unit? {
        units.values
            .filter { $0.owner == playerId && resolvedTileId(for: $0) == tileId }
            .sorted { $0.id < $1.id }
            .first
    }

    /// Set or clear a unit trade route locally (simulation without a server).
    public func setUnitTradeRoute(unitId: String, tradeRouteId: String?) {
        guard var unit = units[unitId] else { return }
        unit.tradeRoute = tradeRouteId
        units[unitId] = unit
    }

    /// Set a unit current stop index locally (simulation without a server).
    public func setUnitCurrentStop(unitId: String, index: Int) {
        guard var unit = units[unitId] else { return }
        unit.currentStop = index
        units[unitId] = unit
    }

    /// Assign or clear a teacher for a student locally (simulation without a server).
    public func assignTeacher(studentId: String, teacherId: String?) {
        guard var student = units[studentId] else { return }

        // Clear previous teacher back-reference if present.
        if let previousTeacherId = student.teacher,
           var previousTeacher = units[previousTeacherId],
           previousTeacher.student == studentId {
            previousTeacher.student = nil
            units[previousTeacherId] = previousTeacher
        }

        student.teacher = teacherId
        units[studentId] = student

        guard let teacherId,
              var teacher = units[teacherId] else {
            return
        }
        teacher.student = studentId
        units[teacherId] = teacher
    }

    /// Change a unit work type locally (simulation without a server).
    public func changeUnitWorkType(unitId: String, workTypeId: String) {
        guard var unit = units[unitId] else { return }
        unit.workType = workTypeId
        units[unitId] = unit
    }

    /// Change a unit work improvement type locally (simulation without a server).
    public func changeUnitWorkImprovementType(unitId: String, improvementTypeId: String) {
        guard var unit = units[unitId] else { return }
        unit.workImprovementType = improvementTypeId
        units[unitId] = unit
    }

    /// Cash in a treasure train locally (simulation without a server).
    public func cashInTreasureTrain(unitId: String) {
        guard var unit = units[unitId] else { return }
        unit.treasureAmount = 0
        units[unitId] = unit
    }

    /// Move a unit from colony interior to colony tile locally (simulation without a server).
    public func putOutsideColony(unitId: String) {
        guard var unit = units[unitId],
              let colonyId = unit.location,
              let colony = colonies[colonyId],
              let tileId = colony.tileId else {
            return
        }
        unit.location = tileId
        units[unitId] = unit
    }

    /// Assign a unit to a work location locally (simulation without a server).
    public func setUnitWorkLocation(unitId: String, workLocationId: String) {
        guard var unit = units[unitId] else { return }
        unit.location = workLocationId
        units[unitId] = unit
    }

    /// Rename a colony locally (simulation without a server).
    public func renameColony(colonyId: String, newName: String) {
        guard var colony = colonies[colonyId] else { return }
        colony.name = newName
        colonies[colonyId] = colony
    }

    /// Abandon a colony locally (simulation without a server).
    public func abandonColony(colonyId: String) {
        guard let colony = colonies[colonyId] else { return }
        if let tileId = colony.tileId,
           var tile = tiles[tileId],
           tile.settlement == colonyId {
            tile.settlement = nil
            tiles[tileId] = tile
        }
        colonies.removeValue(forKey: colonyId)
    }

    /// Resolve a simple local combat outcome for mock-server simulation.
    public func resolveCombat(attackerId: String, targetTileId: String, isRanged: Bool) {
        guard let attacker = units[attackerId],
              let attackerOwner = attacker.owner else {
            return
        }

        if let defender = units.values.first(where: {
            $0.location == targetTileId && $0.owner != nil && $0.owner != attackerOwner
        }) {
            units.removeValue(forKey: defender.id)
        }

        guard !isRanged, var movedAttacker = units[attackerId] else { return }
        movedAttacker.location = targetTileId
        movedAttacker.movesLeft = 0
        units[attackerId] = movedAttacker
    }

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

                // Units and settlements nested inside the tile element
                for tileChild in child.children {
                    switch tileChild.tag {
                    case "unit":
                        try loadUnitTree(tileChild)
                    case "colony", "indianSettlement":
                        let colony = try Colony(id: tileChild.attributes["id"] ?? UUID().uuidString,
                                                attributes: tileChild.attributes,
                                                children: tileChild.children,
                                                game: self)
                        colonies[colony.id] = colony
                        // Register units working inside this colony
                        for colChild in tileChild.children where colChild.tag == "unit" {
                            let unit = try Unit(id: colChild.attributes["id"] ?? UUID().uuidString,
                                                attributes: colChild.attributes,
                                                children: colChild.children,
                                                game: self)
                            units[unit.id] = unit
                        }
                    default:
                        break
                    }
                }
            }
        }
    }

    private func neighboringTileIds(from tileId: String) -> [String] {
        guard let tile = tiles[tileId] else {
            return []
        }

        let deltas: [(Int, Int)] = tile.y.isMultiple(of: 2)
            ? [(0, -2), (0, -1), (1, 0), (0, 1), (0, 2), (-1, 1), (-1, 0), (-1, -1)]
            : [(0, -2), (1, -1), (1, 0), (1, 1), (0, 2), (0, 1), (-1, 0), (0, -1)]

        return deltas.compactMap { dx, dy in
            tiles.values.first(where: { $0.x == tile.x + dx && $0.y == tile.y + dy })?.id
        }
    }

    private func resolvedTileId(for unit: Unit, visited: inout Set<String>) -> String? {
        guard visited.insert(unit.id).inserted else { return nil }
        guard let location = unit.location else { return nil }

        if tiles[location] != nil {
            return location
        }
        if let carrier = units[location] {
            return resolvedTileId(for: carrier, visited: &visited)
        }
        if let colony = colonies[location] {
            return colony.tileId
        }
        return nil
    }

    public func resolvedTileId(for unit: Unit) -> String? {
        var visited: Set<String> = []
        return resolvedTileId(for: unit, visited: &visited)
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

    private func loadUnitTree(_ parsed: ParsedMessage) throws {
        let unit = try Unit(id: parsed.attributes["id"] ?? UUID().uuidString,
                            attributes: parsed.attributes,
                            children: parsed.children,
                            game: self)
        units[unit.id] = unit
        for child in parsed.children where child.tag == "unit" {
            try loadUnitTree(child)
        }
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

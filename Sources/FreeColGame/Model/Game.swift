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
    public internal(set) var regions: [String: GameRegion] = [:]
    public internal(set) var tradeRoutes: [String: TradeRoute] = [:]
    public internal(set) var nationStates: [String: String] = [:]
    public internal(set) var nationColors: [String: String] = [:]
    /// Client-side mirror of the server's authoritative game/map-generator
    /// options, keyed by option id (`updateGameOptions` echo).
    public internal(set) var optionValues: [String: String] = [:]
    /// Known Seven Cities of Gold names (`<cibola>`).
    public internal(set) var cibolaCities: [String] = []

    /// Lazily built (x,y) → tile-id index for cheap neighbour lookups.
    private var coordIndex: [TileCoord: String]?

    private struct TileCoord: Hashable {
        let x: Int
        let y: Int
    }

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
        regions.removeAll()
        tradeRoutes.removeAll()
        nationStates.removeAll()
        nationColors.removeAll()
        optionValues.removeAll()
        cibolaCities.removeAll()
        coordIndex = nil
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
                try loadPlayerTree(child)
            case "unit":
                try loadUnitTree(child)
            case "highSeas":
                for unitChild in child.children where unitChild.tag == "unit" {
                    try loadUnitTree(unitChild)
                }
            case "colony", "indianSettlement":
                try loadSettlementTree(child)
            case "tradeRoute":
                try loadTradeRoute(child)
            case "nationOptions":
                for option in child.children where option.tag == "nationOption" {
                    if let nationId = option.attributes["id"] {
                        nationStates[nationId] = option.attributes["state"]
                    }
                }
            case "cibola":
                if let cityName = child.attributes["id"] {
                    cibolaCities.append(cityName)
                }
            case "areas":
                break // Area groupings are not modelled client-side.
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
                try loadPlayerTree(child)
            case "tile":
                let tile = try Tile(id: child.attributes["id"] ?? UUID().uuidString,
                                    attributes: child.attributes,
                                    children: child.children,
                                    game: self)
                tiles[tile.id] = tile
                coordIndex = nil
                for nestedObject in child.children {
                    switch nestedObject.tag {
                    case "unit":
                        try loadUnitTree(nestedObject)
                    case "colony", "indianSettlement":
                        guard let settlementId = nestedObject.attributes["id"] else { continue }
                        if var existing = colonies[settlementId], nestedObject.children.isEmpty {
                            existing.applyPartial(attributes: nestedObject.attributes)
                            colonies[settlementId] = existing
                        } else {
                            try loadSettlementTree(nestedObject, tileId: tile.id)
                        }
                    case "tileItemContainer":
                        break
                    default:
                        FreeColLogger.shared.debug(
                            "Unhandled <\(nestedObject.tag)> inside tile update \(tile.id)"
                        )
                        continue
                    }
                }
            case "unit":
                try loadUnitTree(child)
            case "highSeas":
                // Ships in transit are serialized as children of the HighSeas location.
                for unitChild in child.children where unitChild.tag == "unit" {
                    try loadUnitTree(unitChild)
                }
            case "europe":
                try applyEuropeUpdate(child)
            case "region":
                guard let regionId = child.attributes["id"] else { continue }
                regions[regionId] = GameRegion(id: regionId, attributes: child.attributes)
            case "colony", "indianSettlement":
                try loadSettlementTree(child)
            case "building", "colonyTile":
                if child.tag == "colonyTile", let id = child.attributes["id"],
                   let colonyId = colonies.values.first(where: { $0.workTiles.contains { $0.id == id } })?.id,
                   var colony = colonies[colonyId],
                   let index = colony.workTiles.firstIndex(where: { $0.id == id }) {
                    colony.workTiles[index].applyUpdate(attributes: child.attributes, children: child.children)
                    colonies[colonyId] = colony
                }
                for unit in child.children where unit.tag == "unit" {
                    try loadUnitTree(unit)
                }
            case "tradeRoute":
                try loadTradeRoute(child)
            case "game":
                try load(from: child)
            case "addPlayer":
                // Change records and nested payloads may carry player additions.
                for playerChild in child.children where playerChild.tag == "player" {
                    let player = try Player(id: playerChild.attributes["id"] ?? UUID().uuidString,
                                            attributes: playerChild.attributes,
                                            children: playerChild.children,
                                            game: self)
                    players[player.id] = player
                }
            case "remove":
                try applyRemove(child)
            case "partial":
                try applyPartial(child)
            case "newTradeRoute", "updateTradeRoute":
                for routeChild in child.children where routeChild.tag == "tradeRoute" {
                    try loadTradeRoute(routeChild)
                }
            case "deleteTradeRoute":
                if let routeId = child.attributes["tradeRoute"] {
                    removeTradeRoute(routeId)
                }
            case "setStance":
                try applySetStance(attributes: child.attributes)
            case "setAI", "setDead", "setNation", "setNationType", "setColor", "setAvailable":
                try applyPlayerChange(tag: child.tag, attributes: child.attributes)
            case "featureChange":
                applyFeatureChange(child)
            case "attribute", "multiple", "update", "error":
                // ChangeSet bookkeeping records with no direct model surface.
                FreeColLogger.shared.debug("Ignoring nested change record <\(child.tag)> in update")
            default:
                FreeColLogger.shared.debug("Unhandled update object <\(child.tag)>")
            }
        }
    }

    /// Apply a top-level `<europe>` update (arrivals, recruits and purchases).
    /// Unit prices are only published with the full player, so keep the known ones.
    private func applyEuropeUpdate(_ parsed: ParsedMessage) throws {
        let europeId = parsed.attributes["id"]
        let ownerId = parsed.attributes["owner"]
        guard let playerId = players.values.first(where: {
            $0.id == ownerId || (europeId != nil && $0.europe?.id == europeId)
        })?.id, var player = players[playerId] else { return }

        var europe = Europe(id: europeId ?? player.europe?.id ?? "\(playerId)-europe",
                            attributes: parsed.attributes,
                            children: parsed.children)
        if europe.unitPrices.isEmpty, let known = player.europe?.unitPrices {
            europe.unitPrices = known
        }
        player.europe = europe
        players[playerId] = player

        for unitChild in parsed.children where unitChild.tag == "unit" {
            try loadUnitTree(unitChild)
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
        } else if var route = tradeRoutes[objectId] {
            route.applyPartial(attributes: attrs)
            tradeRoutes[objectId] = route
        } else if objectId.hasPrefix("tile") {
            if var tile = tiles[objectId] {
                if let type = attrs["type"] { tile.type = type }
                if let owner = attrs["owner"] { tile.owner = owner }
                if let region = attrs["region"] { tile.region = region }
                tiles[objectId] = tile
            }
        }
    }

    /// Apply a `<remove>` message.
    public func applyRemove(_ parsed: ParsedMessage) throws {
        let ids = extractRemoveIds(parsed)
        coordIndex = nil
        for objectId in ids {
            for tileId in Array(tiles.keys) {
                guard var tile = tiles[tileId], tile.lostCityRumourId == objectId else { continue }
                tile.lostCityRumourId = nil
                tile.hasLostCityRumour = false
                tile.lostCityRumourType = nil
                tile.lostCityName = nil
                tiles[tileId] = tile
            }
            players.removeValue(forKey: objectId)
            units.removeValue(forKey: objectId)
            let removedColony = colonies.removeValue(forKey: objectId)
            tradeRoutes.removeValue(forKey: objectId)
            tiles.removeValue(forKey: objectId)

            if removedColony != nil {
                let tileIds = Array(tiles.keys)
                for tileId in tileIds {
                    guard var tile = tiles[tileId], tile.settlement == objectId else { continue }
                    tile.settlement = nil
                    tiles[tileId] = tile
                }
            }

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

    // MARK: - Server-driven player changes

    /// Apply a `<setStance first=".." second=".." stance=".."/>` record to the first player's stance map.
    public func applySetStance(attributes: Attributes) throws {
        guard let firstId = attributes["first"] else { return }
        let stanceValue = attributes["stance"] ?? ""
        let stance = Stance(rawValue: stanceValue)
        if let secondId = attributes["second"] {
            guard var first = players[firstId] else {
                FreeColLogger.shared.debug("setStance for unknown player: \(firstId)")
                return
            }
            if let stance {
                first.stances[secondId] = stance
            } else {
                first.stances.removeValue(forKey: secondId)
            }
            players[firstId] = first
        }
    }

    /// Apply a change-record for tags that map directly onto player fields.
    public func applyPlayerChange(tag: String, attributes: Attributes) throws {
        let playerId = attributes["player"]
        switch tag {
        case "setAI":
            guard let playerId else { return }
            if var player = players[playerId] {
                player.ai = attributes.bool("ai", default: false)
                players[playerId] = player
            }
        case "setDead":
            guard let playerId else { return }
            players.removeValue(forKey: playerId)
            removePlayerOwnedState(playerId)
        case "setNation":
            guard let playerId, let nationId = attributes["value"] else { return }
            if var player = players[playerId] {
                player.nationId = nationId
                players[playerId] = player
            }
        case "setNationType":
            guard let playerId, let nationTypeId = attributes["value"] else { return }
            if var player = players[playerId] {
                player.nationType = nationTypeId
                players[playerId] = player
            }
        case "setColor":
            if let nationId = attributes["nation"] ?? attributes["player"] {
                nationColors[nationId] = attributes["color"]
            }
        case "setAvailable":
            if let nationId = attributes["nation"] ?? attributes["player"] {
                nationStates[nationId] = attributes["state"] ?? attributes["available"]
            }
        default:
            break
        }
    }

    /// Remove carried goods from a unit (local mirror of a dump/unload).
    public func removeUnitGoods(unitId: String, typeId: String, amount: Int) {
        guard let unit = units[unitId] else { return }
        setUnitGoods(unitId: unitId, typeId: typeId,
                     amount: (unit.goods[typeId] ?? 0) - amount)
    }

    /// Set the local mirror of one unit's carried goods amount.
    public func setUnitGoods(unitId: String, typeId: String, amount: Int) {
        guard var unit = units[unitId] else { return }
        let normalizedAmount = max(0, amount)
        if normalizedAmount == 0 {
            unit.goods.removeValue(forKey: typeId)
        } else {
            unit.goods[typeId] = normalizedAmount
        }
        units[unitId] = unit
    }

    /// Set the local mirror of one colony's stored goods amount.
    public func setColonyGoods(colonyId: String, typeId: String, amount: Int) {
        guard var colony = colonies[colonyId] else { return }
        let normalizedAmount = max(0, amount)
        if normalizedAmount == 0 {
            colony.goods.removeValue(forKey: typeId)
        } else {
            colony.goods[typeId] = normalizedAmount
        }
        colonies[colonyId] = colony
    }

    /// Store a locally-updated colony (value type) back into the model.
    public func replaceColony(_ colony: Colony) {
        colonies[colony.id] = colony
    }

    /// Apply a `<featureChange>` record. Abilities and model messages are
    /// tracked on players; other feature kinds are acknowledged but not
    /// modelled (no modifier/history engine client-side).
    public func applyFeatureChange(_ parsed: ParsedMessage) {
        guard let objectId = parsed.attributes["id"] else { return }
        let add = parsed.attributes.bool("add", default: true)
        guard var player = players[objectId] else {
            FreeColLogger.shared.debug("featureChange for unsupported object \(objectId)")
            return
        }
        for child in parsed.children {
            switch child.tag {
            case "ability":
                if let abilityId = child.attributes["id"] {
                    player.abilities[abilityId] = add
                }
            case "modelMessage":
                if add {
                    player.modelMessages.append(ModelMessage(
                        id: child.attributes["id"] ?? "",
                        source: child.attributes["source"],
                        display: child.attributes["display"],
                        messageType: child.attributes["messageType"],
                        hasBeenDisplayed: child.attributes.bool("hasBeenDisplayed", default: false),
                        replacements: ModelMessage.templateReplacements(from: child.children)
                    ))
                }
            default:
                break
            }
        }
        players[objectId] = player
    }

    /// Merge the server's authoritative option echo into the local mirror.
    public func mergeOptions(_ options: [String: String]) {
        for (key, value) in options {
            optionValues[key] = value
        }
    }

    /// Remove a player locally (logout / death / removal broadcast).
    public func removePlayer(_ playerId: String) {
        players.removeValue(forKey: playerId)
        removePlayerOwnedState(playerId)
    }

    private func removePlayerOwnedState(_ playerId: String) {
        for unitId in units.keys where units[unitId]?.owner == playerId {
            units.removeValue(forKey: unitId)
        }
        for routeId in tradeRoutes.keys where tradeRoutes[routeId]?.owner == playerId {
            tradeRoutes.removeValue(forKey: routeId)
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
              unitId != carrierId else {
            return
        }
        let canEmbarkInPlace = unitLoc == carrierLoc
        let canEmbarkFromAdjacentTile = tiles[unitLoc] != nil
            && tiles[carrierLoc] != nil
            && unit.movesLeft > 0
            && neighborTileIds(of: unitLoc).contains(carrierLoc)
        guard canEmbarkInPlace || canEmbarkFromAdjacentTile else { return }
        unit.location = carrierId
        unit.movesLeft = 0
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
        unit.movesLeft = 0
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

    /// True when the server has revealed this tile to the player (Java parity:
    /// explored tiles carry a `type`, unexplored tiles do not).
    public func isExplored(tileId: String) -> Bool {
        tiles[tileId]?.type != nil
    }

    /// All tiles the local player has explored so far.
    public func exploredTileIds() -> Set<String> {
        var explored: Set<String> = []
        explored.reserveCapacity(tiles.count)
        for tile in tiles.values where tile.type != nil {
            explored.insert(tile.id)
        }
        return explored
    }

    /// Line-of-sight radius for a unit (spec `line-of-sight`, name fallback).
    public func sightRadius(for unit: Unit) -> Int {
        max(0, specification?.lineOfSight(forUnitType: unit.unitType)
            ?? Specification.fallbackLineOfSight(forUnitType: unit.unitType))
    }

    /// Return tiles currently visible for a player (Java `Player.getVisibleTileSet`).
    public func visibleTileIds(for playerId: String) -> Set<String> {
        var visible: Set<String> = []

        for unit in units.values where unit.owner == playerId {
            guard let tileId = resolvedTileId(for: unit) else { continue }
            expandVisibility(from: tileId, radius: sightRadius(for: unit), into: &visible)
        }
        for colony in colonies.values where colony.owner == playerId {
            if let tileId = colony.tileId {
                expandVisibility(from: tileId, radius: 1, into: &visible)
            }
        }
        for tile in tiles.values where tile.owner == playerId {
            expandVisibility(from: tile.id, radius: 1, into: &visible)
        }
        return visible
    }

    /// Flood `radius` steps out from a tile into the visible set.
    private func expandVisibility(from source: String, radius: Int, into visible: inout Set<String>) {
        guard radius >= 0 else { return }
        visible.insert(source)
        guard radius > 0 else { return }

        var frontier: Set<String> = [source]
        for _ in 0..<radius {
            var nextFrontier: Set<String> = []
            for tileId in frontier {
                for neighbor in neighboringTileIds(from: tileId) where visible.insert(neighbor).inserted {
                    nextFrontier.insert(neighbor)
                }
            }
            frontier = nextFrontier
            if frontier.isEmpty { break }
        }
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

    // MARK: - Trade routes

    /// Parse and store a `<tradeRoute>` object.
    public func loadTradeRoute(_ parsed: ParsedMessage) throws {
        let route = try TradeRoute(id: parsed.attributes["id"] ?? UUID().uuidString,
                                   attributes: parsed.attributes,
                                   children: parsed.children,
                                   game: self)
        tradeRoutes[route.id] = route
    }

    public func addTradeRoute(_ route: TradeRoute) {
        tradeRoutes[route.id] = route
    }

    public func removeTradeRoute(_ tradeRouteId: String) {
        tradeRoutes.removeValue(forKey: tradeRouteId)
        for unitId in units.keys where units[unitId]?.tradeRoute == tradeRouteId {
            units[unitId]?.tradeRoute = nil
        }
    }

    /// Trade routes owned by a player, sorted by name.
    public func tradeRoutes(forPlayer playerId: String) -> [TradeRoute] {
        tradeRoutes.values
            .filter { $0.owner == playerId }
            .sorted { ($0.name ?? "") < ($1.name ?? "") }
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
        coordIndex = nil
        map = try GameMap(id: parsed.attributes["id"] ?? "map:0",
                           attributes: parsed.attributes,
                           children: parsed.children,
                           game: self)
        for child in parsed.children {
            if child.tag == "region" {
                guard let regionId = child.attributes["id"] else { continue }
                regions[regionId] = GameRegion(id: regionId, attributes: child.attributes)
            } else if child.tag == "tile" {
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
                        try loadSettlementTree(tileChild, tileId: tile.id)
                    default:
                        break
                    }
                }
            }
        }
    }

    /// Build (or reuse) the (x,y) → tile-id index.
    private func tileIndex() -> [TileCoord: String] {
        if let coordIndex { return coordIndex }
        var index: [TileCoord: String] = [:]
        index.reserveCapacity(tiles.count)
        for tile in tiles.values {
            index[TileCoord(x: tile.x, y: tile.y)] = tile.id
        }
        coordIndex = index
        return index
    }

    /// Public accessor for the directly adjacent tile ids (for founding rules etc.).
    public func neighborTileIds(of tileId: String) -> [String] {
        neighboringTileIds(from: tileId)
    }

    private func neighboringTileIds(from tileId: String) -> [String] {
        guard let tile = tiles[tileId] else {
            return []
        }
        let index = tileIndex()

        let deltas: [(Int, Int)] = tile.y.isMultiple(of: 2)
            ? [(0, -2), (0, -1), (1, 0), (0, 1), (0, 2), (-1, 1), (-1, 0), (-1, -1)]
            : [(0, -2), (1, -1), (1, 0), (1, 1), (0, 2), (0, 1), (-1, 0), (0, -1)]

        return deltas.compactMap { dx, dy in
            index[TileCoord(x: tile.x + dx, y: tile.y + dy)]
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
        if let colony = colonies.values.first(where: {
            $0.buildings.contains { $0.id == location } || $0.workTiles.contains { $0.id == location }
        }) {
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
            if key.hasPrefix("array_") {
                ids.append(value)
            }
        }
        let count = parsed.attributes.int("xLength", default: 0)
        for index in 0..<max(count, 0) {
            if let id = parsed.attributes["x\(index)"] {
                ids.append(id)
            }
        }
        return ids
    }

    private func loadSettlementTree(_ parsed: ParsedMessage, tileId: String? = nil) throws {
        let colonyId = parsed.attributes["id"] ?? UUID().uuidString
        var colony = try Colony(id: colonyId, attributes: parsed.attributes,
                                children: parsed.children, game: self)
        if colony.tileId == nil { colony.tileId = tileId ?? colonies[colonyId]?.tileId }
        colonies[colonyId] = colony
        for child in parsed.children {
            if child.tag == "unit" {
                try loadUnitTree(child)
            } else if child.tag == "building" || child.tag == "colonyTile" {
                for unit in child.children where unit.tag == "unit" {
                    try loadUnitTree(unit)
                }
            }
        }
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

    private func loadPlayerTree(_ parsed: ParsedMessage) throws {
        let playerId = parsed.attributes["id"] ?? UUID().uuidString
        let routeIds = Set(parsed.children
            .filter { $0.tag == "tradeRoute" }
            .compactMap { $0.attributes["id"] })
        let removedRouteIds = tradeRoutes.values
            .filter { $0.owner == playerId && !routeIds.contains($0.id) }
            .map(\.id)
        for routeId in removedRouteIds {
            removeTradeRoute(routeId)
        }

        let player = try Player(id: playerId,
                                attributes: parsed.attributes,
                                children: parsed.children,
                                game: self)
        players[player.id] = player
        for child in parsed.children {
            if child.tag == "unit" {
                try loadUnitTree(child)
            } else if child.tag == "europe" || child.tag == "highSeas" {
                for unit in child.children where unit.tag == "unit" {
                    try loadUnitTree(unit)
                }
            }
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

import FreeColClient
import FreeColGame

extension GameState {
    // MARK: - Colony build and goods queries

    /// Build queue of the selected colony, already known to the server.
    var selectedColonyBuildQueue: [String] {
        selectedColony?.buildQueue ?? []
    }

    /// Human-readable building name for a `model.building.*` id.
    func buildingDisplayName(_ typeId: String) -> String {
        if let info = cachedGame?.specification?.buildingTypes[typeId] {
            return info.displayName
        }
        return typeId.split(separator: ".").last.map(String.init) ?? typeId
    }

    /// Human-readable goods name for a `model.goods.*` id.
    func goodsDisplayName(_ typeId: String) -> String {
        if let name = cachedGame?.specification?.goodsTypes[typeId]?.name, !name.isEmpty {
            return name
        }
        return typeId.split(separator: ".").last.map(String.init) ?? typeId
    }

    /// Goods type used for construction progress (FreeCol "building materials").
    nonisolated static let buildingMaterialsGoodsId = "model.goods.hammers"

    /// Stored goods of the selected colony.
    var selectedColonyStoredGoods: [(id: String, label: String, amount: Int)] {
        guard let colony = selectedColony else { return [] }
        return colony.goods
            .map { (id: $0.key, label: goodsDisplayName($0.key), amount: $0.value) }
            .filter { $0.amount > 0 }
            .sorted { $0.label < $1.label }
    }

    /// First item of the selected colony build queue.
    var selectedColonyBuildTarget: (id: String, label: String)? {
        guard let first = selectedColony?.buildQueue.first else { return nil }
        return (id: first, label: buildingDisplayName(first))
    }

    /// Required vs. stored goods for the current build target.
    var selectedColonyBuildRequirements: [(id: String, label: String, required: Int, stored: Int)] {
        guard let colony = selectedColony,
              let target = selectedColonyBuildTarget,
              let info = cachedGame?.specification?.buildingTypes[target.id] else {
            return []
        }
        return info.requiredGoods
            .map { (id: $0.key,
                    label: goodsDisplayName($0.key),
                    required: $0.value,
                    stored: colony.goods[$0.key] ?? 0) }
            .sorted { $0.label < $1.label }
    }

    /// Estimated per-turn output of the construction goods from present buildings.
    var selectedColonyEstimatedBuildPerTurn: Int {
        guard let colony = selectedColony,
              let specification = cachedGame?.specification else {
            return 0
        }
        return Self.estimatedBuildPerTurn(colony: colony,
                                          specification: specification,
                                          centerTileType: centerTileType(of: colony))
    }

    /// Estimated turns until the current build target completes (nil if unknown).
    var selectedColonyEstimatedBuildTurns: Int? {
        guard let target = selectedColonyBuildTarget,
              let colony = selectedColony,
              let specification = cachedGame?.specification else {
            return nil
        }
        return Self.estimatedBuildTurns(colony: colony,
                                        buildableId: target.id,
                                        specification: specification,
                                        centerTileType: centerTileType(of: colony))
    }

    /// Estimate the construction-goods output per turn from present buildings.
    nonisolated static func estimatedBuildPerTurn(colony: Colony,
                                                   specification: Specification,
                                                   centerTileType: String? = nil) -> Int {
        estimatedProduction(colony: colony,
                            specification: specification,
                            centerTileType: centerTileType)
            .first { $0.id == buildingMaterialsGoodsId }?.amount ?? 0
    }

    /// Estimated net per-turn goods output from present buildings plus the
    /// colony-center tile (attended production preferred, unattended fallback).
    nonisolated static func estimatedProduction(colony: Colony,
                                                specification: Specification,
                                                centerTileType: String? = nil) -> [(id: String, amount: Int)] {
        var totals: [String: Int] = [:]
        for building in colony.buildings {
            guard let type = building.buildingType,
                  let info = specification.buildingTypes[type] else { continue }
            for (goods, value) in info.productionOutputs {
                totals[goods, default: 0] += value
            }
            for (goods, value) in info.productionInputs {
                totals[goods, default: 0] -= value
            }
        }
        // The colony center tile is always worked (unattended production).
        if let centerTileType, let tileInfo = specification.tileTypes[centerTileType] {
            for (goods, value) in tileInfo.centerOutputs {
                totals[goods, default: 0] += value
            }
            for (goods, value) in tileInfo.centerInputs {
                totals[goods, default: 0] -= value
            }
        }
        return totals
            .filter { $0.value != 0 }
            .map { (id: $0.key, amount: $0.value) }
    }

    // MARK: - Colony reports and worker selection

    /// Colonies owned by the local player, sorted by name.
    var localColonies: [Colony] {
        guard let game = cachedGame,
              let localPlayerId = resolveLocalPlayerId() else { return [] }
        return game.colonies.values
            .filter { $0.owner == localPlayerId }
            .sorted { ($0.name ?? "") < ($1.name ?? "") }
    }

    /// Workers (units) assigned to a colony, either inside it or on a work location.
    func colonyWorkerUnits(_ colony: Colony) -> [FreeColGame.Unit] {
        guard let game = cachedGame,
              let localPlayerId = resolveLocalPlayerId() else { return [] }
        let workLocationIds = Set(colony.buildings.map(\.id) + colony.workTiles.map(\.id))
        return game.units.values
            .filter { unit in
                guard unit.owner == localPlayerId else { return false }
                if unit.location == colony.id { return true }
                if let location = unit.location, workLocationIds.contains(location) { return true }
                return false
            }
            .sorted { $0.id < $1.id }
    }

    /// Net production estimate for a colony, with display names.
    func colonyProductionSummary(_ colony: Colony) -> [(id: String, label: String, amount: Int)] {
        guard let specification = cachedGame?.specification else { return [] }
        return Self.estimatedProduction(colony: colony,
                                        specification: specification,
                                        centerTileType: centerTileType(of: colony))
            .map { (id: $0.id, label: goodsDisplayName($0.id), amount: $0.amount) }
            .sorted { $0.label < $1.label }
    }

    /// Required vs. stored construction goods for a colony's current build target.
    func colonyBuildRequirements(_ colony: Colony) -> (target: String, items: [(id: String, label: String, required: Int, stored: Int)])? {
        guard let first = colony.buildQueue.first,
              let info = cachedGame?.specification?.buildingTypes[first] else {
            return nil
        }
        let items = info.requiredGoods
            .map { (id: $0.key,
                    label: goodsDisplayName($0.key),
                    required: $0.value,
                    stored: colony.goods[$0.key] ?? 0) }
            .sorted { $0.label < $1.label }
        return (buildingDisplayName(first), items)
    }

    /// Units with an education assignment (student/teacher).
    var educationAssignments: [FreeColGame.Unit] {
        selectableLocalUnits.filter { unit in
            (unit.teacher?.isEmpty == false) || (unit.student?.isEmpty == false)
        }
    }

    /// Units with a missionary role.
    var missionaryUnits: [FreeColGame.Unit] {
        selectableLocalUnits.filter {
            UnitTypeTraits.isMissionary(unitType: $0.unitType, role: $0.role)
        }
    }

    /// Estimated net production of the selected colony, with display names.
    var selectedColonyEstimatedProduction: [(id: String, label: String, amount: Int)] {
        guard let colony = selectedColony,
              let specification = cachedGame?.specification else {
            return []
        }
        return Self.estimatedProduction(colony: colony,
                                        specification: specification,
                                        centerTileType: centerTileType(of: colony))
            .map { (id: $0.id, label: goodsDisplayName($0.id), amount: $0.amount) }
            .sorted { $0.label < $1.label }
    }

    private func centerTileType(of colony: Colony) -> String? {
        guard let tileId = colony.tileId else { return nil }
        return cachedGame?.tiles[tileId]?.type
    }

    /// Estimate the turns to complete a buildable, or nil when unknown.
    nonisolated static func estimatedBuildTurns(colony: Colony,
                                                buildableId: String,
                                                specification: Specification,
                                                centerTileType: String? = nil) -> Int? {
        guard let info = specification.buildingTypes[buildableId],
              !info.requiredGoods.isEmpty else {
            return nil
        }
        let material = buildingMaterialsGoodsId
        guard let required = info.requiredGoods[material] else { return nil }
        let remaining = required - (colony.goods[material] ?? 0)
        guard remaining > 0 else { return 0 }
        let perTurn = estimatedBuildPerTurn(colony: colony,
                                            specification: specification,
                                            centerTileType: centerTileType)
        guard perTurn > 0 else { return nil }
        return (remaining + perTurn - 1) / perTurn
    }

    var selectedColonyWorkerUnitId: String? {
        guard canManageSelectedColony else { return nil }
        if let unit = selectedUnit,
           selectedColonyUnits.contains(where: { $0.id == unit.id }) {
            return unit.id
        }
        return selectedColonyUnits.first?.id
    }

    var canPutSelectedColonyWorkerOutside: Bool {
        guard canManageSelectedColony,
              let colony = selectedColony,
              let colonyId = colony.id as String?,
              let unitId = selectedColonyWorkerUnitId,
              let game = cachedGame,
              let unit = game.units[unitId] else {
            return false
        }
        return unit.location == colonyId
    }

    var canAbandonSelectedColony: Bool {
        guard canManageSelectedColony else { return false }
        return selectedColonyUnits.isEmpty
    }

    var selectedColonyCarrierId: String? {
        guard canManageSelectedColony,
              let game = cachedGame,
              let localPlayerId = resolveLocalPlayerId() else {
            return nil
        }
        if let unit = selectedUnit,
           unit.owner == localPlayerId,
           isLikelyCarrier(unit, in: game) {
            return unit.id
        }
        return selectedColonyUnits.first(where: {
            $0.owner == localPlayerId && isLikelyCarrier($0, in: game)
        })?.id
    }
}

import NovaloriaClient
import FreeColGame
import Foundation

extension GameState {
    func canUnitWorkInColony(_ unit: FreeColGame.Unit) -> Bool {
        guard let type = unit.unitType else { return false }
        if let person = cachedGame?.specification?.effectiveAbility(
            unitTypeId: type, abilityId: "model.ability.person"
        ) { return person }
        let short = type.split(separator: ".").last.map(String.init) ?? type
        return short.lowercased().contains("colonist")
            || short.hasPrefix("expert") || short.hasPrefix("master")
            || ["hardyPioneer", "veteranSoldier", "jesuitMissionary", "firebrandPreacher",
                "elderStatesman", "seasonedScout", "pettyCriminal", "indenturedServant",
                "convertedNative"].contains(short)
    }

    var selectedColonyTerrain: [ColonyTerrainField] {
        guard let game = cachedGame, let colony = selectedColony,
              let tileId = colony.tileId, let center = game.tiles[tileId] else { return [] }
        let origin = MapGeometry.origin(x: center.x, y: center.y, tileW: 1, tileH: 1)
        return ([tileId] + game.neighborTileIds(of: tileId)).compactMap { id in
            guard let tile = game.tiles[id] else { return nil }
            let point = MapGeometry.origin(x: tile.x, y: tile.y, tileW: 1, tileH: 1)
            let location = colony.workTiles.first(where: { $0.tileId == id })
            let reason: String?
            if id == tileId {
                reason = L10n.text("Das Zentrum wird automatisch bewirtschaftet.", table: "GameState_ColonyQueries")
            } else if let location {
                reason = colonyWorkLocationUnavailableReason(location.id)
            } else {
                reason = L10n.text("Für dieses Feld fehlt der Arbeitsplatz in den Serverdaten.", table: "GameState_ColonyQueries")
            }
            let workers = location.map { location in
                selectedColonyUnits.filter { $0.location == location.id }
            } ?? []
            let type = game.specification?.tileTypes[tile.type ?? ""]
            let cachedOutputs = location?.productionOutputs ?? [:]
            let specificationOutputs = type?.workerOutputs ?? [:]
            let outputs = location?.productionOutputs
                ?? (id == tileId ? type?.centerOutputs : type?.workerOutputs) ?? [:]
            // The full worker recipe in the active specification is the
            // authority for selectable jobs; the colony-tile production is
            // only the current production cache.
            let availableOutputs = specificationOutputs.isEmpty
                ? cachedOutputs : specificationOutputs
            let workOptions = id == tileId ? [] : availableOutputs
                .filter { $0.value > 0 }
                .map { ColonyTerrainProduction(goodsType: $0.key, baseAmount: $0.value) }
                .sorted { $0.goodsType < $1.goodsType }
            var production: [ColonyTerrainProduction] = []
            if id == tileId {
                production = outputs.filter { $0.value > 0 }.map {
                    ColonyTerrainProduction(goodsType: $0.key, baseAmount: $0.value)
                }
            } else {
                let workTypes = Set(workers.compactMap(\.workType))
                let goodsTypes = workTypes.isEmpty && !workers.isEmpty
                    ? Set(location?.productionOutputs?.keys.map { $0 } ?? []) : workTypes
                for goods in goodsTypes {
                    let workerCount = workTypes.isEmpty ? workers.count : workers.filter { $0.workType == goods }.count
                    let amount = outputs[goods].map { $0 * workerCount }
                    production.append(ColonyTerrainProduction(goodsType: goods, baseAmount: amount))
                }
            }
            return ColonyTerrainField(
                tile: tile, offset: CGPoint(x: point.x - origin.x, y: point.y - origin.y),
                workLocationId: location?.id,
                workers: workers, unavailableReason: reason,
                production: production.sorted { $0.goodsType < $1.goodsType },
                workOptions: workOptions
            )
        }
    }

    func colonyWorkLocationUnavailableReason(_ locationId: String) -> String? {
        guard let colony = selectedColony, let game = cachedGame else { return L10n.text("Keine Kolonie ausgewählt.", table: "GameState_ColonyQueries") }
        if colony.buildings.contains(where: { $0.id == locationId }) { return nil }
        guard let location = colony.workTiles.first(where: { $0.id == locationId }),
              let tileId = location.tileId, let tile = game.tiles[tileId] else {
            return L10n.text("Dieser Arbeitsplatz ist nicht verfügbar.", table: "GameState_ColonyQueries")
        }
        if tileId == colony.tileId { return L10n.text("Das Zentrum wird automatisch bewirtschaftet.", table: "GameState_ColonyQueries") }
        if tile.type == nil { return L10n.text("Das Gelände ist unbekannt.", table: "GameState_ColonyQueries") }
        if tile.hasLostCityRumour { return L10n.text("Die Ruinen müssen zuerst erkundet werden.", table: "GameState_ColonyQueries") }
        if let owner = tile.owner, owner != colony.owner { return L10n.text("Dieses Land gehört einem anderen Volk.", table: "GameState_ColonyQueries") }
        if let settlement = tile.owningSettlement, settlement != colony.id {
            return L10n.text("Dieses Feld gehört zu einer anderen Siedlung.", table: "GameState_ColonyQueries")
        }
        let isWater = game.specification?.tileTypes[tile.type ?? ""]?.isWater
            ?? ["model.tile.ocean", "model.tile.highSeas", "model.tile.lake", "model.tile.greatRiver"].contains(tile.type ?? "")
        if isWater, !colony.buildings.contains(where: {
            ["model.building.docks", "model.building.drydock", "model.building.shipyard"].contains($0.buildingType ?? "")
        }) {
            return L10n.text("Für Wasserfelder werden Docks benötigt.", table: "GameState_ColonyQueries")
        }
        return nil
    }

    // MARK: - Colony build and goods queries

    /// Build queue of the selected colony, already known to the server.
    var selectedColonyBuildQueue: [String] {
        selectedColony?.buildQueue ?? []
    }

    /// Human-readable building name for a `model.building.*` id.
    func buildingDisplayName(_ typeId: String) -> String {
        if typeId.hasPrefix("model.unit.") {
            return unitDisplayName(typeId)
        }
        return GameLabels.name(typeId, fallback: cachedGame?.specification?.buildingTypes[typeId]?.displayName)
    }

    private func requiredGoods(for buildableId: String) -> [String: Int] {
        guard let specification = cachedGame?.specification else { return [:] }
        return specification.buildingTypes[buildableId]?.requiredGoods
            ?? specification.unitTypes[buildableId]?.requiredGoods
            ?? [:]
    }

    /// Human-readable goods name for a `model.goods.*` id.
    func goodsDisplayName(_ typeId: String) -> String {
        GameLabels.name(typeId, fallback: cachedGame?.specification?.goodsTypes[typeId]?.name)
    }

    /// Goods type used for construction progress (FreeCol "building materials").
    nonisolated static let buildingMaterialsGoodsId = "model.goods.hammers"

    /// Whether goods of this type can be stored in a warehouse and
    /// transported as cargo. Non-storable goods (bells, crosses, hammers)
    /// are production pools and must not show up as freight.
    func isStorableGoodsType(_ typeId: String) -> Bool {
        cachedGame?.specification?.goodsTypes[typeId]?.isStorable ?? true
    }

    /// Stored goods of the selected colony.
    var selectedColonyStoredGoods: [(id: String, label: String, amount: Int)] {
        guard let colony = selectedColony else { return [] }
        return colony.goods
            .filter { $0.value > 0 && isStorableGoodsType($0.key) }
            .map { (id: $0.key, label: goodsDisplayName($0.key), amount: $0.value) }
            .sorted { $0.label < $1.label }
    }

    /// Goods aboard the transporter currently used by the selected colony.
    var selectedColonyCarrierGoods: [(id: String, label: String, amount: Int)] {
        guard let carrierId = selectedColonyCarrierId,
              let carrier = cachedGame?.units[carrierId] else { return [] }
        return carrier.goods
            .filter { $0.value > 0 && isStorableGoodsType($0.key) }
            .map { (id: $0.key, label: goodsDisplayName($0.key), amount: $0.value) }
            .sorted { $0.label < $1.label }
    }

    /// Name and type of the transporter currently used by the selected colony.
    var selectedColonyCarrierDescription: String? {
        guard let carrierId = selectedColonyCarrierId,
              let carrier = cachedGame?.units[carrierId] else { return nil }
        let name = carrier.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = name.flatMap { $0.isEmpty ? nil : $0 } ?? "Unbenannt"
        let type = carrier.unitType.map(unitDisplayName) ?? "Unbekannter Typ"
        return L10n.text("Name: \(displayName) · Typ: \(type)", table: "GameState_ColonyQueries")
    }

    /// Local cargo carriers currently at or inside the selected colony.
    var selectedColonyCarriers: [FreeColGame.Unit] {
        guard canManageSelectedColony,
              let game = cachedGame,
              let localPlayerId = resolveLocalPlayerId() else {
            return []
        }
        return selectedColonyUnits.filter { unit in
            guard unit.owner == localPlayerId else { return false }
            if let type = unit.unitType,
               game.specification?.unitTypes[type] != nil {
                return game.specification?.hasAbility(
                    "model.ability.carryGoods", unitType: type
                ) == true
            }
            return isLikelyCarrier(unit, in: game)
        }.sorted {
            let lhsName = $0.name?.trimmingCharacters(in: .whitespacesAndNewlines)
            let rhsName = $1.name?.trimmingCharacters(in: .whitespacesAndNewlines)
            let lhs = lhsName.flatMap { $0.isEmpty ? nil : $0 }
                ?? $0.unitType.map(unitDisplayName) ?? "Frachter"
            let rhs = rhsName.flatMap { $0.isEmpty ? nil : $0 }
                ?? $1.unitType.map(unitDisplayName) ?? "Frachter"
            let comparison = lhs.localizedStandardCompare(rhs)
            return comparison == .orderedSame ? $0.id < $1.id : comparison == .orderedAscending
        }
    }

    /// Picker options for carriers belonging to the selected colony.
    var selectedColonyCarrierCandidates: [(id: String, label: String)] {
        selectedColonyCarriers.map { carrier in
            let type = carrier.unitType.map(unitDisplayName) ?? "Frachter"
            let name = carrier.name?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (
                id: carrier.id,
                label: name.flatMap { $0.isEmpty ? nil : $0 }.map { "\($0) · \(type)" } ?? type
            )
        }
    }

    /// First item of the selected colony build queue.
    var selectedColonyBuildTarget: (id: String, label: String)? {
        guard let first = selectedColony?.buildQueue.first else { return nil }
        return (id: first, label: buildingDisplayName(first))
    }

    /// Required vs. stored goods for the current build target.
    var selectedColonyBuildRequirements: [(id: String, label: String, required: Int, stored: Int)] {
        guard let colony = selectedColony,
              let target = selectedColonyBuildTarget else {
            return []
        }
        return requiredGoods(for: target.id)
            .map { (id: $0.key,
                    label: goodsDisplayName($0.key),
                    required: $0.value,
                    stored: colony.goods[$0.key] ?? 0) }
            .sorted { $0.label < $1.label }
    }

    /// Estimated gold required to buy the remaining goods for the current
    /// build target, following FreeCol's building-price calculation.
    var selectedColonyBuildPaymentCost: Int? {
        guard let colony = selectedColony,
              let target = selectedColonyBuildTarget,
              let player = localPlayer,
              let specification = cachedGame?.specification else { return nil }
        let requirements = requiredGoods(for: target.id)
        guard !requirements.isEmpty else { return nil }

        var total = 0
        for (goodsId, requiredAmount) in requirements {
            let missing = max(0, requiredAmount - colony.goods[goodsId, default: 0])
            guard missing > 0 else { continue }
            guard let goodsInfo = specification.goodsTypes[goodsId] else { return nil }

            if goodsInfo.isStorable {
                guard let entry = player.market?.entry(for: goodsId) else { return nil }
                let unitPrice = MarketPricing.prices(
                    for: entry,
                    specification: specification
                ).costToBuy
                total += (unitPrice * missing * 110) / 100
            } else {
                total += goodsInfo.price * missing
            }
        }
        return total
    }

    /// Estimated per-turn output of the construction goods from present buildings.
    var selectedColonyEstimatedBuildPerTurn: Int {
        selectedColonyEstimatedProduction
            .first { $0.id == Self.buildingMaterialsGoodsId }?.produced ?? 0
    }

    /// Estimated turns until the current build target completes (nil if unknown).
    var selectedColonyEstimatedBuildTurns: Int? {
        guard let target = selectedColonyBuildTarget,
              let colony = selectedColony,
              let specification = cachedGame?.specification,
              let required = (specification.buildingTypes[target.id]?.requiredGoods
                  ?? specification.unitTypes[target.id]?.requiredGoods)?[Self.buildingMaterialsGoodsId]
        else { return nil }
        let remaining = required - colony.goods[Self.buildingMaterialsGoodsId, default: 0]
        guard remaining > 0 else { return 0 }
        let perTurn = selectedColonyEstimatedBuildPerTurn
        guard perTurn > 0 else { return nil }
        return (remaining + perTurn - 1) / perTurn
    }

    /// Estimate base construction output from currently assigned workers.
    nonisolated static func estimatedBuildPerTurn(colony: Colony,
                                                   specification: Specification,
                                                   centerTileType: String? = nil,
                                                   workers: [FreeColGame.Unit] = [],
                                                   workTileTypes: [String: String] = [:]) -> Int {
        estimatedProduction(colony: colony,
                            specification: specification,
                            centerTileType: centerTileType,
                            workers: workers,
                            workTileTypes: workTileTypes)
            .first { $0.id == buildingMaterialsGoodsId }?.amount ?? 0
    }

    /// Base output per turn from attended worker assignments and unattended
    /// building/colony-center recipes. Omits input consumption and production
    /// modifiers; never treats every building as attended by a worker.
    nonisolated static func estimatedProduction(colony: Colony,
                                                specification: Specification,
                                                centerTileType: String? = nil,
                                                workers: [FreeColGame.Unit] = [],
                                                workTileTypes: [String: String] = [:]) -> [(id: String, amount: Int)] {
        var totals: [String: Int] = [:]

        let centerLocation = colony.workTiles.first { $0.tileId == colony.tileId }
        let centerOutputs = centerLocation?.productionOutputs
            ?? centerTileType.flatMap { specification.tileTypes[$0]?.centerOutputs }
            ?? [:]
        for (goods, amount) in centerOutputs where amount > 0 {
            totals[goods, default: 0] += amount
        }

        for building in colony.buildings {
            guard let type = building.buildingType,
                  let info = specification.buildingTypes[type] else { continue }
            let assignedWorkers = workers.filter { $0.location == building.id }
            if assignedWorkers.isEmpty {
                let outputs = info.unattendedProductionOutputs
                let inputsAvailable = info.unattendedProductionInputs.allSatisfy { goods, amount in
                    (colony.goods[goods] ?? 0) >= amount
                }
                guard inputsAvailable else { continue }
                for (goods, amount) in outputs where amount > 0 {
                    totals[goods, default: 0] += amount
                }
            } else {
                let inputsAvailable = info.attendedProductionInputs.allSatisfy { goods, amount in
                    (colony.goods[goods] ?? 0) >= amount * assignedWorkers.count
                }
                guard inputsAvailable else { continue }
                addAssignedOutputs(info.attendedProductionOutputs,
                                   workers: assignedWorkers,
                                   to: &totals)
            }
        }

        for location in colony.workTiles where location.tileId != colony.tileId {
            let assignedWorkers = workers.filter { $0.location == location.id }
            guard !assignedWorkers.isEmpty else { continue }
            let tileType = workTileTypes[location.id]
            let outputs = location.productionOutputs
                ?? tileType.flatMap { specification.tileTypes[$0]?.workerOutputs }
                ?? [:]
            addAssignedOutputs(outputs, workers: assignedWorkers, to: &totals)
        }

        return totals
            .filter { $0.value > 0 }
            .map { (id: $0.key, amount: $0.value) }
            .sorted { $0.id < $1.id }
    }

    private nonisolated static func addAssignedOutputs(
        _ outputs: [String: Int],
        workers: [FreeColGame.Unit],
        to totals: inout [String: Int]
    ) {
        let outputs = outputs.filter { $0.value > 0 }
        for worker in workers {
            let goodsType: String?
            if let workType = worker.workType, outputs[workType] != nil {
                goodsType = workType
            } else if worker.workType == nil, outputs.count == 1 {
                goodsType = outputs.keys.first
            } else {
                goodsType = nil
            }
            if let goodsType, let amount = outputs[goodsType] {
                totals[goodsType, default: 0] += amount
            }
        }
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

    func colonyPopulation(_ colony: Colony) -> Int {
        max(colony.unitCount, colonyWorkerUnits(colony).count)
    }

    /// Final per-turn production and consumption based on active assignments.
    func colonyProductionSummary(_ colony: Colony) -> [ColonyGoodsFlow] {
        guard let game = cachedGame, let specification = game.specification else { return [] }
        let player = colony.owner.flatMap { game.players[$0] }
        return ColonyProductionCalculator.calculate(
            colony: colony,
            specification: specification,
            tiles: game.tiles,
            workers: colonyWorkerUnits(colony),
            player: player,
            goodsLabel: goodsDisplayName
        )
    }

    /// Required vs. stored construction goods for a colony's current build target.
    func colonyBuildRequirements(_ colony: Colony) -> (target: String, items: [(id: String, label: String, required: Int, stored: Int)])? {
        guard let first = colony.buildQueue.first else {
            return nil
        }
        let items = requiredGoods(for: first)
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

    /// Final output and consumption from the selected colony's current jobs.
    var selectedColonyEstimatedProduction: [ColonyGoodsFlow] {
        guard let colony = selectedColony else { return [] }
        return colonyProductionSummary(colony)
    }

    var selectedColonyEstimatedGrowthTurns: Int? {
        guard let colony = selectedColony,
              let specification = cachedGame?.specification else { return nil }
        return ColonyProductionCalculator.estimatedGrowthTurns(
            foodStock: colony.goods["model.goods.food"] ?? 0,
            specification: specification,
            flows: colonyProductionSummary(colony)
        )
    }

    var selectedColonyFoodGoodsIds: Set<String> {
        guard let specification = cachedGame?.specification else {
            return ["model.goods.food", "model.goods.grain", "model.goods.fish"]
        }
        return Set(specification.goodsTypes.values.filter(\.isFood).map(\.id))
    }

    private func centerTileType(of colony: Colony) -> String? {
        guard let tileId = colony.tileId else { return nil }
        return cachedGame?.tiles[tileId]?.type
    }

    private func workTileTypes(for colony: Colony) -> [String: String] {
        var result: [String: String] = [:]
        for location in colony.workTiles {
            guard let tileId = location.tileId,
                  let type = cachedGame?.tiles[tileId]?.type else { continue }
            result[location.id] = type
        }
        return result
    }

    /// Estimate the turns to complete a buildable, or nil when unknown.
    nonisolated static func estimatedBuildTurns(colony: Colony,
                                                buildableId: String,
                                                specification: Specification,
                                                centerTileType: String? = nil,
                                                workers: [FreeColGame.Unit] = [],
                                                workTileTypes: [String: String] = [:]) -> Int? {
        let requiredGoods = specification.buildingTypes[buildableId]?.requiredGoods
            ?? specification.unitTypes[buildableId]?.requiredGoods
            ?? [:]
        guard !requiredGoods.isEmpty else {
            return nil
        }
        let material = buildingMaterialsGoodsId
        guard let required = requiredGoods[material] else { return nil }
        let remaining = required - (colony.goods[material] ?? 0)
        guard remaining > 0 else { return 0 }
        let perTurn = estimatedBuildPerTurn(colony: colony,
                                            specification: specification,
                                            centerTileType: centerTileType,
                                            workers: workers,
                                            workTileTypes: workTileTypes)
        guard perTurn > 0 else { return nil }
        return (remaining + perTurn - 1) / perTurn
    }

    var selectedColonyWorkerUnitId: String? {
        guard canManageSelectedColony else { return nil }
        if let unit = selectedUnit,
           canUnitWorkInColony(unit),
           selectedColonyUnits.contains(where: { $0.id == unit.id }) {
            return unit.id
        }
        return selectedColonyUnits.first(where: { canUnitWorkInColony($0) })?.id
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
        let carriers = selectedColonyCarriers
        if let selectedUnit, carriers.contains(where: { $0.id == selectedUnit.id }) {
            return selectedUnit.id
        }
        return carriers.first?.id
    }
}

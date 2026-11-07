import Foundation
import FreeColGame

struct ColonyGoodsFlow: Identifiable {
    var id: String
    var label: String
    var produced: Int
    var consumed: Int
    var explanation: String
}

/// Client-side projection of FreeCol's work-location production pipeline.
/// It applies the production modifiers available in the live model and game
/// specification, then limits building recipes by available inputs.
enum ColonyProductionCalculator {
    private struct AppliedModifier {
        var value: ProductionModifierInfo
        var source: String
        var competenceFactor: Double = 1
        var resourceQuantity: Int?
    }

    private struct BuildingPlan {
        var name: String
        var inputs: [String: Int]
        var inputDetails: [String: [String]]
        var outputs: [String: Int]
        var outputDetails: [String: [String]]
    }

    static func calculate(colony: Colony,
                          specification: Specification,
                          tiles: [String: Tile],
                          workers: [FreeColGame.Unit],
                          player: Player?,
                          goodsLabel: (String) -> String) -> [ColonyGoodsFlow] {
        var production: [String: Int] = [:]
        var consumption: [String: Int] = [:]
        var details: [String: [String]] = [:]
        var available = colony.goods

        func addProduction(_ goods: String, amount: Int, explanation: String) {
            guard amount > 0 else { return }
            production[goods, default: 0] += amount
            available[goods, default: 0] += amount
            details[goods, default: []].append(explanation)
        }

        func addConsumption(_ goods: String, amount: Int, explanation: String) {
            guard amount > 0 else { return }
            consumption[goods, default: 0] += amount
            available[goods, default: 0] = max(0, available[goods, default: 0] - amount)
            details[goods, default: []].append(explanation)
        }

        // Colony center production is unattended, but still uses the actual
        // tile, its resource/improvements, and the colony-wide bonus.
        if let centerTileId = colony.tileId,
           let centerTile = tiles[centerTileId],
           let tileTypeId = centerTile.type,
           let tileInfo = specification.tileTypes[tileTypeId] {
            let outputs = colony.workTiles.first(where: { $0.tileId == centerTileId })?.productionOutputs
                ?? tileInfo.centerOutputs
            for (goods, base) in outputs where base > 0 {
                var modifiers = tileModifiers(tile: centerTile,
                                              tileTypeId: tileTypeId,
                                              specification: specification)
                if colony.productionBonus > 0 {
                    modifiers.append(AppliedModifier(
                        value: .init(goodsType: goods, kind: .additive,
                                     value: Double(colony.productionBonus), index: 35),
                        source: "Koloniebonus"
                    ))
                }
                let result = apply(base: base, goods: goods, unitTypeId: nil,
                                   tileTypeId: tileTypeId, contextType: nil,
                                   modifiers: modifiers, specification: specification)
                addProduction(goods, amount: result.amount,
                              explanation: "Koloniezentrum: \(result.explanation)")
            }
        }

        // Assigned field workers: selected tile recipe + terrain, resource,
        // improvement, expert, nation, father, and colony modifiers.
        for location in colony.workTiles where location.tileId != colony.tileId {
            guard let tileId = location.tileId,
                  let tile = tiles[tileId],
                  let tileTypeId = tile.type,
                  let tileInfo = specification.tileTypes[tileTypeId] else { continue }
            let assigned = workers.filter { $0.location == location.id }
            let outputs = location.productionOutputs ?? tileInfo.workerOutputs
            for worker in assigned {
                let goods = selectedGoods(for: worker, outputs: outputs)
                guard let goods, let base = outputs[goods], base > 0 else { continue }
                let modifiers = tileModifiers(tile: tile,
                                              tileTypeId: tileTypeId,
                                              specification: specification)
                    + unitModifiers(goods: goods, worker: worker,
                                    specification: specification, player: player)
                    + colonyTileBonus(goods: goods, colony: colony,
                                     worker: worker, tile: tile,
                                     specification: specification)
                let result = apply(base: base, goods: goods,
                                   unitTypeId: worker.unitType,
                                   tileTypeId: tileTypeId, contextType: nil,
                                   modifiers: modifiers, specification: specification)
                addProduction(goods, amount: result.amount,
                              explanation: "Feldarbeit (\(workerName(worker, specification: specification))): \(result.explanation)")
            }
        }

        // Buildings add their unattended recipe and each assigned worker's
        // attended recipe. Inputs are limited by stored goods and output from
        // earlier work locations, as in the server's production cache.
        var buildingPlans: [BuildingPlan] = []
        for building in colony.buildings {
            guard let buildingTypeId = building.buildingType,
                  specification.buildingTypes[buildingTypeId] != nil else { continue }
            let attendedOutputs = specification.buildingOutputs(for: buildingTypeId, unattended: false)
            let attendedInputs = specification.buildingInputs(for: buildingTypeId, unattended: false)
            let unattendedOutputs = specification.buildingOutputs(for: buildingTypeId, unattended: true)
            let unattendedInputs = specification.buildingInputs(for: buildingTypeId, unattended: true)
            let assigned = workers.filter { $0.location == building.id }
            var plan = BuildingPlan(name: GameLabels.name(buildingTypeId),
                                    inputs: [:], inputDetails: [:],
                                    outputs: [:], outputDetails: [:])

            for worker in assigned {
                guard let goods = selectedGoods(for: worker, outputs: attendedOutputs),
                      let base = attendedOutputs[goods], base > 0 else { continue }
                let modifiers = buildingModifiers(goods: goods, buildingTypeId: buildingTypeId,
                                                  worker: worker, colony: colony,
                                                  specification: specification, player: player)
                let result = apply(base: base, goods: goods,
                                   unitTypeId: worker.unitType, tileTypeId: nil,
                                   contextType: buildingTypeId, modifiers: modifiers,
                                   specification: specification)
                plan.outputs[goods, default: 0] += result.amount
                plan.outputDetails[goods, default: []].append(
                    "\(workerName(worker, specification: specification)): \(result.explanation)"
                )
                for (input, amount) in attendedInputs where amount > 0 {
                    plan.inputs[input, default: 0] += amount
                    plan.inputDetails[input, default: []].append(
                        "\(workerName(worker, specification: specification)): \(amount)"
                    )
                }
            }

            for (goods, base) in unattendedOutputs where base > 0 {
                let modifiers = buildingModifiers(goods: goods, buildingTypeId: buildingTypeId,
                                                  worker: nil, colony: colony,
                                                  specification: specification, player: player)
                let result = apply(base: base, goods: goods, unitTypeId: nil,
                                   tileTypeId: nil, contextType: buildingTypeId,
                                   modifiers: modifiers, specification: specification)
                plan.outputs[goods, default: 0] += result.amount
                plan.outputDetails[goods, default: []].append(
                    "Ohne Arbeiter: \(result.explanation)"
                )
                for (input, amount) in unattendedInputs where amount > 0 {
                    plan.inputs[input, default: 0] += amount
                    plan.inputDetails[input, default: []].append("Unbeaufsichtigt: \(amount)")
                }
            }
            if !plan.outputs.isEmpty || !plan.inputs.isEmpty { buildingPlans.append(plan) }
        }

        for plan in buildingPlans {
            let ratio = plan.inputs.reduce(1.0) { partial, pair in
                guard pair.value > 0 else { return partial }
                return min(partial, Double(available[pair.key, default: 0]) / Double(pair.value))
            }
            let boundedRatio = max(0, min(1, ratio))
            for (goods, amount) in plan.inputs {
                let actual = Int(floor(Double(amount) * boundedRatio))
                let stock = available[goods, default: 0]
                if actual > 0 {
                    consumption[goods, default: 0] += actual
                    available[goods, default: 0] = max(0, stock - actual)
                }
                details[goods, default: []].append(
                    "\(plan.name): Bedarf \(plan.inputDetails[goods, default: []].joined(separator: " + ")) = \(amount) \(goodsLabel(goods)); Vorrat \(stock), Verbrauch \(actual)\(boundedRatio < 1 ? " (durch Vorrat begrenzt)" : "")"
                )
            }
            for (goods, amount) in plan.outputs {
                let actual = Int(floor(Double(amount) * boundedRatio))
                let breakdown = plan.outputDetails[goods, default: []].joined(separator: "; ")
                let explanation = "\(plan.name): \(breakdown)\(boundedRatio < 1 ? "; wegen fehlender Inputs auf \(Int((boundedRatio * 100).rounded())) % begrenzt" : "")"
                if actual > 0 {
                    addProduction(goods, amount: actual, explanation: explanation)
                } else if amount > 0 {
                    details[goods, default: []].append(explanation)
                }
            }
        }

        // Unit-level recurring consumption (food, bells, etc.). Resolve
        // inherited consume declarations before charging each colony unit.
        for worker in workers {
            guard let unitType = worker.unitType else { continue }
            for (goods, amount) in specification.consumes(forUnitType: unitType) where amount > 0 {
                addConsumption(goods, amount: amount,
                               explanation: "\(workerName(worker, specification: specification)): \(amount) \(goodsLabel(goods))")
            }
        }

        let goodsIds = Set(production.keys).union(consumption.keys).union(details.keys)
        return goodsIds.map { goods in
            let produced = production[goods, default: 0]
            let consumed = consumption[goods, default: 0]
            let lines = details[goods, default: []]
        let tooltip = (["Produktion: +\(produced) \(goodsLabel(goods))"]
                + lines
                + ["Verbrauch: −\(consumed) \(goodsLabel(goods))"])
                .joined(separator: "\n")
            return ColonyGoodsFlow(id: goods, label: goodsLabel(goods),
                                   produced: produced, consumed: consumed,
                                   explanation: tooltip)
        }.sorted { $0.label < $1.label }
    }

    private static func tileModifiers(tile: Tile,
                                      tileTypeId: String,
                                      specification: Specification) -> [AppliedModifier] {
        var result = specification.tileTypes[tileTypeId]?.productionModifiers.map {
            AppliedModifier(value: $0, source: "Geländebonus")
        } ?? []
        for resource in tile.resources {
            guard let resourceType = resource.type else { continue }
            result += (specification.resourceTypes[resourceType]?.productionModifiers ?? []).map {
                AppliedModifier(value: $0,
                                source: "Ressource \(GameLabels.name(resourceType))",
                                resourceQuantity: resource.quantity)
            }
        }
        for improvement in tile.improvements {
            guard let type = improvement.type else { continue }
            result += (specification.improvementTypes[type]?.productionModifiers ?? []).map {
                var modifier = $0
                modifier.value *= Double(max(0, improvement.magnitude))
                return AppliedModifier(value: modifier, source: GameLabels.name(type))
            }
        }
        return result
    }

    private static func unitModifiers(goods: String,
                                      worker: FreeColGame.Unit,
                                      specification: Specification,
                                      player: Player?) -> [AppliedModifier] {
        var result = specification.productionModifiers(forUnitType: worker.unitType ?? "")
            .map { AppliedModifier(value: $0, source: workerName(worker, specification: specification)) }
        if let role = worker.role {
            result += (specification.roleTypes[role]?.productionModifiers ?? []).map {
                AppliedModifier(value: $0, source: GameLabels.name(role))
            }
        }
        result += playerModifiers(player: player, specification: specification)
        return result
    }

    private static func buildingModifiers(goods: String,
                                          buildingTypeId: String,
                                          worker: FreeColGame.Unit?,
                                          colony: Colony,
                                          specification: Specification,
                                          player: Player?) -> [AppliedModifier] {
        let building = specification.buildingTypes[buildingTypeId]
        var result = specification.productionModifiers(forBuildingType: buildingTypeId)
            .map { AppliedModifier(value: $0, source: GameLabels.name(buildingTypeId)) }
        if let worker {
            result += specification.productionModifiers(forUnitType: worker.unitType ?? "")
                .map { AppliedModifier(value: $0,
                                       source: workerName(worker, specification: specification),
                                       competenceFactor: building?.competenceFactor ?? 1) }
            if let role = worker.role {
                result += (specification.roleTypes[role]?.productionModifiers ?? []).map {
                    AppliedModifier(value: $0, source: GameLabels.name(role))
                }
            }
            let rebelBonus = Int(floor(Double(colony.productionBonus) * (building?.rebelFactor ?? 1)))
            if rebelBonus != 0 {
                result.append(AppliedModifier(
                    value: .init(goodsType: goods, kind: .additive,
                                 value: Double(rebelBonus), index: 20),
                    source: "Koloniebonus"
                ))
            }
        } else if colony.productionBonus != 0 {
            result.append(AppliedModifier(
                value: .init(goodsType: goods, kind: .additive,
                             value: Double(Int(floor(Double(colony.productionBonus)
                                                    * (building?.rebelFactor ?? 1)))), index: 20),
                source: "Koloniebonus"
            ))
        }
        result += playerModifiers(player: player, specification: specification)
        return result
    }

    private static func colonyTileBonus(goods: String,
                                        colony: Colony,
                                        worker: FreeColGame.Unit,
                                        tile: Tile,
                                        specification: Specification) -> [AppliedModifier] {
        guard colony.productionBonus != 0 else { return [] }
        var factor = specification.expertProduction(forUnitType: worker.unitType) == goods ? 2.0 : 1.0
        let resourceMultipliers = tile.resources.flatMap { resource in
            guard let type = resource.type else { return [ProductionModifierInfo]() }
            return specification.resourceTypes[type]?.productionModifiers ?? []
        }.filter { $0.goodsType == goods && $0.kind == .multiplicative }
        for modifier in resourceMultipliers { factor *= modifier.value }
        let bonus = max(colony.productionBonus, Int(floor(Double(colony.productionBonus) * factor)))
        return [AppliedModifier(value: .init(goodsType: goods, kind: .additive,
                                             value: Double(bonus), index: 35),
                                source: "Koloniebonus")]
    }

    private static func playerModifiers(player: Player?,
                                        specification: Specification) -> [AppliedModifier] {
        guard let player else { return [] }
        var result: [AppliedModifier] = []
        if let nationType = player.nationType {
            result += (specification.nationTypeModifiers[nationType] ?? []).map {
                AppliedModifier(value: $0, source: "Nationale Eigenschaft")
            }
        }
        for father in player.foundingFathers {
            result += (specification.foundingFatherModifiers[father] ?? []).map {
                AppliedModifier(value: $0, source: "Gründervater \(GameLabels.name(father))")
            }
        }
        return result
    }

    private static func apply(base: Int,
                              goods: String,
                              unitTypeId: String?,
                              tileTypeId: String?,
                              contextType: String?,
                              modifiers: [AppliedModifier],
                              specification: Specification) -> (amount: Int, explanation: String) {
        let unitAbilities = unitTypeId.map { specification.effectiveAbilities(forUnitType: $0) } ?? []
        var value = Double(base)
        var lines = ["Grundwert: \(base)"]
        let applicable = modifiers
            .filter({ !$0.value.isDelete && modifierApplies($0.value, goods: goods,
                                      unitTypeId: unitTypeId,
                                      tileTypeId: tileTypeId,
                                      contextType: contextType,
                                      specification: specification,
                                      unitAbilities: unitAbilities) })
            .sorted(by: { $0.value.index < $1.value.index })
        var offset = 0
        while offset < applicable.count {
            let source = applicable[offset].source
            var end = offset + 1
            while end < applicable.count && applicable[end].source == source {
                end += 1
            }
            let group = applicable[offset..<end]
            let beforeGroup = value
            for applied in group {
                let modifier = applied.value
                let effectiveValue = modifier.kind == .additive
                    ? modifier.value * applied.competenceFactor : modifier.value
                let oldValue = value
                switch modifier.kind {
                case .additive: value += effectiveValue
                case .multiplicative: value *= effectiveValue
                case .percentage: value += value * effectiveValue / 100
                }
                if value != oldValue {
                    lines.append("\(applied.source): \(format(oldValue)) → \(format(value))")
                }
            }
            if let quantity = group.compactMap(\.resourceQuantity).first, quantity >= 0 {
                let gained = max(0, value - beforeGroup)
                let capped = min(Double(quantity), gained)
                if capped < gained {
                    value = beforeGroup + capped
                    lines.append("Ressourcenmenge begrenzt Bonus auf \(format(capped))")
                }
            }
            offset = end
        }
        let amount = max(0, Int(floor(value)))
        if Double(amount) != value { lines.append("Abgerundet: \(amount)") }
        return (amount, lines.joined(separator: "; "))
    }

    private static func modifierApplies(_ modifier: ProductionModifierInfo,
                                        goods: String,
                                        unitTypeId: String?,
                                        tileTypeId: String?,
                                        contextType: String?,
                                        specification: Specification,
                                        unitAbilities: Set<String>) -> Bool {
        guard modifier.goodsType == goods else { return false }
        var candidates: Set<String> = [goods]
        if let unitTypeId { candidates.formUnion(specification.unitTypeHierarchy(for: unitTypeId)) }
        if let contextType {
            candidates.formUnion(specification.buildingTypeHierarchy(for: contextType))
        }
        if let tileTypeId { candidates.insert(tileTypeId) }
        if !modifier.scopeTypes.isEmpty && modifier.scopeTypes.allSatisfy({ !candidates.contains($0) }) {
            return false
        }
        if modifier.negatedScopeTypes.contains(where: { candidates.contains($0) }) { return false }
        if !modifier.scopeAbilities.isEmpty
            && modifier.scopeAbilities.allSatisfy({ !unitAbilities.contains($0) }) {
            return false
        }
        if modifier.negatedScopeAbilities.contains(where: { unitAbilities.contains($0) }) { return false }
        return true
    }

    private static func selectedGoods(for worker: FreeColGame.Unit,
                                      outputs: [String: Int]) -> String? {
        if let workType = worker.workType, outputs[workType] != nil { return workType }
        if worker.workType == nil, outputs.count == 1 { return outputs.keys.first }
        return nil
    }

    private static func workerName(_ worker: FreeColGame.Unit,
                                   specification: Specification) -> String {
        worker.unitType.map { GameLabels.name($0) } ?? "Arbeiter"
    }

    private static func format(_ value: Double) -> String {
        value.rounded() == value ? "\(Int(value))" : String(format: "%.1f", value)
    }
}

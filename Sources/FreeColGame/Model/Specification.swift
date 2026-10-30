import Foundation
import FreeColProtocol

/// Parsed subset of a `<unit-type>` definition from the server specification.
public struct UnitTypeInfo: @unchecked Sendable {
    public var id: String
    public var lineOfSight: Int
    public var isNaval: Bool
    public var carriesUnits: Bool
    public var offence: Int
    public var defence: Int
    public var movement: Int
    /// Cargo slots this unit type can carry (`space` in the Java specification).
    public var cargoSpace: Int?
    /// Cargo slots this unit occupies when carried (`spaceTaken` in the Java specification).
    public var spaceTaken: Int?
    /// Parent type id from `extends`, used for ability/attribute inheritance.
    public var extendsId: String?
    /// Directly declared abilities (`<ability id= value=>`), before inheritance.
    public var abilities: [String: Bool]
    /// Europe purchase/training price (`price`), inherited through `extends`; nil if not for sale.
    public var price: Int?
    /// Skill level (`skill`), inherited through `extends`; Java trains units with skill > 0 in Europe.
    public var skill: Int?

    public init(id: String,
                lineOfSight: Int,
                isNaval: Bool,
                carriesUnits: Bool = false,
                offence: Int,
                defence: Int,
                movement: Int,
                cargoSpace: Int? = nil,
                spaceTaken: Int? = nil,
                extendsId: String? = nil,
                abilities: [String: Bool] = [:],
                price: Int? = nil,
                skill: Int? = nil) {
        self.id = id
        self.lineOfSight = lineOfSight
        self.isNaval = isNaval
        self.carriesUnits = carriesUnits
        self.offence = offence
        self.defence = defence
        self.movement = movement
        self.cargoSpace = cargoSpace
        self.spaceTaken = spaceTaken
        self.extendsId = extendsId
        self.abilities = abilities
        self.price = price
        self.skill = skill
    }

    /// FreeCol reserves at least one slot beyond a unit's own cargo capacity
    /// when it is carried by another unit.
    public var spaceTakenOnCarrier: Int {
        max(spaceTaken ?? 1, (cargoSpace ?? 0) + 1)
    }

    public var displayName: String {
        let tail = id.split(separator: ".").last.map(String.init) ?? id
        guard let first = tail.first else { return id }
        return first.uppercased() + tail.dropFirst()
    }
}

/// Parsed subset of a `<goods-type>` definition from the server specification.
public struct GoodsTypeInfo: @unchecked Sendable {
    public var id: String
    public var name: String?
    public var isFood: Bool
    public var isBuildingMaterial: Bool
    public var isTradeGoods: Bool
    /// Whether goods of this type can be stored/traded (`storable`, default true).
    public var isStorable: Bool
    /// New-world goods participate in the market price clamp work-around.
    public var isNewWorldGoods: Bool
    /// Market reference amount from the `<market>` child.
    public var marketInitialAmount: Int
    /// Market reference price from the `<market>` child.
    public var marketInitialPrice: Int
    /// Buy/sell spread from the `<market>` child.
    public var priceDifference: Int
    /// Goods type this one is refined from (`made-from`), used by the price work-around.
    public var madeFrom: String?

    public init(id: String,
                name: String?,
                isFood: Bool,
                isBuildingMaterial: Bool,
                isTradeGoods: Bool,
                isStorable: Bool = true,
                isNewWorldGoods: Bool = false,
                marketInitialAmount: Int = 0,
                marketInitialPrice: Int = 1,
                priceDifference: Int = 1,
                madeFrom: String? = nil) {
        self.id = id
        self.name = name
        self.isFood = isFood
        self.isBuildingMaterial = isBuildingMaterial
        self.isTradeGoods = isTradeGoods
        self.isStorable = isStorable
        self.isNewWorldGoods = isNewWorldGoods
        self.marketInitialAmount = marketInitialAmount
        self.marketInitialPrice = marketInitialPrice
        self.priceDifference = priceDifference
        self.madeFrom = madeFrom
    }
}

/// Parsed subset of a `<tile-improvement-type>` definition (pioneer work).
public struct ImprovementTypeInfo: @unchecked Sendable {
    public var id: String
    /// Role required to make the improvement (`model.role.pioneer`), if any.
    public var requiredRole: String?
    /// Extra work turns added to the tile type cost.
    public var addWorkTurns: Int
    /// Natural improvements (e.g. rivers) cannot be built by pioneers.
    public var isNatural: Bool

    public init(id: String,
                requiredRole: String?,
                addWorkTurns: Int,
                isNatural: Bool) {
        self.id = id
        self.requiredRole = requiredRole
        self.addWorkTurns = addWorkTurns
        self.isNatural = isNatural
    }

    public var displayName: String {
        id.split(separator: ".").last.map(String.init) ?? id
    }
}

/// Parsed subset of a `<building-type>` definition from the server specification.
public struct BuildingTypeInfo: @unchecked Sendable {
    public var id: String
    public var upkeep: Int
    public var requiredPopulation: Int
    public var upgradesFrom: String?
    public var extendsId: String?
    /// Goods required to construct this building, keyed by goods type id.
    public var requiredGoods: [String: Int]
    /// Summed production outputs across `<production>` blocks, keyed by goods type id.
    public var productionOutputs: [String: Int]
    /// Summed production inputs across `<production>` blocks, keyed by goods type id.
    public var productionInputs: [String: Int]

    public init(id: String,
                upkeep: Int,
                requiredPopulation: Int,
                upgradesFrom: String?,
                extendsId: String?,
                requiredGoods: [String: Int] = [:],
                productionOutputs: [String: Int] = [:],
                productionInputs: [String: Int] = [:]) {
        self.id = id
        self.upkeep = upkeep
        self.requiredPopulation = requiredPopulation
        self.upgradesFrom = upgradesFrom
        self.extendsId = extendsId
        self.requiredGoods = requiredGoods
        self.productionOutputs = productionOutputs
        self.productionInputs = productionInputs
    }

    /// Display name derived from the id (`model.building.townHall` → `townHall`).
    public var displayName: String {
        let tail = id.split(separator: ".").last.map(String.init) ?? id
        guard let first = tail.first else { return id }
        return first.uppercased() + tail.dropFirst()
    }
}

/// Parsed subset of a `<tile-type>` definition: the unattended production
/// used by a colony center on that terrain.
public struct TileTypeInfo: @unchecked Sendable {
    public var id: String
    public var isWater: Bool
    public var canSettle: Bool
    public var centerOutputs: [String: Int]
    public var centerInputs: [String: Int]

    public init(id: String,
                isWater: Bool = false,
                canSettle: Bool = true,
                centerOutputs: [String: Int] = [:],
                centerInputs: [String: Int] = [:]) {
        self.id = id
        self.isWater = isWater
        self.canSettle = canSettle
        self.centerOutputs = centerOutputs
        self.centerInputs = centerInputs
    }
}

public final class Specification: @unchecked Sendable {
    public var id: String?
    public var difficultyLevel: String?
    public var version: String?

    /// Unit type definitions keyed by id (`model.unit.*`).
    public private(set) var unitTypes: [String: UnitTypeInfo] = [:]
    /// Goods type definitions keyed by id (`model.goods.*`).
    public private(set) var goodsTypes: [String: GoodsTypeInfo] = [:]
    /// Building type definitions keyed by id (`model.building.*`).
    public private(set) var buildingTypes: [String: BuildingTypeInfo] = [:]
    /// Tile type definitions keyed by id (`model.tile.*`).
    public private(set) var tileTypes: [String: TileTypeInfo] = [:]
    /// Pioneer improvement definitions keyed by id (`model.improvement.*`).
    public private(set) var improvementTypes: [String: ImprovementTypeInfo] = [:]

    public init(parsed: ParsedMessage) {
        id = parsed.attributes["id"]
        difficultyLevel = parsed.attributes["difficulty-level"]
        version = parsed.attributes["version"]
        collectUnitTypes(from: parsed)
        collectGoodsTypes(from: parsed)
        collectBuildingTypes(from: parsed)
        collectTileTypes(from: parsed)
        collectImprovementTypes(from: parsed)
        resolveUnitTypeTraits()
    }

    /// Line of sight for a unit type, falling back to the type-name heuristic.
    public func lineOfSight(forUnitType unitType: String?) -> Int {
        if let unitType, let info = unitTypes[unitType] {
            return info.lineOfSight
        }
        return Self.fallbackLineOfSight(forUnitType: unitType)
    }

    /// Spec-derived naval flag, or nil when the unit type is unknown.
    public func isNaval(unitType: String?) -> Bool? {
        guard let unitType, let info = unitTypes[unitType] else { return nil }
        return info.isNaval
    }

    /// Spec-derived carries-units flag, or nil when the unit type is unknown.
    public func carriesUnits(unitType: String?) -> Bool? {
        guard let unitType, let info = unitTypes[unitType] else { return nil }
        return info.carriesUnits
    }

    /// Whether a unit type has an ability, including abilities inherited from
    /// its parent type.
    public func hasAbility(_ abilityId: String, unitType: String?) -> Bool {
        guard let unitType else { return false }
        return effectiveAbility(unitTypeId: unitType, abilityId: abilityId) ?? false
    }

    /// Best-effort fallback when the specification was not received.
    public static func fallbackLineOfSight(forUnitType unitType: String?) -> Int {
        UnitTypeTraits.isNaval(unitType: unitType) ? 2 : 1
    }

    private func collectUnitTypes(from node: ParsedMessage) {
        for child in node.children {
            if child.tag == "unit-type", let unitId = child.attributes["id"] {
                var abilities: [String: Bool] = [:]
                for grandchild in child.children where grandchild.tag == "ability" {
                    if let abilityId = grandchild.attributes["id"] {
                        abilities[abilityId] = grandchild.attributes.bool("value", default: true)
                    }
                }
                unitTypes[unitId] = UnitTypeInfo(
                    id: unitId,
                    lineOfSight: child.attributes.int("line-of-sight", default: -1),
                    isNaval: child.attributes.bool("naval", default: false),
                    carriesUnits: false,
                    offence: child.attributes.int("offence"),
                    defence: child.attributes.int("defence"),
                    movement: child.attributes.int("movement"),
                    cargoSpace: child.attributes["space"].flatMap { Int($0) },
                    spaceTaken: child.attributes["spaceTaken"].flatMap { Int($0) },
                    extendsId: child.attributes["extends"],
                    abilities: abilities,
                    price: child.attributes["price"].flatMap { Int($0) },
                    skill: child.attributes["skill"].flatMap { Int($0) }
                )
            }
            collectUnitTypes(from: child)
        }
    }

    /// Resolve inherited abilities and attributes after all unit types are known.
    private func resolveUnitTypeTraits() {
        for unitId in unitTypes.keys {
            guard var info = unitTypes[unitId] else { continue }
            let naval = effectiveAbility(unitTypeId: unitId,
                                         abilityId: "model.ability.navalUnit")
                ?? (info.isNaval || UnitTypeTraits.isNaval(unitType: unitId))
            let carries = effectiveAbility(unitTypeId: unitId,
                                           abilityId: "model.ability.carryUnits")
                ?? UnitTypeTraits.isNaval(unitType: unitId)
            info.isNaval = naval
            info.carriesUnits = carries
            if info.cargoSpace == nil {
                info.cargoSpace = inheritedUnitTypeValue(unitTypeId: unitId, value: \.cargoSpace)
            }
            if info.spaceTaken == nil {
                info.spaceTaken = inheritedUnitTypeValue(unitTypeId: unitId, value: \.spaceTaken)
            }
            if info.price == nil {
                info.price = inheritedUnitTypeValue(unitTypeId: unitId, value: \.price)
            }
            if info.skill == nil {
                info.skill = inheritedUnitTypeValue(unitTypeId: unitId, value: \.skill)
            }
            if info.lineOfSight < 0 {
                info.lineOfSight = inheritedLineOfSight(unitTypeId: unitId)
                    ?? Self.fallbackLineOfSight(forUnitType: unitId)
            }
            unitTypes[unitId] = info
        }
    }

    private func inheritedUnitTypeValue(unitTypeId: String,
                                        value: (UnitTypeInfo) -> Int?,
                                        visited: Set<String> = []) -> Int? {
        guard !visited.contains(unitTypeId), let info = unitTypes[unitTypeId] else { return nil }
        if let result = value(info) { return result }
        guard let parent = info.extendsId else { return nil }
        var visited = visited
        visited.insert(unitTypeId)
        return inheritedUnitTypeValue(unitTypeId: parent, value: value, visited: visited)
    }

    /// Walk the `extends` chain for an ability value (own value wins).
    private func effectiveAbility(unitTypeId: String,
                                  abilityId: String,
                                  visited: Set<String> = []) -> Bool? {
        guard !visited.contains(unitTypeId), let info = unitTypes[unitTypeId] else {
            return nil
        }
        if let value = info.abilities[abilityId] { return value }
        guard let parent = info.extendsId else { return nil }
        var visited = visited
        visited.insert(unitTypeId)
        return effectiveAbility(unitTypeId: parent, abilityId: abilityId, visited: visited)
    }

    /// First explicit `line-of-sight` up the `extends` chain.
    private func inheritedLineOfSight(unitTypeId: String,
                                      visited: Set<String> = []) -> Int? {
        guard !visited.contains(unitTypeId), let info = unitTypes[unitTypeId] else {
            return nil
        }
        if info.lineOfSight >= 0 { return info.lineOfSight }
        guard let parent = info.extendsId else { return nil }
        var visited = visited
        visited.insert(unitTypeId)
        return inheritedLineOfSight(unitTypeId: parent, visited: visited)
    }

    private func collectTileTypes(from node: ParsedMessage) {
        for child in node.children {
            guard child.tag == "tile-type", let tileId = child.attributes["id"] else {
                collectTileTypes(from: child)
                continue
            }
            var outputs: [String: Int] = [:]
            var inputs: [String: Int] = [:]
            for production in child.children where production.tag == "production" {
                // The unattended block is the colony-center production.
                guard production.attributes.bool("unattended", default: false) else { continue }
                for item in production.children {
                    guard let goodsType = item.attributes["goods-type"] ?? item.attributes["id"] else { continue }
                    let value = item.attributes.int("value")
                    if item.tag == "output" {
                        outputs[goodsType, default: 0] += value
                    } else if item.tag == "input" {
                        inputs[goodsType, default: 0] += value
                    }
                }
            }
            tileTypes[tileId] = TileTypeInfo(id: tileId,
                                             isWater: child.attributes.bool("is-water", default: false),
                                             canSettle: child.attributes.bool("can-settle", default: true),
                                             centerOutputs: outputs,
                                             centerInputs: inputs)
            collectTileTypes(from: child)
        }
    }

    private func collectGoodsTypes(from node: ParsedMessage) {
        for child in node.children {
            if child.tag == "goods-type", let goodsId = child.attributes["id"] {
                let market = child.children.first { $0.tag == "market" }
                goodsTypes[goodsId] = GoodsTypeInfo(
                    id: goodsId,
                    name: child.attributes["name"],
                    isFood: child.attributes.bool("is-food",
                                                  default: child.attributes.bool("food", default: false)),
                    isBuildingMaterial: child.attributes.bool("buildingMaterial", default: false),
                    isTradeGoods: child.attributes.bool("trade-goods",
                                                        default: child.attributes.bool("tradeGoods", default: false)),
                    isStorable: child.attributes.bool("storable", default: true),
                    isNewWorldGoods: child.attributes.bool("new-world-goods", default: false),
                    marketInitialAmount: market?.attributes.int("initial-amount") ?? 0,
                    marketInitialPrice: market?.attributes.int("initial-price") ?? 1,
                    priceDifference: market?.attributes.int("price-difference") ?? 1,
                    madeFrom: child.attributes["made-from"]
                )
            }
            collectGoodsTypes(from: child)
        }
    }

    private func collectImprovementTypes(from node: ParsedMessage) {
        for child in node.children {
            if child.tag == "tile-improvement-type", let improvementId = child.attributes["id"] {
                improvementTypes[improvementId] = ImprovementTypeInfo(
                    id: improvementId,
                    requiredRole: child.attributes["required-role"],
                    addWorkTurns: child.attributes.int("add-work-turns"),
                    isNatural: child.attributes.bool("natural", default: false)
                )
            }
            collectImprovementTypes(from: child)
        }
    }

    private func collectBuildingTypes(from node: ParsedMessage) {
        for child in node.children {
            if child.tag == "building-type", let buildingId = child.attributes["id"] {
                var requiredGoods: [String: Int] = [:]
                var attendedOutputs: [String: Int] = [:]
                var attendedInputs: [String: Int] = [:]
                var unattendedOutputs: [String: Int] = [:]
                var unattendedInputs: [String: Int] = [:]
                for grandchild in child.children {
                    switch grandchild.tag {
                    case "required-goods":
                        if let goodsId = grandchild.attributes["id"] {
                            requiredGoods[goodsId] = grandchild.attributes.int("value")
                        }
                    case "production":
                        let unattended = grandchild.attributes.bool("unattended", default: false)
                        for item in grandchild.children {
                            let goodsType = item.attributes["goods-type"] ?? item.attributes["id"]
                            guard let goodsType else { continue }
                            let value = item.attributes.int("value")
                            if item.tag == "output" {
                                if unattended {
                                    unattendedOutputs[goodsType, default: 0] += value
                                } else {
                                    attendedOutputs[goodsType, default: 0] += value
                                }
                            } else if item.tag == "input" {
                                if unattended {
                                    unattendedInputs[goodsType, default: 0] += value
                                } else {
                                    attendedInputs[goodsType, default: 0] += value
                                }
                            }
                        }
                    default:
                        break
                    }
                }
                // Prefer the attended block (a worker is present); fall back to
                // the unattended block so a building without workers still
                // contributes some output.
                let outputs = attendedOutputs.isEmpty ? unattendedOutputs : attendedOutputs
                let inputs = attendedInputs.isEmpty ? unattendedInputs : attendedInputs
                buildingTypes[buildingId] = BuildingTypeInfo(
                    id: buildingId,
                    upkeep: child.attributes.int("upkeep"),
                    requiredPopulation: child.attributes.int("required-population"),
                    upgradesFrom: child.attributes["upgrades-from"],
                    extendsId: child.attributes["extends"],
                    requiredGoods: requiredGoods,
                    productionOutputs: outputs,
                    productionInputs: inputs
                )
            }
            collectBuildingTypes(from: child)
        }
    }
}

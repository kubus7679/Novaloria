import Foundation
import FreeColProtocol

/// A production modifier parsed from the FreeCol specification.
public struct ProductionModifierInfo: Sendable {
    public enum Kind: String, Sendable {
        case additive
        case multiplicative
        case percentage
    }

    public var goodsType: String
    public var kind: Kind
    public var value: Double
    public var index: Int
    public var isDelete: Bool
    public var scopeTypes: [String]
    public var scopeAbilities: [String]
    public var negatedScopeTypes: [String]
    public var negatedScopeAbilities: [String]

    public init(goodsType: String,
                kind: Kind,
                value: Double,
                index: Int,
                isDelete: Bool = false,
                scopeTypes: [String] = [],
                scopeAbilities: [String] = [],
                negatedScopeTypes: [String] = [],
                negatedScopeAbilities: [String] = []) {
        self.goodsType = goodsType
        self.kind = kind
        self.value = value
        self.index = index
        self.isDelete = isDelete
        self.scopeTypes = scopeTypes
        self.scopeAbilities = scopeAbilities
        self.negatedScopeTypes = negatedScopeTypes
        self.negatedScopeAbilities = negatedScopeAbilities
    }
}

/// A player modifier that changes the colony's Sons of Liberty percentage.
public struct ColonyLibertyModifier: Sendable {
    public var kind: ProductionModifierInfo.Kind
    public var value: Double
    public var index: Int

    public init(kind: ProductionModifierInfo.Kind, value: Double, index: Int) {
        self.kind = kind
        self.value = value
        self.index = index
    }
}

/// Active difficulty thresholds used to calculate colony government efficiency.
public struct ColonyGovernmentRules: Sendable {
    public var badGovernmentLimit: Int
    public var veryBadGovernmentLimit: Int
    public var goodGovernmentLimit: Int
    public var veryGoodGovernmentLimit: Int

    public init(badGovernmentLimit: Int,
                veryBadGovernmentLimit: Int,
                goodGovernmentLimit: Int,
                veryGoodGovernmentLimit: Int) {
        self.badGovernmentLimit = badGovernmentLimit
        self.veryBadGovernmentLimit = veryBadGovernmentLimit
        self.goodGovernmentLimit = goodGovernmentLimit
        self.veryGoodGovernmentLimit = veryGoodGovernmentLimit
    }

    public static let classic = ColonyGovernmentRules(
        badGovernmentLimit: 8,
        veryBadGovernmentLimit: 12,
        goodGovernmentLimit: 50,
        veryGoodGovernmentLimit: 100
    )
}

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
    /// Unit type this unit can teach, from `skill-taught`.
    public var skillTaught: String?
    public var expertProduction: String?
    /// Goods required to construct this unit in a colony.
    public var requiredGoods: [String: Int]
    public var productionModifiers: [ProductionModifierInfo]
    public var consumes: [String: Int]

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
                 skill: Int? = nil,
                 skillTaught: String? = nil,
                 expertProduction: String? = nil,
                 requiredGoods: [String: Int] = [:],
                 productionModifiers: [ProductionModifierInfo] = [],
                consumes: [String: Int] = [:]) {
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
        self.skillTaught = skillTaught
        self.expertProduction = expertProduction
        self.requiredGoods = requiredGoods
        self.productionModifiers = productionModifiers
        self.consumes = consumes
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
    /// Whether this goods type contributes to the player's liberty total.
    public var isLiberty: Bool
    public var isBuildingMaterial: Bool
    public var isTradeGoods: Bool
    /// Whether goods of this type can be stored/traded (`storable`, default true).
    public var isStorable: Bool
    /// Fixed price for non-storable goods used by the building payment quote.
    public var price: Int
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
                isLiberty: Bool = false,
                isBuildingMaterial: Bool,
                isTradeGoods: Bool,
                isStorable: Bool = true,
                price: Int = 0,
                isNewWorldGoods: Bool = false,
                marketInitialAmount: Int = 0,
                marketInitialPrice: Int = 1,
                priceDifference: Int = 1,
                madeFrom: String? = nil) {
        self.id = id
        self.name = name
        self.isFood = isFood
        self.isLiberty = isLiberty
        self.isBuildingMaterial = isBuildingMaterial
        self.isTradeGoods = isTradeGoods
        self.isStorable = isStorable
        self.price = price
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
    /// Number of role equipment units expended when the improvement completes.
    public var expendedAmount: Int
    public var productionModifiers: [ProductionModifierInfo]

    public init(id: String,
                requiredRole: String?,
                addWorkTurns: Int,
                isNatural: Bool,
                expendedAmount: Int = 0,
                productionModifiers: [ProductionModifierInfo] = []) {
        self.id = id
        self.requiredRole = requiredRole
        self.addWorkTurns = addWorkTurns
        self.isNatural = isNatural
        self.expendedAmount = expendedAmount
        self.productionModifiers = productionModifiers
    }

    public var displayName: String {
        id.split(separator: ".").last.map(String.init) ?? id
    }
}

/// Parsed equipment requirements for a `<role>` definition.
public struct RoleTypeInfo: @unchecked Sendable {
    public var id: String
    public var maximumCount: Int
    /// Abilities granted by this role.
    public var abilities: [String: Bool]
    /// Goods required for each role-count unit, keyed by goods type id.
    public var requiredGoods: [String: Int]
    /// Required unit abilities and their expected values.
    public var requiredAbilities: [String: Bool]
    public var productionModifiers: [ProductionModifierInfo]

    public init(id: String,
                maximumCount: Int = 1,
                abilities: [String: Bool] = [:],
                requiredGoods: [String: Int] = [:],
                requiredAbilities: [String: Bool] = [:],
                productionModifiers: [ProductionModifierInfo] = []) {
        self.id = id
        self.maximumCount = maximumCount
        self.abilities = abilities
        self.requiredGoods = requiredGoods
        self.requiredAbilities = requiredAbilities
        self.productionModifiers = productionModifiers
    }
}

/// Parsed subset of a `<building-type>` definition from the server specification.
public struct BuildingTypeInfo: @unchecked Sendable {
    public var id: String
    public var upkeep: Int
    public var requiredPopulation: Int
    /// Additive storage capacity contributed by this building type.
    public var warehouseStorageBonus: Int
    /// Number of worker slots; nil means use the FreeCol default/inherited value.
    public var workplaces: Int?
    /// Skill bounds for units allowed to work here; nil means inherited/default.
    public var minimumSkill: Int?
    public var maximumSkill: Int?
    public var upgradesFrom: String?
    public var extendsId: String?
    /// Goods required to construct this building, keyed by goods type id.
    public var requiredGoods: [String: Int]
    /// Abilities required to construct this building, keyed by ability id.
    public var requiredAbilities: [String: Bool]
    /// Unit types this building grants the colony the ability to construct.
    public var buildableUnitTypes: Set<String>
    /// Abilities declared by this building type (inherited through `extends`).
    public var abilities: [String: Bool]
    /// Effective outputs: attended blocks when present, otherwise unattended.
    public var productionOutputs: [String: Int]
    /// Effective inputs: attended blocks when present, otherwise unattended.
    public var productionInputs: [String: Int]
    /// Attended production blocks, retained for assignment-aware estimates.
    public var attendedProductionOutputs: [String: Int]
    public var attendedProductionInputs: [String: Int]
    /// Unattended production blocks, which may run with no assigned worker.
    public var unattendedProductionOutputs: [String: Int]
    public var unattendedProductionInputs: [String: Int]
    public var competenceFactor: Double
    public var rebelFactor: Double
    public var productionModifiers: [ProductionModifierInfo]

    public init(id: String,
                upkeep: Int,
                requiredPopulation: Int,
                warehouseStorageBonus: Int = 0,
                workplaces: Int? = nil,
                minimumSkill: Int? = nil,
                maximumSkill: Int? = nil,
                upgradesFrom: String?,
                extendsId: String?,
                requiredGoods: [String: Int] = [:],
                requiredAbilities: [String: Bool] = [:],
                buildableUnitTypes: Set<String> = [],
                abilities: [String: Bool] = [:],
                productionOutputs: [String: Int] = [:],
                productionInputs: [String: Int] = [:],
                attendedProductionOutputs: [String: Int] = [:],
                attendedProductionInputs: [String: Int] = [:],
                unattendedProductionOutputs: [String: Int] = [:],
                unattendedProductionInputs: [String: Int] = [:],
                competenceFactor: Double = 1,
                rebelFactor: Double = 1,
                productionModifiers: [ProductionModifierInfo] = []) {
        self.id = id
        self.upkeep = upkeep
        self.requiredPopulation = requiredPopulation
        self.warehouseStorageBonus = warehouseStorageBonus
        self.workplaces = workplaces
        self.minimumSkill = minimumSkill
        self.maximumSkill = maximumSkill
        self.upgradesFrom = upgradesFrom
        self.extendsId = extendsId
        self.requiredGoods = requiredGoods
        self.requiredAbilities = requiredAbilities
        self.buildableUnitTypes = buildableUnitTypes
        self.abilities = abilities
        self.productionOutputs = productionOutputs
        self.productionInputs = productionInputs
        self.attendedProductionOutputs = attendedProductionOutputs
        self.attendedProductionInputs = attendedProductionInputs
        self.unattendedProductionOutputs = unattendedProductionOutputs
        self.unattendedProductionInputs = unattendedProductionInputs
        self.competenceFactor = competenceFactor
        self.rebelFactor = rebelFactor
        self.productionModifiers = productionModifiers
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
    public var canMoveToEurope: Bool
    public var centerOutputs: [String: Int]
    public var centerInputs: [String: Int]
    public var workerOutputs: [String: Int]
    public var productionModifiers: [ProductionModifierInfo]

    public init(id: String,
                isWater: Bool = false,
                canSettle: Bool = true,
                canMoveToEurope: Bool = false,
                centerOutputs: [String: Int] = [:],
                centerInputs: [String: Int] = [:],
                workerOutputs: [String: Int] = [:],
                productionModifiers: [ProductionModifierInfo] = []) {
        self.id = id
        self.isWater = isWater
        self.canSettle = canSettle
        self.canMoveToEurope = canMoveToEurope
        self.centerOutputs = centerOutputs
        self.centerInputs = centerInputs
        self.workerOutputs = workerOutputs
        self.productionModifiers = productionModifiers
    }
}

/// Production bonuses attached to natural tile resources.
public struct ResourceTypeInfo: Sendable {
    public var id: String
    public var productionModifiers: [ProductionModifierInfo]

    public init(id: String, productionModifiers: [ProductionModifierInfo]) {
        self.id = id
        self.productionModifiers = productionModifiers
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
    /// Unit equipment roles keyed by id (`model.role.*`).
    public private(set) var roleTypes: [String: RoleTypeInfo] = [:]
    public private(set) var resourceTypes: [String: ResourceTypeInfo] = [:]
    public private(set) var foundingFatherModifiers: [String: [ProductionModifierInfo]] = [:]
    public private(set) var nationTypeModifiers: [String: [ProductionModifierInfo]] = [:]
    public private(set) var foundingFatherIds: Set<String> = []
    /// Liberty cost factor selected by the server's active game options.
    public private(set) var foundingFatherFactor: Int?
    /// Active difficulty's government-efficiency thresholds.
    public private(set) var colonyGovernmentRules: ColonyGovernmentRules = .classic
    private var foundingFatherLibertyModifiers: [String: [ColonyLibertyModifier]] = [:]
    private var nationTypeLibertyModifiers: [String: [ColonyLibertyModifier]] = [:]
    private var nationTypeParents: [String: String] = [:]
    private var educationChanges: [String: [EducationChange]] = [:]

    private struct EducationChange {
        let to: String
        let turns: Int
    }

    public init(parsed: ParsedMessage) {
        id = parsed.attributes["id"]
        difficultyLevel = parsed.attributes["difficulty-level"]
        version = parsed.attributes["version"]
        if let difficultyLevel,
           let activeDifficulty = Self.optionGroup(withId: difficultyLevel, in: parsed) {
            foundingFatherFactor = Self.integerOption(
                "model.option.foundingFatherFactor",
                in: activeDifficulty
            ) ?? Self.integerOption("model.option.foundingFatherFactor", in: parsed)
        } else {
            foundingFatherFactor = Self.integerOption(
                "model.option.foundingFatherFactor",
                in: parsed
            )
        }
        let governmentOptions = (difficultyLevel.flatMap {
            Self.optionGroup(withId: $0, in: parsed)
        }) ?? parsed
        colonyGovernmentRules = ColonyGovernmentRules(
            badGovernmentLimit: Self.integerOption("model.option.badGovernmentLimit", in: governmentOptions)
                ?? ColonyGovernmentRules.classic.badGovernmentLimit,
            veryBadGovernmentLimit: Self.integerOption("model.option.veryBadGovernmentLimit", in: governmentOptions)
                ?? ColonyGovernmentRules.classic.veryBadGovernmentLimit,
            goodGovernmentLimit: Self.integerOption("model.option.goodGovernmentLimit", in: governmentOptions)
                ?? ColonyGovernmentRules.classic.goodGovernmentLimit,
            veryGoodGovernmentLimit: Self.integerOption("model.option.veryGoodGovernmentLimit", in: governmentOptions)
                ?? ColonyGovernmentRules.classic.veryGoodGovernmentLimit
        )
        collectUnitTypes(from: parsed)
        collectEducationChanges(from: parsed)
        collectGoodsTypes(from: parsed)
        collectBuildingTypes(from: parsed)
        collectTileTypes(from: parsed)
        collectImprovementTypes(from: parsed)
        collectRoleTypes(from: parsed)
        collectResourceTypes(from: parsed)
        collectFeatureProductionModifiers(from: parsed)
        resolveUnitTypeTraits()
    }

    /// Goods that contribute to the liberty/founding-father total.
    public var libertyGoodsTypes: Set<String> {
        Set(goodsTypes.values.filter(\.isLiberty).map(\.id))
    }

    /// Liberty-percentage modifiers granted to a European player by their nation and fathers.
    public func colonyLibertyModifiers(nationTypeId: String?, foundingFathers: [String]) -> [ColonyLibertyModifier] {
        var modifiers: [ColonyLibertyModifier] = []
        var visited: Set<String> = []
        var currentNation = nationTypeId
        while let nation = currentNation, visited.insert(nation).inserted {
            modifiers += nationTypeLibertyModifiers[nation] ?? []
            currentNation = nationTypeParents[nation]
        }
        for father in foundingFathers {
            modifiers += foundingFatherLibertyModifiers[father] ?? []
        }
        return modifiers.sorted { $0.index < $1.index }
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

    /// Whether a unit has an ability from its type or equipped role.
    public func hasAbility(_ abilityId: String, unitType: String?, role: String?) -> Bool {
        if let role, let value = roleTypes[role]?.abilities[abilityId] {
            return value
        }
        return hasAbility(abilityId, unitType: unitType)
    }

    /// Best-effort fallback when the specification was not received.
    public static func fallbackLineOfSight(forUnitType unitType: String?) -> Int {
        UnitTypeTraits.isNaval(unitType: unitType) ? 2 : 1
    }

    private func collectUnitTypes(from node: ParsedMessage) {
        for child in node.children {
            if child.tag == "unit-type", let unitId = child.attributes["id"] {
                var abilities: [String: Bool] = [:]
                var requiredGoods: [String: Int] = [:]
                for grandchild in child.children where grandchild.tag == "ability" {
                    if let abilityId = grandchild.attributes["id"] {
                        abilities[abilityId] = grandchild.attributes.bool("value", default: true)
                    }
                }
                for requirement in child.children where requirement.tag == "required-goods" {
                    if let goodsId = requirement.attributes["id"] {
                        requiredGoods[goodsId] = requirement.attributes.int("value")
                    }
                }
                var consumes: [String: Int] = [:]
                for consumption in child.children where consumption.tag == "consumes" {
                    if let goodsType = consumption.attributes["id"] {
                        consumes[goodsType] = consumption.attributes.int("value")
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
                    skill: child.attributes["skill"].flatMap { Int($0) },
                    skillTaught: child.attributes["skill-taught"],
                    expertProduction: child.attributes["expert-production"],
                    requiredGoods: requiredGoods,
                    productionModifiers: Self.productionModifiers(in: child.children),
                    consumes: consumes
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
            if info.skillTaught == nil {
                info.skillTaught = unitId
            }
            if info.lineOfSight < 0 {
                info.lineOfSight = inheritedLineOfSight(unitTypeId: unitId)
                    ?? Self.fallbackLineOfSight(forUnitType: unitId)
            }
            unitTypes[unitId] = info
        }
    }

    /// Base turns for the next education step a teacher can impart to a student.
    public func neededEducationTurns(teacherUnitTypeId: String,
                                     studentUnitTypeId: String) -> Int? {
        guard let taughtType = unitTypes[teacherUnitTypeId]?.skillTaught,
              let taughtSkill = unitTypes[taughtType]?.skill,
              let studentSkill = unitTypes[studentUnitTypeId]?.skill,
              studentSkill < taughtSkill else {
            return nil
        }
        return nextEducationChange(
            from: studentUnitTypeId,
            taughtType: taughtType,
            taughtSkill: taughtSkill,
            visited: []
        )?.turns
    }

    private func nextEducationChange(from unitTypeId: String,
                                     taughtType: String,
                                     taughtSkill: Int,
                                     visited: Set<String>) -> EducationChange? {
        guard !visited.contains(unitTypeId) else { return nil }
        let changes = educationChanges[unitTypeId] ?? []
        if let direct = changes.first(where: { $0.to == taughtType }) {
            return direct
        }
        var visited = visited
        visited.insert(unitTypeId)
        for change in changes where
            (unitTypes[change.to]?.skill ?? Int.max) < taughtSkill {
            if nextEducationChange(
                from: change.to,
                taughtType: taughtType,
                taughtSkill: taughtSkill,
                visited: visited
            ) != nil {
                return change
            }
        }
        return nil
    }

    private func collectEducationChanges(from node: ParsedMessage) {
        for child in node.children {
            if child.tag == "unit-change-type",
               child.attributes["id"] == "model.unitChange.education" {
                for change in child.children where change.tag == "unit-type-change" {
                    guard let from = change.attributes["from"],
                          let to = change.attributes["to"],
                          let turns = change.attributes["turns"].flatMap(Int.init),
                          turns > 0 else { continue }
                    educationChanges[from, default: []].append(EducationChange(to: to, turns: turns))
                }
            }
            collectEducationChanges(from: child)
        }
    }

    private func inheritedUnitTypeValue<Value>(unitTypeId: String,
                                               value: (UnitTypeInfo) -> Value?,
                                               visited: Set<String> = []) -> Value? {
        guard !visited.contains(unitTypeId), let info = unitTypes[unitTypeId] else { return nil }
        if let result = value(info) { return result }
        guard let parent = info.extendsId else { return nil }
        var visited = visited
        visited.insert(unitTypeId)
        return inheritedUnitTypeValue(unitTypeId: parent, value: value, visited: visited)
    }

    /// Walk the `extends` chain for an ability value (own value wins).
    public func effectiveAbility(unitTypeId: String,
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

    public func productionModifiers(forUnitType unitTypeId: String) -> [ProductionModifierInfo] {
        guard let info = unitTypes[unitTypeId] else { return [] }
        return mergeProductionModifiers(
            inherited: info.extendsId.map { productionModifiers(forUnitType: $0) } ?? [],
            declared: info.productionModifiers
        )
    }

    public func unitTypeHierarchy(for unitTypeId: String) -> Set<String> {
        var result: Set<String> = [unitTypeId]
        var current = unitTypes[unitTypeId]?.extendsId
        while let parent = current, result.insert(parent).inserted {
            current = unitTypes[parent]?.extendsId
        }
        return result
    }

    public func expertProduction(forUnitType unitTypeId: String?) -> String? {
        guard let unitTypeId, let info = unitTypes[unitTypeId] else { return nil }
        return info.expertProduction ?? info.extendsId.flatMap { expertProduction(forUnitType: $0) }
    }

    public func consumes(forUnitType unitTypeId: String) -> [String: Int] {
        guard let info = unitTypes[unitTypeId] else { return [:] }
        var result = info.extendsId.map { consumes(forUnitType: $0) } ?? [:]
        for (goods, amount) in info.consumes { result[goods] = amount }
        return result
    }

    public func effectiveAbilities(forUnitType unitTypeId: String) -> Set<String> {
        guard let info = unitTypes[unitTypeId] else { return [] }
        var result = info.extendsId.map { effectiveAbilities(forUnitType: $0) } ?? []
        for (ability, enabled) in info.abilities {
            if enabled { result.insert(ability) } else { result.remove(ability) }
        }
        return result
    }

    public func productionModifiers(forBuildingType buildingTypeId: String) -> [ProductionModifierInfo] {
        guard let info = buildingTypes[buildingTypeId] else { return [] }
        return mergeProductionModifiers(
            inherited: info.extendsId.map { productionModifiers(forBuildingType: $0) } ?? [],
            declared: info.productionModifiers
        )
    }

    public func buildingTypeHierarchy(for buildingTypeId: String) -> Set<String> {
        var result: Set<String> = [buildingTypeId]
        var current = buildingTypes[buildingTypeId]?.extendsId
        while let parent = current, result.insert(parent).inserted {
            current = buildingTypes[parent]?.extendsId
        }
        return result
    }

    /// Storage capacity contributed by a building, including inherited modifiers.
    public func warehouseStorageCapacity(forBuildingType buildingTypeId: String) -> Int? {
        warehouseStorageCapacity(forBuildingType: buildingTypeId, visited: [])
    }

    private func warehouseStorageCapacity(
        forBuildingType buildingTypeId: String,
        visited: Set<String>
    ) -> Int? {
        guard !visited.contains(buildingTypeId),
              let info = buildingTypes[buildingTypeId] else { return nil }
        var visited = visited
        visited.insert(buildingTypeId)
        let inheritedCapacity: Int
        if let parent = info.extendsId {
            guard let capacity = warehouseStorageCapacity(
                forBuildingType: parent,
                visited: visited
            ) else { return nil }
            inheritedCapacity = capacity
        } else {
            inheritedCapacity = 0
        }
        return inheritedCapacity + info.warehouseStorageBonus
    }

    /// Whether a building type has an ability, including inherited abilities.
    public func buildingHasAbility(_ abilityId: String,
                                   buildingTypeId: String,
                                   visited: Set<String> = []) -> Bool {
        guard !visited.contains(buildingTypeId),
              let info = buildingTypes[buildingTypeId] else { return false }
        if let value = info.abilities[abilityId] { return value }
        guard let parent = info.extendsId else { return false }
        var visited = visited
        visited.insert(buildingTypeId)
        return buildingHasAbility(abilityId, buildingTypeId: parent, visited: visited)
    }

    /// Maximum number of units which may work in this building type.
    public func buildingWorkplaces(for buildingTypeId: String) -> Int {
        var current: String? = buildingTypeId
        var visited = Set<String>()
        while let id = current, visited.insert(id).inserted,
              let info = buildingTypes[id] {
            if let workplaces = info.workplaces { return workplaces }
            current = info.extendsId
        }
        return 3
    }

    /// Whether a unit type meets this building's inherited skill bounds.
    public func canUnitTypeWorkInBuilding(_ unitTypeId: String,
                                          buildingTypeId: String) -> Bool {
        guard let skill = unitTypes[unitTypeId]?.skill else { return false }
        var minimumSkill: Int?
        var maximumSkill: Int?
        var current: String? = buildingTypeId
        var visited = Set<String>()
        while let id = current, visited.insert(id).inserted,
              let info = buildingTypes[id] {
            if minimumSkill == nil { minimumSkill = info.minimumSkill }
            if maximumSkill == nil { maximumSkill = info.maximumSkill }
            current = info.extendsId
        }
        return skill >= (minimumSkill ?? Int.min)
            && skill <= (maximumSkill ?? Int.max)
    }

    public func buildingOutputs(for buildingTypeId: String, unattended: Bool) -> [String: Int] {
        guard let info = buildingTypes[buildingTypeId] else { return [:] }
        let own = unattended ? info.unattendedProductionOutputs : info.attendedProductionOutputs
        if !own.isEmpty { return own }
        guard let parent = info.extendsId else { return [:] }
        return buildingOutputs(for: parent, unattended: unattended)
    }

    public func buildingInputs(for buildingTypeId: String, unattended: Bool) -> [String: Int] {
        guard let info = buildingTypes[buildingTypeId] else { return [:] }
        let own = unattended ? info.unattendedProductionInputs : info.attendedProductionInputs
        if !own.isEmpty { return own }
        guard let parent = info.extendsId else { return [:] }
        return buildingInputs(for: parent, unattended: unattended)
    }

    public func unitTypeHasAbility(_ abilityId: String, unitTypeId: String?) -> Bool {
        guard let unitTypeId else { return false }
        return effectiveAbility(unitTypeId: unitTypeId, abilityId: abilityId) ?? false
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
            var workerOutputs: [String: Int] = [:]
            for production in child.children where production.tag == "production" {
                // The unattended block is the colony-center production.
                let unattended = production.attributes.bool("unattended", default: false)
                for item in production.children {
                    guard let goodsType = item.attributes["goods-type"] ?? item.attributes["id"] else { continue }
                    let value = item.attributes.int("value")
                    if item.tag == "output" {
                        if unattended {
                            outputs[goodsType, default: 0] += value
                        } else {
                            workerOutputs[goodsType] = max(workerOutputs[goodsType] ?? 0, value)
                        }
                    } else if item.tag == "input", unattended {
                        inputs[goodsType, default: 0] += value
                    }
                }
            }
            tileTypes[tileId] = TileTypeInfo(id: tileId,
                                             isWater: child.attributes.bool("is-water", default: false),
                                             canSettle: child.attributes.bool("can-settle", default: true),
                                             canMoveToEurope: child.children.contains {
                                                 $0.tag == "ability"
                                                     && $0.attributes["id"] == "model.ability.moveToEurope"
                                                     && $0.attributes.bool("value", default: true)
                                             },
                                             centerOutputs: outputs,
                                             centerInputs: inputs,
                                             workerOutputs: workerOutputs,
                                             productionModifiers: Self.productionModifiers(in: child.children))
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
                    isLiberty: child.children.contains {
                        $0.tag == "modifier" && $0.attributes["id"] == "model.modifier.liberty"
                    },
                    isBuildingMaterial: child.attributes.bool("buildingMaterial", default: false),
                    isTradeGoods: child.attributes.bool("trade-goods",
                                                        default: child.attributes.bool("tradeGoods", default: false)),
                    isStorable: child.attributes.bool("storable", default: true),
                    price: child.attributes.int("price", default: 0),
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

    private static func integerOption(_ optionId: String, in node: ParsedMessage) -> Int? {
        if node.attributes["id"] == optionId,
           let value = node.attributes["value"],
           let parsed = Int(value) {
            return parsed
        }
        for child in node.children {
            if let value = integerOption(optionId, in: child) { return value }
        }
        return nil
    }

    private static func optionGroup(withId optionId: String, in node: ParsedMessage) -> ParsedMessage? {
        if node.tag == "optionGroup", node.attributes["id"] == optionId {
            return node
        }
        for child in node.children {
            if let group = optionGroup(withId: optionId, in: child) { return group }
        }
        return nil
    }

    private func collectImprovementTypes(from node: ParsedMessage) {
        for child in node.children {
            if child.tag == "tile-improvement-type", let improvementId = child.attributes["id"] {
                improvementTypes[improvementId] = ImprovementTypeInfo(
                    id: improvementId,
                    requiredRole: child.attributes["required-role"],
                    addWorkTurns: child.attributes.int("add-work-turns"),
                    isNatural: child.attributes.bool("natural", default: false),
                    expendedAmount: child.attributes.int("expended-amount"),
                    productionModifiers: Self.productionModifiers(in: child.children)
                )
            }
            collectImprovementTypes(from: child)
        }
    }

    private func collectRoleTypes(from node: ParsedMessage) {
        for child in node.children {
            if child.tag == "role", let roleId = child.attributes["id"] {
                var abilities: [String: Bool] = [:]
                var requiredGoods: [String: Int] = [:]
                var requiredAbilities: [String: Bool] = [:]
                for requirement in child.children {
                    switch requirement.tag {
                    case "ability":
                        if let abilityId = requirement.attributes["id"] {
                            abilities[abilityId] = requirement.attributes.bool("value", default: true)
                        }
                    case "required-goods":
                        if let goodsId = requirement.attributes["id"] {
                            requiredGoods[goodsId] = requirement.attributes.int("value")
                        }
                    case "required-ability":
                        if let abilityId = requirement.attributes["id"] {
                            requiredAbilities[abilityId] = requirement.attributes.bool("value", default: true)
                        }
                    default:
                        break
                    }
                }
                roleTypes[roleId] = RoleTypeInfo(
                    id: roleId,
                    maximumCount: max(1, child.attributes.int("maximum-count", default: 1)),
                    abilities: abilities,
                    requiredGoods: requiredGoods,
                    requiredAbilities: requiredAbilities,
                    productionModifiers: Self.productionModifiers(in: child.children)
                )
            }
            collectRoleTypes(from: child)
        }
    }

    private func collectBuildingTypes(from node: ParsedMessage) {
        for child in node.children {
            if child.tag == "building-type", let buildingId = child.attributes["id"] {
                var requiredGoods: [String: Int] = [:]
                var warehouseStorageBonus = 0
                var buildableUnitTypes = Set<String>()
                var abilities: [String: Bool] = [:]
                var requiredAbilities: [String: Bool] = [:]
                var attendedOutputs: [String: Int] = [:]
                var attendedInputs: [String: Int] = [:]
                var unattendedOutputs: [String: Int] = [:]
                var unattendedInputs: [String: Int] = [:]
                for grandchild in child.children {
                    switch grandchild.tag {
                    case "ability":
                        guard let abilityId = grandchild.attributes["id"] else { continue }
                        let enabled = grandchild.attributes.bool("value", default: true)
                        abilities[abilityId] = enabled
                        if abilityId == "model.ability.build", enabled {
                            for scope in grandchild.children where scope.tag == "scope" {
                                if let unitType = scope.attributes["type"] {
                                    buildableUnitTypes.insert(unitType)
                                }
                            }
                        }
                    case "required-goods":
                        if let goodsId = grandchild.attributes["id"] {
                            requiredGoods[goodsId] = grandchild.attributes.int("value")
                        }
                    case "required-ability":
                        if let abilityId = grandchild.attributes["id"] {
                            requiredAbilities[abilityId] = grandchild.attributes.bool("value", default: true)
                        }
                    case "modifier":
                        guard grandchild.attributes["id"] == "model.modifier.warehouseStorage",
                              grandchild.attributes["type"] == "additive" else { continue }
                        if let rawValue = grandchild.attributes["value"],
                           let value = Double(rawValue), value.isFinite {
                            warehouseStorageBonus += Int(value.rounded(.towardZero))
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
                    warehouseStorageBonus: warehouseStorageBonus,
                    workplaces: child.attributes["workplaces"].flatMap { Int($0) },
                    minimumSkill: child.attributes["minimum-skill"].flatMap { Int($0) },
                    maximumSkill: child.attributes["maximum-skill"].flatMap { Int($0) },
                    upgradesFrom: child.attributes["upgrades-from"],
                    extendsId: child.attributes["extends"],
                    requiredGoods: requiredGoods,
                    requiredAbilities: requiredAbilities,
                    buildableUnitTypes: buildableUnitTypes,
                    abilities: abilities,
                    productionOutputs: outputs,
                    productionInputs: inputs,
                    attendedProductionOutputs: attendedOutputs,
                    attendedProductionInputs: attendedInputs,
                    unattendedProductionOutputs: unattendedOutputs,
                    unattendedProductionInputs: unattendedInputs,
                    competenceFactor: Double(child.attributes["competence-factor"] ?? "1") ?? 1,
                    rebelFactor: Double(child.attributes["rebel-factor"] ?? "1") ?? 1,
                    productionModifiers: Self.productionModifiers(in: child.children)
                )
            }
            collectBuildingTypes(from: child)
        }
    }

    private func collectResourceTypes(from node: ParsedMessage) {
        for child in node.children {
            if child.tag == "resource-type", let id = child.attributes["id"] {
                resourceTypes[id] = ResourceTypeInfo(
                    id: id,
                    productionModifiers: Self.productionModifiers(in: child.children)
                )
            }
            collectResourceTypes(from: child)
        }
    }

    private func collectFeatureProductionModifiers(from node: ParsedMessage) {
        for child in node.children {
            guard let id = child.attributes["id"] else {
                collectFeatureProductionModifiers(from: child)
                continue
            }
            switch child.tag {
            case "founding-father":
                foundingFatherIds.insert(id)
                foundingFatherModifiers[id] = Self.productionModifiers(in: child.children)
                foundingFatherLibertyModifiers[id] = Self.colonyLibertyModifiers(in: child.children)
            case "european-nation-type":
                nationTypeModifiers[id] = Self.productionModifiers(in: child.children)
                nationTypeLibertyModifiers[id] = Self.colonyLibertyModifiers(in: child.children)
                nationTypeParents[id] = child.attributes["extends"]
            default:
                break
            }
            collectFeatureProductionModifiers(from: child)
        }
    }

    private static func productionModifiers(in children: [ParsedMessage]) -> [ProductionModifierInfo] {
        children.compactMap { child in
            guard child.tag == "modifier",
                  let goodsType = child.attributes["id"],
                  goodsType.hasPrefix("model.goods.") else { return nil }
            let isDelete = child.attributes.bool("delete", default: false)
            guard let value = Double(child.attributes["value"] ?? (isDelete ? "0" : "")) else {
                return nil
            }
            let kind = ProductionModifierInfo.Kind(
                rawValue: child.attributes["type"]?.lowercased() ?? "additive"
            ) ?? .additive
            let scopes = child.children.filter { $0.tag == "scope" }
            return ProductionModifierInfo(
                goodsType: goodsType,
                kind: kind,
                value: value,
                index: child.attributes.int("index", default: 100),
                isDelete: isDelete,
                scopeTypes: scopes.filter { !$0.attributes.bool("match-negated") }
                    .compactMap { $0.attributes["type"] },
                scopeAbilities: scopes.filter { !$0.attributes.bool("match-negated") }
                    .compactMap { $0.attributes["ability-id"] },
                negatedScopeTypes: scopes.filter { $0.attributes.bool("match-negated") }
                    .compactMap { $0.attributes["type"] },
                negatedScopeAbilities: scopes.filter { $0.attributes.bool("match-negated") }
                    .compactMap { $0.attributes["ability-id"] }
            )
        }
    }

    private static func colonyLibertyModifiers(in children: [ParsedMessage]) -> [ColonyLibertyModifier] {
        children.compactMap { child in
            guard child.tag == "modifier",
                  child.attributes["id"] == "model.modifier.SoL",
                  let value = Double(child.attributes["value"] ?? "") else { return nil }
            let kind = ProductionModifierInfo.Kind(
                rawValue: child.attributes["type"]?.lowercased() ?? "additive"
            ) ?? .additive
            return ColonyLibertyModifier(
                kind: kind,
                value: value,
                index: child.attributes.int("index", default: 100)
            )
        }
    }

    private func mergeProductionModifiers(inherited: [ProductionModifierInfo],
                                          declared: [ProductionModifierInfo]) -> [ProductionModifierInfo] {
        var result = inherited
        for modifier in declared {
            if modifier.isDelete {
                result.removeAll { $0.goodsType == modifier.goodsType }
            } else {
                result.append(modifier)
            }
        }
        return result
    }
}

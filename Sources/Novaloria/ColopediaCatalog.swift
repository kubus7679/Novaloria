import Foundation
import FreeColGame
import FreeColProtocol

enum ColopediaCategory: String, Codable, CaseIterable {
    case units, goods, terrain, buildings, improvements, fathers, nations, resources, roles, concepts

    var title: String {
        switch self {
        case .units: return L10n.text("Einheiten", table: "ColopediaCatalog")
        case .goods: return L10n.text("Waren", table: "ColopediaCatalog")
        case .terrain: return L10n.text("Gelände", table: "ColopediaCatalog")
        case .buildings: return L10n.text("Gebäude", table: "ColopediaCatalog")
        case .improvements: return L10n.text("Geländeverbesserungen", table: "ColopediaCatalog")
        case .fathers: return L10n.text("Gründerväter", table: "ColopediaCatalog")
        case .nations: return L10n.text("Nationen", table: "ColopediaCatalog")
        case .resources: return L10n.text("Bodenschätze und Ressourcen", table: "ColopediaCatalog")
        case .roles: return L10n.text("Ausrüstung und Rollen", table: "ColopediaCatalog")
        case .concepts: return L10n.text("Konzepte", table: "ColopediaCatalog")
        }
    }

    var symbol: String {
        switch self {
        case .units: return "person.fill"
        case .goods: return "shippingbox.fill"
        case .terrain: return "mountain.2.fill"
        case .buildings: return "building.2.fill"
        case .improvements: return "hammer.fill"
        case .fathers: return "person.crop.rectangle"
        case .nations: return "flag.fill"
        case .resources: return "leaf.fill"
        case .roles: return "backpack.fill"
        case .concepts: return "lightbulb.fill"
        }
    }
}

private final class ColopediaResourceCache: @unchecked Sendable {
    private let lock = NSLock()
    private var entriesByLanguage: [String: [ColopediaEntry]] = [:]

    func entries(language: String) -> [ColopediaEntry] {
        lock.lock()
        defer { lock.unlock() }
        if let cached = entriesByLanguage[language] { return cached }
        var entries = (Self.loadEntries(language: language) ?? [])
            + (Self.loadConceptEntries(language: language) ?? [])
        var identifiers = Set(entries.map(\.id))
        if language == "es" {
            let english = (Self.loadEntries(language: "en") ?? [])
                + (Self.loadConceptEntries(language: "en") ?? [])
            entries += english.filter { identifiers.insert($0.id).inserted }
        }
        if language != "de" {
            let german = (Self.loadEntries(language: "de") ?? [])
                + (Self.loadConceptEntries(language: "de") ?? [])
            entries += german.filter { identifiers.insert($0.id).inserted }
        }
        entriesByLanguage[language] = entries
        return entries
    }

    private static func loadEntries(language: String) -> [ColopediaEntry]? {
        do {
            let subdirectory = language == "de" ? nil : "\(language).lproj"
            guard let url = Bundle.module.url(
                forResource: "colopedia-\(language)",
                withExtension: "json",
                subdirectory: subdirectory
            ) ?? Bundle.module.url(forResource: "colopedia-\(language)", withExtension: "json") else {
                throw CocoaError(.fileNoSuchFile)
            }
            return try JSONDecoder().decode([ColopediaEntry].self, from: Data(contentsOf: url))
        } catch {
            FreeColLogger.shared.error("Colopädie konnte nicht geladen werden (colopedia-\(language).json): \(error)")
            return nil
        }
    }

    private static func loadConceptEntries(language: String) -> [ColopediaEntry]? {
        do {
            guard let url = Bundle.module.url(
                forResource: "colopedia-concepts-\(language)",
                withExtension: "json",
                subdirectory: "colopedia"
            ) else {
                throw CocoaError(.fileNoSuchFile)
            }
            return try JSONDecoder().decode([ColopediaEntry].self, from: Data(contentsOf: url))
        } catch {
            FreeColLogger.shared.error("Colopädie-Konzepte konnten nicht geladen werden (\(language)): \(error)")
            return nil
        }
    }
}

struct ColopediaEntry: Decodable, Identifiable {
    struct Fact: Decodable {
        let label: String
        let value: String
    }

    let id: String
    let category: ColopediaCategory
    let title: String
    let summary: String
    let text: String
    let facts: [Fact]
    let related: [String]
    let icon: String?

    func facts(using specification: Specification?) -> [Fact] {
        if category == .fathers {
            var result = facts
            if !summary.isEmpty {
                result.insert(Fact(label: L10n.text("Bonus", table: "ColopediaCatalog"), value: summary), at: 0)
            }
            guard let specification else { return result }
            result += productionModifierFacts(specification.foundingFatherModifiers[id] ?? [])
            result += specification.colonyLibertyModifiers(
                nationTypeId: nil,
                foundingFathers: [id]
            ).map {
                Fact(
                    label: L10n.text("Freiheitsmodifikator", table: "ColopediaCatalog"),
                    value: formattedModifier($0.kind, value: $0.value)
                )
            }
            return result
        }
        if let info = specification?.unitTypes[id] {
            var result = [
                Fact(label: L10n.text("Sichtweite", table: "ColopediaCatalog"), value: "\(info.lineOfSight)"),
                Fact(label: L10n.text("Angriff", table: "ColopediaCatalog"), value: "\(info.offence)"),
                Fact(label: L10n.text("Verteidigung", table: "ColopediaCatalog"), value: "\(info.defence)"),
                Fact(label: L10n.text("Bewegungspunkte", table: "ColopediaCatalog"), value: String(format: "%g", Double(info.movement) / 3)),
                Fact(label: L10n.text("Frachtplätze", table: "ColopediaCatalog"), value: "\(info.cargoSpace ?? 0)"),
            ]
            if let price = info.price {
                result.append(Fact(label: L10n.text("Preis in Gold", table: "ColopediaCatalog"), value: "\(price)"))
            }
            if let skill = info.skill {
                result.append(Fact(label: L10n.text("Fähigkeitsstufe", table: "ColopediaCatalog"), value: "\(skill)"))
            }
            if let skillTaught = info.skillTaught {
                result.append(Fact(label: L10n.text("Lehrt Fähigkeit", table: "ColopediaCatalog"), value: GameLabels.name(skillTaught)))
            }
            if let expertProduction = info.expertProduction {
                result.append(Fact(label: L10n.text("Produktionsfachgebiet", table: "ColopediaCatalog"), value: GameLabels.name(expertProduction)))
            }
            if info.carriesUnits {
                result.append(Fact(label: L10n.text("Kann Einheiten transportieren", table: "ColopediaCatalog"), value: L10n.text("Ja", table: "ColopediaCatalog")))
            }
            if let spaceTaken = info.spaceTaken {
                result.append(Fact(label: L10n.text("Plätze auf Transporter", table: "ColopediaCatalog"), value: "\(spaceTaken)"))
            }
            result += goodsFacts(info.requiredGoods, label: L10n.text("Baukosten", table: "ColopediaCatalog"))
            result += goodsFacts(info.consumes, label: L10n.text("Verbrauch", table: "ColopediaCatalog"))
            result += abilityFacts(info.abilities, label: L10n.text("Gewährte Fähigkeit", table: "ColopediaCatalog"))
            result += productionModifierFacts(info.productionModifiers)
            result += combatModifierFacts(info.combatModifiers)
            return result
        }
        if let info = specification?.goodsTypes[id] {
            var result: [Fact] = []
            if info.isFood { result.append(booleanFact("Nahrung", value: true)) }
            if info.isLiberty { result.append(booleanFact("Freiheitsgut", value: true)) }
            if info.isBuildingMaterial { result.append(booleanFact("Baumaterial", value: true)) }
            if info.isTradeGoods { result.append(booleanFact("Handelsware", value: true)) }
            if !info.isStorable { result.append(booleanFact("Lagerfähig", value: false)) }
            if info.price > 0 {
                result.append(Fact(label: L10n.text("Festpreis", table: "ColopediaCatalog"), value: "\(info.price)"))
            }
            if info.marketInitialAmount > 0 {
                result.append(Fact(label: L10n.text("Markt-Referenzpreis", table: "ColopediaCatalog"), value: "\(info.marketInitialPrice)"))
                result.append(Fact(label: L10n.text("Markt-Referenzmenge", table: "ColopediaCatalog"), value: "\(info.marketInitialAmount)"))
                result.append(Fact(label: L10n.text("Preisunterschied", table: "ColopediaCatalog"), value: "\(info.priceDifference)"))
            }
            if let madeFrom = info.madeFrom {
                result.append(Fact(label: L10n.text("Veredelt aus", table: "ColopediaCatalog"), value: GameLabels.name(madeFrom)))
            }
            return result
        }
        if let info = specification?.buildingTypes[id] {
            var result = [
                Fact(label: L10n.text("Benötigte Bevölkerung", table: "ColopediaCatalog"), value: "\(info.requiredPopulation)"),
                Fact(label: L10n.text("Unterhalt in Gold", table: "ColopediaCatalog"), value: "\(info.upkeep)"),
            ]
            if let workplaces = info.workplaces {
                result.append(Fact(label: L10n.text("Arbeitsplätze", table: "ColopediaCatalog"), value: "\(workplaces)"))
            }
            if info.warehouseStorageBonus > 0 {
                result.append(Fact(label: L10n.text("Lagerkapazitätsbonus", table: "ColopediaCatalog"), value: "\(info.warehouseStorageBonus)"))
            }
            if let upgradesFrom = info.upgradesFrom {
                result.append(Fact(label: L10n.text("Ausbau von", table: "ColopediaCatalog"), value: GameLabels.name(upgradesFrom)))
            }
            if let minimumSkill = info.minimumSkill {
                result.append(Fact(label: L10n.text("Mindestfähigkeitsstufe", table: "ColopediaCatalog"), value: "\(minimumSkill)"))
            }
            if let maximumSkill = info.maximumSkill {
                result.append(Fact(label: L10n.text("Maximalfähigkeitsstufe", table: "ColopediaCatalog"), value: "\(maximumSkill)"))
            }
            result += goodsFacts(info.requiredGoods, label: L10n.text("Baukosten", table: "ColopediaCatalog"))
            result += goodsFacts(info.productionInputs, label: L10n.text("Verbrauch", table: "ColopediaCatalog"))
            result += goodsFacts(info.productionOutputs, label: L10n.text("Produktion", table: "ColopediaCatalog"))
            result += abilityFacts(info.requiredAbilities, label: L10n.text("Erforderliche Fähigkeit", table: "ColopediaCatalog"))
            result += abilityFacts(info.abilities, label: L10n.text("Gewährte Fähigkeit", table: "ColopediaCatalog"))
            result += info.buildableUnitTypes.sorted().map {
                Fact(label: L10n.text("Kann Einheiten bauen", table: "ColopediaCatalog"), value: GameLabels.name($0))
            }
            result += productionModifierFacts(info.productionModifiers)
            result += combatModifierFacts(info.combatModifiers)
            return result
        }
        if let info = specification?.roleTypes[id] {
            var result = [Fact(
                label: L10n.text("Maximale Ausrüstung", table: "ColopediaCatalog"),
                value: "\(info.maximumCount)"
            )]
            result += goodsFacts(info.requiredGoods, label: L10n.text("Ausrüstung", table: "ColopediaCatalog"))
            result += info.abilities.filter(\.value).keys.sorted().map {
                Fact(label: L10n.text("Gewährte Fähigkeit", table: "ColopediaCatalog"), value: GameLabels.name($0))
            }
            result += info.requiredAbilities.keys.sorted().map {
                Fact(label: L10n.text("Erforderliche Fähigkeit", table: "ColopediaCatalog"), value: GameLabels.name($0))
            }
            result += productionModifierFacts(info.productionModifiers)
            result += combatModifierFacts(info.combatModifiers)
            return result
        }
        if let info = specification?.tileTypes[id] {
            return [Fact(
                label: L10n.text("Geländeart", table: "ColopediaCatalog"),
                value: info.isWater
                    ? L10n.text("Wasser", table: "ColopediaCatalog")
                    : L10n.text("Land", table: "ColopediaCatalog")
            ), Fact(
                label: L10n.text("Besiedelbar", table: "ColopediaCatalog"),
                value: info.canSettle
                    ? L10n.text("Ja", table: "ColopediaCatalog")
                    : L10n.text("Nein", table: "ColopediaCatalog")
            ), Fact(
                label: L10n.text("Passage nach Europa", table: "ColopediaCatalog"),
                value: info.canMoveToEurope
                    ? L10n.text("Ja", table: "ColopediaCatalog")
                    : L10n.text("Nein", table: "ColopediaCatalog")
            )]
                + goodsFacts(info.centerOutputs, label: L10n.text("Produktion im Koloniezentrum", table: "ColopediaCatalog"))
                + goodsFacts(info.centerInputs, label: L10n.text("Verbrauch im Koloniezentrum", table: "ColopediaCatalog"))
                + goodsFacts(info.workerOutputs, label: L10n.text("Produktion mit Arbeiter", table: "ColopediaCatalog"))
                + productionModifierFacts(info.productionModifiers)
                + combatModifierFacts(info.combatModifiers)
        }
        if let info = specification?.improvementTypes[id] {
            var result = [
                Fact(label: L10n.text("Zusätzliche Arbeitsrunden", table: "ColopediaCatalog"), value: "\(info.addWorkTurns)"),
                Fact(
                    label: L10n.text("Natürlich", table: "ColopediaCatalog"),
                    value: info.isNatural
                        ? L10n.text("Ja", table: "ColopediaCatalog")
                        : L10n.text("Nein", table: "ColopediaCatalog")
                ),
            ]
            if info.expendedAmount > 0 {
                result.append(Fact(label: L10n.text("Benötigte Ausrüstung", table: "ColopediaCatalog"), value: "\(info.expendedAmount)"))
            }
            result += (info.requiredRole.map {
                [Fact(label: L10n.text("Benötigte Rolle", table: "ColopediaCatalog"), value: GameLabels.name($0))]
            } ?? []) + productionModifierFacts(info.productionModifiers)
            return result
        }
        if let info = specification?.resourceTypes[id] {
            return productionModifierFacts(info.productionModifiers)
        }
        if id == "colopedia.concepts.efficiency", let specification {
            let rules = specification.colonyGovernmentRules
            return [
                Fact(label: L10n.text("Grenze schlechte Regierung", table: "ColopediaCatalog"), value: "\(rules.badGovernmentLimit)"),
                Fact(label: L10n.text("Grenze sehr schlechte Regierung", table: "ColopediaCatalog"), value: "\(rules.veryBadGovernmentLimit)"),
                Fact(label: L10n.text("Grenze gute Regierung", table: "ColopediaCatalog"), value: "\(rules.goodGovernmentLimit)"),
                Fact(label: L10n.text("Grenze sehr gute Regierung", table: "ColopediaCatalog"), value: "\(rules.veryGoodGovernmentLimit)"),
                booleanFact("Glockenproduktion begrenzt", value: specification.bellAccumulationCapped),
            ]
        }
        return facts
    }

    private func booleanFact(_ label: String, value: Bool) -> Fact {
        Fact(
            label: L10n.text(String.LocalizationValue(label), table: "ColopediaCatalog"),
            value: L10n.text(value ? "Ja" : "Nein", table: "ColopediaCatalog")
        )
    }

    private func abilityFacts(_ abilities: [String: Bool], label: String) -> [Fact] {
        abilities.keys.sorted().map {
            Fact(label: label, value: "\(GameLabels.name($0)): \(L10n.text(abilities[$0] == true ? "Ja" : "Nein", table: "ColopediaCatalog"))")
        }
    }

    private func productionModifierFacts(_ modifiers: [ProductionModifierInfo]) -> [Fact] {
        modifiers.map { modifier in
            let scopes = modifier.scopeTypes + modifier.scopeAbilities
                + modifier.negatedScopeTypes.map { "!\($0)" }
                + modifier.negatedScopeAbilities.map { "!\($0)" }
            let scope = scopes.isEmpty ? "" : " (\(scopes.map(GameLabels.name).joined(separator: ", ")))"
            let value = modifier.isDelete
                ? L10n.text("Entfernt", table: "ColopediaCatalog")
                : formattedModifier(modifier.kind, value: modifier.value)
            return Fact(
                label: L10n.text("Produktionsmodifikator", table: "ColopediaCatalog"),
                value: "\(GameLabels.name(modifier.goodsType)): \(value)\(scope)"
            )
        }
    }

    private func combatModifierFacts(_ modifiers: [CombatModifierInfo]) -> [Fact] {
        modifiers.map {
            Fact(
                label: L10n.text("Kampfmodifikator", table: "ColopediaCatalog"),
                value: "\(GameLabels.name($0.id)): \(formattedModifier($0.kind, value: $0.value))"
            )
        }
    }

    private func formattedModifier(_ kind: ProductionModifierInfo.Kind, value: Double) -> String {
        let number = String(format: "%g", value)
        switch kind {
        case .additive:
            return value > 0 ? "+\(number)" : number
        case .multiplicative:
            return "×\(number)"
        case .percentage:
            return "\(number)%"
        }
    }

    private func goodsFacts(_ goods: [String: Int], label: String) -> [Fact] {
        goods.sorted { $0.key < $1.key }.map {
            Fact(label: "\(label): \(GameLabels.name($0.key))", value: "\($0.value)")
        }
    }
}

enum ColopediaCatalog {
    private static let resourceCache = ColopediaResourceCache()

    static var classicEntries: [ColopediaEntry] {
        let language: String
        switch InterfaceLanguage.selected {
        case .german: language = "de"
        case .english: language = "en"
        case .spanish: language = "es"
        case .system:
            switch Locale.autoupdatingCurrent.language.languageCode?.identifier {
            case "de": language = "de"
            case "es": language = "es"
            default: language = "en"
            }
        }
        return resourceCache.entries(language: language)
    }

    static func entries(specification: Specification?) -> [ColopediaEntry] {
        var result = classicEntries
        var known = Set(result.map(\.id))
        let extra: [(ColopediaCategory, [String])] = [
            (.units, specification?.unitTypes.keys.map { $0 } ?? []),
            (.goods, specification?.goodsTypes.keys.map { $0 } ?? []),
            (.terrain, specification?.tileTypes.keys.map { $0 } ?? []),
            (.buildings, specification?.buildingTypes.keys.map { $0 } ?? []),
            (.improvements, specification?.improvementTypes.keys.map { $0 } ?? []),
            (.roles, specification?.roleTypes.keys.map { $0 } ?? []),
            (.resources, specification?.resourceTypes.keys.map { $0 } ?? []),
            (.fathers, specification?.foundingFatherIds.map { $0 } ?? []),
        ]
        for (category, ids) in extra {
            for id in ids where id.hasPrefix("model.") && known.insert(id).inserted {
                let roleInfo = specification?.roleTypes[id]
                let title = category == .roles ? roleTitle(id) : GameLabels.name(id)
                result.append(ColopediaEntry(
                    id: id, category: category, title: title,
                    summary: category == .roles ? roleSummary(roleInfo) : "",
                    text: "", facts: [], related: [], icon: nil
                ))
            }
        }
        return result.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    private static func roleTitle(_ id: String) -> String {
        let prefix = "model.role."
        guard id.hasPrefix(prefix) else {
            return id == "model.role"
                ? L10n.text("Unbenannte Rolle", table: "ColopediaCatalog")
                : GameLabels.name(id)
        }
        let title = GameLabels.name(id)
        let genericNames = ["Rolle", "Role", "Función"]
        if !genericNames.contains(title) { return title }
        let suffix = String(id.dropFirst(prefix.count))
        let suffixTitle = suffix.isEmpty ? "" : GameLabels.name(suffix)
        if !suffixTitle.isEmpty, !genericNames.contains(suffixTitle) {
            return suffixTitle
        }
        return id == "model.role"
            ? L10n.text("Unbenannte Rolle", table: "ColopediaCatalog")
            : "\(L10n.text("Rolle", table: "ColopediaCatalog")) (\(id))"
    }

    private static func roleSummary(_ info: RoleTypeInfo?) -> String {
        guard let info else {
            return L10n.text("Für diese Rolle liegen keine Ausrüstungsdetails vor.", table: "ColopediaCatalog")
        }
        var details: [String] = []
        let equipment = info.requiredGoods.sorted { $0.key < $1.key }.map {
            "\(GameLabels.name($0.key)) ×\($0.value)"
        }
        if !equipment.isEmpty {
            details.append("\(L10n.text("Ausrüstung", table: "ColopediaCatalog")): \(equipment.joined(separator: ", "))")
        }
        let grantedAbilities = info.abilities.filter(\.value).keys.sorted().map(GameLabels.name)
        if !grantedAbilities.isEmpty {
            details.append(
                "\(L10n.text("Gewährte Fähigkeit", table: "ColopediaCatalog")): \(grantedAbilities.joined(separator: ", "))"
            )
        }
        let requiredAbilities = info.requiredAbilities.filter(\.value).keys.sorted().map(GameLabels.name)
        if !requiredAbilities.isEmpty {
            details.append(
                "\(L10n.text("Erforderliche Fähigkeit", table: "ColopediaCatalog")): \(requiredAbilities.joined(separator: ", "))"
            )
        }
        return details.isEmpty
            ? L10n.text("Diese Rolle benötigt keine zusätzliche Ausrüstung und gewährt keine besonderen Fähigkeiten.", table: "ColopediaCatalog")
            : details.joined(separator: ". ") + "."
    }

    static func search(_ entries: [ColopediaEntry], query: String) -> [ColopediaEntry] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return entries }
        return entries.filter {
            [$0.title, $0.summary, $0.text, $0.category.title, $0.id].contains {
                $0.localizedCaseInsensitiveContains(query)
            }
        }
    }
}

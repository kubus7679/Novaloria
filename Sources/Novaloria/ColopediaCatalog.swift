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
            return result
        }
        if let info = specification?.buildingTypes[id] {
            return [
                Fact(label: L10n.text("Benötigte Bevölkerung", table: "ColopediaCatalog"), value: "\(info.requiredPopulation)"),
                Fact(label: L10n.text("Unterhalt in Gold", table: "ColopediaCatalog"), value: "\(info.upkeep)"),
            ] + goodsFacts(info.requiredGoods, label: L10n.text("Baukosten", table: "ColopediaCatalog"))
                + goodsFacts(info.productionInputs, label: L10n.text("Verbrauch", table: "ColopediaCatalog"))
                + goodsFacts(info.productionOutputs, label: L10n.text("Produktion", table: "ColopediaCatalog"))
        }
        if let info = specification?.tileTypes[id] {
            return [Fact(
                label: L10n.text("Geländeart", table: "ColopediaCatalog"),
                value: info.isWater
                    ? L10n.text("Wasser", table: "ColopediaCatalog")
                    : L10n.text("Land", table: "ColopediaCatalog")
            )]
                + goodsFacts(info.centerOutputs, label: L10n.text("Produktion im Koloniezentrum", table: "ColopediaCatalog"))
                + goodsFacts(info.workerOutputs, label: L10n.text("Produktion mit Arbeiter", table: "ColopediaCatalog"))
        }
        if let info = specification?.improvementTypes[id] {
            return [
                Fact(label: L10n.text("Zusätzliche Arbeitsrunden", table: "ColopediaCatalog"), value: "\(info.addWorkTurns)"),
                Fact(
                    label: L10n.text("Natürlich", table: "ColopediaCatalog"),
                    value: info.isNatural
                        ? L10n.text("Ja", table: "ColopediaCatalog")
                        : L10n.text("Nein", table: "ColopediaCatalog")
                ),
            ]
        }
        return facts
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
        let known = Set(result.map(\.id))
        let extra: [(ColopediaCategory, [String])] = [
            (.units, specification?.unitTypes.keys.map { $0 } ?? []),
            (.goods, specification?.goodsTypes.keys.map { $0 } ?? []),
            (.terrain, specification?.tileTypes.keys.map { $0 } ?? []),
            (.buildings, specification?.buildingTypes.keys.map { $0 } ?? []),
            (.improvements, specification?.improvementTypes.keys.map { $0 } ?? []),
        ]
        for (category, ids) in extra {
            for id in ids where !known.contains(id) && id.hasPrefix("model.") {
                result.append(ColopediaEntry(
                    id: id, category: category, title: GameLabels.name(id),
                    summary: "", text: "", facts: [], related: [], icon: nil
                ))
            }
        }
        return result.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
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

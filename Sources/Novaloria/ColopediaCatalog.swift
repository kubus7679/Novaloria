import Foundation
import FreeColGame
import FreeColProtocol

enum ColopediaCategory: String, Codable, CaseIterable {
    case units, goods, terrain, buildings, improvements, fathers, nations, resources, roles

    var title: String {
        switch self {
        case .units: return "Einheiten"
        case .goods: return "Waren"
        case .terrain: return "Gelände"
        case .buildings: return "Gebäude"
        case .improvements: return "Geländeverbesserungen"
        case .fathers: return "Gründerväter"
        case .nations: return "Nationen"
        case .resources: return "Bodenschätze und Ressourcen"
        case .roles: return "Ausrüstung und Rollen"
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
                Fact(label: "Sichtweite", value: "\(info.lineOfSight)"),
                Fact(label: "Angriff", value: "\(info.offence)"),
                Fact(label: "Verteidigung", value: "\(info.defence)"),
                Fact(label: "Bewegungspunkte", value: String(format: "%g", Double(info.movement) / 3)),
                Fact(label: "Frachtplätze", value: "\(info.cargoSpace ?? 0)"),
            ]
            if let price = info.price { result.append(Fact(label: "Preis in Gold", value: "\(price)")) }
            if let skill = info.skill { result.append(Fact(label: "Fähigkeitsstufe", value: "\(skill)")) }
            return result
        }
        if let info = specification?.buildingTypes[id] {
            return [
                Fact(label: "Benötigte Bevölkerung", value: "\(info.requiredPopulation)"),
                Fact(label: "Unterhalt in Gold", value: "\(info.upkeep)"),
            ] + goodsFacts(info.requiredGoods, label: "Baukosten")
                + goodsFacts(info.productionInputs, label: "Verbrauch")
                + goodsFacts(info.productionOutputs, label: "Produktion")
        }
        if let info = specification?.tileTypes[id] {
            return [Fact(label: "Geländeart", value: info.isWater ? "Wasser" : "Land")]
                + goodsFacts(info.centerOutputs, label: "Produktion im Koloniezentrum")
                + goodsFacts(info.workerOutputs, label: "Produktion mit Arbeiter")
        }
        if let info = specification?.improvementTypes[id] {
            return [Fact(label: "Zusätzliche Arbeitsrunden", value: "\(info.addWorkTurns)"),
                    Fact(label: "Natürlich", value: info.isNatural ? "Ja" : "Nein")]
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
    static let classicEntries: [ColopediaEntry] = {
        do {
            guard let url = Bundle.module.url(forResource: "colopedia-de", withExtension: "json") else {
                throw CocoaError(.fileNoSuchFile)
            }
            return try JSONDecoder().decode([ColopediaEntry].self, from: Data(contentsOf: url))
        } catch {
            FreeColLogger.shared.error("Colopädie konnte nicht geladen werden: \(error)")
            return []
        }
    }()

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

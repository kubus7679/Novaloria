import Foundation
import FreeColGame
import FreeColProtocol

enum GameLabels {
    private static let names: [String: String] = {
        do {
            guard let url = Bundle.module.url(forResource: "object-names-de", withExtension: "json") else {
                throw CocoaError(.fileNoSuchFile)
            }
            return try JSONDecoder().decode([String: String].self, from: Data(contentsOf: url))
        } catch {
            FreeColLogger.shared.error("Spielnamen konnten nicht geladen werden: \(error)")
            return [:]
        }
    }()

    static func name(_ identifier: String) -> String {
        if let translated = names[identifier] { return translated }
        let short = identifier.split(separator: ".").last.map(String.init) ?? identifier
        return short.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression)
            .capitalized
    }

    static func name(_ identifier: String, fallback: String?) -> String {
        if names[identifier] == nil, let fallback, !fallback.isEmpty {
            return fallback
        }
        return name(identifier)
    }

    static func state(_ state: UnitState) -> String {
        switch state {
        case .active: return "Aktiv"
        case .fortified: return "Befestigt"
        case .fortifying: return "Befestigt sich"
        case .sentry: return "Wache"
        case .skipped: return "Wartet"
        case .improving: return "Arbeitet"
        case .inColony: return "In der Kolonie"
        case .sailing: return "Auf See"
        case .toEurope: return "Nach Europa"
        case .toAmerica: return "Zur Neuen Welt"
        }
    }
}

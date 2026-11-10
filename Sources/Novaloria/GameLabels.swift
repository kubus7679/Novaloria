import Foundation
import FreeColGame
import FreeColProtocol

private final class GameLabelResourceCache: @unchecked Sendable {
    private let lock = NSLock()
    private var namesByLanguage: [String: [String: String]] = [:]
    private var messagesByLanguage: [String: [String: String]] = [:]

    func names(language: String) -> [String: String] {
        lock.lock()
        defer { lock.unlock() }
        if let cached = namesByLanguage[language] { return cached }
        let result = loadLocalizedMap(resourcePrefix: "object-names", language: language)
        namesByLanguage[language] = result
        return result
    }

    func modelMessageTexts(language: String) -> [String: String] {
        lock.lock()
        defer { lock.unlock() }
        if let cached = messagesByLanguage[language] { return cached }
        let result = loadLocalizedMap(resourcePrefix: "model-message-texts", language: language)
        messagesByLanguage[language] = result
        return result
    }

    private func loadLocalizedMap(resourcePrefix: String, language: String) -> [String: String] {
        var result: [String: String] = [:]
        if language != "de",
           let german = Self.loadJSON(
               [String: String].self,
               resource: "\(resourcePrefix)-de",
               errorMessage: "Deutsche Ressourcen konnten nicht geladen werden"
           ) {
            result.merge(german) { _, fallback in fallback }
        }
        if language == "es",
           let english = Self.loadJSON(
               [String: String].self,
               resource: "\(resourcePrefix)-en",
               errorMessage: "Englische Ressourcen konnten nicht geladen werden"
           ) {
            result.merge(english) { _, fallback in fallback }
        }
        if let selected = Self.loadJSON(
            [String: String].self,
            resource: "\(resourcePrefix)-\(language)",
            errorMessage: "Lokalisierte Ressourcen konnten nicht geladen werden"
        ) {
            result.merge(selected) { _, translated in translated }
        }
        return result
    }

    private static func loadJSON<T: Decodable>(
        _ type: T.Type,
        resource: String,
        errorMessage: String
    ) -> T? {
        do {
            let language = resource.split(separator: "-").last.map(String.init) ?? "de"
            let subdirectory = language == "de" ? nil : "\(language).lproj"
            guard let url = Bundle.module.url(
                forResource: resource,
                withExtension: "json",
                subdirectory: subdirectory
            ) ?? Bundle.module.url(forResource: resource, withExtension: "json") else {
                throw CocoaError(.fileNoSuchFile)
            }
            return try JSONDecoder().decode(type, from: Data(contentsOf: url))
        } catch {
            FreeColLogger.shared.error("\(errorMessage): \(resource).json: \(error)")
            return nil
        }
    }
}

enum GameLabels {
    private static let resourceCache = GameLabelResourceCache()

    private static var selectedResourceLanguage: String {
        InterfaceLanguage.selected.localizationCode
    }

    private static var names: [String: String] {
        resourceCache.names(language: selectedResourceLanguage)
    }

    private static var modelMessageTexts: [String: String] {
        resourceCache.modelMessageTexts(language: selectedResourceLanguage)
    }

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

    static func modelMessageText(_ identifier: String) -> String? {
        modelMessageTexts[identifier]
    }

    static func state(_ state: UnitState) -> String {
        switch state {
        case .active: return L10n.text("Aktiv", table: "GameLabels")
        case .fortified: return L10n.text("Befestigt", table: "GameLabels")
        case .fortifying: return L10n.text("Befestigt sich", table: "GameLabels")
        case .sentry: return L10n.text("Wache", table: "GameLabels")
        case .skipped: return L10n.text("Wartet", table: "GameLabels")
        case .improving: return L10n.text("Arbeitet", table: "GameLabels")
        case .inColony: return L10n.text("In der Kolonie", table: "GameLabels")
        case .sailing: return L10n.text("Auf See", table: "GameLabels")
        case .toEurope: return L10n.text("Nach Europa", table: "GameLabels")
        case .toAmerica: return L10n.text("Zur Neuen Welt", table: "GameLabels")
        }
    }
}

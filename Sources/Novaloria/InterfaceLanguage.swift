import Foundation
import Observation

enum InterfaceLanguage: String, CaseIterable, Identifiable {
    static let preferenceKey = "novaloria.interfaceLanguage"

    case system
    case german
    case english
    case spanish

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return L10n.text("Systemsprache", table: "InterfaceLanguage")
        case .german: return "Deutsch"
        case .english: return "English"
        case .spanish: return "Español"
        }
    }

    var locale: Locale {
        switch self {
        case .system: return .autoupdatingCurrent
        case .german: return Locale(identifier: "de_DE")
        case .english: return Locale(identifier: "en_US")
        case .spanish: return Locale(identifier: "es_ES")
        }
    }

    var localizationCode: String {
        switch self {
        case .german: return "de"
        case .english: return "en"
        case .spanish: return "es"
        case .system:
            switch Locale.autoupdatingCurrent.language.languageCode?.identifier {
            case "de": return "de"
            case "es": return "es"
            default: return "en"
            }
        }
    }

    static var selected: InterfaceLanguage {
        LocalizationSettings.shared.language
    }
}

@Observable
final class LocalizationSettings {
    static let shared = LocalizationSettings()

    var language: InterfaceLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: InterfaceLanguage.preferenceKey)
        }
    }

    private init() {
        let rawValue = UserDefaults.standard.string(forKey: InterfaceLanguage.preferenceKey)
        language = rawValue.flatMap(InterfaceLanguage.init(rawValue:)) ?? .system
    }
}

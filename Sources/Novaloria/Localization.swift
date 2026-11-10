import Foundation
import FreeColProtocol

enum LocalizationBundles {
    private static let bundles: [String: Bundle] = {
        Dictionary(uniqueKeysWithValues: ["de", "en", "es"].compactMap { language in
            let resource = "NovaloriaLocalization-\(language)"
            guard let url = Bundle.module.url(forResource: resource, withExtension: "bundle"),
                  let bundle = Bundle(url: url) else {
                FreeColLogger.shared.error("Lokalisierungspaket konnte nicht geladen werden: \(resource).bundle")
                return nil
            }
            return (language, bundle)
        })
    }()

    static func bundle(for language: String) -> Bundle {
        guard let bundle = bundles[language] else {
            FreeColLogger.shared.error("Unbekannte Lokalisierung: \(language)")
            return Bundle.module
        }
        return bundle
    }
}

enum L10n {
    static func text(
        _ key: String.LocalizationValue,
        table: String = "Localizable"
    ) -> String {
        let language = LocalizationSettings.shared.language
        return String(
            localized: key,
            table: table,
            bundle: LocalizationBundles.bundle(for: language.localizationCode),
            locale: language.locale
        )
    }
}

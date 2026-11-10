import XCTest
@testable import Novaloria

final class InterfaceLanguageTests: XCTestCase {
    func testGermanLanguageUsesGermanLocale() {
        XCTAssertEqual(InterfaceLanguage.german.locale.identifier, "de_DE")
    }

    func testEnglishLanguageUsesEnglishLocale() {
        XCTAssertEqual(InterfaceLanguage.english.title, "English")
        XCTAssertEqual(InterfaceLanguage.english.locale.identifier, "en_US")
    }

    func testSpanishLanguageUsesSpanishLocale() {
        XCTAssertEqual(InterfaceLanguage.spanish.title, "Español")
        XCTAssertEqual(InterfaceLanguage.spanish.locale.identifier, "es_ES")
    }

    func testSystemLanguageFollowsCurrentLocale() {
        XCTAssertEqual(InterfaceLanguage.system.locale, .autoupdatingCurrent)
    }

    func testLanguageLabelsUseSelectedLocalizationTable() {
        let previousLanguage = LocalizationSettings.shared.language
        defer { LocalizationSettings.shared.language = previousLanguage }

        LocalizationSettings.shared.language = .english
        XCTAssertEqual(L10n.text("Systemsprache", table: "InterfaceLanguage"), "System language")

        LocalizationSettings.shared.language = .spanish
        XCTAssertEqual(L10n.text("Systemsprache", table: "InterfaceLanguage"), "Idioma del sistema")

        LocalizationSettings.shared.language = .german
        XCTAssertEqual(L10n.text("Systemsprache", table: "InterfaceLanguage"), "Systemsprache")
    }

    func testAppStringsFollowSelectedLanguage() {
        let previousLanguage = LocalizationSettings.shared.language
        defer { LocalizationSettings.shared.language = previousLanguage }

        LocalizationSettings.shared.language = .german
        XCTAssertEqual(L10n.text("Über Novaloria", table: "App"), "Über Novaloria")

        LocalizationSettings.shared.language = .english
        XCTAssertEqual(L10n.text("Über Novaloria", table: "App"), "About Novaloria")

        LocalizationSettings.shared.language = .spanish
        XCTAssertEqual(L10n.text("Über Novaloria", table: "App"), "Acerca de Novaloria")
    }

    func testTaxLabelFollowsSelectedLanguage() {
        let previousLanguage = LocalizationSettings.shared.language
        defer { LocalizationSettings.shared.language = previousLanguage }
        let tax = 20

        for (language, expected) in [
            (InterfaceLanguage.english, "Tax 20%"),
            (.spanish, "Impuestos 20%"),
            (.german, "Steuern 20%"),
        ] {
            LocalizationSettings.shared.language = language
            XCTAssertEqual(L10n.text("Steuern \(tax)%", table: "GameView"), expected)
        }
    }

    func testCargoMaximumLabelsFollowSelectedLanguage() {
        let previousLanguage = LocalizationSettings.shared.language
        defer { LocalizationSettings.shared.language = previousLanguage }
        let amount = 100

        for (language, load, unload) in [
            (InterfaceLanguage.english, "Max load: 100", "Max unload: 100"),
            (.spanish, "Carga máx.: 100", "Descarga máx.: 100"),
            (.german, "Max laden: 100", "Max entladen: 100"),
        ] {
            LocalizationSettings.shared.language = language
            XCTAssertEqual(L10n.text("Max laden: \(amount)", table: "ColonyPanelView"), load)
            XCTAssertEqual(L10n.text("Max entladen: \(amount)", table: "ColonyPanelView"), unload)
        }
    }

    func testInspectorCommandsFollowSelectedLanguage() {
        let previousLanguage = LocalizationSettings.shared.language
        defer { LocalizationSettings.shared.language = previousLanguage }
        let labels: [(String.LocalizationValue, String, String, String)] = [
            ("Aktivieren", "Aktivieren", "Activate", "Activar"),
            ("Warten", "Warten", "Wait", "Esperar"),
            ("Wache", "Wache", "Sentry", "Centinela"),
            ("Einheitenbefehle", "Einheitenbefehle", "Unit orders", "Órdenes de la unidad"),
            ("Marschziel", "Marschziel", "Destination", "Destino"),
            ("Pionierarbeit", "Pionierarbeit", "Pioneer work", "Trabajo de pionero"),
            ("Angriff", "Angriff", "Attack", "Ataque"),
            ("Transport", "Transport", "Transport", "Transporte"),
        ]
        for (key, german, english, spanish) in labels {
            for (language, expected) in [
                (InterfaceLanguage.english, english), (.spanish, spanish), (.german, german),
            ] {
                LocalizationSettings.shared.language = language
                XCTAssertEqual(L10n.text(key, table: "GameView"), expected)
            }
        }
    }
}

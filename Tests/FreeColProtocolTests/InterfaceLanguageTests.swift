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

    func testColonyRebelTooltipLabelsFollowSelectedLanguage() {
        let previousLanguage = LocalizationSettings.shared.language
        defer { LocalizationSettings.shared.language = previousLanguage }

        for (language, rebels, royalists, turns) in [
            (InterfaceLanguage.english, "Rebels:", "Royalists:", "Turns: 6"),
            (.spanish, "Rebeldes:", "Realistas:", "Turnos: 6"),
            (.german, "Rebellen:", "Royalisten:", "Züge: 6"),
        ] {
            LocalizationSettings.shared.language = language
            XCTAssertEqual(L10n.text("Rebellen:", table: "ColonyPanelView"), rebels)
            XCTAssertEqual(L10n.text("Royalisten:", table: "ColonyPanelView"), royalists)
            XCTAssertEqual(L10n.text("Züge: \(6)", table: "ColonyPanelView"), turns)
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

        func testColonyEducationActionsAndRemainingTimeFollowSelectedLanguage() {
            let previousLanguage = LocalizationSettings.shared.language
            defer { LocalizationSettings.shared.language = previousLanguage }

            for (language, assignment, hint) in [
                (InterfaceLanguage.english, "Assign teacher", "Right-click for education actions"),
                (.spanish, "Asignar profesor", "Haz clic derecho para opciones de formación"),
                (.german, "Lehrer zuweisen", "Rechtsklick für Ausbildungsaktionen"),
            ] {
                LocalizationSettings.shared.language = language
                XCTAssertEqual(L10n.text("Lehrer zuweisen", table: "ColonyPanelView"), assignment)
                XCTAssertEqual(L10n.text("Rechtsklick für Ausbildungsaktionen", table: "ColonyPanelView"), hint)
            }
        }

        func testWarehouseCapacityLabelFollowsSelectedLanguage() {
            let previousLanguage = LocalizationSettings.shared.language
            defer { LocalizationSettings.shared.language = previousLanguage }

            for (language, expected) in [
                (InterfaceLanguage.english, "Maximum warehouse capacity per good"),
                (.spanish, "Capacidad máxima del almacén por mercancía"),
                (.german, "Maximale Lagerkapazität je Ware"),
            ] {
                LocalizationSettings.shared.language = language
                XCTAssertEqual(L10n.text("Maximale Lagerkapazität je Ware", table: "ColonyPanelView"), expected)
            }
        }
    }

    func testColonyProductionExplanationsFollowSelectedLanguage() {
        let previousLanguage = LocalizationSettings.shared.language
        defer { LocalizationSettings.shared.language = previousLanguage }
        let amount = 2
        let produced = 3
        let consumed = 1
        let goods = "tools"
        for (language, result, balance, administration) in [
            (InterfaceLanguage.english, "Result: 2 tools per turn", "Balance: 3 − 1 = 2", "Administration"),
            (.spanish, "Resultado: 2 tools por turno", "Balance: 3 − 1 = 2", "Administración"),
            (.german, "Ergebnis: 2 tools pro Runde", "Bilanz: 3 − 1 = 2", "Verwaltung"),
        ] {
            LocalizationSettings.shared.language = language
            XCTAssertEqual(L10n.text("Ergebnis: \(amount) \(goods) pro Runde", table: "ColonyProductionCalculator"), result)
            XCTAssertEqual(L10n.text("Bilanz: \(produced) − \(consumed) = \(produced - consumed)", table: "ColonyProductionCalculator"), balance)
            XCTAssertEqual(L10n.text("Verwaltung", table: "ColonyPanelView"), administration)
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
            ("Feldinfo anzeigen", "Feldinfo anzeigen", "Show tile info", "Mostrar información de la casilla"),
            ("Einheitenaktionen anzeigen", "Einheitenaktionen anzeigen", "Show unit actions", "Mostrar acciones de unidad"),
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

import Foundation

/// Centralized labels resolved for the currently selected interface language.

enum UILabels {
    // MARK: - General

    static var close: String { L10n.text("Schließen", table: "UILabels") }
    static var dismiss: String { L10n.text("Schließen", table: "UILabels") }
    static var cancel: String { L10n.text("Abbrechen", table: "UILabels") }
    static var ok: String { L10n.text("OK", table: "UILabels") }
    static var `default`: String { L10n.text("Standard", table: "UILabels") }

    // MARK: - Reports

    static var reports: String { L10n.text("Berichte", table: "UILabels") }
    static var nationSummary: String { L10n.text("Nationsübersicht", table: "UILabels") }
    static var highScores: String { L10n.text("Bestenliste", table: "UILabels") }
    static var noReportsAvailable: String { L10n.text("Keine Berichte verfügbar.", table: "UILabels") }
    static var noEntries: String { L10n.text("Keine Einträge.", table: "UILabels") }

    // Report headers
    static var player: String { L10n.text("Spieler", table: "UILabels") }
    static var nation: String { L10n.text("Nation", table: "UILabels") }
    static var score: String { L10n.text("Punkte", table: "UILabels") }
    static var units: String { L10n.text("Einheiten", table: "UILabels") }
    static var colonies: String { L10n.text("Kolonien", table: "UILabels") }
    static var settlements: String { L10n.text("Siedlungen", table: "UILabels") }
    static var military: String { L10n.text("Militär", table: "UILabels") }
    static var naval: String { L10n.text("Flotte", table: "UILabels") }
    static var gold: String { L10n.text("Gold", table: "UILabels") }
    static var sol: String { L10n.text("Freiheitsbewusstsein", table: "UILabels") }
    static var tax: String { L10n.text("Steuer", table: "UILabels") }
    static var stance: String { L10n.text("Haltung", table: "UILabels") }

    // MARK: - Report Panel

    static var coloniesReport: String { L10n.text("Kolonien", table: "UILabels") }
    static var unitTypesReport: String { L10n.text("Einheiten", table: "UILabels") }
    static var militaryReport: String { L10n.text("Militär", table: "UILabels") }
    static var navalReport: String { L10n.text("Flotte", table: "UILabels") }
    static var cargoReport: String { L10n.text("Fracht", table: "UILabels") }
    static var tradeReport: String { L10n.text("Handel", table: "UILabels") }
    static var foreignAffairsReport: String { L10n.text("Außenpolitik", table: "UILabels") }
    static var indianReport: String { L10n.text("Ureinwohner", table: "UILabels") }
    static var explorationReport: String { L10n.text("Erkundung", table: "UILabels") }
    static var turnReport: String { L10n.text("Zugbericht", table: "UILabels") }
    static var financialReport: String { L10n.text("Finanzen", table: "UILabels") }
    static var continentalCongressReport: String { L10n.text("Kontinentalkongress", table: "UILabels") }
    static var labourReport: String { L10n.text("Arbeit", table: "UILabels") }
    static var religiousReport: String { L10n.text("Religion", table: "UILabels") }
    static var productionReport: String { L10n.text("Produktion", table: "UILabels") }
    static var educationReport: String { L10n.text("Ausbildung", table: "UILabels") }
    static var requirementsReport: String { L10n.text("Bedarf", table: "UILabels") }
    static var historyReport: String { L10n.text("Geschichte", table: "UILabels") }

    // Filter and sort
    static var filterRows: String { L10n.text("Zeilen filtern", table: "UILabels") }
    static var sortAscending: String { L10n.text("Sortieren ↑", table: "UILabels") }
    static var sortDescending: String { L10n.text("Sortieren ↓", table: "UILabels") }
    static var sortHelp: String { L10n.text("Zeilen nach der ersten Spalte sortieren", table: "UILabels") }
    static var exportCSV: String { L10n.text("CSV exportieren…", table: "UILabels") }
    static var csvExportFailed: String { L10n.text("CSV-Export fehlgeschlagen", table: "UILabels") }
    static var requestFromServer: String { L10n.text("Vom Server anfordern", table: "UILabels") }

    // Empty states
    static var noColonies: String { L10n.text("Keine Kolonien.", table: "UILabels") }
    static var noUnits: String { L10n.text("Keine Einheiten.", table: "UILabels") }
    static var noNavalUnits: String { L10n.text("Keine Schiffe.", table: "UILabels") }
    static var noMilitaryUnits: String { L10n.text("Keine Militäreinheiten.", table: "UILabels") }
    static var noCargoCarriers: String { L10n.text("Keine Frachter.", table: "UILabels") }
    static var empty: String { L10n.text("leer", table: "UILabels") }
    static var noMarketData: String { L10n.text("Keine Marktdaten.", table: "UILabels") }
    static var noOtherEuropeanPowers: String { L10n.text("Keine anderen europäischen Mächte.", table: "UILabels") }
    static var noNativePeoples: String { L10n.text("Keine Ureinwohner.", table: "UILabels") }
    static var noMap: String { L10n.text("Keine Karte.", table: "UILabels") }
    static var noGame: String { L10n.text("Kein Spiel.", table: "UILabels") }
    static var noFoundingFathers: String { L10n.text("Noch keine Gründerväter.", table: "UILabels") }
    static var inCongress: String { L10n.text("Im Kongress", table: "UILabels") }
    static var offered: String { L10n.text("Angeboten", table: "UILabels") }
    static var noWorkers: String { L10n.text("Keine Arbeiter.", table: "UILabels") }
    static var noMissionaries: String { L10n.text("Keine Missionare.", table: "UILabels") }
    static var noEstimatedProduction: String { L10n.text("Keine geschätzte Produktion.", table: "UILabels") }
    static var noMaterialRequirements: String { L10n.text("Keine Materialanforderungen.", table: "UILabels") }
    static var noEducation: String { L10n.text("Keine Ausbildung im Gange.", table: "UILabels") }
    static var noEventsRecorded: String { L10n.text("Keine Ereignisse aufgezeichnet.", table: "UILabels") }

    // Table headers
    static var name: String { L10n.text("Name", table: "UILabels") }
    static var population: String { L10n.text("Bev.", table: "UILabels") }
    static var liberty: String { L10n.text("Freiheit", table: "UILabels") }
    static var bonus: String { L10n.text("Bonus", table: "UILabels") }
    static var unitType: String { L10n.text("Einheitentyp", table: "UILabels") }
    static var count: String { L10n.text("Anzahl", table: "UILabels") }
    static var unit: String { L10n.text("Einheit", table: "UILabels") }
    static var state: String { L10n.text("Zustand", table: "UILabels") }
    static var moves: String { L10n.text("BP", table: "UILabels") }
    static var location: String { L10n.text("Standort", table: "UILabels") }
    static var goods: String { L10n.text("Ware", table: "UILabels") }
    static var inStock: String { L10n.text("Vorrat", table: "UILabels") }
    static var buy: String { L10n.text("Kauf", table: "UILabels") }
    static var sell: String { L10n.text("Verkauf", table: "UILabels") }
    static var arrears: String { L10n.text("Schulden", table: "UILabels") }
    static var item: String { L10n.text("Posten", table: "UILabels") }
    static var value: String { L10n.text("Wert", table: "UILabels") }
    static var people: String { L10n.text("Volk", table: "UILabels") }
    static var tension: String { L10n.text("Spannung", table: "UILabels") }
    static var exploredTiles: String { L10n.text("Erkundete Kacheln", table: "UILabels") }
    static var explored: String { L10n.text("Erkundet", table: "UILabels") }
    static var turn: String { L10n.text("Runde", table: "UILabels") }
    static var currentPlayer: String { L10n.text("Aktueller Spieler", table: "UILabels") }
    static var yourGold: String { L10n.text("Dein Gold", table: "UILabels") }
    static var yourTax: String { L10n.text("Deine Steuer", table: "UILabels") }
    static var yourScore: String { L10n.text("Deine Punkte", table: "UILabels") }
    static var events: String { L10n.text("Ereignisse", table: "UILabels") }
    static var foundingFather: String { L10n.text("Gründervater", table: "UILabels") }
    static var student: String { L10n.text("Schüler", table: "UILabels") }
    static var teacher: String { L10n.text("Lehrer", table: "UILabels") }
    static var colony: String { L10n.text("Kolonie", table: "UILabels") }
    static var work: String { L10n.text("Arbeit", table: "UILabels") }
    static var perTurn: String { L10n.text("Pro Runde", table: "UILabels") }
    static var stored: String { L10n.text("Vorhanden", table: "UILabels") }
    static var required: String { L10n.text("Benötigt", table: "UILabels") }
    static var event: String { L10n.text("Ereignis", table: "UILabels") }
    static var source: String { L10n.text("Quelle", table: "UILabels") }
    static var type: String { L10n.text("Typ", table: "UILabels") }

    // MARK: - Colony Panel

    static var owner: String { L10n.text("Besitzer", table: "UILabels") }
    static var freedom: String { L10n.text("Freiheit", table: "UILabels") }
    static var immigration: String { L10n.text("Einwanderung", table: "UILabels") }
    static var production: String { L10n.text("Produktion", table: "UILabels") }
    static var productionBonus: String { L10n.text("Produktionsbonus", table: "UILabels") }
    static var workers: String { L10n.text("Arbeiter", table: "UILabels") }
    static var administration: String { L10n.text("Verwaltung", table: "UILabels") }
    static var renameColony: String { L10n.text("Kolonie umbenennen", table: "UILabels") }
    static var leaveColony: String { L10n.text("Kolonie verlassen", table: "UILabels") }
    static var payForBuilding: String { L10n.text("Bau bezahlen", table: "UILabels") }
    static var exportImport: String { L10n.text("Export und Import…", table: "UILabels") }
    static var changeProduction: String { L10n.text("Produktion ändern", table: "UILabels") }
    static var changeImprovement: String { L10n.text("Verbesserung ändern", table: "UILabels") }
    static var clearSpecialization: String { L10n.text("Spezialisierung löschen", table: "UILabels") }
    static var assignTeacher: String { L10n.text("Lehrer zuweisen", table: "UILabels") }
    static var removeTeacher: String { L10n.text("Lehrer entfernen", table: "UILabels") }
    static var assignWorker: String { L10n.text("Arbeiter zuweisen", table: "UILabels") }
    static var add: String { L10n.text("Hinzufügen", table: "UILabels") }
    static var up: String { L10n.text("Hoch", table: "UILabels") }
    static var down: String { L10n.text("Runter", table: "UILabels") }
    static var remove: String { L10n.text("Entfernen", table: "UILabels") }
    static var adoptBuildQueue: String { L10n.text("Bauliste übernehmen", table: "UILabels") }
    static var reset: String { L10n.text("Zurücksetzen", table: "UILabels") }
    static var putInFront: String { L10n.text("Vor die Kolonie stellen", table: "UILabels") }
    static var loadGoods: String { L10n.text("Waren laden", table: "UILabels") }
    static var unloadGoods: String { L10n.text("Waren entladen", table: "UILabels") }
    static var storage: String { L10n.text("Lager", table: "UILabels") }
    static var buildOrder: String { L10n.text("Bauauftrag", table: "UILabels") }
    static var none: String { L10n.text("Keiner", table: "UILabels") }
    static var buildTarget: String { L10n.text("Bauziel", table: "UILabels") }

    // MARK: - Chat

    static var chat: String { L10n.text("Chat", table: "UILabels") }
    static var noMessagesYet: String { L10n.text("Noch keine Nachrichten.", table: "UILabels") }
    static var message: String { L10n.text("Nachricht", table: "UILabels") }
    static var send: String { L10n.text("Senden", table: "UILabels") }

    // MARK: - Diplomacy

    static var diplomacy: String { L10n.text("Diplomatie", table: "UILabels") }
    static var tributeNegotiation: String { L10n.text("Tributverhandlung", table: "UILabels") }
    static var reject: String { L10n.text("Ablehnen", table: "UILabels") }
    static var accept: String { L10n.text("Akzeptieren", table: "UILabels") }
    static var incomingClauses: String { L10n.text("Eingehende Klauseln", table: "UILabels") }
    static var noClauses: String { L10n.text("Keine Klauseln.", table: "UILabels") }
    static var noDiplomaticProposal: String { L10n.text("Kein diplomatischer Vorschlag.", table: "UILabels") }
    static var counterProposal: String { L10n.text("Gegenvorschlag", table: "UILabels") }
    static var addClause: String { L10n.text("Klausel hinzufügen", table: "UILabels") }
    static var sendCounterProposal: String { L10n.text("Gegenvorschlag senden", table: "UILabels") }
    static var clauseType: String { L10n.text("Typ", table: "UILabels") }
    static var direction: String { L10n.text("Richtung", table: "UILabels") }
    static var weGive: String { L10n.text("Wir geben", table: "UILabels") }
    static var theyGive: String { L10n.text("Sie geben", table: "UILabels") }
    static var selectGoods: String { L10n.text("Ware auswählen", table: "UILabels") }
    static var amount: String { L10n.text("Menge", table: "UILabels") }
    static var selectColony: String { L10n.text("Kolonie auswählen", table: "UILabels") }
    static var selectUnit: String { L10n.text("Einheit auswählen", table: "UILabels") }
    static var selectTarget: String { L10n.text("Ziel auswählen", table: "UILabels") }

    // MARK: - Europe Panel

    static var europe: String { L10n.text("Europa", table: "UILabels") }
    static var recruit: String { L10n.text("Anwerben", table: "UILabels") }
    static var purchase: String { L10n.text("Kaufen", table: "UILabels") }
    static var ware: String { L10n.text("Ware", table: "UILabels") }
    static var buyPrice: String { L10n.text("Kauf", table: "UILabels") }
    static var sellPrice: String { L10n.text("Verkauf", table: "UILabels") }
    static var stock: String { L10n.text("Vorrat", table: "UILabels") }
    static var trend: String { L10n.text("Trend", table: "UILabels") }

    // MARK: - Login

    static var login: String { L10n.text("Anmelden", table: "UILabels") }
    static var connect: String { L10n.text("Verbinden", table: "UILabels") }
    static var server: String { L10n.text("Server", table: "UILabels") }
    static var port: String { L10n.text("Port", table: "UILabels") }
    static var username: String { L10n.text("Benutzername", table: "UILabels") }
    static var startGame: String { L10n.text("Spiel starten", table: "UILabels") }

    // MARK: - Game

    static var game: String { L10n.text("Spiel", table: "UILabels") }
    static var saveGame: String { L10n.text("Spiel speichern…", table: "UILabels") }
    static var about: String { L10n.text("Über Novaloria", table: "UILabels") }

    // MARK: - Stances (for diplomacy)

    static var peace: String { L10n.text("Frieden", table: "UILabels") }
    static var war: String { L10n.text("Krieg", table: "UILabels") }
    static var ceaseFire: String { L10n.text("Waffenstillstand", table: "UILabels") }
    static var alliance: String { L10n.text("Allianz", table: "UILabels") }
    static var uncontacted: String { L10n.text("Unbekannt", table: "UILabels") }

    // MARK: - Helper to get stance label

    static func stance(_ stance: String) -> String {
        switch stance {
        case "PEACE": return peace
        case "WAR": return war
        case "CEASE_FIRE": return ceaseFire
        case "ALLIANCE": return alliance
        case "UNCONTACTED": return uncontacted
        default: return stance
        }
    }
}

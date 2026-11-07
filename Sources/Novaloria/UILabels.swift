import Foundation

/// Centralized UI string localization for NovaloriaClient.
/// This struct provides all user-visible strings in German, preparing for future multi-language support.
/// When adding support for additional languages, this can be extended with language selection.

enum UILabels {
    // MARK: - General

    static let close = "Schließen"
    static let dismiss = "Schließen"
    static let cancel = "Abbrechen"
    static let ok = "OK"
    static let `default` = "Standard"

    // MARK: - Reports

    static let reports = "Berichte"
    static let nationSummary = "Nationsübersicht"
    static let highScores = "Bestenliste"
    static let noReportsAvailable = "Keine Berichte verfügbar."
    static let noEntries = "Keine Einträge."

    // Report headers
    static let player = "Spieler"
    static let nation = "Nation"
    static let score = "Punkte"
    static let units = "Einheiten"
    static let colonies = "Kolonien"
    static let settlements = "Siedlungen"
    static let military = "Militär"
    static let naval = "Flotte"
    static let gold = "Gold"
    static let sol = "Freiheitsbewusstsein"
    static let tax = "Steuer"
    static let stance = "Haltung"

    // MARK: - Report Panel

    static let coloniesReport = "Kolonien"
    static let unitTypesReport = "Einheiten"
    static let militaryReport = "Militär"
    static let navalReport = "Flotte"
    static let cargoReport = "Fracht"
    static let tradeReport = "Handel"
    static let foreignAffairsReport = "Außenpolitik"
    static let indianReport = "Ureinwohner"
    static let explorationReport = "Erkundung"
    static let turnReport = "Zugbericht"
    static let financialReport = "Finanzen"
    static let continentalCongressReport = "Kontinentalkongress"
    static let labourReport = "Arbeit"
    static let religiousReport = "Religion"
    static let productionReport = "Produktion"
    static let educationReport = "Ausbildung"
    static let requirementsReport = "Bedarf"
    static let historyReport = "Geschichte"

    // Filter and sort
    static let filterRows = "Zeilen filtern"
    static let sortAscending = "Sortieren ↑"
    static let sortDescending = "Sortieren ↓"
    static let sortHelp = "Zeilen nach der ersten Spalte sortieren"
    static let exportCSV = "CSV exportieren…"
    static let csvExportFailed = "CSV-Export fehlgeschlagen"
    static let requestFromServer = "Vom Server anfordern"

    // Empty states
    static let noColonies = "Keine Kolonien."
    static let noUnits = "Keine Einheiten."
    static let noNavalUnits = "Keine Schiffe."
    static let noMilitaryUnits = "Keine Militäreinheiten."
    static let noCargoCarriers = "Keine Frachter."
    static let empty = "leer"
    static let noMarketData = "Keine Marktdaten."
    static let noOtherEuropeanPowers = "Keine anderen europäischen Mächte."
    static let noNativePeoples = "Keine Ureinwohner."
    static let noMap = "Keine Karte."
    static let noGame = "Kein Spiel."
    static let noFoundingFathers = "Noch keine Gründerväter."
    static let inCongress = "Im Kongress"
    static let offered = "Angeboten"
    static let noWorkers = "Keine Arbeiter."
    static let noMissionaries = "Keine Missionare."
    static let noEstimatedProduction = "Keine geschätzte Produktion."
    static let noMaterialRequirements = "Keine Materialanforderungen."
    static let noEducation = "Keine Ausbildung im Gange."
    static let noEventsRecorded = "Keine Ereignisse aufgezeichnet."

    // Table headers
    static let name = "Name"
    static let population = "Bev."
    static let liberty = "Freiheit"
    static let bonus = "Bonus"
    static let unitType = "Einheitentyp"
    static let count = "Anzahl"
    static let unit = "Einheit"
    static let state = "Zustand"
    static let moves = "BP"
    static let location = "Standort"
    static let goods = "Ware"
    static let inStock = "Vorrat"
    static let buy = "Kauf"
    static let sell = "Verkauf"
    static let arrears = "Schulden"
    static let item = "Posten"
    static let value = "Wert"
    static let people = "Volk"
    static let tension = "Spannung"
    static let exploredTiles = "Erkundete Kacheln"
    static let explored = "Erkundet"
    static let turn = "Runde"
    static let currentPlayer = "Aktueller Spieler"
    static let yourGold = "Dein Gold"
    static let yourTax = "Deine Steuer"
    static let yourScore = "Deine Punkte"
    static let events = "Ereignisse"
    static let foundingFather = "Gründervater"
    static let student = "Schüler"
    static let teacher = "Lehrer"
    static let colony = "Kolonie"
    static let work = "Arbeit"
    static let perTurn = "Pro Runde"
    static let stored = "Vorhanden"
    static let required = "Benötigt"
    static let event = "Ereignis"
    static let source = "Quelle"
    static let type = "Typ"

    // MARK: - Colony Panel

    static let owner = "Besitzer"
    static let freedom = "Freiheit"
    static let immigration = "Einwanderung"
    static let production = "Produktion"
    static let productionBonus = "Produktionsbonus"
    static let workers = "Arbeiter"
    static let administration = "Verwaltung"
    static let renameColony = "Kolonie umbenennen"
    static let leaveColony = "Kolonie verlassen"
    static let payForBuilding = "Bau bezahlen"
    static let exportImport = "Export und Import…"
    static let changeProduction = "Produktion ändern"
    static let changeImprovement = "Verbesserung ändern"
    static let clearSpecialization = "Spezialisierung löschen"
    static let assignTeacher = "Lehrer zuweisen"
    static let removeTeacher = "Lehrer entfernen"
    static let assignWorker = "Arbeiter zuweisen"
    static let add = "Hinzufügen"
    static let up = "Hoch"
    static let down = "Runter"
    static let remove = "Entfernen"
    static let adoptBuildQueue = "Bauliste übernehmen"
    static let reset = "Zurücksetzen"
    static let putInFront = "Vor die Kolonie stellen"
    static let loadGoods = "Waren laden"
    static let unloadGoods = "Waren entladen"
    static let storage = "Lager"
    static let buildOrder = "Bauauftrag"
    static let none = "Keiner"
    static let buildTarget = "Bauziel"

    // MARK: - Chat

    static let chat = "Chat"
    static let noMessagesYet = "Noch keine Nachrichten."
    static let message = "Nachricht"
    static let send = "Senden"

    // MARK: - Diplomacy

    static let diplomacy = "Diplomatie"
    static let tributeNegotiation = "Tributverhandlung"
    static let reject = "Ablehnen"
    static let accept = "Akzeptieren"
    static let incomingClauses = "Eingehende Klauseln"
    static let noClauses = "Keine Klauseln."
    static let noDiplomaticProposal = "Kein diplomatischer Vorschlag."
    static let counterProposal = "Gegenvorschlag"
    static let addClause = "Klausel hinzufügen"
    static let sendCounterProposal = "Gegenvorschlag senden"
    static let clauseType = "Typ"
    static let direction = "Richtung"
    static let weGive = "Wir geben"
    static let theyGive = "Sie geben"
    static let selectGoods = "Ware auswählen"
    static let amount = "Menge"
    static let selectColony = "Kolonie auswählen"
    static let selectUnit = "Einheit auswählen"
    static let selectTarget = "Ziel auswählen"

    // MARK: - Europe Panel

    static let europe = "Europa"
    static let recruit = "Anwerben"
    static let purchase = "Kaufen"
    static let ware = "Ware"
    static let buyPrice = "Kauf"
    static let sellPrice = "Verkauf"
    static let stock = "Vorrat"
    static let trend = "Trend"

    // MARK: - Login

    static let login = "Anmelden"
    static let connect = "Verbinden"
    static let server = "Server"
    static let port = "Port"
    static let username = "Benutzername"
    static let startGame = "Spiel starten"

    // MARK: - Game

    static let game = "Spiel"
    static let saveGame = "Spiel speichern…"
    static let about = "Über Novaloria"

    // MARK: - Stances (for diplomacy)

    static let peace = "Frieden"
    static let war = "Krieg"
    static let ceaseFire = "Waffenstillstand"
    static let alliance = "Allianz"
    static let uncontacted = "Unbekannt"

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

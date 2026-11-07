import SwiftUI
import FreeColProtocol
import FreeColGame
import FreeColClient

private enum MarketTradeError: Error, CustomStringConvertible {
    case message(String)
    var description: String {
        switch self {
        case .message(let text): return text
        }
    }
}

@MainActor
@Observable
final class GameState {
    struct MapAnimationCue {
        enum Style {
            case move
            case attack
            case attackSuccess
            case attackFail
        }

        let sourceTileId: String
        let targetTileId: String
        let style: Style
    }

    enum Phase: CustomStringConvertible {
        case disconnected
        case connecting
        case reconnecting
        case login
        case lobby
        case inGame

        var description: String {
            switch self {
            case .disconnected: return "Getrennt"
            case .connecting: return "Verbindung wird hergestellt …"
            case .reconnecting: return "Verbindung wird wiederhergestellt …"
            case .login: return "Anmeldung"
            case .lobby: return "Warteraum"
            case .inGame: return "Im Spiel"
            }
        }
    }

    enum PendingServerDecisionType: String {
        case fountainOfYouth
        case indianDemand
        case lootCargo
        case firstContact
        case monarchAction
        case newLandName
        case newRegionName
        case nativeTrade
        case diplomacy
        case foundingFather
        case scoutReport
        case incite
    }

    enum MapOverlay: String, CaseIterable, Identifiable {
        case none
        case resources
        case tradeRoutes
        case paths

        var id: String { rawValue }

        var title: String {
            switch self {
            case .none: return "Keine"
            case .resources: return "Ressourcen"
            case .tradeRoutes: return "Handelsrouten"
            case .paths: return "Wege"
            }
        }
    }

    struct QueuedGameplayAction: Identifiable {
        let id: UUID
        let message: ParsedMessage

        var title: String {
            switch message.tag {
            case "move": return "Einheit bewegen"
            case "attack": return "Angreifen"
            case "endTurn": return "Zug beenden"
            case "abandonColony": return "Kolonie aufgeben"
            case "buildColony": return "Kolonie gründen"
            case "disbandUnit": return "Einheit auflösen"
            default: return message.tag
            }
        }
    }

    struct PendingServerDecision {
        let id = UUID()
        let type: PendingServerDecisionType
        let rawPayload: [String: String]
        var children: [ParsedMessage] = []

        /// `<goods>` children carried by a `lootCargo` prompt.
        var goodsChildren: [ParsedMessage] {
            children.filter { $0.tag == "goods" }
        }

        /// Remaining fountain-of-youth migrants to place.
        var migrantCount: Int {
            max(0, Int(rawPayload["migrants"] ?? "") ?? 0)
        }

        /// Inner `<nativeTrade>` node of a `nativeTrade` prompt.
        var nativeTradeChild: ParsedMessage? {
            children.first { $0.tag == "nativeTrade" }
        }

        var nativeTradeSession: NativeTradeSession {
            NativeTradeSession(nativeTradeChild: nativeTradeChild)
        }

        /// `<diplomaticTrade>` node of a `diplomacy` prompt.
        var diplomaticTradeChild: ParsedMessage? {
            children.first { $0.tag == "diplomaticTrade" }
        }

        var diplomaticTradeProposal: DiplomaticTradeProposal? {
            diplomaticTradeChild.map { DiplomaticTradeProposal(raw: $0) }
        }
    }

    /// A selectable loot stack from a `lootCargo` prompt.
    struct LootGoodsOption: Identifiable {
        var id: String { type }
        let type: String
        let amount: Int
    }

    /// A selectable emigrant slot from a `fountainOfYouth` prompt.
    struct EmigrantOption: Identifiable {
        var id: Int { slot }
        let slot: Int
        let unitType: String?
        let role: String?
    }

    /// A candidate founding father from a `chooseFoundingFather` prompt.
    struct FoundingFatherOption: Identifiable {
        var id: String { fatherId }
        let fatherId: String
        /// Offer category key (`trade`, `exploration`, `military`, `political`, `religious`).
        let typeKey: String
        let label: String
    }

    /// A pending `incite` confirmation.
    struct InciteOption {
        let unit: String
        let settlement: String
        let enemy: String
        let gold: Int
        let enemyName: String?
    }

    var phase: Phase = .disconnected
    var statusMessage: String = ""
    var errorMessage: String?
    var pendingServerDecision: PendingServerDecision?
    var hasPendingDecision: Bool {
        pendingServerDecision != nil
    }
    var pendingDecisionTitle: String {
        switch pendingServerDecision?.type {
        case .fountainOfYouth:
            return "Jungbrunnen"
        case .indianDemand:
            return "Forderung der Ureinwohner"
        case .lootCargo:
            return "Fracht erbeuten"
        case .firstContact:
            return "Erstkontakt"
        case .monarchAction:
            return "Monarch"
        case .newLandName:
            return "Neues Land benennen"
        case .newRegionName:
            return "Neue Region benennen"
        case .nativeTrade:
            return "Handel mit Ureinwohnern"
        case .diplomacy:
            return "Diplomatie"
        case .foundingFather:
            return "Kontinentalkongress"
        case .scoutReport:
            return "Erkundungsbericht"
        case .incite:
            return "Aufstand anzetteln"
        case .none:
            return ""
        }
    }

    var pendingDecisionSummary: String {
        guard let decision = pendingServerDecision else { return "" }
        switch decision.type {
        case .fountainOfYouth:
            return "Auswanderer zu platzieren: \(decision.migrantCount)"
        case .indianDemand:
            var parts: [String] = []
            if let type = decision.rawPayload["type"] {
                let displayName = type == "gold" ? "Gold" : (type == "model.goods.tribute" ? "Tribut" : goodsDisplayName(type))
                parts.append("Ware: \(displayName)")
            }
            if let amount = decision.rawPayload["amount"] { parts.append("Menge: \(amount)") }
            if let colonyId = decision.rawPayload["colony"] {
                parts.append("Kolonie: \(cachedGame?.colonies[colonyId]?.name ?? "Kolonie")")
            }
            if let unitId = decision.rawPayload["unit"] {
                parts.append("Einheit: \(cachedGame?.units[unitId].map(unitDisplayLabel) ?? "Einheit")")
            }
            return parts.isEmpty ? "Forderung der Ureinwohner prüfen." : parts.joined(separator: " · ")
        case .lootCargo:
            var parts: [String] = []
            if let winner = decision.rawPayload["winner"] { parts.append("Sieger: \(pendingObjectDisplayName(winner))") }
            if let loser = decision.rawPayload["loser"] { parts.append("Verlierer: \(pendingObjectDisplayName(loser))") }
            let goodsCount = decision.goodsChildren.count
            if goodsCount > 0 { parts.append("Warenstapel: \(goodsCount)") }
            return parts.isEmpty ? "Beute auswählen." : parts.joined(separator: " · ")
        case .firstContact:
            return firstContactMessage
        case .monarchAction:
            var parts: [String] = []
            if let action = decision.rawPayload["action"] { parts.append(monarchActionDescription(action)) }
            if let tax = decision.rawPayload["tax"] { parts.append("Steuern: \(tax)") }
            return parts.isEmpty ? "Der Monarch macht ein Angebot." : parts.joined(separator: " · ")
        case .newLandName:
            if let unitId = decision.rawPayload["unit"] {
                return "Einheit: \(cachedGame?.units[unitId].map(unitDisplayLabel) ?? "Einheit")"
            }
            return "Wähle einen Namen für das neue Land."
        case .newRegionName:
            return "Wähle einen Namen für die neue Region."
        case .nativeTrade:
            let session = decision.nativeTradeSession
            let buy = session.settlementToUnit.filter { $0.priceIsValid }.count
            let sell = session.unitToSettlement.filter { $0.priceIsValid }.count
            return "Kaufangebote: \(buy) · Verkaufsangebote: \(sell)"
        case .diplomacy:
            guard let proposal = decision.diplomaticTradeProposal else {
                return "Diplomatischen Vorschlag prüfen."
            }
            let context = proposal.context?.uppercased() == "TRIBUTE" ? "Tribut" : "Diplomatie"
            return "\(context): \(proposal.clauses.count) Klauseln"
        case .foundingFather:
            let options = pendingFoundingFathers
            return options.isEmpty
                ? "Wähle einen Gründervater aus."
                : "\(options.count) Gründerväter verfügbar."
        case .scoutReport:
            return scoutReportText
        case .incite:
            guard let incite = pendingIncite else { return "Aufstand anzetteln?" }
            let enemy = incite.enemyName
                ?? cachedGame?.players[incite.enemy]?.name
                ?? cachedGame?.players[incite.enemy]?.nationId.map(GameLabels.name)
                ?? "gegnerische Nation"
            return "Aufstand gegen \(enemy) anzetteln? Kosten: \(incite.gold) Gold."
        }
    }

    private func pendingObjectDisplayName(_ identifier: String) -> String {
        guard let game = cachedGame else { return "Einheit" }
        if let player = game.players[identifier] {
            return player.name ?? player.nationId.map(GameLabels.name) ?? "Spieler"
        }
        if let unit = game.units[identifier] { return unitDisplayLabel(unit) }
        if let colony = game.colonies[identifier] { return colony.name ?? "Kolonie" }
        return "Einheit"
    }

    /// User-facing German message for the monarchAction prompt.
    var monarchActionMessage: String {
        guard let decision = pendingServerDecision, decision.type == .monarchAction else { return "" }
        let action = decision.rawPayload["action"] ?? ""
        let tax = decision.rawPayload["tax"]
        let gold = decision.rawPayload["gold"]
        let bell = decision.rawPayload["bell"]

        if let template = decision.children.first(where: { $0.tag == "stringTemplate" }),
           let message = monarchActionTemplateText(template) {
            return "\(message) Akzeptieren?"
        }

        switch action.uppercased() {
        case "RAISE_TAX_ACT":
            if let tax { return "Der Monarch möchte die Steuern auf \(tax)% erhöhen. Akzeptieren?" }
            return "Der Monarch fordert eine Steuererhöhung. Akzeptieren?"
        case "RAISE_TAX_WAR":
            if let tax { return "Wegen des Kriegs fordert der Monarch eine Steuererhöhung auf \(tax)%. Bei Ablehnung droht ein Boykott. Akzeptieren?" }
            return "Wegen des Kriegs fordert der Monarch eine Steuererhöhung. Bei Ablehnung droht ein Boykott. Akzeptieren?"
        case "LOWER_TAX_ACT":
            if let tax { return "Der Monarch bietet an, die Steuern auf \(tax)% zu senken. Akzeptieren?" }
            return "Der Monarch bietet eine Steuersenkung an. Akzeptieren?"
        case "ADD_TO_ARMY":
            if let gold { return "Der Monarch fordert \(gold) Gold für die Armee. Bezahlen?" }
            return "Der Monarch fordert Gold für die Armee. Bezahlen?"
        case "ADD_TO_NAVY":
            if let gold { return "Der Monarch fordert \(gold) Gold für die Marine. Bezahlen?" }
            return "Der Monarch fordert Gold für die Marine. Bezahlen?"
        case "DECLARE_INDEPENDENCE":
            return "Der Monarch bietet an, die Unabhängigkeit zu erklären. Akzeptieren?"
        case "BELL":
            if let bell { return "Der Monarch verkündet eine neue Freiheit: \(bell). Akzeptieren?" }
            return "Der Monarch verkündet eine neue Freiheit. Akzeptieren?"
        default:
            return "Der Monarch hat eine Aktion: \(monarchActionDescription(action)). Akzeptieren?"
        }
    }

    private func monarchActionTemplateText(_ template: ParsedMessage) -> String? {
        guard let id = template.attributes["id"],
              let localizedTemplate = GameLabels.modelMessageText(id) else {
            return nil
        }

        var replacements: [String: String] = [:]
        for pair in template.children where pair.tag == "pair" {
            guard let key = pair.attributes["value"],
                  let value = pair.children.first(where: { $0.tag == "stringTemplate" }) else {
                continue
            }
            replacements[key] = monarchTemplateValue(value)
        }
        return formatModelMessage(localizedTemplate, replacements: replacements)
    }

    private func monarchTemplateValue(_ template: ParsedMessage) -> String {
        guard let id = template.attributes["id"] else { return "" }
        switch template.attributes["templateType"]?.uppercased() {
        case "NAME":
            return id
        case "TEMPLATE":
            guard let localizedTemplate = GameLabels.modelMessageText(id) else {
                return modelMessageReplacement(id)
            }
            var replacements: [String: String] = [:]
            for pair in template.children where pair.tag == "pair" {
                guard let key = pair.attributes["value"],
                      let value = pair.children.first(where: { $0.tag == "stringTemplate" }) else {
                    continue
                }
                replacements[key] = monarchTemplateValue(value)
            }
            return formatModelMessage(localizedTemplate, replacements: replacements)
        default:
            return modelMessageReplacement(id)
        }
    }

    /// User-facing German message for the firstContact prompt.
    var firstContactMessage: String {
        guard let decision = pendingServerDecision, decision.type == .firstContact else { return "" }
        let other = contactPlayerName(decision.rawPayload["other"], fallback: "einem unbekannten Volk")
        let playerName = contactPlayerName(decision.rawPayload["player"], fallback: localPlayerName ?? "Dein Spieler")
        let camps = decision.rawPayload["camps"].flatMap(Int.init)
        let settlementInfo = camps.map { " Das Volk besitzt \($0) \($0 == 1 ? "Siedlung" : "Siedlungen")." } ?? ""
        return "\(playerName) hat zum ersten Mal Kontakt mit \(other) aufgenommen.\(settlementInfo) Diplomatische Beziehungen herstellen?"
    }

    private func contactPlayerName(_ id: String?, fallback: String) -> String {
        guard let id, let player = cachedGame?.players[id] else { return fallback }
        if let name = player.name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return name
        }
        if let nation = player.nationId { return GameLabels.name(nation) }
        return fallback
    }

    var showsColonyWorkOrder: Bool {
        selectedUnit.map { !isNavalUnit($0) && canUnitWorkInColony($0) } ?? false
    }

    var showsEuropeTravelOrder: Bool {
        selectedUnit.map { isNavalUnit($0) } ?? false
    }
    /// User-facing German message for the indianDemand prompt.
    var indianDemandMessage: String {
        guard let decision = pendingServerDecision, decision.type == .indianDemand else { return "" }
        let type = decision.rawPayload["type"] ?? "Gold"
        let amount = decision.rawPayload["amount"] ?? "?"
        let colonyId = decision.rawPayload["colony"]
        let colony = colonyId.flatMap { cachedGame?.colonies[$0] }
        let colonyName = colony?.name ?? "eine Kolonie"
        let unitId = decision.rawPayload["unit"]
        let unit = unitId.flatMap { cachedGame?.units[$0] }
        let unitName = unit.map(unitDisplayLabel) ?? "eine Einheit"

        let typeDisplay: String
        switch type.lowercased() {
        case "gold": typeDisplay = "Gold"
        case "model.goods.tribute": typeDisplay = "Tribut"
        default: typeDisplay = goodsDisplayName(type)
        }
        return "Die Ureinwohner fordern \(amount) \(typeDisplay) als Tribut für \(unitName) in \(colonyName). Akzeptieren (Verlust: \(amount) \(typeDisplay)) oder ablehnen (Risiko: Angriff)?"
    }

    /// Parsed session for a pending `nativeTrade` prompt.
    var pendingNativeTrade: NativeTradeSession? {
        guard pendingServerDecision?.type == .nativeTrade else { return nil }
        return pendingServerDecision?.nativeTradeSession
    }

    /// Parsed proposal for a pending `diplomacy` prompt.
    var pendingDiplomacy: DiplomaticTradeProposal? {
        guard pendingServerDecision?.type == .diplomacy else { return nil }
        return pendingServerDecision?.diplomaticTradeProposal
    }

    /// Title and seeded default text for the text-entry prompts.
    var pendingTextPrompt: (title: String, defaultText: String)? {
        guard let decision = pendingServerDecision else { return nil }
        switch decision.type {
        case .newLandName:
            return (pendingDecisionTitle, decision.rawPayload["newLandName"] ?? "")
        case .newRegionName:
            return (pendingDecisionTitle, decision.rawPayload["newRegionName"] ?? "")
        default:
            return nil
        }
    }

    /// Turns a wire enum value such as `raise_tax_act` into `Raise tax act`.
    private func prettyEnum(_ raw: String) -> String {
        let spaced = raw.replacingOccurrences(of: "_", with: " ")
        guard let first = spaced.first else { return raw }
        return first.uppercased() + spaced.dropFirst()
    }

    private func monarchActionDescription(_ raw: String) -> String {
        switch raw.uppercased() {
        case "RAISE_TAX_ACT": return "Steuern erhöhen"
        case "RAISE_TAX_WAR": return "Steuern wegen des Kriegs erhöhen"
        case "LOWER_TAX_ACT": return "Steuern senken"
        case "ADD_TO_ARMY": return "Armee finanzieren"
        case "ADD_TO_NAVY": return "Marine finanzieren"
        case "DECLARE_INDEPENDENCE": return "Unabhängigkeit erklären"
        case "BELL": return "Freiheitsbewusstsein"
        case "NO_ACTION": return "Keine Aktion"
        case "DISPLEASURE": return "Missfallen"
        default: return prettyEnum(raw)
        }
    }

    /// Available loot stacks for a pending `lootCargo` prompt.
    var pendingLootOptions: [LootGoodsOption] {
        guard let decision = pendingServerDecision, decision.type == .lootCargo else { return [] }
        return decision.goodsChildren.compactMap { child in
            guard let type = child.attributes["type"] else { return nil }
            let amount = Int(child.attributes["amount"] ?? "") ?? 0
            return LootGoodsOption(type: type, amount: amount)
        }
    }

    /// Expanded emigrant slots (1...3) for a pending `fountainOfYouth` prompt.
    var pendingEmigrantOptions: [EmigrantOption] {
        guard let decision = pendingServerDecision, decision.type == .fountainOfYouth,
              let europe = localPlayer?.europe else { return [] }
        var options: [EmigrantOption] = []
        var slot = 1
        for recruit in europe.recruitable {
            for _ in 0..<max(1, recruit.number) {
                if slot > 3 { break }
                options.append(EmigrantOption(slot: slot, unitType: recruit.unitType, role: recruit.role))
                slot += 1
            }
            if slot > 3 { break }
        }
        return options
    }

    /// Candidate founding fathers offered by a `chooseFoundingFather` prompt.
    var pendingFoundingFathers: [FoundingFatherOption] {
        guard let decision = pendingServerDecision, decision.type == .foundingFather else {
            return []
        }
        // The server keys offers by FoundingFatherType key.
        let order = ["trade", "exploration", "military", "political", "religious"]
        var options: [FoundingFatherOption] = []
        for key in order {
            guard let fatherId = decision.rawPayload[key], !fatherId.isEmpty else { continue }
            options.append(FoundingFatherOption(fatherId: fatherId,
                                                typeKey: key,
                                                label: Self.foundingFatherLabel(fatherId)))
        }
        return options
    }

    /// Pending `incite` confirmation details.
    var pendingIncite: InciteOption? {
        guard let decision = pendingServerDecision, decision.type == .incite,
              let unit = decision.rawPayload["unit"],
              let settlement = decision.rawPayload["settlement"],
              let enemy = decision.rawPayload["enemy"] else { return nil }
        let gold = Int(decision.rawPayload["gold"] ?? "") ?? 0
        return InciteOption(unit: unit,
                            settlement: settlement,
                            enemy: enemy,
                            gold: gold,
                            enemyName: cachedGame?.players[enemy]?.name)
    }

    /// Human-readable outcome of a `scoutSpeakToChief` prompt.
    var scoutReportText: String {
        guard let decision = pendingServerDecision, decision.type == .scoutReport else {
            return ""
        }
        let result = decision.rawPayload["result"] ?? ""
        switch result {
        case "die": return "The chief had the scout killed."
        case "expert": return "The scout learned from the chief and became an expert."
        case "tales": return "The chief shared tales of the land."
        case "nothing": return "The chief had nothing to offer."
        default:
            if let amount = Int(result), amount > 0 {
                return "The chief gave beads worth \(amount) gold."
            } else if result.isEmpty {
                return "The scout spoke with the chief."
            }
            return "The chief's response: \(result)"
        }
    }

    /// Turns a founding-father id (`model.foundingFather.adamSmith`) into a label.
    nonisolated static func foundingFatherLabel(_ id: String) -> String {
        var name = id
        if let range = name.range(of: "model.foundingFather.") {
            name = String(name[range.upperBound...])
        }
        var result = ""
        for character in name {
            if character.isUppercase, !result.isEmpty {
                result.append(" ")
            }
            result.append(character)
        }
        guard !result.isEmpty else { return id }
        return result.prefix(1).uppercased() + result.dropFirst()
    }

    /// Latest `highScores` report from the server, if any.
    var highScoresReport: ParsedMessage?
    /// Latest `nationSummary` report from the server, if any.
    var nationSummaryReport: ParsedMessage?

    private(set) var client: FreeColClient?
    // Expose vacant players after connection, before login
    var vacantPlayers: ParsedMessage?
    var serverState: ServerState?
    private var bridge: ClientBridge?
    private var server: MockServer?
    private var javaServer: LocalJavaServer?
    private var javaServerStartTask: Task<Void, Never>?
    private var javaServerStartID: UUID?
    private var connectionAttemptID: UUID?
    private(set) var hostedGameDirectory: URL?
    private(set) var hostedSavegameName: String?
    var usesLocalServer: Bool { server != nil }
    private var messageLoopTask: Task<Void, Never>?
    private var localServerTask: Task<Void, Never>?
    private var gameStorage: Game?
    private(set) var cachedGame: Game? {
        get {
            // Model objects mutate in place; every derived UI query must observe their revision.
            _ = gameUpdateID
            return gameStorage
        }
        set { gameStorage = newValue }
    }
    var autoExecuteTradeRoutes: Bool = false
    var gameUpdateID: Int = 0
    var selectedUnitId: String?
    var selectedTileId: String?
    var isChoosingMoveDestination: Bool = false
    private(set) var movingUnitId: String?
    private var movementTask: Task<Void, Never>?
    private var movementAttempts: [String: Int] = [:]
    private var europeTravelOrders: Set<String> = []
    var isReadyToStart: Bool = false
    var localPlayerName: String?
    private var remoteHost: String?
    private var remotePort: Int?
    private var reconnectTask: Task<Void, Never>?
    private var userRequestedDisconnect = false
    var queuedGameplayActions: [QueuedGameplayAction] = []
    private var cachedLocalPlayerId: String?
    var localNationId: String?
    var localNationTypeId: String?
    var localColorValue: String?
    private var gameOptions: [String: String] = [:]
    private var seenModelMessageSignatures: Set<String> = []
    private var isEndingTurn: Bool = false
    private var saveRequestID: UUID?
    var isSavingGame: Bool { saveRequestID != nil }

    var canSaveGame: Bool {
        phase == .inGame && !usesLocalServer && isLocalPlayerAdmin
            && isLocalPlayersTurn && !isSavingGame && movingUnitId == nil && !isEndingTurn
    }

    func saveGame(to url: URL) {
        guard canSaveGame, let client, let game = cachedGame else {
            errorMessage = "Speichern ist nur als Spieladministrator im eigenen Zug auf einem Java-Server möglich."
            return
        }
        let requestID = UUID()
        saveRequestID = requestID
        errorMessage = nil
        statusMessage = "Spielstand wird vom Server angefordert…"
        Task {
            defer {
                if saveRequestID == requestID { saveRequestID = nil }
            }
            do {
                let reply = try await client.ask(message: ParsedMessage(
                    tag: "saveGame", attributes: [:], children: []
                ), timeout: 60)
                guard saveRequestID == requestID, cachedGame === game else { return }
                let data = try ServerSavegame.decode(reply)
                try data.write(to: url, options: .atomic)
                statusMessage = "Spiel gespeichert: \(url.lastPathComponent)"
            } catch {
                guard saveRequestID == requestID else { return }
                FreeColLogger.shared.error("Saving game failed: \(error)")
                errorMessage = "Spiel konnte nicht gespeichert werden: \(ServerErrorMessage.description(for: error))"
                if let protocolError = error as? FreeColProtocolError, case .timeout = protocolError {
                    errorMessage = "Keine Speicherbestätigung vom Server erhalten. Es wurde keine Datei gespeichert. Der Java-Server benötigt die FreeColClient-Speichererweiterung."
                }
                statusMessage = "Speichern fehlgeschlagen."
            }
        }
    }
    private var pendingEndTurnTurn: Int?
    private var endTurnToken: Int = 0
    private static let coreGameplayAskTimeout: TimeInterval = 30
    var incomingChatLog: [String] = []
    var isGameEnded: Bool = false
    /// Set when the server announces the local player has been eliminated.
    var isDefeated: Bool = false
    /// Set when the local player won (`gameEnded`); drives the victory overlay.
    var isVictorious: Bool = false
    var gameEndedHighScore: Bool = false
    /// True once the local player has already entered revenge mode.
    var isUndead: Bool = false
    var mapAnimationCue: MapAnimationCue?
    private var mapAnimationCueToken: Int = 0
    private var didAutoFocusInitialUnit: Bool = false

    // MARK: - UI state (Java-client parity)

    var showMapGrid: Bool = true
    var showFogOfWar: Bool = true
    var showBorders: Bool = true
    var showSettlementLabels: Bool = true
    var mapZoomScale: Double = 2.0
    var mapOverlay: MapOverlay = .none
    var showEuropePanel: Bool = false
    var showColonyPanel: Bool = false
    private var displayedColonyId: String?
    var showDebugPanel: Bool = false
    var showStatusPanel: Bool = false
    var showShortcutsHelp: Bool = false
    var showReportsPanel: Bool = false
    var showChatPanel: Bool = false
    var showPreferencesPanel: Bool = false
    var showColopediaPanel: Bool = false
    var requestedColopediaCategory: ColopediaCategory?
    var showIndependencePanel: Bool = false
    var showFindSettlementPanel: Bool = false
    var showTradeRoutesPanel: Bool = false
    var requestedMapScrollTileId: String?
    /// Report currently selected in the report browser.
    var requestedReport: ReportKind?
    /// Settlement the user asked to find (center map on).
    var findSettlementQuery: String?
    
    // Keyboard shortcuts manager
    private(set) var keyboardShortcutsManager: KeyboardShortcutsManager?
    
    init() {
        // Initialize keyboard shortcuts manager
        keyboardShortcutsManager = KeyboardShortcutsManager(gameState: self)
    }

    // Purchases tracking (client-side, like the Java client's purchases summary)
    var purchasesRecruits: Int = 0
    var purchasesTrained: Int = 0
    var purchasesTotal: Int = 0
    var salesTotal: Int = 0
    var purchasesNetProfit: Int { salesTotal - purchasesTotal }

    func requestMapScroll(to tileId: String) {
        requestedMapScrollTileId = tileId
    }

    func toggleMapGrid() { showMapGrid.toggle() }
    func toggleFogOfWar() { showFogOfWar.toggle() }
    func toggleBorders() { showBorders.toggle() }
    var canZoomMapIn: Bool { mapZoomScale < 5.0 }
    var canZoomMapOut: Bool { mapZoomScale > 0.5 }
    func zoomMap(in zoomIn: Bool) {
        let nextScale = zoomIn ? mapZoomScale * 1.4 : mapZoomScale / 1.4
        mapZoomScale = min(5.0, max(0.5, nextScale))
    }
    func resetMapZoom() { mapZoomScale = 2.0 }
    func openEuropePanel() {
        isChoosingMoveDestination = false
        closeTileActions()
        showEuropePanel = true
    }
    func closeEuropePanel() { showEuropePanel = false }
    func openColonyPanel() {
        guard let colony = selectedColony else {
            errorMessage = "Bitte eine Kolonie auf der Karte auswählen."
            return
        }
        displayedColonyId = colony.id
        if !selectedColonyUnits.contains(where: { $0.id == selectedUnitId }) {
            selectedUnitId = nil
        }
        closeTileActions()
        isChoosingMoveDestination = false
        showColonyPanel = true
    }
    /// Select a colony by id (e.g. from a spy result) and open its panel.
    func openColonyPanel(colonyId: String) {
        guard let colony = cachedGame?.colonies[colonyId],
              let tileId = colony.tileId, cachedGame?.tiles[tileId] != nil else {
            errorMessage = "Die Kolonie ist auf der Karte nicht verfügbar."
            return
        }
        displayedColonyId = colonyId
        selectedTileId = tileId
        openColonyPanel()
    }
    func closeColonyPanel() {
        showColonyPanel = false
        displayedColonyId = nil
    }

    func selectPreviousColony() { cycleColony(offset: -1) }
    func selectNextColony() { cycleColony(offset: 1) }

    private func cycleColony(offset: Int) {
        let colonies = coloniesForNavigation
        guard !colonies.isEmpty else {
            errorMessage = "Keine eigenen Kolonien verfügbar."
            return
        }
        let currentIndex = colonies.firstIndex { $0.id == selectedColony?.id }
        let index = currentIndex.map { ($0 + offset + colonies.count) % colonies.count }
            ?? (offset > 0 ? 0 : colonies.count - 1)
        openColonyPanel(colonyId: colonies[index].id)
    }
    func openDebugPanel() { showDebugPanel = true }
    func closeDebugPanel() { showDebugPanel = false }
    
    // MARK: - Keyboard Shortcuts Support
    
    /// Attempt to build a colony using keyboard shortcut
    func attemptBuildColonyWithShortcut() {
        guard canBuildSelectedColony else {
            errorMessage = "Kann hier keine Kolonie bauen. Benötige Kolonist auf geeignetem Gelände."
            return
        }
        buildColony(name: suggestedColonyName)
    }
    
    /// Attempt to build a road using keyboard shortcut
    func attemptBuildRoadWithShortcut() {
        statusMessage = "Straßenbau ist noch nicht implementiert."
    }
    
    /// Attempt to attack using keyboard shortcut
    func attemptAttackWithShortcut(ranged: Bool) {
        guard let tileId = selectedTileId else {
            errorMessage = "Kein Ziel für Angriff ausgewählt."
            return
        }
        
        if ranged && canAttackSelectedUnitRanged(onTile: tileId) {
            requestAttack(onTile: tileId, ranged: true)
        } else if !ranged && canAttackSelectedUnitMelee(onTile: tileId) {
            requestAttack(onTile: tileId, ranged: false)
        } else {
            errorMessage = ranged ? "Fernkampf nicht möglich." : "Nahkampf nicht möglich."
        }
    }
    
    /// Embark selected unit on default carrier
    func embarkSelectedUnitOnDefaultCarrier() {
        guard let carrierId = defaultEmbarkCarrierId else {
            errorMessage = "Kein Transportschiff zum Einsteigen verfügbar."
            return
        }
        embarkSelectedUnit(onCarrier: carrierId)
    }
    
    /// Center map on selected unit
    func centerMapOnSelectedUnit() {
        if let unitTileId = selectedUnitTileId {
            requestMapScroll(to: unitTileId)
        }
    }
    

    
    /// Show reports panel
    func showReports() {
        requestedReport = .turn
        showReportsPanel = true
    }
    
    /// Show chat panel
    func showChat() {
        showChatPanel = true
    }
    
    /// Toggle find settlement panel
    func toggleFindSettlement() {
        showFindSettlementPanel.toggle()
    }
    
    /// Prompt to save game
    func promptSaveGame() {
        if canSaveGame {
            statusMessage = "Spiel speichern... (Noch nicht implementiert)"
        } else {
            errorMessage = "Spiel kann derzeit nicht gespeichert werden."
        }
    }
    
    /// Toggle shortcuts help display
    func toggleShortcutsHelp() {
        showShortcutsHelp.toggle()
    }

    var isLocalPlayerAdmin: Bool {
        guard let game = cachedGame,
              let localPlayerId = resolveLocalPlayerId(),
              let player = game.players[localPlayerId] else {
            return false
        }
        return player.admin
    }

    /// All players in the lobby/game, sorted by name (for the player table).
    var lobbyPlayers: [Player] {
        guard let game = cachedGame else { return [] }
        return game.players.values.sorted { ($0.name ?? $0.id) < ($1.name ?? $1.id) }
    }

    /// Server-authoritative value for an option id from the `updateGameOptions`
    /// echo, when available.
    func serverOptionValue(id: String) -> String? {
        cachedGame?.optionValues[id]
    }

    var availableLobbyNationIds: [String] {
        guard phase == .lobby else { return [] }
        return cachedGame?.nationStates.compactMap { id, availability in
            availability == "AVAILABLE" ? id : nil
        }.sorted() ?? []
    }

    var isLocalPlayersTurn: Bool {
        guard let game = cachedGame,
              let localPlayerId = resolveLocalPlayerId() else {
            return false
        }
        // The server writes `currentPlayer` only once a turn is underway; when
        // it is still unset (mid-game join, or a local game) assume it is our
        // turn so turn-bound actions such as "End Turn" stay available.
        guard let currentPlayerId = game.currentPlayerId else { return true }
        return currentPlayerId == localPlayerId
    }

    /// Name of the current player (whose turn it is), if available.
    var currentPlayerName: String? {
        guard let game = cachedGame,
              let currentPlayerId = game.currentPlayerId else { return nil }
        return game.players[currentPlayerId]?.name
    }

    /// Human-readable description of the current turn status.
    var turnStatusDescription: String {
        let turnNumber = cachedGame?.turn.number ?? 0
        if isLocalPlayersTurn {
            return "Dein Zug (Zug #\(turnNumber))"
        } else if let name = currentPlayerName {
            return "Warte auf \(name) (Zug #\(turnNumber))"
        } else {
            return "Zug #\(turnNumber)"
        }
    }

    var localPlayerId: String? {
        resolveLocalPlayerId()
    }

    var localPlayer: Player? {
        guard let game = cachedGame,
              let localPlayerId = resolveLocalPlayerId() else {
            return nil
        }
        return game.players[localPlayerId]
    }

    var europeUnits: [FreeColGame.Unit] {
        guard let game = cachedGame,
              let localPlayerId = resolveLocalPlayerId(),
              let europeId = localPlayer?.europe?.id else {
            return []
        }
        return game.units.values
            .filter { $0.owner == localPlayerId && $0.location == europeId }
            .sorted { $0.id < $1.id }
    }

    var europeCarrierUnits: [FreeColGame.Unit] {
        europeUnits.filter { isCarrierUnit($0) }
    }

    /// Naval flag preferring the specification ability, heuristic as fallback.
    func isNavalUnit(_ unit: FreeColGame.Unit) -> Bool {
        if let type = unit.unitType,
           let value = cachedGame?.specification?.isNaval(unitType: type) {
            return value
        }
        return UnitTypeTraits.isNaval(unitType: unit.unitType, role: unit.role)
    }

    /// Carrier flag preferring the specification ability, heuristic as fallback.
    func isCarrierUnit(_ unit: FreeColGame.Unit) -> Bool {
        if let type = unit.unitType,
           let value = cachedGame?.specification?.carriesUnits(unitType: type) {
            return value
        }
        return UnitTypeTraits.isCarrier(unitType: unit.unitType, role: unit.role)
    }

    var localPlayerMarketData: [MarketData] {
        guard let market = localPlayer?.market else { return [] }
        return market.data.values.sorted { ($0.goodsType ?? "") < ($1.goodsType ?? "") }
    }

    // MARK: Phase 57 - founding fathers, reports, event log

    /// Founding fathers already in the local player's congress.
    var localPlayerFoundingFathers: [String] {
        localPlayer?.foundingFathers ?? []
    }

    /// Founding fathers currently offered to the local player.
    var localPlayerOfferedFathers: [String] {
        localPlayer?.offeredFathers ?? []
    }

    /// The father the local player is currently electing.
    var localPlayerCurrentFather: String? {
        localPlayer?.currentFather
    }

    /// Server model messages for the local player (event log / turn report).
    var localPlayerModelMessages: [ModelMessage] {
        localPlayer?.modelMessages ?? []
    }

    func modelMessageText(_ message: ModelMessage) -> String {
        func replacement(_ key: String) -> String? {
            message.replacements[key].map(modelMessageReplacement)
        }

        let colony = replacement("%colony%")
            ?? message.source.flatMap { cachedGame?.colonies[$0]?.name }
            ?? "unbekannte Kolonie"

        let messageId = message.id.hasSuffix(".description")
            ? String(message.id.dropLast(".description".count))
            : message.id

        switch messageId {
        case "model.colony.famineFeared":
            let turns = replacement("%number%") ?? "?"
            return "In \(colony) wird eine Hungersnot befürchtet. Die Nahrung reicht nur noch für \(turns) Züge."
        case "model.colony.starving":
            return "\(colony) verhungert."
        case "model.colony.colonistStarved":
            return "In \(colony) ist ein Kolonist verhungert!"
        case "model.colony.colonyStarved":
            return "Der letzte Kolonist in \(colony) ist verhungert; die Kolonie ist verlassen."
        case "model.colony.newColonist":
            return "Ein neuer Kolonist ist in \(colony) eingetroffen."
        case "model.unit.experience":
            let oldUnit = replacement("%oldName%") ?? "Ein Kolonist"
            let newUnit = replacement("%unit%") ?? "ein Experte"
            return "Ein \(oldUnit) in \(colony) ist durch Erfahrung zum Experten (\(newUnit)) geworden."
        default:
            break
        }

        let rumourPrefix = "model.lostCityRumour."
        if messageId.hasPrefix(rumourPrefix) {
            let result = String(messageId.dropFirst(rumourPrefix.count))
            let money = replacement("%money%") ?? "?"
            switch result {
            case "burialGround":
                return "Eure Einheit hat eine heilige Begräbnisstätte betreten."
            case "cibola":
                let city = replacement("%city%") ?? "eine der Sieben Goldenen Städte"
                return "Ihr habt \(city) entdeckt und einen Schatz im Wert von \(money) Gold gefunden."
            case "colonist":
                return "Überlebende einer verlorenen Kolonie schließen sich Eurer Expedition an."
            case "expeditionVanishes":
                return "Eure Expedition ist spurlos verschwunden!"
            case "fountainOfYouth", "fountainOfYouth.noEurope":
                return "Ihr habt den Jungbrunnen entdeckt!"
            case "learn":
                let unit = replacement("%unit%") ?? "Eure Einheit"
                let type = replacement("%type%") ?? "einen erfahrenen Beruf"
                return "\(unit) hat Erfahrung gesammelt und ist jetzt \(type)."
            case "ruins", "ruins.mounds":
                return "Ihr habt Ruinen mit Schätzen im Wert von \(money) Gold entdeckt."
            case "tribalChief", "tribalChief.mounds":
                return "Ein Häuptling beschenkt Euch mit Schmuck im Wert von \(money) Gold."
            default:
                if result.hasPrefix("nothing.") {
                    return "Das Gerücht über eine verlorene Stadt war nichts als ein Gerücht."
                }
                return "Ein Gerücht über eine verlorene Stadt wurde erforscht."
            }
        }

        if let template = GameLabels.modelMessageText(messageId) {
            return formatModelMessage(template, replacements: message.replacements)
        }
        return modelMessageFallback(message)
    }

    private func formatModelMessage(_ template: String, replacements: [String: String]) -> String {
        var text = template
        for (key, value) in replacements.sorted(by: { $0.key.count > $1.key.count }) {
            let resolved = modelMessageReplacement(value)
            guard !resolved.isEmpty else { continue }
            text = text.replacingOccurrences(of: key, with: resolved)
        }
        // Never expose unresolved FreeCol template syntax to the player.
        if let expression = try? NSRegularExpression(pattern: "%[A-Za-z0-9_.-]+%") {
            let range = NSRange(text.startIndex..., in: text)
            for match in expression.matches(in: text, range: range).reversed() {
                guard let matchRange = Range(match.range, in: text) else { continue }
                text.replaceSubrange(matchRange, with: "unbekannt")
            }
        }
        return text
    }

    private func modelMessageReplacement(_ rawValue: String) -> String {
        let value = rawValue.hasSuffix(".name") ? String(rawValue.dropLast(".name".count)) : rawValue
        if value.hasPrefix("model.unit.") { return unitDisplayName(value) }
        if value.hasPrefix("model.goods.") { return goodsDisplayName(value) }
        if value.hasPrefix("model.building.") { return buildingDisplayName(value) }
        if value.hasPrefix("model.foundingFather.") { return Self.foundingFatherLabel(value) }
        if value.hasPrefix("model.") { return GameLabels.name(value) }
        return rawValue
    }

    private func modelMessageFallback(_ message: ModelMessage) -> String {
        let type = message.messageType?.uppercased() ?? ""
        let category: String
        switch type {
        case "BUILDING_COMPLETED": category = "Gebäude fertiggestellt"
        case "COMBAT_RESULT": category = "Kampfergebnis"
        case "DEMANDS": category = "Forderung der Ureinwohner"
        case "DISASTERS": category = "Katastrophe"
        case "FOREIGN_DIPLOMACY": category = "Diplomatie"
        case "GIFT_GOODS": category = "Geschenk"
        case "GOODS_MOVEMENT": category = "Warenbewegung"
        case "GOVERNMENT_EFFICIENCY": category = "Regierungseffizienz"
        case "LOST_CITY_RUMOUR": category = "Gerücht über eine verlorene Stadt"
        case "MARKET_PRICES": category = "Marktpreis"
        case "MISSING_GOODS": category = "Fehlende Waren"
        case "SONS_OF_LIBERTY": category = "Söhne der Freiheit"
        case "TUTORIAL": category = "Spielhinweis"
        case "UNIT_ADDED": category = "Neue Einheit"
        case "UNIT_ARRIVED": category = "Einheit angekommen"
        case "UNIT_DEMOTED": category = "Einheit zurückgestuft"
        case "UNIT_IMPROVED": category = "Einheit befördert"
        case "UNIT_LOST": category = "Einheit verloren"
        case "UNIT_REPAIRED": category = "Einheit repariert"
        case "WAREHOUSE_CAPACITY": category = "Lagerbestand"
        case "WARNING": category = "Warnung"
        default: category = "Spielmeldung"
        }

        let display = modelMessageObjectName(message.display)
        let source = message.display == message.source ? nil : modelMessageObjectName(message.source)
        let context = [display, source].compactMap { $0 }
        guard !context.isEmpty else { return category + "." }
        return "\(category): \(context.joined(separator: " · "))."
    }

    private func modelMessageObjectName(_ objectId: String?) -> String? {
        guard let objectId, !objectId.isEmpty else { return nil }
        let value = objectId.hasSuffix(".name") ? String(objectId.dropLast(".name".count)) : objectId
        if value.hasPrefix("model.goods.") { return goodsDisplayName(value) }
        if value.hasPrefix("model.unit.") { return unitDisplayName(value) }
        if value.hasPrefix("model.building.") { return buildingDisplayName(value) }

        if let unit = cachedGame?.units[value] {
            return unit.name ?? unit.unitType.map(modelMessageReplacement)
        }
        if let colonRange = value.range(of: ":"), value[..<colonRange.lowerBound] == "unit" {
            let numericId = String(value[colonRange.upperBound...])
            if let unit = cachedGame?.units.values.first(where: { $0.id.hasSuffix(":" + numericId) }) {
                return unit.name ?? unit.unitType.map(modelMessageReplacement) ?? "Einheit"
            }
            return "Einheit"
        }
        if let colony = cachedGame?.colonies[value] { return colony.name ?? "Kolonie" }
        if value.hasPrefix("model.") { return GameLabels.name(value) }
        return nil
    }

    func foundingFatherDisplayName(_ id: String?) -> String {
        guard let id else { return "—" }
        return Self.foundingFatherLabel(id)
    }

    /// Ask the server for the high-score table (`HighScoresMessage`).
    func requestHighScores(key: String = "model.option.score") {
        guard phase == .inGame || phase == .lobby else { return }
        Task {
            do {
                let msg = ParsedMessage(tag: "highScores", attributes: ["key": key], children: [])
                let reply = try await client?.ask(message: msg)
                if let reply, let payload = reply.children.first {
                    highScoresReport = payload
                }
                statusMessage = "Bestenliste wird angefordert."
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    /// Ask the server for a nation summary for one player.
    func requestNationSummary(playerId: String) {
        guard !playerId.isEmpty else { return }
        Task {
            do {
                let msg = ParsedMessage(tag: "nationSummary",
                                        attributes: ["player": playerId],
                                        children: [])
                let reply = try await client?.ask(message: msg)
                if let reply, let payload = reply.children.first {
                    // The reply wraps the summary; unwrap the inner <nationSummary>.
                    nationSummaryReport = payload.children.first { $0.tag == "nationSummary" } ?? payload
                }
                statusMessage = "Nationsübersicht wird angefordert."
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    /// Client-side recorded market sale-price history per goods type.
    var marketPriceHistory: [String: [(turn: Int, price: Int)]] = [:]
    /// Client-side recorded market buy-price history per goods type.
    var marketBuyPriceHistory: [String: [(turn: Int, price: Int)]] = [:]
    /// Price trend indicators per goods type (up/down/stable).
    var marketPriceTrends: [String: PriceTrend] = [:]

    enum PriceTrend: String, Sendable {
        case up = "↑"
        case down = "↓"
        case stable = "→"
    }

    /// Append an aligned buy/sale price snapshot whenever either price changes.
    func recordMarketSnapshot() {
        guard phase == .inGame,
              let game = cachedGame else { return }
        let currentTurn = game.turn.number
        for entry in localPlayerMarketData {
            guard let goodsType = entry.goodsType else { continue }
            let prices = MarketPricing.prices(for: entry, specification: game.specification)
            var buySeries = marketBuyPriceHistory[goodsType] ?? []
            var saleSeries = marketPriceHistory[goodsType] ?? []
            guard buySeries.last?.price != prices.costToBuy || saleSeries.last?.price != prices.paidForSale else {
                continue
            }
            buySeries.append((turn: currentTurn, price: prices.costToBuy))
            saleSeries.append((turn: currentTurn, price: prices.paidForSale))
            if buySeries.count > 60 {
                buySeries.removeFirst(buySeries.count - 60)
            }
            if saleSeries.count > 60 {
                saleSeries.removeFirst(saleSeries.count - 60)
            }
            marketBuyPriceHistory[goodsType] = buySeries
            marketPriceHistory[goodsType] = saleSeries
            updatePriceTrend(for: goodsType, buySeries: buySeries, saleSeries: saleSeries)
        }
    }

    /// Calculate price trend based on recent price movements.
    private func updatePriceTrend(for goodsType: String, buySeries: [(turn: Int, price: Int)], saleSeries: [(turn: Int, price: Int)]) {
        let windowSize = 5
        let recentBuyPrices = buySeries.suffix(windowSize).map { $0.price }
        let recentSalePrices = saleSeries.suffix(windowSize).map { $0.price }
        
        let allRecent = recentBuyPrices + recentSalePrices
        guard allRecent.count >= 2 else {
            marketPriceTrends[goodsType] = .stable
            return
        }
        
        let first = allRecent.first!
        let last = allRecent.last!
        
        if last > first {
            marketPriceTrends[goodsType] = .up
        } else if last < first {
            marketPriceTrends[goodsType] = .down
        } else {
            marketPriceTrends[goodsType] = .stable
        }
    }

    /// Derived buy/sale prices for one goods type (Java `MarketData.price()`).
    func marketPrices(for goodsTypeId: String?) -> (costToBuy: Int, paidForSale: Int) {
        guard let game = cachedGame,
              let entry = localPlayer?.market?.entry(for: goodsTypeId) else {
            return (0, 0)
        }
        return MarketPricing.prices(for: entry, specification: game.specification)
    }
    
    /// Get the current price trend for a goods type.
    func marketPriceTrend(for goodsTypeId: String?) -> PriceTrend? {
        guard let goodsTypeId else { return nil }
        return marketPriceTrends[goodsTypeId]
    }

    var canEndTurn: Bool {
        phase == .inGame && isLocalPlayersTurn && !isGameEnded && !isEndingTurn && !isSavingGame && movingUnitId == nil
    }

    /// True while the local player still has an active unit with moves left.
    var hasUnmovedLocalUnits: Bool {
        !unitsAwaitingOrders.isEmpty
    }

    /// A colony name that is not already in use, seeded into the build-colony field.
    var suggestedColonyName: String {
        guard let game = cachedGame else { return "New Colony" }
        let existing = Set(game.colonies.values.compactMap { $0.name?.lowercased() })
        let base = "New Amsterdam"
        if !existing.contains(base.lowercased()) { return base }
        var index = 2
        while existing.contains("\(base) \(index)".lowercased()) { index += 1 }
        return "\(base) \(index)"
    }

    var canBuildSelectedColony: Bool {
        guard phase == .inGame,
              isLocalPlayersTurn,
              let game = cachedGame,
              let unitId = selectedUnitId,
              let unit = game.units[unitId],
              let localPlayerId = resolveLocalPlayerId(),
              unit.owner == localPlayerId,
              let loc = unit.location,
              unit.movesLeft > 0,
              unit.state == .active,
              unitCanFoundColony(unit, in: game) else {
            return false
        }
        guard game.colonies.first(where: { $0.value.tileId == loc }) == nil,
              let tile = game.tiles[loc],
              isBuildableColonyTile(tile) else {
            return false
        }
        return true
    }

    private func unitCanFoundColony(_ unit: FreeColGame.Unit, in game: Game) -> Bool {
        guard let unitType = unit.unitType else { return false }
        if game.specification?.unitTypes[unitType] != nil {
            return game.specification?.hasAbility(
                "model.ability.foundColony", unitType: unitType
            ) == true
        }
        // Older/partial game snapshots may omit the specification entirely.
        // Keep the previous best-effort behavior for those snapshots only.
        return unitType.localizedCaseInsensitiveContains("colonist")
    }

    var canJoinSelectedColony: Bool {
        guard showsColonyWorkOrder,
              phase == .inGame,
              isLocalPlayersTurn,
              let game = cachedGame,
              let unitId = selectedUnitId,
              let unit = game.units[unitId],
              let localPlayerId = resolveLocalPlayerId(),
              unit.owner == localPlayerId,
              let tileId = selectedTileId,
              let colony = game.colonies.values.first(where: { $0.tileId == tileId }),
              colony.owner == localPlayerId,
              unit.location == tileId,
              unit.movesLeft > 0,
              unit.state == .active else {
            return false
        }
        return true
    }

    var canDisembarkSelectedUnit: Bool {
        guard phase == .inGame,
              isLocalPlayersTurn,
              movingUnitId == nil,
              let game = cachedGame,
              let unitId = selectedUnitId,
              let unit = game.units[unitId],
              let localPlayerId = resolveLocalPlayerId(),
              unit.owner == localPlayerId,
              !isNavalUnit(unit),
              let carrier = selectedUnitCarrier,
              carrier.owner == localPlayerId,
              isCarrierUnit(carrier) else {
            return false
        }
        if selectedUnitCanDisembarkInPlace { return true }
        guard canChooseMoveDestination, let source = resolveUnitTileId(carrier, in: game) else { return false }
        return game.neighborTileIds(of: source).contains { tileId in
            guard let tile = game.tiles[tileId], tile.type != nil, !isWaterTile(tile, in: game) else { return false }
            return nextStepTowardDestination(for: unit, destinationTileId: tileId, in: game) == tileId
        }
    }

    private var selectedUnitCanDisembarkInPlace: Bool {
        guard let game = cachedGame, let location = selectedUnitCarrier?.location else { return false }
        if game.players.values.contains(where: { $0.europe?.id == location }) { return true }
        guard let tile = game.tiles[location], tile.type != nil else { return false }
        return !isWaterTile(tile, in: game)
    }

    var selectedUnitDisembarkHint: String? {
        guard selectedUnitCarrier != nil else { return nil }
        if !isLocalPlayersTurn { return "Ausschiffen ist nur im eigenen Zug möglich." }
        if selectedUnitCanDisembarkInPlace { return "Im Hafen kann die Einheit direkt von Bord gehen." }
        if selectedUnitTileId == nil { return "Während der Überfahrt ist Ausschiffen nicht möglich." }
        if selectedUnit?.movesLeft == 0 {
            return "Zum Anlanden fehlen Bewegungspunkte. Bitte bis zum nächsten Zug warten."
        }
        return "Zum Anlanden ein benachbartes, freies Landfeld wählen; alternativ dort rechtsklicken."
    }

    var canDisbandSelectedUnit: Bool {
        selectedUnitDisbandDisabledReason == nil
    }

    var selectedUnitDisbandDisabledReason: String? {
        guard phase == .inGame else { return "Einheiten können nur im laufenden Spiel aufgelöst werden." }
        guard isLocalPlayersTurn else { return "Einheiten können nur im eigenen Zug aufgelöst werden." }
        guard movingUnitId == nil, !isSavingGame else {
            return "Während einer laufenden Aktion oder des Speicherns nicht möglich."
        }
        guard let game = cachedGame, let unit = selectedUnit,
              let localPlayerId = resolveLocalPlayerId(), unit.owner == localPlayerId else {
            return "Wähle eine eigene Einheit aus."
        }
        // Avoid disbanding carriers that currently transport units.
        if game.units.values.contains(where: { $0.location == unit.id }) {
            return "Transporter mit Passagieren können nicht aufgelöst werden."
        }
        return nil
    }

    var canSetDestinationToSelectedTile: Bool {
        guard let tileId = selectedTileId else { return false }
        return canSetSelectedUnitDestination(to: tileId)
    }

    var canClearSelectedUnitDestination: Bool {
        guard phase == .inGame,
              isLocalPlayersTurn,
              movingUnitId == nil, !isSavingGame,
              let game = cachedGame,
              let unitId = selectedUnitId,
              let unit = game.units[unitId],
              let localPlayerId = resolveLocalPlayerId(),
              unit.owner == localPlayerId else {
            return false
        }
        return unit.destination != nil
    }

    var canCashInSelectedTreasureTrain: Bool {
        guard phase == .inGame,
              isLocalPlayersTurn,
              let game = cachedGame,
              let unitId = selectedUnitId,
              let unit = game.units[unitId],
              let localPlayerId = resolveLocalPlayerId(),
              unit.owner == localPlayerId else {
            return false
        }
        return unit.treasureAmount > 0
    }

    var embarkCarrierOptions: [FreeColGame.Unit] {
        guard let game = cachedGame,
              let unitId = selectedUnitId,
              let selectedUnit = game.units[unitId],
              let localPlayerId = resolveLocalPlayerId(),
              selectedUnit.owner == localPlayerId,
              let selectedTile = selectedUnit.location else {
            return []
        }
        return game.units.values
            .filter {
                guard $0.id != selectedUnit.id,
                      $0.owner == localPlayerId,
                      let carrierLocation = $0.location,
                      isLikelyCarrier($0, in: game) else {
                    return false
                }
                return carrierLocation == selectedTile
                    || (game.tiles[selectedTile] != nil
                        && game.tiles[carrierLocation] != nil
                        && attackDirection(fromTileId: selectedTile, toTileId: carrierLocation, in: game) != nil)
            }
            .sorted { $0.id < $1.id }
    }

    var defaultEmbarkCarrierId: String? {
        let options = embarkCarrierOptions
        guard options.count == 1 else { return nil }
        return options[0].id
    }

    var selectedUnit: FreeColGame.Unit? {
        guard let game = cachedGame, let unitId = selectedUnitId else { return nil }
        return game.units[unitId]
    }

    /// Tile the selected unit currently occupies (resolving carriers/colonies).
    /// Used by the map to keep the camera on the active unit.
    var selectedUnitTileId: String? {
        guard let game = cachedGame, let unit = selectedUnit else { return nil }
        return resolveUnitTileId(unit, in: game)
    }

    var selectedUnitIsCarrier: Bool {
        guard let game = cachedGame, let unit = selectedUnit else { return false }
        return isLikelyCarrier(unit, in: game)
    }

    var selectedUnitCargoUnits: [FreeColGame.Unit] {
        guard let game = cachedGame,
              let carrier = selectedUnit,
              isLikelyCarrier(carrier, in: game) else {
            return []
        }
        return game.units.values
            .filter {
                $0.id != carrier.id
                && $0.owner == carrier.owner
                // Sharing a tile (notably a colony tile) does not mean a unit
                // is aboard. The carrier's ID is the authoritative cargo location.
                && $0.location == carrier.id
            }
            .sorted { $0.id < $1.id }
    }

    var selectedUnitCarrier: FreeColGame.Unit? {
        guard let game = cachedGame,
              let unit = selectedUnit,
              let carrierId = unit.location,
              let carrier = game.units[carrierId] else {
            return nil
        }
        return carrier
    }

    var selectedColony: Colony? {
        guard let game = cachedGame else { return nil }
        if showColonyPanel, let displayedColonyId {
            return game.colonies[displayedColonyId]
        }
        guard let tileId = selectedTileId else { return nil }
        if let tile = game.tiles[tileId],
           let settlementId = tile.settlement,
           let colony = game.colonies[settlementId] {
            return colony
        }
        return game.colonies.values.first(where: { $0.tileId == tileId })
    }

    var coloniesForNavigation: [Colony] {
        guard let game = cachedGame, let owner = resolveLocalPlayerId() else { return [] }
        return game.colonies.values.filter {
            $0.owner == owner && $0.tileId.flatMap { game.tiles[$0] } != nil
        }.sorted {
            let comparison = ($0.name ?? $0.id).localizedStandardCompare($1.name ?? $1.id)
            return comparison == .orderedSame ? $0.id < $1.id : comparison == .orderedAscending
        }
    }

    var canNavigateColonies: Bool {
        let colonies = coloniesForNavigation
        return colonies.count > 1 || colonies.first.map { $0.id != selectedColony?.id } == true
    }

    var selectedColonyUnits: [FreeColGame.Unit] {
        guard let game = cachedGame,
              let colony = selectedColony else {
            return []
        }
        let colonyId = colony.id
        let colonyTileId = colony.tileId
        let workLocationIds = Set(colony.buildings.map(\.id) + colony.workTiles.map(\.id))
        return game.units.values
            .filter { unit in
                unit.location == colonyId
                    || (colonyTileId != nil && unit.location == colonyTileId)
                    || unit.location.map { workLocationIds.contains($0) } == true
            }
            .sorted { $0.id < $1.id }
    }

    var canManageSelectedColony: Bool {
        guard phase == .inGame,
              isLocalPlayersTurn,
              let colony = selectedColony,
              let localPlayerId = resolveLocalPlayerId() else {
            return false
        }
        return colony.owner == localPlayerId
    }

    /// Custom-house export settings for the selected colony, sorted by goods.
    var selectedColonyExportData: [ColonyExportData] {
        guard let colony = selectedColony else { return [] }
        return colony.exportData.values.sorted { $0.goodsType < $1.goodsType }
    }

    /// Goods types a colony worker can produce/refine.
    var selectedColonyWorkTypeCandidates: [(id: String, label: String)] {
        guard let colony = selectedColony, let workerId = selectedColonyWorkerUnitId,
              let worker = cachedGame?.units[workerId], let location = worker.location else { return [] }
        return colonyWorkOutputs(at: location, in: colony).filter { $0.value > 0 }
            .map { (id: $0.key, label: goodsDisplayName($0.key)) }.sorted { $0.label < $1.label }
    }

    private func colonyWorkOutputs(at location: String, in colony: Colony) -> [String: Int] {
        guard let specification = cachedGame?.specification else { return [:] }
        if let building = colony.buildings.first(where: { $0.id == location }),
           let type = building.buildingType {
            return specification.buildingTypes[type]?.productionOutputs ?? [:]
        } else if let location = colony.workTiles.first(where: { $0.id == location }),
                    let tileId = location.tileId, let tileType = cachedGame?.tiles[tileId]?.type {
            let specificationOutputs = specification.tileTypes[tileType]?.workerOutputs ?? [:]
            return specificationOutputs.isEmpty
                ? (location.productionOutputs ?? [:]) : specificationOutputs
        }
        return [:]
    }

    /// Storable goods types, i.e. goods that can be kept in a warehouse and
    /// transported as cargo. Bells, crosses and hammers are not storable.
    var colonyGoodsCandidates: [(id: String, label: String)] {
        guard let specification = cachedGame?.specification else { return [] }
        return specification.goodsTypes.values
            .filter(\.isStorable)
            .map { (id: $0.id, label: goodsDisplayName($0.id)) }
            .sorted { $0.label < $1.label }
    }

    /// Work locations a colony worker can be assigned to (tiles + buildings).
    var selectedColonyWorkLocationCandidates: [(id: String, label: String)] {
        guard let colony = selectedColony else { return [] }
        let workerId = selectedColonyWorkerUnitId
        let worker = workerId.flatMap { cachedGame?.units[$0] }
        let specification = cachedGame?.specification
        var candidates: [(id: String, label: String)] = []
        for building in colony.buildings {
            guard let buildingType = building.buildingType,
                  let worker,
                  let unitType = worker.unitType,
                  let specification,
                  specification.buildingWorkplaces(for: buildingType)
                    > selectedColonyUnits.filter({ $0.location == building.id && $0.id != worker.id }).count,
                  (specification.buildingOutputs(for: buildingType, unattended: false)
                    .contains(where: { $0.value > 0 })
                    || specification.buildingHasAbility(
                        "model.ability.teach", buildingTypeId: buildingType
                    )),
                  specification.canUnitTypeWorkInBuilding(unitType, buildingTypeId: buildingType) else {
                continue
            }
            candidates.append((id: building.id, label: buildingDisplayName(buildingType)))
        }
        for tile in colony.workTiles {
            guard colonyWorkLocationUnavailableReason(tile.id) == nil else { continue }
            let label = tile.tileId.flatMap { cachedGame?.tiles[$0] }.map {
                "\($0.type.map(GameLabels.name) ?? "Gelände") (\($0.x), \($0.y))"
            } ?? "Koloniefeld"
            candidates.append((id: tile.id, label: label))
        }
        return candidates.sorted { $0.label < $1.label }
    }

    /// Colony units that can serve as teachers according to the built
    /// education buildings' skill limits. The server uses the same rule when
    /// validating an `assignTeacher` request.
    var selectedColonyTeacherCandidates: [FreeColGame.Unit] {
        guard let colony = selectedColony,
              let specification = cachedGame?.specification else { return [] }
        let teachingBuildings = colony.buildings.compactMap(\.buildingType).filter {
            specification.buildingHasAbility("model.ability.teach", buildingTypeId: $0)
        }
        guard !teachingBuildings.isEmpty else { return [] }
        return selectedColonyUnits.filter { unit in
            guard let unitType = unit.unitType else { return false }
            return teachingBuildings.contains {
                specification.canUnitTypeWorkInBuilding(unitType, buildingTypeId: $0)
            }
        }
    }

    /// Building types the colony can start building now (spec-known, not yet
    /// built, population requirement met, and — for upgrades — the prerequisite
    /// building present). Approximation of the Java `BuildQueuePanel`.
    var selectedColonyBuildableCandidates: [(id: String, label: String)] {
        guard let colony = selectedColony,
              let specification = cachedGame?.specification else {
            return []
        }
        let population = colonyPopulation(colony)
        return Self.buildableBuildingCandidates(colony: colony,
                                                specification: specification,
                                                population: population)
    }

    /// Building types a colony may start building: spec-known, not yet built,
    /// population requirement met, and — for upgrades — predecessor present.
    nonisolated static func buildableBuildingCandidates(colony: Colony,
                                                        specification: Specification,
                                                        population: Int) -> [(id: String, label: String)] {
        let built = Set(colony.buildings.compactMap { $0.buildingType })
        var superseded = Set<String>()
        for buildingId in built {
            var predecessor = specification.buildingTypes[buildingId]?.upgradesFrom
            while let predecessorId = predecessor, superseded.insert(predecessorId).inserted {
                predecessor = specification.buildingTypes[predecessorId]?.upgradesFrom
            }
        }
        let buildings = specification.buildingTypes.values
            .filter { info in
                guard !built.contains(info.id), !superseded.contains(info.id),
                      info.requiredPopulation <= population else {
                    return false
                }
                if let upgradesFrom = info.upgradesFrom {
                    return built.contains(upgradesFrom)
                }
                return true
            }
            .map { info -> (id: String, label: String) in
                let cost = info.requiredGoods[buildingMaterialsGoodsId] ?? 0
                let name = GameLabels.name(info.id, fallback: info.displayName)
                let label = cost > 0 ? "\(name) – \(cost)" : name
                return (id: info.id, label: label)
            }

        // A colony can build certain units when one of its buildings grants
        // model.ability.build for that unit type (e.g. a carpenter's house
        // enables wagon trains). Include inherited building abilities too.
        var buildableUnitTypeIds = Set<String>()
        for buildingId in built {
            var current: String? = buildingId
            var visited = Set<String>()
            while let id = current, visited.insert(id).inserted,
                  let building = specification.buildingTypes[id] {
                buildableUnitTypeIds.formUnion(building.buildableUnitTypes)
                current = building.extendsId
            }
        }
        let units = specification.unitTypes.values
            .filter { info in
                buildableUnitTypeIds.contains(info.id) && !info.requiredGoods.isEmpty
            }
            .map { info -> (id: String, label: String) in
                let cost = info.requiredGoods[buildingMaterialsGoodsId] ?? 0
                let name = GameLabels.name(info.id, fallback: info.displayName)
                return (id: info.id, label: cost > 0 ? "\(name) – \(cost)" : name)
            }

        return (buildings + units).sorted { $0.label < $1.label }
    }

    /// Buildings present in the selected colony with display names.
    var selectedColonyBuildings: [(id: String, label: String)] {
        guard let colony = selectedColony else { return [] }
        return colony.buildings
            .map { (id: $0.buildingType ?? $0.id, label: buildingDisplayName($0.buildingType ?? $0.id)) }
            .sorted { $0.label < $1.label }
    }

    var game: Game? { _ = gameUpdateID; return cachedGame }

    /// Install a game model directly (local play and tests) without a connection.
    func installGame(_ game: Game) {
        cachedGame = game
        gameUpdateID += 1
    }

    func startLocal(userName: String, nationId: String) {
        guard case .disconnected = phase else { return }
        FreeColLogger.shared.info("Starting local game")
        resetSessionState()
        localPlayerName = userName
        localNationId = nationId
        phase = .connecting
        statusMessage = "Lokaler Server wird gestartet …"

        let server = MockServer()
        self.server = server
        let bridge = ClientBridge(gameState: self)
        self.bridge = bridge

        Task {
            let actualPort = await server.port
            FreeColLogger.shared.info("MockServer on port \(actualPort)")
            let client = FreeColClient(host: "127.0.0.1", port: actualPort)
            self.client = client
            await client.setDelegate(bridge)
            do {
                async let serverHandshake: Void = runServerHandshake(
                    server: server, gameXML: makeGameXML())

                try await client.connect()
                statusMessage = "Verbunden, Anmeldung läuft …"
                let result = try await client.login(userName: userName, nationId: nationId)
                cachedGame = await client.game
                if let game = cachedGame, game.currentPlayerId == nil {
                    // Local games have no server-side turn owner yet.
                    game.currentPlayerId = resolveLocalPlayerId()
                }

                // Make sure handshake completed
                _ = try await serverHandshake

                applyLoginResult(result)
                statusMessage = ""
                startMessageLoop(client: client, server: server)
                startLocalServerLoop(server: server)
            } catch {
                FreeColLogger.shared.error("Local game failed: \(error)")
                errorMessage = ServerErrorMessage.description(for: error)
                phase = .disconnected
                statusMessage = ""
            }
        }
    }

    private func runServerHandshake(server: MockServer, gameXML: String) async throws {
        try await server.waitForConnection()
        try await server.doHandshake(gameResponse: gameXML)
    }

    /// Minimal server-side loop for local games: answers the handful of
    /// messages that need a server response so the local game is playable,
    /// most importantly `endTurn` (turn advancement).
    private func startLocalServerLoop(server: MockServer) {
        localServerTask?.cancel()
        localServerTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let line = try? await server.nextLine() else { break }
                guard let parsed = try? XMLDecoder.decode(line) else { continue }
                let message = (parsed.tag == "question" && !parsed.children.isEmpty)
                    ? parsed.children[0]
                    : parsed
                await self?.handleLocalServerMessage(message, server: server)
            }
        }
    }

    private func handleLocalServerMessage(_ message: ParsedMessage, server: MockServer) async {
        switch message.tag {
        case "endTurn":
            let nextTurn = (cachedGame?.turn.number ?? 1) + 1
            await server.send("<newTurn turn=\"\(nextTurn)\"/>")
            if let localPlayerId = resolveLocalPlayerId() {
                await server.send("<setCurrentPlayer player=\"\(localPlayerId)\"/>")
            }
            await server.flush()
        case "chat":
            let text = message.attributes["message"] ?? ""
            let from = message.attributes["userName"] ?? "?"
            if !text.isEmpty {
                await server.send("<chat userName=\"\(from)\" message=\"\(text)\"/>")
                await server.flush()
            }
        default:
            break
        }
    }

    func createJavaGame(configuration: NewGameConfiguration, java: URL, port: Int,
                        name: String, seed: String) throws {
        guard phase == .disconnected || phase == .lobby else {
            throw NewGameError.invalid("Eine neue Partie kann nur außerhalb eines laufenden Spiels erstellt werden.")
        }
        let launch = try JavaServerLaunch.prepare(configuration: configuration, java: java, port: port,
                                                 name: name, seed: seed, root: try hostedGamesRoot())
        startHostedServer(launch, savegameName: nil)
    }

    func loadJavaSavegame(_ savegame: URL, installation: URL, java: URL, port: Int, name: String) throws {
        guard phase == .disconnected || phase == .lobby else {
            throw NewGameError.invalid("Ein Spielstand kann nur außerhalb eines laufenden Spiels geladen werden.")
        }
        let launch = try JavaServerLaunch.prepareSavegame(savegame, installation: installation, java: java,
                                                         port: port, name: name, root: try hostedGamesRoot())
        startHostedServer(launch, savegameName: savegame.deletingPathExtension().lastPathComponent)
    }

    private func hostedGamesRoot() throws -> URL {
        try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                    appropriateFor: nil, create: true)
            .appendingPathComponent("FreeColClient/Games")
    }

    private func startHostedServer(_ launch: JavaServerLaunch, savegameName: String?) {
        let port = launch.port
        let previousServer = javaServer
        if phase == .lobby { disconnect() }
        resetSessionState()
        hostedGameDirectory = launch.directory
        hostedSavegameName = savegameName
        let server = LocalJavaServer()
        javaServer = server
        server.onUnexpectedExit = { [weak self] message in
            guard let self else { return }
            FreeColLogger.shared.error(message)
            self.disconnect()
            self.errorMessage = message
        }
        let startID = UUID()
        javaServerStartID = startID
        phase = .connecting
        statusMessage = "Java-Server wird gestartet…"
        javaServerStartTask = Task {
            do {
                try await previousServer?.waitForShutdown()
                try Task.checkCancellation()
                try await server.start(launch)
                guard javaServerStartID == startID else { return }
                javaServerStartTask = nil
                javaServerStartID = nil
                phase = .disconnected
                connect(host: "127.0.0.1", port: port)
            } catch {
                guard javaServerStartID == startID else { return }
                FreeColLogger.shared.error("Java-Serverstart fehlgeschlagen: \(error)")
                stopHostedServer()
                errorMessage = error.localizedDescription
                phase = .disconnected
                statusMessage = ""
            }
        }
    }

    func stopHostedServer() {
        javaServerStartID = nil
        javaServerStartTask?.cancel()
        javaServerStartTask = nil
        javaServer?.stop()
        javaServer = nil
        hostedSavegameName = nil
    }

    func connect(host: String, port: Int) {
        guard case .disconnected = phase else { return }
        userRequestedDisconnect = false
        remoteHost = host
        remotePort = port
        FreeColLogger.shared.info("Connecting to \(host):\(port)...")
        resetSessionState()
        phase = .connecting
        statusMessage = "Verbindung zu \(host):\(port) wird hergestellt …"
        let client = FreeColClient(host: host, port: port)
        self.client = client
        let bridge = ClientBridge(gameState: self)
        self.bridge = bridge
        let attemptID = UUID()
        connectionAttemptID = attemptID

        Task {
            await client.setDelegate(bridge)
            do {
                try await client.connect()
                // Capture initial handshake data from client after connection and handshake
                let vacantPlayers = await client.initialVacantPlayers
                let serverState = await client.initialGameState
                guard connectionAttemptID == attemptID else {
                    await client.disconnect()
                    return
                }
                self.vacantPlayers = vacantPlayers
                self.serverState = serverState
                
                phase = .login
                statusMessage = "Verbunden"
            } catch {
                guard connectionAttemptID == attemptID else { return }
                FreeColLogger.shared.error("Connection failed: \(error)")
                stopHostedServer()
                errorMessage = ServerErrorMessage.description(for: error)
                phase = .disconnected
                statusMessage = ""
            }
        }
    }

    func login(userName: String, nationId: String) {
        guard case .login = phase, let client = client else { return }
        FreeColLogger.shared.info("Logging in")
        errorMessage = nil
        localPlayerName = userName
        phase = .connecting
        statusMessage = "Anmeldung läuft …"

        Task {
            do {
                let result = try await client.login(userName: userName, nationId: nationId)
                cachedGame = await client.game
                applyLoginResult(result)
                // The server ignores the nationId of the login and assigns the first vacant nation.
                if result.nationId != nationId { setLocalPlayerNation(nationId) }
                statusMessage = ""
                startMessageLoop(client: client, server: nil)
            } catch {
                FreeColLogger.shared.error("Login failed: \(error)")
                errorMessage = ServerErrorMessage.description(for: error)
                phase = .login
                statusMessage = "Anmeldung fehlgeschlagen"
            }
        }
    }

    func disconnect() {
        userRequestedDisconnect = true
        connectionAttemptID = nil
        stopHostedServer()
        reconnectTask?.cancel()
        reconnectTask = nil
        queuedGameplayActions.removeAll()
        messageLoopTask?.cancel()
        messageLoopTask = nil
        localServerTask?.cancel()
        localServerTask = nil
        let disconnectedClient = client
        let disconnectedServer = server
        Task {
            await disconnectedClient?.disconnect()
            await disconnectedServer?.stop()
        }
        server = nil
        client = nil
        bridge = nil
        resetSessionState()
        phase = .disconnected
        statusMessage = ""
    }

    func clearError() { errorMessage = nil }

    func applyLoginResult(_ result: LoginResult) {
        if localPlayerName == nil {
            localPlayerName = result.playerName
        }
        localNationId = result.nationId
        applyServerState(result.serverState)
    }

    private static let serverPromptTags: Set<String> = [
        "fountainOfYouth", "indianDemand", "lootCargo",
        "firstContact", "monarchAction", "newLandName", "newRegionName",
        "close", "highScores", "nationSummary", "nativeTrade", "diplomacy",
        "chooseFoundingFather", "scoutSpeakToChief", "spySettlement",
        "incite", "setDead"
    ]

    private func isServerPromptTag(_ tag: String) -> Bool {
        Self.serverPromptTags.contains(tag)
    }

    private func isDecisionPromptTag(_ tag: String) -> Bool {
        tag == "fountainOfYouth" || tag == "indianDemand" || tag == "lootCargo"
    }

    private func isDecisionResponse(_ parsed: ParsedMessage) -> Bool {
        guard isDecisionPromptTag(parsed.tag) else { return false }
        return parsed.attributes["result"] != nil || parsed.attributes["value"] != nil
    }

    func applySessionMessage(_ parsed: ParsedMessage) {
        switch parsed.tag {
        case "question":
            if let payload = parsed.children.first {
                applySessionMessage(payload)
            }
        case "reply", "multiple":
            for child in parsed.children {
                if isDecisionResponse(child) {
                    clearPendingDecision()
                    statusMessage = "Entscheidung verarbeitet."
                    continue
                }
                applySessionMessage(child)
            }
        case "update":
            // Model deltas in an update are applied by GameStateManager; here we
            // only surface nested server prompts that were forwarded up.
            for child in parsed.children {
                if isServerPromptTag(child.tag) || child.tag == "multiple" || child.tag == "update" {
                    applySessionMessage(child)
                }
            }
        case "gameState":
            guard let rawState = parsed.attributes["state"],
                  let state = ServerState(rawValue: rawState) else {
                return
            }
            applyServerState(state)
        case "startGame":
            applyServerState(.inGame)
        case "reconnect":
            applyReconnectRequest()
        case "vacantPlayers":
            vacantPlayers = parsed
        case "ready":
            applyReadyMessage(parsed)
        case "error":
            applyServerError(parsed)
        case "firstContact":
            applyFirstContactMessage(parsed)
        case "missionary":
            applyMissionaryMessage(parsed)
        case "monarchAction":
            applyMonarchActionMessage(parsed)
        case "newLandName":
            applyNamePrompt(parsed, type: .newLandName)
        case "newRegionName":
            applyNamePrompt(parsed, type: .newRegionName)
        case "close":
            applyCloseMessage(parsed)
        case "highScores":
            highScoresReport = parsed
            statusMessage = "Bestenliste empfangen."
        case "nationSummary":
            nationSummaryReport = parsed
            statusMessage = "Nationsübersicht empfangen."
        case "scoutSpeakToChief":
            if isDecisionResponse(parsed) {
                clearPendingDecision()
                return
            }
            clearPendingDecision()
            pendingServerDecision = PendingServerDecision(
                type: .scoutReport,
                rawPayload: parsed.attributes,
                children: parsed.children
            )
        case "spySettlement":
            applySpySettlementMessage(parsed)
        case "incite":
            if isDecisionResponse(parsed) {
                clearPendingDecision()
                statusMessage = "Entscheidung verarbeitet."
                return
            }
            clearPendingDecision()
            pendingServerDecision = PendingServerDecision(
                type: .incite,
                rawPayload: parsed.attributes,
                children: parsed.children
            )
            statusMessage = "Bestätigung für den Aufstand steht aus."
        case "chooseFoundingFather":
            if isDecisionResponse(parsed) {
                clearPendingDecision()
                statusMessage = "Gründervater ausgewählt."
                return
            }
            clearPendingDecision()
            pendingServerDecision = PendingServerDecision(
                type: .foundingFather,
                rawPayload: parsed.attributes,
                children: parsed.children
            )
            statusMessage = "Wähle einen Gründervater aus."
        case "learnSkill", "askSkill":
            applyActionResultLog(parsed)
        case "setDead":
            applySetDeadMessage(parsed)
        case "updateGameOptions", "updateMapGeneratorOptions":
            applyOptionEcho(parsed)
        case "nativeTrade":
            applyNativeTradeMessage(parsed)
        case "diplomacy":
            applyDiplomacyMessage(parsed)
        case "animateMove":
            applyAnimateMoveMessage(parsed)
        case "animateAttack":
            applyAnimateAttackMessage(parsed)
        case "chat":
            applyChatMessage(parsed)
        case "gameEnded":
            // The server broadcasts this to every player; only the winner reacts.
            let winner = parsed.attributes["winner"]
            isGameEnded = true
            isVictorious = winner != nil && winner == resolveLocalPlayerId()
            gameEndedHighScore = (parsed.attributes["highScore"] ?? "").lowercased() == "true"
            statusMessage = isVictorious
                ? "Du hast das Spiel gewonnen!"
                : "Das Spiel ist beendet. Sieger: \(winner ?? "unbekannt")"
            pendingServerDecision = nil
        case "fountainOfYouth":
            if isDecisionResponse(parsed) {
                clearPendingDecision()
                statusMessage = "Entscheidung verarbeitet."
                return
            }
            clearPendingDecision()
            pendingServerDecision = PendingServerDecision(
                type: .fountainOfYouth,
                rawPayload: parsed.attributes,
                children: parsed.children
            )
            statusMessage = "Jungbrunnen: Wähle Auswanderer aus."
        case "indianDemand":
            if isDecisionResponse(parsed) {
                clearPendingDecision()
                statusMessage = "Entscheidung verarbeitet."
                return
            }
            clearPendingDecision()
            pendingServerDecision = PendingServerDecision(
                type: .indianDemand,
                rawPayload: parsed.attributes,
                children: parsed.children
            )
            statusMessage = "Forderung der Ureinwohner wartet auf Antwort."
        case "lootCargo":
            if isDecisionResponse(parsed) {
                clearPendingDecision()
                statusMessage = "Entscheidung verarbeitet."
                return
            }
            clearPendingDecision()
            pendingServerDecision = PendingServerDecision(
                type: .lootCargo,
                rawPayload: parsed.attributes,
                children: parsed.children
            )
            statusMessage = "Entscheidung über die Beute steht aus."
        case "logout":
            if parsed.attributes["player"] == resolveLocalPlayerId() {
                statusMessage = "Deine Sitzung wurde beendet."
            }
            pendingServerDecision = nil
        default:
            break
        }
    }

    private func applyChatMessage(_ parsed: ParsedMessage) {
        let sender = parsed.attributes["sender"] ?? "?"
        let message = parsed.attributes["message"] ?? ""
        let senderName = cachedGame?.players[sender]?.name ?? sender
        incomingChatLog.append("\(senderName): \(message)")
        if incomingChatLog.count > 8 {
            incomingChatLog.removeFirst(incomingChatLog.count - 8)
        }
        statusMessage = "Chat – \(senderName): \(message)"
        errorMessage = nil
    }

    private func applyAnimateMoveMessage(_ parsed: ParsedMessage) {
        guard let source = parsed.attributes["oldTile"],
              let target = parsed.attributes["newTile"] else {
            return
        }
        showMapAnimationCue(sourceTileId: source, targetTileId: target, style: .move)
    }

    private func applyAnimateAttackMessage(_ parsed: ParsedMessage) {
        guard let source = parsed.attributes["attackerTile"],
              let target = parsed.attributes["defenderTile"] else {
            return
        }
        let successRaw = parsed.attributes["success"]
        let success = successRaw.map { ($0 as NSString).boolValue }
        let style: MapAnimationCue.Style
        switch success {
        case .some(true):
            style = .attackSuccess
        case .some(false):
            style = .attackFail
        case .none:
            style = .attack
        }
        showMapAnimationCue(sourceTileId: source, targetTileId: target, style: style)
        let attacker = parsed.attributes["attacker"] ?? "unknown attacker"
        let defender = parsed.attributes["defender"] ?? "unknown defender"
        switch success {
        case .some(true):
            statusMessage = "Angriff erfolgreich: \(attacker) gegen \(defender)"
        case .some(false):
            statusMessage = "Angriff fehlgeschlagen: \(attacker) gegen \(defender)"
        case .none:
            statusMessage = "Angriff: \(attacker) gegen \(defender)"
        }
        errorMessage = nil
    }

    private func applyFirstContactMessage(_ parsed: ParsedMessage) {
        errorMessage = nil
        if let result = parsed.attributes["result"], !result.isEmpty {
            // Response echo: record it instead of opening a new prompt.
            statusMessage = "Erstkontakt abgeschlossen: \(result)"
            return
        }
        clearPendingDecision()
        pendingServerDecision = PendingServerDecision(
            type: .firstContact,
            rawPayload: parsed.attributes,
            children: parsed.children
        )
        statusMessage = "Erstkontakt: Diplomatische Beziehungen herstellen oder ablehnen."
    }

    private func applyMonarchActionMessage(_ parsed: ParsedMessage) {
        let action = parsed.attributes["action"] ?? ""
        // A result attribute means this is a response echo, not a new offer.
        if let result = parsed.attributes["result"], !result.isEmpty {
            statusMessage = "Monarch – \(monarchActionDescription(action)) (\(result))"
            return
        }
        // Only these actions create a MonarchSession on the server and require
        // an accept/reject response. Other actions (including ADD_TO_REF) are
        // announcements; answering them produces "Bogus monarch action".
        let responseRequiredActions: Set<String> = [
            "raise_tax_act", "raise_tax_war",
            "monarch_mercenaries", "hessian_mercenaries",
        ]
        guard responseRequiredActions.contains(action.lowercased()) else {
            statusMessage = "Monarch – \(monarchActionDescription(action))"
            return
        }
        clearPendingDecision()
        pendingServerDecision = PendingServerDecision(
            type: .monarchAction,
            rawPayload: parsed.attributes,
            children: parsed.children
        )
        statusMessage = "Angebot des Monarchen wartet auf Antwort."
    }

    private func applyNamePrompt(_ parsed: ParsedMessage, type: PendingServerDecisionType) {
        if parsed.attributes["result"] != nil {
            clearPendingDecision()
            statusMessage = "Name übermittelt."
            return
        }
        clearPendingDecision()
        pendingServerDecision = PendingServerDecision(
            type: type,
            rawPayload: parsed.attributes,
            children: parsed.children
        )
        statusMessage = type == .newLandName ? "Benenne das neue Land." : "Benenne die neue Region."
    }

    private func applyCloseMessage(_ parsed: ParsedMessage) {
        let panel = parsed.attributes["panel"] ?? ""
        if matchesPendingPrompt(panel: panel) {
            clearPendingDecision()
            statusMessage = "Der Server hat die Abfrage geschlossen."
        } else {
            statusMessage = "Der Server hat das Fenster geschlossen: \(panel)"
        }
    }

    private func matchesPendingPrompt(panel: String) -> Bool {
        guard let type = pendingServerDecision?.type else { return false }
        let lower = panel.lowercased()
        switch type {
        case .indianDemand:
            return lower.contains("demand")
        case .lootCargo:
            return lower.contains("capture") || lower.contains("loot")
        case .fountainOfYouth:
            return lower.contains("emigration") || lower.contains("fountain")
        case .firstContact:
            return lower.contains("contact")
        case .monarchAction:
            return lower.contains("monarch")
        case .newLandName:
            return lower.contains("newland")
        case .newRegionName:
            return lower.contains("newregion")
        case .nativeTrade:
            return lower.contains("trade")
        case .diplomacy:
            return lower.contains("diplomacy") || lower.contains("negotiation")
        case .foundingFather:
            return lower.contains("congress") || lower.contains("founding")
        case .scoutReport:
            return lower.contains("scout") || lower.contains("chief")
        case .incite:
            return lower.contains("incite")
        }
    }

    private func applyActionResultLog(_ parsed: ParsedMessage) {
        var parts: [String] = [parsed.tag]
        for key in ["unit", "settlement", "result", "success", "gold", "goods", "action"] {
            if let value = parsed.attributes[key] { parts.append("\(key): \(value)") }
        }
        let line = parts.joined(separator: " · ")
        incomingChatLog.append(line)
        if incomingChatLog.count > 8 {
            incomingChatLog.removeFirst(incomingChatLog.count - 8)
        }
        statusMessage = line
        errorMessage = nil
    }

    /// A `spySettlement` result opens the colony panel for the spied settlement.
    private func applySpySettlementMessage(_ parsed: ParsedMessage) {
        guard let settlementId = parsed.attributes["settlement"] else {
            applyActionResultLog(parsed)
            return
        }
        guard let game = cachedGame else { return }
        if let colony = game.colonies[settlementId] {
            statusMessage = "Erkundet: \(colony.name ?? settlementId)."
        } else {
            statusMessage = "Erkundungsbericht: \(settlementId)"
        }
        openColonyPanel(colonyId: settlementId)
    }

    /// A `setDead` record: forward defeat of the local player to the UI.
    private func applySetDeadMessage(_ parsed: ParsedMessage) {
        guard let deadId = parsed.attributes["player"] else { return }
        if deadId == resolveLocalPlayerId() {
            isDefeated = true
            isVictorious = false
            pendingServerDecision = nil
            statusMessage = "Deine Nation wurde besiegt."
        } else {
            statusMessage = "Spieler ausgeschaltet: \(deadId)"
        }
    }

    /// Merge `updateGameOptions` / `updateMapGeneratorOptions` echoes.
    private func applyOptionEcho(_ parsed: ParsedMessage) {
        var options: [String: String] = [:]
        for child in parsed.children where child.tag == "option" {
            guard let id = child.attributes["id"] else { continue }
            options[id] = child.attributes["value"] ?? ""
        }
        if !options.isEmpty {
            cachedGame?.mergeOptions(options)
            statusMessage = "Optionen aktualisiert (\(options.count))."
        }
    }

    private func applyNativeTradeMessage(_ parsed: ParsedMessage) {
        let action = parsed.attributes["action"] ?? ""
        errorMessage = nil
        let incoming = NativeTradeSession(nativeTradeChild: parsed.children.first { $0.tag == "nativeTrade" })

        func mergeIntoPrompt() {
            var session = pendingNativeTrade ?? incoming
            session.merge(from: incoming)
            pendingServerDecision = PendingServerDecision(
                type: .nativeTrade,
                rawPayload: ["action": action],
                children: [session.toInnerMessage()]
            )
        }

        switch action {
        case "ACK_OPEN":
            clearPendingDecision()
            pendingServerDecision = PendingServerDecision(
                type: .nativeTrade,
                rawPayload: ["action": action],
                children: [incoming.toInnerMessage()]
            )
            statusMessage = "Handel mit Ureinwohnern geöffnet."
        case "ACK_BUY":
            mergeIntoPrompt()
            statusMessage = tradeItemStatus("Gekauft", session: pendingNativeTrade)
        case "ACK_SELL":
            mergeIntoPrompt()
            statusMessage = tradeItemStatus("Verkauft", session: pendingNativeTrade)
        case "ACK_GIFT":
            mergeIntoPrompt()
            statusMessage = "Geschenk angenommen."
        case "ACK_BUY_HAGGLE", "ACK_SELL_HAGGLE":
            mergeIntoPrompt()
            if let item = pendingNativeTrade?.item {
                statusMessage = "Nachverhandlung: \(item.goodsType.map(goodsDisplayName) ?? "Ware") kostet jetzt \(item.price) Gold."
            } else {
                statusMessage = "Gegenangebot erhalten."
            }
        case "CLOSE":
            clearPendingDecision()
            statusMessage = "Handel mit Ureinwohnern beendet."
        case "NAK_GOODS", "NAK_HAGGLE", "NAK_HOSTILE", "NAK_NOSALE", "NAK_INVALID":
            statusMessage = "Handel mit Ureinwohnern abgelehnt: \(nativeTradeActionDescription(action))"
        default:
            // Includes a stray server-side OPEN echo.
            mergeIntoPrompt()
            statusMessage = "Handel mit Ureinwohnern: \(nativeTradeActionDescription(action))"
        }
    }

    private func tradeItemStatus(_ verb: String, session: NativeTradeSession?) -> String {
        guard let item = session?.item else { return "\(verb)." }
        return "\(verb): \(item.goodsType.map(goodsDisplayName) ?? "Ware") ×\(item.amount) für \(item.price) Gold."
    }

    private func nativeTradeActionDescription(_ action: String) -> String {
        switch action {
        case "NAK_GOODS": return "Warenmenge nicht verfügbar"
        case "NAK_HAGGLE": return "Gegenangebot abgelehnt"
        case "NAK_HOSTILE": return "Siedlung ist feindselig"
        case "NAK_NOSALE": return "Handel nicht möglich"
        case "NAK_INVALID": return "Ungültiges Angebot"
        case "OPEN": return "Handel geöffnet"
        default: return action
        }
    }

    private func applyDiplomacyMessage(_ parsed: ParsedMessage) {
        guard let tradeNode = parsed.children.first(where: { $0.tag == "diplomaticTrade" }) else {
            statusMessage = "Diplomatische Nachricht ohne Vereinbarung."
            return
        }
        errorMessage = nil
        let proposal = DiplomaticTradeProposal(raw: tradeNode)
        switch proposal.status {
        case "ACCEPT_TRADE":
            clearPendingDecision()
            statusMessage = "Diplomatie: Angebot angenommen."
        case "REJECT_TRADE":
            clearPendingDecision()
            statusMessage = "Diplomatie: Angebot abgelehnt."
        default:
            clearPendingDecision()
            pendingServerDecision = PendingServerDecision(
                type: .diplomacy,
                rawPayload: parsed.attributes,
                children: [tradeNode]
            )
            statusMessage = "Diplomatie: Angebot wartet auf eine Antwort."
        }
    }

    private func applyMissionaryMessage(_ parsed: ParsedMessage) {
        let unitId = parsed.attributes["unit"] ?? ""
        let unit = cachedGame?.units[unitId].map(unitDisplayLabel) ?? "Einheit"
        let direction = parsed.attributes["direction"] ?? "unknown"
        let denounce = (parsed.attributes["denounce"] ?? "false").lowercased() == "true"
        errorMessage = nil
        statusMessage = "Missionarsaktion mit \(unit), Richtung \(direction), anprangern: \(denounce ? "ja" : "nein")."
    }

    private func showMapAnimationCue(sourceTileId: String, targetTileId: String, style: MapAnimationCue.Style) {
        mapAnimationCueToken += 1
        let token = mapAnimationCueToken
        mapAnimationCue = MapAnimationCue(sourceTileId: sourceTileId, targetTileId: targetTileId, style: style)

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard mapAnimationCueToken == token else { return }
            mapAnimationCue = nil
        }
    }

    private func applyServerError(_ parsed: ParsedMessage) {
        clearPendingEndTurn()
        if let message = parsed.attributes["message"], !message.isEmpty {
            reconcileFromServerErrorMessage(message)
            errorMessage = ServerRejectMapper.userFacingMessage(for: parsed)
            return
        }
        errorMessage = ServerRejectMapper.userFacingMessage(for: parsed)
    }

    private func reconcileFromServerErrorMessage(_ message: String) {
        // Keep local action gating in sync when the server rejects a move due to no moves left.
        guard message.lowercased().contains("move_no_moves"),
              let unitId = ServerRejectMapper.rejectedObjectId(prefix: "unit:", in: message),
              let game = cachedGame else {
            return
        }
        let partial = ParsedMessage(
            tag: "partial",
            attributes: ["id": unitId, "movesLeft": "0"],
            children: []
        )
        try? game.applyPartial(partial)
        if selectedUnitId == unitId {
            reconcileSelectionWithGame()
            gameUpdateID += 1
        }
    }

    private func applyReadyMessage(_ parsed: ParsedMessage) {
        guard let playerId = parsed.attributes["player"] else { return }
        guard let localPlayerId = resolveLocalPlayerId() else { return }
        guard playerId == localPlayerId else { return }
        let rawValue = parsed.attributes["value"] ?? "false"
        isReadyToStart = (rawValue as NSString).boolValue
    }

    private func applyReconnectRequest() {
        disconnect()
        errorMessage = "Server hat eine Neuverbindung angefordert."
    }

    func clearPendingDecision() {
        pendingServerDecision = nil
    }

    func dismissPendingDecision() {
        clearPendingDecision()
        statusMessage = ""
    }

    func canRespondToPendingDecision() -> Bool {
        guard let decision = pendingServerDecision else { return false }
        guard phase == .inGame else { return false }
        switch decision.type {
        case .fountainOfYouth, .monarchAction, .nativeTrade, .foundingFather, .incite:
            // All are current-player messages on the Java side.
            return isLocalPlayersTurn
        case .indianDemand, .lootCargo, .firstContact, .newLandName, .newRegionName,
             .diplomacy, .scoutReport:
            return true
        }
    }

    /// Reply to an `indianDemand` prompt. The Java enum wire values are
    /// `indian_demand_accept` / `indian_demand_reject`.
    private func respondToIndianDemand(accept: Bool) {
        guard let decision = pendingServerDecision, decision.type == .indianDemand else { return }
        guard phase == .inGame else { return }

        var attributes: [String: String] = [:]
        for key in ["unit", "colony", "type", "amount"] {
            if let value = decision.rawPayload[key] { attributes[key] = value }
        }
        attributes["result"] = accept ? "indian_demand_accept" : "indian_demand_reject"
        sendDecision(tag: "indianDemand", attributes: attributes, children: [])
    }

    func acceptPendingDecision() {
        respondToIndianDemand(accept: true)
    }

    func declinePendingDecision() {
        respondToIndianDemand(accept: false)
    }

    func acceptFirstContact() {
        respondToFirstContact(accept: true)
    }

    func declineFirstContact() {
        respondToFirstContact(accept: false)
    }

    /// Reply to a `firstContact` prompt. `result` is a boolean string.
    private func respondToFirstContact(accept: Bool) {
        guard let decision = pendingServerDecision, decision.type == .firstContact else { return }
        guard phase == .inGame else { return }

        var attributes: [String: String] = [:]
        for key in ["player", "other", "tile", "camps"] {
            if let value = decision.rawPayload[key] { attributes[key] = value }
        }
        attributes["result"] = accept ? "true" : "false"
        sendDecision(tag: "firstContact", attributes: attributes, children: [])
    }

    /// Reply to a `monarchAction` offer. `result` is a boolean string.
    func answerMonarch(accept: Bool) {
        guard let decision = pendingServerDecision, decision.type == .monarchAction else { return }
        guard phase == .inGame, isLocalPlayersTurn else { return }

        var attributes: [String: String] = [:]
        for key in ["action", "monarch", "tax"] {
            if let value = decision.rawPayload[key] { attributes[key] = value }
        }
        attributes["result"] = accept ? "true" : "false"
        sendDecision(tag: "monarchAction", attributes: attributes, children: [])
    }

    func submitNewLandName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Bitte einen Namen eingeben."
            return
        }
        guard let decision = pendingServerDecision, decision.type == .newLandName else { return }
        guard phase == .inGame else { return }

        var attributes: [String: String] = [:]
        if let unit = decision.rawPayload["unit"] { attributes["unit"] = unit }
        attributes["newLandName"] = trimmed
        sendDecision(tag: "newLandName", attributes: attributes, children: [])
    }

    func submitNewRegionName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Bitte einen Namen eingeben."
            return
        }
        guard let decision = pendingServerDecision, decision.type == .newRegionName else { return }
        guard phase == .inGame else { return }

        var attributes: [String: String] = [:]
        for key in ["region", "tile", "unit"] {
            if let value = decision.rawPayload[key] { attributes[key] = value }
        }
        attributes["newRegionName"] = trimmed
        sendDecision(tag: "newRegionName", attributes: attributes, children: [])
    }

    // MARK: Phase 54 - inbound decision handling

    /// Dismiss an informational server prompt (no reply is sent).
    func acknowledgePendingDecision() {
        clearPendingDecision()
        statusMessage = ""
    }

    /// Choose one of the offered founding fathers in a `chooseFoundingFather` prompt.
    func choosePendingFoundingFather(_ fatherId: String) {
        guard let decision = pendingServerDecision, decision.type == .foundingFather,
              phase == .inGame else { return }
        let trimmed = fatherId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var attributes = decision.rawPayload
        attributes["foundingFather"] = trimmed
        sendDecision(tag: "chooseFoundingFather", attributes: attributes, children: [])
    }

    /// Accept an `incite` prompt by sending the confirmed action back.
    func confirmPendingIncite() {
        guard let incite = pendingIncite, phase == .inGame else { return }
        errorMessage = nil
        let attributes = [
            "unit": incite.unit,
            "settlement": incite.settlement,
            "enemy": incite.enemy,
            "gold": String(incite.gold),
        ]
        sendDecision(tag: "incite", attributes: attributes, children: [])
    }

    func declinePendingIncite() {
        clearPendingDecision()
        statusMessage = "Aufstand abgelehnt."
    }

    /// Continue playing after winning.
    func continueAfterVictory() {
        isVictorious = false
        isGameEnded = false
        sendContinue()
    }

    /// Retire after winning.
    func retireAfterVictory() {
        isVictorious = false
        isGameEnded = false
        retireGame()
    }

    /// Enter revenge mode after a local defeat.
    func enterRevengeModeFromDefeat() {
        isDefeated = false
        isUndead = true
        enterRevengeMode()
    }

    // MARK: Phase 45 - Native trade sessions

    /// A native settlement adjacent to the selected unit that can be traded with.
    struct NativeTradeTarget: Identifiable {
        var id: String { settlementId }
        let settlementId: String
        let name: String
    }

    /// Native settlements adjacent to the selected unit.
    var nativeTradeTargetsForSelectedUnit: [NativeTradeTarget] {
        guard let game = cachedGame,
              let unit = selectedUnit,
              let unitTileId = unit.location,
              let unitTile = game.tiles[unitTileId] else { return [] }
        return game.colonies.values.compactMap { colony in
            guard let ownerId = colony.owner,
                  let owner = game.players[ownerId],
                  owner.playerType == .indian,
                  let colonyTileId = colony.tileId,
                  let colonyTile = game.tiles[colonyTileId] else { return nil }
            let dx = abs(colonyTile.x - unitTile.x)
            let dy = abs(colonyTile.y - unitTile.y)
            guard dx <= 1, dy <= 1, !(dx == 0 && dy == 0) else { return nil }
            return NativeTradeTarget(settlementId: colony.id, name: colony.name ?? colony.id)
        }
    }

    var canOpenNativeTrade: Bool {
        guard phase == .inGame,
              isLocalPlayersTurn,
              let unit = selectedUnit,
              let localPlayerId = resolveLocalPlayerId(),
              unit.movesLeft > 0,
              unit.owner == localPlayerId else { return false }
        return !nativeTradeTargetsForSelectedUnit.isEmpty
    }

    /// Compass direction from the selected unit's tile to an adjacent settlement.
    func directionToAdjacentSettlement(_ settlementId: String) -> String? {
        guard let game = cachedGame,
              let unitId = selectedUnitId,
              let unit = game.units[unitId],
              let fromTileId = game.resolvedTileId(for: unit),
              let settlement = game.colonies[settlementId],
              let toTileId = settlement.tileId else {
            return nil
        }
        return attackDirection(fromTileId: fromTileId, toTileId: toTileId, in: game)
    }

    func openNativeTradeWithSelectedUnit(settlementId: String) {
        guard canOpenNativeTrade, let unitId = selectedUnitId else {
            errorMessage = "Kein Handel möglich."
            return
        }
        guard !settlementId.isEmpty else {
            errorMessage = "Siedlung erforderlich."
            return
        }
        guard nativeTradeTargetsForSelectedUnit.contains(where: { $0.settlementId == settlementId }) else {
            errorMessage = "Keine angrenzende Siedlung der Ureinwohner."
            return
        }
        errorMessage = nil
        let session = NativeTradeSession(unitId: unitId, settlementId: settlementId)
        sendNativeTrade(session.toMessage(action: "OPEN", item: nil))
    }

    func nativeTradeBuy(_ item: NativeTradeItem, offerPrice: Int? = nil) {
        sendNativeTradeOffer("BUY", item: item, offerPrice: offerPrice)
    }

    func nativeTradeSell(_ item: NativeTradeItem, offerPrice: Int? = nil) {
        sendNativeTradeOffer("SELL", item: item, offerPrice: offerPrice)
    }

    func nativeTradeGift(_ item: NativeTradeItem) {
        sendNativeTradeAction("GIFT", item: item)
    }

    /// Suggested haggle offer: 10% better than the native's asking/offered price.
    func nativeTradeHaggleOffer(_ item: NativeTradeItem, buying: Bool) -> Int {
        let step = max(1, item.price / 10)
        return buying ? max(1, item.price - step) : item.price + step
    }

    func closeNativeTrade() {
        if let session = pendingNativeTrade {
            sendNativeTrade(session.toMessage(action: "CLOSE", item: nil))
        }
        clearPendingDecision()
            statusMessage = "Handel mit Ureinwohnern beendet."
    }

    private func sendNativeTradeAction(_ action: String, item: NativeTradeItem) {
        guard let session = pendingNativeTrade else { return }
        guard phase == .inGame, isLocalPlayersTurn else { return }
        errorMessage = nil
        sendNativeTrade(session.toMessage(action: action, item: item))
    }

    /// Send BUY/SELL with an optional offer price. A positive `offerPrice`
    /// below (buy) / above (sell) the native's price triggers a haggle.
    private func sendNativeTradeOffer(_ action: String, item: NativeTradeItem, offerPrice: Int?) {
        var offered = item
        if let offerPrice {
            offered.price = max(0, offerPrice)
        }
        sendNativeTradeAction(action, item: offered)
    }

    private func sendNativeTrade(_ message: ParsedMessage) {
        guard let client else {
            errorMessage = "Der Client ist nicht verbunden."
            return
        }
        Task {
            do {
                try await client.send(message: message)
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    // MARK: Phase 45 - Diplomacy

    func acceptDiplomacy() {
        respondToDiplomacy(accept: true)
    }

    func rejectDiplomacy() {
        respondToDiplomacy(accept: false)
    }

    private func respondToDiplomacy(accept: Bool) {
        guard let decision = pendingServerDecision, decision.type == .diplomacy,
              let proposal = decision.diplomaticTradeProposal else { return }
        guard phase == .inGame else { return }
        guard let client else {
            errorMessage = "Der Client ist nicht verbunden."
            return
        }

        var attributes = proposal.raw.attributes
        attributes["status"] = accept ? "ACCEPT_TRADE" : "REJECT_TRADE"
        let tradeNode = ParsedMessage(
            tag: "diplomaticTrade",
            attributes: attributes,
            children: proposal.raw.children
        )
        guard let ourId = decision.rawPayload["ourId"], !ourId.isEmpty,
              let otherId = decision.rawPayload["otherId"], !otherId.isEmpty else {
            errorMessage = "Diplomatie-Objekte fehlen."
            return
        }
        let message = ParsedMessage(
            tag: "diplomacy",
            attributes: ["ourId": ourId, "otherId": otherId],
            children: [tradeNode]
        )
        errorMessage = nil
        Task {
            do {
                _ = try await client.ask(message: message)
                if pendingServerDecision?.id == decision.id {
                    clearPendingDecision()
                    statusMessage = accept ? "Diplomatie: Annahme gesendet." : "Diplomatie: Ablehnung gesendet."
                }
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    /// Send a counter-proposal built from the given clause drafts.
    func sendDiplomacyCounterProposal(_ drafts: [DiplomaticClauseDraft]) {
        guard let decision = pendingServerDecision, decision.type == .diplomacy,
              let proposal = decision.diplomaticTradeProposal,
              phase == .inGame,
              let client else {
            errorMessage = "Kein diplomatischer Vorschlag aktiv."
            return
        }
        let ourId = decision.rawPayload["ourId"] ?? ""
        let otherId = decision.rawPayload["otherId"] ?? ""
        guard !ourId.isEmpty, !otherId.isEmpty,
              let localPlayerId = resolveLocalPlayerId(),
              let sender = proposal.sender, let recipient = proposal.recipient,
              sender == localPlayerId || recipient == localPlayerId else {
            errorMessage = "Diplomatie-Objekte fehlen."
            return
        }
        guard drafts.allSatisfy({ pendingDiplomacyClauseKinds.contains($0.kind) }) else {
            errorMessage = "Diese Vertragsklausel ist für die Tributverhandlung nicht verfügbar."
            return
        }

        var attributes = proposal.raw.attributes
        attributes["status"] = "PROPOSE_TRADE"
        attributes["version"] = String(proposal.version)
        let otherPlayerId = sender == localPlayerId ? recipient : sender
        let children = drafts.map {
            Self.diplomacyClauseNode($0, ourId: localPlayerId, otherId: otherPlayerId)
        }
        let tradeNode = ParsedMessage(tag: "diplomaticTrade", attributes: attributes, children: children)
        let message = ParsedMessage(
            tag: "diplomacy",
            attributes: ["ourId": ourId, "otherId": otherId],
            children: [tradeNode]
        )
        errorMessage = nil
        Task {
            do {
                _ = try await client.ask(message: message)
                if pendingServerDecision?.id == decision.id {
                    clearPendingDecision()
                    statusMessage = "Gegenangebot gesendet."
                }
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    /// Java keeps the original sender throughout a session; version zero is only the opening draft.
    var pendingDiplomacyIsIncoming: Bool {
        guard let proposal = pendingDiplomacy else { return false }
        return proposal.version > 0
    }

    /// Draft clauses pre-populated from the pending proposal.
    var pendingDiplomacyDrafts: [DiplomaticClauseDraft] {
        guard let decision = pendingServerDecision,
              let proposal = decision.diplomaticTradeProposal else {
            return []
        }
        let ourId = resolveLocalPlayerId() ?? ""
        return proposal.clauses.compactMap {
            DiplomaticClauseDraft(clause: $0, ourPlayerId: ourId)
        }
    }

    /// Serialize a clause draft into a `<*TradeItem>` node.
    nonisolated static func diplomacyClauseNode(_ draft: DiplomaticClauseDraft,
                                                 ourId: String,
                                                 otherId: String) -> ParsedMessage {
        let source = draft.weGive ? ourId : otherId
        let destination = draft.weGive ? otherId : ourId
        var attributes: Attributes = [
            "id": draft.kind.tradeItemId,
            "source": source,
            "destination": destination,
        ]
        var children: [ParsedMessage] = []
        switch draft.kind {
        case .gold:
            attributes["gold"] = String(draft.goldAmount)
        case .goods:
            children = [ParsedMessage(
                tag: "goods",
                attributes: ["type": draft.goodsType, "amount": String(draft.goodsAmount)],
                children: []
            )]
        case .colony:
            attributes["colony"] = draft.colonyId
            attributes["colonyName"] = draft.colonyName
        case .stance:
            attributes["stance"] = draft.stance
        case .unit:
            attributes["unit"] = draft.unitId
        case .incite:
            attributes["victim"] = draft.victimId
        }
        return ParsedMessage(tag: draft.kind.tag, attributes: attributes, children: children)
    }

    /// Units selectable for a diplomacy unit clause.
    func diplomacyUnitOptions(weGive: Bool) -> [(id: String, label: String)] {
        guard let game = cachedGame,
              let localPlayerId = resolveLocalPlayerId() else {
            return []
        }
        return game.units.values
            .filter { weGive ? $0.owner == localPlayerId : ($0.owner != localPlayerId && $0.owner != nil) }
            .map { (id: $0.id, label: "\($0.unitType ?? $0.id) [\($0.owner ?? "?")]") }
            .sorted { $0.label < $1.label }
    }

    /// Player ids selectable as an incite target (everyone but us).
    func diplomacyVictimOptions() -> [(id: String, label: String)] {
        guard let game = cachedGame,
              let localPlayerId = resolveLocalPlayerId() else {
            return []
        }
        return game.players.values
            .filter { $0.id != localPlayerId }
            .map { (id: $0.id, label: $0.name ?? $0.nationId ?? $0.id) }
            .sorted { $0.label < $1.label }
    }

    /// Reply to a `lootCargo` prompt with the selected goods stacks. An empty
    /// selection sends the reply with no `<goods>` children, meaning "loot nothing".
    func lootPendingCargo(selected: [LootGoodsOption]) {
        guard let decision = pendingServerDecision, decision.type == .lootCargo else { return }
        guard phase == .inGame else { return }

        var attributes: [String: String] = [:]
        if let winner = decision.rawPayload["winner"] { attributes["winner"] = winner }
        if let loser = decision.rawPayload["loser"] { attributes["loser"] = loser }

        let children = selected.map { option in
            ParsedMessage(
                tag: "goods",
                attributes: ["type": option.type, "amount": "\(option.amount)"],
                children: []
            )
        }
        sendDecision(tag: "lootCargo", attributes: attributes, children: children)
    }

    /// Place one fountain-of-youth emigrant in the given slot (1...3).
    /// Each call consumes one remaining migrant; the pending prompt closes at zero.
    func emigratePendingMigrant(slot: Int) {
        guard let decision = pendingServerDecision, decision.type == .fountainOfYouth else { return }
        guard phase == .inGame, isLocalPlayersTurn else { return }
        guard slot >= 1 && slot <= 3 else { return }
        guard let client else {
            errorMessage = "Der Client ist nicht verbunden."
            return
        }

        Task {
            do {
                let message = ParsedMessage(
                    tag: "emigrateUnit",
                    attributes: ["slot": "\(slot)"],
                    children: []
                )
                _ = try await client.ask(message: message)

                let remaining = decision.migrantCount - 1
                if remaining > 0 {
                    pendingServerDecision = PendingServerDecision(
                        type: .fountainOfYouth,
                        rawPayload: ["migrants": "\(remaining)"],
                        children: []
                    )
                    statusMessage = "Auswanderer platziert. Noch \(remaining) verfügbar."
                } else {
                    clearPendingDecision()
                    statusMessage = "Auswanderer platziert."
                }
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    private func sendDecision(tag: String, attributes: [String: String], children: [ParsedMessage]) {
        guard let client else {
            errorMessage = "Der Client ist nicht verbunden."
            return
        }
        Task {
            do {
                _ = try await client.ask(
                    message: ParsedMessage(tag: tag, attributes: attributes, children: children)
                )
                clearPendingDecision()
                statusMessage = "Entscheidung gesendet."
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    func resolveLocalPlayerId() -> String? {
        guard let game = cachedGame else { return cachedLocalPlayerId }
        if let clientUserName = game.clientUserName,
           let player = game.players.values.first(where: { $0.name == clientUserName }) {
            cachedLocalPlayerId = player.id
            return player.id
        }
        if let name = localPlayerName,
           let player = game.players.values.first(where: { $0.name == name }) {
            cachedLocalPlayerId = player.id
            return player.id
        }
        if let nationId = localNationId,
           let player = game.players.values.first(where: { $0.nationId == nationId }) {
            cachedLocalPlayerId = player.id
            return player.id
        }
        // The local player object may already have been removed (e.g. setDead).
        return cachedLocalPlayerId
    }

    private func applyServerState(_ state: ServerState) {
        serverState = state
        phase = state.isInGame ? .inGame : .lobby
        if phase != .inGame {
            clearPendingEndTurn()
        }
        statusMessage = state.isInGame ? "" : "Waiting for game start…"
    }

    private func resetSessionState() {
        movementAttempts.removeAll()
        europeTravelOrders.removeAll()
        saveRequestID = nil
        movementTask?.cancel()
        movementTask = nil
        movingUnitId = nil
        errorMessage = nil
        vacantPlayers = nil
        serverState = nil
        cachedGame = nil
        gameUpdateID = 0
        selectedUnitId = nil
        selectedTileId = nil
        mapZoomScale = 2.0
        isChoosingMoveDestination = false
        showEuropePanel = false
        closeColonyPanel()
        showDebugPanel = false
        showStatusPanel = false
        showReportsPanel = false
        showChatPanel = false
        showPreferencesPanel = false
        showColopediaPanel = false
        showIndependencePanel = false
        showFindSettlementPanel = false
        showTradeRoutesPanel = false
        showShortcutsHelp = false
        tileActionTileId = nil
        isReadyToStart = false
        localPlayerName = nil
        cachedLocalPlayerId = nil
        localNationId = nil
        localNationTypeId = nil
        localColorValue = nil
        seenModelMessageSignatures = []
        isEndingTurn = false
        pendingEndTurnTurn = nil
        incomingChatLog = []
        marketPriceHistory = [:]
        marketBuyPriceHistory = [:]
        isGameEnded = false
        isVictorious = false
        isDefeated = false
        isUndead = false
        gameEndedHighScore = false
        pendingServerDecision = nil
        mapAnimationCue = nil
        mapAnimationCueToken += 1
        didAutoFocusInitialUnit = false
    }

    func setReady(_ ready: Bool) {
        guard phase == .lobby else { return }
        errorMessage = nil
        let previous = isReadyToStart
        isReadyToStart = ready

        Task {
            do {
                let msg = ParsedMessage(
                    tag: "ready",
                    attributes: ["value": ready ? "true" : "false"],
                    children: []
                )
                try await client?.send(message: msg)
            } catch {
                isReadyToStart = previous
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    func requestLaunch() {
        guard phase == .lobby else { return }
        guard isLocalPlayerAdmin else {
            errorMessage = "Nur der Admin kann das Spiel starten."
            return
        }
        errorMessage = nil


        Task {
            do {
                let msg = ParsedMessage(tag: "requestLaunch", attributes: [:], children: [])
                try await client?.send(message: msg)
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    func setLocalPlayerNation(_ nationId: String) {
        guard phase == .lobby else { return }
        let trimmedNationId = nationId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNationId.isEmpty else {
            errorMessage = "Bitte eine Nation auswählen."
            return
        }
        guard let playerId = resolveLocalPlayerId() else {
            errorMessage = "Lokaler Spieler konnte nicht bestimmt werden."
            return
        }

        errorMessage = nil
        let previousNationId = localNationId
        let previousPlayerNationId = cachedGame?.players[playerId]?.nationId
        localNationId = trimmedNationId
        // The server does not echo setNation to its sender, so the local model is updated here.
        try? cachedGame?.applyPlayerChange(tag: "setNation", attributes: ["player": playerId, "value": trimmedNationId])
        gameUpdateID += 1

        Task {
            do {
                let msg = ParsedMessage(
                    tag: "setNation",
                    attributes: ["player": playerId, "value": trimmedNationId],
                    children: []
                )
                try await client?.send(message: msg)
            } catch {
                localNationId = previousNationId
                if let previousPlayerNationId {
                    try? cachedGame?.applyPlayerChange(tag: "setNation", attributes: ["player": playerId, "value": previousPlayerNationId])
                }
                gameUpdateID += 1
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    func setLocalPlayerNationType(_ nationTypeId: String) {
        guard phase == .lobby else { return }
        let trimmedNationTypeId = nationTypeId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNationTypeId.isEmpty else {
            errorMessage = "Bitte einen Nationstyp angeben."
            return
        }
        guard let playerId = resolveLocalPlayerId() else {
            errorMessage = "Lokaler Spieler konnte nicht bestimmt werden."
            return
        }

        errorMessage = nil
        let previousNationTypeId = localNationTypeId
        localNationTypeId = trimmedNationTypeId

        Task {
            do {
                let msg = ParsedMessage(
                    tag: "setNationType",
                    attributes: ["player": playerId, "value": trimmedNationTypeId],
                    children: []
                )
                try await client?.send(message: msg)
            } catch {
                localNationTypeId = previousNationTypeId
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    func setGameOption(_ optionId: String, value: String) {
        gameOptions[optionId] = value
    }

    func setLocalPlayerColor(_ colorValue: String) {
        guard phase == .lobby else { return }
        let trimmedColorValue = colorValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedColorValue.isEmpty else {
            errorMessage = "Bitte einen Farbwert angeben."
            return
        }
        guard let playerId = resolveLocalPlayerId() else {
            errorMessage = "Lokaler Spieler konnte nicht bestimmt werden."
            return
        }
        guard let player = cachedGame?.players[playerId],
              let nationId = player.nationId else {
            errorMessage = "Nation des Spielers konnte nicht bestimmt werden."
            return
        }

        errorMessage = nil
        let previousColorValue = localColorValue
        localColorValue = trimmedColorValue

        Task {
            do {
                let msg = ParsedMessage(
                    tag: "setColor",
                    attributes: [
                        "nation": nationId,
                        "color": Self.rgbValue(fromHexCSS: trimmedColorValue) ?? trimmedColorValue,
                    ],
                    children: []
                )
                try await client?.send(message: msg)
            } catch {
                localColorValue = previousColorValue
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    /// Convert a "#RRGGBB" CSS-style color to the signed RGB int the Java server expects.
    static func rgbValue(fromHexCSS hex: String) -> String? {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") {
            value.removeFirst()
        }
        guard value.count == 6,
              let rgb = Int(value, radix: 16) else {
            return nil
        }
        let signed = Int32(truncatingIfNeeded: rgb)
        return String(signed)
    }

    func updateSingleGameOption(id optionId: String, value optionValue: String) {
        guard phase == .lobby else { return }
        let trimmedOptionId = optionId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedOptionValue = optionValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedOptionId.isEmpty else {
            errorMessage = "Bitte eine Option-ID angeben."
            return
        }
        guard !trimmedOptionValue.isEmpty else {
            errorMessage = "Bitte einen Optionswert angeben."
            return
        }

        errorMessage = nil


        Task {
            do {
                let optionChild = ParsedMessage(
                    tag: "option",
                    attributes: ["id": trimmedOptionId, "value": trimmedOptionValue],
                    children: []
                )
                let msg = ParsedMessage(
                    tag: "updateGameOptions",
                    attributes: [:],
                    children: [optionChild]
                )
                try await client?.send(message: msg)
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    func updateSingleMapGeneratorOption(id optionId: String, value optionValue: String) {
        guard phase == .lobby else { return }
        let trimmedOptionId = optionId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedOptionValue = optionValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedOptionId.isEmpty else {
            errorMessage = "Bitte eine Kartenoption-ID angeben."
            return
        }
        guard !trimmedOptionValue.isEmpty else {
            errorMessage = "Bitte einen Map-Optionswert angeben."
            return
        }

        errorMessage = nil


        Task {
            do {
                let optionChild = ParsedMessage(
                    tag: "option",
                    attributes: ["id": trimmedOptionId, "value": trimmedOptionValue],
                    children: []
                )
                let msg = ParsedMessage(
                    tag: "updateMapGeneratorOptions",
                    attributes: [:],
                    children: [optionChild]
                )
                try await client?.send(message: msg)
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    func chooseFoundingFather(_ foundingFatherId: String) {
        guard phase == .lobby || phase == .inGame else { return }
        let trimmedFoundingFatherId = foundingFatherId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedFoundingFatherId.isEmpty else {
            errorMessage = "Bitte eine Gründervater-ID angeben."
            return
        }

        errorMessage = nil


        Task {
            do {
                let msg = ParsedMessage(
                    tag: "chooseFoundingFather",
                    attributes: ["foundingFather": trimmedFoundingFatherId],
                    children: []
                )
                try await client?.send(message: msg)
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    func sendContinue() {
        guard phase == .inGame else { return }
        errorMessage = nil


        Task {
            do {
                let msg = ParsedMessage(tag: "continue", attributes: [:], children: [])
                try await client?.send(message: msg)
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    func retireGame() {
        guard phase == .inGame else { return }
        errorMessage = nil


        Task {
            do {
                let msg = ParsedMessage(tag: "retire", attributes: [:], children: [])
                try await client?.send(message: msg)
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    func enterRevengeMode() {
        guard phase == .inGame else { return }
        errorMessage = nil


        Task {
            do {
                let msg = ParsedMessage(tag: "enterRevengeMode", attributes: [:], children: [])
                try await client?.send(message: msg)
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    func declineMoundsForSelectedUnit() {
        guard phase == .inGame,
              let unitId = selectedUnitId else {
            return
        }
        errorMessage = nil


        Task {
            do {
                let msg = ParsedMessage(tag: "declineMounds", attributes: ["unit": unitId], children: [])
                try await client?.send(message: msg)
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    func sendMonarchAction(_ actionType: String) {
        guard phase == .inGame else { return }
        let trimmedActionType = actionType.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedActionType.isEmpty else {
            errorMessage = "Bitte einen Monarch-Action-Typ angeben."
            return
        }

        errorMessage = nil


        Task {
            do {
                // Java reads `action` plus a boolean `result` here.
                let msg = ParsedMessage(
                    tag: "monarchAction",
                    attributes: ["action": trimmedActionType, "result": "true"],
                    children: []
                )
                try await client?.send(message: msg)
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    func setLocalPlayerAI(_ enabled: Bool) {
        guard phase == .inGame else { return }
        guard let playerId = resolveLocalPlayerId() else {
            errorMessage = "Lokaler Spieler konnte nicht bestimmt werden."
            return
        }

        errorMessage = nil


        Task {
            do {
                let msg = ParsedMessage(
                    tag: "setAI",
                    attributes: ["player": playerId, "ai": enabled ? "true" : "false"],
                    children: []
                )
                try await client?.send(message: msg)
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    func setLocalPlayerAvailable() {
        guard phase == .inGame else { return }
        guard let playerId = resolveLocalPlayerId(),
              let player = cachedGame?.players[playerId],
              let nationId = player.nationId else {
            errorMessage = "Lokaler Spieler konnte nicht bestimmt werden."
            return
        }

        errorMessage = nil

        // Match the Java client: toggle the nation availability state.
        let current = cachedGame?.nationStates[nationId] ?? "AVAILABLE"
        let nextState = current == "NOT_AVAILABLE" ? "AVAILABLE" : "NOT_AVAILABLE"

        Task {
            do {
                let msg = ParsedMessage(
                    tag: "setAvailable",
                    attributes: ["nation": nationId, "state": nextState],
                    children: []
                )
                try await client?.send(message: msg)
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    func setStance(stance: String, targetPlayerId: String) {
        guard phase == .inGame else { return }
        let trimmedStance = stance.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTarget = targetPlayerId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedStance.isEmpty else {
            errorMessage = "Bitte eine Stance angeben."
            return
        }
        guard !trimmedTarget.isEmpty else {
            errorMessage = "Bitte eine Ziel-Spieler-ID angeben."
            return
        }
        guard let sourcePlayerId = resolveLocalPlayerId() else {
            errorMessage = "Lokaler Spieler konnte nicht bestimmt werden."
            return
        }

        errorMessage = nil


        Task {
            do {
                let msg = ParsedMessage(
                    tag: "setStance",
                    attributes: ["stance": trimmedStance, "source": sourcePlayerId, "target": trimmedTarget],
                    children: []
                )
                try await client?.send(message: msg)
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    func declareIndependence(countryName: String, nationName: String) {
        guard phase == .inGame else { return }
        let trimmedCountry = countryName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNation = nationName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCountry.isEmpty else {
            errorMessage = "Bitte einen Landesnamen angeben."
            return
        }
        guard !trimmedNation.isEmpty else {
            errorMessage = "Bitte einen Nationsnamen angeben."
            return
        }

        errorMessage = nil


        Task {
            do {
                let msg = ParsedMessage(
                    tag: "declareIndependence",
                    attributes: ["countryName": trimmedCountry, "nationName": trimmedNation],
                    children: []
                )
                try await client?.send(message: msg)
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    func sendChatMessage(message: String, privateRecipientId: String) {
        guard phase == .inGame else { return }
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPrivate = privateRecipientId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else {
            errorMessage = "Bitte eine Chat-Nachricht angeben."
            return
        }
        guard let senderId = resolveLocalPlayerId() else {
            errorMessage = "Lokaler Spieler konnte nicht bestimmt werden."
            return
        }

        errorMessage = nil


        Task {
            do {
                var attributes: [String: String] = [
                    "sender": senderId,
                    "message": trimmedMessage
                ]
                if !trimmedPrivate.isEmpty {
                    attributes["private"] = trimmedPrivate
                }
                let msg = ParsedMessage(tag: "chat", attributes: attributes, children: [])
                try await client?.send(message: msg)
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    func setLocalPlayerDead() {
        guard phase == .inGame else { return }
        guard let playerId = resolveLocalPlayerId() else {
            errorMessage = "Lokaler Spieler konnte nicht bestimmt werden."
            return
        }

        errorMessage = nil


        Task {
            do {
                let msg = ParsedMessage(tag: "setDead", attributes: ["player": playerId], children: [])
                try await client?.send(message: msg)
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    func claimLand(price: String, tileId: String) {
        guard phase == .inGame else { return }
        let trimmedPrice = price.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTile = tileId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrice.isEmpty else {
            errorMessage = "Bitte einen Preis angeben."
            return
        }
        guard !trimmedTile.isEmpty else {
            errorMessage = "Bitte eine Kachel angeben."
            return
        }
        guard let claimant = resolveLocalPlayerId() else {
            errorMessage = "Lokaler Spieler konnte nicht bestimmt werden."
            return
        }

        errorMessage = nil


        Task {
            do {
                let msg = ParsedMessage(
                    tag: "claimLand",
                    attributes: ["price": trimmedPrice, "claimant": claimant, "tile": trimmedTile],
                    children: []
                )
                try await client?.send(message: msg)
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    /// Set while the end-turn confirmation dialog lists units without orders.
    var showEndTurnDialog: Bool = false

    /// Pending combat confirmation (Java `PreCombatDialog`).
    var showAttackConfirmation: Bool = false
    private var pendingAttackTileId: String?
    private var pendingAttackRanged: Bool = false

    /// Ask for confirmation before attacking the given tile.
    func requestAttack(onTile tileId: String, ranged: Bool) {
        let allowed = ranged
            ? canAttackSelectedUnitRanged(onTile: tileId)
            : canAttackSelectedUnitMelee(onTile: tileId)
        guard allowed else {
            errorMessage = "Angriff nicht möglich."
            return
        }
        pendingAttackTileId = tileId
        pendingAttackRanged = ranged
        showAttackConfirmation = true
    }

    func confirmPendingAttack() {
        guard let tileId = pendingAttackTileId else { return }
        let ranged = pendingAttackRanged
        dismissPendingAttack()
        if ranged {
            attackSelectedUnitRanged(onTile: tileId)
        } else {
            attackSelectedUnitMelee(onTile: tileId)
        }
    }

    func dismissPendingAttack() {
        showAttackConfirmation = false
        pendingAttackTileId = nil
        pendingAttackRanged = false
    }

    /// Short summary of the pending attack for the dialog.
    var pendingAttackSummary: String {
        guard let tileId = pendingAttackTileId,
              let game = cachedGame,
              let unit = selectedUnit else { return "" }
        let defender = game.units.values.first {
            game.resolvedTileId(for: $0) == tileId && $0.owner != unit.owner
        }
        let attacker = unit.unitType.flatMap { $0.split(separator: ".").last.map(String.init) } ?? unit.id
        let target = defender?.unitType.flatMap { $0.split(separator: ".").last.map(String.init) } ?? tileId
        let kind = pendingAttackRanged ? "Ranged" : "Melee"
        return "\(kind): \(attacker) → \(target)"
    }

    /// End the turn, prompting first when units still have orders left.
    func requestEndTurn() {
        if unitsAwaitingOrders.isEmpty {
            endTurn()
        } else {
            showEndTurnDialog = true
        }
    }

    func confirmEndTurn() {
        showEndTurnDialog = false
        endTurn()
    }

    func dismissEndTurnDialog() {
        showEndTurnDialog = false
    }

    /// Java handles core in-game actions as `<question>` requests and returns a
    /// `<reply>` containing the result/change set. The local mock server only
    /// implements the fire-and-forget subset, so retain that transport locally.
    private func sendCoreGameplayAction(
        _ message: ParsedMessage,
        timeout: TimeInterval? = nil,
        queueIfDisconnected: Bool = true
    ) async throws {
        guard let client else { throw FreeColProtocolError.disconnected }
        if usesLocalServer {
            try await client.send(message: message)
        } else {
            do {
                _ = try await client.ask(message: message, timeout: timeout ?? Self.coreGameplayAskTimeout)
            } catch FreeColProtocolError.serverError(let raw) {
                throw UserFacingActionError(message: Self.userFacingServerError(raw))
            } catch {
                if queueIfDisconnected, Self.isTransportDisconnect(error) {
                    queuedGameplayActions.append(QueuedGameplayAction(id: UUID(), message: message))
                }
                throw error
            }
        }
    }

    private nonisolated static func isTransportDisconnect(_ error: Error) -> Bool {
        guard let protocolError = error as? FreeColProtocolError else { return false }
        switch protocolError {
        case .disconnected, .connectionFailed(_):
            return true
        default:
            return false
        }
    }

    /// Error carrying a German, user-facing message; `localizedDescription` returns it.
    struct UserFacingActionError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    /// Map raw Java server rejection texts (`ServerAPI` clientError) to user-facing messages.
    /// Unknown texts are passed through so no server information is lost.
    nonisolated static func userFacingServerError(_ raw: String) -> String {
        ServerErrorMessage.userFacing(raw)
    }

    nonisolated static func endTurnSafetyTimeout(localServer: Bool, askTimeout: TimeInterval) -> TimeInterval {
        localServer ? 8 : askTimeout + 5
    }

    func endTurn() {
        guard phase == .inGame else {
            errorMessage = "Diese Aktion ist nur im laufenden Spiel verfügbar."
            return
        }
        guard !isEndingTurn else {
            errorMessage = "Warte auf Serverantwort fuer Zugende."
            return
        }
        guard canEndTurn else {
            errorMessage = "Du bist gerade nicht am Zug."
            return
        }
        guard let game = cachedGame else { return }
        errorMessage = nil
        isEndingTurn = true
        pendingEndTurnTurn = game.turn.number
        endTurnToken += 1
        let token = endTurnToken
        let safetyTimeout = Self.endTurnSafetyTimeout(
            localServer: usesLocalServer,
            askTimeout: Self.coreGameplayAskTimeout
        )

        Task {
            do {
                await executeTradeRoutesOnTurnEnd()
                // Start the watchdog only after pre-turn actions have been
                // queued; remote asks get their full reply timeout plus margin.
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: UInt64(safetyTimeout * 1_000_000_000))
                    guard token == self.endTurnToken, self.isEndingTurn else { return }
                    self.clearPendingEndTurn()
                    self.statusMessage = "Zugende nicht bestätigt – bitte erneut versuchen."
                }
                let msg = ParsedMessage(tag: "endTurn", attributes: [:], children: [])
                try await sendCoreGameplayAction(msg, timeout: Self.coreGameplayAskTimeout)
            } catch {
                clearPendingEndTurn()
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    func selectUnit(_ unitId: String?, onTile tileId: String?) {
        isChoosingMoveDestination = false
        selectedUnitId = unitId
        selectedTileId = tileId
    }

    func selectMapTile(_ tileId: String, openColony: Bool = false) {
        guard let game = cachedGame, game.tiles[tileId] != nil else {
            errorMessage = "Das Kartenfeld ist nicht verfügbar."
            return
        }

        closeTileActions()
        if isChoosingMoveDestination {
            isChoosingMoveDestination = false
            moveSelectedUnitTo(destinationTileId: tileId)
            return
        }
        selectedTileId = tileId
        if openColony, selectedColony != nil {
            openColonyPanel()
            return
        }
        guard let localPlayerId else { return }

        let units = game.units.values
            .filter { $0.owner == localPlayerId && $0.location == tileId }
            .sorted { $0.id < $1.id }
        if !units.isEmpty {
            if let index = units.firstIndex(where: { $0.id == selectedUnitId }) {
                selectedUnitId = units[(index + 1) % units.count].id
            } else {
                selectedUnitId = units[0].id
            }
        }
    }

    func rightClickMapTile(_ tileId: String, showMenu: Bool = false) {
        guard cachedGame?.tiles[tileId] != nil else {
            errorMessage = "Das Kartenfeld ist nicht verfügbar."
            return
        }
        if selectedUnitId != nil, !showMenu {
            closeTileActions()
            isChoosingMoveDestination = false
            moveSelectedUnitTo(destinationTileId: tileId)
        } else {
            selectedTileId = tileId
            openTileActions(tileId)
        }
    }

    var canChooseMoveDestination: Bool {
        selectedUnitMoveDisabledReason == nil
    }

    /// A reason suitable for a disabled Move control, derived from the same
    /// guards that determine whether movement is currently available.
    var selectedUnitMoveDisabledReason: String? {
        guard phase == .inGame else { return "Bewegen ist nur im laufenden Spiel möglich." }
        guard isLocalPlayersTurn else { return "Bewegen ist nur im eigenen Zug möglich." }
        guard movingUnitId == nil else { return "Eine andere Bewegung wird noch verarbeitet." }
        guard let game = cachedGame, let unit = selectedUnit,
              let localPlayerId else { return "Wähle zuerst eine eigene Einheit aus." }
        guard unit.owner == localPlayerId else { return "Du kannst nur eigene Einheiten bewegen." }
        guard unit.movesLeft > 0 else { return "Diese Einheit hat keine Bewegungspunkte mehr." }
        guard canIssueMovementOrders(for: unit, in: game) else {
            return "Für diese Einheit sind derzeit keine Bewegungsbefehle möglich."
        }
        guard let unitLocation = unit.location else {
            return "Diese Einheit befindet sich nicht auf einer gültigen Kartenposition."
        }
        let isColonyLocation = game.colonies[unitLocation] != nil
            || game.colonies.values.contains { colony in
                colony.buildings.contains { $0.id == unitLocation }
                    || colony.workTiles.contains { $0.id == unitLocation }
            }
        let isOwnedCarrierLocation = game.units[unitLocation].map {
            isCarrierUnit($0) && $0.owner == unit.owner
        } == true
        // Colony/work-location IDs resolve to the colony tile. Carrier IDs
        // also resolve to a tile and remain eligible for disembark checks.
        guard game.tiles[unitLocation] != nil || isColonyLocation || isOwnedCarrierLocation,
              let location = resolveUnitTileId(unit, in: game), game.tiles[location] != nil else {
            return "Diese Einheit befindet sich nicht auf einer gültigen Kartenposition."
        }
        return nil
    }

    /// Shared explanation for optional unit actions whose more specific
    /// eligibility is represented by their existing `can…` guards.
    var selectedUnitActionUnavailableReason: String {
        if phase != .inGame { return "Aktionen sind nur im laufenden Spiel verfügbar." }
        if !isLocalPlayersTurn { return "Aktionen sind nur im eigenen Zug verfügbar." }
        if movingUnitId != nil { return "Eine andere Aktion wird noch verarbeitet." }
        if isSavingGame { return "Während des Speicherns sind Aktionen vorübergehend gesperrt." }
        guard let unit = selectedUnit else { return "Wähle zuerst eine Einheit aus." }
        if unit.owner != resolveLocalPlayerId() { return "Du kannst nur eigene Einheiten befehligen." }
        return "Die Voraussetzungen für diese Aktion sind derzeit nicht erfüllt."
    }

    var errorRecoveryActionTitle: String? {
        guard let errorMessage else { return nil }
        let knownMovementErrors = [
            "Ziel kann nicht erreicht werden.",
            "Kein begehbarer Weg zum Ziel verfügbar.",
            "Der weitere Weg zum Ziel ist blockiert.",
            "Die Bewegung wurde vom Server nicht ausgeführt.",
        ]
        guard knownMovementErrors.contains(errorMessage) else { return nil }
        if isChoosingMoveDestination { return "Zielauswahl abbrechen" }
        if canClearSelectedUnitDestination { return "Marschziel löschen" }
        return nil
    }

    func performErrorRecoveryAction() {
        guard errorRecoveryActionTitle != nil else { return }
        if isChoosingMoveDestination {
            cancelChoosingMoveDestination()
        } else if canClearSelectedUnitDestination {
            clearSelectedUnitDestination()
        }
    }

    func beginChoosingMoveDestination() {
        guard canChooseMoveDestination else {
            errorMessage = "Diese Einheit kann gerade nicht bewegt werden."
            return
        }
        closeTileActions()
        isChoosingMoveDestination = true
    }

    func cancelChoosingMoveDestination() {
        isChoosingMoveDestination = false
    }

    // MARK: Phase 56 - tile popup

    /// Tile whose context menu (Java `TilePopup`) is currently shown.
    var tileActionTileId: String?

    func openTileActions(_ tileId: String) {
        tileActionTileId = tileId
    }

    func closeTileActions() {
        tileActionTileId = nil
    }

    var tileActionTile: Tile? {
        guard let tileActionTileId else { return nil }
        return cachedGame?.tiles[tileActionTileId]
    }

    func moveSelectedUnit(to destinationTileId: String) {
        guard canMoveSelectedUnit(to: destinationTileId) else {
            errorMessage = "Ungültige Bewegung."
            return
        }
        startMovingSelectedUnit(to: destinationTileId)
    }

    func canMoveSelectedUnitTo(destinationTileId: String) -> Bool {
        guard canChooseMoveDestination,
              let game = cachedGame,
              let sourceTileId = selectedUnitTileId,
              sourceTileId != destinationTileId,
              game.tiles[destinationTileId] != nil else {
            return false
        }
        return true
    }

    func moveSelectedUnitTo(destinationTileId: String) {
        guard canChooseMoveDestination else {
            errorMessage = selectedUnitMoveDisabledReason ?? "Diese Einheit kann gerade nicht bewegt werden."
            return
        }
        guard let unit = selectedUnit, let game = cachedGame else {
            errorMessage = "Wähle zuerst eine eigene Einheit aus."
            return
        }
        guard let sourceTileId = selectedUnitTileId else {
            errorMessage = "Diese Einheit befindet sich nicht auf einer gültigen Kartenposition."
            return
        }
        guard game.tiles[destinationTileId] != nil else {
            errorMessage = "Das ausgewählte Zielfeld ist nicht verfügbar."
            return
        }
        guard sourceTileId != destinationTileId else {
            errorMessage = "Das Zielfeld ist bereits der Standort dieser Einheit."
            return
        }
        guard canMoveSelectedUnitTo(destinationTileId: destinationTileId) else {
            errorMessage = "Ziel kann nicht erreicht werden."
            return
        }
        guard nextStepTowardDestination(for: unit, destinationTileId: destinationTileId, in: game) != nil else {
            errorMessage = "Kein begehbarer Weg zum Ziel verfügbar."
            return
        }
        startMovingSelectedUnit(to: destinationTileId)
    }

    private func startMovingSelectedUnit(to destinationTileId: String) {
        guard let unitId = selectedUnitId else { return }
        europeTravelOrders.remove(unitId)
        startMovingUnit(unitId, to: destinationTileId)
    }

    private func startMovingUnit(_ unitId: String, to destinationTileId: String) {
        guard movingUnitId == nil, let game = cachedGame else { return }
        movingUnitId = unitId
        movementAttempts[unitId] = game.turn.number
        let sendsToEurope = europeTravelOrders.contains(unitId)
        let storesDestination = game.units[unitId].map { unit in
            sendsToEurope || unit.destination == destinationTileId
                || resolveUnitTileId(unit, in: game).map {
                    attackDirection(fromTileId: $0, toTileId: destinationTileId, in: game) == nil
                } == true
        } ?? false
        movementTask = Task {
            defer {
                if movingUnitId == unitId {
                    movingUnitId = nil
                    movementTask = nil
                    continueSavedMovementOrders()
                }
            }
            do {
                if storesDestination, let unit = game.units[unitId], unit.destination != destinationTileId {
                    try await sendCoreGameplayAction(ParsedMessage(tag: "setDestination", attributes: [
                        "unit": unitId, "destination": destinationTileId,
                    ], children: []), queueIfDisconnected: false)
                    if usesLocalServer {
                        game.setUnitDestination(unitId: unitId, destinationId: destinationTileId)
                        gameUpdateID += 1
                    }
                }
                while !Task.isCancelled, cachedGame === game, isLocalPlayersTurn,
                      let unit = game.units[unitId], unit.movesLeft > 0, canIssueMovementOrders(for: unit, in: game),
                      (!storesDestination || unit.destination == destinationTileId),
                      let source = resolveUnitTileId(unit, in: game), source != destinationTileId {
                    guard let next = nextStepTowardDestination(for: unit, destinationTileId: destinationTileId, in: game),
                          let direction = attackDirection(fromTileId: source, toTileId: next, in: game) else {
                        throw UserFacingActionError(message: "Der weitere Weg zum Ziel ist blockiert.")
                    }
                    try Task.checkCancellation()
                    try await sendCoreGameplayAction(ParsedMessage(tag: "move", attributes: [
                        "unit": unitId, "direction": direction,
                    ], children: []), queueIfDisconnected: false)
                    if usesLocalServer {
                        game.moveUnit(unitId, to: next)
                        game.changeUnitState(unitId: unitId, state: .active)
                        gameUpdateID += 1
                    }
                    guard !Task.isCancelled, cachedGame === game else { return }
                    guard let moved = game.units[unitId], resolveUnitTileId(moved, in: game) == next,
                          moved.location != unit.location else {
                        throw UserFacingActionError(message: "Die Bewegung wurde vom Server nicht ausgeführt.")
                    }
                    errorMessage = nil
                    if selectedUnitId == unitId {
                        selectedTileId = resolveUnitTileId(moved, in: game)
                    }
                }
                if sendsToEurope, cachedGame === game,
                   let unit = game.units[unitId],
                   resolveUnitTileId(unit, in: game) == destinationTileId,
                   game.tiles[destinationTileId]?.moveToEurope == true,
                   let europeId = localPlayer?.europe?.id {
                    try await sendCoreGameplayAction(
                        Self.moveToMessage(unitId: unitId, destinationId: europeId),
                        queueIfDisconnected: false
                    )
                    if server != nil {
                        game.setUnitDestination(unitId: unitId, destinationId: europeId)
                        gameUpdateID += 1
                    }
                    europeTravelOrders.remove(unitId)
                    statusMessage = "Segelt nach Europa."
                }
                if storesDestination, !sendsToEurope, cachedGame === game, let unit = game.units[unitId],
                   resolveUnitTileId(unit, in: game) == destinationTileId {
                    try await sendCoreGameplayAction(ParsedMessage(
                        tag: "setDestination", attributes: ["unit": unitId], children: []
                    ), queueIfDisconnected: false)
                    game.setUnitDestination(unitId: unitId, destinationId: nil)
                    gameUpdateID += 1
                }
            } catch is CancellationError {
                return
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }


    func buildColony(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Bitte einen Kolonienamen eingeben."
            return
        }
        guard canBuildSelectedColony,
              let unitId = selectedUnitId,
              let game = cachedGame else {
            errorMessage = "Kolonie kann hier nicht gegruendet werden."
            return
        }
        if game.colonies.values.contains(where: { ($0.name ?? "").caseInsensitiveCompare(trimmed) == .orderedSame }) {
            errorMessage = "Der Koloniename ist bereits vergeben."
            return
        }
        errorMessage = nil


        Task {
            do {
                let msg = ParsedMessage(
                    tag: "buildColony",
                    attributes: ["unit": unitId, "name": trimmed],
                    children: []
                )
                let colonyTileId = game.units[unitId]?.location
                if server != nil {
                    game.buildColony(unitId: unitId, colonyName: trimmed)
                    reconcileSelectionWithGame()
                    gameUpdateID += 1
                }
                try await sendCoreGameplayAction(msg)
                // Keep the colony tile focused after founding so the new colony panel appears.
                if let tileId = colonyTileId ?? selectedTileId {
                    selectUnit(nil, onTile: tileId)
                } else {
                    selectUnit(nil, onTile: nil)
                }
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    func joinSelectedColony() {
        guard canJoinSelectedColony,
              let unitId = selectedUnitId,
              let tileId = selectedTileId,
              let game = cachedGame,
              let colony = game.colonies.values.first(where: { $0.tileId == tileId }) else {
            errorMessage = "Eintritt in die Kolonie nicht möglich."
            return
        }

        errorMessage = nil
        Task {
            do {
                let msg = ParsedMessage(
                    tag: "joinColony",
                    attributes: ["unit": unitId, "colony": colony.id],
                    children: []
                )
                if server != nil {
                    game.joinColony(unitId: unitId, colonyId: colony.id)
                    reconcileSelectionWithGame()
                    gameUpdateID += 1
                }
                try await client?.send(message: msg)
                selectUnit(nil, onTile: tileId)
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    func canEmbarkSelectedUnit(onCarrier carrierId: String) -> Bool {
        guard let unitId = selectedUnitId else { return false }
        return canEmbarkUnit(unitId, onCarrier: carrierId)
    }

    func canEmbarkUnit(_ unitId: String, onCarrier carrierId: String) -> Bool {
        guard phase == .inGame,
              isLocalPlayersTurn,
              movingUnitId == nil,
              let game = cachedGame,
              let unit = game.units[unitId],
              let carrier = game.units[carrierId],
              let localPlayerId = resolveLocalPlayerId(),
              unit.owner == localPlayerId,
              carrier.owner == localPlayerId,
              !isNavalUnit(unit),
              let unitLoc = unit.location,
              let carrierLoc = carrier.location,
              unit.id != carrier.id,
              isCarrierUnit(carrier) else {
            return false
        }
        let direction = unitLoc == carrierLoc ? nil : attackDirection(fromTileId: unitLoc, toTileId: carrierLoc, in: game)
        guard unitLoc == carrierLoc || (direction != nil && unit.movesLeft > 0),
              game.tiles[unitLoc] != nil || localPlayer?.europe?.id == unitLoc else {
            return false
        }
        if let capacity = carrier.unitType.flatMap({ game.specification?.unitTypes[$0]?.cargoSpace }) {
            let passengers = game.units.values.filter { $0.location == carrierId }
            let occupied = passengers.reduce(0) {
                $0 + ($1.unitType.flatMap { game.specification?.unitTypes[$0]?.spaceTakenOnCarrier } ?? 1)
            } + carrier.goods.values.reduce(0) { $0 + max(0, ($1 + 99) / 100) }
            let required = unit.unitType.flatMap { game.specification?.unitTypes[$0]?.spaceTakenOnCarrier } ?? 1
            guard occupied + required <= capacity else { return false }
        }
        return true
    }

    func embarkSelectedUnit(onCarrier carrierId: String) {
        guard canEmbarkSelectedUnit(onCarrier: carrierId),
              let unitId = selectedUnitId,
              let game = cachedGame else {
            errorMessage = "Einschiffen nicht möglich."
            return
        }
        errorMessage = nil
        movingUnitId = unitId
        Task {
            defer { if movingUnitId == unitId { movingUnitId = nil } }
            do {
                let msg = ParsedMessage(
                    tag: "embark",
                    attributes: embarkAttributes(unitId: unitId, carrierId: carrierId, in: game),
                    children: []
                )
                try await sendCoreGameplayAction(msg, queueIfDisconnected: false)
                guard cachedGame === game else { return }
                // Java replies to an embark-from-adjacent-tile with an
                // animateMove to the carrier's tile, not a passenger location
                // update. Reconcile that animation to the requested carrier
                // after the server confirms the action, or the passenger is
                // left as a separate unit on the ship's map tile.
                game.embarkUnit(unitId: unitId, carrierId: carrierId)
                gameUpdateID += 1
                guard game.units[unitId]?.location == carrierId else {
                    throw UserFacingActionError(message: "Der Server hat das Einschiffen nicht bestätigt.")
                }
                reconcileSelectionWithGame()
                statusMessage = "Einheit ist an Bord."
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    private func embarkAttributes(unitId: String, carrierId: String, in game: Game) -> [String: String] {
        var attributes = ["unit": unitId, "carrier": carrierId]
        if let unitLocation = game.units[unitId]?.location,
           let carrierLocation = game.units[carrierId]?.location,
           unitLocation != carrierLocation,
           let direction = attackDirection(fromTileId: unitLocation, toTileId: carrierLocation, in: game) {
            attributes["direction"] = direction
        }
        return attributes
    }

    func disembarkSelectedUnit() {
        guard canDisembarkSelectedUnit,
              let unitId = selectedUnitId,
              let unit = selectedUnit,
              let game = cachedGame else {
            errorMessage = selectedUnitDisembarkHint ?? "Ausschiffen nicht möglich."
            return
        }
        errorMessage = nil
        if !selectedUnitCanDisembarkInPlace {
            if let destination = selectedTileId,
               nextStepTowardDestination(for: unit, destinationTileId: destination, in: game) == destination {
                moveSelectedUnitTo(destinationTileId: destination)
            } else {
                beginChoosingMoveDestination()
                statusMessage = "Zum Ausschiffen ein benachbartes Landfeld auswählen."
            }
            return
        }

        Task {
            do {
                let msg = ParsedMessage(
                    tag: "disembark",
                    attributes: ["unit": unitId],
                    children: []
                )
                try await sendCoreGameplayAction(msg, queueIfDisconnected: false)
                if usesLocalServer {
                    game.disembarkUnit(unitId: unitId)
                    reconcileSelectionWithGame()
                    gameUpdateID += 1
                }
                guard game.units[unitId]?.location != unit.location else {
                    throw UserFacingActionError(message: "Das Ausschiffen wurde vom Server nicht ausgeführt.")
                }
                syncAfterModelUpdate()
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    func disbandSelectedUnit() {
        guard canDisbandSelectedUnit,
              let unitId = selectedUnitId,
              let game = cachedGame else {
            errorMessage = "Einheit kann nicht aufgeloest werden."
            return
        }
        errorMessage = nil


        Task {
            do {
                let msg = ParsedMessage(
                    tag: "disbandUnit",
                    attributes: ["unit": unitId],
                    children: []
                )
                if server != nil {
                    game.disbandUnit(unitId: unitId)
                    reconcileSelectionWithGame()
                    gameUpdateID += 1
                }
                try await client?.send(message: msg)
                if selectedUnitId == unitId {
                    selectUnit(nil, onTile: selectedTileId)
                }
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    func canSetSelectedUnitDestination(to destinationTileId: String) -> Bool {
        guard phase == .inGame,
              isLocalPlayersTurn,
              movingUnitId == nil, !isSavingGame,
              let game = cachedGame,
              let unitId = selectedUnitId,
              let unit = game.units[unitId],
              let localPlayerId = resolveLocalPlayerId(),
              unit.owner == localPlayerId,
              game.tiles[unit.location ?? ""] != nil,
              canIssueMovementOrders(for: unit, in: game),
              game.tiles[destinationTileId] != nil else {
            return false
        }
        return unit.destination != destinationTileId
    }

    func setSelectedUnitDestination(to destinationTileId: String) {
        guard canSetSelectedUnitDestination(to: destinationTileId),
              let unitId = selectedUnitId,
              let game = cachedGame else {
            errorMessage = "Ziel kann nicht gesetzt werden."
            return
        }
        updateMovementOrders(unitId, destination: destinationTileId, activate: false, in: game)
    }

    func clearSelectedUnitDestination() {
        guard canClearSelectedUnitDestination,
              let unitId = selectedUnitId,
              let game = cachedGame else {
            errorMessage = "Kein Ziel zum Entfernen gesetzt."
            return
        }
        updateMovementOrders(unitId, destination: nil, activate: false, in: game)
    }

    // MARK: Phase 56 - unit orders

    /// True when the selected unit has any orders that can be cleared.
    var canClearSelectedUnitOrders: Bool {
        guard phase == .inGame,
              isLocalPlayersTurn,
              movingUnitId == nil, !isSavingGame,
              let game = cachedGame,
              let unitId = selectedUnitId,
              let unit = game.units[unitId],
              let localPlayerId = resolveLocalPlayerId(),
              unit.owner == localPlayerId else {
            return false
        }
        return unit.destination != nil || unit.state != .active
    }

    /// Clear goto orders and make the selected unit active again.
    func clearSelectedUnitOrders() {
        guard canClearSelectedUnitOrders,
              let unitId = selectedUnitId,
              let game = cachedGame else {
            errorMessage = "Keine Befehle zum Loeschen."
            return
        }
        updateMovementOrders(unitId, destination: nil, activate: true, in: game)
    }

    private func updateMovementOrders(_ unitId: String, destination: String?, activate: Bool, in game: Game) {
        europeTravelOrders.remove(unitId)
        movingUnitId = unitId
        movementAttempts[unitId] = game.turn.number
        Task {
            defer { if movingUnitId == unitId { movingUnitId = nil } }
            do {
                if game.units[unitId]?.destination != destination {
                    var attributes = ["unit": unitId]
                    if let destination { attributes["destination"] = destination }
                    try await sendCoreGameplayAction(ParsedMessage(
                        tag: "setDestination", attributes: attributes, children: []),
                        queueIfDisconnected: false)
                    guard cachedGame === game else { return }
                    if usesLocalServer {
                        game.setUnitDestination(unitId: unitId, destinationId: destination)
                        gameUpdateID += 1
                    }
                    guard game.units[unitId]?.destination == destination else {
                        throw UserFacingActionError(message: "Der Server hat die Zieländerung nicht bestätigt.")
                    }
                }
                if activate, game.units[unitId]?.state != .active {
                    try await sendCoreGameplayAction(ParsedMessage(
                        tag: "changeState",
                        attributes: ["unit": unitId, "state": "active"], children: []),
                        queueIfDisconnected: false)
                    guard cachedGame === game else { return }
                    if usesLocalServer {
                        game.changeUnitState(unitId: unitId, state: .active)
                        gameUpdateID += 1
                    }
                    guard game.units[unitId]?.state == .active else {
                        throw UserFacingActionError(message: "Der Server hat die Aktivierung nicht bestätigt.")
                    }
                }
                errorMessage = nil
                statusMessage = destination == nil ? "Befehle gelöscht." : "Marschziel gespeichert."
            } catch {
                guard cachedGame === game else { return }
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    func updateTradeRouteStop(_ unitId: String, index: Int, in game: Game) {
        errorMessage = nil
        movingUnitId = unitId
        Task {
            defer { if movingUnitId == unitId { movingUnitId = nil } }
            do {
                try await sendCoreGameplayAction(ParsedMessage(
                    tag: "setCurrentStop", attributes: ["unit": unitId, "index": String(index)], children: []
                ), queueIfDisconnected: false)
                guard cachedGame === game else { return }
                if usesLocalServer {
                    game.setUnitCurrentStop(unitId: unitId, index: index)
                    gameUpdateID += 1
                }
                guard game.units[unitId]?.currentStop == index else {
                    throw UserFacingActionError(message: "Der Server hat den Haltepunkt nicht bestätigt.")
                }
                statusMessage = "Haltepunkt geändert."
            } catch {
                guard cachedGame === game else { return }
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    func updateTradeRouteAssignment(_ unitId: String, routeId: String?, in game: Game) {
        errorMessage = nil
        movingUnitId = unitId
        Task {
            defer { if movingUnitId == unitId { movingUnitId = nil } }
            do {
                var attributes = ["unit": unitId]
                if let routeId { attributes["tradeRoute"] = routeId }
                try await sendCoreGameplayAction(ParsedMessage(
                    tag: "assignTradeRoute", attributes: attributes, children: []
                ), queueIfDisconnected: false)
                guard cachedGame === game else { return }
                if usesLocalServer {
                    game.setUnitTradeRoute(unitId: unitId, tradeRouteId: routeId)
                    gameUpdateID += 1
                }
                guard let unit = game.units[unitId], unit.tradeRoute == routeId else {
                    throw UserFacingActionError(message: "Der Server hat die Routenzuweisung nicht bestätigt.")
                }
                statusMessage = routeId == nil ? "Routenzuweisung entfernt." : "Handelsroute zugewiesen."
            } catch {
                guard cachedGame === game else { return }
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    /// All local units, including colony workers used in reports.
    var selectableLocalUnits: [FreeColGame.Unit] {
        guard let game = cachedGame,
              let localPlayerId = resolveLocalPlayerId() else { return [] }
        return game.units.values
            .filter { $0.owner == localPlayerId }
            .sorted { $0.id < $1.id }
    }

    /// Units cycled on the map; workers remain selectable in their colony.
    var cyclingLocalUnits: [FreeColGame.Unit] {
        guard let game = cachedGame else { return [] }
        let colonyLocations = Set(game.colonies.values.flatMap {
            [$0.id] + $0.buildings.map(\.id) + $0.workTiles.map(\.id)
        })
        return selectableLocalUnits.filter { unit in
            guard let location = unit.location else { return true }
            return !colonyLocations.contains(location)
        }
    }

    /// Units the player has not given an order to yet (Java `EndTurnDialog`).
    var unitsAwaitingOrders: [FreeColGame.Unit] {
        guard cachedGame != nil else { return [] }
        return cyclingLocalUnits.filter {
            $0.movesLeft > 0 && $0.state == .active && $0.destination == nil
        }
    }

    /// Cycle to the next (`forward`) or previous local unit.
    func selectAdjacentUnit(forward: Bool, onlyAwaitingOrders: Bool = false) {
        let units = onlyAwaitingOrders ? unitsAwaitingOrders : cyclingLocalUnits
        guard !units.isEmpty, let game = cachedGame else { return }
        let target: FreeColGame.Unit
        if let currentId = selectedUnitId, let index = units.firstIndex(where: { $0.id == currentId }) {
            let offset = forward ? 1 : units.count - 1
            target = units[(index + offset) % units.count]
        } else {
            target = units[0]
        }
        // Europe and other off-map locations remain selectable, but must not
        // be used as a map-centering target.
        let tileId = game.resolvedTileId(for: target)
        selectUnit(target.id, onTile: tileId)
    }

    func selectNextUnit() { selectAdjacentUnit(forward: true) }
    func selectPreviousUnit() { selectAdjacentUnit(forward: false) }

    /// Only a ship on a direct high-seas exit can begin a Europe crossing.
    var canSendSelectedUnitToEurope: Bool {
        guard phase == .inGame,
              isLocalPlayersTurn,
              let game = cachedGame,
              let unitId = selectedUnitId,
              let unit = game.units[unitId],
              let localPlayerId = resolveLocalPlayerId(),
              unit.owner == localPlayerId,
              isNavalUnit(unit),
              let tileId = resolveUnitTileId(unit, in: game),
              game.tiles[tileId]?.moveToEurope == true,
              localPlayer?.europe?.id != nil else {
            return false
        }
        return true
    }

    /// Send the selected ship to Europe using the server `moveTo` routing.
    func sendSelectedUnitToEurope() {
        guard canSendSelectedUnitToEurope,
              let unitId = selectedUnitId,
              let game = cachedGame,
              let europeId = localPlayer?.europe?.id else {
            errorMessage = "Die Reise nach Europa ist nur mit einem eigenen Schiff auf einem Hochsee-Ausfahrtsfeld am Kartenrand im eigenen Zug möglich."
            return
        }
        errorMessage = nil
        Task {
            do {
                let msg = Self.moveToMessage(unitId: unitId, destinationId: europeId)
                if server != nil {
                    game.setUnitDestination(unitId: unitId, destinationId: europeId)
                    gameUpdateID += 1
                }
                try await sendCoreGameplayAction(msg)
                statusMessage = "Segelt nach Europa."
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    /// Whether the selected ship can reach a high-seas exit and travel to Europe.
    var canGoSelectedShipToEurope: Bool {
        guard phase == .inGame,
              isLocalPlayersTurn,
              movingUnitId == nil,
              !isSavingGame,
              !isEndingTurn,
              let game = cachedGame,
              let unitId = selectedUnitId,
              let unit = game.units[unitId],
              let localPlayerId = resolveLocalPlayerId(),
              unit.owner == localPlayerId,
              isNavalUnit(unit),
              canIssueMovementOrders(for: unit, in: game),
              let source = resolveUnitTileId(unit, in: game),
              game.tiles[source] != nil,
              localPlayer?.europe?.id != nil else {
            return false
        }
        return nearestEuropeExit(from: source, for: unit, in: game) != nil
    }

    /// Route the selected ship to its nearest reachable high-seas exit, then send it to Europe.
    func goSelectedShipToEurope() {
        guard canGoSelectedShipToEurope,
              let unitId = selectedUnitId,
              let unit = selectedUnit,
              let game = cachedGame,
              let source = resolveUnitTileId(unit, in: game),
              let exit = nearestEuropeExit(from: source, for: unit, in: game) else {
            errorMessage = "Kein befahrbarer Weg zu einem Hochsee-Ausfahrtsfeld nach Europa gefunden."
            return
        }
        errorMessage = nil
        europeTravelOrders.insert(unitId)
        startMovingUnit(unitId, to: exit)
    }

    /// Breadth-first search to the nearest traversable tile that leads to Europe.
    private func nearestEuropeExit(from source: String, for unit: FreeColGame.Unit, in game: Game) -> String? {
        guard game.tiles[source] != nil else { return nil }
        var queue = [source]
        var head = 0
        var visited: Set<String> = [source]

        while head < queue.count {
            let current = queue[head]
            head += 1
            if game.tiles[current]?.moveToEurope == true { return current }

            for neighbor in game.neighborTileIds(of: current) where !visited.contains(neighbor) {
                guard canNavalUnitTraverse(unit, to: neighbor, in: game) else { continue }
                visited.insert(neighbor)
                queue.append(neighbor)
            }
        }
        return nil
    }

    private func canNavalUnitTraverse(_ unit: FreeColGame.Unit, to tileId: String, in game: Game) -> Bool {
        guard let tile = game.tiles[tileId], tile.type != nil,
              let owner = unit.owner,
              !hasHostileUnit(onTile: tileId, in: game, friendlyOwner: owner),
              !game.colonies.values.contains(where: { $0.tileId == tileId && $0.owner != owner }) else {
            return false
        }
        return isWaterTile(tile, in: game)
            || game.colonies.values.contains { $0.tileId == tileId && $0.owner == owner }
    }

    func canSendShipToAmerica(_ unitId: String) -> Bool {
        guard phase == .inGame, isLocalPlayersTurn, !usesLocalServer,
              !isSavingGame, !isEndingTurn, movingUnitId == nil,
              let game = cachedGame, game.map != nil,
              let unit = game.units[unitId], unit.owner == localPlayerId,
              isNavalUnit(unit),
              let europeId = localPlayer?.europe?.id,
              unit.location == europeId else { return false }
        return true
    }

    func sendShipToAmerica(_ unitId: String) {
        guard canSendShipToAmerica(unitId),
              let game = cachedGame, let mapId = game.map?.id,
              let europeId = localPlayer?.europe?.id else {
            errorMessage = "Die Rückreise ist nur mit einem eigenen Schiff im Europahafen im eigenen Zug auf einem Java-Server möglich."
            return
        }
        errorMessage = nil
        movingUnitId = unitId
        Task {
            defer { if movingUnitId == unitId { movingUnitId = nil } }
            do {
                try await sendCoreGameplayAction(
                    Self.moveToMessage(unitId: unitId, destinationId: mapId),
                    queueIfDisconnected: false
                )
                guard cachedGame === game else { return }
                guard let ship = game.units[unitId], ship.location != europeId,
                      ship.destination == mapId, unitTravelStatus(ship) != nil else {
                    throw UserFacingActionError(message: "Der Server hat die Abreise zur Neuen Welt nicht bestätigt.")
                }
                reconcileSelectionWithGame()
                statusMessage = "Schiff ist zur Neuen Welt aufgebrochen."
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    /// Build a `moveTo` message (server-side high-seas routing).
    nonisolated static func moveToMessage(unitId: String, destinationId: String) -> ParsedMessage {
        ParsedMessage(tag: "moveTo",
                      attributes: ["unit": unitId, "destination": destinationId],
                      children: [])
    }

    /// Pioneer improvements the selected unit could build.
    var selectedUnitImprovementCandidates: [(id: String, label: String)] {
        guard let game = cachedGame, let specification = game.specification,
              let unit = selectedUnit, canUnitWorkInColony(unit),
              let location = unit.location, let tile = game.tiles[location] else { return [] }
        return specification.improvementTypes.values
            .filter { improvement in
                !improvement.isNatural
                    && (improvement.expendedAmount == 0 || unit.roleCount >= improvement.expendedAmount)
                    && !tile.improvements.contains {
                        $0.type == improvement.id && $0.turns == 0
                    }
                    && (improvement.requiredRole.map { $0 == unit.role }
                    ?? (unit.role == "model.role.pioneer"
                        || specification.effectiveAbility(unitTypeId: unit.unitType ?? "",
                            abilityId: "model.ability.improveTerrain") == true))
            }
            .map { (id: $0.id, label: GameLabels.name($0.id)) }
            .sorted { $0.label < $1.label }
    }

    /// Pioneer improvements available in the colony worker controls.
    var selectedColonyWorkImprovementCandidates: [(id: String, label: String)] {
        selectedUnitImprovementCandidates
    }

    /// Raw tools consumed when the selected improvement completes.
    func selectedUnitImprovementToolCost(for improvementTypeId: String) -> Int {
        guard let specification = cachedGame?.specification,
              let improvement = specification.improvementTypes[improvementTypeId] else { return 0 }
        let roleId = improvement.requiredRole
            ?? (selectedUnit?.role == "model.role.pioneer" ? "model.role.pioneer" : nil)
        guard let roleId else { return 0 }
        let toolsPerRoleCount = specification.roleTypes[roleId]?
            .requiredGoods["model.goods.tools"] ?? 20
        return improvement.expendedAmount * toolsPerRoleCount
    }

    var pioneerToolsPerRoleCount: Int {
        cachedGame?.specification?.roleTypes["model.role.pioneer"]?
            .requiredGoods["model.goods.tools"] ?? 20
    }

    var canChangeSelectedUnitWorkImprovement: Bool {
        guard phase == .inGame,
              isLocalPlayersTurn,
              let game = cachedGame,
              let unitId = selectedUnitId,
              let unit = game.units[unitId],
              let localPlayerId = resolveLocalPlayerId(),
              unit.owner == localPlayerId else {
            return false
        }
        // FreeCol accepts improvement orders even at zero moves; equipping in a
        // colony can consume the unit's moves before it receives its work order.
        return !selectedUnitImprovementCandidates.isEmpty
    }

    /// Order the selected pioneer to build a tile improvement on its tile.
    func changeSelectedUnitWorkImprovement(_ improvementTypeId: String) {
        let trimmed = improvementTypeId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Bitte einen Verbesserungstyp auswählen."
            return
        }
        guard canChangeSelectedUnitWorkImprovement,
              selectedUnitImprovementCandidates.contains(where: { $0.id == trimmed }),
              let unitId = selectedUnitId,
              let game = cachedGame else {
            errorMessage = "Verbesserung nicht möglich."
            return
        }
        errorMessage = nil
        Task {
            do {
                let msg = ParsedMessage(
                    tag: "changeWorkImprovementType",
                    attributes: ["unit": unitId, "improvementType": trimmed],
                    children: []
                )
                if server != nil {
                    game.changeUnitWorkImprovementType(unitId: unitId, improvementTypeId: trimmed)
                    gameUpdateID += 1
                }
                try await sendCoreGameplayAction(msg, queueIfDisconnected: false)
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    // MARK: Phase 59 - Europe / cargo

    /// Goods carried by the selected carrier, with display names.
    var selectedUnitCargoGoods: [(id: String, label: String, amount: Int)] {
        guard let unit = selectedUnit else { return [] }
        return unit.goods
            .filter { $0.value > 0 }
            .map { (id: $0.key, label: goodsDisplayName($0.key), amount: $0.value) }
            .sorted { $0.label < $1.label }
    }

    /// Dump (or unload) cargo from the selected carrier overboard.
    func dumpSelectedUnitCargo(typeId: String, amount: Int) {
        let trimmed = typeId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, amount > 0 else {
            errorMessage = "Ungültige Fracht."
            return
        }
        guard phase == .inGame,
              isLocalPlayersTurn,
              let game = cachedGame,
              let carrier = selectedUnit,
              let localPlayerId = resolveLocalPlayerId(),
              carrier.owner == localPlayerId,
              isCarrierUnit(carrier),
              (carrier.goods[trimmed] ?? 0) >= amount else {
            errorMessage = "Fracht kann nicht abgeworfen werden."
            return
        }
        errorMessage = nil
        Task {
            do {
                let msg = ParsedMessage(
                    tag: "unloadGoods",
                    attributes: ["type": trimmed,
                                 "amount": String(amount),
                                 "carrier": carrier.id],
                    children: []
                )
                if server != nil {
                    game.removeUnitGoods(unitId: carrier.id, typeId: trimmed, amount: amount)
                    gameUpdateID += 1
                }
                try await client?.send(message: msg)
                statusMessage = "Fracht abgeworfen."
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    func cashInSelectedTreasureTrain() {
        guard canCashInSelectedTreasureTrain,
              let unitId = selectedUnitId,
              let game = cachedGame else {
            errorMessage = "Schaetze koennen nicht eingeliefert werden."
            return
        }
        errorMessage = nil


        Task {
            do {
                let msg = ParsedMessage(
                    tag: "cashInTreasureTrain",
                    attributes: ["unit": unitId],
                    children: []
                )
                if server != nil {
                    game.cashInTreasureTrain(unitId: unitId)
                    gameUpdateID += 1
                }
                try await client?.send(message: msg)
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    func canChangeSelectedUnitState(to targetState: UnitState) -> Bool {
        guard phase == .inGame,
              isLocalPlayersTurn,
              let game = cachedGame,
              let unitId = selectedUnitId,
              let unit = game.units[unitId],
              let localPlayerId = resolveLocalPlayerId(),
              unit.owner == localPlayerId else {
            return false
        }

        if unit.state == targetState {
            return false
        }

        switch targetState {
        case .active:
            return true
        case .fortifying:
            return unit.state == .active && unit.movesLeft > 0
        case .skipped:
            return unit.state == .active && unit.movesLeft > 0
        case .sentry:
            return unit.state == .active && !isNavalUnit(unit)
        default:
            return false
        }
    }

    func setSelectedUnitState(_ targetState: UnitState) {
        guard canChangeSelectedUnitState(to: targetState),
              let unitId = selectedUnitId,
              let game = cachedGame else {
            errorMessage = "Statuswechsel nicht möglich."
            return
        }

        errorMessage = nil
        Task {
            do {
                let msg = ParsedMessage(
                    tag: "changeState",
                    attributes: ["unit": unitId, "state": targetState.rawValue],
                    children: []
                )
                if server != nil {
                    game.changeUnitState(unitId: unitId, state: targetState)
                    reconcileSelectionWithGame()
                    gameUpdateID += 1
                }
                try await client?.send(message: msg)
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    func changeSelectedColonyWorkerWorkType(_ workTypeId: String) {
        let trimmed = workTypeId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Bitte eine Arbeitsart-ID eingeben."
            return
        }
        guard canManageSelectedColony,
              let unitId = selectedColonyWorkerUnitId,
              selectedColonyWorkTypeCandidates.contains(where: { $0.id == trimmed }),
              let game = cachedGame else {
            errorMessage = "Diese Ware kann am ausgewählten Arbeitsplatz nicht produziert werden."
            return
        }
        errorMessage = nil


        Task {
            do {
                let msg = ParsedMessage(
                    tag: "changeWorkType",
                    attributes: ["unit": unitId, "workType": trimmed],
                    children: []
                )
                if server != nil {
                    game.changeUnitWorkType(unitId: unitId, workTypeId: trimmed)
                    gameUpdateID += 1
                }
                try await sendCoreGameplayAction(msg, queueIfDisconnected: false)
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    func changeSelectedColonyWorkerWorkImprovementType(_ improvementTypeId: String) {
        let trimmed = improvementTypeId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Bitte eine Verbesserungstyp-ID eingeben."
            return
        }
        guard canManageSelectedColony,
              let unitId = selectedColonyWorkerUnitId,
              let game = cachedGame else {
            errorMessage = "Verbesserungstyp kann nicht geändert werden."
            return
        }
        errorMessage = nil


        Task {
            do {
                let msg = ParsedMessage(
                    tag: "changeWorkImprovementType",
                    attributes: ["unit": unitId, "improvementType": trimmed],
                    children: []
                )
                if server != nil {
                    game.changeUnitWorkImprovementType(unitId: unitId, improvementTypeId: trimmed)
                    gameUpdateID += 1
                }
                try await client?.send(message: msg)
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    func clearSelectedColonyWorkerSpeciality() {
        guard canManageSelectedColony,
              let unitId = selectedColonyWorkerUnitId else {
            errorMessage = "Spezialisierung kann nicht entfernt werden."
            return
        }
        errorMessage = nil


        Task {
            do {
                let msg = ParsedMessage(
                    tag: "clearSpeciality",
                    attributes: ["unit": unitId],
                    children: []
                )
                try await client?.send(message: msg)
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    func assignTeacherToSelectedColonyWorker(_ teacherId: String) {
        let trimmed = teacherId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Bitte eine Lehrer-ID eingeben."
            return
        }
        guard canManageSelectedColony,
              let studentId = selectedColonyWorkerUnitId,
              let game = cachedGame,
              let teacher = game.units[trimmed],
              let localPlayerId = resolveLocalPlayerId(),
              teacher.owner == localPlayerId,
              selectedColonyTeacherCandidates.contains(where: { $0.id == trimmed }),
              studentId != trimmed else {
            errorMessage = "Lehrer kann nicht zugewiesen werden."
            return
        }
        guard let student = game.units[studentId],
              let colony = selectedColony,
              colony.buildings.contains(where: { $0.id == student.location })
                || colony.workTiles.contains(where: { $0.id == student.location }) else {
            errorMessage = "Der Schüler muss zuerst in einem Gebäude oder auf einem Feld arbeiten."
            return
        }
        errorMessage = nil


        Task {
            do {
                let msg = ParsedMessage(
                    tag: "assignTeacher",
                    attributes: ["student": studentId, "teacher": trimmed],
                    children: []
                )
                if server != nil {
                    game.assignTeacher(studentId: studentId, teacherId: trimmed)
                    gameUpdateID += 1
                }
                try await client?.send(message: msg)
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    func clearTeacherForSelectedColonyWorker() {
        guard canManageSelectedColony,
              let studentId = selectedColonyWorkerUnitId,
              let game = cachedGame else {
            errorMessage = "Lehrer kann nicht entfernt werden."
            return
        }
        errorMessage = nil


        Task {
            do {
                let msg = ParsedMessage(
                    tag: "assignTeacher",
                    attributes: ["student": studentId],
                    children: []
                )
                if server != nil {
                    game.assignTeacher(studentId: studentId, teacherId: nil)
                    gameUpdateID += 1
                }
                try await client?.send(message: msg)
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    func setSelectedColonyBuildQueue(_ buildableIds: [String]) {
        let sanitized = buildableIds
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard canManageSelectedColony,
              let colony = selectedColony else {
            errorMessage = "Build Queue kann nicht gesetzt werden."
            return
        }
        errorMessage = nil


        Task {
            do {
                var attrs: [String: String] = [
                    "colony": colony.id,
                    "xLength": String(sanitized.count),
                ]
                for (idx, id) in sanitized.enumerated() {
                    attrs["x\(idx)"] = id
                }
                let msg = ParsedMessage(tag: "setBuildQueue", attributes: attrs, children: [])
                try await client?.send(message: msg)
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    func putSelectedColonyWorkerOutside() {
        guard canPutSelectedColonyWorkerOutside,
              let unitId = selectedColonyWorkerUnitId,
              let game = cachedGame else {
            errorMessage = "Einheit kann nicht nach draussen gesetzt werden."
            return
        }
        errorMessage = nil


        Task {
            do {
                let msg = ParsedMessage(
                    tag: "putOutsideColony",
                    attributes: ["unit": unitId],
                    children: []
                )
                if server != nil {
                    game.putOutsideColony(unitId: unitId)
                    gameUpdateID += 1
                }
                try await client?.send(message: msg)
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    /// Assign the selected colony worker to a work location. If another worker
    /// already occupies the target, the two are swapped. Uses `rearrangeColony`
    /// so the server can resolve capacity and swaps atomically.
    func assignSelectedColonyWorker(to workLocationId: String, workTypeId: String? = nil) {
        let trimmed = workLocationId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Bitte einen Arbeitsplatz auswählen."
            return
        }
        guard canManageSelectedColony,
              let colony = selectedColony,
              let game = cachedGame,
              let unitId = selectedColonyWorkerUnitId,
              let unit = game.units[unitId] else {
            errorMessage = "Arbeit kann nicht zugewiesen werden."
            return
        }
        if let reason = colonyWorkLocationUnavailableReason(trimmed) {
            errorMessage = reason
            return
        }
        guard selectedColonyWorkLocationCandidates.contains(where: { $0.id == trimmed }),
              unit.owner == colony.owner, canUnitWorkInColony(unit) else {
            errorMessage = "Dieser Arbeitsplatz ist für die Einheit nicht verfügbar."
            return
        }
        let selectedWorkType = workTypeId?.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetOutputs = colonyWorkOutputs(at: trimmed, in: colony).filter { $0.value > 0 }
        if let selectedWorkType,
           (selectedWorkType.isEmpty || targetOutputs[selectedWorkType] == nil) {
            errorMessage = "Diese Ware kann an diesem Arbeitsplatz nicht produziert werden."
            return
        }
        if unit.location == trimmed {
            guard let selectedWorkType else {
                errorMessage = nil
                return
            }
            guard unit.workType != selectedWorkType else {
                errorMessage = nil
                return
            }
            changeSelectedColonyWorkerWorkType(selectedWorkType)
            return
        }
        errorMessage = nil
        // Build the arrangement list: the target's occupant (if any) swaps to
        // the unit's previous location, then the unit moves to the target.
        var arrangements: [(unit: String, loc: String, work: String?, role: String?, count: Int)] = []
        let previousLocation = unit.location ?? colony.tileId ?? colony.id
        func workType(for worker: FreeColGame.Unit, at location: String) -> String? {
            let outputs = colonyWorkOutputs(at: location, in: colony).filter { $0.value > 0 }
            if worker.id == unitId, location == trimmed, let selectedWorkType {
                return selectedWorkType
            }
            if let current = worker.workType, outputs[current] != nil { return current }
            return outputs.sorted {
                $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value
            }.first?.key
        }
        if colony.workTiles.contains(where: { $0.id == trimmed }),
           let occupant = selectedColonyUnits.first(where: {
            $0.id != unitId && $0.location == trimmed
        }) {
            arrangements.append((
                unit: occupant.id,
                loc: previousLocation,
                work: workType(for: occupant, at: previousLocation),
                role: previousLocation == colony.tileId ? occupant.role : "model.role.default",
                count: previousLocation == colony.tileId ? occupant.roleCount : 0
            ))
        }
        arrangements.append((
            unit: unitId,
            loc: trimmed,
            work: workType(for: unit, at: trimmed),
            role: "model.role.default",
            count: 0
        ))

        Task {
            do {
                if let location = colony.workTiles.first(where: { $0.id == trimmed }),
                   let tileId = location.tileId, let tile = game.tiles[tileId],
                   tile.owner == nil, !usesLocalServer {
                    try await sendCoreGameplayAction(ParsedMessage(tag: "claimLand", attributes: [
                        "claimant": colony.id, "tile": tileId, "price": "0",
                    ], children: []), queueIfDisconnected: false)
                }
                if server != nil {
                    for arrangement in arrangements {
                        game.setUnitWorkLocation(unitId: arrangement.unit,
                                                 workLocationId: arrangement.loc)
                        if let workType = arrangement.work {
                            game.changeUnitWorkType(unitId: arrangement.unit, workTypeId: workType)
                        }
                    }
                    gameUpdateID += 1
                }

                if arrangements.count == 1, let selectedWorkType {
                    // FreeCol 1.2's RearrangeColonyMessage reader fails to
                    // consume its closing tag inside a <question>. Use the
                    // regular work and changeWorkType requests for a simple
                    // move with an explicit production choice.
                    try await sendCoreGameplayAction(ParsedMessage(
                        tag: "work",
                        attributes: ["unit": unitId, "workLocation": trimmed],
                        children: []
                    ), queueIfDisconnected: false)
                    try await sendCoreGameplayAction(ParsedMessage(
                        tag: "changeWorkType",
                        attributes: ["unit": unitId, "workType": selectedWorkType],
                        children: []
                    ), queueIfDisconnected: false)
                } else {
                    let msg = arrangements.count > 1
                        ? Self.rearrangeColonyMessage(colonyId: colony.id, arrangements: arrangements)
                        : ParsedMessage(tag: "work", attributes: [
                            "unit": unitId, "workLocation": trimmed,
                        ], children: [])
                    try await sendCoreGameplayAction(msg, queueIfDisconnected: false)
                }
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    /// Build a `rearrangeColony` message from worker arrangements.
    nonisolated static func rearrangeColonyMessage(
        colonyId: String,
        arrangements: [(unit: String, loc: String, work: String?, role: String?, count: Int)]
    ) -> ParsedMessage {
        var attributes: [String: String] = [
            "colony": colonyId,
            "xLength": String(arrangements.count),
        ]
        for (index, arrangement) in arrangements.enumerated() {
            attributes["x\(index)unit"] = arrangement.unit
            attributes["x\(index)loc"] = arrangement.loc
            if let work = arrangement.work, !work.isEmpty {
                attributes["x\(index)work"] = work
            }
            attributes["x\(index)role"] = arrangement.role ?? "model.role.default"
            attributes["x\(index)count"] = String(arrangement.count)
        }
        return ParsedMessage(tag: "rearrangeColony", attributes: attributes, children: [])
    }

    func renameSelectedColony(to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Bitte einen Kolonienamen eingeben."
            return
        }
        guard canManageSelectedColony,
              let colony = selectedColony,
              let game = cachedGame else {
            errorMessage = "Kolonie kann nicht umbenannt werden."
            return
        }
        if (colony.name ?? "").caseInsensitiveCompare(trimmed) == .orderedSame {
            statusMessage = "Kolonie hat bereits diesen Namen."
            return
        }
        if game.colonies.values.contains(where: { $0.id != colony.id && ($0.name ?? "").caseInsensitiveCompare(trimmed) == .orderedSame }) {
            errorMessage = "Der Koloniename ist bereits vergeben."
            return
        }
        errorMessage = nil


        Task {
            do {
                let msg = ParsedMessage(
                    tag: "rename",
                    attributes: ["name": trimmed, "nameable": colony.id],
                    children: []
                )
                if server != nil {
                    game.renameColony(colonyId: colony.id, newName: trimmed)
                    gameUpdateID += 1
                }
                try await sendCoreGameplayAction(msg, queueIfDisconnected: false)
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    func payForSelectedColonyBuilding() {
        guard canManageSelectedColony,
              let colony = selectedColony else {
            errorMessage = "Bau kann nicht bezahlt werden."
            return
        }
        errorMessage = nil


        Task {
            do {
                let msg = ParsedMessage(
                    tag: "payForBuilding",
                    attributes: ["colony": colony.id],
                    children: []
                )
                try await client?.send(message: msg)
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    func abandonSelectedColony() {
        guard canAbandonSelectedColony,
              let colony = selectedColony,
              let game = cachedGame else {
            errorMessage = "Kolonie kann nicht aufgegeben werden."
            return
        }
        errorMessage = nil


        Task {
            do {
                let msg = ParsedMessage(
                    tag: "abandonColony",
                    attributes: ["colony": colony.id],
                    children: []
                )
                if server != nil {
                    game.abandonColony(colonyId: colony.id)
                    reconcileSelectionWithGame()
                    gameUpdateID += 1
                }
                try await client?.send(message: msg)
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    /// Set the custom-house export settings for one goods type.
    func setSelectedColonyGoodsLevel(_ data: ColonyExportData) {
        guard canManageSelectedColony,
              let colony = selectedColony else {
            errorMessage = "Warenbestände können nicht festgelegt werden."
            return
        }
        guard !data.goodsType.isEmpty else {
            errorMessage = "Warenart erforderlich."
            return
        }
        errorMessage = nil

        Task {
            do {
                let msg = Self.exportDataMessage(colonyId: colony.id, data: data)
                if server != nil {
                    selectedColonyExportDataApplyLocal(data)
                }
                try await client?.send(message: msg)
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    /// Build a `setGoodsLevels` message carrying a single `<exportData>` child.
    nonisolated static func exportDataMessage(colonyId: String,
                                              data: ColonyExportData) -> ParsedMessage {
        let exportChild = ParsedMessage(
            tag: "exportData",
            attributes: [
                "id": data.goodsType,
                "exported": data.exported ? "true" : "false",
                "highLevel": String(data.highLevel),
                "lowLevel": String(data.lowLevel),
                "importLevel": String(data.importLevel),
                "exportLevel": String(data.exportLevel),
            ],
            children: []
        )
        return ParsedMessage(tag: "setGoodsLevels",
                             attributes: ["colony": colonyId],
                             children: [exportChild])
    }

    private func selectedColonyExportDataApplyLocal(_ data: ColonyExportData) {
        guard var colony = selectedColony else { return }
        colony.exportData[data.goodsType] = data
        cachedGame?.replaceColony(colony)
        gameUpdateID += 1
    }

    func trainUnitInEurope(unitType: String) {
        let trimmed = unitType.trimmingCharacters(in: .whitespacesAndNewlines)
        guard phase == .inGame else { return }
        guard !trimmed.isEmpty else {
            errorMessage = "Bitte einen Einheitentyp fuer Europa angeben."
            return
        }
        guard localPlayer != nil else {
            errorMessage = "Lokaler Spieler konnte nicht bestimmt werden."
            return
        }
        errorMessage = nil

        // Client-side purchases tracking (like the Java client's purchases summary)
        let price = europeUnitPrice(for: trimmed)
        purchasesTrained += 1
        purchasesTotal += price

        Task {
            do {
                let msg = ParsedMessage(
                    tag: "trainUnitInEurope",
                    attributes: ["unitType": trimmed],
                    children: []
                )
                try await client?.send(message: msg)
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    /// Unit types Europe sells: every type with a price in the specification
    /// (the server's `<unitPrice>` entries override it), sorted by price.
    var purchasableEuropeUnits: [(unitType: String, label: String, price: Int)] {
        guard let europe = localPlayer?.europe else { return [] }
        var prices = europe.unitPrices
        for (id, info) in cachedGame?.specification?.unitTypes ?? [:] {
            if prices[id] == nil, let price = info.price, price > 0 {
                prices[id] = price
            }
        }
        return prices
            .map { (unitType: $0.key,
                    label: unitDisplayName($0.key),
                    price: $0.value) }
            .sorted { $0.price == $1.price ? $0.unitType < $1.unitType : $0.price < $1.price }
    }

    /// Europe price for a unit type: server override, then the specification price.
    func europeUnitPrice(for unitType: String) -> Int {
        if let price = localPlayer?.europe?.unitPrices[unitType] { return price }
        return cachedGame?.specification?.unitTypes[unitType]?.price
            ?? localPlayer?.europe?.recruitPrice ?? 0
    }

    func unitDisplayName(_ typeId: String) -> String {
        GameLabels.name(typeId, fallback: cachedGame?.specification?.unitTypes[typeId]?.displayName)
    }

    func unitDisplayLabel(_ unit: FreeColGame.Unit) -> String {
        let typeName = unit.name ?? unit.unitType.map(unitDisplayName) ?? "Einheit"
        guard let role = unit.role, role != "model.role.default" else { return typeName }
        return "\(GameLabels.name(role)) (\(typeName))"
    }

    func playerColor(for playerId: String) -> Color {
        switch cachedGame?.players[playerId]?.nationId {
        case "model.nation.french": return .blue
        case "model.nation.english": return .red
        case "model.nation.dutch": return .orange
        case "model.nation.spanish": return .yellow
        case "model.nation.portuguese": return .green
        case "model.nation.danish": return .brown
        case "model.nation.swedish": return .cyan
        case "model.nation.russian": return .purple
        default:
            let colors: [Color] = [.blue, .red, .green, .orange, .purple, .brown, .cyan, .mint]
            let value = playerId.utf8.reduce(UInt64(0)) { ($0 &* 31) &+ UInt64($1) }
            return colors[Int(value % UInt64(colors.count))]
        }
    }

    var europeRecruitmentCost: Int? {
        guard let player = localPlayer, let europe = player.europe,
              let required = player.immigrationRequired, required > 0 else { return nil }
        if player.immigration >= required { return 0 }
        return max(europe.recruitLowerCap,
                   europe.recruitPrice * max(0, required - player.immigration) / required)
    }

    var canRecruitInEurope: Bool {
        guard isLocalPlayersTurn, let cost = europeRecruitmentCost, let player = localPlayer else { return false }
        return player.gold >= cost && player.europe?.recruitable.isEmpty == false
    }

    var canChooseEuropeRecruit: Bool {
        europeRecruitmentCost != 0 || localPlayer?.abilities["model.ability.selectRecruit"] == true
    }

    /// Recruit an emigrant from a Europe slot (1-based; 0 picks at random).
    func recruitUnitInEurope(slot: Int) {
        guard phase == .inGame,
              isLocalPlayersTurn,
              canRecruitInEurope else {
            errorMessage = "Rekrutierung nicht möglich."
            return
        }
        guard slot >= 0, slot <= min(3, localPlayer?.europe?.recruitable.count ?? 0),
              slot == 0 || canChooseEuropeRecruit else {
            errorMessage = "Ungültiger Slot."
            return
        }
        errorMessage = nil
        let price = europeRecruitmentCost ?? 0
        purchasesRecruits += 1
        purchasesTotal += price
        Task {
            do {
                let msg = ParsedMessage(
                    tag: "emigrateUnit",
                    attributes: ["slot": String(slot)],
                    children: []
                )
                try await client?.send(message: msg)
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    /// Maximum amount of one goods type that can be loaded from the selected colony.
    /// A goods stack uses one cargo slot per 100 units; an existing partial stack
    /// can be filled before another slot is needed.
    func maximumGoodsLoadAmountForSelectedColony(typeId: String) -> Int {
        guard !typeId.isEmpty,
              let colony = selectedColony,
              let carrierId = selectedColonyCarrierId,
              let carrier = cachedGame?.units[carrierId],
              let game = cachedGame,
              let specification = game.specification,
              let carrierTypeId = carrier.unitType,
              specification.hasAbility("model.ability.carryGoods", unitType: carrierTypeId),
              let cargoCapacity = specification.unitTypes[carrierTypeId]?.cargoSpace else {
            return 0
        }

        let availableGoods = max(0, colony.goods[typeId] ?? 0)
        guard availableGoods > 0 else { return 0 }
        let carriedUnitSpace = game.units.values
            .filter { $0.location == carrierId }
            .reduce(0) { total, cargoUnit in
                total + (cargoUnit.unitType.flatMap {
                    specification.unitTypes[$0]?.spaceTakenOnCarrier
                } ?? 1)
            }
        let loadableAmount = Self.loadableGoodsAmount(
            cargoCapacity: cargoCapacity,
            goodsAmounts: Array(carrier.goods.values),
            carriedUnitSpace: carriedUnitSpace,
            selectedGoodsAmount: carrier.goods[typeId] ?? 0
        )
        return min(availableGoods, loadableAmount)
    }

    /// All goods of the selected type currently carried by the selected transporter.
    func maximumGoodsUnloadAmountFromSelectedCarrier(typeId: String) -> Int {
        guard !typeId.isEmpty,
              let carrierId = selectedColonyCarrierId,
              let carrier = cachedGame?.units[carrierId] else {
            return 0
        }
        return max(0, carrier.goods[typeId] ?? 0)
    }

    func loadGoodsForSelectedColony(typeId: String, amount: Int) {
        let trimmedType = typeId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedType.isEmpty else {
            errorMessage = "Bitte eine Warenart angeben."
            return
        }
        guard amount > 0 else {
            errorMessage = "Menge muss groesser als 0 sein."
            return
        }
        guard canManageSelectedColony,
              let colony = selectedColony,
              let carrierId = selectedColonyCarrierId else {
            errorMessage = "Waren können nicht geladen werden."
            return
        }
        let colonyId = colony.id
        let colonyAmountBefore = colony.goods[trimmedType] ?? 0
        let carrierAmountBefore = cachedGame?.units[carrierId]?.goods[trimmedType] ?? 0
        let fallbackAmount = min(amount, maximumGoodsLoadAmountForSelectedColony(typeId: trimmedType))
        errorMessage = nil


        Task {
            do {
                let msg = ParsedMessage(
                    tag: "loadGoods",
                    attributes: [
                        "location": colony.id,
                        "type": trimmedType,
                        "amount": String(amount),
                        "carrier": carrierId,
                    ],
                    children: []
                )
                try await sendCoreGameplayAction(msg, queueIfDisconnected: false)
                reconcileGoodsTransfer(
                    colonyId: colonyId,
                    carrierId: carrierId,
                    typeId: trimmedType,
                    fallbackAmount: fallbackAmount,
                    loading: true,
                    colonyAmountBefore: colonyAmountBefore,
                    carrierAmountBefore: carrierAmountBefore
                )
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    func unloadGoodsFromSelectedCarrier(typeId: String, amount: Int) {
        let trimmedType = typeId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedType.isEmpty else {
            errorMessage = "Bitte eine Warenart angeben."
            return
        }
        guard amount > 0 else {
            errorMessage = "Menge muss groesser als 0 sein."
            return
        }
        guard canManageSelectedColony,
              let carrierId = selectedColonyCarrierId else {
            errorMessage = "Waren können nicht entladen werden."
            return
        }
        guard let colony = selectedColony else {
            errorMessage = "Waren können nicht entladen werden."
            return
        }
        let colonyId = colony.id
        let colonyAmountBefore = colony.goods[trimmedType] ?? 0
        let carrierAmountBefore = cachedGame?.units[carrierId]?.goods[trimmedType] ?? 0
        let fallbackAmount = min(amount, carrierAmountBefore)
        errorMessage = nil


        Task {
            do {
                let msg = ParsedMessage(
                    tag: "unloadGoods",
                    attributes: [
                        "type": trimmedType,
                        "amount": String(amount),
                        "carrier": carrierId,
                    ],
                    children: []
                )
                try await sendCoreGameplayAction(msg, queueIfDisconnected: false)
                reconcileGoodsTransfer(
                    colonyId: colonyId,
                    carrierId: carrierId,
                    typeId: trimmedType,
                    fallbackAmount: fallbackAmount,
                    loading: false,
                    colonyAmountBefore: colonyAmountBefore,
                    carrierAmountBefore: carrierAmountBefore
                )
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    /// Keep the local goods views responsive when a server reply omits one or
    /// both goods-container snapshots. Any side already changed by the server
    /// remains authoritative; the missing side is reconciled from that delta.
    private func reconcileGoodsTransfer(colonyId: String,
                                        carrierId: String,
                                        typeId: String,
                                        fallbackAmount: Int,
                                        loading: Bool,
                                        colonyAmountBefore: Int,
                                        carrierAmountBefore: Int) {
        guard let game = cachedGame,
              let colony = game.colonies[colonyId],
              let carrier = game.units[carrierId] else { return }

        let colonyAmountAfter = colony.goods[typeId] ?? 0
        let carrierAmountAfter = carrier.goods[typeId] ?? 0
        let colonyChanged = colonyAmountAfter != colonyAmountBefore
        let carrierChanged = carrierAmountAfter != carrierAmountBefore
        guard !colonyChanged || !carrierChanged else { return }

        let transferredAmount: Int
        if carrierChanged {
            transferredAmount = loading
                ? carrierAmountAfter - carrierAmountBefore
                : carrierAmountBefore - carrierAmountAfter
        } else if colonyChanged {
            transferredAmount = loading
                ? colonyAmountBefore - colonyAmountAfter
                : colonyAmountAfter - colonyAmountBefore
        } else {
            transferredAmount = fallbackAmount
        }
        guard transferredAmount > 0 else { return }

        if !carrierChanged {
            let updatedCarrierAmount = loading
                ? carrierAmountBefore + transferredAmount
                : carrierAmountBefore - transferredAmount
            game.setUnitGoods(unitId: carrierId, typeId: typeId, amount: updatedCarrierAmount)
        }
        if !colonyChanged {
            let updatedColonyAmount = loading
                ? colonyAmountBefore - transferredAmount
                : colonyAmountBefore + transferredAmount
            game.setColonyGoods(colonyId: colonyId, typeId: typeId, amount: updatedColonyAmount)
        }
        gameUpdateID += 1
    }

    func buyGoodsInEurope(goodsTypeId: String, amount: Int, carrierId: String) {
        do {
            let (europeId, typeId, carrier) = try marketTradeContext(goodsTypeId: goodsTypeId, amount: amount, carrierId: carrierId)
            guard amount <= europeMarketTradeLimits(goodsTypeId: typeId, carrierId: carrierId).buy else {
                throw MarketTradeError.message("Menge überschreitet Bezahlbarkeit, Frachtraum oder Preisstufe.")
            }
            errorMessage = nil
            let price = marketPrice(for: typeId, sell: false)
            purchasesTotal += amount * price

            Task {
                do {
                    let msg = ParsedMessage(
                        tag: "loadGoods",
                        attributes: [
                            "location": europeId,
                            "type": typeId,
                            "amount": String(amount),
                            "carrier": carrier.id,
                        ],
                        children: []
                    )
                    try await client?.send(message: msg)
                } catch {
                    errorMessage = ServerErrorMessage.description(for: error)
                }
            }
        } catch let MarketTradeError.message(text) {
            errorMessage = text
        } catch {
            errorMessage = ServerErrorMessage.description(for: error)
        }
    }

    func sellGoodsInEurope(goodsTypeId: String, amount: Int, carrierId: String) {
        do {
            let (_, typeId, carrier) = try marketTradeContext(goodsTypeId: goodsTypeId, amount: amount, carrierId: carrierId)
            guard amount <= europeMarketTradeLimits(goodsTypeId: typeId, carrierId: carrierId).sell else {
                throw MarketTradeError.message("Menge überschreitet den Warenbestand im Carrier.")
            }
            errorMessage = nil
            let price = marketPrice(for: typeId, sell: true)
            salesTotal += amount * price

            Task {
                do {
                    let msg = ParsedMessage(
                        tag: "unloadGoods",
                        attributes: [
                            "type": typeId,
                            "amount": String(amount),
                            "carrier": carrier.id,
                        ],
                        children: []
                    )
                    try await client?.send(message: msg)
                } catch {
                    errorMessage = ServerErrorMessage.description(for: error)
                }
            }
        } catch let MarketTradeError.message(text) {
            errorMessage = text
        } catch {
            errorMessage = ServerErrorMessage.description(for: error)
        }
    }

    /// Maximum affordable and loadable buy quantity plus sale cargo for a Europe trade.
    func europeMarketTradeLimits(goodsTypeId: String?, carrierId: String?) -> (buy: Int, sell: Int) {
        guard let goodsTypeId, !goodsTypeId.isEmpty,
              let marketData = localPlayer?.market?.entry(for: goodsTypeId) else {
            return (buy: 0, sell: 0)
        }
        let carriedAmount = carrierId
            .flatMap { cachedGame?.units[$0]?.goods[goodsTypeId] } ?? 0
        guard let game = cachedGame,
              let specification = game.specification,
              let carrierId,
              let carrier = game.units[carrierId],
              let carrierTypeId = carrier.unitType,
              specification.hasAbility("model.ability.carryGoods", unitType: carrierTypeId),
              let cargoCapacity = specification.unitTypes[carrierTypeId]?.cargoSpace else {
            return Self.marketTradeLimits(gold: localPlayer?.gold ?? 0,
                                          buyPrice: marketPrices(for: goodsTypeId).costToBuy,
                                          loadableAmount: 0,
                                          carriedAmount: carriedAmount,
                                          arrears: marketData.arrears)
        }
        let carriedUnitSpace = game.units.values
            .filter { $0.location == carrierId }
            .reduce(0) { total, cargoUnit in
                let spaceTaken = cargoUnit.unitType.flatMap {
                    specification.unitTypes[$0]?.spaceTakenOnCarrier
                } ?? 1
                return total + spaceTaken
            }
        let loadableAmount = Self.loadableGoodsAmount(
            cargoCapacity: cargoCapacity,
            goodsAmounts: Array(carrier.goods.values),
            carriedUnitSpace: carriedUnitSpace,
            selectedGoodsAmount: carriedAmount
        )
        return Self.marketTradeLimits(gold: localPlayer?.gold ?? 0,
                                      buyPrice: marketPrices(for: goodsTypeId).costToBuy,
                                      loadableAmount: loadableAmount,
                                      carriedAmount: carriedAmount,
                                      arrears: marketData.arrears)
    }

    nonisolated static func marketTradeLimits(gold: Int,
                                             buyPrice: Int,
                                             loadableAmount: Int,
                                             carriedAmount: Int,
                                             arrears: Int = 0) -> (buy: Int, sell: Int) {
        guard arrears <= 0 else { return (buy: 0, sell: 0) }
        let affordableAmount = gold > 0 && buyPrice > 0 ? gold / buyPrice : 0
        return (buy: min(affordableAmount,
                         max(0, loadableAmount),
                         MarketPricing.goodsPerCargoChunk),
                sell: min(max(0, carriedAmount), MarketPricing.goodsPerCargoChunk))
    }

    func europeMarketTradeQuote(goodsTypeId: String?, amount: Int) -> (buyTotal: Int, sellAfterTax: Int)? {
        guard let goodsTypeId, !goodsTypeId.isEmpty, amount > 0 else { return nil }
        let prices = marketPrices(for: goodsTypeId)
        return Self.marketTransactionQuote(amount: amount,
                                           buyPrice: prices.costToBuy,
                                           salePrice: prices.paidForSale,
                                           tax: localPlayer?.tax ?? 0)
    }

    nonisolated static func marketTransactionQuote(amount: Int,
                                                   buyPrice: Int,
                                                   salePrice: Int,
                                                   tax: Int) -> (buyTotal: Int, sellAfterTax: Int) {
        let count = max(0, amount)
        let normalizedTax = min(max(0, tax), 100)
        let grossSale = count * max(0, salePrice)
        return (buyTotal: count * max(0, buyPrice),
                sellAfterTax: (grossSale * (100 - normalizedTax)) / 100)
    }

    nonisolated static func loadableGoodsAmount(cargoCapacity: Int,
                                                goodsAmounts: [Int],
                                                carriedUnitSpace: Int,
                                                selectedGoodsAmount: Int) -> Int {
        let cargoSize = MarketPricing.goodsPerCargoChunk
        let goodsSpace = goodsAmounts.reduce(0) { total, amount in
            let positiveAmount = max(0, amount)
            return total + (positiveAmount + cargoSize - 1) / cargoSize
        }
        let freeSlots = max(0, cargoCapacity - goodsSpace - max(0, carriedUnitSpace))
        let selectedRemainder = max(0, selectedGoodsAmount) % cargoSize
        let partialStackSpace = selectedRemainder == 0 ? 0 : cargoSize - selectedRemainder
        return freeSlots * cargoSize + partialStackSpace
    }

    /// Buy price (`costToBuy`) or sale price (`paidForSale`) for one goods type.
    private func marketPrice(for goodsTypeId: String, sell: Bool) -> Int {
        let prices = marketPrices(for: goodsTypeId)
        return sell ? prices.paidForSale : prices.costToBuy
    }

    /// Arrears owed for a goods type (0 when not boycotted).
    func arrears(for goodsTypeId: String?) -> Int {
        localPlayer?.market?.entry(for: goodsTypeId)?.arrears ?? 0
    }

    func canPayArrears(for goodsTypeId: String?) -> Bool {
        guard phase == .inGame, isLocalPlayersTurn,
              let goodsTypeId, !goodsTypeId.isEmpty,
              let gold = localPlayer?.gold else { return false }
        let owed = arrears(for: goodsTypeId)
        return owed > 0 && gold >= owed
    }

    /// Pay the tax arrears to lift a boycott on one goods type.
    func payArrears(goodsTypeId: String) {
        let trimmed = goodsTypeId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Bitte eine Warenart angeben."
            return
        }
        guard canPayArrears(for: trimmed) else {
            errorMessage = "Rueckstaende koennen nicht bezahlt werden."
            return
        }
        errorMessage = nil
        Task {
            do {
                let msg = ParsedMessage(
                    tag: "payArrears",
                    attributes: ["goodsType": trimmed],
                    children: []
                )
                try await client?.send(message: msg)
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    private func marketTradeContext(goodsTypeId: String,
                                    amount: Int,
                                    carrierId: String) throws -> (europeId: String, typeId: String, carrier: FreeColGame.Unit) {
        let typeId = goodsTypeId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard phase == .inGame else {
            throw MarketTradeError.message("Handel in Europa nicht möglich.")
        }
        guard isLocalPlayersTurn else {
            throw MarketTradeError.message("Nicht dein Zug.")
        }
        guard !typeId.isEmpty else {
            throw MarketTradeError.message("Bitte eine Warenart angeben.")
        }
        guard amount > 0 else {
            throw MarketTradeError.message("Menge muss groesser als 0 sein.")
        }
        guard let game = cachedGame,
              let localPlayerId = resolveLocalPlayerId(),
              let player = game.players[localPlayerId],
              let europeId = player.europe?.id else {
            throw MarketTradeError.message("Europa-Informationen fehlen.")
        }
        guard let marketData = player.market?.entry(for: typeId) else {
            throw MarketTradeError.message("Marktdaten für diese Ware fehlen.")
        }
        guard marketData.arrears <= 0 else {
            throw MarketTradeError.message("Ware boykottiert. Bitte zuerst die Rückstände bezahlen.")
        }
        guard let carrier = game.units[carrierId],
              carrier.owner == localPlayerId,
              resolveUnitTileId(carrier, in: game) == nil else {
            throw MarketTradeError.message("Traeger nicht in Europa.")
        }
        return (europeId, typeId, carrier)
    }

    func equipSelectedUnitForRole(_ roleId: String, count: Int) {
        guard canEquipSelectedUnit(forRole: roleId, count: count),
              let unitId = selectedUnitId else {
            errorMessage = "Einheit kann diese Rolle mit der verfügbaren Ausrüstung nicht annehmen."
            return
        }
        errorMessage = nil


        Task {
            do {
                let msg = ParsedMessage(
                    tag: "equipForRole",
                    attributes: [
                        "unit": unitId,
                        "role": roleId,
                        "count": String(count),
                    ],
                    children: []
                )
                try await sendCoreGameplayAction(msg, queueIfDisconnected: false)
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    func sendMissionaryAction(direction: String, denounce: Bool) {
        guard canSendMissionaryAction,
              let unitId = selectedUnitId else {
            errorMessage = "Missionarsaktion nicht möglich."
            return
        }
        guard isValidDirection(direction) else {
            errorMessage = "Ungültige Richtung."
            return
        }
        errorMessage = nil


        Task {
            do {
                let msg = ParsedMessage(
                    tag: "missionary",
                    attributes: [
                        "unit": unitId,
                        "direction": direction,
                        "denounce": denounce ? "true" : "false",
                    ],
                    children: []
                )
                try await client?.send(message: msg)
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    var canEquipSelectedUnitForRole: Bool {
        canEquipSelectedUnit(forRole: "model.role.missionary", count: 1)
    }

    var selectedUnitPioneerEquipmentCount: Int {
        guard let unit = selectedUnit, unit.role == "model.role.pioneer" else { return 1 }
        return unit.roleCount + 1
    }

    var canEquipSelectedUnitAsPioneer: Bool {
        canEquipSelectedUnit(forRole: "model.role.pioneer", count: selectedUnitPioneerEquipmentCount)
    }

    func canEquipSelectedUnit(forRole roleId: String, count: Int) -> Bool {
        guard phase == .inGame,
              isLocalPlayersTurn,
              let game = cachedGame,
              let unitId = selectedUnitId,
              let unit = game.units[unitId],
              let localPlayerId = resolveLocalPlayerId(),
              unit.owner == localPlayerId,
              canUnitWorkInColony(unit),
              count > 0 else {
            return false
        }

        guard roleId == "model.role.missionary" || roleId == "model.role.pioneer",
              unit.role != roleId || roleId == "model.role.pioneer",
              let specification = game.specification else {
            return false
        }

        let roleInfo = specification.roleTypes[roleId]
        let maximumCount = roleInfo?.maximumCount ?? (roleId == "model.role.pioneer" ? 5 : 1)
        guard count <= maximumCount else { return false }
        if let unitType = unit.unitType {
            if specification.effectiveAbility(unitTypeId: unitType,
                                              abilityId: "model.ability.canBeEquipped") == false {
                return false
            }
            for (abilityId, expectedValue) in roleInfo?.requiredAbilities ?? [:] {
                let actualValue = specification.effectiveAbility(unitTypeId: unitType,
                                                                 abilityId: abilityId) ?? false
                if actualValue != expectedValue { return false }
            }
        } else if !(roleInfo?.requiredAbilities.isEmpty ?? true) {
            return false
        }

        let goodsDelta = Self.roleEquipmentGoodsDelta(unit: unit,
                                                      targetRoleId: roleId,
                                                      targetCount: count,
                                                      roleTypes: specification.roleTypes)
        let neededGoods = goodsDelta.filter { $0.value > 0 }

        if unit.location == localPlayer?.europe?.id {
            guard let player = game.players[localPlayerId] else { return false }
            var totalCost = 0
            for (goodsType, amount) in neededGoods {
                guard let marketData = player.market?.entry(for: goodsType),
                      marketData.arrears <= 0 else { return false }
                let price = MarketPricing.prices(for: marketData, specification: specification).costToBuy
                guard price > 0 else { return false }
                totalCost += amount * price
            }
            return player.gold >= totalCost
        }

        guard let tileId = resolveUnitTileId(unit, in: game),
              let colony = game.colonies.values.first(where: {
                  $0.tileId == tileId && $0.owner == localPlayerId
              }) else { return false }

        if roleId == "model.role.missionary",
           unit.unitType != "model.unit.jesuitMissionary",
           !colony.buildings.contains(where: {
                ["model.building.church", "model.building.cathedral"].contains($0.buildingType ?? "")
           }) {
            return false
        }
        return neededGoods.allSatisfy { colony.goods[$0.key, default: 0] >= $0.value }
    }

    private nonisolated static func roleEquipmentGoodsDelta(
        unit: FreeColGame.Unit,
        targetRoleId: String,
        targetCount: Int,
        roleTypes: [String: RoleTypeInfo]
    ) -> [String: Int] {
        let currentRoleId = unit.role
        let currentGoods = currentRoleId.flatMap { roleTypes[$0]?.requiredGoods } ?? [:]
        let targetGoods = roleTypes[targetRoleId]?.requiredGoods ?? [:]
        var result: [String: Int] = [:]
        for goodsType in Set(currentGoods.keys).union(targetGoods.keys) {
            let currentAmount = currentGoods[goodsType, default: 0] * unit.roleCount
            let targetAmount = targetGoods[goodsType, default: 0] * targetCount
            result[goodsType] = targetAmount - currentAmount
        }
        return result
    }

    var canSendMissionaryAction: Bool {
        guard phase == .inGame,
              isLocalPlayersTurn,
              let game = cachedGame,
              let unitId = selectedUnitId,
              let unit = game.units[unitId],
              let localPlayerId = resolveLocalPlayerId(),
              unit.owner == localPlayerId,
              unit.state == .active,
              unit.movesLeft > 0 else {
            return false
        }
        return UnitTypeTraits.isMissionary(unitType: unit.unitType, role: unit.role)
    }

    func learnSkillAtSelectedUnit(direction: String) {
        guard canLearnSkillAtSelectedUnit,
              let unitId = selectedUnitId,
              let game = cachedGame else {
            errorMessage = "Fähigkeit kann nicht erlernt werden."
            return
        }
        errorMessage = nil


        Task {
            do {
                let msg = ParsedMessage(
                    tag: "learnSkill",
                    attributes: [
                        "unit": unitId,
                        "direction": direction,
                    ],
                    children: []
                )
                try await client?.send(message: msg)
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    var canLearnSkillAtSelectedUnit: Bool {
        guard phase == .inGame,
              isLocalPlayersTurn,
              let game = cachedGame,
              let unitId = selectedUnitId,
              let unit = game.units[unitId],
              let localPlayerId = resolveLocalPlayerId(),
              unit.owner == localPlayerId,
              unit.movesLeft > 0,
              unit.state == .active else {
            return false
        }
        return true
    }

    /// Refresh a native settlement's learnable skill from the server.
    func askSkillAtSelectedUnit(direction: String) {
        guard canAskSkillAtSelectedUnit,
              let unitId = selectedUnitId else {
            errorMessage = "Fähigkeit kann nicht erfragt werden."
            return
        }
        errorMessage = nil
        Task {
            do {
                let msg = ParsedMessage(
                    tag: "askSkill",
                    attributes: ["unit": unitId, "direction": direction],
                    children: []
                )
                let reply = try await client?.ask(message: msg)
                if let reply, server == nil, let payload = reply.children.first {
                    // Remote server: apply the refreshed settlement payload.
                    try? cachedGame?.applyUpdate(payload)
                    gameUpdateID += 1
                }
                statusMessage = "Fähigkeit erfragt."
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    var canAskSkillAtSelectedUnit: Bool {
        canLearnSkillAtSelectedUnit
    }

    func nameNewLandWithSelectedUnit(_ landName: String) {
        let trimmedName = landName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Bitte einen Namen eingeben."
            return
        }
        guard canNameNewLandWithSelectedUnit,
              let unitId = selectedUnitId,
              let game = cachedGame else {
            errorMessage = "Neues Land kann nicht benannt werden."
            return
        }
        errorMessage = nil


        Task {
            do {
                let msg = ParsedMessage(
                    tag: "newLandName",
                    attributes: [
                        "unit": unitId,
                        "newLandName": trimmedName,
                    ],
                    children: []
                )
                try await client?.send(message: msg)
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    var canNameNewLandWithSelectedUnit: Bool {
        guard phase == .inGame,
              isLocalPlayersTurn,
              let game = cachedGame,
              let unitId = selectedUnitId,
              let unit = game.units[unitId],
              let localPlayerId = resolveLocalPlayerId(),
              unit.owner == localPlayerId else {
            return false
        }
        return true
    }

    func nameNewRegionWithSelectedUnit(
        regionId: String,
        tileId: String,
        regionName: String
    ) {
        let trimmedName = regionName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Bitte einen Namen eingeben."
            return
        }
        guard canNameNewRegionWithSelectedUnit,
              let unitId = selectedUnitId,
              let game = cachedGame else {
            errorMessage = "Neue Region kann nicht benannt werden."
            return
        }
        guard !regionId.isEmpty && !tileId.isEmpty else {
            errorMessage = "Region oder Kachel-ID fehlt."
            return
        }
        errorMessage = nil


        Task {
            do {
                let msg = ParsedMessage(
                    tag: "newRegionName",
                    attributes: [
                        "unit": unitId,
                        "region": regionId,
                        "tile": tileId,
                        "newRegionName": trimmedName,
                    ],
                    children: []
                )
                try await client?.send(message: msg)
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    var canNameNewRegionWithSelectedUnit: Bool {
        guard phase == .inGame,
              isLocalPlayersTurn,
              let game = cachedGame,
              let unitId = selectedUnitId,
              let unit = game.units[unitId],
              let localPlayerId = resolveLocalPlayerId(),
              unit.owner == localPlayerId else {
            return false
        }
        return true
    }

    func inciteSettlement(
        settlementId: String,
        enemyPlayerId: String,
        gold: Int
    ) {
        guard canInciteSelectedUnit,
              let unitId = selectedUnitId,
              let game = cachedGame else {
            errorMessage = "In der Siedlung kann kein Aufstand angezettelt werden."
            return
        }
        guard !settlementId.isEmpty && !enemyPlayerId.isEmpty else {
            errorMessage = "Siedlung oder Gegner-ID fehlt."
            return
        }
        errorMessage = nil


        Task {
            do {
                let msg = ParsedMessage(
                    tag: "incite",
                    attributes: [
                        "unit": unitId,
                        "settlement": settlementId,
                        "enemy": enemyPlayerId,
                        "gold": String(gold),
                    ],
                    children: []
                )
                try await client?.send(message: msg)
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    var canInciteSelectedUnit: Bool {
        guard phase == .inGame,
              isLocalPlayersTurn,
              let game = cachedGame,
              let unitId = selectedUnitId,
              let unit = game.units[unitId],
              let localPlayerId = resolveLocalPlayerId(),
              unit.owner == localPlayerId else {
            return false
        }
        return true
    }

    // MARK: Phase 42 - DeliverGift

    func deliverGiftToSettlement(_ settlementId: String) {
        guard canDeliverGiftWithSelectedUnit,
              let unitId = selectedUnitId else {
            errorMessage = "Geschenk kann nicht übergeben werden."
            return
        }
        guard !settlementId.isEmpty else {
            errorMessage = "Siedlungs-ID erforderlich."
            return
        }
        errorMessage = nil


        Task {
            do {
                let msg = ParsedMessage(
                    tag: "deliverGift",
                    attributes: [
                        "unit": unitId,
                        "settlement": settlementId,
                    ],
                    children: []
                )
                try await client?.send(message: msg)
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    var canDeliverGiftWithSelectedUnit: Bool {
        guard phase == .inGame,
              isLocalPlayersTurn,
              let game = cachedGame,
              let unitId = selectedUnitId,
              let unit = game.units[unitId],
              let localPlayerId = resolveLocalPlayerId(),
              unit.owner == localPlayerId else {
            return false
        }
        return true
    }

    // MARK: Phase 43 - DemandTribute

    func demandTributeFromSettlement(direction: String) {
        guard canDemandTributeWithSelectedUnit,
              let unitId = selectedUnitId else {
            errorMessage = "Tribut kann nicht gefordert werden."
            return
        }
        guard isValidDirection(direction) else {
            errorMessage = "Ungültige Richtung."
            return
        }
        errorMessage = nil


        Task {
            do {
                let msg = ParsedMessage(
                    tag: "demandTribute",
                    attributes: [
                        "direction": direction,
                        "unit": unitId,
                    ],
                    children: []
                )
                try await client?.send(message: msg)
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    var canDemandTributeWithSelectedUnit: Bool {
        guard phase == .inGame,
              isLocalPlayersTurn,
              let game = cachedGame,
              let unitId = selectedUnitId,
              let unit = game.units[unitId],
              let localPlayerId = resolveLocalPlayerId(),
              unit.owner == localPlayerId,
              unit.movesLeft > 0,
              unit.state == .active else {
            return false
        }
        return true
    }

    // MARK: Phase 44 - NativeGift

    func acceptGiftFromNativeSettlement(colonyId: String) {
        guard canAcceptNativeGift,
              let unitId = selectedUnitId else {
            errorMessage = "Geschenk kann nicht angenommen werden."
            return
        }
        guard !colonyId.isEmpty else {
            errorMessage = "Kolonie-ID erforderlich."
            return
        }
        errorMessage = nil


        Task {
            do {
                let msg = ParsedMessage(
                    tag: "nativeGift",
                    attributes: [
                        "colony": colonyId,
                        "unit": unitId,
                    ],
                    children: []
                )
                try await client?.send(message: msg)
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    var canAcceptNativeGift: Bool {
        guard phase == .inGame,
              isLocalPlayersTurn,
              let game = cachedGame,
              let unitId = selectedUnitId,
              let unit = game.units[unitId],
              let localPlayerId = resolveLocalPlayerId(),
              unit.owner == localPlayerId else {
            return false
        }
        return true
    }

    // MARK: Phase 45 - SpySettlement

    func spyOnNativeSettlement(settlementId: String) {
        guard canSpyOnNativeSettlement,
              let unitId = selectedUnitId else {
            errorMessage = "Spionage ist nicht möglich."
            return
        }
        guard !settlementId.isEmpty else {
            errorMessage = "Siedlungs-ID erforderlich."
            return
        }
        errorMessage = nil


        Task {
            do {
                let msg = ParsedMessage(
                    tag: "spySettlement",
                    attributes: [
                        "settlement": settlementId,
                        "unit": unitId,
                    ],
                    children: []
                )
                try await client?.send(message: msg)
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    var canSpyOnNativeSettlement: Bool {
        guard phase == .inGame,
              isLocalPlayersTurn,
              let game = cachedGame,
              let unitId = selectedUnitId,
              let unit = game.units[unitId],
              let localPlayerId = resolveLocalPlayerId(),
              unit.owner == localPlayerId else {
            return false
        }
        return true
    }

    // MARK: Phase 46 - ScoutIndianSettlement

    func scoutIndianSettlement(direction: String) {
        guard canScoutIndianSettlement,
              let unitId = selectedUnitId else {
            errorMessage = "Erkundung ist nicht möglich."
            return
        }
        guard isValidDirection(direction) else {
            errorMessage = "Ungültige Richtung."
            return
        }
        errorMessage = nil


        Task {
            do {
                let msg = ParsedMessage(
                    tag: "scoutIndianSettlement",
                    attributes: [
                        "direction": direction,
                        "unit": unitId,
                    ],
                    children: []
                )
                try await client?.send(message: msg)
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    var canScoutIndianSettlement: Bool {
        guard phase == .inGame,
              isLocalPlayersTurn,
              let game = cachedGame,
              let unitId = selectedUnitId,
              let unit = game.units[unitId],
              let localPlayerId = resolveLocalPlayerId(),
              unit.owner == localPlayerId,
              unit.movesLeft > 0,
              unit.state == .active else {
            return false
        }
        return true
    }

    // MARK: Phase 47 - ScoutSpeakToChief

    func scoutSpeakToChief(settlementId: String, result: String) {
        guard canScoutSpeakToChief,
              let unitId = selectedUnitId else {
            errorMessage = "Gespräch mit Häuptling nicht möglich."
            return
        }
        guard !settlementId.isEmpty && !result.isEmpty else {
            errorMessage = "Siedlungs-ID und Ergebnis erforderlich."
            return
        }
        errorMessage = nil


        Task {
            do {
                let msg = ParsedMessage(
                    tag: "scoutSpeakToChief",
                    attributes: [
                        "result": result,
                        "settlement": settlementId,
                        "unit": unitId,
                    ],
                    children: []
                )
                try await client?.send(message: msg)
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    var canScoutSpeakToChief: Bool {
        guard phase == .inGame,
              isLocalPlayersTurn,
              let game = cachedGame,
              let unitId = selectedUnitId,
              let unit = game.units[unitId],
              let localPlayerId = resolveLocalPlayerId(),
              unit.owner == localPlayerId else {
            return false
        }
        return true
    }

    // MARK: Phase 48 - Diplomacy

    var diplomacyContextForSelectedUnit: String? {
        guard let unit = selectedUnit, let specification = cachedGame?.specification else { return nil }
        if specification.hasAbility("model.ability.negotiate", unitType: unit.unitType) {
            return "DIPLOMATIC"
        }
        guard !isNavalUnit(unit),
              ["model.role.soldier", "model.role.dragoon"].contains(unit.role ?? "")
                || (specification.unitTypes[unit.unitType ?? ""]?.offence ?? 0) > 0 else { return nil }
        return "TRIBUTE"
    }

    var pendingDiplomacyClauseKinds: [DiplomaticClauseKind] {
        pendingDiplomacy?.context == "TRIBUTE" ? [.gold, .stance, .incite] : DiplomaticClauseKind.allCases
    }

    /// Adjacent foreign colonies the selected unit could negotiate with.
    var diplomacyInitiationTargetsForSelectedUnit: [(id: String, label: String)] {
        guard phase == .inGame,
              isLocalPlayersTurn,
              let game = cachedGame,
              let unit = selectedUnit,
              let localPlayerId = resolveLocalPlayerId(),
              unit.owner == localPlayerId,
              unit.movesLeft > 0,
              unit.state == .active,
              diplomacyContextForSelectedUnit != nil,
              let unitTileId = resolveUnitTileId(unit, in: game),
              game.tiles[unitTileId] != nil else { return [] }
        let neighbors = Set(game.neighborTileIds(of: unitTileId))
        return game.colonies.values.compactMap { colony in
            guard let ownerId = colony.owner,
                  ownerId != localPlayerId,
                  game.players[ownerId]?.playerType == .european,
                  let colonyTileId = colony.tileId,
                  neighbors.contains(colonyTileId) else { return nil }
            let ownerName = game.players[ownerId]?.name ?? ownerId
            return (id: colony.id, label: "\(colony.name ?? colony.id) (\(ownerName))")
        }
    }

    /// Open a diplomacy session with a foreign colony using the selected unit.
    /// Synthesizes a PROPOSE_TRADE so the counter-proposal builder can compose
    /// the opening offer.
    func beginDiplomacy(otherColonyId: String) {
        guard phase == .inGame,
              isLocalPlayersTurn,
              let game = cachedGame,
              let unitId = selectedUnitId,
              let other = game.colonies[otherColonyId],
              let otherOwner = other.owner,
              let context = diplomacyContextForSelectedUnit,
              let ourId = resolveLocalPlayerId() else {
            errorMessage = "Diplomatie nicht möglich."
            return
        }
        guard diplomacyInitiationTargetsForSelectedUnit.contains(where: { $0.id == otherColonyId }) else {
            errorMessage = "Keine angrenzende fremde Kolonie."
            return
        }
        errorMessage = nil
        let tradeNode = ParsedMessage(
            tag: "diplomaticTrade",
            attributes: [
                "id": "",
                "context": context,
                "sender": ourId,
                "recipient": otherOwner,
                "status": "PROPOSE_TRADE",
                "version": "0",
            ],
            children: context == "TRIBUTE" ? [
                Self.diplomacyClauseNode(DiplomaticClauseDraft(kind: .stance), ourId: ourId, otherId: otherOwner),
                Self.diplomacyClauseNode(DiplomaticClauseDraft(kind: .gold, weGive: false),
                                        ourId: ourId, otherId: otherOwner),
            ] : []
        )
        pendingServerDecision = PendingServerDecision(
            type: .diplomacy,
            rawPayload: ["ourId": unitId, "otherId": otherColonyId],
            children: [tradeNode]
        )
        statusMessage = context == "TRIBUTE" ? "Tributverhandlung eröffnet." : "Diplomatie eröffnet."
    }

    var canSendDiplomacy: Bool {
        guard phase == .inGame,
              isLocalPlayersTurn,
              let game = cachedGame,
              let localPlayerId = resolveLocalPlayerId(),
              game.players[localPlayerId] != nil else {
            return false
        }
        return true
    }

    func canAttackSelectedUnitMelee(onTile targetTileId: String) -> Bool {
        guard phase == .inGame,
              isLocalPlayersTurn,
              let game = cachedGame,
              let unitId = selectedUnitId,
              let attacker = game.units[unitId],
              let localPlayerId = resolveLocalPlayerId(),
              attacker.owner == localPlayerId,
              attacker.movesLeft > 0,
              attacker.state == .active,
              let sourceTileId = resolveUnitTileId(attacker, in: game),
              sourceTileId != targetTileId,
              let _ = attackDirection(fromTileId: sourceTileId, toTileId: targetTileId, in: game) else {
            return false
        }
        return hasHostileUnit(onTile: targetTileId, in: game, friendlyOwner: localPlayerId)
    }

    func canAttackSelectedUnitRanged(onTile targetTileId: String) -> Bool {
        guard phase == .inGame,
              isLocalPlayersTurn,
              let game = cachedGame,
              let unitId = selectedUnitId,
              let attacker = game.units[unitId],
              let localPlayerId = resolveLocalPlayerId(),
              attacker.owner == localPlayerId,
              attacker.movesLeft > 0,
              attacker.state == .active,
              let sourceTileId = resolveUnitTileId(attacker, in: game),
              sourceTileId != targetTileId else {
            return false
        }
        guard hasHostileUnit(onTile: targetTileId, in: game, friendlyOwner: localPlayerId) else {
            return false
        }
        // MVP heuristic: treat artillery/cannon-like units as ranged-capable.
        let type = (attacker.unitType ?? "").lowercased()
        let isRangedCapable = type.contains("artillery")
            || type.contains("cannon")
            || type.contains("mortar")
        return isRangedCapable
    }

    func attackSelectedUnitMelee(onTile targetTileId: String) {
        guard canAttackSelectedUnitMelee(onTile: targetTileId),
              let game = cachedGame,
              let unitId = selectedUnitId,
              let attacker = game.units[unitId],
              let sourceTileId = resolveUnitTileId(attacker, in: game),
              let direction = attackDirection(fromTileId: sourceTileId, toTileId: targetTileId, in: game) else {
            errorMessage = "Nahkampfangriff nicht möglich."
            return
        }
        errorMessage = nil


        Task {
            do {
                let msg = ParsedMessage(
                    tag: "attack",
                    attributes: ["unit": unitId, "direction": direction],
                    children: []
                )
                if server != nil {
                    game.resolveCombat(attackerId: unitId, targetTileId: targetTileId, isRanged: false)
                    reconcileSelectionWithGame()
                    gameUpdateID += 1
                }
                try await client?.send(message: msg)
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    func attackSelectedUnitRanged(onTile targetTileId: String) {
        guard canAttackSelectedUnitRanged(onTile: targetTileId),
              let game = cachedGame,
              let unitId = selectedUnitId else {
            errorMessage = "Fernkampfangriff nicht möglich."
            return
        }
        errorMessage = nil


        Task {
            do {
                let msg = ParsedMessage(
                    tag: "attackRanged",
                    attributes: ["unit": unitId, "target": targetTileId],
                    children: []
                )
                if server != nil {
                    game.resolveCombat(attackerId: unitId, targetTileId: targetTileId, isRanged: true)
                    reconcileSelectionWithGame()
                    gameUpdateID += 1
                }
                try await client?.send(message: msg)
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    func canMoveSelectedUnit(to destinationTileId: String) -> Bool {
        guard canMoveSelectedUnitTo(destinationTileId: destinationTileId),
              let game = cachedGame,
              let sourceTileId = selectedUnitTileId else {
            return false
        }
        guard attackDirection(fromTileId: sourceTileId, toTileId: destinationTileId, in: game) != nil else {
            return false
        }
        return true
    }

    func syncAfterModelUpdate() {
        surfaceEuropeArrivalMessage()
        reconcileSelectionWithGame()
        reconcileSelectedUnitOrderWithGame()
        reconcilePendingEndTurnWithGame()
        // Saved movement orders are attempted once per local turn, not once
        // per calendar turn. Clear the guard as soon as control passes away so
        // orders can resume when this player's next turn begins, even if the
        // server has not advanced the global turn number yet.
        if !isLocalPlayersTurn {
            movementAttempts.removeAll()
        }
        autoFocusInitialUnitIfNeeded()
        continueSavedMovementOrders()
    }

    private func continueSavedMovementOrders() {
        guard phase == .inGame, isLocalPlayersTurn, !isEndingTurn, !isSavingGame,
              movingUnitId == nil, let game = cachedGame, let owner = localPlayerId else { return }
        guard let unit = game.units.values.sorted(by: { $0.id < $1.id }).first(where: {
            $0.owner == owner && $0.movesLeft > 0 && $0.tradeRoute == nil
                && game.tiles[$0.location ?? ""] != nil
                && canIssueMovementOrders(for: $0, in: game)
                && $0.destination.flatMap { game.tiles[$0] } != nil
                && movementAttempts[$0.id] != game.turn.number
        }), let destination = unit.destination else { return }
        startMovingUnit(unit.id, to: destination)
    }

    func movementPath(for unit: FreeColGame.Unit) -> [String] {
        guard let game = cachedGame, let destination = unit.destination,
              let source = resolveUnitTileId(unit, in: game), game.tiles[destination] != nil else { return [] }
        var path = [source]
        var visited: Set<String> = [source]
        while let current = path.last, current != destination {
            guard let next = nextStepTowardDestination(
                for: unit, destinationTileId: destination, in: game, from: current
            ), visited.insert(next).inserted else { return [] }
            path.append(next)
        }
        return path
    }

    func unitTravelStatus(_ unit: FreeColGame.Unit) -> String? {
        guard let game = cachedGame else { return nil }
        if game.players.values.contains(where: { $0.europe?.id == unit.location && unit.location != nil }) {
            return "In Europa"
        }
        let isOnMap = unit.location.flatMap { game.tiles[$0] } != nil
        guard !isOnMap,
              unit.location?.hasPrefix("highSeas:") == true
                || [.sailing, .toEurope, .toAmerica].contains(unit.state) else { return nil }
        let destination: String
        if game.players.values.contains(where: { $0.europe?.id == unit.destination && unit.destination != nil })
            || unit.state == .toEurope {
            destination = "Europa"
        } else if unit.destination == game.map?.id && unit.destination != nil
                    || unit.destination.flatMap({ game.tiles[$0] }) != nil
                    || unit.state == .toAmerica {
            destination = "Neue Welt"
        } else {
            destination = "Ziel unbekannt"
        }
        let turns = max(0, unit.workLeft)
        return "Überfahrt: \(destination) (\(turns) \(turns == 1 ? "Runde" : "Runden"))"
    }

    func unitLocationDisplayName(_ unit: FreeColGame.Unit) -> String {
        if let travelStatus = unitTravelStatus(unit) { return travelStatus }
        guard let game = cachedGame else { return "Standort unbekannt" }
        if let tileId = game.resolvedTileId(for: unit), let tile = game.tiles[tileId] {
            if let colony = game.colonies.values.first(where: { $0.tileId == tileId }) {
                return colony.name ?? "Kolonie"
            }
            return "Karte \(tile.x), \(tile.y)"
        }
        return "Standort unbekannt"
    }

    private func surfaceEuropeArrivalMessage() {
        guard let message = localPlayer?.modelMessages.first(where: { message in
            let signature = "\(message.id)|\(message.source ?? "")|\(message.display ?? "")"
            guard !seenModelMessageSignatures.contains(signature) else { return false }
            seenModelMessageSignatures.insert(signature)
            return message.id == "model.unit.arriveInEurope"
        }) else { return }
        let ship = message.source.flatMap { cachedGame?.units[$0] }
        let name = ship?.name ?? ship?.unitType.map(unitDisplayName) ?? "Ein Schiff"
        statusMessage = "\(name) ist in Europa eingetroffen."
    }

    private func reconcileSelectionWithGame() {
        guard let game = cachedGame else {
            selectedUnitId = nil
            selectedTileId = nil
            closeColonyPanel()
            return
        }

        // Colony actions must not let unit recovery or movement change the open colony.
        if showColonyPanel, let displayedColonyId {
            if let colony = game.colonies[displayedColonyId],
               let tileId = colony.tileId, game.tiles[tileId] != nil {
                selectedTileId = tileId
                if !selectedColonyUnits.contains(where: { $0.id == selectedUnitId }) {
                    selectedUnitId = nil
                }
                return
            }
            closeColonyPanel()
        }

        let localPlayerId = resolveLocalPlayerId()

        if let unitId = selectedUnitId {
            guard let unit = game.units[unitId] else {
                if let tileId = selectedTileId, game.tiles[tileId] != nil {
                    if let localPlayerId,
                       let recovered = game.recoverSelection(for: localPlayerId, preferredTileId: tileId) {
                        selectedUnitId = recovered.unitId
                        selectedTileId = recovered.tileId
                    } else {
                        selectedUnitId = nil
                        selectedTileId = tileId
                    }
                } else if let localPlayerId,
                          let recovered = game.recoverSelection(for: localPlayerId) {
                    selectedUnitId = recovered.unitId
                    selectedTileId = recovered.tileId
                } else {
                    selectedUnitId = nil
                    selectedTileId = nil
                }
                return
            }
            if let tileId = resolveUnitTileId(unit, in: game) {
                selectedTileId = tileId
            } else {
                selectedTileId = nil
            }
        } else if let tileId = selectedTileId {
            if game.tiles[tileId] == nil {
                selectedTileId = nil
            } else if let localPlayerId,
                      let recovered = game.recoverSelection(for: localPlayerId, preferredTileId: tileId) {
                selectedUnitId = recovered.unitId
                selectedTileId = recovered.tileId
            }
        }
    }

    private func reconcilePendingEndTurnWithGame() {
        guard isEndingTurn else { return }
        guard let game = cachedGame else {
            clearPendingEndTurn()
            return
        }
        if !isLocalPlayersTurn {
            clearPendingEndTurn()
            return
        }
        if let pendingTurn = pendingEndTurnTurn, game.turn.number != pendingTurn {
            clearPendingEndTurn()
        }
    }

    private func reconcileSelectedUnitOrderWithGame() {
        guard let game = cachedGame,
              let unitId = selectedUnitId,
              let unit = game.units[unitId],
              let destinationId = unit.destination else {
            return
        }

        let currentTileId: String?
        if let loc = unit.location, game.tiles[loc] != nil {
            currentTileId = loc
        } else if let carrierId = unit.location,
                  let carrier = game.units[carrierId],
                  let carrierTile = carrier.location,
                  game.tiles[carrierTile] != nil {
            currentTileId = carrierTile
        } else {
            currentTileId = nil
        }

        if currentTileId == destinationId {
            game.setUnitDestination(unitId: unitId, destinationId: nil)
        }
    }

    func resolveUnitTileId(_ unit: FreeColGame.Unit, in game: Game) -> String? {
        game.resolvedTileId(for: unit)
    }

    private func hasHostileUnit(onTile tileId: String, in game: Game, friendlyOwner: String) -> Bool {
        game.units.values.contains {
            $0.location == tileId && $0.owner != nil && $0.owner != friendlyOwner
        }
    }

    func attackDirection(fromTileId sourceTileId: String, toTileId targetTileId: String, in game: Game) -> String? {
        guard let source = game.tiles[sourceTileId],
              let target = game.tiles[targetTileId] else {
            return nil
        }

        let dx = target.x - source.x
        let dy = target.y - source.y
        let odd = !source.y.isMultiple(of: 2)

        let mapping: [String: (Int, Int)] = odd
            ? [
                "N": (0, -2),
                "NE": (1, -1),
                "E": (1, 0),
                "SE": (1, 1),
                "S": (0, 2),
                "SW": (0, 1),
                "W": (-1, 0),
                "NW": (0, -1),
            ]
            : [
                "N": (0, -2),
                "NE": (0, -1),
                "E": (1, 0),
                "SE": (0, 1),
                "S": (0, 2),
                "SW": (-1, 1),
                "W": (-1, 0),
                "NW": (-1, -1),
            ]

        return mapping.first(where: { $0.value.0 == dx && $0.value.1 == dy })?.key
    }

    private func nextStepTowardDestination(for unit: FreeColGame.Unit, destinationTileId: String, in game: Game, from source: String? = nil) -> String? {
        guard let sourceTileId = source ?? resolveUnitTileId(unit, in: game),
              game.tiles[destinationTileId] != nil else {
            return nil
        }
        return game.nextPathStep(
            from: sourceTileId,
            to: destinationTileId,
            stepCost: { current, next in
                game.hasRoadConnection(from: current, to: next) ? 1 : 3
            }
        ) { _, next in
            guard let tile = game.tiles[next], tile.type != nil, let owner = unit.owner,
                  !hasHostileUnit(onTile: next, in: game, friendlyOwner: owner),
                  !game.colonies.values.contains(where: { $0.tileId == next && $0.owner != owner }) else { return false }
            let water = isWaterTile(tile, in: game)
            if isNavalUnit(unit) {
                return water || game.colonies.values.contains { $0.tileId == next && $0.owner == owner }
            }
            return !water
        }
    }

    private func isWaterTile(_ tile: Tile, in game: Game) -> Bool {
        guard let type = tile.type else { return false }
        return game.specification?.tileTypes[type]?.isWater
            ?? ["model.tile.ocean", "model.tile.highSeas", "model.tile.lake", "model.tile.greatRiver"].contains(type)
    }

    private func canIssueMovementOrders(for unit: FreeColGame.Unit, in game: Game) -> Bool {
        unit.state == .active || (unit.state == .sentry && game.units[unit.location ?? ""] != nil)
    }
    private func isValidDirection(_ direction: String) -> Bool {
        ["N", "NE", "E", "SE", "S", "SW", "W", "NW"].contains(direction)
    }

    private func clearPendingEndTurn() {
        isEndingTurn = false
        pendingEndTurnTurn = nil
        endTurnToken += 1
    }

    private func autoFocusInitialUnitIfNeeded() {
        guard !didAutoFocusInitialUnit,
              !showColonyPanel,
              selectedUnitId == nil,
              phase == .inGame,
              let game = cachedGame,
              let localPlayerId = resolveLocalPlayerId() else {
            return
        }

        let unit = game.units.values
            .sorted { $0.id < $1.id }
            .first(where: {
                $0.owner == localPlayerId
                && $0.state == .active
                && resolveUnitTileId($0, in: game) != nil
            })

        guard let unit else { return }
        selectUnit(unit.id, onTile: resolveUnitTileId(unit, in: game))
        didAutoFocusInitialUnit = true
    }

    func isLikelyCarrier(_ unit: FreeColGame.Unit, in game: Game) -> Bool {
        if game.units.values.contains(where: { $0.location == unit.id }) {
            return true
        }
        return isCarrierUnit(unit)
    }

    /// True when a settlement (colony or native village) occupies the tile.
    nonisolated static func tileHasSettlement(_ tile: Tile, in game: Game) -> Bool {
        if tile.settlement != nil { return true }
        if let owning = tile.owningSettlement, game.colonies[owning] != nil { return true }
        return game.colonies.values.contains { $0.tileId == tile.id }
    }

    /// True when the tile is owned by a native (Indian) player.
    nonisolated static func tileIsNativeOwned(_ tile: Tile, in game: Game) -> Bool {
        let ownerId = tile.owner
            ?? tile.owningSettlement.flatMap { game.colonies[$0]?.owner }
        guard let ownerId else { return false }
        return game.players[ownerId]?.playerType == .indian
    }

    /// Founding eligibility, approximating the server's
    /// `Player.canClaimToFoundSettlement` rules: settleable terrain, no
    /// settlement on the tile (colony *or* native village), no native-owned
    /// land, and no settlement on an adjacent tile.
    nonisolated static func isBuildableColonyTile(_ tile: Tile, in game: Game) -> Bool {
        guard let type = tile.type?.lowercased() else { return false }
        let forbidden = ["ocean", "highseas", "lake", "arctic", "mountains"]
        guard !forbidden.contains(where: { type.contains($0) }) else { return false }

        // Reject tiles that already carry a settlement (another colony or a
        // native village), including when only a partial tile update was seen.
        if tileHasSettlement(tile, in: game) { return false }
        if tileIsNativeOwned(tile, in: game) { return false }

        // FreeCol founding rule: no settlement on the tile or an adjacent tile.
        for neighborId in game.neighborTileIds(of: tile.id) {
            if game.colonies.values.contains(where: { $0.tileId == neighborId }) {
                return false
            }
        }
        return true
    }

    private func isBuildableColonyTile(_ tile: Tile) -> Bool {
        guard let game = cachedGame else { return false }
        return Self.isBuildableColonyTile(tile, in: game)
    }

    private func startMessageLoop(client: FreeColClient, server: MockServer? = nil) {
        messageLoopTask = Task {
            await client.startMessageLoop()
        }
    }

    func handleUnexpectedDisconnect(error: Error?) {
        guard !userRequestedDisconnect,
              !usesLocalServer,
              let remoteHost,
              let remotePort,
              let localPlayerName,
              let localNationId,
              reconnectTask == nil else {
            if !userRequestedDisconnect {
                errorMessage = error.map { ServerErrorMessage.description(for: $0) }
                    ?? "Die Verbindung zum Server wurde getrennt."
            }
            return
        }

        errorMessage = nil
        phase = .reconnecting
        statusMessage = "Verbindung verloren. Wiederverbindung läuft …"
        reconnectTask = Task { [weak self] in
            guard let self else { return }
            for attempt in 1...5 {
                if Task.isCancelled { return }
                self.statusMessage = "Wiederverbindung (Versuch \(attempt)/5) …"
                if attempt > 1 {
                    try? await Task.sleep(nanoseconds: UInt64(attempt - 1) * 1_000_000_000)
                }
                if Task.isCancelled { return }
                do {
                    let newClient = FreeColClient(host: remoteHost, port: remotePort)
                    let newBridge = ClientBridge(gameState: self)
                    await newClient.setDelegate(newBridge)
                    try await newClient.connect()
                    self.vacantPlayers = await newClient.initialVacantPlayers
                    self.serverState = await newClient.initialGameState
                    let result = try await newClient.login(userName: localPlayerName, nationId: localNationId)
                    self.client = newClient
                    self.bridge = newBridge
                    self.cachedGame = await newClient.game
                    self.applyLoginResult(result)
                    self.statusMessage = "Wiederverbunden. Prüfe ausstehende Aktionen vor dem erneuten Senden."
                    self.reconnectTask = nil
                    self.startMessageLoop(client: newClient)
                    return
                } catch {
                    FreeColLogger.shared.info("Reconnect attempt \(attempt) failed: \(error)")
                }
            }
            self.reconnectTask = nil
            self.phase = .disconnected
            self.statusMessage = ""
            self.errorMessage = "Wiederverbindung nach fünf Versuchen fehlgeschlagen."
        }
    }

    func resendQueuedGameplayAction(_ action: QueuedGameplayAction) {
        guard phase == .inGame else { return }
        Task {
            do {
                try await sendCoreGameplayAction(action.message, queueIfDisconnected: false)
                queuedGameplayActions.removeAll { $0.id == action.id }
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    func discardQueuedGameplayAction(_ action: QueuedGameplayAction) {
        queuedGameplayActions.removeAll { $0.id == action.id }
    }

    private func makeGameXML() -> String {
        let startingMoney = gameOptions["model.option.startingMoney"] ?? "500"
        let mapWidth = gameOptions["model.option.mapWidth"] ?? "10"
        let mapHeight = gameOptions["model.option.mapHeight"] ?? "8"
        let nationId = self.localNationId ?? "model.nation.dutch"
        let userName = self.localPlayerName ?? "Player"
        
        return """
<game id="local-game" turn="1">
<freecol-specification>
<option id="model.option.startingMoney" value="\(startingMoney)"/>
<option id="model.option.mapWidth" value="\(mapWidth)"/>
<option id="model.option.mapHeight" value="\(mapHeight)"/>
</freecol-specification>
<player id="player-european" username="\(userName)" nationId="\(nationId)" gold="\(startingMoney)"/>
<player id="player-native-1" nationId="model.nation.iroquois" playerType="INDIAN"/>
<map id="map-0" width="\(mapWidth)" height="\(mapHeight)">
<tile id="tile-0-0" x="0" y="0" type="model.tile.ocean"/>
<tile id="tile-1-0" x="1" y="0" type="model.tile.ocean"/>
<tile id="tile-2-0" x="2" y="0" type="model.tile.ocean"/>
<tile id="tile-3-0" x="3" y="0" type="model.tile.plains"/>
<tile id="tile-4-0" x="4" y="0" type="model.tile.plains" owner="player-european"/>
<tile id="tile-0-1" x="0" y="1" type="model.tile.ocean"/>
<tile id="tile-1-1" x="1" y="1" type="model.tile.ocean"/>
<tile id="tile-2-1" x="2" y="1" type="model.tile.grassland"/>
<tile id="tile-3-1" x="3" y="1" type="model.tile.grassland" owner="player-european"/>
<tile id="tile-4-1" x="4" y="1" type="model.tile.grassland" owner="player-european"/>
<tile id="tile-0-2" x="0" y="2" type="model.tile.ocean"/>
<tile id="tile-1-2" x="1" y="2" type="model.tile.ocean"/>
<tile id="tile-2-2" x="2" y="2" type="model.tile.ocean"/>
<tile id="tile-3-2" x="3" y="2" type="model.tile.ocean"/>
<tile id="tile-4-2" x="4" y="2" type="model.tile.ocean"/>
<tile id="tile-0-3" x="0" y="3" type="model.tile.ocean"/>
<tile id="tile-1-3" x="1" y="3" type="model.tile.ocean"/>
<tile id="tile-2-3" x="2" y="3" type="model.tile.ocean"/>
<tile id="tile-3-3" x="3" y="3" type="model.tile.ocean"/>
<tile id="tile-4-3" x="4" y="3" type="model.tile.ocean"/>
</map>
<unit id="unit-caravel" owner="player-european" unitType="model.unit.caravel" location="tile-4-1" movesLeft="3" state="ACTIVE">
  <unit id="unit-veteran-soldier" owner="player-european" unitType="model.unit.veteranSoldier" location="unit-caravel" role="model.role.soldier" roleCount="1" state="SENTRY"/>
  <unit id="unit-hardy-pioneer" owner="player-european" unitType="model.unit.hardyPioneer" location="unit-caravel" role="model.role.pioneer" roleCount="1" state="SENTRY"/>
</unit>
<colony id="colony-amsterdam" name="Amsterdam" owner="player-european" tile="tile-4-0" settlementType="model.settlement.colony"/>
</game>
"""
}

private final class ClientBridge: ClientDelegate {
    weak var gameState: GameState?

    init(gameState: GameState) {
        self.gameState = gameState
    }

    nonisolated func clientDidConnect() {}

    nonisolated func clientDidLogin(_ result: LoginResult) {}

    nonisolated func clientDidReceiveGameState(_ parsed: ParsedMessage) {
        guard let gs = gameState else { return }
        Task { @MainActor in
            gs.applySessionMessage(parsed)
            gs.syncAfterModelUpdate()
            gs.recordMarketSnapshot()
            gs.gameUpdateID += 1
        }
    }

    nonisolated func clientDidDisconnect(error: Error?) {
        guard let gs = gameState else { return }
        Task { @MainActor in
            gs.handleUnexpectedDisconnect(error: error)
        }
    }

    nonisolated func clientDidUpdate() {
        guard let gs = gameState else { return }
        Task { @MainActor in
            gs.syncAfterModelUpdate()
            gs.recordMarketSnapshot()
            gs.gameUpdateID += 1
        }
    }
}
}

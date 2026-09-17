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
        case login
        case lobby
        case inGame

        var description: String {
            switch self {
            case .disconnected: return "Disconnected"
            case .connecting: return "Connecting…"
            case .login: return "Login"
            case .lobby: return "Lobby"
            case .inGame: return "In Game"
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

    struct PendingServerDecision {
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
            return "Fountain of Youth"
        case .indianDemand:
            return "Native Demand"
        case .lootCargo:
            return "Loot Cargo"
        case .firstContact:
            return "First Contact"
        case .monarchAction:
            return "Monarch"
        case .newLandName:
            return "Name New Land"
        case .newRegionName:
            return "Name New Region"
        case .nativeTrade:
            return "Native Trade"
        case .diplomacy:
            return "Diplomacy"
        case .foundingFather:
            return "Continental Congress"
        case .scoutReport:
            return "Scout Report"
        case .incite:
            return "Incite Natives"
        case .none:
            return ""
        }
    }

    var pendingDecisionSummary: String {
        guard let decision = pendingServerDecision else { return "" }
        switch decision.type {
        case .fountainOfYouth:
            return "Migrants to place: \(decision.migrantCount)"
        case .indianDemand:
            var parts: [String] = []
            if let type = decision.rawPayload["type"] { parts.append("demand: \(type)") }
            if let amount = decision.rawPayload["amount"] { parts.append("amount: \(amount)") }
            if let colony = decision.rawPayload["colony"] { parts.append("colony: \(colony)") }
            if let unit = decision.rawPayload["unit"] { parts.append("unit: \(unit)") }
            return parts.isEmpty ? "Native demand to review." : parts.joined(separator: ", ")
        case .lootCargo:
            var parts: [String] = []
            if let winner = decision.rawPayload["winner"] { parts.append("winner: \(winner)") }
            if let loser = decision.rawPayload["loser"] { parts.append("loser: \(loser)") }
            let goodsCount = decision.goodsChildren.count
            if goodsCount > 0 { parts.append("goods stacks: \(goodsCount)") }
            return parts.isEmpty ? "Cargo to assess." : parts.joined(separator: ", ")
        case .firstContact:
            var parts: [String] = []
            if let other = decision.rawPayload["other"] { parts.append("contact: \(other)") }
            if let camps = decision.rawPayload["camps"] { parts.append("camps: \(camps)") }
            if let tile = decision.rawPayload["tile"] { parts.append("tile: \(tile)") }
            return parts.isEmpty ? "A native people greets you." : parts.joined(separator: ", ")
        case .monarchAction:
            var parts: [String] = []
            if let action = decision.rawPayload["action"] { parts.append(prettyEnum(action)) }
            if let tax = decision.rawPayload["tax"] { parts.append("tax: \(tax)") }
            return parts.isEmpty ? "The monarch makes an offer." : parts.joined(separator: ", ")
        case .newLandName:
            if let unit = decision.rawPayload["unit"] { return "Unit: \(unit)" }
            return "Choose a name for the new land."
        case .newRegionName:
            var parts: [String] = []
            if let region = decision.rawPayload["region"] { parts.append("region: \(region)") }
            if let tile = decision.rawPayload["tile"] { parts.append("tile: \(tile)") }
            return parts.isEmpty ? "Choose a name for the new region." : parts.joined(separator: ", ")
        case .nativeTrade:
            let session = decision.nativeTradeSession
            let buy = session.settlementToUnit.filter { $0.priceIsValid }.count
            let sell = session.unitToSettlement.filter { $0.priceIsValid }.count
            return "Can buy \(buy), can sell \(sell)"
        case .diplomacy:
            guard let proposal = decision.diplomaticTradeProposal else {
                return "Diplomatic proposal to review."
            }
            let context = proposal.context ?? "DIPLOMATIC"
            return "\(context): \(proposal.clauses.count) clause(s)"
        case .foundingFather:
            let options = pendingFoundingFathers
            return options.isEmpty
                ? "Choose a founding father."
                : "\(options.count) candidate(s) available."
        case .scoutReport:
            return scoutReportText
        case .incite:
            guard let incite = pendingIncite else { return "Incite the natives?" }
            let enemy = incite.enemyName ?? incite.enemy
            return "Incite \(enemy) for \(incite.gold) gold."
        }
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
    static func foundingFatherLabel(_ id: String) -> String {
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
    private var messageLoopTask: Task<Void, Never>?
    private var localServerTask: Task<Void, Never>?
    private(set) var cachedGame: Game?
    var gameUpdateID: Int = 0
    var selectedUnitId: String?
    var selectedTileId: String?
    var isReadyToStart: Bool = false
    private var localPlayerName: String?
    private var cachedLocalPlayerId: String?
    private var localNationId: String?
    private var localNationTypeId: String?
    private var localColorValue: String?
    private var isEndingTurn: Bool = false
    private var pendingEndTurnTurn: Int?
    private var endTurnToken: Int = 0
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
    var showEuropePanel: Bool = false
    var showColonyPanel: Bool = false
    var showDebugPanel: Bool = false
    var requestedMapScrollTileId: String?
    /// Report currently selected in the report browser.
    var requestedReport: ReportKind?
    /// Settlement the user asked to find (center map on).
    var findSettlementQuery: String?

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
    func openEuropePanel() { showEuropePanel = true }
    func closeEuropePanel() { showEuropePanel = false }
    func openColonyPanel() { showColonyPanel = true }
    /// Select a colony by id (e.g. from a spy result) and open its panel.
    func openColonyPanel(colonyId: String) {
        guard let colony = cachedGame?.colonies[colonyId] else {
            showColonyPanel = true
            return
        }
        if let tileId = colony.tileId {
            selectedTileId = tileId
        }
        showColonyPanel = true
    }
    func closeColonyPanel() { showColonyPanel = false }
    func openDebugPanel() { showDebugPanel = true }
    func closeDebugPanel() { showDebugPanel = false }

    var isLocalPlayerAdmin: Bool {
        guard let game = cachedGame,
              let localPlayerId = resolveLocalPlayerId(),
              let player = game.players[localPlayerId] else {
            return false
        }
        return player.admin
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
              let localPlayerId = resolveLocalPlayerId() else {
            return []
        }
        return game.units.values
            .filter { $0.owner == localPlayerId && resolveUnitTileId($0, in: game) == nil }
            .sorted { $0.id < $1.id }
    }

    var europeCarrierUnits: [FreeColGame.Unit] {
        let carriers = europeUnits.filter { isCarrierUnit($0) }
        return carriers.isEmpty ? europeUnits : carriers
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

    /// Derived buy/sale prices for one goods type (Java `MarketData.price()`).
    func marketPrices(for goodsTypeId: String?) -> (costToBuy: Int, paidForSale: Int) {
        guard let game = cachedGame,
              let entry = localPlayer?.market?.entry(for: goodsTypeId) else {
            return (0, 0)
        }
        return MarketPricing.prices(for: entry, specification: game.specification)
    }

    // MARK: - Trade routes

    var localPlayerTradeRoutes: [TradeRoute] {
        guard let game = cachedGame,
              let localPlayerId = resolveLocalPlayerId() else {
            return []
        }
        return game.tradeRoutes(forPlayer: localPlayerId)
    }

    var canManageTradeRoutes: Bool {
        phase == .inGame && isLocalPlayersTurn
    }

    /// Owned colonies plus Europe, as candidate trade route stops.
    var tradeRouteStopCandidates: [(id: String, label: String)] {
        guard let game = cachedGame,
              let localPlayerId = resolveLocalPlayerId() else {
            return []
        }
        var result: [(id: String, label: String)] = []
        if let europeId = game.players[localPlayerId]?.europe?.id {
            result.append((id: europeId, label: "Europe"))
        }
        let colonies = game.colonies.values
            .filter { $0.owner == localPlayerId }
            .sorted { ($0.name ?? "") < ($1.name ?? "") }
            .map { (id: $0.id, label: $0.name ?? $0.id) }
        result.append(contentsOf: colonies)
        return result
    }

    /// Goods types offered for trade-route cargo selection.
    var tradeRouteGoodsTypes: [(id: String, label: String)] {
        guard let specification = cachedGame?.specification else { return [] }
        return specification.goodsTypes.values
            .sorted { ($0.name ?? $0.id) < ($1.name ?? $1.id) }
            .map { (id: $0.id, label: $0.name ?? $0.id) }
    }

    var canEndTurn: Bool {
        // Always available on the local player's turn, like the Java client.
        // Duplicate requests while one is in flight are blocked in `endTurn()`.
        phase == .inGame && isLocalPlayersTurn && !isGameEnded
    }

    /// True while the local player still has an active unit with moves left.
    var hasUnmovedLocalUnits: Bool {
        guard let game = cachedGame,
              let localPlayerId = resolveLocalPlayerId() else {
            return false
        }
        return game.units.values.contains { unit in
            unit.owner == localPlayerId
                && unit.state == .active
                && unit.movesLeft > 0
                && game.resolvedTileId(for: unit) != nil
        }
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
              unit.unitType?.localizedCaseInsensitiveContains("colonist") == true else {
            return false
        }
        guard game.colonies.first(where: { $0.value.tileId == loc }) == nil,
              let tile = game.tiles[loc],
              isBuildableColonyTile(tile) else {
            return false
        }
        return true
    }

    var canJoinSelectedColony: Bool {
        guard phase == .inGame,
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
              let game = cachedGame,
              let unitId = selectedUnitId,
              let unit = game.units[unitId],
              let localPlayerId = resolveLocalPlayerId(),
              unit.owner == localPlayerId,
              unit.state == .active,
              unit.movesLeft > 0,
              unit.location != nil,
              game.units[unit.location ?? ""] != nil else {
            return false
        }
        return true
    }

    var canDisbandSelectedUnit: Bool {
        guard phase == .inGame,
              isLocalPlayersTurn,
              let game = cachedGame,
              let unitId = selectedUnitId,
              let unit = game.units[unitId],
              let localPlayerId = resolveLocalPlayerId(),
              unit.owner == localPlayerId else {
            return false
        }
        // Avoid disbanding carriers that currently transport units.
        if game.units.values.contains(where: { $0.location == unit.id }) {
            return false
        }
        return true
    }

    var canSetDestinationToSelectedTile: Bool {
        guard let tileId = selectedTileId else { return false }
        return canSetSelectedUnitDestination(to: tileId)
    }

    var canClearSelectedUnitDestination: Bool {
        guard phase == .inGame,
              isLocalPlayersTurn,
              let game = cachedGame,
              let unitId = selectedUnitId,
              let unit = game.units[unitId],
              let localPlayerId = resolveLocalPlayerId(),
              unit.owner == localPlayerId else {
            return false
        }
        return unit.destination != nil
    }

    var canClearSelectedUnitTradeRoute: Bool {
        guard phase == .inGame,
              isLocalPlayersTurn,
              let game = cachedGame,
              let unitId = selectedUnitId,
              let unit = game.units[unitId],
              let localPlayerId = resolveLocalPlayerId(),
              unit.owner == localPlayerId else {
            return false
        }
        return unit.tradeRoute != nil
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
                $0.id != selectedUnit.id
                && $0.owner == localPlayerId
                && $0.location == selectedTile
                && isLikelyCarrier($0, in: game)
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
        let carrierTileId = resolveUnitTileId(carrier, in: game)
        return game.units.values
            .filter {
                $0.id != carrier.id
                && $0.owner == carrier.owner
                && ($0.location == carrier.id || (carrierTileId != nil && $0.location == carrierTileId))
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
        guard let game = cachedGame,
              let tileId = selectedTileId else {
            return nil
        }
        if let tile = game.tiles[tileId],
           let settlementId = tile.settlement,
           let colony = game.colonies[settlementId] {
            return colony
        }
        return game.colonies.values.first(where: { $0.tileId == tileId })
    }

    var selectedColonyUnits: [FreeColGame.Unit] {
        guard let game = cachedGame,
              let colony = selectedColony else {
            return []
        }
        let colonyId = colony.id
        let colonyTileId = colony.tileId
        return game.units.values
            .filter { unit in
                unit.location == colonyId || (colonyTileId != nil && unit.location == colonyTileId)
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
        guard let specification = cachedGame?.specification else { return [] }
        return specification.goodsTypes.values
            .map { (id: $0.id, label: goodsDisplayName($0.id)) }
            .sorted { $0.label < $1.label }
    }

    /// Work locations a colony worker can be assigned to (tiles + buildings).
    var selectedColonyWorkLocationCandidates: [(id: String, label: String)] {
        guard let colony = selectedColony else { return [] }
        var candidates: [(id: String, label: String)] = []
        for building in colony.buildings {
            let id = building.buildingType ?? building.id
            candidates.append((id: building.id, label: buildingDisplayName(id)))
        }
        for tile in colony.workTiles {
            let label = tile.tileId.map { "Tile \($0)" } ?? "Tile \(tile.id)"
            candidates.append((id: tile.id, label: label))
        }
        return candidates.sorted { $0.label < $1.label }
    }

    /// Building types the colony can start building now (spec-known, not yet
    /// built, population requirement met, and — for upgrades — the prerequisite
    /// building present). Approximation of the Java `BuildQueuePanel`.
    var selectedColonyBuildableCandidates: [(id: String, label: String)] {
        guard let colony = selectedColony,
              let specification = cachedGame?.specification else {
            return []
        }
        let population = max(colony.unitCount, selectedColonyUnits.count)
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
        return specification.buildingTypes.values
            .filter { info in
                guard !built.contains(info.id), info.requiredPopulation <= population else {
                    return false
                }
                if let upgradesFrom = info.upgradesFrom {
                    return built.contains(upgradesFrom)
                }
                return true
            }
            .map { info -> (id: String, label: String) in
                let cost = info.requiredGoods[buildingMaterialsGoodsId] ?? 0
                let label = cost > 0 ? "\(info.displayName) – \(cost)" : info.displayName
                return (id: info.id, label: label)
            }
            .sorted { $0.label < $1.label }
    }

    /// Buildings present in the selected colony with display names.
    var selectedColonyBuildings: [(id: String, label: String)] {
        guard let colony = selectedColony else { return [] }
        return colony.buildings
            .map { (id: $0.buildingType ?? $0.id, label: buildingDisplayName($0.buildingType ?? $0.id)) }
            .sorted { $0.label < $1.label }
    }

    /// Build queue of the selected colony, already known to the server.
    var selectedColonyBuildQueue: [String] {
        selectedColony?.buildQueue ?? []
    }

    /// Human-readable building name for a `model.building.*` id.
    func buildingDisplayName(_ typeId: String) -> String {
        if let info = cachedGame?.specification?.buildingTypes[typeId] {
            return info.displayName
        }
        return typeId.split(separator: ".").last.map(String.init) ?? typeId
    }

    /// Human-readable goods name for a `model.goods.*` id.
    func goodsDisplayName(_ typeId: String) -> String {
        if let name = cachedGame?.specification?.goodsTypes[typeId]?.name, !name.isEmpty {
            return name
        }
        return typeId.split(separator: ".").last.map(String.init) ?? typeId
    }

    /// Goods type used for construction progress (FreeCol "building materials").
    nonisolated static let buildingMaterialsGoodsId = "model.goods.hammers"

    /// Stored goods of the selected colony.
    var selectedColonyStoredGoods: [(id: String, label: String, amount: Int)] {
        guard let colony = selectedColony else { return [] }
        return colony.goods
            .map { (id: $0.key, label: goodsDisplayName($0.key), amount: $0.value) }
            .filter { $0.amount > 0 }
            .sorted { $0.label < $1.label }
    }

    /// First item of the selected colony build queue.
    var selectedColonyBuildTarget: (id: String, label: String)? {
        guard let first = selectedColony?.buildQueue.first else { return nil }
        return (id: first, label: buildingDisplayName(first))
    }

    /// Required vs. stored goods for the current build target.
    var selectedColonyBuildRequirements: [(id: String, label: String, required: Int, stored: Int)] {
        guard let colony = selectedColony,
              let target = selectedColonyBuildTarget,
              let info = cachedGame?.specification?.buildingTypes[target.id] else {
            return []
        }
        return info.requiredGoods
            .map { (id: $0.key,
                    label: goodsDisplayName($0.key),
                    required: $0.value,
                    stored: colony.goods[$0.key] ?? 0) }
            .sorted { $0.label < $1.label }
    }

    /// Estimated per-turn output of the construction goods from present buildings.
    var selectedColonyEstimatedBuildPerTurn: Int {
        guard let colony = selectedColony,
              let specification = cachedGame?.specification else {
            return 0
        }
        return Self.estimatedBuildPerTurn(colony: colony,
                                          specification: specification,
                                          centerTileType: centerTileType(of: colony))
    }

    /// Estimated turns until the current build target completes (nil if unknown).
    var selectedColonyEstimatedBuildTurns: Int? {
        guard let target = selectedColonyBuildTarget,
              let colony = selectedColony,
              let specification = cachedGame?.specification else {
            return nil
        }
        return Self.estimatedBuildTurns(colony: colony,
                                        buildableId: target.id,
                                        specification: specification,
                                        centerTileType: centerTileType(of: colony))
    }

    /// Estimate the construction-goods output per turn from present buildings.
    nonisolated static func estimatedBuildPerTurn(colony: Colony,
                                                   specification: Specification,
                                                   centerTileType: String? = nil) -> Int {
        estimatedProduction(colony: colony,
                            specification: specification,
                            centerTileType: centerTileType)
            .first { $0.id == buildingMaterialsGoodsId }?.amount ?? 0
    }

    /// Estimated net per-turn goods output from present buildings plus the
    /// colony-center tile (attended production preferred, unattended fallback).
    nonisolated static func estimatedProduction(colony: Colony,
                                                specification: Specification,
                                                centerTileType: String? = nil) -> [(id: String, amount: Int)] {
        var totals: [String: Int] = [:]
        for building in colony.buildings {
            guard let type = building.buildingType,
                  let info = specification.buildingTypes[type] else { continue }
            for (goods, value) in info.productionOutputs {
                totals[goods, default: 0] += value
            }
            for (goods, value) in info.productionInputs {
                totals[goods, default: 0] -= value
            }
        }
        // The colony center tile is always worked (unattended production).
        if let centerTileType, let tileInfo = specification.tileTypes[centerTileType] {
            for (goods, value) in tileInfo.centerOutputs {
                totals[goods, default: 0] += value
            }
            for (goods, value) in tileInfo.centerInputs {
                totals[goods, default: 0] -= value
            }
        }
        return totals
            .filter { $0.value != 0 }
            .map { (id: $0.key, amount: $0.value) }
    }

    /// Estimated net production of the selected colony, with display names.
    var selectedColonyEstimatedProduction: [(id: String, label: String, amount: Int)] {
        guard let colony = selectedColony,
              let specification = cachedGame?.specification else {
            return []
        }
        return Self.estimatedProduction(colony: colony,
                                        specification: specification,
                                        centerTileType: centerTileType(of: colony))
            .map { (id: $0.id, label: goodsDisplayName($0.id), amount: $0.amount) }
            .sorted { $0.label < $1.label }
    }

    private func centerTileType(of colony: Colony) -> String? {
        guard let tileId = colony.tileId else { return nil }
        return cachedGame?.tiles[tileId]?.type
    }

    /// Estimate the turns to complete a buildable, or nil when unknown.
    nonisolated static func estimatedBuildTurns(colony: Colony,
                                                buildableId: String,
                                                specification: Specification,
                                                centerTileType: String? = nil) -> Int? {
        guard let info = specification.buildingTypes[buildableId],
              !info.requiredGoods.isEmpty else {
            return nil
        }
        let material = buildingMaterialsGoodsId
        guard let required = info.requiredGoods[material] else { return nil }
        let remaining = required - (colony.goods[material] ?? 0)
        guard remaining > 0 else { return 0 }
        let perTurn = estimatedBuildPerTurn(colony: colony,
                                            specification: specification,
                                            centerTileType: centerTileType)
        guard perTurn > 0 else { return nil }
        return (remaining + perTurn - 1) / perTurn
    }

    var selectedColonyWorkerUnitId: String? {
        guard canManageSelectedColony else { return nil }
        if let unit = selectedUnit,
           selectedColonyUnits.contains(where: { $0.id == unit.id }) {
            return unit.id
        }
        return selectedColonyUnits.first?.id
    }

    var canPutSelectedColonyWorkerOutside: Bool {
        guard canManageSelectedColony,
              let colony = selectedColony,
              let colonyId = colony.id as String?,
              let unitId = selectedColonyWorkerUnitId,
              let game = cachedGame,
              let unit = game.units[unitId] else {
            return false
        }
        return unit.location == colonyId
    }

    var canAbandonSelectedColony: Bool {
        guard canManageSelectedColony else { return false }
        return selectedColonyUnits.isEmpty
    }

    var selectedColonyCarrierId: String? {
        guard canManageSelectedColony,
              let game = cachedGame,
              let localPlayerId = resolveLocalPlayerId() else {
            return nil
        }
        if let unit = selectedUnit,
           unit.owner == localPlayerId,
           isLikelyCarrier(unit, in: game) {
            return unit.id
        }
        return selectedColonyUnits.first(where: {
            $0.owner == localPlayerId && isLikelyCarrier($0, in: game)
        })?.id
    }

    var game: Game? { _ = gameUpdateID; return cachedGame }

    /// Install a game model directly (local play and tests) without a connection.
    func installGame(_ game: Game) {
        cachedGame = game
        gameUpdateID += 1
    }

    func startLocal(userName: String, nationId: String) {
        guard case .disconnected = phase else { return }
        FreeColLogger.shared.info("Starting local game: user=\(userName) nation=\(nationId)")
        resetSessionState()
        localPlayerName = userName
        phase = .connecting
        statusMessage = "Starting local server…"

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
                statusMessage = "Connected, logging in…"
                _ = try await client.login(userName: userName, nationId: nationId)
                cachedGame = await client.game
                if let game = cachedGame, game.currentPlayerId == nil {
                    // Local games have no server-side turn owner yet.
                    game.currentPlayerId = resolveLocalPlayerId()
                }

                // Make sure handshake completed
                _ = try await serverHandshake

                phase = .inGame
                statusMessage = ""
                startMessageLoop(client: client, server: server)
                startLocalServerLoop(server: server)
            } catch {
                FreeColLogger.shared.error("Local game failed: \(error)")
                errorMessage = error.localizedDescription
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

    func connect(host: String, port: Int) {
        guard case .disconnected = phase else { return }
        FreeColLogger.shared.info("Connecting to \(host):\(port)...")
        resetSessionState()
        phase = .connecting
        statusMessage = "Connecting to \(host):\(port)…"
        let client = FreeColClient(host: host, port: port)
        self.client = client
        let bridge = ClientBridge(gameState: self)
        self.bridge = bridge

        Task {
            await client.setDelegate(bridge)
            do {
                try await client.connect()
                // Capture initial handshake data from client after connection and handshake
                self.vacantPlayers = await client.initialVacantPlayers
                self.serverState = await client.initialGameState
                
                phase = .login
                statusMessage = "Connected"
            } catch {
                FreeColLogger.shared.error("Connection failed: \(error)")
                errorMessage = error.localizedDescription
                phase = .disconnected
                statusMessage = ""
            }
        }
    }

    func login(userName: String, nationId: String) {
        guard case .login = phase, let client = client else { return }
        FreeColLogger.shared.info("Logging in: user=\(userName) nation=\(nationId)")
        errorMessage = nil
        localPlayerName = userName
        phase = .connecting
        statusMessage = "Logging in…"

        Task {
            do {
                let result = try await client.login(userName: userName, nationId: nationId)
                cachedGame = await client.game
                applyLoginResult(result)
                statusMessage = ""
                startMessageLoop(client: client, server: nil)
            } catch {
                FreeColLogger.shared.error("Login failed: \(error)")
                errorMessage = error.localizedDescription
                phase = .login
                statusMessage = "Login failed"
            }
        }
    }

    func disconnect() {
        messageLoopTask?.cancel()
        messageLoopTask = nil
        localServerTask?.cancel()
        localServerTask = nil
        Task {
            await client?.disconnect()
            await server?.stop()
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
                    statusMessage = "Decision processed."
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
            statusMessage = "High scores received."
        case "nationSummary":
            nationSummaryReport = parsed
            statusMessage = "Nation summary received."
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
                statusMessage = "Decision processed."
                return
            }
            clearPendingDecision()
            pendingServerDecision = PendingServerDecision(
                type: .incite,
                rawPayload: parsed.attributes,
                children: parsed.children
            )
            statusMessage = "Incite confirmation pending."
        case "chooseFoundingFather":
            if isDecisionResponse(parsed) {
                clearPendingDecision()
                statusMessage = "Founding father chosen."
                return
            }
            clearPendingDecision()
            pendingServerDecision = PendingServerDecision(
                type: .foundingFather,
                rawPayload: parsed.attributes,
                children: parsed.children
            )
            statusMessage = "Choose a founding father."
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
                ? "You won the game!"
                : "Game ended. Winner: \(winner ?? "unknown")"
            pendingServerDecision = nil
        case "fountainOfYouth":
            if isDecisionResponse(parsed) {
                clearPendingDecision()
                statusMessage = "Decision processed."
                return
            }
            clearPendingDecision()
            pendingServerDecision = PendingServerDecision(
                type: .fountainOfYouth,
                rawPayload: parsed.attributes,
                children: parsed.children
            )
            statusMessage = "Fountain of youth: select emigrants."
        case "indianDemand":
            if isDecisionResponse(parsed) {
                clearPendingDecision()
                statusMessage = "Decision processed."
                return
            }
            clearPendingDecision()
            pendingServerDecision = PendingServerDecision(
                type: .indianDemand,
                rawPayload: parsed.attributes,
                children: parsed.children
            )
            statusMessage = "Native demand pending."
        case "lootCargo":
            if isDecisionResponse(parsed) {
                clearPendingDecision()
                statusMessage = "Decision processed."
                return
            }
            clearPendingDecision()
            pendingServerDecision = PendingServerDecision(
                type: .lootCargo,
                rawPayload: parsed.attributes,
                children: parsed.children
            )
            statusMessage = "Loot decision pending."
        case "logout":
            if parsed.attributes["player"] == resolveLocalPlayerId() {
                statusMessage = "Your session has ended."
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
        statusMessage = "Chat: \(senderName): \(message)"
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
            statusMessage = "Attack success: \(attacker) vs \(defender)"
        case .some(false):
            statusMessage = "Attack failed: \(attacker) vs \(defender)"
        case .none:
            statusMessage = "Attack animation: \(attacker) vs \(defender)"
        }
        errorMessage = nil
    }

    private func applyFirstContactMessage(_ parsed: ParsedMessage) {
        errorMessage = nil
        if let result = parsed.attributes["result"], !result.isEmpty {
            // Response echo: record it instead of opening a new prompt.
            statusMessage = "First contact resolved: result=\(result)"
            return
        }
        clearPendingDecision()
        pendingServerDecision = PendingServerDecision(
            type: .firstContact,
            rawPayload: parsed.attributes,
            children: parsed.children
        )
        statusMessage = "First contact: accept or decline."
    }

    private func applyMonarchActionMessage(_ parsed: ParsedMessage) {
        let action = parsed.attributes["action"] ?? ""
        // A result attribute means this is a response echo, not a new offer.
        if let result = parsed.attributes["result"], !result.isEmpty {
            statusMessage = "Monarch: \(prettyEnum(action)) (\(result))"
            return
        }
        // Announcement-only actions need no answer.
        if action == "no_action" || action == "displeasure" {
            statusMessage = "Monarch: \(prettyEnum(action))"
            return
        }
        clearPendingDecision()
        pendingServerDecision = PendingServerDecision(
            type: .monarchAction,
            rawPayload: parsed.attributes,
            children: parsed.children
        )
        statusMessage = "Monarch offer pending."
    }

    private func applyNamePrompt(_ parsed: ParsedMessage, type: PendingServerDecisionType) {
        if parsed.attributes["result"] != nil {
            clearPendingDecision()
            statusMessage = "Name submitted."
            return
        }
        clearPendingDecision()
        pendingServerDecision = PendingServerDecision(
            type: type,
            rawPayload: parsed.attributes,
            children: parsed.children
        )
        statusMessage = type == .newLandName ? "Name the new land." : "Name the new region."
    }

    private func applyCloseMessage(_ parsed: ParsedMessage) {
        let panel = parsed.attributes["panel"] ?? ""
        if matchesPendingPrompt(panel: panel) {
            clearPendingDecision()
            statusMessage = "Server closed the prompt."
        } else {
            statusMessage = "Server closed panel: \(panel)"
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
            statusMessage = "Spying on \(colony.name ?? settlementId)."
        } else {
            statusMessage = "Spy report: \(settlementId)"
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
            statusMessage = "Your nation has been defeated."
        } else {
            statusMessage = "Player eliminated: \(deadId)"
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
            statusMessage = "Options updated (\(options.count))."
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
            statusMessage = "Native trade open."
        case "ACK_BUY":
            mergeIntoPrompt()
            statusMessage = tradeItemStatus("Bought", session: pendingNativeTrade)
        case "ACK_SELL":
            mergeIntoPrompt()
            statusMessage = tradeItemStatus("Sold", session: pendingNativeTrade)
        case "ACK_GIFT":
            mergeIntoPrompt()
            statusMessage = "Gift accepted."
        case "ACK_BUY_HAGGLE", "ACK_SELL_HAGGLE":
            mergeIntoPrompt()
            if let item = pendingNativeTrade?.item {
                statusMessage = "Haggle: \(item.goodsType ?? "goods") now \(item.price) gold."
            } else {
                statusMessage = "Haggle counter-offer received."
            }
        case "CLOSE":
            clearPendingDecision()
            statusMessage = "Native trade closed."
        case "NAK_GOODS", "NAK_HAGGLE", "NAK_HOSTILE", "NAK_NOSALE", "NAK_INVALID":
            statusMessage = "Native trade declined: \(action)"
        default:
            // Includes a stray server-side OPEN echo.
            mergeIntoPrompt()
            statusMessage = "Native trade: \(action)"
        }
    }

    private func tradeItemStatus(_ verb: String, session: NativeTradeSession?) -> String {
        guard let item = session?.item else { return "\(verb)." }
        return "\(verb) \(item.goodsType ?? "goods") x\(item.amount) for \(item.price) gold."
    }

    private func applyDiplomacyMessage(_ parsed: ParsedMessage) {
        guard let tradeNode = parsed.children.first(where: { $0.tag == "diplomaticTrade" }) else {
            statusMessage = "Diplomacy message without agreement."
            return
        }
        errorMessage = nil
        let proposal = DiplomaticTradeProposal(raw: tradeNode)
        switch proposal.status {
        case "ACCEPT_TRADE":
            clearPendingDecision()
            statusMessage = "Diplomacy: offer accepted."
        case "REJECT_TRADE":
            clearPendingDecision()
            statusMessage = "Diplomacy: offer rejected."
        default:
            clearPendingDecision()
            pendingServerDecision = PendingServerDecision(
                type: .diplomacy,
                rawPayload: parsed.attributes,
                children: [tradeNode]
            )
            statusMessage = "Diplomacy: proposal pending."
        }
    }

    private func applyMissionaryMessage(_ parsed: ParsedMessage) {
        let unit = parsed.attributes["unit"] ?? "unknown"
        let direction = parsed.attributes["direction"] ?? "unknown"
        let denounce = parsed.attributes["denounce"] ?? "false"
        errorMessage = nil
        statusMessage = "Missionary prompt: unit=\(unit) direction=\(direction) denounce=\(denounce)"
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
        statusMessage = "Incite declined."
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
        guard phase == .inGame, isLocalPlayersTurn, selectedUnit != nil else { return false }
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
        guard phase == .inGame, isLocalPlayersTurn, let unitId = selectedUnitId else {
            errorMessage = "Kein Handel möglich."
            return
        }
        guard !settlementId.isEmpty else {
            errorMessage = "Siedlung erforderlich."
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
        statusMessage = "Native trade closed."
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
            errorMessage = "Client is not connected."
            return
        }
        Task {
            do {
                try await client.send(message: message)
            } catch {
                errorMessage = error.localizedDescription
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
            errorMessage = "Client is not connected."
            return
        }

        var attributes = proposal.raw.attributes
        attributes["status"] = accept ? "ACCEPT_TRADE" : "REJECT_TRADE"
        let tradeNode = ParsedMessage(
            tag: "diplomaticTrade",
            attributes: attributes,
            children: proposal.raw.children
        )
        let ourId = decision.rawPayload["ourId"] ?? proposal.sender ?? resolveLocalPlayerId() ?? ""
        let otherId = decision.rawPayload["otherId"] ?? proposal.recipient ?? ""
        let message = ParsedMessage(
            tag: "diplomacy",
            attributes: ["ourId": ourId, "otherId": otherId],
            children: [tradeNode]
        )
        errorMessage = nil
        Task {
            do {
                _ = try await client.ask(message: message)
                clearPendingDecision()
                statusMessage = accept ? "Diplomacy accepted." : "Diplomacy rejected."
            } catch {
                errorMessage = error.localizedDescription
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
        let ourId = decision.rawPayload["ourId"] ?? resolveLocalPlayerId() ?? ""
        let otherId = decision.rawPayload["otherId"] ?? ""
        guard !ourId.isEmpty, !otherId.isEmpty else {
            errorMessage = "Diplomatie-Objekte fehlen."
            return
        }

        var attributes = proposal.raw.attributes
        attributes["status"] = "PROPOSE_TRADE"
        attributes["version"] = String(proposal.version + 1)
        let children = drafts.map { Self.diplomacyClauseNode($0, ourId: ourId, otherId: otherId) }
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
                clearPendingDecision()
                statusMessage = "Gegenangebot gesendet."
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Draft clauses pre-populated from the pending proposal.
    var pendingDiplomacyDrafts: [DiplomaticClauseDraft] {
        guard let decision = pendingServerDecision,
              let proposal = decision.diplomaticTradeProposal else {
            return []
        }
        let ourId = decision.rawPayload["ourId"] ?? resolveLocalPlayerId() ?? ""
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
            errorMessage = "Client is not connected."
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
                    statusMessage = "Emigrant placed. \(remaining) remaining."
                } else {
                    clearPendingDecision()
                    statusMessage = "Emigrants placed."
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func sendDecision(tag: String, attributes: [String: String], children: [ParsedMessage]) {
        guard let client else {
            errorMessage = "Client is not connected."
            return
        }
        Task {
            do {
                _ = try await client.ask(
                    message: ParsedMessage(tag: tag, attributes: attributes, children: children)
                )
                clearPendingDecision()
                statusMessage = "Decision sent."
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func resolveLocalPlayerId() -> String? {
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
        phase = state == .inGame ? .inGame : .lobby
        if phase != .inGame {
            clearPendingEndTurn()
        }
        statusMessage = state == .inGame ? "" : "Waiting for game start…"
    }

    private func resetSessionState() {
        errorMessage = nil
        vacantPlayers = nil
        serverState = nil
        cachedGame = nil
        gameUpdateID = 0
        selectedUnitId = nil
        selectedTileId = nil
        isReadyToStart = false
        localPlayerName = nil
        cachedLocalPlayerId = nil
        localNationId = nil
        localNationTypeId = nil
        localColorValue = nil
        isEndingTurn = false
        pendingEndTurnTurn = nil
        incomingChatLog = []
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
                errorMessage = error.localizedDescription
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
                errorMessage = error.localizedDescription
            }
        }
    }

    func setLocalPlayerNation(_ nationId: String) {
        guard phase == .lobby else { return }
        let trimmedNationId = nationId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNationId.isEmpty else {
            errorMessage = "Bitte eine Nation waehlen."
            return
        }
        guard let playerId = resolveLocalPlayerId() else {
            errorMessage = "Lokaler Spieler konnte nicht bestimmt werden."
            return
        }

        errorMessage = nil
        let previousNationId = localNationId
        localNationId = trimmedNationId

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
                errorMessage = error.localizedDescription
            }
        }
    }

    func setLocalPlayerNationType(_ nationTypeId: String) {
        guard phase == .lobby else { return }
        let trimmedNationTypeId = nationTypeId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNationTypeId.isEmpty else {
            errorMessage = "Bitte einen NationType angeben."
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
                errorMessage = error.localizedDescription
            }
        }
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
                errorMessage = error.localizedDescription
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
                errorMessage = error.localizedDescription
            }
        }
    }

    func updateSingleMapGeneratorOption(id optionId: String, value optionValue: String) {
        guard phase == .lobby else { return }
        let trimmedOptionId = optionId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedOptionValue = optionValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedOptionId.isEmpty else {
            errorMessage = "Bitte eine Map-Option-ID angeben."
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
                errorMessage = error.localizedDescription
            }
        }
    }

    func chooseFoundingFather(_ foundingFatherId: String) {
        guard phase == .lobby || phase == .inGame else { return }
        let trimmedFoundingFatherId = foundingFatherId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedFoundingFatherId.isEmpty else {
            errorMessage = "Bitte eine FoundingFather-ID angeben."
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
                errorMessage = error.localizedDescription
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
                errorMessage = error.localizedDescription
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
                errorMessage = error.localizedDescription
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
                errorMessage = error.localizedDescription
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
                errorMessage = error.localizedDescription
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
                errorMessage = error.localizedDescription
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
                errorMessage = error.localizedDescription
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
                errorMessage = error.localizedDescription
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
                errorMessage = error.localizedDescription
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
                errorMessage = error.localizedDescription
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
                errorMessage = error.localizedDescription
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
                errorMessage = error.localizedDescription
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
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Set while the end-turn confirmation dialog lists units without orders.
    var showEndTurnDialog: Bool = false

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

    func endTurn() {
        guard phase == .inGame else {
            errorMessage = "Aktion nur im laufenden Spiel verfuegbar."
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

        Task {
            do {
                let msg = ParsedMessage(tag: "endTurn", attributes: [:], children: [])
                try await client?.send(message: msg)
            } catch {
                clearPendingEndTurn()
                errorMessage = error.localizedDescription
            }
        }

        // Safety net: if the server never confirms (no turn/current-player
        // update), release the lock after a while so the player can retry
        // instead of being stuck with a permanently disabled button.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            guard token == self.endTurnToken, self.isEndingTurn else { return }
            self.clearPendingEndTurn()
            self.statusMessage = "Zugende nicht bestätigt – bitte erneut versuchen."
        }
    }

    func selectUnit(_ unitId: String?, onTile tileId: String?) {
        selectedUnitId = unitId
        selectedTileId = tileId
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
        guard canMoveSelectedUnit(to: destinationTileId),
              let unitId = selectedUnitId,
              let unit = cachedGame?.units[unitId],
              let game = cachedGame else {
            errorMessage = "Ungueltige Bewegung."
            return
        }
        guard let sourceTileId = resolveUnitTileId(unit, in: game),
              let dir = attackDirection(fromTileId: sourceTileId, toTileId: destinationTileId, in: game) else {
            errorMessage = "Ziel nicht benachbart."
            return
        }
        errorMessage = nil
        Task {
            do {
                let msg = ParsedMessage(
                    tag: "move",
                    attributes: ["direction": dir, "unit": unitId],
                    children: []
                )
                // For local games (MockServer), directly update the game model.
                if server != nil {
                    game.moveUnit(unitId, to: destinationTileId)
                    reconcileSelectionWithGame()
                    gameUpdateID += 1
                }
                try await client?.send(message: msg)
                selectUnit(unitId, onTile: destinationTileId)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func canMoveSelectedUnitTo(destinationTileId: String) -> Bool {
        guard phase == .inGame,
              isLocalPlayersTurn,
              let game = cachedGame,
              let unitId = selectedUnitId,
              let unit = game.units[unitId],
              let localPlayerId = resolveLocalPlayerId(),
              unit.owner == localPlayerId,
              unit.movesLeft > 0,
              unit.state == .active,
              let sourceTileId = resolveUnitTileId(unit, in: game),
              sourceTileId != destinationTileId,
              game.tiles[destinationTileId] != nil else {
            return false
        }
        return true
    }

    func moveSelectedUnitTo(destinationTileId: String) {
        guard canMoveSelectedUnitTo(destinationTileId: destinationTileId),
              let unitId = selectedUnitId,
              let unit = cachedGame?.units[unitId],
              let game = cachedGame else {
            errorMessage = "Ziel kann nicht erreicht werden."
            return
        }
        // Adjacent target: regular one-step move.
        if canMoveSelectedUnit(to: destinationTileId) {
            moveSelectedUnit(to: destinationTileId)
            return
        }
        // Distant target: take one legal step along the shortest known path.
        guard let nextStepTileId = nextStepTowardDestination(for: unit, destinationTileId: destinationTileId, in: game) else {
            errorMessage = "Kein gueltiger Schritt zum Ziel verfuegbar."
            return
        }
        errorMessage = nil

        moveSelectedUnit(to: nextStepTileId)
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
                try await client?.send(message: msg)
                // Keep the colony tile focused after founding so the new colony panel appears.
                if let tileId = colonyTileId ?? selectedTileId {
                    selectUnit(nil, onTile: tileId)
                } else {
                    selectUnit(nil, onTile: nil)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func joinSelectedColony() {
        guard canJoinSelectedColony,
              let unitId = selectedUnitId,
              let tileId = selectedTileId,
              let game = cachedGame,
              let colony = game.colonies.values.first(where: { $0.tileId == tileId }) else {
            errorMessage = "Eintritt in Kolonie nicht moeglich."
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
                errorMessage = error.localizedDescription
            }
        }
    }

    func canEmbarkSelectedUnit(onCarrier carrierId: String) -> Bool {
        guard phase == .inGame,
              isLocalPlayersTurn,
              let game = cachedGame,
              let unitId = selectedUnitId,
              let unit = game.units[unitId],
              let carrier = game.units[carrierId],
              let localPlayerId = resolveLocalPlayerId(),
              unit.owner == localPlayerId,
              carrier.owner == localPlayerId,
              unit.state == .active,
              unit.movesLeft > 0,
              let unitLoc = unit.location,
              let carrierLoc = carrier.location,
              unitLoc == carrierLoc,
                            unit.id != carrier.id,
                            isLikelyCarrier(carrier, in: game) else {
            return false
        }
        return true
    }

    func embarkSelectedUnit(onCarrier carrierId: String) {
        guard canEmbarkSelectedUnit(onCarrier: carrierId),
              let unitId = selectedUnitId,
              let game = cachedGame else {
            errorMessage = "Einschiffen nicht moeglich."
            return
        }
        errorMessage = nil


        Task {
            do {
                let msg = ParsedMessage(
                    tag: "embark",
                    attributes: ["unit": unitId, "carrier": carrierId],
                    children: []
                )
                if server != nil {
                    game.embarkUnit(unitId: unitId, carrierId: carrierId)
                    reconcileSelectionWithGame()
                    gameUpdateID += 1
                }
                try await client?.send(message: msg)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func disembarkSelectedUnit() {
        guard canDisembarkSelectedUnit,
              let unitId = selectedUnitId,
              let game = cachedGame else {
            errorMessage = "Ausschiffen nicht moeglich."
            return
        }
        errorMessage = nil


        Task {
            do {
                let msg = ParsedMessage(
                    tag: "disembark",
                    attributes: ["unit": unitId],
                    children: []
                )
                if server != nil {
                    game.disembarkUnit(unitId: unitId)
                    reconcileSelectionWithGame()
                    gameUpdateID += 1
                }
                try await client?.send(message: msg)
            } catch {
                errorMessage = error.localizedDescription
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
                errorMessage = error.localizedDescription
            }
        }
    }

    func canSetSelectedUnitDestination(to destinationTileId: String) -> Bool {
        guard phase == .inGame,
              isLocalPlayersTurn,
              let game = cachedGame,
              let unitId = selectedUnitId,
              let unit = game.units[unitId],
              let localPlayerId = resolveLocalPlayerId(),
              unit.owner == localPlayerId,
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
        errorMessage = nil


        Task {
            do {
                let msg = ParsedMessage(
                    tag: "setDestination",
                    attributes: ["unit": unitId, "destination": destinationTileId],
                    children: []
                )
                if server != nil {
                    game.setUnitDestination(unitId: unitId, destinationId: destinationTileId)
                    gameUpdateID += 1
                }
                try await client?.send(message: msg)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func clearSelectedUnitDestination() {
        guard canClearSelectedUnitDestination,
              let unitId = selectedUnitId,
              let game = cachedGame else {
            errorMessage = "Kein Ziel zum Entfernen gesetzt."
            return
        }
        errorMessage = nil


        Task {
            do {
                let msg = ParsedMessage(
                    tag: "setDestination",
                    attributes: ["unit": unitId],
                    children: []
                )
                if server != nil {
                    game.setUnitDestination(unitId: unitId, destinationId: nil)
                    gameUpdateID += 1
                }
                try await client?.send(message: msg)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: Phase 56 - unit orders

    /// True when the selected unit has any orders that can be cleared.
    var canClearSelectedUnitOrders: Bool {
        guard phase == .inGame,
              isLocalPlayersTurn,
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
        errorMessage = nil
        Task {
            do {
                if game.units[unitId]?.destination != nil {
                    try await client?.send(message: ParsedMessage(
                        tag: "setDestination", attributes: ["unit": unitId], children: []))
                    if server != nil {
                        game.setUnitDestination(unitId: unitId, destinationId: nil)
                    }
                }
                if game.units[unitId]?.state != .active {
                    try await client?.send(message: ParsedMessage(
                        tag: "changeState",
                        attributes: ["unit": unitId, "state": UnitState.active.rawValue],
                        children: []))
                    if server != nil {
                        game.changeUnitState(unitId: unitId, state: .active)
                    }
                }
                if server != nil {
                    reconcileSelectionWithGame()
                    gameUpdateID += 1
                }
                statusMessage = "Orders cleared."
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Local units that still have movement or are active this turn.
    var selectableLocalUnits: [FreeColGame.Unit] {
        guard let game = cachedGame,
              let localPlayerId = resolveLocalPlayerId() else { return [] }
        return game.units.values
            .filter { $0.owner == localPlayerId }
            .sorted { $0.id < $1.id }
    }

    /// Units the player has not given an order to yet (Java `EndTurnDialog`).
    var unitsAwaitingOrders: [FreeColGame.Unit] {
        guard let game = cachedGame else { return [] }
        return selectableLocalUnits.filter {
            $0.movesLeft > 0 && $0.state == .active && game.resolvedTileId(for: $0) != nil
        }
    }

    /// Cycle to the next (`forward`) or previous local unit.
    func selectAdjacentUnit(forward: Bool, onlyAwaitingOrders: Bool = false) {
        let units = onlyAwaitingOrders ? unitsAwaitingOrders : selectableLocalUnits
        guard !units.isEmpty, let game = cachedGame else { return }
        let target: FreeColGame.Unit
        if let currentId = selectedUnitId, let index = units.firstIndex(where: { $0.id == currentId }) {
            let offset = forward ? 1 : units.count - 1
            target = units[(index + offset) % units.count]
        } else {
            target = units[0]
        }
        let tileId = target.location.flatMap { game.tiles[$0] != nil ? $0 : nil }
        selectUnit(target.id, onTile: tileId)
    }

    func selectNextUnit() { selectAdjacentUnit(forward: true) }
    func selectPreviousUnit() { selectAdjacentUnit(forward: false) }

    /// A naval unit on a tile can be sent to Europe via server high-seas routing.
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
              game.tiles[tileId] != nil,
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
            errorMessage = "Reise nach Europa nicht moeglich."
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
                try await client?.send(message: msg)
                statusMessage = "Segelt nach Europa."
            } catch {
                errorMessage = error.localizedDescription
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
        guard let specification = cachedGame?.specification else { return [] }
        return specification.improvementTypes.values
            .filter { !$0.isNatural }
            .map { (id: $0.id, label: $0.displayName) }
            .sorted { $0.label < $1.label }
    }

    var canChangeSelectedUnitWorkImprovement: Bool {
        guard phase == .inGame,
              isLocalPlayersTurn,
              let game = cachedGame,
              let unitId = selectedUnitId,
              let unit = game.units[unitId],
              let localPlayerId = resolveLocalPlayerId(),
              unit.owner == localPlayerId,
              unit.movesLeft > 0 else {
            return false
        }
        return resolveUnitTileId(unit, in: game) != nil
    }

    /// Order the selected pioneer to build a tile improvement on its tile.
    func changeSelectedUnitWorkImprovement(_ improvementTypeId: String) {
        let trimmed = improvementTypeId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Bitte einen Improvement-Typ waehlen."
            return
        }
        guard canChangeSelectedUnitWorkImprovement,
              let unitId = selectedUnitId,
              let game = cachedGame else {
            errorMessage = "Verbesserung nicht moeglich."
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
                errorMessage = error.localizedDescription
            }
        }
    }

    func canAssignSelectedUnitTradeRoute(_ tradeRouteId: String) -> Bool {
        let trimmed = tradeRouteId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              phase == .inGame,
              isLocalPlayersTurn,
              let game = cachedGame,
              let unitId = selectedUnitId,
              let unit = game.units[unitId],
              let localPlayerId = resolveLocalPlayerId(),
              unit.owner == localPlayerId else {
            return false
        }
        return unit.tradeRoute != trimmed
    }

    func assignSelectedUnitTradeRoute(_ tradeRouteId: String) {
        let trimmed = tradeRouteId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canAssignSelectedUnitTradeRoute(trimmed),
              let unitId = selectedUnitId,
              let game = cachedGame else {
            errorMessage = "Handelsroute kann nicht zugewiesen werden."
            return
        }
        errorMessage = nil


        Task {
            do {
                let msg = ParsedMessage(
                    tag: "assignTradeRoute",
                    attributes: ["unit": unitId, "tradeRoute": trimmed],
                    children: []
                )
                if server != nil {
                    game.setUnitTradeRoute(unitId: unitId, tradeRouteId: trimmed)
                    gameUpdateID += 1
                }
                try await client?.send(message: msg)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func clearSelectedUnitTradeRoute() {
        guard canClearSelectedUnitTradeRoute,
              let unitId = selectedUnitId,
              let game = cachedGame else {
            errorMessage = "Keine Handelsroute zum Entfernen gesetzt."
            return
        }
        errorMessage = nil


        Task {
            do {
                let msg = ParsedMessage(
                    tag: "assignTradeRoute",
                    attributes: ["unit": unitId],
                    children: []
                )
                if server != nil {
                    game.setUnitTradeRoute(unitId: unitId, tradeRouteId: nil)
                    gameUpdateID += 1
                }
                try await client?.send(message: msg)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Trade route editing

    func createTradeRoute() {
        guard canManageTradeRoutes else {
            errorMessage = "Handelsrouten können nur im eigenen Zug verwaltet werden."
            return
        }
        errorMessage = nil
        Task {
            do {
                let msg = ParsedMessage(tag: "newTradeRoute", attributes: [:], children: [])
                try await client?.send(message: msg)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func saveTradeRoute(_ route: TradeRoute) {
        guard canManageTradeRoutes,
              let game = cachedGame,
              route.owner != nil else {
            errorMessage = "Handelsroute kann nicht gespeichert werden."
            return
        }
        let trimmed = (route.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Handelsroute braucht einen Namen."
            return
        }
        errorMessage = nil

        var updated = route
        updated.name = trimmed
        let msg = Self.tradeRouteMessage(tag: "updateTradeRoute", route: updated)

        Task {
            do {
                if server != nil {
                    game.addTradeRoute(updated)
                    gameUpdateID += 1
                }
                try await client?.send(message: msg)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func deleteTradeRoute(_ tradeRouteId: String) {
        guard canManageTradeRoutes,
              let game = cachedGame,
              game.tradeRoutes[tradeRouteId] != nil else {
            errorMessage = "Handelsroute kann nicht gelöscht werden."
            return
        }
        errorMessage = nil

        Task {
            do {
                let msg = ParsedMessage(
                    tag: "deleteTradeRoute",
                    attributes: ["tradeRoute": tradeRouteId],
                    children: []
                )
                if server != nil {
                    game.removeTradeRoute(tradeRouteId)
                    gameUpdateID += 1
                }
                try await client?.send(message: msg)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Serialize a `<tradeRoute>` object for `updateTradeRoute` requests.
    nonisolated static func tradeRouteMessage(tag: String, route: TradeRoute) -> ParsedMessage {
        let stops: [ParsedMessage] = route.stops.map { stop in
            var attributes: Attributes = [:]
            if let locationId = stop.locationId { attributes["location"] = locationId }
            let cargo = stop.cargoTypeIds.map {
                ParsedMessage(tag: "cargo", attributes: ["id": $0], children: [])
            }
            return ParsedMessage(tag: "tradeRouteStop", attributes: attributes, children: cargo)
        }
        var routeAttributes: Attributes = ["id": route.id]
        if let name = route.name { routeAttributes["name"] = name }
        if let owner = route.owner { routeAttributes["owner"] = owner }
        routeAttributes["silent"] = route.silent ? "true" : "false"
        let routeChild = ParsedMessage(tag: "tradeRoute", attributes: routeAttributes, children: stops)
        return ParsedMessage(tag: tag, attributes: [:], children: [routeChild])
    }

    func setSelectedUnitCurrentStop(_ indexText: String) {
        guard phase == .inGame,
              isLocalPlayersTurn,
              let game = cachedGame,
              let unitId = selectedUnitId,
              let unit = game.units[unitId],
              let localPlayerId = resolveLocalPlayerId(),
              unit.owner == localPlayerId else {
            errorMessage = "Aktueller Stop kann nicht gesetzt werden."
            return
        }
        let trimmed = indexText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let index = Int(trimmed), index >= 0 else {
            errorMessage = "Bitte einen gueltigen Stop-Index eingeben."
            return
        }
        guard unit.currentStop != index else {
            errorMessage = "Stop ist bereits gesetzt."
            return
        }
        errorMessage = nil


        Task {
            do {
                let msg = ParsedMessage(
                    tag: "setCurrentStop",
                    attributes: ["unit": unitId, "index": String(index)],
                    children: []
                )
                if server != nil {
                    game.setUnitCurrentStop(unitId: unitId, index: index)
                    gameUpdateID += 1
                }
                try await client?.send(message: msg)
            } catch {
                errorMessage = error.localizedDescription
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
                errorMessage = error.localizedDescription
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
            errorMessage = "Statuswechsel nicht moeglich."
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
                errorMessage = error.localizedDescription
            }
        }
    }

    func changeSelectedColonyWorkerWorkType(_ workTypeId: String) {
        let trimmed = workTypeId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Bitte eine WorkType ID eingeben."
            return
        }
        guard canManageSelectedColony,
              let unitId = selectedColonyWorkerUnitId,
              let game = cachedGame else {
            errorMessage = "WorkType-Wechsel nicht moeglich."
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
                try await client?.send(message: msg)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func changeSelectedColonyWorkerWorkImprovementType(_ improvementTypeId: String) {
        let trimmed = improvementTypeId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Bitte eine ImprovementType ID eingeben."
            return
        }
        guard canManageSelectedColony,
              let unitId = selectedColonyWorkerUnitId,
              let game = cachedGame else {
            errorMessage = "ImprovementType-Wechsel nicht moeglich."
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
                errorMessage = error.localizedDescription
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
                errorMessage = error.localizedDescription
            }
        }
    }

    func assignTeacherToSelectedColonyWorker(_ teacherId: String) {
        let trimmed = teacherId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Bitte eine Teacher-ID eingeben."
            return
        }
        guard canManageSelectedColony,
              let studentId = selectedColonyWorkerUnitId,
              let game = cachedGame,
              let teacher = game.units[trimmed],
              let localPlayerId = resolveLocalPlayerId(),
              teacher.owner == localPlayerId,
              selectedColonyUnits.contains(where: { $0.id == trimmed }),
              studentId != trimmed else {
            errorMessage = "Teacher-Zuweisung nicht moeglich."
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
                errorMessage = error.localizedDescription
            }
        }
    }

    func clearTeacherForSelectedColonyWorker() {
        guard canManageSelectedColony,
              let studentId = selectedColonyWorkerUnitId,
              let game = cachedGame else {
            errorMessage = "Teacher kann nicht entfernt werden."
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
                errorMessage = error.localizedDescription
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
                errorMessage = error.localizedDescription
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
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Assign the selected colony worker to a work location. If another worker
    /// already occupies the target, the two are swapped. Uses `rearrangeColony`
    /// so the server can resolve capacity and swaps atomically.
    func assignSelectedColonyWorker(to workLocationId: String) {
        let trimmed = workLocationId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Bitte eine Work Location auswaehlen."
            return
        }
        guard canManageSelectedColony,
              let colony = selectedColony,
              let game = cachedGame,
              let unitId = selectedColonyWorkerUnitId,
              let unit = game.units[unitId] else {
            errorMessage = "Work-Zuweisung nicht moeglich."
            return
        }
        guard unit.location != trimmed else {
            errorMessage = "Einheit arbeitet bereits dort."
            return
        }
        errorMessage = nil

        // Build the arrangement list: the target's occupant (if any) swaps to
        // the unit's previous location, then the unit moves to the target.
        var arrangements: [(unit: String, loc: String, work: String?, role: String?, count: Int)] = []
        let previousLocation = unit.location ?? colony.tileId ?? colony.id
        if let occupant = selectedColonyUnits.first(where: {
            $0.id != unitId && $0.location == trimmed
        }) {
            arrangements.append((
                unit: occupant.id,
                loc: previousLocation,
                work: occupant.workType,
                role: occupant.role ?? "model.role.default",
                count: occupant.roleCount
            ))
        }
        arrangements.append((
            unit: unitId,
            loc: trimmed,
            work: unit.workType,
            role: unit.role ?? "model.role.default",
            count: unit.roleCount
        ))

        Task {
            do {
                let msg = Self.rearrangeColonyMessage(colonyId: colony.id,
                                                      arrangements: arrangements)
                if server != nil {
                    for arrangement in arrangements {
                        game.setUnitWorkLocation(unitId: arrangement.unit,
                                                 workLocationId: arrangement.loc)
                    }
                    gameUpdateID += 1
                }
                try await client?.send(message: msg)
            } catch {
                errorMessage = error.localizedDescription
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
                try await client?.send(message: msg)
            } catch {
                errorMessage = error.localizedDescription
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
                errorMessage = error.localizedDescription
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
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Set the custom-house export settings for one goods type.
    func setSelectedColonyGoodsLevel(_ data: ColonyExportData) {
        guard canManageSelectedColony,
              let colony = selectedColony else {
            errorMessage = "Goods-Levels koennen nicht gesetzt werden."
            return
        }
        guard !data.goodsType.isEmpty else {
            errorMessage = "Goods Type erforderlich."
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
                errorMessage = error.localizedDescription
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
        let price = localPlayer?.europe?.price(for: trimmed) ?? 0
        if trimmed.localizedCaseInsensitiveContains("colonist") {
            purchasesRecruits += 1
        } else {
            purchasesTrained += 1
        }
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
                errorMessage = error.localizedDescription
            }
        }
    }

    func loadGoodsForSelectedColony(typeId: String, amount: Int) {
        let trimmedType = typeId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedType.isEmpty else {
            errorMessage = "Bitte einen Goods Type angeben."
            return
        }
        guard amount > 0 else {
            errorMessage = "Menge muss groesser als 0 sein."
            return
        }
        guard canManageSelectedColony,
              let colony = selectedColony,
              let carrierId = selectedColonyCarrierId else {
            errorMessage = "Goods laden nicht moeglich."
            return
        }
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
                try await client?.send(message: msg)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func unloadGoodsFromSelectedCarrier(typeId: String, amount: Int) {
        let trimmedType = typeId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedType.isEmpty else {
            errorMessage = "Bitte einen Goods Type angeben."
            return
        }
        guard amount > 0 else {
            errorMessage = "Menge muss groesser als 0 sein."
            return
        }
        guard canManageSelectedColony,
              let carrierId = selectedColonyCarrierId else {
            errorMessage = "Goods entladen nicht moeglich."
            return
        }
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
                try await client?.send(message: msg)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func buyGoodsInEurope(goodsTypeId: String, amount: Int, carrierId: String) {
        do {
            let (europeId, typeId, carrier) = try marketTradeContext(goodsTypeId: goodsTypeId, amount: amount, carrierId: carrierId)
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
                    errorMessage = error.localizedDescription
                }
            }
        } catch let MarketTradeError.message(text) {
            errorMessage = text
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sellGoodsInEurope(goodsTypeId: String, amount: Int, carrierId: String) {
        do {
            let (_, typeId, carrier) = try marketTradeContext(goodsTypeId: goodsTypeId, amount: amount, carrierId: carrierId)
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
                    errorMessage = error.localizedDescription
                }
            }
        } catch let MarketTradeError.message(text) {
            errorMessage = text
        } catch {
            errorMessage = error.localizedDescription
        }
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
            errorMessage = "Bitte einen Goods Type angeben."
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
                errorMessage = error.localizedDescription
            }
        }
    }

    private func marketTradeContext(goodsTypeId: String,
                                    amount: Int,
                                    carrierId: String) throws -> (europeId: String, typeId: String, carrier: FreeColGame.Unit) {
        let typeId = goodsTypeId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard phase == .inGame else {
            throw MarketTradeError.message("Handel in Europa nicht moeglich.")
        }
        guard isLocalPlayersTurn else {
            throw MarketTradeError.message("Nicht dein Zug.")
        }
        guard !typeId.isEmpty else {
            throw MarketTradeError.message("Bitte einen Goods Type angeben.")
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
        guard let carrier = game.units[carrierId],
              carrier.owner == localPlayerId,
              resolveUnitTileId(carrier, in: game) == nil else {
            throw MarketTradeError.message("Traeger nicht in Europa.")
        }
        return (europeId, typeId, carrier)
    }

    func equipSelectedUnitForRole(_ roleId: String, count: Int) {
        guard canEquipSelectedUnitForRole,
              let unitId = selectedUnitId,
              let game = cachedGame else {
            errorMessage = "Unit kann diese Rolle nicht annehmen."
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
                try await client?.send(message: msg)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func sendMissionaryAction(direction: String, denounce: Bool) {
        guard canSendMissionaryAction,
              let unitId = selectedUnitId else {
            errorMessage = "Missionarische Aktion nicht moeglich."
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
                errorMessage = error.localizedDescription
            }
        }
    }

    var canEquipSelectedUnitForRole: Bool {
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
                errorMessage = error.localizedDescription
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
                errorMessage = error.localizedDescription
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
            errorMessage = "Region oder Kachel ID fehlt."
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
                errorMessage = error.localizedDescription
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
            errorMessage = "Settlement kann nicht angestiftet werden."
            return
        }
        guard !settlementId.isEmpty && !enemyPlayerId.isEmpty else {
            errorMessage = "Settlement oder Feind ID fehlt."
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
                errorMessage = error.localizedDescription
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
            errorMessage = "Settlement ID erforderlich."
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
                errorMessage = error.localizedDescription
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
                errorMessage = error.localizedDescription
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
            errorMessage = "Kolonie ID erforderlich."
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
                errorMessage = error.localizedDescription
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
            errorMessage = "Settlement ID erforderlich."
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
                errorMessage = error.localizedDescription
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
                errorMessage = error.localizedDescription
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
            errorMessage = "Settlement ID und Ergebnis erforderlich."
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
                errorMessage = error.localizedDescription
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

    func sendDiplomacyMessage(otherId: String) {
        guard canSendDiplomacy else {
            errorMessage = "Diplomatie nicht möglich."
            return
        }
        guard !otherId.isEmpty else {
            errorMessage = "Spieler ID erforderlich."
            return
        }
        guard let localPlayerId = resolveLocalPlayerId() else {
            errorMessage = "Lokaler Spieler nicht gefunden."
            return
        }
        errorMessage = nil


        Task {
            do {
                let msg = ParsedMessage(
                    tag: "diplomacy",
                    attributes: [
                        "otherId": otherId,
                        "ourId": localPlayerId,
                    ],
                    children: []
                )
                try await client?.send(message: msg)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
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
            errorMessage = "Nahkampfangriff nicht moeglich."
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
                errorMessage = error.localizedDescription
            }
        }
    }

    func attackSelectedUnitRanged(onTile targetTileId: String) {
        guard canAttackSelectedUnitRanged(onTile: targetTileId),
              let game = cachedGame,
              let unitId = selectedUnitId else {
            errorMessage = "Fernkampfangriff nicht moeglich."
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
                errorMessage = error.localizedDescription
            }
        }
    }

    func canMoveSelectedUnit(to destinationTileId: String) -> Bool {
        guard phase == .inGame,
              isLocalPlayersTurn,
              let game = cachedGame,
              let unitId = selectedUnitId,
              let unit = game.units[unitId],
              let localPlayerId = resolveLocalPlayerId(),
              unit.owner == localPlayerId,
              unit.movesLeft > 0,
              unit.state == .active,
              let sourceTileId = resolveUnitTileId(unit, in: game),
              unit.location != destinationTileId,
              game.tiles[destinationTileId] != nil else {
            return false
        }
        guard attackDirection(fromTileId: sourceTileId, toTileId: destinationTileId, in: game) != nil else {
            return false
        }
        return true
    }

    func syncAfterModelUpdate() {
        reconcileSelectionWithGame()
        reconcileSelectedUnitOrderWithGame()
        reconcilePendingEndTurnWithGame()
        autoFocusInitialUnitIfNeeded()
    }

    private func reconcileSelectionWithGame() {
        guard let game = cachedGame else {
            selectedUnitId = nil
            selectedTileId = nil
            return
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
            if let loc = unit.location, game.tiles[loc] != nil {
                selectedTileId = loc
            } else if let carrierId = unit.location,
                      let carrier = game.units[carrierId],
                      let carrierTile = carrier.location,
                      game.tiles[carrierTile] != nil {
                // Keep embarked units selectable by projecting selection onto carrier tile.
                selectedTileId = carrierTile
            } else {
                selectedUnitId = nil
                selectedTileId = nil
                return
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

    private func resolveUnitTileId(_ unit: FreeColGame.Unit, in game: Game) -> String? {
        if let loc = unit.location, game.tiles[loc] != nil {
            return loc
        }
        if let carrierId = unit.location,
           let carrier = game.units[carrierId],
           let carrierTile = carrier.location,
           game.tiles[carrierTile] != nil {
            return carrierTile
        }
        return nil
    }

    private func hasHostileUnit(onTile tileId: String, in game: Game, friendlyOwner: String) -> Bool {
        game.units.values.contains {
            $0.location == tileId && $0.owner != nil && $0.owner != friendlyOwner
        }
    }

    private func attackDirection(fromTileId sourceTileId: String, toTileId targetTileId: String, in game: Game) -> String? {
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

    private func nextStepTowardDestination(for unit: FreeColGame.Unit, destinationTileId: String, in game: Game) -> String? {
        guard let sourceTileId = resolveUnitTileId(unit, in: game),
              let source = game.tiles[sourceTileId],
              let destination = game.tiles[destinationTileId] else {
            return nil
        }

        if let pathStep = game.nextPathStep(from: sourceTileId, to: destinationTileId, canTraverse: { currentTileId, nextTileId in
            attackDirection(fromTileId: currentTileId, toTileId: nextTileId, in: game) != nil
        }) {
            return pathStep
        }

        let neighborDeltas: [(Int, Int)] = source.y.isMultiple(of: 2)
            ? [(0, -2), (0, -1), (1, 0), (0, 1), (0, 2), (-1, 1), (-1, 0), (-1, -1)]
            : [(0, -2), (1, -1), (1, 0), (1, 1), (0, 2), (0, 1), (-1, 0), (0, -1)]

        func score(x: Int, y: Int) -> Int {
            abs(destination.x - x) + abs(destination.y - y)
        }

        var bestTileId: String?
        var bestScore: Int = .max
        for (dx, dy) in neighborDeltas {
            let nx = source.x + dx
            let ny = source.y + dy
            guard let neighbor = game.tiles.values.first(where: { $0.x == nx && $0.y == ny }) else {
                continue
            }
            guard canMoveSelectedUnit(to: neighbor.id) else {
                continue
            }
            let candidateScore = score(x: nx, y: ny)
            if candidateScore < bestScore {
                bestScore = candidateScore
                bestTileId = neighbor.id
            }
        }
        return bestTileId
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

    private func isLikelyCarrier(_ unit: FreeColGame.Unit, in game: Game) -> Bool {
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
            if !Task.isCancelled {
                self.errorMessage = "Disconnected from server"
                self.disconnect()
            }
        }
    }
}

private func makeGameXML() -> String {
    """
    <game id="local-game" turn="1">
      <player id="player-european" username="Player" nationId="model.nation.dutch" gold="500"/>
      <player id="player-native-1" nationId="model.nation.iroquois" playerType="INDIAN"/>
      <map id="map-0" width="10" height="8">
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
      <unit id="unit-colonist" owner="player-european" unitType="model.unit.colonist" location="tile-4-1" movesLeft="3" state="ACTIVE"/>
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

    nonisolated func clientDidLogin(_ result: LoginResult) {
        guard let gs = gameState else { return }
        Task { @MainActor in
            gs.applyLoginResult(result)
        }
    }

    nonisolated func clientDidReceiveGameState(_ parsed: ParsedMessage) {
        guard let gs = gameState else { return }
        Task { @MainActor in
            gs.applySessionMessage(parsed)
            gs.syncAfterModelUpdate()
            gs.gameUpdateID += 1
        }
    }

    nonisolated func clientDidDisconnect(error: Error?) {
        guard let gs = gameState else { return }
        Task { @MainActor in
            gs.errorMessage = error?.localizedDescription ?? "Disconnected"
            gs.disconnect()
        }
    }

    nonisolated func clientDidUpdate() {
        guard let gs = gameState else { return }
        Task { @MainActor in
            gs.syncAfterModelUpdate()
            gs.gameUpdateID += 1
        }
    }
}

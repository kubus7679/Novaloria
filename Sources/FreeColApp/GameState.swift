import SwiftUI
import FreeColProtocol
import FreeColGame
import FreeColClient

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

    var phase: Phase = .disconnected
    var statusMessage: String = ""
    var errorMessage: String?

    private(set) var client: FreeColClient?
    // Expose vacant players after connection, before login
    var vacantPlayers: ParsedMessage?
    var serverState: ServerState?
    private var bridge: ClientBridge?
    private var server: MockServer?
    private var messageLoopTask: Task<Void, Never>?
    private(set) var cachedGame: Game?
    var gameUpdateID: Int = 0
    var selectedUnitId: String?
    var selectedTileId: String?
    var isReadyToStart: Bool = false
    private var localPlayerName: String?
    private var localNationId: String?
    private var localNationTypeId: String?
    private var localColorValue: String?
    private var isEndingTurn: Bool = false
    private var pendingEndTurnTurn: Int?
    var mapAnimationCue: MapAnimationCue?
    private var mapAnimationCueToken: Int = 0

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
        return game.currentPlayerId == localPlayerId
    }

    var localPlayerId: String? {
        resolveLocalPlayerId()
    }

    var canEndTurn: Bool {
        phase == .inGame && isLocalPlayersTurn && !isEndingTurn
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

                // Make sure handshake completed
                _ = try await serverHandshake

                phase = .inGame
                statusMessage = ""
                startMessageLoop(client: client, server: server)
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

    func applySessionMessage(_ parsed: ParsedMessage) {
        switch parsed.tag {
        case "question":
            if let payload = parsed.children.first {
                applySessionMessage(payload)
            }
        case "reply", "multiple":
            for child in parsed.children {
                applySessionMessage(child)
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
        case "animateMove":
            applyAnimateMoveMessage(parsed)
        case "animateAttack":
            applyAnimateAttackMessage(parsed)
        default:
            break
        }
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
            if message.contains("can not build colony") {
                errorMessage = "Diese Einheit kann hier keine Kolonie gruenden."
                return
            }
            errorMessage = message
            return
        }
        if let template = parsed.children.first(where: { $0.tag == "stringTemplate" }),
           let templateId = template.attributes["id"] {
            switch templateId {
            case "server.onlyAdminCanLaunch":
                errorMessage = "Nur der Admin kann das Spiel starten."
            case "server.notAllReady":
                errorMessage = "Nicht alle Spieler sind bereit."
            default:
                errorMessage = templateId
            }
            return
        }
        errorMessage = "Server error"
    }

    private func reconcileFromServerErrorMessage(_ message: String) {
        // Keep local action gating in sync when the server rejects a move due to no moves left.
        guard message.contains("MOVE_NO_MOVES"),
              let unitId = extractObjectId(withPrefix: "unit:", in: message),
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

    private func extractObjectId(withPrefix prefix: String, in text: String) -> String? {
        for rawToken in text.split(separator: " ") {
            let token = rawToken.trimmingCharacters(in: CharacterSet(charactersIn: ":;,()[]{}"))
            if token.hasPrefix(prefix) {
                return String(token)
            }
        }
        return nil
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

    private func resolveLocalPlayerId() -> String? {
        guard let game = cachedGame else { return nil }
        if let clientUserName = game.clientUserName,
           let player = game.players.values.first(where: { $0.name == clientUserName }) {
            return player.id
        }
        if let name = localPlayerName,
           let player = game.players.values.first(where: { $0.name == name }) {
            return player.id
        }
        if let nationId = localNationId,
           let player = game.players.values.first(where: { $0.nationId == nationId }) {
            return player.id
        }
        return nil
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
        localNationId = nil
        localNationTypeId = nil
        localColorValue = nil
        isEndingTurn = false
        pendingEndTurnTurn = nil
        mapAnimationCue = nil
        mapAnimationCueToken += 1
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

        errorMessage = nil
        let previousColorValue = localColorValue
        localColorValue = trimmedColorValue

        Task {
            do {
                let msg = ParsedMessage(
                    tag: "setColor",
                    attributes: ["player": playerId, "value": trimmedColorValue],
                    children: []
                )
                try await client?.send(message: msg)
            } catch {
                localColorValue = previousColorValue
                errorMessage = error.localizedDescription
            }
        }
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
        guard phase == .lobby else { return }
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
        guard let playerId = resolveLocalPlayerId() else {
            errorMessage = "Lokaler Spieler konnte nicht bestimmt werden."
            return
        }

        errorMessage = nil

        Task {
            do {
                let msg = ParsedMessage(
                    tag: "monarchAction",
                    attributes: ["action": trimmedActionType, "player": playerId],
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
        guard let playerId = resolveLocalPlayerId() else {
            errorMessage = "Lokaler Spieler konnte nicht bestimmt werden."
            return
        }

        errorMessage = nil

        Task {
            do {
                let msg = ParsedMessage(
                    tag: "setAvailable",
                    attributes: ["player": playerId],
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

        Task {
            do {
                let msg = ParsedMessage(tag: "endTurn", attributes: [:], children: [])
                try await client?.send(message: msg)
            } catch {
                clearPendingEndTurn()
                errorMessage = error.localizedDescription
            }
        }
    }

    func selectUnit(_ unitId: String?, onTile tileId: String?) {
        selectedUnitId = unitId
        selectedTileId = tileId
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
              unit.location != destinationTileId,
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
        // Distant target: take one legal step toward it.
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
                if server != nil {
                    game.buildColony(unitId: unitId, colonyName: trimmed)
                    reconcileSelectionWithGame()
                    gameUpdateID += 1
                }
                try await client?.send(message: msg)
                // Builder is consumed after founding on the server, clear immediately.
                selectUnit(nil, onTile: nil)
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
            let type = (unit.unitType ?? "").lowercased()
            let isLikelyNaval = type.contains("ship")
                || type.contains("caravel")
                || type.contains("galleon")
                || type.contains("frigate")
                || type.contains("manowar")
                || type.contains("privateer")
            return unit.state == .active && !isLikelyNaval
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

    func rearrangeSelectedColony() {
        guard canManageSelectedColony,
              let colony = selectedColony else {
            errorMessage = "Kolonie kann nicht neu sortiert werden."
            return
        }
        errorMessage = nil

        Task {
            do {
                let msg = ParsedMessage(
                    tag: "rearrangeColony",
                    attributes: ["colony": colony.id, "xLength": "0"],
                    children: []
                )
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

    func setSelectedColonyWorkerWorkLocation(_ workLocationId: String) {
        let trimmed = workLocationId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Bitte eine Work Location ID eingeben."
            return
        }
        guard canManageSelectedColony,
              let unitId = selectedColonyWorkerUnitId,
              let game = cachedGame else {
            errorMessage = "Work-Zuweisung nicht moeglich."
            return
        }
        errorMessage = nil

        Task {
            do {
                let msg = ParsedMessage(
                    tag: "work",
                    attributes: ["unit": unitId, "workLocation": trimmed],
                    children: []
                )
                if server != nil {
                    game.setUnitWorkLocation(unitId: unitId, workLocationId: trimmed)
                    gameUpdateID += 1
                }
                try await client?.send(message: msg)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
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

    func setSelectedColonyGoodsLevels() {
        guard canManageSelectedColony,
              let colony = selectedColony else {
            errorMessage = "Goods-Levels koennen nicht gesetzt werden."
            return
        }
        errorMessage = nil

        Task {
            do {
                let msg = ParsedMessage(
                    tag: "setGoodsLevels",
                    attributes: ["colony": colony.id],
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
              unit.location != destinationTileId,
              game.tiles[destinationTileId] != nil else {
            return false
        }
        guard let sourceTileId = resolveUnitTileId(unit, in: game),
              attackDirection(fromTileId: sourceTileId, toTileId: destinationTileId, in: game) != nil else {
            return false
        }
        return true
    }

    func syncAfterModelUpdate() {
        reconcileSelectionWithGame()
        reconcileSelectedUnitOrderWithGame()
        reconcilePendingEndTurnWithGame()
    }

    private func reconcileSelectionWithGame() {
        guard let game = cachedGame else {
            selectedUnitId = nil
            selectedTileId = nil
            return
        }

        if let unitId = selectedUnitId {
            guard let unit = game.units[unitId] else {
                selectedUnitId = nil
                selectedTileId = nil
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
        } else if let tileId = selectedTileId, game.tiles[tileId] == nil {
            selectedTileId = nil
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
    }

    private func isLikelyCarrier(_ unit: FreeColGame.Unit, in game: Game) -> Bool {
        if game.units.values.contains(where: { $0.location == unit.id }) {
            return true
        }
        let type = (unit.unitType ?? "").lowercased()
        return type.contains("ship")
            || type.contains("caravel")
            || type.contains("galleon")
            || type.contains("merchant")
            || type.contains("frigate")
            || type.contains("privateer")
            || type.contains("manowar")
    }

    private func isBuildableColonyTile(_ tile: Tile) -> Bool {
        guard let type = tile.type?.lowercased() else { return false }
        guard !type.contains("ocean"),
              !type.contains("highseas"),
              !type.contains("lake"),
              tile.settlement == nil else {
            return false
        }
        return true
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

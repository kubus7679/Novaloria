import Foundation
import FreeColGame
import FreeColProtocol

extension GameState {
    // MARK: - Trade route state and validation

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

    var canClearSelectedUnitTradeRoute: Bool {
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
        return unit.tradeRoute != nil
    }

    /// Owned colonies plus Europe, as candidate trade route stops.
    var tradeRouteStopCandidates: [(id: String, label: String)] {
        guard let game = cachedGame,
              let localPlayerId = resolveLocalPlayerId() else {
            return []
        }
        var result: [(id: String, label: String)] = []
        if let europeId = game.players[localPlayerId]?.europe?.id {
            result.append((id: europeId, label: "Europa"))
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
            .filter(\.isStorable)
            .map { (id: $0.id, label: goodsDisplayName($0.id)) }
            .sorted { $0.label < $1.label }
    }

    func tradeRouteValidationError(for route: TradeRoute) -> String? {
        guard canManageTradeRoutes,
              let game = cachedGame,
              let localPlayerId = resolveLocalPlayerId() else {
            return L10n.text("Handelsrouten können nur im eigenen Zug verwaltet werden.", table: "GameState+TradeRoutes")
        }
        return Self.tradeRouteValidationError(
            route: route,
            localPlayerId: localPlayerId,
            existingRoutes: localPlayerTradeRoutes,
            validStopLocationIds: Set(tradeRouteStopCandidates.map(\.id)),
            validGoodsTypeIds: Set(tradeRouteGoodsTypes.map(\.id)),
            enhancedTradeRoutes: game.optionValues["model.option.enhancedTradeRoutes"] == "true"
        )
    }

    nonisolated static func tradeRouteValidationError(
        route: TradeRoute,
        localPlayerId: String,
        existingRoutes: [TradeRoute],
        validStopLocationIds: Set<String>,
        validGoodsTypeIds: Set<String>,
        enhancedTradeRoutes: Bool
    ) -> String? {
        let name = (route.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return L10n.text("Die Handelsroute benötigt einen Namen.", table: "GameState+TradeRoutes") }
        guard route.owner == localPlayerId else { return L10n.text("Diese Handelsroute gehört einem anderen Spieler.", table: "GameState+TradeRoutes") }
        guard !existingRoutes.contains(where: { $0.id != route.id && $0.name == name }) else {
            return L10n.text("Eine Handelsroute mit diesem Namen existiert bereits.", table: "GameState+TradeRoutes")
        }
        guard route.stops.count >= 2 else { return L10n.text("Mindestens zwei Haltepunkte hinzufügen.", table: "GameState+TradeRoutes") }
        guard route.stops.allSatisfy({
            guard let location = $0.locationId else { return false }
            return validStopLocationIds.contains(location)
        }) else {
            return L10n.text("Für jeden Halt einen gültigen eigenen Ort auswählen.", table: "GameState+TradeRoutes")
        }
        guard route.stops.allSatisfy({ $0.cargoTypeIds.allSatisfy(validGoodsTypeIds.contains) }) else {
            return L10n.text("Die Handelsroute enthält eine unbekannte Warenart.", table: "GameState+TradeRoutes")
        }
        guard route.stops.contains(where: { !$0.cargoTypeIds.isEmpty }) else {
            return L10n.text("Für mindestens einen Halt Waren auswählen.", table: "GameState+TradeRoutes")
        }
        if !enhancedTradeRoutes, let firstStop = route.stops.first {
            var presentAtEveryStop = Set(firstStop.cargoTypeIds)
            for stop in route.stops.dropFirst() {
                presentAtEveryStop.formIntersection(stop.cargoTypeIds)
            }
            if !presentAtEveryStop.isEmpty {
                return L10n.text("Bei Standard-Handelsrouten darf dieselbe Ware nicht an allen Haltepunkten ausgewählt sein.", table: "GameState+TradeRoutes")
            }
        }
        return nil
    }

    // MARK: - Trade route assignment and editing

    func canAssignSelectedUnitTradeRoute(_ tradeRouteId: String) -> Bool {
        let trimmed = tradeRouteId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              phase == .inGame,
              isLocalPlayersTurn,
              movingUnitId == nil, !isSavingGame,
              let game = cachedGame,
              let unitId = selectedUnitId,
              let unit = game.units[unitId],
              let localPlayerId = resolveLocalPlayerId(),
              unit.owner == localPlayerId,
              let route = game.tradeRoutes[trimmed], route.owner == localPlayerId,
              game.specification?.hasAbility("model.ability.carryGoods", unitType: unit.unitType) == true else {
            return false
        }
        return unit.tradeRoute != trimmed
    }

    func assignSelectedUnitTradeRoute(_ tradeRouteId: String) {
        let trimmed = tradeRouteId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canAssignSelectedUnitTradeRoute(trimmed),
              let unitId = selectedUnitId,
              let game = cachedGame else {
            errorMessage = L10n.text("Handelsroute kann nicht zugewiesen werden.", table: "GameState+TradeRoutes")
            return
        }
        updateTradeRouteAssignment(unitId, routeId: trimmed, in: game)
    }

    func clearSelectedUnitTradeRoute() {
        guard canClearSelectedUnitTradeRoute,
              let unitId = selectedUnitId,
              let game = cachedGame else {
            errorMessage = L10n.text("Keine Handelsroute zum Entfernen gesetzt.", table: "GameState+TradeRoutes")
            return
        }
        updateTradeRouteAssignment(unitId, routeId: nil, in: game)
    }

    func createTradeRoute() {
        guard canManageTradeRoutes else {
            errorMessage = L10n.text("Handelsrouten können nur im eigenen Zug verwaltet werden.", table: "GameState+TradeRoutes")
            return
        }
        errorMessage = nil
        Task {
            do {
                try await client?.send(message: ParsedMessage(tag: "newTradeRoute", attributes: [:], children: []))
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    func saveTradeRoute(_ route: TradeRoute) {
        guard let game = cachedGame else {
            errorMessage = L10n.text("Handelsroute kann nicht gespeichert werden.", table: "GameState+TradeRoutes")
            return
        }
        if let validationError = tradeRouteValidationError(for: route) {
            errorMessage = validationError
            return
        }
        let trimmed = (route.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        errorMessage = nil

        var updated = route
        updated.name = trimmed
        let msg = Self.tradeRouteMessage(tag: "updateTradeRoute", route: updated)

        Task {
            do {
                if usesLocalServer {
                    game.addTradeRoute(updated)
                    gameUpdateID += 1
                }
                try await client?.send(message: msg)
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

    func deleteTradeRoute(_ tradeRouteId: String) {
        guard canManageTradeRoutes,
              let game = cachedGame,
              game.tradeRoutes[tradeRouteId] != nil else {
            errorMessage = L10n.text("Handelsroute kann nicht gelöscht werden.", table: "GameState+TradeRoutes")
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
                if usesLocalServer {
                    game.removeTradeRoute(tradeRouteId)
                    gameUpdateID += 1
                }
                try await client?.send(message: msg)
            } catch {
                errorMessage = ServerErrorMessage.description(for: error)
            }
        }
    }

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
              movingUnitId == nil, !isSavingGame,
              let game = cachedGame,
              let unitId = selectedUnitId,
              let unit = game.units[unitId],
              let localPlayerId = resolveLocalPlayerId(),
              unit.owner == localPlayerId,
              let routeId = unit.tradeRoute, let route = game.tradeRoutes[routeId],
              route.owner == localPlayerId else {
            errorMessage = L10n.text("Aktueller Halt kann nicht gesetzt werden.", table: "GameState+TradeRoutes")
            return
        }
        let trimmed = indexText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let index = Int(trimmed), route.stops.indices.contains(index) else {
            errorMessage = L10n.text("Bitte einen gültigen Haltepunkt auswählen.", table: "GameState+TradeRoutes")
            return
        }
        guard unit.currentStop != index else {
            errorMessage = L10n.text("Dieser Halt ist bereits gesetzt.", table: "GameState+TradeRoutes")
            return
        }
        updateTradeRouteStop(unitId, index: index, in: game)
    }

    // MARK: - Trade route execution

    func executeTradeRoutes() {
        Task {
            await executeTradeRoutesNow()
        }
    }

    private func executeTradeRoutesNow() async {
        guard phase == .inGame,
              isLocalPlayersTurn,
              let game = cachedGame,
              let localPlayerId = resolveLocalPlayerId() else {
            return
        }

        var anyExecuted = false
        for route in game.tradeRoutes.values where route.owner == localPlayerId {
            guard let carrier = game.units.values.first(where: {
                $0.owner == localPlayerId && $0.tradeRoute == route.id
            }) else {
                continue
            }
            if await executeTradeRouteStep(route: route, carrier: carrier, game: game, localPlayerId: localPlayerId) {
                anyExecuted = true
            }
        }

        if anyExecuted {
            gameUpdateID += 1
            statusMessage = L10n.text("Handelsrouten ausgeführt.", table: "GameState+TradeRoutes")
        }
    }

    private func executeTradeRouteStep(
        route: TradeRoute,
        carrier: FreeColGame.Unit,
        game: Game,
        localPlayerId: String
    ) async -> Bool {
        guard !route.stops.isEmpty else { return false }
        let currentStopIndex = carrier.currentStop
        guard route.stops.indices.contains(currentStopIndex),
              let stopLocationId = route.stops[currentStopIndex].locationId else {
            return false
        }
        let stop = route.stops[currentStopIndex]

        guard isCarrier(carrier, atTradeRouteStop: stopLocationId, in: game) else {
            return await moveCarrierToStop(
                carrier: carrier,
                stopLocationId: stopLocationId,
                playerId: localPlayerId,
                game: game
            )
        }

        let cargoMessages = tradeRouteCargoMessages(
            stop: stop,
            carrier: carrier,
            stopLocationId: stopLocationId,
            game: game,
            playerId: localPlayerId
        )
        let nextStopIndex = (currentStopIndex + 1) % route.stops.count
        do {
            for message in cargoMessages {
                try await client?.send(message: message)
            }
            try await client?.send(message: ParsedMessage(
                tag: "setCurrentStop",
                attributes: ["unit": carrier.id, "index": String(nextStopIndex)],
                children: []
            ))
            return true
        } catch {
            errorMessage = ServerErrorMessage.description(for: error)
            return false
        }
    }

    private func tradeRouteCargoMessages(
        stop: TradeRouteStop,
        carrier: FreeColGame.Unit,
        stopLocationId: String,
        game: Game,
        playerId: String
    ) -> [ParsedMessage] {
        let wantedGoods = Set(stop.cargoTypeIds)
        var messages: [ParsedMessage] = []
        for (goodsTypeId, amount) in carrier.goods.sorted(by: { $0.key < $1.key })
        where amount > 0 && !wantedGoods.contains(goodsTypeId) {
            messages.append(ParsedMessage(
                tag: "unloadGoods",
                attributes: ["type": goodsTypeId, "amount": String(amount), "carrier": carrier.id],
                children: []
            ))
        }

        guard let specification = game.specification,
              let carrierTypeId = carrier.unitType,
              specification.hasAbility("model.ability.carryGoods", unitType: carrierTypeId),
              let cargoCapacity = specification.unitTypes[carrierTypeId]?.cargoSpace else {
            return messages
        }
        let carriedUnitSpace = game.units.values
            .filter { $0.location == carrier.id }
            .reduce(0) { total, cargoUnit in
                total + (cargoUnit.unitType.flatMap { specification.unitTypes[$0]?.spaceTakenOnCarrier } ?? 1)
            }

        var plannedGoods = carrier.goods
        for goodsTypeId in Set(stop.cargoTypeIds).sorted() where !goodsTypeId.isEmpty {
            let alreadyCarried = plannedGoods[goodsTypeId] ?? 0
            let loadable = Self.loadableGoodsAmount(
                cargoCapacity: cargoCapacity,
                goodsAmounts: Array(plannedGoods.values),
                carriedUnitSpace: carriedUnitSpace,
                selectedGoodsAmount: alreadyCarried
            )
            guard loadable > 0 else { continue }

            let amount: Int
            if let colony = game.colonies[stopLocationId] {
                amount = min(loadable, max(0, colony.goods[goodsTypeId] ?? 0))
            } else if game.players[playerId]?.europe?.id == stopLocationId {
                amount = min(loadable, europeMarketTradeLimits(goodsTypeId: goodsTypeId, carrierId: carrier.id).buy)
            } else {
                continue
            }
            guard amount > 0 else { continue }
            messages.append(ParsedMessage(
                tag: "loadGoods",
                attributes: [
                    "location": stopLocationId,
                    "type": goodsTypeId,
                    "amount": String(amount),
                    "carrier": carrier.id,
                ],
                children: []
            ))
            plannedGoods[goodsTypeId] = alreadyCarried + amount
        }
        return messages
    }

    private func isCarrier(
        _ carrier: FreeColGame.Unit,
        atTradeRouteStop stopLocationId: String,
        in game: Game
    ) -> Bool {
        if carrier.location == stopLocationId { return true }
        guard let colonyTileId = game.colonies[stopLocationId]?.tileId else { return false }
        return resolveUnitTileId(carrier, in: game) == colonyTileId
    }

    private func moveCarrierToStop(
        carrier: FreeColGame.Unit,
        stopLocationId: String,
        playerId: String,
        game: Game
    ) async -> Bool {
        let targetTileId = game.colonies[stopLocationId]?.tileId
            ?? (game.tiles[stopLocationId] == nil ? nil : stopLocationId)
        let sourceTileId = resolveUnitTileId(carrier, in: game)
        let isEuropeStop = game.players[playerId]?.europe?.id == stopLocationId
        guard isEuropeStop || targetTileId != nil,
              carrier.movesLeft > 0 else {
            return false
        }
        if let sourceTileId, let targetTileId, sourceTileId == targetTileId { return false }

        let message: ParsedMessage
        if isEuropeStop || sourceTileId == nil {
            message = ParsedMessage(
                tag: "moveTo",
                attributes: ["unit": carrier.id, "destination": stopLocationId],
                children: []
            )
        } else {
            guard let sourceTileId,
                  let targetTileId,
                  let nextTileId = game.nextPathStep(from: sourceTileId, to: targetTileId, canTraverse: { _, _ in true }),
                  let direction = attackDirection(fromTileId: sourceTileId, toTileId: nextTileId, in: game) else {
                return false
            }
            message = ParsedMessage(
                tag: "move",
                attributes: ["unit": carrier.id, "direction": direction],
                children: []
            )
        }

        do {
            try await client?.send(message: message)
            return true
        } catch {
            errorMessage = ServerErrorMessage.description(for: error)
            return false
        }
    }

    /// Execute routes before ending the turn when automatic execution is enabled.
    func executeTradeRoutesOnTurnEnd() async {
        guard autoExecuteTradeRoutes else { return }
        await executeTradeRoutesNow()
    }
}

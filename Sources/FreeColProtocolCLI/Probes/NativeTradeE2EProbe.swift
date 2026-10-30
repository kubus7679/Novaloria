import Foundation
import FreeColProtocol
import FreeColGame
import FreeColClient

func nativeTradeE2EProbe() async throws {
    let host = ProcessInfo.processInfo.environment["REAL_SERVER_HOST"] ?? "127.0.0.1"
    let port = Int(ProcessInfo.processInfo.environment["REAL_SERVER_PORT"] ?? "3541") ?? 3541
    let client = FreeColClient(host: host, port: port)
    let delegate = TestDelegate()
    await client.setDelegate(delegate)

    try await client.connect()
    let vacant = await client.initialVacantPlayers
    let nationId = vacant?.children.first?.attributes["nationId"]
        ?? vacant?.children.first?.attributes["id"]
        ?? "model.nation.dutch"
    let userName = ProcessInfo.processInfo.environment["REAL_SERVER_USERNAME"]
        ?? "CopilotNativeTrade-\(Int(Date().timeIntervalSince1970))"

    let result = try await client.login(userName: userName, nationId: nationId)
    if result.serverState == .preGame {
        try await client.send(message: ParsedMessage(
            tag: "updateGameOptions",
            attributes: [:],
            children: [ParsedMessage(tag: "optionGroup", attributes: ["id": "gameOptions"], children: [
                ParsedMessage(tag: "integerOption", attributes: [
                    "id": "model.option.turnsToSail", "value": "1",
                ], children: []),
            ])]
        ))
        let mapGeneratorOptions = ParsedMessage(
            tag: "optionGroup",
            attributes: ["id": "mapGeneratorOptions"],
            children: [ParsedMessage(
                tag: "optionGroup",
                attributes: ["id": "mapGeneratorOptions.landGenerator"],
                children: [
                    ParsedMessage(tag: "integerOption", attributes: ["id": "model.option.mapWidth", "value": "40"], children: []),
                    ParsedMessage(tag: "integerOption", attributes: ["id": "model.option.mapHeight", "value": "40"], children: []),
                    ParsedMessage(tag: "integerOption", attributes: ["id": "model.option.landMass", "value": "50"], children: []),
                    ParsedMessage(tag: "selectOption", attributes: ["id": "model.option.landGeneratorType", "value": "1"], children: []),
                ]
            )]
        )
        try await client.send(message: ParsedMessage(
            tag: "updateMapGeneratorOptions",
            attributes: [:],
            children: [mapGeneratorOptions]
        ))
        try await client.send(message: ParsedMessage(tag: "ready", attributes: ["value": "true"], children: []))
        try await client.send(message: ParsedMessage(tag: "requestLaunch", attributes: [:], children: []))
    }

    let loopTask = Task { await client.startMessageLoop() }
    defer {
        loopTask.cancel()
        Task { await client.disconnect() }
    }

    var waited = 0
    while true {
        let current = await client.game
        if current.currentPlayerId != nil && !current.units.isEmpty { break }
        if waited >= 60 { throw TestError(message: "game did not start within 30s") }
        try await Task.sleep(nanoseconds: 500_000_000)
        waited += 1
    }


        var game = await client.game
        guard let spec = game.specification else {
            throw TestError(message: "launched game has no specification")
        }
        guard let localPlayerId = game.players.values.first(where: { $0.name == result.playerName })?.id else {
            throw TestError(message: "local player not found in launched game")
        }

        print("    native test map size: \(game.map?.width ?? 0)x\(game.map?.height ?? 0)")

        // Find a land unit to use as trader. Prefer a scout, otherwise any land unit.
        func landUnit(in current: FreeColGame.Game) -> FreeColGame.Unit? {
            current.units.values
                .filter { $0.owner == localPlayerId && spec.isNaval(unitType: $0.unitType) != true }
                .sorted { a, b in
                    func priority(_ unit: FreeColGame.Unit) -> Int {
                        let type = unit.unitType?.lowercased() ?? ""
                        if type.contains("scout") { return 0 }
                        if type.contains("freecolonist") { return 1 }
                        if type.contains("veteran") || type.contains("soldier") { return 3 }
                        return 2
                    }
                    let aPriority = priority(a)
                    let bPriority = priority(b)
                    return aPriority == bPriority ? a.id < b.id : aPriority < bPriority
                }
                .first
        }
        guard let trader = landUnit(in: game) else {
            throw TestError(message: "no local land unit found for native trade test")
        }
        let traderId = trader.id

        // Helpers for adjacency and movement.
        func nativeSettlementTargets(around sourceTileId: String, in current: FreeColGame.Game) -> [(settlementId: String, tileId: String)] {
            current.neighborTileIds(of: sourceTileId).compactMap { neighborId in
                guard let tile = current.tiles[neighborId],
                      let settlementId = tile.settlement else { return nil }
                let settlement = current.colonies[settlementId]
                let ownerIsNative = settlement?.owner
                    .flatMap { current.players[$0]?.playerType == .indian } ?? false
                let nativeObjectId = settlementId.lowercased().contains("indiansettlement")
                let nativeType = settlement?.settlementType?.lowercased().contains("indian") == true
                guard ownerIsNative || nativeObjectId || nativeType else { return nil }
                return (settlementId, tile.id)
            }
        }

        func endTurnAndWait() async throws {
            let turnBefore = await client.game.turn.number
            _ = try await client.ask(message: ParsedMessage(tag: "endTurn", attributes: [:], children: []), timeout: 45)
            for _ in 0..<60 {
                let current = await client.game
                if current.turn.number > turnBefore && current.currentPlayerId == localPlayerId { return }
                try await Task.sleep(nanoseconds: 500_000_000)
            }
            throw TestError(message: "local player's turn did not return after endTurn")
        }

        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]

        func isWaterTile(_ tile: FreeColGame.Tile) -> Bool {
            guard let type = tile.type else { return false }
            return spec.tileTypes[type]?.isWater
                ?? (type.lowercased().contains("ocean") || type.lowercased().contains("highseas") || type.lowercased().contains("lake"))
        }

        func openLandTiles(around sourceTileId: String, in current: FreeColGame.Game) -> [FreeColGame.Tile] {
            current.neighborTileIds(of: sourceTileId)
                .compactMap { current.tiles[$0] }
                .filter { tile in
                    guard tile.type != nil,
                          tile.settlement == nil,
                          tile.owningSettlement == nil,
                          tile.owner == nil || tile.owner == localPlayerId else { return false }
                    return !isWaterTile(tile)
                }
                .sorted { $0.id < $1.id }
        }

        func usefulLandingTiles(around sourceTileId: String, in current: FreeColGame.Game) -> [FreeColGame.Tile] {
            return openLandTiles(around: sourceTileId, in: current).filter {
                !($0.type?.lowercased().contains("arctic") ?? false)
            }
        }

        func direction(from source: FreeColGame.Tile, to target: FreeColGame.Tile) -> String? {
            let isOddRow = !source.y.isMultiple(of: 2)
            let deltas: [(String, Int, Int)] = [
                ("N", 0, -2),
                ("NE", isOddRow ? 1 : 0, -1),
                ("E", 1, 0),
                ("SE", isOddRow ? 1 : 0, 1),
                ("S", 0, 2),
                ("SW", isOddRow ? 0 : -1, 1),
                ("W", -1, 0),
                ("NW", isOddRow ? 0 : -1, -1),
            ]
            return deltas.first(where: { name, dx, dy in
                source.x + dx == target.x && source.y + dy == target.y
            })?.0
        }

        func moveAndWait(unitId: String, direction: String) async throws -> Bool {
            let before = await client.game.units[unitId]?.location
            do {
                _ = try await client.ask(message: ParsedMessage(
                    tag: "move",
                    attributes: ["unit": unitId, "direction": direction],
                    children: []
                ), timeout: 2)
            } catch FreeColProtocolError.serverError(_) {
                return false
            } catch FreeColProtocolError.timeout {
                return false
            }
            for _ in 0..<20 {
                if await client.game.units[unitId]?.location != before { return true }
                try await Task.sleep(nanoseconds: 100_000_000)
            }
            return false
        }

        func moveCarrierToCoast(_ carrierId: String) async throws -> String? {
            var explorationHeading = 0
            for _ in 0..<30 {
                game = await client.game
                guard let carrier = game.units[carrierId],
                      let sourceTileId = game.resolvedTileId(for: carrier),
                      let sourceTile = game.tiles[sourceTileId] else { return nil }

                if !usefulLandingTiles(around: sourceTileId, in: game).isEmpty {
                    try await Task.sleep(nanoseconds: 300_000_000)
                    game = await client.game
                    guard let latestCarrier = game.units[carrierId],
                          let latestTileId = game.resolvedTileId(for: latestCarrier) else { return nil }
                    if !usefulLandingTiles(around: latestTileId, in: game).isEmpty {
                        return latestTileId
                    }
                    continue
                }
                if carrier.movesLeft <= 0 {
                    try await endTurnAndWait()
                    continue
                }

                let coastalWaterTiles = game.tiles.values.filter { tile in
                    isWaterTile(tile) && !usefulLandingTiles(around: tile.id, in: game).isEmpty
                }.sorted { first, second in
                    let firstDistance = abs(first.x - sourceTile.x) + abs(first.y - sourceTile.y)
                    let secondDistance = abs(second.x - sourceTile.x) + abs(second.y - sourceTile.y)
                    return firstDistance == secondDistance ? first.id < second.id : firstDistance < secondDistance
                }

                var knownCoastDirection: String?
                for target in coastalWaterTiles where target.id != sourceTileId {
                    if let step = game.nextPathStep(from: sourceTileId, to: target.id, canTraverse: { _, next in
                        guard let tile = game.tiles[next] else { return false }
                        return isWaterTile(tile)
                    }), let nextTile = game.tiles[step],
                       let nextDirection = direction(from: sourceTile, to: nextTile) {
                        knownCoastDirection = nextDirection
                        break
                    }
                }

                var moved = false
                var candidates = directions.indices.map { directions[($0 + explorationHeading) % directions.count] }
                if let knownCoastDirection {
                    candidates.removeAll { $0 == knownCoastDirection }
                    candidates.insert(knownCoastDirection, at: 0)
                }
                for moveDirection in candidates {
                    if try await moveAndWait(unitId: carrierId, direction: moveDirection) {
                        moved = true
                        if let index = directions.firstIndex(of: moveDirection) {
                            explorationHeading = index
                        }
                        break
                    }
                    game = await client.game
                    if (game.units[carrierId]?.movesLeft ?? 0) <= 0 { break }
                }
                if !moved {
                    game = await client.game
                    if (game.units[carrierId]?.movesLeft ?? 0) <= 0 {
                        try await endTurnAndWait()
                    } else {
                        explorationHeading = (explorationHeading + 1) % directions.count
                    }
                }
            }
            return nil
        }

        // The initial trader is usually aboard the starting ship in the high seas.
        // Sail to the coast, then move the passenger directly onto an adjacent land tile.
        if let location = game.units[traderId]?.location,
           game.tiles[location] == nil,
           let carrier = game.units[location],
           spec.isNaval(unitType: carrier.unitType) == true {
            let carrierId = carrier.id
            if carrier.location?.hasPrefix("highSeas:") == true {
                guard let mapId = game.map?.id else {
                    throw TestError(message: "game map id missing while carrier is on high seas")
                }
                _ = try await client.ask(message: ParsedMessage(
                    tag: "moveTo",
                    attributes: ["unit": carrierId, "destination": mapId],
                    children: []
                ), timeout: 8)
                for _ in 0..<4 {
                    game = await client.game
                    if let location = game.units[carrierId]?.location,
                       game.tiles[location] != nil { break }
                    try await endTurnAndWait()
                }
                game = await client.game
                guard let location = game.units[carrierId]?.location,
                      game.tiles[location] != nil else {
                    throw TestError(message: "carrier did not return from high seas to the map")
                }
            }
            guard try await moveCarrierToCoast(carrierId) != nil else {
                print("    native trade skipped: carrier could not reach a temperate coast")
                await client.disconnect()
                return
            }
            game = await client.game
            if (game.units[traderId]?.movesLeft ?? 0) <= 0 {
                try await endTurnAndWait()
                game = await client.game
            }
            guard let currentCarrier = game.units[carrierId],
                  let seaTileId = game.resolvedTileId(for: currentCarrier),
                  let seaTile = game.tiles[seaTileId] else {
                print("    native trade skipped: no stable coastal carrier position")
                await client.disconnect()
                return
            }
            let landingCandidates = usefulLandingTiles(around: seaTileId, in: game)
                + openLandTiles(around: seaTileId, in: game).filter { candidate in
                    !usefulLandingTiles(around: seaTileId, in: game).contains(where: { $0.id == candidate.id })
                }
            var landed = false
            for landingTile in landingCandidates {
                guard let landingDirection = direction(from: seaTile, to: landingTile) else { continue }
                if try await moveAndWait(unitId: traderId, direction: landingDirection),
                   await client.game.units[traderId]?.location == landingTile.id {
                    landed = true
                    print("    landed trader at \(landingTile.id) (\(landingTile.type ?? "?") at \(landingTile.x),\(landingTile.y))")
                    break
                }
                game = await client.game
            }
            guard landed else {
                print("    native trade skipped: no accessible land tile at coast \(seaTileId)")
                await client.disconnect()
                return
            }
        }

        // Explore the New World until adjacent to a known Native settlement.
        var foundSettlement: (settlementId: String, tileId: String)?
        var previousTileId: String?
        var blockedLandEdges: Set<String> = []
        exploreLoop: for _ in 0..<120 {
            game = await client.game
            guard let unit = game.units[traderId],
                  let currentLocation = game.resolvedTileId(for: unit),
                  let sourceTile = game.tiles[currentLocation] else { break }

            if let adjacent = nativeSettlementTargets(around: currentLocation, in: game).first {
                foundSettlement = adjacent
                break
            }

            if unit.movesLeft <= 0 {
                try await endTurnAndWait()
                continue
            }

            var moved = false
            let neighbors = game.neighborTileIds(of: currentLocation).compactMap { game.tiles[$0] }
            let centerY = (game.map?.height ?? 0) / 2
            let candidates = neighbors.filter { tile in
                guard tile.settlement == nil,
                      tile.unitIds.allSatisfy({ $0 == traderId }),
                      !blockedLandEdges.contains("\(currentLocation)->\(tile.id)") else { return false }
                return tile.type == nil || !isWaterTile(tile)
            }.sorted { first, second in
                let firstBacktrack = first.id == previousTileId
                let secondBacktrack = second.id == previousTileId
                if firstBacktrack != secondBacktrack { return !firstBacktrack }
                let firstLatitudeDistance = abs(first.y - centerY)
                let secondLatitudeDistance = abs(second.y - centerY)
                if firstLatitudeDistance != secondLatitudeDistance {
                    return firstLatitudeDistance < secondLatitudeDistance
                }
                let firstUnknown = first.type == nil
                let secondUnknown = second.type == nil
                if firstUnknown != secondUnknown { return firstUnknown }
                return first.id < second.id
            }
            for neighbor in candidates {
                guard let moveDirection = direction(from: sourceTile, to: neighbor) else { continue }
                if try await moveAndWait(unitId: traderId, direction: moveDirection) {
                    previousTileId = currentLocation
                    moved = true
                    break
                }
                game = await client.game
                if (game.units[traderId]?.movesLeft ?? 0) <= 0 { break }
                blockedLandEdges.insert("\(currentLocation)->\(neighbor.id)")
            }

            if !moved {
                try await endTurnAndWait()
                previousTileId = nil
            }
        }

        guard let foundSettlement else {
            let nativeCount = game.colonies.values.filter { colony in
                guard let ownerId = colony.owner else { return false }
                return game.players[ownerId]?.playerType == .indian
            }.count
            print("    native trade skipped: no reachable settlement after 120 exploration steps (revealed \(game.exploredTileIds().count), known natives \(nativeCount))")
            await client.disconnect()
            return
        }
        print("    adjacent to native settlement \(foundSettlement.settlementId)")

        func nativeTradeEnvelope(in message: ParsedMessage) -> ParsedMessage? {
            if message.tag == "nativeTrade", message.attributes["action"] != nil {
                return message
            }
            for child in message.children {
                if let result = nativeTradeEnvelope(in: child) { return result }
            }
            return nil
        }

        func nativeTradePayload(in message: ParsedMessage) -> ParsedMessage? {
            if message.tag == "nativeTrade",
               message.attributes["unit"] != nil,
               message.attributes["settlement"] != nil {
                return message
            }
            for child in message.children {
                if let result = nativeTradePayload(in: child) { return result }
            }
            return nil
        }

        func waitForNativeTradeAction(_ expected: Set<String>,
                                      after startIndex: Int,
                                      timeout: TimeInterval = 30) async throws -> ParsedMessage {
            let deadline = Date().addingTimeInterval(timeout)
            while Date() < deadline {
                for incoming in delegate.receivedPayloads.dropFirst(startIndex) {
                    if incoming.tag == "error" {
                        throw TestError(message: "Java rejected native trade: \(incoming.attributes["message"] ?? "unknown error")")
                    }
                    guard let envelope = nativeTradeEnvelope(in: incoming),
                          let action = envelope.attributes["action"] else { continue }
                    if expected.contains(action) { return envelope }
                }
                try await Task.sleep(nanoseconds: 200_000_000)
            }
            let received = delegate.receivedPayloads.dropFirst(startIndex).map { message in
                "\(message.tag):\(message.attributes["action"] ?? "")"
            }
            throw TestError(message: "timed out waiting for native trade action \(expected.sorted()); received \(received)")
        }

        // Open native trade session.
        game = await client.game
        if (game.units[traderId]?.movesLeft ?? 0) <= 0 {
            try await endTurnAndWait()
            game = await client.game
        }
        guard (game.units[traderId]?.movesLeft ?? 0) > 0 else {
            throw TestError(message: "trading unit has no moves left adjacent to native settlement")
        }
        var session = NativeTradeSession(unitId: traderId, settlementId: foundSettlement.settlementId)
        let openStart = delegate.receivedPayloads.count
        let openReply = try await client.ask(message: session.toMessage(action: "OPEN", item: nil), timeout: 15)
        let openActions: Set<String> = ["ACK_OPEN", "NAK_HOSTILE", "NAK_INVALID", "NAK_NOSALE"]
        let openEnvelope: ParsedMessage
        if let directEnvelope = nativeTradeEnvelope(in: openReply),
           openActions.contains(directEnvelope.attributes["action"] ?? "") {
            openEnvelope = directEnvelope
        } else {
            openEnvelope = try await waitForNativeTradeAction(openActions, after: openStart)
        }
        guard openEnvelope.attributes["action"] == "ACK_OPEN" else {
            print("    native trade skipped: settlement replied \(openEnvelope.attributes["action"] ?? "unknown")")
            await client.disconnect()
            return
        }
        let openSession = NativeTradeSession(nativeTradeChild: nativeTradePayload(in: openEnvelope))
        guard !openSession.settlementToUnit.isEmpty || !openSession.unitToSettlement.isEmpty else {
            print("    native trade skipped: settlement returned no priced items")
            await client.disconnect()
            return
        }
        print("    native trade opened with \(openSession.settlementToUnit.count) buy / \(openSession.unitToSettlement.count) sell offers")

        session.settlementToUnit = openSession.settlementToUnit
        session.unitToSettlement = openSession.unitToSettlement
        let goldBefore = (await client.game).players[localPlayerId]?.gold ?? 0
        guard let item = openSession.settlementToUnit.first(where: {
            $0.priceIsValid && $0.price <= goldBefore && ($0.goodsType?.isEmpty == false)
        }) else {
            throw TestError(message: "native settlement returned no affordable buy offer")
        }

        let goodsType = item.goodsType ?? "goods"
        let cargoBefore = (await client.game).units[traderId]?.goods[goodsType] ?? 0

        // Haggling uses a discounted BUY offer; there is no separate HAGGLE action.
        var buyOffer = item
        let offerReduction = max(1, item.price / 10)
        buyOffer.price = max(1, item.price - offerReduction)
        let buyStart = delegate.receivedPayloads.count
        let buyActions: Set<String> = ["ACK_BUY", "ACK_BUY_HAGGLE", "NAK_GOODS", "NAK_HAGGLE", "NAK_HOSTILE", "NAK_INVALID", "NAK_NOSALE"]
        let buyRequest = session.toMessage(action: "BUY", item: buyOffer)
        let buyReply = try await client.ask(message: buyRequest, timeout: 15)
        let firstEnvelope: ParsedMessage
        if let directEnvelope = nativeTradeEnvelope(in: buyReply),
           buyActions.contains(directEnvelope.attributes["action"] ?? "") {
            firstEnvelope = directEnvelope
        } else {
            firstEnvelope = try await waitForNativeTradeAction(buyActions, after: buyStart)
        }
        guard let firstAction = firstEnvelope.attributes["action"] else {
            throw TestError(message: "native trade BUY returned an acknowledgement without an action")
        }

        var finalAction = firstAction
        var negotiatedPrice = buyOffer.price
        var purchaseEnvelope = firstEnvelope
        if firstAction != "ACK_BUY" && firstAction != "ACK_BUY_HAGGLE" {
            print("    native trade BUY offer declined: \(firstAction)")
            await client.disconnect()
            return
        }
        if firstAction == "ACK_BUY_HAGGLE" {
            let counterSession = NativeTradeSession(nativeTradeChild: nativeTradePayload(in: firstEnvelope))
            guard let counterItem = counterSession.item else {
                throw TestError(message: "native trade haggle acknowledgement omitted counter-offer")
            }
            negotiatedPrice = counterItem.price
            print("    Java counter-offered \(negotiatedPrice) gold after \(buyOffer.price) gold offer")
            let acceptStart = delegate.receivedPayloads.count
            let acceptReply = try await client.ask(message: session.toMessage(action: "BUY", item: counterItem), timeout: 15)
            let acceptEnvelope: ParsedMessage
            if let directEnvelope = nativeTradeEnvelope(in: acceptReply),
               buyActions.contains(directEnvelope.attributes["action"] ?? "") {
                acceptEnvelope = directEnvelope
            } else {
                acceptEnvelope = try await waitForNativeTradeAction(buyActions, after: acceptStart)
            }
            purchaseEnvelope = acceptEnvelope
            finalAction = acceptEnvelope.attributes["action"] ?? "unknown"
        } else {
            print("    Java responded to discounted BUY with \(firstAction)")
        }
        guard finalAction == "ACK_BUY" else {
            print("    native trade negotiation ended with \(finalAction); no purchase completed")
            await client.disconnect()
            return
        }
        var tradeObserved = false
        for _ in 0..<50 {
            game = await client.game
            let cargoAfter = game.units[traderId]?.goods[goodsType] ?? 0
            let goldAfter = game.players[localPlayerId]?.gold ?? goldBefore
            if cargoAfter > cargoBefore && goldAfter < goldBefore {
                tradeObserved = true
                break
            }
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        guard tradeObserved else {
            let cargoAfter = game.units[traderId]?.goods[goodsType] ?? 0
            let goldAfter = game.players[localPlayerId]?.gold ?? goldBefore
            throw TestError(message: "Java acknowledged BUY but cargo/gold did not change (cargo \(cargoBefore)->\(cargoAfter), gold \(goldBefore)->\(goldAfter), messages \(delegate.receivedPayloads.suffix(8).map(\.tag)))")
        }
        print("    bought \(goodsType) for negotiated price \(negotiatedPrice)")

        let postPurchaseSession = NativeTradeSession(nativeTradeChild: nativeTradePayload(in: purchaseEnvelope))
        if let sellItem = postPurchaseSession.unitToSettlement.first(where: {
            $0.goodsType == goodsType && $0.priceIsValid
        }) {
            let goldBeforeSale = (await client.game).players[localPlayerId]?.gold ?? 0
            let cargoBeforeSale = (await client.game).units[traderId]?.goods[goodsType] ?? 0
            let sellStart = delegate.receivedPayloads.count
            let sellActions: Set<String> = ["ACK_SELL", "ACK_SELL_HAGGLE", "NAK_GOODS", "NAK_HAGGLE", "NAK_HOSTILE", "NAK_INVALID", "NAK_NOSALE"]
            let sellReply = try await client.ask(message: session.toMessage(action: "SELL", item: sellItem), timeout: 15)
            let sellEnvelope: ParsedMessage
            if let directEnvelope = nativeTradeEnvelope(in: sellReply),
               sellActions.contains(directEnvelope.attributes["action"] ?? "") {
                sellEnvelope = directEnvelope
            } else {
                sellEnvelope = try await waitForNativeTradeAction(sellActions, after: sellStart)
            }
            let sellAction = sellEnvelope.attributes["action"] ?? "unknown"
            if sellAction == "ACK_SELL" {
                var saleObserved = false
                for _ in 0..<50 {
                    game = await client.game
                    let cargoAfterSale = game.units[traderId]?.goods[goodsType] ?? 0
                    let goldAfterSale = game.players[localPlayerId]?.gold ?? goldBeforeSale
                    if cargoAfterSale < cargoBeforeSale && goldAfterSale > goldBeforeSale {
                        saleObserved = true
                        break
                    }
                    try await Task.sleep(nanoseconds: 200_000_000)
                }
                guard saleObserved else {
                    throw TestError(message: "Java acknowledged SELL but cargo/gold did not change")
                }
                print("    sold \(goodsType) to the settlement")
            } else {
                print("    native settlement declined SELL: \(sellAction)")
            }
        }

        // CLOSE session.
        let closeStart = delegate.receivedPayloads.count
        try await client.send(message: session.toMessage(action: "CLOSE", item: nil))
        for _ in 0..<10 {
            if let error = delegate.receivedPayloads.dropFirst(closeStart).first(where: { $0.tag == "error" }) {
                throw TestError(message: "native trade CLOSE rejected: \(error.attributes["message"] ?? "unknown error")")
            }
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        print("    native trade session closed")

        await client.disconnect()
    }

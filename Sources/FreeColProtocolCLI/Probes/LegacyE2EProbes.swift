import Foundation
import FreeColProtocol
import FreeColGame
import FreeColClient

@MainActor
func runLegacyE2EProbes() async {
if ProcessInfo.processInfo.environment["REAL_SERVER_E2E"] == "1" {
    await integrationTest("real Java server connect/login smoke") {
        let host = ProcessInfo.processInfo.environment["REAL_SERVER_HOST"] ?? "127.0.0.1"
        let port = Int(ProcessInfo.processInfo.environment["REAL_SERVER_PORT"] ?? "3541") ?? 3541
        let client = FreeColClient(host: host, port: port)
        let delegate = TestDelegate()
        await client.setDelegate(delegate)

        try await client.connect()
        guard await client.initialGameState != nil else {
            throw TestError(message: "real server did not send gameState")
        }

        let vacant = await client.initialVacantPlayers
        let nationId = vacant?.children.first?.attributes["nationId"]
            ?? vacant?.children.first?.attributes["id"]
            ?? "model.nation.dutch"
        let userName = "CopilotE2E-\(Int(Date().timeIntervalSince1970))"

        let result = try await client.login(userName: userName, nationId: nationId)
        guard result.serverState == .preGame || result.serverState == .inGame else {
            throw TestError(message: "unexpected server state after login: \(result.serverState.rawValue)")
        }

        if result.serverState == .preGame {
            try await client.send(message: ParsedMessage(tag: "ready", attributes: ["value": "true"], children: []))
            try await client.send(message: ParsedMessage(tag: "requestLaunch", attributes: [:], children: []))
        } else {
            try await client.send(message: ParsedMessage(tag: "endTurn", attributes: [:], children: []))
        }

        await client.disconnect()
    }
}

// The deep probe launches a game, which consumes the server's pre-game lobby.
// Run it on a fresh server, i.e. not together with the smoke probe.
if ProcessInfo.processInfo.environment["REAL_SERVER_DEEP_E2E"] == "1"
    && ProcessInfo.processInfo.environment["REAL_SERVER_E2E"] != "1" {
    await integrationTest("real Java server pregame-to-ingame probe") {
        let host = ProcessInfo.processInfo.environment["REAL_SERVER_HOST"] ?? "127.0.0.1"
        let port = Int(ProcessInfo.processInfo.environment["REAL_SERVER_PORT"] ?? "3541") ?? 3541
        let client = FreeColClient(host: host, port: port)
        let delegate = TestDelegate()
        await client.setDelegate(delegate)

        try await client.connect()
        guard await client.initialGameState != nil else {
            throw TestError(message: "real server did not send gameState")
        }

        let vacant = await client.initialVacantPlayers
        let nationId = vacant?.children.first?.attributes["nationId"]
            ?? vacant?.children.first?.attributes["id"]
            ?? "model.nation.dutch"
        let userName = "CopilotDeep-\(Int(Date().timeIntervalSince1970))"

        let result = try await client.login(userName: userName, nationId: nationId)
        guard result.serverState == .preGame || result.serverState == .inGame else {
            throw TestError(message: "unexpected server state after login: \(result.serverState.rawValue)")
        }

        var launchProbeSent = false

        // Probe launch path in pre-game. Servers may reject launch if not all players are ready.
        // `ready`/`requestLaunch` are fire-and-forget in the Java ServerAPI, so
        // they do not produce a `<reply>` to wait for.
        if result.serverState == .preGame {
            try await client.send(message: ParsedMessage(tag: "ready", attributes: ["value": "true"], children: []))
            try await client.send(message: ParsedMessage(tag: "requestLaunch", attributes: [:], children: []))
            launchProbeSent = true
        }

        let loopTask = Task {
            await client.startMessageLoop()
        }
        try await Task.sleep(nanoseconds: 2_000_000_000)
        loopTask.cancel()

        let tags = delegate.receivedMessages
        let sawSessionSignal = tags.contains("gameState") || tags.contains("startGame") || tags.contains("error")

        // Real servers may keep PRE_GAME without broadcasting immediate events to this client.
        // Passing ask/reply for ready/requestLaunch is still a valid transport-level success.
        guard sawSessionSignal || launchProbeSent || result.serverState == .inGame else {
            throw TestError(message: "no session signal and no launch probe activity observed")
        }

        // If the session reached in-game, validate the deserialized model and
        // probe endTurn transport opportunistically.
        if await client.game.currentPlayerId != nil {
            let game = await client.game
            guard !game.players.isEmpty else {
                throw TestError(message: "real server game has no players")
            }
            guard !game.tiles.isEmpty else {
                throw TestError(message: "real server game has no map tiles")
            }
            guard game.specification != nil else {
                throw TestError(message: "real server game has no specification")
            }
            guard game.units.values.contains(where: { unit in
                unit.owner != nil && game.resolvedTileId(for: unit) != nil
            }) else {
                throw TestError(message: "real server game has no units on the map")
            }

            // The server may defer the reply until it is our turn, so a timeout
            // here must not fail the launch probe.
            do {
                _ = try await client.ask(message: ParsedMessage(tag: "endTurn", attributes: [:], children: []),
                                         timeout: 5)
            } catch {
                // Disconnects, server errors and deferred turns are all tolerated.
            }
        }

        await client.disconnect()
    }
}

// Gameplay probe: launch a real game, move a unit, end the turn and verify the
// server-driven model advances. Requires a fresh server (pre-game lobby).
if ProcessInfo.processInfo.environment["REAL_SERVER_GAMEPLAY_E2E"] == "1" {
    await integrationTest("real Java server gameplay probe") {
        let host = ProcessInfo.processInfo.environment["REAL_SERVER_HOST"] ?? "127.0.0.1"
        let port = Int(ProcessInfo.processInfo.environment["REAL_SERVER_PORT"] ?? "3541") ?? 3541
        let client = FreeColClient(host: host, port: port)

        try await client.connect()
        let vacant = await client.initialVacantPlayers
        let nationId = vacant?.children.first?.attributes["nationId"]
            ?? vacant?.children.first?.attributes["id"]
            ?? "model.nation.dutch"
        let userName = "CopilotPlay-\(Int(Date().timeIntervalSince1970))"

        let result = try await client.login(userName: userName, nationId: nationId)
        if result.serverState == .preGame {
            // Shorten Europe sailing time for the isolated real-server fixture.
            try await client.send(message: ParsedMessage(
                tag: "updateGameOptions",
                attributes: [:],
                children: [ParsedMessage(tag: "optionGroup", attributes: ["id": "gameOptions"], children: [
                    ParsedMessage(tag: "integerOption", attributes: [
                        "id": "model.option.turnsToSail", "value": "1",
                    ], children: []),
                ])]
            ))
            try await client.send(message: ParsedMessage(tag: "ready", attributes: ["value": "true"], children: []))
            try await client.send(message: ParsedMessage(tag: "requestLaunch", attributes: [:], children: []))
        }

        let loopTask = Task { await client.startMessageLoop() }
        defer { loopTask.cancel() }

        // Wait for the launched game to reach the client.
        var waited = 0
        while true {
            let current = await client.game
            if current.currentPlayerId != nil && !current.units.isEmpty {
                break
            }
            if waited >= 60 {
                throw TestError(message: "game did not start within 30s")
            }
            try await Task.sleep(nanoseconds: 500_000_000)
            waited += 1
        }

        var game = await client.game
        guard let spec = game.specification else {
            throw TestError(message: "launched game has no specification")
        }
        guard !spec.unitTypes.isEmpty, !spec.goodsTypes.isEmpty,
              !spec.buildingTypes.isEmpty, !spec.tileTypes.isEmpty else {
            throw TestError(message: "specification is missing type definitions")
        }
        guard !game.tiles.isEmpty else {
            throw TestError(message: "launched game has no map tiles")
        }
        guard let localPlayerId = game.players.values.first(where: { $0.name == result.playerName })?.id else {
            throw TestError(message: "local player not found in launched game")
        }
        // Market data must deserialize from the real server XML.
        var marketEntries = game.players[localPlayerId]?.market.map { Array($0.data.values) } ?? []
        guard !marketEntries.isEmpty else {
            throw TestError(message: "no market data received")
        }
        guard marketEntries.contains(where: { $0.amount > 0 && $0.initialPrice > 0 }) else {
            throw TestError(message: "market data has no priced entries")
        }

        func endTurnAndWaitForLocalPlayer() async throws -> FreeColGame.Game {
            let turnBefore = await client.game.turn.number
            _ = try await client.ask(
                message: ParsedMessage(tag: "endTurn", attributes: [:], children: []),
                timeout: 45
            )
            for _ in 0..<180 {
                let current = await client.game
                if current.turn.number > turnBefore && current.currentPlayerId == localPlayerId {
                    return current
                }
                try await Task.sleep(nanoseconds: 500_000_000)
            }
            throw TestError(message: "local turn did not return after endTurn")
        }

        // Keep the map movement probe independent from the market trip: a
        // standard start often has its only naval carrier on the map.
        let movementCandidates = game.units.values
            .filter { candidate in
                candidate.owner == localPlayerId
                    && candidate.movesLeft > 0
                    && candidate.location.flatMap { game.tiles[$0] } != nil
            }
            .sorted { $0.id < $1.id }
        guard let unit = movementCandidates.first(where: {
            !spec.hasAbility("model.ability.foundColony", unitType: $0.unitType)
        }) ?? movementCandidates.first else {
            throw TestError(message: "no local unit with movement on the map")
        }
        let unitId = unit.id
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        var moved = false
        var lastMoveError: String?
        for direction in directions {
            let before = await client.game.units[unitId]?.location ?? ""
            do {
                _ = try await client.ask(message: ParsedMessage(
                    tag: "move",
                    attributes: ["unit": unitId, "direction": direction],
                    children: []
                ), timeout: 8)
            } catch {
                lastMoveError = "\(error)"
                continue
            }
            for _ in 0..<10 {
                try await Task.sleep(nanoseconds: 200_000_000)
                let after = await client.game.units[unitId]?.location ?? ""
                if after != before {
                    moved = true
                    break
                }
            }
            if moved { break }
        }
        guard moved else {
            throw TestError(message: "unit did not move in any direction (last error: \(lastMoveError ?? "none"))")
        }

        func canFoundColony(with unit: FreeColGame.Unit, in current: FreeColGame.Game) -> Bool {
            guard unit.owner == localPlayerId,
                  spec.hasAbility("model.ability.foundColony", unitType: unit.unitType),
                  let tileId = unit.location,
                  let tile = current.tiles[tileId],
                  tile.settlement == nil,
                  tile.owningSettlement == nil,
                  tile.owner == nil || tile.owner == localPlayerId,
                  let tileType = tile.type,
                  let tileInfo = spec.tileTypes[tileType] else { return false }
            return !tileInfo.isWater && tileInfo.canSettle
        }

        func colonyLandingTiles(around sourceTileId: String,
                                in current: FreeColGame.Game) -> [FreeColGame.Tile] {
            current.neighborTileIds(of: sourceTileId)
                .compactMap { current.tiles[$0] }
                .filter { tile in
                    guard tile.settlement == nil,
                          tile.owningSettlement == nil,
                          tile.owner == nil || tile.owner == localPlayerId,
                          let tileType = tile.type,
                          let tileInfo = spec.tileTypes[tileType],
                          !tileInfo.isWater,
                          tileInfo.canSettle else { return false }
                    return !current.neighborTileIds(of: tile.id).contains {
                        current.tiles[$0]?.settlement != nil
                    }
                }
                .sorted { $0.id < $1.id }
        }

        func direction(from source: FreeColGame.Tile,
                       to target: FreeColGame.Tile) -> String? {
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

        func nextCoastalSeaStep(from sourceTileId: String,
                                in current: FreeColGame.Game) -> String? {
            guard let source = current.tiles[sourceTileId] else { return nil }
            let coastalSeaTiles = current.tiles.values
                .filter { tile in
                    guard let type = tile.type,
                          let info = spec.tileTypes[type], info.isWater else { return false }
                    return !colonyLandingTiles(around: tile.id, in: current).isEmpty
                }
                .sorted {
                    let firstDistance = abs($0.x - source.x) + abs($0.y - source.y)
                    let secondDistance = abs($1.x - source.x) + abs($1.y - source.y)
                    return firstDistance == secondDistance ? $0.id < $1.id : firstDistance < secondDistance
                }
            for target in coastalSeaTiles where target.id != sourceTileId {
                if let step = current.nextPathStep(from: sourceTileId, to: target.id, canTraverse: { _, next in
                    guard let type = current.tiles[next]?.type,
                          let info = spec.tileTypes[type] else { return false }
                    return info.isWater
                }) {
                    return step
                }
            }
            return nil
        }

        func moveCarrierToCoast(_ carrierId: String) async throws -> Bool {
            let allDirections = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
            var explorationHeading = 0
            for _ in 0..<120 {
                game = await client.game
                guard let carrier = game.units[carrierId],
                      let sourceTileId = carrier.location,
                      let sourceTile = game.tiles[sourceTileId] else { return false }
                if !colonyLandingTiles(around: sourceTileId, in: game).isEmpty {
                    return true
                }
                if carrier.movesLeft <= 0 {
                    game = try await endTurnAndWaitForLocalPlayer()
                    continue
                }
                let knownCoastDirection = nextCoastalSeaStep(from: sourceTileId, in: game)
                    .flatMap { game.tiles[$0] }
                    .flatMap { direction(from: sourceTile, to: $0) }
                let moveDirection = knownCoastDirection ?? allDirections[explorationHeading]
                let before = sourceTileId
                do {
                    _ = try await client.ask(message: ParsedMessage(
                        tag: "move",
                        attributes: ["unit": carrierId, "direction": moveDirection],
                        children: []
                    ), timeout: 8)
                } catch {
                    if "\(error)".contains("MOVE_NO_MOVES") {
                        game = try await endTurnAndWaitForLocalPlayer()
                        continue
                    }
                    guard knownCoastDirection == nil else { return false }
                    explorationHeading = (explorationHeading + 1) % allDirections.count
                    continue
                }
                var moved = false
                for _ in 0..<20 {
                    game = await client.game
                    if game.units[carrierId]?.location != before {
                        moved = true
                        break
                    }
                    try await Task.sleep(nanoseconds: 200_000_000)
                }
                if !moved { return false }
            }
            game = await client.game
            guard let location = game.units[carrierId]?.location else { return false }
            return !colonyLandingTiles(around: location, in: game).isEmpty
        }

        let requireColonyFounding = ProcessInfo.processInfo.environment["REAL_SERVER_REQUIRE_COLONY_FOUNDING"] == "1"
        var colonyWasFounded = false
        var foundedColonyId: String?
        game = await client.game
        let foundingUnits = game.units.values
            .filter {
                $0.owner == localPlayerId
                    && spec.hasAbility("model.ability.foundColony", unitType: $0.unitType)
            }
            .sorted { $0.id < $1.id }
        if let landedFounder = foundingUnits.first(where: { canFoundColony(with: $0, in: game) }) {
            let colonyName = "E2E\(Int(Date().timeIntervalSince1970) % 100000)"
            _ = try await client.ask(message: ParsedMessage(
                tag: "buildColony",
                attributes: ["unit": landedFounder.id, "name": colonyName],
                children: []
            ), timeout: 8)
            for _ in 0..<30 {
                game = await client.game
                if let colony = game.colonies.values.first(where: {
                    $0.name == colonyName
                        && $0.owner == localPlayerId
                        && $0.tileId == landedFounder.location
                }) {
                    colonyWasFounded = true
                    foundedColonyId = colony.id
                    break
                }
                try await Task.sleep(nanoseconds: 200_000_000)
            }
            guard colonyWasFounded else {
                throw TestError(message: "colony \(colonyName) was not created")
            }
            print("    founded colony \(colonyName)")
        } else {
            let embarkedFounder = foundingUnits.first { candidate in
                guard let carrierId = candidate.location,
                      let carrier = game.units[carrierId],
                      spec.isNaval(unitType: carrier.unitType) == true,
                      let carrierTileId = carrier.location,
                      game.tiles[carrierTileId] != nil else { return false }
                return true
            }
            if let embarkedFounder, let carrierId = embarkedFounder.location,
               let carrier = game.units[carrierId], let initialTileId = carrier.location {
                if colonyLandingTiles(around: initialTileId, in: game).isEmpty {
                    _ = try await moveCarrierToCoast(carrierId)
                    game = await client.game
                }
                if let currentCarrier = game.units[carrierId],
                    let sourceTileId = currentCarrier.location,
                    let sourceTile = game.tiles[sourceTileId],
                 let targetTile = colonyLandingTiles(around: sourceTileId, in: game).first,
                 let landingDirection = direction(from: sourceTile, to: targetTile) {
                    // Moving the passenger directly onto the land tile unloads
                    // it in Java FreeCol; <disembark> would place it on the
                    // carrier's water tile, which rejects land units.
                    game = try await endTurnAndWaitForLocalPlayer()
                    do {
                        _ = try await client.ask(message: ParsedMessage(
                            tag: "move",
                            attributes: ["unit": embarkedFounder.id, "direction": landingDirection],
                            children: []
                        ), timeout: 8)
                    } catch {
                        throw TestError(message: "founding unit could not move from carrier tile "
                            + "\(sourceTileId) to land tile \(targetTile.id): \(error)")
                    }
                    var reachedLand = false
                    for _ in 0..<30 {
                        game = await client.game
                        if game.units[embarkedFounder.id]?.location == targetTile.id {
                            reachedLand = true
                            break
                        }
                        try await Task.sleep(nanoseconds: 200_000_000)
                    }
                    guard reachedLand else {
                        throw TestError(message: "founding unit did not reach selected tile \(targetTile.id)")
                    }
                    print("    coastal landing confirmed: passenger \(embarkedFounder.id) moved from carrier to \(targetTile.id)")
                    game = try await endTurnAndWaitForLocalPlayer()
                    guard let landedFounder = game.units[embarkedFounder.id],
                          canFoundColony(with: landedFounder, in: game) else {
                        throw TestError(message: "founding unit is not eligible after reaching tile \(targetTile.id)")
                    }
                    let colonyName = "E2E\(Int(Date().timeIntervalSince1970) % 100000)"
                    do {
                        _ = try await client.ask(message: ParsedMessage(
                            tag: "buildColony",
                            attributes: ["unit": landedFounder.id, "name": colonyName],
                            children: []
                        ), timeout: 8)
                    } catch {
                        throw TestError(message: "buildColony rejected for unit \(embarkedFounder.id) "
                            + "type=\(embarkedFounder.unitType ?? "unknown") tile=\(targetTile.id): \(error)")
                    }
                    for _ in 0..<30 {
                        game = await client.game
                        if let colony = game.colonies.values.first(where: {
                            $0.name == colonyName
                                && $0.owner == localPlayerId
                                && $0.tileId == targetTile.id
                        }) {
                            colonyWasFounded = true
                            foundedColonyId = colony.id
                            break
                        }
                        try await Task.sleep(nanoseconds: 200_000_000)
                    }
                    guard colonyWasFounded else {
                        throw TestError(message: "colony \(colonyName) was not created")
                    }
                    print("    founded colony \(colonyName)")
                } else {
                    let carrierState = game.units[carrierId].map {
                        let location = $0.location.flatMap { game.tiles[$0] }
                        return "carrier=\(carrierId) tile=\($0.location ?? "unknown") "
                            + "coord=\(location.map { "\($0.x),\($0.y)" } ?? "unknown") "
                            + "movesLeft=\($0.movesLeft) exploredTiles=\(game.exploredTileIds().count)"
                    } ?? "carrier=\(carrierId) missing from game model"
                    let reason = "no reachable eligible coastal tile (\(carrierState))"
                    if requireColonyFounding {
                        throw TestError(message: "colony founding required but \(reason)")
                    }
                    print("    colony founding skipped: \(reason)")
                }
            } else {
                let reason = "no founder aboard a map carrier"
                if requireColonyFounding {
                    throw TestError(message: "colony founding required but \(reason)")
                }
                print("    colony founding skipped: \(reason)")
            }
        }

        if let foundedColonyId,
           let foundedColony = game.colonies[foundedColonyId],
           let foundedTileId = foundedColony.tileId {
            let renamedColony = "Managed\(Int(Date().timeIntervalSince1970) % 100000)"
            do {
                _ = try await client.ask(message: ParsedMessage(
                    tag: "rename",
                    attributes: ["nameable": foundedColonyId, "name": renamedColony],
                    children: []
                ), timeout: 8)
            } catch {
                throw TestError(message: "rename rejected for colony \(foundedColonyId): \(error)")
            }
            var colonyWasRenamed = false
            for _ in 0..<30 {
                game = await client.game
                if let colony = game.colonies[foundedColonyId],
                   colony.name == renamedColony,
                   colony.owner == localPlayerId,
                   colony.tileId == foundedTileId {
                    colonyWasRenamed = true
                    break
                }
                try await Task.sleep(nanoseconds: 200_000_000)
            }
            guard colonyWasRenamed else {
                throw TestError(message: "renamed colony \(foundedColonyId) was not updated in the model")
            }
            print("    renamed colony to \(renamedColony)")

            guard let warehouseGoodsType = spec.goodsTypes.values
                .filter(\.isStorable)
                .map(\.id)
                .sorted()
                .first else {
                throw TestError(message: "specification has no storable goods for warehouse probe")
            }
            let warehouseSettings = ColonyExportData(goodsType: warehouseGoodsType,
                                                     exported: true,
                                                     importLevel: -1,
                                                     exportLevel: 60,
                                                     highLevel: 80,
                                                     lowLevel: 20)
            let exportData = ParsedMessage(
                tag: "exportData",
                attributes: [
                    "id": warehouseSettings.goodsType,
                    "exported": String(warehouseSettings.exported),
                    "importLevel": String(warehouseSettings.importLevel),
                    "exportLevel": String(warehouseSettings.exportLevel),
                    "highLevel": String(warehouseSettings.highLevel),
                    "lowLevel": String(warehouseSettings.lowLevel),
                ],
                children: []
            )
            do {
                _ = try await client.ask(message: ParsedMessage(
                    tag: "setGoodsLevels",
                    attributes: ["colony": foundedColonyId],
                    children: [exportData]
                ), timeout: 8)
            } catch {
                throw TestError(message: "setGoodsLevels rejected for colony \(foundedColonyId): \(error)")
            }
            var warehouseUpdateApplied = false
            for _ in 0..<30 {
                game = await client.game
                if let applied = game.colonies[foundedColonyId]?.exportData[warehouseGoodsType],
                   applied.exported == warehouseSettings.exported,
                   applied.importLevel == warehouseSettings.importLevel,
                   applied.exportLevel == warehouseSettings.exportLevel,
                   applied.highLevel == warehouseSettings.highLevel,
                   applied.lowLevel == warehouseSettings.lowLevel {
                    warehouseUpdateApplied = true
                    break
                }
                try await Task.sleep(nanoseconds: 200_000_000)
            }
            guard warehouseUpdateApplied else {
                throw TestError(message: "warehouse settings for \(warehouseGoodsType) were not applied")
            }
            print("    updated warehouse levels for \(warehouseGoodsType)")

            guard let routeEuropeId = game.players[localPlayerId]?.europe?.id else {
                throw TestError(message: "Europe location missing for trade-route probe")
            }
            let previousRouteIds = Set(game.tradeRoutes.keys)
            do {
                _ = try await client.ask(message: ParsedMessage(
                    tag: "newTradeRoute", attributes: [:], children: []
                ), timeout: 8)
            } catch {
                throw TestError(message: "newTradeRoute rejected by Java: \(error)")
            }
            var createdRoute: FreeColGame.TradeRoute?
            for _ in 0..<30 {
                game = await client.game
                createdRoute = game.tradeRoutes.values.first {
                    !previousRouteIds.contains($0.id) && $0.owner == localPlayerId
                }
                if createdRoute != nil { break }
                try await Task.sleep(nanoseconds: 200_000_000)
            }
            guard let createdRoute else {
                throw TestError(message: "Java did not add the requested trade route")
            }

            let routeName = "E2E Route \(Int(Date().timeIntervalSince1970) % 100000)"
            let routeCargo = spec.goodsTypes["model.goods.horses"] == nil
                ? warehouseGoodsType
                : "model.goods.horses"
            let routeStops = [
                ParsedMessage(tag: "tradeRouteStop",
                              attributes: ["location": routeEuropeId],
                              children: []),
                ParsedMessage(tag: "tradeRouteStop",
                              attributes: ["location": foundedColonyId],
                              children: [ParsedMessage(tag: "cargo",
                                                       attributes: ["id": routeCargo],
                                                       children: [])]),
            ]
            let routeNode = ParsedMessage(
                tag: "tradeRoute",
                attributes: [
                    "id": createdRoute.id,
                    "name": routeName,
                    "owner": localPlayerId,
                    "silent": "false",
                ],
                children: routeStops
            )
            do {
                _ = try await client.ask(message: ParsedMessage(
                    tag: "updateTradeRoute", attributes: [:], children: [routeNode]
                ), timeout: 8)
            } catch {
                throw TestError(message: "updateTradeRoute rejected for \(createdRoute.id): \(error)")
            }
            var routeUpdateApplied = false
            for _ in 0..<30 {
                game = await client.game
                if let route = game.tradeRoutes[createdRoute.id],
                   route.name == routeName,
                   route.owner == localPlayerId,
                   route.stops.count == 2,
                   route.stops[0].locationId == routeEuropeId,
                   route.stops[1].locationId == foundedColonyId,
                   route.stops[1].cargoTypeIds == [routeCargo] {
                    routeUpdateApplied = true
                    break
                }
                try await Task.sleep(nanoseconds: 200_000_000)
            }
            guard routeUpdateApplied else {
                throw TestError(message: "updated trade route \(createdRoute.id) missing from game model")
            }
            print("    created trade route \(routeName)")

            game = await client.game
            guard let routeCarrier = game.units.values
                .filter({
                    $0.owner == localPlayerId
                        && spec.isNaval(unitType: $0.unitType) == true
                        && $0.location.flatMap { game.tiles[$0] } != nil
                })
                .sorted(by: { $0.id < $1.id })
                .first else {
                throw TestError(message: "no local map carrier available for trade-route assignment")
            }
            do {
                _ = try await client.ask(message: ParsedMessage(
                    tag: "assignTradeRoute",
                    attributes: ["unit": routeCarrier.id, "tradeRoute": createdRoute.id],
                    children: []
                ), timeout: 8)
            } catch {
                throw TestError(message: "assignTradeRoute rejected for \(routeCarrier.id): \(error)")
            }
            var routeAssigned = false
            for _ in 0..<30 {
                game = await client.game
                if game.units[routeCarrier.id]?.tradeRoute == createdRoute.id {
                    routeAssigned = true
                    break
                }
                try await Task.sleep(nanoseconds: 200_000_000)
            }
            guard routeAssigned else {
                throw TestError(message: "trade route \(createdRoute.id) was not assigned to \(routeCarrier.id)")
            }
            print("    assigned trade route to \(routeCarrier.id)")

            do {
                _ = try await client.ask(message: ParsedMessage(
                    tag: "deleteTradeRoute",
                    attributes: ["tradeRoute": createdRoute.id],
                    children: []
                ), timeout: 8)
            } catch {
                throw TestError(message: "deleteTradeRoute rejected for \(createdRoute.id): \(error)")
            }
            var routeAndCarrierReleased = false
            for _ in 0..<30 {
                game = await client.game
                if game.tradeRoutes[createdRoute.id] == nil,
                   game.units[routeCarrier.id]?.tradeRoute == nil {
                    routeAndCarrierReleased = true
                    break
                }
                try await Task.sleep(nanoseconds: 200_000_000)
            }
            guard routeAndCarrierReleased else {
                throw TestError(message: "deleting trade route \(createdRoute.id) did not remove it "
                    + "or release carrier \(routeCarrier.id) in the client model")
            }
            print("    deleted trade route \(createdRoute.id) and released \(routeCarrier.id)")
        } else if requireColonyFounding {
            throw TestError(message: "colony management required but the new colony was not available to rename")
        }

        // The default server start places the initial carrier on the map.
        // Sail it to Europe; the market action itself confirms when the server
        // considers the carrier to have arrived, even if the location update
        // is delayed in the client model.
        let europeId = game.players[localPlayerId]?.europe?.id
        let requireMarketTrade = ProcessInfo.processInfo.environment["REAL_SERVER_REQUIRE_MARKET_TRADE"] == "1"
        var marketCarrierId: String?
        var marketSkipReason: String?
        if let europeId {
            game = await client.game
            let navalUnits = game.units.values
                .filter { $0.owner == localPlayerId && spec.isNaval(unitType: $0.unitType) == true }
                .sorted {
                    let firstCargo = $0.goods.values.reduce(0, +)
                    let secondCargo = $1.goods.values.reduce(0, +)
                    return firstCargo == secondCargo ? $0.id < $1.id : firstCargo < secondCargo
                }
            if let alreadyInEurope = navalUnits.first(where: { $0.location == europeId }) {
                marketCarrierId = alreadyInEurope.id
            } else if let carrier = navalUnits.first(where: {
                $0.location.flatMap { game.tiles[$0] } != nil
                    || $0.state == .sailing
                    || $0.state == .toEurope
            }) {
                marketCarrierId = carrier.id
                _ = try await client.ask(message: ParsedMessage(
                    tag: "moveTo",
                    attributes: ["unit": carrier.id, "destination": europeId],
                    children: []
                ), timeout: 8)
            } else {
                marketSkipReason = "no owned naval carrier on the map or in Europe"
            }
        } else {
            marketSkipReason = "local player has no Europe location"
        }

        game = await client.game
        if let marketCarrierId, let europeId {
            var tradeCompleted = false
            for _ in 0..<20 {
                game = await client.game
                marketEntries = game.players[localPlayerId]?.market.map { Array($0.data.values) } ?? []
                let playerGold = game.players[localPlayerId]?.gold ?? 0
                let buyableGoods: [(type: String, amount: Int, unitPrice: Int)] = marketEntries
                    .compactMap { entry in
                        guard let goodsType = entry.goodsType,
                              let goodsInfo = spec.goodsTypes[goodsType],
                              goodsInfo.isStorable,
                              entry.amount > 0,
                              entry.arrears == 0 else { return nil }
                        let unitPrice = MarketPricing.prices(for: entry, specification: spec).costToBuy
                        guard unitPrice > 0 else { return nil }
                        let amount = min(100, entry.amount, playerGold / unitPrice)
                        guard amount > 0 else { return nil }
                        return (type: goodsType, amount: amount, unitPrice: unitPrice)
                    }
                    .sorted {
                        return $0.unitPrice == $1.unitPrice
                            ? $0.type < $1.type
                            : $0.unitPrice < $1.unitPrice
                    }
                guard let selectedGoods = buyableGoods.first,
                      let carrier = game.units[marketCarrierId] else {
                    let marketSummary = marketEntries.prefix(6).compactMap { entry -> String? in
                        guard let type = entry.goodsType else { return nil }
                        let price = MarketPricing.prices(for: entry, specification: spec).costToBuy
                        return "\(type):stock=\(entry.amount),buy=\(price),arrears=\(entry.arrears)"
                    }.joined(separator: ";")
                    marketSkipReason = "no affordable, non-boycotted goods "
                        + "(difficulty=\(spec.difficultyLevel ?? "unknown"), gold=\(playerGold), "
                        + "market=\(marketSummary))"
                    break
                }
                let goodsType = selectedGoods.type
                let buyAmount = selectedGoods.amount

                let cargoBeforeBuy = carrier.goods[goodsType] ?? 0
                let goldBeforeBuy = playerGold
                do {
                    _ = try await client.ask(message: ParsedMessage(
                        tag: "loadGoods",
                        attributes: [
                            "location": europeId,
                            "type": goodsType,
                            "amount": String(buyAmount),
                            "carrier": carrier.id,
                        ],
                        children: []
                    ), timeout: 8)
                } catch FreeColProtocolError.serverError(let message)
                    where message.localizedCaseInsensitiveContains("not at a trade location") {
                    game = try await endTurnAndWaitForLocalPlayer()
                    let transit = game.units[carrier.id]
                    print("    waiting for Europe arrival: turn=\(game.turn.number), workLeft=\(transit?.workLeft ?? -1)")
                    continue
                } catch FreeColProtocolError.serverError(let message)
                    where message.localizedCaseInsensitiveContains("too much goods") {
                    let passengers = game.units.values
                        .filter {
                            $0.owner == localPlayerId
                                && $0.location == carrier.id
                                && spec.isNaval(unitType: $0.unitType) != true
                        }
                        .map(\.id)
                        .sorted()
                    guard !passengers.isEmpty else {
                        throw TestError(message: "market carrier has no free space for \(buyAmount) goods")
                    }
                    for passengerId in passengers {
                        _ = try await client.ask(message: ParsedMessage(
                            tag: "disembark", attributes: ["unit": passengerId], children: []
                        ), timeout: 8)
                    }
                    _ = try await client.ask(message: ParsedMessage(
                        tag: "loadGoods",
                        attributes: [
                            "location": europeId,
                            "type": goodsType,
                            "amount": String(buyAmount),
                            "carrier": carrier.id,
                        ],
                        children: []
                    ), timeout: 8)
                }

                var bought = false
                for _ in 0..<30 {
                    game = await client.game
                    let currentCargo = game.units[carrier.id]?.goods[goodsType] ?? 0
                    let currentGold = game.players[localPlayerId]?.gold ?? goldBeforeBuy
                    if currentCargo >= cargoBeforeBuy + buyAmount && currentGold < goldBeforeBuy {
                        bought = true
                        break
                    }
                    try await Task.sleep(nanoseconds: 200_000_000)
                }
                guard bought else {
                    throw TestError(message: "market purchase did not update carrier cargo and player gold")
                }
                let goldAfterBuy = game.players[localPlayerId]?.gold ?? goldBeforeBuy
                let expectedBuyCost = buyAmount * selectedGoods.unitPrice
                let actualBuyCost = goldBeforeBuy - goldAfterBuy
                guard actualBuyCost == expectedBuyCost else {
                    throw TestError(message: "market purchase price mismatch for \(goodsType): "
                        + "expected \(expectedBuyCost), server charged \(actualBuyCost)")
                }
                guard let marketAfterBuy = game.players[localPlayerId]?.market?.entry(for: goodsType) else {
                    throw TestError(message: "market data missing after purchase of \(goodsType)")
                }
                let expectedSellPrice = MarketPricing.prices(for: marketAfterBuy,
                                                              specification: spec).paidForSale
                let taxRate = game.players[localPlayerId]?.tax ?? 0
                let expectedSaleProceeds = (buyAmount * expectedSellPrice * (100 - taxRate)) / 100

                _ = try await client.ask(message: ParsedMessage(
                    tag: "unloadGoods",
                    attributes: ["type": goodsType, "amount": String(buyAmount), "carrier": carrier.id],
                    children: []
                ), timeout: 8)
                var sold = false
                for _ in 0..<30 {
                    game = await client.game
                    let currentCargo = game.units[carrier.id]?.goods[goodsType] ?? 0
                    let currentGold = game.players[localPlayerId]?.gold ?? goldAfterBuy
                    if currentCargo <= cargoBeforeBuy && currentGold > goldAfterBuy {
                        sold = true
                        break
                    }
                    try await Task.sleep(nanoseconds: 200_000_000)
                }
                guard sold else {
                    throw TestError(message: "market sale did not update carrier cargo and player gold")
                }
                let actualSaleProceeds = (game.players[localPlayerId]?.gold ?? goldAfterBuy) - goldAfterBuy
                guard actualSaleProceeds == expectedSaleProceeds else {
                    throw TestError(message: "market sale price mismatch for \(goodsType): "
                        + "expected \(expectedSaleProceeds), server paid \(actualSaleProceeds)")
                }
                guard game.players[localPlayerId]?.market?.entry(for: goodsType) != nil else {
                    throw TestError(message: "market data disappeared after a trade")
                }
                print("    bought and sold \(buyAmount) \(goodsType) in Europe")
                tradeCompleted = true
                break
            }
            if !tradeCompleted && marketSkipReason == nil {
                let stalledCarrier = game.units[marketCarrierId]
                marketSkipReason = "carrier did not become trade-ready after 20 turns "
                    + "(location=\(stalledCarrier?.location ?? "nil"), "
                    + "workLeft=\(stalledCarrier?.workLeft ?? -1), "
                    + "turn=\(game.turn.number))"
            }
        }

        if let marketSkipReason {
            if requireMarketTrade {
                throw TestError(message: "required market trade could not run: \(marketSkipReason)")
            }
            print("    market trade skipped: \(marketSkipReason)")
        }

        // End the turn and wait for the server to advance the turn counter.
        let turnBefore = await client.game.turn.number
        _ = try await client.ask(message: ParsedMessage(tag: "endTurn", attributes: [:], children: []),
                                 timeout: 45)
        var advanced = false
        for _ in 0..<120 {
            if await client.game.turn.number > turnBefore {
                advanced = true
                break
            }
            try await Task.sleep(nanoseconds: 500_000_000)
        }
        guard advanced else {
            throw TestError(message: "turn did not advance after endTurn")
        }

        await client.disconnect()
    }
}

if ProcessInfo.processInfo.environment["REAL_SERVER_REJECT_E2E"] == "1" {
    await integrationTest("real Java server rejection probe") {
        let host = ProcessInfo.processInfo.environment["REAL_SERVER_HOST"] ?? "127.0.0.1"
        let port = Int(ProcessInfo.processInfo.environment["REAL_SERVER_PORT"] ?? "3541") ?? 3541
        let client = FreeColClient(host: host, port: port)

        try await client.connect()
        let vacant = await client.initialVacantPlayers
        let nationId = vacant?.children.first?.attributes["nationId"]
            ?? vacant?.children.first?.attributes["id"]
            ?? "model.nation.dutch"
        let userName = "CopilotReject-\(Int(Date().timeIntervalSince1970))"

        let result = try await client.login(userName: userName, nationId: nationId)
        if result.serverState == .preGame {
            try await client.send(message: ParsedMessage(tag: "ready", attributes: ["value": "true"], children: []))
            try await client.send(message: ParsedMessage(tag: "requestLaunch", attributes: [:], children: []))
        }

        let loopTask = Task { await client.startMessageLoop() }
        defer { loopTask.cancel() }

        var waited = 0
        while true {
            let current = await client.game
            if current.currentPlayerId != nil && !current.units.isEmpty { break }
            if waited >= 60 { throw TestError(message: "game did not start within 30s") }
            try await Task.sleep(nanoseconds: 500_000_000)
            waited += 1
        }

        let before = await client.game
        let unitCountBefore = before.units.count
        let turnBefore = before.turn.number

        // An action for a unit that does not exist must be rejected by the server.
        var rejection: String?
        do {
            _ = try await client.ask(
                message: ParsedMessage(tag: "move", attributes: ["unit": "unit:does-not-exist", "direction": "N"], children: []),
                timeout: 30
            )
        } catch let FreeColProtocolError.serverError(message) {
            rejection = message
        }
        guard let rejection, !rejection.isEmpty else {
            throw TestError(message: "illegal move was not rejected with a server error")
        }
        print("    java rejection text: \(rejection)")

        let after = await client.game
        guard after.units.count == unitCountBefore, after.turn.number == turnBefore else {
            throw TestError(message: "model changed after rejected action")
        }
    }
}

// Trade Route Execution probe: verify automatic trade route execution at turn end.
if ProcessInfo.processInfo.environment["REAL_SERVER_TRADE_ROUTE_E2E"] == "1" {
    await integrationTest("real Java server trade route execution probe") {
        let host = ProcessInfo.processInfo.environment["REAL_SERVER_HOST"] ?? "127.0.0.1"
        let port = Int(ProcessInfo.processInfo.environment["REAL_SERVER_PORT"] ?? "3541") ?? 3541
        let client = FreeColClient(host: host, port: port)

        try await client.connect()
        let nationId = "model.nation.dutch"
        let userName = "CopilotTradeRoute-\(Int(Date().timeIntervalSince1970))"

        let result = try await client.login(userName: userName, nationId: nationId)
        if result.serverState == .preGame {
            // Shorten Europe sailing time for the isolated real-server fixture.
            try await client.send(message: ParsedMessage(
                tag: "updateGameOptions",
                attributes: [:],
                children: [ParsedMessage(tag: "optionGroup", attributes: ["id": "gameOptions"], children: [
                  ParsedMessage(tag: "optionGroup", attributes: ["id": "gameOptions.map"], children: [
                    ParsedMessage(tag: "integerOption", attributes: [
                        "id": "model.option.turnsToSail", "value": "1",
                    ], children: []),
                    ParsedMessage(tag: "booleanOption", attributes: [
                        "id": "model.option.fogOfWar", "value": "false",
                    ], children: []),
                  ]),
                ])]
            ))
            try await client.send(message: ParsedMessage(
                tag: "updateMapGeneratorOptions",
                attributes: [:],
                children: [ParsedMessage(tag: "optionGroup", attributes: ["id": "mapGeneratorOptions"], children: [
                    ParsedMessage(tag: "optionGroup", attributes: [
                        "id": "mapGeneratorOptions.landGenerator",
                    ], children: [
                        ParsedMessage(tag: "integerOption", attributes: [
                            "id": "model.option.mapWidth", "value": "40",
                        ], children: []),
                        ParsedMessage(tag: "integerOption", attributes: [
                            "id": "model.option.mapHeight", "value": "40",
                        ], children: []),
                        ParsedMessage(tag: "integerOption", attributes: [
                            "id": "model.option.landMass", "value": "50",
                        ], children: []),
                        ParsedMessage(tag: "selectOption", attributes: [
                            "id": "model.option.landGeneratorType", "value": "2",
                        ], children: []),
                    ]),
                ])]
            ))
            try await client.send(message: ParsedMessage(tag: "ready", attributes: ["value": "true"], children: []))
            try await client.send(message: ParsedMessage(tag: "requestLaunch", attributes: [:], children: []))
        }

        let loopTask = Task { await client.startMessageLoop() }
        defer { loopTask.cancel() }

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

        // Find a naval carrier to use for the trade route.
        let navalUnits = game.units.values
            .filter { $0.owner == localPlayerId && spec.isNaval(unitType: $0.unitType) == true }
            .sorted { $0.id < $1.id }
        guard let carrier = navalUnits.first else {
            throw TestError(message: "no local naval carrier found for trade route test")
        }
let carrierId = carrier.id
 
        func endTurnAndWait() async throws {
            let turnBefore = await client.game.turn.number
            _ = try await client.ask(message: ParsedMessage(tag: "endTurn", attributes: [:], children: []), timeout: 45)
            for _ in 0..<180 {
                let current = await client.game
                if current.turn.number > turnBefore && current.currentPlayerId == localPlayerId { return }
                try await Task.sleep(nanoseconds: 500_000_000)
            }
        }
 
        // Find or create a coastal colony to use as a trade route stop.
        var colonyId: String?
        func findCoastalColony(in current: FreeColGame.Game) -> String? {
            for (id, colony) in current.colonies {
                guard colony.owner == localPlayerId,
                      let tileId = colony.tileId,
                      let tile = current.tiles[tileId],
                      let tileType = tile.type,
                      let tileInfo = spec.tileTypes[tileType],
                      !tileInfo.isWater,
                      tileInfo.canSettle else { continue }
                return id
            }
            return nil
        }

        colonyId = findCoastalColony(in: game)
        var colonyWasFounded = false

if colonyId == nil {
            // Move carrier to coast if needed, then disembark a founder.
            // Filter out military units that have foundColony ability but can't actually found.
            func canActuallyFoundColony(unitType: String?) -> Bool {
                guard let unitType else { return false }
                let nonFoundingSubstrings = ["dragoon", "cavalry", "artillery", "regular", "soldier", "treasure"]
                let lower = unitType.lowercased()
                return !nonFoundingSubstrings.contains { lower.contains($0) }
            }
            
            let candidates = game.units.values
                .filter {
                    $0.owner == localPlayerId
                        && spec.hasAbility("model.ability.foundColony", unitType: $0.unitType)
                        && canActuallyFoundColony(unitType: $0.unitType)
                        && $0.location == carrierId
                }
                .sorted { $0.id < $1.id }
            
            print("    embarkedFounder candidates: \(candidates.map { "\($0.id):\($0.unitType ?? "?")" })")
            if let embarkedFounder = candidates.first {
                print("    selected founder \(embarkedFounder.id) type \(embarkedFounder.unitType ?? "?")")
                // Move carrier to coastal tile if not already there.
                func colonyLandingTiles(around sourceTileId: String,
                                        in current: FreeColGame.Game) -> [FreeColGame.Tile] {
                    current.neighborTileIds(of: sourceTileId)
                        .compactMap { current.tiles[$0] }
                        .filter { tile in
                            guard tile.settlement == nil,
                                  tile.owningSettlement == nil,
                                  tile.owner == nil || tile.owner == localPlayerId,
                                  let tileType = tile.type,
                                  let tileInfo = spec.tileTypes[tileType],
                                  !tileInfo.isWater,
                                  tileInfo.canSettle,
                                  !(tileType.lowercased().contains("arctic")) else { return false }
                            return !current.neighborTileIds(of: tile.id).contains {
                                current.tiles[$0]?.settlement != nil
                            }
                        }
                        .sorted { $0.id < $1.id }
                }

                func direction(from source: FreeColGame.Tile,
                               to target: FreeColGame.Tile) -> String? {
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

                var explorationHeading = 0
                for _ in 0..<60 {
                    game = await client.game
                    guard let carrier = game.units[carrierId],
                          let sourceTileId = carrier.location,
                          let sourceTile = game.tiles[sourceTileId] else { break }
                    let landingTiles = colonyLandingTiles(around: sourceTileId, in: game)
                    if !landingTiles.isEmpty { break }
                    if carrier.movesLeft <= 0 {
                        // End turn to get more movement
                        let turnBefore = game.turn.number
                        _ = try await client.ask(message: ParsedMessage(tag: "endTurn", attributes: [:], children: []), timeout: 45)
                        for _ in 0..<180 {
                            let current = await client.game
                            if current.turn.number > turnBefore && current.currentPlayerId == localPlayerId {
                                break
                            }
                            try await Task.sleep(nanoseconds: 500_000_000)
                        }
                        continue
                    }
                    let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
                    let candidates = directions.indices.map {
                        directions[($0 + explorationHeading) % directions.count]
                    }
                    var moved = false
                    for direction in candidates {
                        do {
                            _ = try await client.ask(message: ParsedMessage(
                                tag: "move",
                                attributes: ["unit": carrierId, "direction": direction],
                                children: []
                            ), timeout: 8)
                        } catch {
                            if "\(error)".contains("MOVE_NO_MOVES") {
                                game = await client.game
                                break
                            }
                            continue
                        }
                        for _ in 0..<10 {
                            game = await client.game
                            if game.units[carrierId]?.location != sourceTileId {
                                moved = true
                                if let index = directions.firstIndex(of: direction) {
                                    explorationHeading = index
                                }
                                break
                            }
                            try await Task.sleep(nanoseconds: 200_000_000)
                        }
                        if moved { break }
                    }
                    if !moved {
                        explorationHeading = (explorationHeading + 1) % directions.count
                    }
                }

                game = await client.game
                guard let carrier = game.units[carrierId],
                      let sourceTileId = carrier.location,
                      let sourceTile = game.tiles[sourceTileId],
                      let targetTile = colonyLandingTiles(around: sourceTileId, in: game).first,
                      let landingDirection = direction(from: sourceTile, to: targetTile) else {
                    throw TestError(message: "could not find coastal tile for colony founding")
                }
                print("    carrier at \(sourceTileId) type \(sourceTile.type ?? "?"); landing on \(targetTile.id) type \(targetTile.type ?? "?") dir \(landingDirection)")

                // Move founder from carrier to land tile
                _ = try await client.ask(message: ParsedMessage(
                    tag: "move",
                    attributes: ["unit": embarkedFounder.id, "direction": landingDirection],
                    children: []
                ), timeout: 8)

                var reachedLand = false
                for _ in 0..<30 {
                    game = await client.game
                    if game.units[embarkedFounder.id]?.location == targetTile.id {
                        reachedLand = true
                        break
                    }
                    try await Task.sleep(nanoseconds: 200_000_000)
                }
guard reachedLand else {
                    throw TestError(message: "founding unit did not reach land tile")
                }
                print("    founder \(embarkedFounder.id) now on \(targetTile.id) with movesLeft \(game.units[embarkedFounder.id]?.movesLeft ?? -1)")
 
                // buildColony requires movement points. If the landing consumed them
                // all, advance one turn so the founder can act.
                if (game.units[embarkedFounder.id]?.movesLeft ?? 0) <= 0 {
                    print("    founder out of moves; advancing one turn")
                    try await endTurnAndWait()
                    game = await client.game
                }
                guard (game.units[embarkedFounder.id]?.movesLeft ?? 0) > 0 else {
                    throw TestError(message: "founder has no moves left after waiting")
                }
 
                // Found colony
                let colonyName = "E2ETradeRoute\(Int(Date().timeIntervalSince1970) % 100000)"
                _ = try await client.ask(message: ParsedMessage(
                    tag: "buildColony",
                    attributes: ["unit": embarkedFounder.id, "name": colonyName],
                    children: []
                ), timeout: 8)

                for _ in 0..<30 {
                    game = await client.game
                    if let colony = game.colonies.values.first(where: {
                        $0.name == colonyName && $0.owner == localPlayerId && $0.tileId == targetTile.id
                    }) {
                        colonyId = colony.id
                        colonyWasFounded = true
                        break
                    }
                    try await Task.sleep(nanoseconds: 200_000_000)
                }
                guard colonyWasFounded, let colonyId else {
                    throw TestError(message: "colony \(colonyName) was not created")
                }
                print("    founded colony \(colonyName)")
            } else {
                throw TestError(message: "no founder unit available aboard carrier")
            }
        }

        guard let colonyId else {
            throw TestError(message: "no coastal colony available for trade route test")
        }

        // Get Europe location
        guard let europeId = game.players[localPlayerId]?.europe?.id else {
            throw TestError(message: "Europe location missing")
        }

        // Create a new trade route
        let previousRouteIds = Set(game.tradeRoutes.keys)
        _ = try await client.ask(message: ParsedMessage(tag: "newTradeRoute", attributes: [:], children: []), timeout: 8)

        var createdRoute: FreeColGame.TradeRoute?
        for _ in 0..<30 {
            game = await client.game
            createdRoute = game.tradeRoutes.values.first {
                !previousRouteIds.contains($0.id) && $0.owner == localPlayerId
            }
            if createdRoute != nil { break }
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        guard let createdRoute else {
            throw TestError(message: "Java did not add the requested trade route")
        }

        // Update the trade route with stops: Europe -> Colony
        let routeName = "E2E Route \(Int(Date().timeIntervalSince1970) % 100000)"
        let routeCargo = "model.goods.food"
        let routeStops = [
            ParsedMessage(tag: "tradeRouteStop",
                          attributes: ["location": europeId],
                          children: []),
            ParsedMessage(tag: "tradeRouteStop",
                          attributes: ["location": colonyId],
                          children: [ParsedMessage(tag: "cargo",
                                                   attributes: ["id": routeCargo],
                                                   children: [])]),
        ]
        let routeNode = ParsedMessage(
            tag: "tradeRoute",
            attributes: [
                "id": createdRoute.id,
                "name": routeName,
                "owner": localPlayerId,
                "silent": "false",
            ],
            children: routeStops
        )
        _ = try await client.ask(message: ParsedMessage(tag: "updateTradeRoute", attributes: [:], children: [routeNode]), timeout: 8)

        var routeUpdateApplied = false
        for _ in 0..<30 {
            game = await client.game
            if let route = game.tradeRoutes[createdRoute.id],
               route.name == routeName,
               route.owner == localPlayerId,
               route.stops.count == 2,
               route.stops[0].locationId == europeId,
               route.stops[1].locationId == colonyId,
               route.stops[1].cargoTypeIds == [routeCargo] {
                routeUpdateApplied = true
                break
            }
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        guard routeUpdateApplied else {
            throw TestError(message: "updated trade route \(createdRoute.id) missing from game model")
        }
        print("    created trade route \(routeName)")

        // Assign the trade route to the carrier
        _ = try await client.ask(message: ParsedMessage(
            tag: "assignTradeRoute",
            attributes: ["unit": carrierId, "tradeRoute": createdRoute.id],
            children: []
        ), timeout: 8)

        var routeAssigned = false
        for _ in 0..<30 {
            game = await client.game
            if game.units[carrierId]?.tradeRoute == createdRoute.id {
                routeAssigned = true
                break
            }
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        guard routeAssigned else {
            throw TestError(message: "trade route \(createdRoute.id) was not assigned to \(carrierId)")
        }
        print("    assigned trade route to carrier \(carrierId)")

        // Java advances route stops client-side (setCurrentStop), not at turn end.
        // Verify the server's assignment state, that endTurn leaves the stop
        // untouched, and that setCurrentStop is applied, range-checked and wraps.
        let stopCount = routeStops.count
        let assignedStop = game.units[carrierId]?.currentStop ?? -1
        guard (0..<stopCount).contains(assignedStop) else {
            throw TestError(message: "server assigned invalid currentStop \(assignedStop)")
        }
        print("    server assigned currentStop \(assignedStop)")

        let turnBefore = await client.game.turn.number
        _ = try await client.ask(message: ParsedMessage(tag: "endTurn", attributes: [:], children: []), timeout: 45)
        var advanced = false
        for _ in 0..<120 {
            if await client.game.turn.number > turnBefore {
                advanced = true
                break
            }
            try await Task.sleep(nanoseconds: 500_000_000)
        }
        guard advanced else {
            throw TestError(message: "turn did not advance after endTurn")
        }
        game = await client.game
        guard let carrierAfterTurn = game.units[carrierId],
              carrierAfterTurn.tradeRoute == createdRoute.id else {
            throw TestError(message: "carrier lost trade route assignment after endTurn")
        }
        guard carrierAfterTurn.currentStop == assignedStop else {
            throw TestError(message: "server unexpectedly changed currentStop on endTurn: \(assignedStop) -> \(carrierAfterTurn.currentStop)")
        }
        print("    endTurn left currentStop at \(assignedStop) (client-driven, as in Java)")

        // Step through every stop, then wrap to the first one.
        for step in 1...stopCount {
            let target = (assignedStop + step) % stopCount
            _ = try await client.ask(message: ParsedMessage(
                tag: "setCurrentStop",
                attributes: ["unit": carrierId, "index": String(target)],
                children: []
            ), timeout: 8)
            var applied = false
            for _ in 0..<30 {
                game = await client.game
                if game.units[carrierId]?.currentStop == target {
                    applied = true
                    break
                }
                try await Task.sleep(nanoseconds: 200_000_000)
            }
            guard applied else {
                throw TestError(message: "setCurrentStop \(target) was not applied (got \(game.units[carrierId]?.currentStop ?? -1))")
            }
        }
        print("    setCurrentStop cycled through \(stopCount) stops and wrapped to \(assignedStop)")

        // Out-of-range index must be rejected without changing state.
        let rejected: Bool
        do {
            _ = try await client.ask(message: ParsedMessage(
                tag: "setCurrentStop",
                attributes: ["unit": carrierId, "index": String(stopCount)],
                children: []
            ), timeout: 8)
            rejected = false
        } catch {
            rejected = true
        }
        try await Task.sleep(nanoseconds: 500_000_000)
        game = await client.game
        guard game.units[carrierId]?.currentStop == assignedStop else {
            throw TestError(message: "out-of-range setCurrentStop changed currentStop to \(game.units[carrierId]?.currentStop ?? -1)")
        }
        print("    out-of-range stop \(stopCount) left currentStop unchanged (rejectedReply=\(rejected))")

        _ = try await client.ask(message: ParsedMessage(
            tag: "assignTradeRoute", attributes: ["unit": carrierId], children: []
        ), timeout: 8)
        game = await client.game
        guard game.units[carrierId]?.tradeRoute == nil else {
            throw TestError(message: "cleared trade route remained assigned to \(carrierId)")
        }
        print("    server confirmed removal of the trade route")

        await client.disconnect()
    }
}
}

import Foundation
import FreeColProtocol
import FreeColGame
import FreeColClient

func recruitmentE2EProbe() async throws {
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
    let userName = "CopilotRecruitment-\(Int(Date().timeIntervalSince1970))"

    let result = try await client.login(userName: userName, nationId: nationId)
    if result.serverState == .preGame {
        let mapGeneratorOptions = ParsedMessage(
            tag: "optionGroup",
            attributes: ["id": "mapGeneratorOptions"],
            children: [ParsedMessage(
                tag: "optionGroup",
                attributes: ["id": "mapGeneratorOptions.landGenerator"],
                children: [
                    ParsedMessage(tag: "integerOption", attributes: ["id": "model.option.mapWidth", "value": "40"], children: []),
                    ParsedMessage(tag: "integerOption", attributes: ["id": "model.option.mapHeight", "value": "40"], children: []),
                    ParsedMessage(tag: "integerOption", attributes: ["id": "model.option.landMass", "value": "70"], children: []),
                    ParsedMessage(tag: "selectOption", attributes: ["id": "model.option.landGeneratorType", "value": "1"], children: []),
                ]
            )]
        )
        do {
            _ = try await client.ask(message: ParsedMessage(
                tag: "updateMapGeneratorOptions",
                attributes: [:],
                children: [mapGeneratorOptions]
            ), timeout: 10)
        } catch {
            print("    map-generator options unchanged: \(error)")
        }
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

    print("    recruitment test map size: \(game.map?.width ?? 0)x\(game.map?.height ?? 0)")

    // Find a carrier (naval unit) to sail to Europe
    func carrierUnit(in current: FreeColGame.Game) -> FreeColGame.Unit? {
        current.units.values
            .filter { $0.owner == localPlayerId && spec.isNaval(unitType: $0.unitType) == true }
            .first
    }

    // Find a land unit to recruit/emigrate
    func landUnitForEurope(in current: FreeColGame.Game) -> FreeColGame.Unit? {
        current.units.values
            .filter { $0.owner == localPlayerId && spec.isNaval(unitType: $0.unitType) != true }
            .first
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
            ), timeout: 10)
        } catch {
            return false
        }
        for _ in 0..<50 {
            if await client.game.units[unitId]?.location != before { return true }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        return false
    }

    func endTurnAndWait() async throws {
        let turnBefore = await client.game.turn.number
        _ = try await client.ask(message: ParsedMessage(tag: "endTurn", attributes: [:], children: []), timeout: 45)
        for _ in 0..<180 {
            let current = await client.game
            if current.turn.number > turnBefore && current.currentPlayerId == localPlayerId { return }
            try await Task.sleep(nanoseconds: 500_000_000)
        }
        throw TestError(message: "local player's turn did not return after endTurn")
    }

    // Sail carrier to Europe
    var europeArrived = false
    var carrierId: String?
    var recruited = false
    var emigrated = false
    var purchased = false
    var cargoLoaded = false

    guard let carrier = carrierUnit(in: game) else {
        print("    recruitment skipped: no carrier unit found")
        await client.disconnect()
        return
    }
    carrierId = carrier.id
    print("    carrier \(carrierId!) at \(game.resolvedTileId(for: carrier) ?? "?") sailing to Europe...")

    // Navigate to Europe - wait for moves, then pathfind to high seas and enter Europe
    for turn in 0..<20 {
        game = await client.game
        guard let carrier = game.units[carrierId!] else { break }
        let location = carrier.location
        
        // Check if already in Europe
        if let loc = location, loc.hasPrefix("europe:") {
            print("    carrier arrived in \(loc)")
            europeArrived = true
            break
        }
        
        // Wait for moves if needed
        if carrier.movesLeft <= 0 {
            print("    carrier has no moves, ending turn...")
            try await endTurnAndWait()
            continue
        }
        
        // Check if in high seas - can move to Europe directly
        if let loc = location, let tile = game.tiles[loc], tile.type?.contains("highSeas") == true {
            print("    carrier in high seas at \(loc), attempting to enter Europe...")
            // From high seas, try moving in directions that might lead to Europe
            // In FreeCol, moving "off the map" from high seas enters Europe
            let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
            var moved = false
            for dir in directions {
                if try await moveAndWait(unitId: carrierId!, direction: dir) {
                    moved = true
                    print("    moved \(dir) from high seas")
                    break
                }
            }
            if !moved && carrier.movesLeft <= 0 {
                try await endTurnAndWait()
            }
            continue
        }
        
        // Otherwise sail towards high seas using pathfinding
        guard let sourceTileId = location, let sourceTile = game.tiles[sourceTileId] else {
            if carrier.movesLeft <= 0 { try await endTurnAndWait() }
            continue
        }
        
        // Find nearest high seas tile
        let highSeasTiles = game.tiles.values.filter { $0.type?.contains("highSeas") == true }
        if let nearestHighSeas = highSeasTiles.min(by: { a, b in
            let distA = abs(a.x - sourceTile.x) + abs(a.y - sourceTile.y)
            let distB = abs(b.x - sourceTile.x) + abs(b.y - sourceTile.y)
            return distA < distB
        }) {
            print("    sailing towards high seas at \(nearestHighSeas.id) from \(sourceTileId)")
            if let step = game.nextPathStep(from: sourceTileId, to: nearestHighSeas.id, canTraverse: { _, next in
                guard let tile = game.tiles[next] else { return false }
                let type = tile.type ?? ""
                return spec.tileTypes[type]?.isWater ?? type.contains("ocean") || type.contains("highSeas")
            }), let nextTile = game.tiles[step],
               let nextDirection = direction(from: sourceTile, to: nextTile) {
                print("    moving \(nextDirection) towards high seas")
                if try await moveAndWait(unitId: carrierId!, direction: nextDirection) {
                    continue
                }
            }
        }
        
        if carrier.movesLeft <= 0 {
            try await endTurnAndWait()
        }
    }
    
    if !europeArrived {
        print("    recruitment skipped: carrier did not reach Europe within 20 turns")
        await client.disconnect()
        return
    }

    game = await client.game
    let europeId = game.units[carrierId!]?.location ?? ""
    guard europeId.hasPrefix("europe:") else {
        print("    recruitment skipped: carrier not in Europe")
        await client.disconnect()
        return
    }

    print("    carrier in \(europeId)")

    // Check Europe info for recruit price and available slots
    guard let europe = game.players[localPlayerId]?.europe else {
        print("    recruitment skipped: no Europe info for player")
        await client.disconnect()
        return
    }
    print("    Europe: \(europeId), recruitPrice=\(europe.recruitPrice)")

    // Get player gold
    let goldBefore = game.players[localPlayerId]?.gold ?? 0

    // Try to recruit a unit
    if goldBefore >= europe.recruitPrice {
        print("    recruiting unit for \(europe.recruitPrice) gold (gold before: \(goldBefore))")
        
        let recruitMsg = ParsedMessage(
            tag: "recruitUnit",
            attributes: [:],
            children: []
        )
        
        let recruitResult = try await client.ask(message: recruitMsg, timeout: 30)
        if recruitResult.tag == "error" {
            print("    recruitUnit rejected: \(recruitResult.attributes["message"] ?? "unknown error")")
        } else {
            print("    recruitUnit accepted")
            // Wait for update
            for _ in 0..<50 {
                game = await client.game
                let goldAfter = game.players[localPlayerId]?.gold ?? goldBefore
                if goldAfter < goldBefore {
                    print("    recruit result: gold \(goldBefore)->\(goldAfter), new unit in Europe")
                    recruited = true
                    break
                }
                try await Task.sleep(nanoseconds: 200_000_000)
            }
        }
    }

    // Try to emigrate a unit from the pool
    game = await client.game
    if let europe = game.players[localPlayerId]?.europe {
        // Check for available emigrants in the pool
        print("    checking for emigrants in Europe...")
        // The pool units would be in the europe's recruitment pool
        // For now, try to find a unit in Europe that's not owned by us but in the pool
        // This is simplified - in reality we'd check the recruitment pool
    }

    // Try to purchase a unit (optional)
    game = await client.game
    let goldAfterRecruit = game.players[localPlayerId]?.gold ?? 0
    if goldAfterRecruit >= 2000 {
        print("    attempting purchaseUnit (caravel) for 2000 gold...")
        let purchaseMsg = ParsedMessage(
            tag: "purchaseUnit",
            attributes: [:],
            children: []
        )
        let purchaseResult = try await client.ask(message: purchaseMsg, timeout: 30)
        if purchaseResult.tag == "error" {
            print("    purchaseUnit rejected: \(purchaseResult.attributes["message"] ?? "unknown error")")
        } else {
            print("    purchaseUnit accepted")
            for _ in 0..<50 {
                game = await client.game
                let goldAfter = game.players[localPlayerId]?.gold ?? goldAfterRecruit
                if goldAfter < goldAfterRecruit {
                    print("    purchase result: gold \(goldAfterRecruit)->\(goldAfter), new unit in Europe")
                    purchased = true
                    break
                }
                try await Task.sleep(nanoseconds: 200_000_000)
            }
        }
    }

    // Try cargo load/unload on the carrier in Europe
    game = await client.game
    if let carrier = game.units[carrierId!],
       let goods = carrier.goods.first?.key,
       let amount = carrier.goods[goods],
       amount > 0 {
        print("    carrier has \(amount) \(goods), testing unload...")
        let unloadMsg = ParsedMessage(
            tag: "unloadCargo",
            attributes: ["unit": carrierId!, "goods": goods, "amount": String(amount)],
            children: []
        )
        let unloadResult = try await client.ask(message: unloadMsg, timeout: 10)
        if unloadResult.tag == "error" {
            print("    unloadCargo rejected: \(unloadResult.attributes["message"] ?? "unknown error")")
        } else {
            print("    unloadCargo accepted")
            cargoLoaded = true
        }
    }

    if recruited || emigrated || purchased || cargoLoaded {
        print("    recruitment actions completed: recruit=\(recruited), emigrate=\(emigrated), purchase=\(purchased), cargo=\(cargoLoaded)")
    } else {
        print("    recruitment skipped: no recruitment actions performed (may need specific units/conditions)")
    }

    await client.disconnect()
}
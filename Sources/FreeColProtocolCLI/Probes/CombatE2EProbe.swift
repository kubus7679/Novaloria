import Foundation
import FreeColProtocol
import FreeColGame
import FreeColClient

func combatE2EProbe() async throws {
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
        ?? "CopilotCombat-\(Int(Date().timeIntervalSince1970))"

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

    print("    combat test map size: \(game.map?.width ?? 0)x\(game.map?.height ?? 0)")

    // Find a land unit to use as attacker. Prefer a soldier/veteran, otherwise any land unit.
    func landUnit(in current: FreeColGame.Game) -> FreeColGame.Unit? {
        current.units.values
            .filter { $0.owner == localPlayerId && spec.isNaval(unitType: $0.unitType) != true }
            .sorted { a, b in
                func priority(_ unit: FreeColGame.Unit) -> Int {
                    let type = unit.unitType?.lowercased() ?? ""
                    if type.contains("soldier") || type.contains("veteran") || type.contains("dragoon") { return 0 }
                    if type.contains("freecolonist") { return 1 }
                    if type.contains("scout") { return 2 }
                    return 3
                }
                let aPriority = priority(a)
                let bPriority = priority(b)
                return aPriority == bPriority ? a.id < b.id : aPriority < bPriority
            }
            .first
    }

    // Find an adjacent enemy unit (European AI)
    func combatTarget(in current: FreeColGame.Game) -> (attackerId: String, defenderId: String, defenderTileId: String, direction: String)? {
        for (attackerId, attacker) in current.units {
            guard attacker.owner == localPlayerId,
                  spec.isNaval(unitType: attacker.unitType) != true,
                  let attackerTileId = current.resolvedTileId(for: attacker),
                  let attackerTile = current.tiles[attackerTileId],
                  attacker.movesLeft > 0 else { continue }
            
            for (defenderId, defender) in current.units {
                guard let defenderOwnerId = defender.owner,
                      defenderOwnerId != localPlayerId,
                      let defenderOwner = current.players[defenderOwnerId],
                      defenderOwner.playerType == FreeColGame.PlayerType.european,
                      defenderOwner.ai,
                      let defenderTileId = current.resolvedTileId(for: defender),
                      let defenderTile = current.tiles[defenderTileId] else { continue }
                
                // Check adjacency and get direction
                if let direction = direction(from: attackerTile, to: defenderTile) {
                    return (attackerId, defenderId, defenderTileId, direction)
                }
            }
        }
        return nil
    }

    // Find an adjacent AI colony for colony attack test
    func colonyAttackTarget(in current: FreeColGame.Game) -> (attackerId: String, colonyId: String, colonyTileId: String, direction: String)? {
        for (attackerId, attacker) in current.units {
            guard attacker.owner == localPlayerId,
                  spec.isNaval(unitType: attacker.unitType) != true,
                  let attackerTileId = current.resolvedTileId(for: attacker),
                  let attackerTile = current.tiles[attackerTileId],
                  attacker.movesLeft > 0 else { continue }
            
            for (colonyId, colony) in current.colonies {
                guard let ownerId = colony.owner,
                      ownerId != localPlayerId,
                      let owner = current.players[ownerId],
                      owner.playerType == FreeColGame.PlayerType.european,
                      owner.ai,
                      let colonyTileId = colony.tileId,
                      let colonyTile = current.tiles[colonyTileId] else { continue }
                
                if let direction = direction(from: attackerTile, to: colonyTile) {
                    return (attackerId, colonyId, colonyTileId, direction)
                }
            }
        }
        return nil
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

    func attackAndWait(unitId: String, direction: String) async throws -> Bool {
        do {
            let response = try await client.ask(message: ParsedMessage(
                tag: "attack",
                attributes: ["unit": unitId, "direction": direction],
                children: []
            ), timeout: 10)
            return response.tag != "error"
        } catch {
            return false
        }
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

    // Try to find combat target for up to 15 turns
    var combatPerformed = false
    var colonyAttackPerformed = false
    
    let scenarioFixture = ProcessInfo.processInfo.environment["REAL_SERVER_SCENARIO_FIXTURE"] == "1"
    let searchLimit = scenarioFixture ? 1 : 15
    for _ in 0..<searchLimit {
        game = await client.game
        
        // Try unit vs unit combat first
        if !combatPerformed, let target = combatTarget(in: game) {
            print("    combat target: enemy unit \(target.defenderId) at \(target.defenderTileId) (owner \(game.players[game.units[target.defenderId]?.owner ?? ""]?.name ?? "?"))")
            print("    attacker \(target.attackerId) at \(game.resolvedTileId(for: game.units[target.attackerId]!) ?? "?") moving \(target.direction)")
            
            let defenderId = target.defenderId
            let defenderOwner = game.units[defenderId]?.owner
            let attackerMovesBefore = game.units[target.attackerId]?.movesLeft ?? 0
            print("    combat stance: \(game.players[localPlayerId]?.stances[defenderOwner ?? ""]?.rawValue ?? "unknown")")

            if try await attackAndWait(unitId: target.attackerId, direction: target.direction) {
                // Wait for combat result
                var combatResolved = false
                for _ in 0..<100 {
                    game = await client.game
                    let attackerStillExists = game.units[target.attackerId] != nil
                    let defenderStillExists = game.units[defenderId] != nil
                    let attackerLocation = game.units[target.attackerId]?.location
                    
                    if attackerStillExists && attackerLocation == target.defenderTileId && !defenderStillExists {
                        print("    combat result: attacker survived, defender removed")
                        print("    attacker at \(attackerLocation ?? "?") with movesLeft \(game.units[target.attackerId]?.movesLeft ?? -1)")
                        combatPerformed = true
                        combatResolved = true
                        break
                    } else if attackerStillExists && !defenderStillExists {
                        print("    combat result: attacker survived, defender removed (location: \(attackerLocation ?? "?"))")
                        combatPerformed = true
                        combatResolved = true
                        break
                    } else if !attackerStillExists && defenderStillExists {
                        print("    combat result: attacker lost, defender survived")
                        combatPerformed = true
                        combatResolved = true
                        break
                    } else if !attackerStillExists && !defenderStillExists {
                        print("    combat result: both units lost")
                        combatPerformed = true
                        combatResolved = true
                        break
                    } else if let attackerMoves = game.units[target.attackerId]?.movesLeft,
                              attackerMoves < attackerMovesBefore {
                        print("    combat processed: attacker moves \(attackerMovesBefore) -> \(attackerMoves)")
                        combatPerformed = true
                        combatResolved = true
                        break
                    }
                    try await Task.sleep(nanoseconds: 200_000_000)
                }
                if !combatResolved {
                    print("    combat result: timeout waiting for resolution")
                }
            } else {
                print("    attack move rejected by server")
            }
        }
        
        // Try colony attack
        if !colonyAttackPerformed, !combatPerformed, let target = colonyAttackTarget(in: game) {
            print("    colony attack target: colony \(target.colonyId) at \(target.colonyTileId) (owner \(game.players[game.colonies[target.colonyId]?.owner ?? ""]?.name ?? "?"))")
            
            let colonyOwnerBefore = game.colonies[target.colonyId]?.owner
            
            if try await attackAndWait(unitId: target.attackerId, direction: target.direction) {
                var colonyAttackResolved = false
                for _ in 0..<100 {
                    game = await client.game
                    let colonyStillExists = game.colonies[target.colonyId] != nil
                    let colonyOwnerAfter = game.colonies[target.colonyId]?.owner
                    let attackerLocation = game.units[target.attackerId]?.location
                    
                    if colonyStillExists && colonyOwnerAfter != colonyOwnerBefore {
                        print("    colony attack result: colony captured, new owner \(colonyOwnerAfter ?? "?")")
                        colonyAttackPerformed = true
                        colonyAttackResolved = true
                        break
                    } else if colonyStillExists && attackerLocation == target.colonyTileId {
                        print("    colony attack result: attacker reached colony tile, owner unchanged \(colonyOwnerAfter ?? "?")")
                        colonyAttackPerformed = true
                        colonyAttackResolved = true
                        break
                    } else if !colonyStillExists {
                        print("    colony attack result: colony destroyed/removed")
                        colonyAttackPerformed = true
                        colonyAttackResolved = true
                        break
                    }
                    try await Task.sleep(nanoseconds: 200_000_000)
                }
                if !colonyAttackResolved {
                    print("    colony attack result: timeout waiting for resolution")
                }
            }
        }
        
        if combatPerformed || colonyAttackPerformed {
            break
        }
        
        // No target found this turn, end turn and explore
        if game.units.values.contains(where: { $0.owner == localPlayerId && spec.isNaval(unitType: $0.unitType) != true && ($0.movesLeft ?? 0) > 0 }) {
            // Try to move units to explore
            for (unitId, unit) in game.units where unit.owner == localPlayerId && spec.isNaval(unitType: unit.unitType) != true && (unit.movesLeft ?? 0) > 0 {
                guard let unitTileId = game.resolvedTileId(for: unit),
                      let unitTile = game.tiles[unitTileId] else { continue }
                let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
                for dir in directions {
                    if game.tiles.values.contains(where: { direction(from: unitTile, to: $0) == dir }) {
                        _ = try await moveAndWait(unitId: unitId, direction: dir)
                        break
                    }
                }
                break
            }
        }
        
        try await endTurnAndWait()
    }
    
    if !combatPerformed && !colonyAttackPerformed {
        print("    combat skipped: no enemy unit or AI colony in reach after \(searchLimit) turns")
    }
    
    await client.disconnect()
}
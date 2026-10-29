import Foundation
import FreeColProtocol
import FreeColGame
import FreeColClient

func missionarySpyE2EProbe() async throws {
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
    let userName = "CopilotMissionarySpy-\(Int(Date().timeIntervalSince1970))"

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

    print("    missionary/spy test map size: \(game.map?.width ?? 0)x\(game.map?.height ?? 0)")

    // Find a missionary unit (Jesuit or unit with missionary role)
    func missionaryUnit(in current: FreeColGame.Game) -> FreeColGame.Unit? {
        current.units.values
            .filter { $0.owner == localPlayerId }
            .filter { unit in
                let type = unit.unitType?.lowercased() ?? ""
                return type.contains("missionary") || type.contains("jesuit")
            }
            .first
    }

    // Find a scout unit for spying
    func scoutUnit(in current: FreeColGame.Game) -> FreeColGame.Unit? {
        current.units.values
            .filter { $0.owner == localPlayerId }
            .filter { unit in
                let type = unit.unitType?.lowercased() ?? ""
                return type.contains("scout")
            }
            .first
    }

    // Find native settlement adjacent to a land unit
    func nativeSettlementTarget(in current: FreeColGame.Game) -> (unitId: String, settlementId: String, settlementTileId: String, direction: String)? {
        for (unitId, unit) in current.units {
            guard unit.owner == localPlayerId,
                  spec.isNaval(unitType: unit.unitType) != true,
                  let unitTileId = current.resolvedTileId(for: unit),
                  let unitTile = current.tiles[unitTileId] else { continue }
            
            for (settlementId, settlement) in current.colonies {
                guard let ownerId = settlement.owner,
                      let owner = current.players[ownerId],
                      owner.playerType == FreeColGame.PlayerType.indian,
                      let settlementTileId = settlement.tileId,
                      let settlementTile = current.tiles[settlementTileId] else { continue }
                
                if let direction = direction(from: unitTile, to: settlementTile) {
                    return (unitId, settlementId, settlementTileId, direction)
                }
            }
        }
        return nil
    }

    // Find AI colony adjacent to a scout
    func spyTarget(in current: FreeColGame.Game) -> (unitId: String, colonyId: String, colonyTileId: String, direction: String)? {
        for (unitId, unit) in current.units {
            guard unit.owner == localPlayerId,
                  let type = unit.unitType?.lowercased(),
                  type.contains("scout"),
                  let unitTileId = current.resolvedTileId(for: unit),
                  let unitTile = current.tiles[unitTileId] else { continue }
            
            for (colonyId, colony) in current.colonies {
                guard let ownerId = colony.owner,
                      ownerId != localPlayerId,
                      let owner = current.players[ownerId],
                      owner.playerType == FreeColGame.PlayerType.european,
                      owner.ai,
                      let colonyTileId = colony.tileId,
                      let colonyTile = current.tiles[colonyTileId] else { continue }
                
                if let direction = direction(from: unitTile, to: colonyTile) {
                    return (unitId, colonyId, colonyTileId, direction)
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

    var missionaryPerformed = false
    var spyPerformed = false

    for turn in 0..<15 {
        game = await client.game

        // Try missionary first
        if !missionaryPerformed, let missionary = missionaryUnit(in: game),
           let target = nativeSettlementTarget(in: game),
           target.unitId == missionary.id {
            print("    missionary target: unit \(missionary.id) (\(missionary.unitType ?? "?")) at \(game.resolvedTileId(for: missionary) ?? "?")")
            print("    native settlement: \(target.settlementId) at \(target.settlementTileId) direction \(target.direction)")

            let sendMissionaryMsg = ParsedMessage(
                tag: "sendMissionary",
                attributes: ["unit": missionary.id, "settlement": target.settlementId],
                children: []
            )
            let sendResult = try await client.ask(message: sendMissionaryMsg, timeout: 30)
            if sendResult.tag == "error" {
                print("    sendMissionary rejected: \(sendResult.attributes["message"] ?? "unknown error")")
            } else {
                print("    sendMissionary accepted by server")
            }

            // Wait for missionary result
            var missionaryResolved = false
            for _ in 0..<100 {
                game = await client.game
                let updatedMissionary = game.units[missionary.id]
                let missionaryLocation = updatedMissionary?.location
                
                if let loc = missionaryLocation, loc == target.settlementTileId {
                    print("    missionary placed in settlement \(target.settlementId)")
                    missionaryPerformed = true
                    missionaryResolved = true
                    break
                }
                
                // Check for modelMessage with missionary result
                if let msg = delegate.receivedPayloads.last(where: { $0.tag == "modelMessage" }) {
                    if let text = msg.attributes["text"], text.lowercased().contains("missionary") {
                        print("    missionary result: \(text)")
                        missionaryResolved = true
                        break
                    }
                }
                
                try await Task.sleep(nanoseconds: 200_000_000)
            }
            if !missionaryResolved {
                print("    missionary result: timeout waiting for resolution")
            }
        }

        // Try spying
        if !spyPerformed, let spy = scoutUnit(in: game),
           let target = spyTarget(in: game),
           target.unitId == spy.id {
            print("    spy target: unit \(spy.id) (\(spy.unitType ?? "?")) at \(game.resolvedTileId(for: spy) ?? "?")")
            print("    ai colony: \(target.colonyId) at \(target.colonyTileId) direction \(target.direction)")

            let spyMsg = ParsedMessage(
                tag: "spySettlement",
                attributes: ["unit": spy.id, "settlement": target.colonyId],
                children: []
            )
            let spyResult = try await client.ask(message: spyMsg, timeout: 30)
            if spyResult.tag == "error" {
                print("    spySettlement rejected: \(spyResult.attributes["message"] ?? "unknown error")")
            } else {
                print("    spySettlement accepted by server")
            }

            // Wait for spy report (modelMessage)
            var spyResolved = false
            for _ in 0..<100 {
                game = await client.game
                
                if let msg = delegate.receivedPayloads.last(where: { $0.tag == "modelMessage" }) {
                    if let text = msg.attributes["text"], text.lowercased().contains("scout report") || text.lowercased().contains("spy") {
                        print("    spy report received: \(text)")
                        spyPerformed = true
                        spyResolved = true
                        break
                    }
                }
                
                try await Task.sleep(nanoseconds: 200_000_000)
            }
            if !spyResolved {
                print("    spy result: timeout waiting for report")
            }
        }

        if missionaryPerformed && spyPerformed {
            break
        }

        // No target found this turn, end turn and explore
        if game.units.values.contains(where: { $0.owner == localPlayerId && spec.isNaval(unitType: $0.unitType) != true && ($0.movesLeft ?? 0) > 0 }) {
            for (unitId, unit) in game.units where unit.owner == localPlayerId && spec.isNaval(unitType: unit.unitType) != true && (unit.movesLeft ?? 0) > 0 {
                guard let unitTileId = game.resolvedTileId(for: unit),
                      let unitTile = game.tiles[unitTileId] else { continue }
                let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
                for dir in directions {
                    if let neighborId = direction(from: unitTile, to: game.tiles.values.first(where: { t in direction(from: unitTile, to: t) == dir }) ?? unitTile) {
                        _ = try await moveAndWait(unitId: unitId, direction: dir)
                        break
                    }
                }
                break
            }
        }

        try await endTurnAndWait()
    }

    if !missionaryPerformed {
        print("    missionary skipped: no missionary unit or native settlement in reach after 15 turns")
    }
    if !spyPerformed {
        print("    spy skipped: no scout unit or AI colony in reach after 15 turns")
    }

    await client.disconnect()
}
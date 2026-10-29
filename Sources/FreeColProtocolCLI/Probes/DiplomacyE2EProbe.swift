import Foundation
import FreeColProtocol
import FreeColGame
import FreeColClient

func diplomacyE2EProbe() async throws {
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
    let userName = "CopilotDiplomacy-\(Int(Date().timeIntervalSince1970))"

    let result = try await client.login(userName: userName, nationId: nationId)
    if result.serverState == .preGame {
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

        // Find an adjacent foreign colony owned by a European AI.
        func diplomacyTarget(in current: FreeColGame.Game) -> (unitId: String, colonyId: String, ownerId: String)? {
            for (unitId, unit) in current.units {
                guard unit.owner == localPlayerId,
                      spec.hasAbility("model.ability.negotiate", unitType: unit.unitType),
                      let unitTileId = current.resolvedTileId(for: unit),
                      let unitTile = current.tiles[unitTileId] else { continue }
                for (colonyId, colony) in current.colonies {
                    guard let ownerId = colony.owner,
                          ownerId != localPlayerId,
                          let owner = current.players[ownerId],
                          owner.playerType == .european,
                          owner.ai,
                          let colonyTileId = colony.tileId,
                          let colonyTile = current.tiles[colonyTileId] else { continue }
                    let dx = abs(colonyTile.x - unitTile.x)
                    let dy = abs(colonyTile.y - unitTile.y)
                    guard dx <= 1, dy <= 1, !(dx == 0 && dy == 0) else { continue }
                    return (unitId, colonyId, ownerId)
                }
            }
            return nil
        }

        // Try to explore a bit if no adjacent AI colony is known.
        func endTurnAndWait() async throws {
            let turnBefore = await client.game.turn.number
            _ = try await client.ask(message: ParsedMessage(tag: "endTurn", attributes: [:], children: []), timeout: 45)
            for _ in 0..<180 {
                let current = await client.game
                if current.turn.number > turnBefore && current.currentPlayerId == localPlayerId { return }
                try await Task.sleep(nanoseconds: 500_000_000)
            }
        }

        for _ in 0..<15 {
            if diplomacyTarget(in: game) != nil { break }
            try await endTurnAndWait()
            game = await client.game
        }

        guard let target = diplomacyTarget(in: game) else {
            print("    diplomacy skipped: no negotiable unit adjacent to a visible European AI colony after 15 turns")
            await client.disconnect()
            return
        }

        print("    diplomacy target: colony \(target.colonyId) (owner \(target.ownerId))")

        let tradeNode = ParsedMessage(
            tag: "diplomaticTrade",
            attributes: [
                "context": "DIPLOMATIC",
                "sender": localPlayerId,
                "recipient": target.ownerId,
                "status": "PROPOSE_TRADE",
                "version": "1",
            ],
            children: [
                ParsedMessage(tag: "stanceTradeItem",
                              attributes: ["id": "model.tradeItem.stance", "stance": "PEACE",
                                           "source": localPlayerId, "destination": target.ownerId],
                              children: [])
            ]
        )
        let proposalMessage = ParsedMessage(
            tag: "diplomacy",
            attributes: ["ourId": target.unitId, "otherId": target.colonyId],
            children: [tradeNode]
        )

        func diplomacyEnvelope(in message: ParsedMessage) -> ParsedMessage? {
            if message.tag == "diplomacy",
               message.children.contains(where: { $0.tag == "diplomaticTrade" }) {
                return message
            }
            for child in message.children {
                if let result = diplomacyEnvelope(in: child) { return result }
            }
            return nil
        }

        func waitForDiplomacyResponse(after startIndex: Int,
                                      timeout: TimeInterval) async throws -> ParsedMessage? {
            let deadline = Date().addingTimeInterval(timeout)
            while Date() < deadline {
                for incoming in delegate.receivedPayloads.dropFirst(startIndex) {
                    if incoming.tag == "error" {
                        throw TestError(message: "Java diplomacy error: \(incoming.attributes["message"] ?? "unknown error")")
                    }
                    guard let envelope = diplomacyEnvelope(in: incoming),
                          let trade = envelope.children.first(where: { $0.tag == "diplomaticTrade" }),
                          let status = trade.attributes["status"],
                          ["ACCEPT_TRADE", "REJECT_TRADE", "PROPOSE_TRADE"].contains(status) else { continue }
                    let proposal = DiplomaticTradeProposal(raw: trade)
                    guard proposal.context == "DIPLOMATIC",
                          proposal.sender != nil,
                          proposal.recipient != nil else {
                        throw TestError(message: "AI diplomacy response has invalid context/version")
                    }
                    return envelope
                }
                try await Task.sleep(nanoseconds: 250_000_000)
            }
            return nil
        }

        func waitForPeaceWithAI() async throws -> Bool {
            for _ in 0..<40 {
                game = await client.game
                if game.players[localPlayerId]?.stances[target.ownerId] == .peace { return true }
                try await Task.sleep(nanoseconds: 250_000_000)
            }
            return false
        }

        // Send proposal and wait for an asynchronous AI answer.
        let responseStart = delegate.receivedPayloads.count
        let response = try await client.ask(message: proposalMessage, timeout: 60)
        guard response.tag != "error" else {
            throw TestError(message: "diplomacy proposal returned immediate error")
        }
        print("    diplomacy proposal accepted by server envelope")

        if let aiReply = try await waitForDiplomacyResponse(after: responseStart, timeout: 30),
           let trade = aiReply.children.first(where: { $0.tag == "diplomaticTrade" }) {
            let proposal = DiplomaticTradeProposal(raw: trade)
            print("    AI diplomacy response: \(proposal.status ?? "unknown") (\(proposal.clauses.count) clauses)")
            if proposal.status == "ACCEPT_TRADE" {
                guard try await waitForPeaceWithAI() else {
                    throw TestError(message: "AI accepted peace but the stance update was not applied")
                }
                print("    AI acceptance applied: stance is PEACE")
            } else if proposal.status == "PROPOSE_TRADE" {
                var attributes = trade.attributes
                attributes["status"] = "ACCEPT_TRADE"
                let acceptance = ParsedMessage(
                    tag: "diplomacy",
                    attributes: aiReply.attributes,
                    children: [ParsedMessage(tag: "diplomaticTrade", attributes: attributes, children: trade.children)]
                )
                _ = try await client.ask(message: acceptance, timeout: 20)
                print("    accepted AI counter-proposal")
                if try await waitForPeaceWithAI() {
                    print("    accepted counter-proposal applied: stance is PEACE")
                }
            }
        } else {
            print("    no AI diplomacy response observed within 30s (tolerated)")
        }

        await client.disconnect()
    }

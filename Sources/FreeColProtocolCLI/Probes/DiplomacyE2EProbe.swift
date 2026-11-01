import Foundation
import FreeColProtocol
import FreeColGame
import FreeColClient

func diplomacyE2EProbe() async throws {
    let tribute = ProcessInfo.processInfo.environment["REAL_SERVER_TRIBUTE_E2E"] == "1"
    let context = tribute ? "TRIBUTE" : "DIPLOMATIC"
    let host = ProcessInfo.processInfo.environment["REAL_SERVER_HOST"] ?? "127.0.0.1"
    let port = Int(ProcessInfo.processInfo.environment["REAL_SERVER_PORT"] ?? "3541") ?? 3541
    let client = FreeColClient(host: host, port: port)
    let delegate = TestDelegate()
    await client.setDelegate(delegate)

    let userName = ProcessInfo.processInfo.environment["REAL_SERVER_USERNAME"]
        ?? "CopilotDiplomacy-\(Int(Date().timeIntervalSince1970))"
    let result = try await connectAndLogin(client, userName: userName)
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
                let eligible: Bool
                if tribute {
                    eligible = spec.isNaval(unitType: unit.unitType) == false
                        && (["model.role.soldier", "model.role.dragoon"].contains(unit.role ?? "")
                            || (spec.unitTypes[unit.unitType ?? ""]?.offence ?? 0) > 0)
                } else {
                    eligible = spec.hasAbility("model.ability.negotiate", unitType: unit.unitType)
                        || unit.role == "model.role.scout"
                }
                guard unit.owner == localPlayerId,
                      eligible,
                      let unitTileId = current.resolvedTileId(for: unit) else { continue }
                let neighbors = Set(current.neighborTileIds(of: unitTileId))
                for (colonyId, colony) in current.colonies {
                    guard let ownerId = colony.owner,
                          ownerId != localPlayerId,
                          let owner = current.players[ownerId],
                          owner.playerType == .european,
                          owner.ai,
                          let colonyTileId = colony.tileId,
                          neighbors.contains(colonyTileId) else { continue }
                    return (unitId, colonyId, ownerId)
                }
            }
            return nil
        }

        // Try to explore a bit if no adjacent AI colony is known.
        let scenarioFixture = ProcessInfo.processInfo.environment["REAL_SERVER_SCENARIO_FIXTURE"] == "1"
        for _ in 0..<(scenarioFixture ? 0 : 15) {
            if diplomacyTarget(in: game) != nil { break }
            try await endTurnAndWait(client: client, localPlayerId: localPlayerId)
            game = await client.game
        }

        guard let target = diplomacyTarget(in: game) else {
            await client.disconnect()
            if scenarioFixture {
                throw TestError(message: "\(context) fixture has no eligible unit adjacent to an AI colony")
            }
            throw ProbeSkipped(message: "no negotiable unit adjacent to a visible European AI colony")
        }

        print("    diplomacy target: colony \(target.colonyId) (owner \(target.ownerId))")
        let gift = 100
        let goldSource = tribute ? target.ownerId : localPlayerId
        let goldDestination = tribute ? localPlayerId : target.ownerId
        let goldBefore = game.players[localPlayerId]?.gold ?? 0
        guard tribute || goldBefore >= gift else {
            throw TestError(message: "diplomacy fixture needs at least \(gift) local gold")
        }

        let tradeNode = ParsedMessage(
            tag: "diplomaticTrade",
            attributes: [
                "id": "",
                "context": context,
                "sender": localPlayerId,
                "recipient": target.ownerId,
                "status": "PROPOSE_TRADE",
                "version": "0",
            ],
            children: [
                ParsedMessage(tag: "stanceTradeItem",
                              attributes: ["id": "model.tradeItem.stance", "stance": "PEACE",
                                           "source": localPlayerId, "destination": target.ownerId],
                              children: []),
                ParsedMessage(tag: "goldTradeItem",
                              attributes: ["id": "model.tradeItem.gold", "gold": String(gift),
                                           "source": goldSource, "destination": goldDestination],
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
                          let trade = envelope.children.first(where: { $0.tag == "diplomaticTrade" }) else { continue }
                    let proposal = DiplomaticTradeProposal(raw: trade)
                    guard let status = proposal.status,
                          ["ACCEPT_TRADE", "REJECT_TRADE", "PROPOSE_TRADE"].contains(status) else { continue }
                    guard proposal.context == context,
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
        _ = try await client.ask(message: proposalMessage, timeout: 20)
        print("    diplomacy proposal sent")

        if let aiReply = try await waitForDiplomacyResponse(after: responseStart, timeout: 30),
           let trade = aiReply.children.first(where: { $0.tag == "diplomaticTrade" }) {
            let proposal = DiplomaticTradeProposal(raw: trade)
            print("    AI diplomacy response: \(proposal.status ?? "unknown") (\(proposal.clauses.count) clauses)")
            guard proposal.clauses.count == 2,
                  proposal.clauses.contains(where: {
                      $0.tag == "goldTradeItem" && Int($0.attributes["gold"] ?? "") == gift
                          && $0.attributes["source"] == goldSource
                          && $0.attributes["destination"] == goldDestination
                  }),
                  proposal.clauses.contains(where: {
                      $0.tag == "stanceTradeItem" && $0.attributes["stance"]?.uppercased() == "PEACE"
                          && $0.attributes["source"] == localPlayerId
                          && $0.attributes["destination"] == target.ownerId
                  }) else {
                throw TestError(message: "AI response changed the required \(context) terms")
            }
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
                guard try await waitForPeaceWithAI() else {
                    throw TestError(message: "accepted AI counter-proposal but PEACE stance was not applied")
                }
                print("    accepted counter-proposal applied: stance is PEACE")
            } else {
                throw TestError(message: "AI rejected the required diplomacy agreement")
            }
        } else {
            await client.disconnect()
            if scenarioFixture {
                throw TestError(message: "Java \(context) fixture provided no AI response within 30s")
            }
            throw ProbeSkipped(message: "Java server provided no AI response within 30s")
        }
        game = await client.game
        guard game.players[localPlayerId]?.gold == goldBefore + (tribute ? gift : -gift) else {
            throw TestError(message: "accepted diplomacy did not transfer exactly \(gift) gold")
        }
        print("    accepted \(tribute ? "tribute" : "gift") applied: \(gift) gold transferred")

        await client.disconnect()
    }

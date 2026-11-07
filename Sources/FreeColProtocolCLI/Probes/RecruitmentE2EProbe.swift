import Foundation
import FreeColProtocol
import FreeColGame
import NovaloriaClient

func recruitmentE2EProbe() async throws {
    let host = ProcessInfo.processInfo.environment["REAL_SERVER_HOST"] ?? "127.0.0.1"
    let port = Int(ProcessInfo.processInfo.environment["REAL_SERVER_PORT"] ?? "3541") ?? 3541
    let client = NovaloriaClient(host: host, port: port)
    let delegate = TestDelegate()
    await client.setDelegate(delegate)

    let userName = "CopilotRecruitment-\(Int(Date().timeIntervalSince1970))"
    let result = try await connectAndLogin(client, userName: userName)
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

    guard let europeId = game.players[localPlayerId]?.europe?.id else {
        throw TestError(message: "local player has no Europe location")
    }

    func unitsInEurope(_ current: FreeColGame.Game) -> [FreeColGame.Unit] {
        current.units.values.filter { $0.owner == localPlayerId && $0.location == europeId }
    }

    // Sail a carrier to Europe. The recruit/train actions only need Europe to exist,
    // but arriving there confirms the Europe screen state the client would show.
    guard let carrier = game.units.values
        .filter({ $0.owner == localPlayerId && spec.isNaval(unitType: $0.unitType) == true })
        .sorted(by: { $0.id < $1.id }).first else {
        throw TestError(message: "no naval carrier available to sail to Europe")
    }
    let carrierId = carrier.id
    if carrier.location != europeId {
        _ = try await client.ask(message: ParsedMessage(
            tag: "moveTo",
            attributes: ["unit": carrierId, "destination": europeId],
            children: []
        ), timeout: 8)
        print("    carrier \(carrierId) sailing to \(europeId)...")
        var arrived = false
        for _ in 0..<15 {
            try await endTurnAndWait(client: client, localPlayerId: localPlayerId)
            game = await client.game
            let transit = game.units[carrierId]
            print("    turn \(game.turn.number): carrier location=\(transit?.location ?? "nil") state=\(String(describing: transit?.state)) workLeft=\(transit?.workLeft ?? -1)")
            if transit?.location == europeId {
                arrived = true
                break
            }
        }
        guard arrived else {
            throw TestError(message: "carrier did not reach Europe within 15 turns (state \(String(describing: game.units[carrierId]?.state)))")
        }
    }
    print("    carrier \(carrierId) in \(europeId)")

    // Rejection paths first: they must not change the model.
    func expectRejection(_ message: ParsedMessage, label: String) async throws {
        let goldBefore = await client.game.players[localPlayerId]?.gold
        let unitsBefore = unitsInEurope(await client.game).count
        do {
            _ = try await client.ask(message: message, timeout: 10)
            throw TestError(message: "\(label) was not rejected by the server")
        } catch let FreeColProtocolError.serverError(text) {
            print("    \(label) rejected: \(text)")
        }
        try await Task.sleep(nanoseconds: 500_000_000)
        let after = await client.game
        guard after.players[localPlayerId]?.gold == goldBefore,
              unitsInEurope(after).count == unitsBefore else {
            throw TestError(message: "\(label) changed gold or Europe units")
        }
    }
    try await expectRejection(
        ParsedMessage(tag: "emigrateUnit", attributes: ["slot": "9"], children: []),
        label: "emigrateUnit with invalid slot")
    try await expectRejection(
        ParsedMessage(tag: "trainUnitInEurope", attributes: ["unitType": "model.unit.doesNotExist"], children: []),
        label: "trainUnitInEurope with unknown type")

    // Slot 1 is a concrete Europe offer. This path remains available without the
    // selectRecruit ability when the player is paying the normal recruit price.
    game = await client.game
    guard let europe = game.players[localPlayerId]?.europe else {
        throw TestError(message: "Europe data missing")
    }
    guard let selectedRecruitType = europe.recruitable.first?.unitType else {
        throw TestError(message: "Europe did not publish a recruit offer for slot 1")
    }
    let goldBeforeRecruit = game.players[localPlayerId]?.gold ?? 0
    let europeUnitsBeforeRecruit = unitsInEurope(game)
    let unitsBeforeRecruit = europeUnitsBeforeRecruit.count
    let unitIdsBeforeRecruit = Set(europeUnitsBeforeRecruit.map(\.id))
    guard goldBeforeRecruit >= europe.recruitPrice else {
        throw TestError(message: "cannot afford recruitment: gold \(goldBeforeRecruit) < \(europe.recruitPrice)")
    }
    print("    recruiting slot 1 (\(selectedRecruitType)), recruitPrice=\(europe.recruitPrice), gold=\(goldBeforeRecruit)")
    _ = try await client.ask(message: ParsedMessage(
        tag: "emigrateUnit", attributes: ["slot": "1"], children: []
    ), timeout: 10)
    var recruitedUnit: FreeColGame.Unit?
    for _ in 0..<30 {
        game = await client.game
        recruitedUnit = unitsInEurope(game).first {
            $0.unitType == selectedRecruitType
                && !unitIdsBeforeRecruit.contains($0.id)
        }
        if unitsInEurope(game).count == unitsBeforeRecruit + 1,
           recruitedUnit != nil {
            break
        }
        try await Task.sleep(nanoseconds: 200_000_000)
    }
    guard unitsInEurope(game).count == unitsBeforeRecruit + 1,
          let recruitedUnit else {
        throw TestError(message: "slot 1 recruit \(selectedRecruitType) did not appear in Europe")
    }
    let goldAfterRecruit = game.players[localPlayerId]?.gold ?? goldBeforeRecruit
    let recruitCost = goldBeforeRecruit - goldAfterRecruit
    guard recruitCost >= 0, recruitCost <= europe.recruitPrice else {
        throw TestError(message: "recruit cost \(recruitCost) outside 0...\(europe.recruitPrice)")
    }
    print("    recruit result: slot 1 produced \(recruitedUnit.id) \(recruitedUnit.unitType ?? "?"), gold \(goldBeforeRecruit)->\(goldAfterRecruit), Europe units \(unitsBeforeRecruit)->\(unitsBeforeRecruit + 1)")

    // Train: buy the cheapest affordable unit type for sale. Java prices a type at the
    // server's Europe override, else the specification price.
    game = await client.game
    let gold = game.players[localPlayerId]?.gold ?? 0
    let unitPrices = game.players[localPlayerId]?.europe?.unitPrices ?? [:]
    var forSale: [String: Int] = [:]
    for (id, info) in spec.unitTypes {
        if let price = unitPrices[id] ?? info.price, price > 0 { forSale[id] = price }
    }
    guard let (unitType, price) = forSale
        .filter({ $0.value <= gold })
        .sorted(by: { $0.value == $1.value ? $0.key < $1.key : $0.value < $1.value })
        .first else {
        throw TestError(message: "no affordable Europe unit among \(forSale) with gold \(gold)")
    }
    let unitsBeforeTrain = unitsInEurope(game)
    print("    training \(unitType) for \(price) gold (gold \(gold))")
    _ = try await client.ask(message: ParsedMessage(
        tag: "trainUnitInEurope", attributes: ["unitType": unitType], children: []
    ), timeout: 10)
    var trained: FreeColGame.Unit?
    for _ in 0..<30 {
        game = await client.game
        let knownIds = Set(unitsBeforeTrain.map(\.id))
        trained = unitsInEurope(game).first { !knownIds.contains($0.id) && $0.unitType == unitType }
        if trained != nil { break }
        try await Task.sleep(nanoseconds: 200_000_000)
    }
    guard let trained else {
        throw TestError(message: "trained \(unitType) did not appear in Europe")
    }
    let goldAfterTrain = game.players[localPlayerId]?.gold ?? gold
    guard goldAfterTrain == gold - price else {
        throw TestError(message: "train price mismatch: expected \(price), server charged \(gold - goldAfterTrain)")
    }
    print("    train result: \(trained.id) \(unitType) in Europe, gold \(gold)->\(goldAfterTrain)")
}

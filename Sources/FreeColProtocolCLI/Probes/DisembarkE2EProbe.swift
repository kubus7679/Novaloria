import Foundation
import FreeColProtocol
import FreeColGame
import FreeColClient

func disembarkE2EProbe() async throws {
    let environment = ProcessInfo.processInfo.environment
    let client = FreeColClient(
        host: environment["REAL_SERVER_HOST"] ?? "127.0.0.1",
        port: Int(environment["REAL_SERVER_PORT"] ?? "3541") ?? 3541
    )
    let result = try await connectAndLogin(
        client, userName: environment["REAL_SERVER_USERNAME"] ?? "FreeColE2ENativeTrade"
    )
    guard result.serverState != .preGame else {
        await client.disconnect()
        throw TestError(message: "disembark probe requires the scenario savegame")
    }
    let loopTask = Task { await client.startMessageLoop() }
    defer {
        loopTask.cancel()
        Task { await client.disconnect() }
    }
    let game = await client.game
    guard let localPlayer = game.players.values.first(where: { $0.name == result.playerName }),
          let europe = localPlayer.europe?.id,
          let specification = game.specification,
          let carrier = game.units.values.first(where: {
              $0.owner == localPlayer.id && $0.location == europe
                  && specification.carriesUnits(unitType: $0.unitType) == true
          }),
          let passenger = game.units.values.first(where: {
              $0.owner == localPlayer.id && $0.location == europe
                  && specification.hasAbility("model.ability.person", unitType: $0.unitType)
          }) else {
        throw TestError(message: "scenario needs a Europe carrier and a person at the docks")
    }
    _ = try await client.ask(message: ParsedMessage(
        tag: "embark", attributes: ["unit": passenger.id, "carrier": carrier.id], children: []
    ), timeout: 10)
    let aboard = await client.game.units[passenger.id]
    guard aboard?.location == carrier.id, aboard?.movesLeft == 0 else {
        throw TestError(message: "Java embark did not put an exhausted passenger aboard")
    }
    _ = try await client.ask(message: ParsedMessage(
        tag: "disembark", attributes: ["unit": passenger.id], children: []
    ), timeout: 10)
    let after = await client.game
    guard after.units[passenger.id]?.location == europe,
          after.units[passenger.id]?.movesLeft == 0,
          after.units[carrier.id]?.location == europe else {
        throw TestError(message: "Java disembark did not unload the exhausted passenger at the Europe docks")
    }
    print("    exhausted passenger unloaded at Europe docks; carrier stayed in port")
    guard let mapId = after.map?.id else {
        throw TestError(message: "scenario has no map destination for America")
    }
    _ = try await client.ask(message: ParsedMessage(
        tag: "setDestination", attributes: ["unit": carrier.id, "destination": mapId], children: []
    ), timeout: 10)
    guard await client.game.units[carrier.id]?.destination == mapId else {
        throw TestError(message: "Java did not confirm the stored destination")
    }
    _ = try await client.ask(message: ParsedMessage(
        tag: "setDestination", attributes: ["unit": carrier.id], children: []
    ), timeout: 10)
    guard await client.game.units[carrier.id]?.destination == nil else {
        throw TestError(message: "Java did not confirm destination cancellation")
    }
    print("    stored destination and cancellation confirmed by Java")
    _ = try await client.ask(message: ParsedMessage(
        tag: "embark", attributes: ["unit": passenger.id, "carrier": carrier.id], children: []
    ), timeout: 10)
    _ = try await client.ask(message: ParsedMessage(
        tag: "moveTo", attributes: ["unit": carrier.id, "destination": mapId], children: []
    ), timeout: 10)
    let departure = await client.game
    guard let ship = departure.units[carrier.id],
          ship.location?.hasPrefix("highSeas:") == true,
          ship.destination == mapId, ship.workLeft > 0,
          departure.units[passenger.id]?.location == carrier.id else {
        throw TestError(message: "Java did not start the return crossing with the passenger aboard")
    }
    print("    America return crossing confirmed with passenger aboard")
    await client.disconnect()
}

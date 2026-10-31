import Foundation
import FreeColClient
import FreeColGame
import FreeColProtocol

func runSessionMessageIntegrationTests() async {
  await integrationTest("client sends ready and requestLaunch messages") {
    let server = MockServer()
    let port = server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
      <game id="game-3" turn="1">
        <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
      </game>
      """

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        try await client.connect()
        _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
        try await client.send(
          message: ParsedMessage(tag: "ready", attributes: ["value": "true"], children: []))
        try await client.send(
          message: ParsedMessage(tag: "requestLaunch", attributes: [:], children: []))
        await client.disconnect()
      }
      group.addTask {
        try await server.doHandshake(gameResponse: gameXML)
        let readyLine = try await server.nextLine()
        let launchLine = try await server.nextLine()

        let readyMsg = try XMLDecoder.decode(readyLine)
        let launchMsg = try XMLDecoder.decode(launchLine)

        guard readyMsg.tag == "ready" else {
          throw TestError(message: "expected ready, got \(readyMsg.tag)")
        }
        guard readyMsg.attributes["value"] == "true" else {
          throw TestError(message: "ready value mismatch")
        }
        guard launchMsg.tag == "requestLaunch" else {
          throw TestError(message: "expected requestLaunch, got \(launchMsg.tag)")
        }
      }
      while try await group.next() != nil {}
    }

    await server.stop()
  }

  await integrationTest("client sends setNation message") {
    let server = MockServer()
    let port = server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
      <game id="game-3b" turn="1">
        <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
      </game>
      """

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        try await client.connect()
        _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
        try await client.send(
          message: ParsedMessage(
            tag: "setNation", attributes: ["player": "player-1", "value": "model.nation.english"],
            children: []))
        await client.disconnect()
      }
      group.addTask {
        try await server.doHandshake(gameResponse: gameXML)
        let line = try await server.nextLine()
        let msg = try XMLDecoder.decode(line)

        guard msg.tag == "setNation" else {
          throw TestError(message: "expected setNation, got \(msg.tag)")
        }
        guard msg.attributes["player"] == "player-1" else {
          throw TestError(message: "setNation player mismatch")
        }
        guard msg.attributes["value"] == "model.nation.english" else {
          throw TestError(message: "setNation value mismatch")
        }
      }
      while try await group.next() != nil {}
    }

    await server.stop()
  }

  await integrationTest("client sends setNationType message") {
    let server = MockServer()
    let port = server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
      <game id="game-3c" turn="1">
        <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
      </game>
      """

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        try await client.connect()
        _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
        try await client.send(
          message: ParsedMessage(
            tag: "setNationType",
            attributes: ["player": "player-1", "value": "model.nationType.default"], children: []))
        await client.disconnect()
      }
      group.addTask {
        try await server.doHandshake(gameResponse: gameXML)
        let line = try await server.nextLine()
        let msg = try XMLDecoder.decode(line)

        guard msg.tag == "setNationType" else {
          throw TestError(message: "expected setNationType, got \(msg.tag)")
        }
        guard msg.attributes["player"] == "player-1" else {
          throw TestError(message: "setNationType player mismatch")
        }
        guard msg.attributes["value"] == "model.nationType.default" else {
          throw TestError(message: "setNationType value mismatch")
        }
      }
      while try await group.next() != nil {}
    }

    await server.stop()
  }

  await integrationTest("client sends setColor message") {
    let server = MockServer()
    let port = server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
      <game id="game-3d" turn="1">
        <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
      </game>
      """

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        try await client.connect()
        _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
        try await client.send(
          message: ParsedMessage(
            tag: "setColor", attributes: ["nation": "model.nation.dutch", "color": "3368601"],
            children: []))
        await client.disconnect()
      }
      group.addTask {
        try await server.doHandshake(gameResponse: gameXML)
        let line = try await server.nextLine()
        let msg = try XMLDecoder.decode(line)

        guard msg.tag == "setColor" else {
          throw TestError(message: "expected setColor, got \(msg.tag)")
        }
        guard msg.attributes["nation"] == "model.nation.dutch" else {
          throw TestError(message: "setColor nation mismatch")
        }
        guard msg.attributes["color"] == "3368601" else {
          throw TestError(message: "setColor color mismatch")
        }
      }
      while try await group.next() != nil {}
    }

    await server.stop()
  }

  await integrationTest("client sends updateGameOptions message") {
    let server = MockServer()
    let port = server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
      <game id="game-3e" turn="1">
        <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
      </game>
      """

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        try await client.connect()
        _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
        try await client.send(
          message: ParsedMessage(
            tag: "updateGameOptions",
            attributes: [:],
            children: [
              ParsedMessage(
                tag: "option", attributes: ["id": "model.option.startingMoney", "value": "3000"],
                children: [])
            ]
          ))
        await client.disconnect()
      }
      group.addTask {
        try await server.doHandshake(gameResponse: gameXML)
        let line = try await server.nextLine()
        let msg = try XMLDecoder.decode(line)

        guard msg.tag == "updateGameOptions" else {
          throw TestError(message: "expected updateGameOptions, got \(msg.tag)")
        }
        guard let option = msg.children.first(where: { $0.tag == "option" }) else {
          throw TestError(message: "updateGameOptions option child missing")
        }
        guard option.attributes["id"] == "model.option.startingMoney" else {
          throw TestError(message: "updateGameOptions option id mismatch")
        }
        guard option.attributes["value"] == "3000" else {
          throw TestError(message: "updateGameOptions option value mismatch")
        }
      }
      while try await group.next() != nil {}
    }

    await server.stop()
  }

  await integrationTest("client sends updateMapGeneratorOptions message") {
    let server = MockServer()
    let port = server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
      <game id="game-3f" turn="1">
        <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
      </game>
      """

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        try await client.connect()
        _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
        try await client.send(
          message: ParsedMessage(
            tag: "updateMapGeneratorOptions",
            attributes: [:],
            children: [
              ParsedMessage(
                tag: "option", attributes: ["id": "model.option.mapWidth", "value": "80"],
                children: [])
            ]
          ))
        await client.disconnect()
      }
      group.addTask {
        try await server.doHandshake(gameResponse: gameXML)
        let line = try await server.nextLine()
        let msg = try XMLDecoder.decode(line)

        guard msg.tag == "updateMapGeneratorOptions" else {
          throw TestError(message: "expected updateMapGeneratorOptions, got \(msg.tag)")
        }
        guard let option = msg.children.first(where: { $0.tag == "option" }) else {
          throw TestError(message: "updateMapGeneratorOptions option child missing")
        }
        guard option.attributes["id"] == "model.option.mapWidth" else {
          throw TestError(message: "updateMapGeneratorOptions option id mismatch")
        }
        guard option.attributes["value"] == "80" else {
          throw TestError(message: "updateMapGeneratorOptions option value mismatch")
        }
      }
      while try await group.next() != nil {}
    }

    await server.stop()
  }

  await integrationTest("client sends chooseFoundingFather message") {
    let server = MockServer()
    let port = server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
      <game id="game-3g" turn="1">
        <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
      </game>
      """

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        try await client.connect()
        _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
        try await client.send(
          message: ParsedMessage(
            tag: "chooseFoundingFather",
            attributes: ["foundingFather": "model.foundingFather.adamSmith"],
            children: []
          ))
        await client.disconnect()
      }
      group.addTask {
        try await server.doHandshake(gameResponse: gameXML)
        let line = try await server.nextLine()
        let msg = try XMLDecoder.decode(line)

        guard msg.tag == "chooseFoundingFather" else {
          throw TestError(message: "expected chooseFoundingFather, got \(msg.tag)")
        }
        guard msg.attributes["foundingFather"] == "model.foundingFather.adamSmith" else {
          throw TestError(message: "chooseFoundingFather value mismatch")
        }
      }
      while try await group.next() != nil {}
    }

    await server.stop()
  }

  await integrationTest("client sends continue message") {
    let server = MockServer()
    let port = server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
      <game id="game-3h" turn="1">
        <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
      </game>
      """

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        try await client.connect()
        _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
        try await client.send(
          message: ParsedMessage(tag: "continue", attributes: [:], children: []))
        await client.disconnect()
      }
      group.addTask {
        try await server.doHandshake(gameResponse: gameXML)
        let line = try await server.nextLine()
        let msg = try XMLDecoder.decode(line)

        guard msg.tag == "continue" else {
          throw TestError(message: "expected continue, got \(msg.tag)")
        }
      }
      while try await group.next() != nil {}
    }

    await server.stop()
  }

  await integrationTest("client sends retire message") {
    let server = MockServer()
    let port = server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
      <game id="game-3i" turn="1">
        <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
      </game>
      """

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        try await client.connect()
        _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
        try await client.send(message: ParsedMessage(tag: "retire", attributes: [:], children: []))
        await client.disconnect()
      }
      group.addTask {
        try await server.doHandshake(gameResponse: gameXML)
        let line = try await server.nextLine()
        let msg = try XMLDecoder.decode(line)

        guard msg.tag == "retire" else {
          throw TestError(message: "expected retire, got \(msg.tag)")
        }
      }
      while try await group.next() != nil {}
    }

    await server.stop()
  }

  await integrationTest("client sends enterRevengeMode message") {
    let server = MockServer()
    let port = server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
      <game id="game-3j" turn="1">
        <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
      </game>
      """

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        try await client.connect()
        _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
        try await client.send(
          message: ParsedMessage(tag: "enterRevengeMode", attributes: [:], children: []))
        await client.disconnect()
      }
      group.addTask {
        try await server.doHandshake(gameResponse: gameXML)
        let line = try await server.nextLine()
        let msg = try XMLDecoder.decode(line)

        guard msg.tag == "enterRevengeMode" else {
          throw TestError(message: "expected enterRevengeMode, got \(msg.tag)")
        }
      }
      while try await group.next() != nil {}
    }

    await server.stop()
  }

  await integrationTest("client sends declineMounds message") {
    let server = MockServer()
    let port = server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
      <game id="game-3k" turn="1">
        <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
        <unit id="unit-1" unitType="model.unit.scout" owner="player-1" location="tile-0" movesLeft="3" state="ACTIVE"/>
        <map id="map-0" width="1" height="1">
          <tile id="tile-0" x="0" y="0" type="model.tile.plains"/>
        </map>
      </game>
      """

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        try await client.connect()
        _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
        try await client.send(
          message: ParsedMessage(tag: "declineMounds", attributes: ["unit": "unit-1"], children: [])
        )
        await client.disconnect()
      }
      group.addTask {
        try await server.doHandshake(gameResponse: gameXML)
        let line = try await server.nextLine()
        let msg = try XMLDecoder.decode(line)

        guard msg.tag == "declineMounds" else {
          throw TestError(message: "expected declineMounds, got \(msg.tag)")
        }
        guard msg.attributes["unit"] == "unit-1" else {
          throw TestError(message: "declineMounds unit mismatch")
        }
      }
      while try await group.next() != nil {}
    }

    await server.stop()
  }

  await integrationTest("client sends monarchAction message") {
    let server = MockServer()
    let port = server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
      <game id="game-3l" turn="1">
        <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
      </game>
      """

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        try await client.connect()
        _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
        try await client.send(
          message: ParsedMessage(
            tag: "monarchAction",
            attributes: ["action": "RAISE_TAX_ACT", "player": "player-1"],
            children: []
          ))
        await client.disconnect()
      }
      group.addTask {
        try await server.doHandshake(gameResponse: gameXML)
        let line = try await server.nextLine()
        let msg = try XMLDecoder.decode(line)

        guard msg.tag == "monarchAction" else {
          throw TestError(message: "expected monarchAction, got \(msg.tag)")
        }
        guard msg.attributes["action"] == "RAISE_TAX_ACT" else {
          throw TestError(message: "monarchAction action mismatch")
        }
        guard msg.attributes["player"] == "player-1" else {
          throw TestError(message: "monarchAction player mismatch")
        }
      }
      while try await group.next() != nil {}
    }

    await server.stop()
  }

  await integrationTest("client sends setAI message") {
    let server = MockServer()
    let port = server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
      <game id="game-3m" turn="1">
        <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
      </game>
      """

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        try await client.connect()
        _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
        try await client.send(
          message: ParsedMessage(
            tag: "setAI",
            attributes: ["player": "player-1", "ai": "true"],
            children: []
          ))
        await client.disconnect()
      }
      group.addTask {
        try await server.doHandshake(gameResponse: gameXML)
        let line = try await server.nextLine()
        let msg = try XMLDecoder.decode(line)

        guard msg.tag == "setAI" else {
          throw TestError(message: "expected setAI, got \(msg.tag)")
        }
        guard msg.attributes["player"] == "player-1" else {
          throw TestError(message: "setAI player mismatch")
        }
        guard msg.attributes["ai"] == "true" else {
          throw TestError(message: "setAI ai flag mismatch")
        }
      }
      while try await group.next() != nil {}
    }

    await server.stop()
  }

  await integrationTest("client sends setAvailable message") {
    let server = MockServer()
    let port = server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
      <game id="game-3n" turn="1">
        <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
      </game>
      """

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        try await client.connect()
        _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
        try await client.send(
          message: ParsedMessage(
            tag: "setAvailable",
            attributes: ["nation": "model.nation.dutch", "state": "NOT_AVAILABLE"],
            children: []
          ))
        await client.disconnect()
      }
      group.addTask {
        try await server.doHandshake(gameResponse: gameXML)
        let line = try await server.nextLine()
        let msg = try XMLDecoder.decode(line)

        guard msg.tag == "setAvailable" else {
          throw TestError(message: "expected setAvailable, got \(msg.tag)")
        }
        guard msg.attributes["nation"] == "model.nation.dutch" else {
          throw TestError(message: "setAvailable nation mismatch")
        }
        guard msg.attributes["state"] == "NOT_AVAILABLE" else {
          throw TestError(message: "setAvailable state mismatch")
        }
      }
      while try await group.next() != nil {}
    }

    await server.stop()
  }

  await integrationTest("client sends setStance message") {
    let server = MockServer()
    let port = server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
      <game id="game-3o" turn="1">
        <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
        <player id="player-2" username="Bob" nationId="model.nation.french" gold="500"/>
      </game>
      """

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        try await client.connect()
        _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
        try await client.send(
          message: ParsedMessage(
            tag: "setStance",
            attributes: ["stance": "WAR", "source": "player-1", "target": "player-2"],
            children: []
          ))
        await client.disconnect()
      }
      group.addTask {
        try await server.doHandshake(gameResponse: gameXML)
        let line = try await server.nextLine()
        let msg = try XMLDecoder.decode(line)

        guard msg.tag == "setStance" else {
          throw TestError(message: "expected setStance, got \(msg.tag)")
        }
        guard msg.attributes["stance"] == "WAR" else {
          throw TestError(message: "setStance stance mismatch")
        }
        guard msg.attributes["source"] == "player-1" else {
          throw TestError(message: "setStance source mismatch")
        }
        guard msg.attributes["target"] == "player-2" else {
          throw TestError(message: "setStance target mismatch")
        }
      }
      while try await group.next() != nil {}
    }

    await server.stop()
  }

  await integrationTest("client sends declareIndependence message") {
    let server = MockServer()
    let port = server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
      <game id="game-3p" turn="1">
        <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
      </game>
      """

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        try await client.connect()
        _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
        try await client.send(
          message: ParsedMessage(
            tag: "declareIndependence",
            attributes: ["countryName": "Freedonia", "nationName": "Free Colonials"],
            children: []
          ))
        await client.disconnect()
      }
      group.addTask {
        try await server.doHandshake(gameResponse: gameXML)
        let line = try await server.nextLine()
        let msg = try XMLDecoder.decode(line)

        guard msg.tag == "declareIndependence" else {
          throw TestError(message: "expected declareIndependence, got \(msg.tag)")
        }
        guard msg.attributes["countryName"] == "Freedonia" else {
          throw TestError(message: "declareIndependence countryName mismatch")
        }
        guard msg.attributes["nationName"] == "Free Colonials" else {
          throw TestError(message: "declareIndependence nationName mismatch")
        }
      }
      while try await group.next() != nil {}
    }

    await server.stop()
  }

  await integrationTest("client sends chat message") {
    let server = MockServer()
    let port = server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
      <game id="game-3q" turn="1">
        <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
        <player id="player-2" username="Bob" nationId="model.nation.french" gold="500"/>
      </game>
      """

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        try await client.connect()
        _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
        try await client.send(
          message: ParsedMessage(
            tag: "chat",
            attributes: ["sender": "player-1", "message": "Hello", "private": "player-2"],
            children: []
          ))
        await client.disconnect()
      }
      group.addTask {
        try await server.doHandshake(gameResponse: gameXML)
        let line = try await server.nextLine()
        let msg = try XMLDecoder.decode(line)

        guard msg.tag == "chat" else {
          throw TestError(message: "expected chat, got \(msg.tag)")
        }
        guard msg.attributes["sender"] == "player-1" else {
          throw TestError(message: "chat sender mismatch")
        }
        guard msg.attributes["message"] == "Hello" else {
          throw TestError(message: "chat message mismatch")
        }
        guard msg.attributes["private"] == "player-2" else {
          throw TestError(message: "chat private mismatch")
        }
      }
      while try await group.next() != nil {}
    }

    await server.stop()
  }

  await integrationTest("client sends setDead message") {
    let server = MockServer()
    let port = server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
      <game id="game-3r" turn="1">
        <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
      </game>
      """

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        try await client.connect()
        _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
        try await client.send(
          message: ParsedMessage(
            tag: "setDead",
            attributes: ["player": "player-1"],
            children: []
          ))
        await client.disconnect()
      }
      group.addTask {
        try await server.doHandshake(gameResponse: gameXML)
        let line = try await server.nextLine()
        let msg = try XMLDecoder.decode(line)

        guard msg.tag == "setDead" else {
          throw TestError(message: "expected setDead, got \(msg.tag)")
        }
        guard msg.attributes["player"] == "player-1" else {
          throw TestError(message: "setDead player mismatch")
        }
      }
      while try await group.next() != nil {}
    }

    await server.stop()
  }

  await integrationTest("client sends claimLand message") {
    let server = MockServer()
    let port = server.port
    let client = FreeColClient(host: "127.0.0.1", port: port)

    let gameXML = """
      <game id="game-3s" turn="1">
        <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
        <map id="map-0" width="2" height="1">
          <tile id="tile-0" x="0" y="0" type="model.tile.plains"/>
        </map>
      </game>
      """

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        try await client.connect()
        _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
        try await client.send(
          message: ParsedMessage(
            tag: "claimLand",
            attributes: ["price": "100", "claimant": "player-1", "tile": "tile-0"],
            children: []
          ))
        await client.disconnect()
      }
      group.addTask {
        try await server.doHandshake(gameResponse: gameXML)
        let line = try await server.nextLine()
        let msg = try XMLDecoder.decode(line)

        guard msg.tag == "claimLand" else {
          throw TestError(message: "expected claimLand, got \(msg.tag)")
        }
        guard msg.attributes["price"] == "100" else {
          throw TestError(message: "claimLand price mismatch")
        }
        guard msg.attributes["claimant"] == "player-1" else {
          throw TestError(message: "claimLand claimant mismatch")
        }
        guard msg.attributes["tile"] == "tile-0" else {
          throw TestError(message: "claimLand tile mismatch")
        }
      }
      while try await group.next() != nil {}
    }

    await server.stop()
  }
}

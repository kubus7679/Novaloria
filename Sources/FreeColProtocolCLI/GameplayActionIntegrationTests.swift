import Foundation
import NovaloriaClient
import FreeColGame
import FreeColProtocol

func runGameplayActionIntegrationTests() async {
  await integrationTest("client sends combat action messages") {
    let server = MockServer()
    let port = server.port
    let client = NovaloriaClient(host: "127.0.0.1", port: port)

    let gameXML = """
      <game id="game-12" turn="1">
        <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
        <player id="player-2" username="Bob" nationId="model.nation.french" gold="500"/>
        <map id="map-0" width="2" height="2">
          <tile id="tile-0" x="0" y="0" type="model.tile.plains"/>
          <tile id="tile-1" x="1" y="0" type="model.tile.plains"/>
          <tile id="tile-2" x="0" y="1" type="model.tile.plains"/>
        </map>
        <unit id="unit-1" unitType="model.unit.freeColonist" owner="player-1" location="tile-0" movesLeft="3" state="ACTIVE"/>
        <unit id="enemy-1" unitType="model.unit.freeColonist" owner="player-2" location="tile-1" movesLeft="3" state="ACTIVE"/>
      </game>
      """

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        try await client.connect()
        _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
        try await client.send(
          message: ParsedMessage(
            tag: "attack", attributes: ["unit": "unit-1", "direction": "E"], children: []))
        try await client.send(
          message: ParsedMessage(
            tag: "attackRanged", attributes: ["unit": "unit-1", "target": "tile-1"], children: []))
        await client.disconnect()
      }
      group.addTask {
        try await server.doHandshake(gameResponse: gameXML)

        let attackLine = try await server.nextLine()
        let rangedLine = try await server.nextLine()

        let attackMsg = try XMLDecoder.decode(attackLine)
        let rangedMsg = try XMLDecoder.decode(rangedLine)

        guard attackMsg.tag == "attack" else {
          throw TestError(message: "expected attack, got \(attackMsg.tag)")
        }
        guard attackMsg.attributes["unit"] == "unit-1" else {
          throw TestError(message: "attack unit mismatch")
        }
        guard attackMsg.attributes["direction"] == "E" else {
          throw TestError(message: "attack direction mismatch")
        }

        guard rangedMsg.tag == "attackRanged" else {
          throw TestError(message: "expected attackRanged, got \(rangedMsg.tag)")
        }
        guard rangedMsg.attributes["unit"] == "unit-1" else {
          throw TestError(message: "attackRanged unit mismatch")
        }
        guard rangedMsg.attributes["target"] == "tile-1" else {
          throw TestError(message: "attackRanged target mismatch")
        }
      }
      while try await group.next() != nil {}
    }

    await server.stop()
  }

  await integrationTest("client sends equipForRole action") {
    let server = MockServer()
    let port = server.port
    let client = NovaloriaClient(host: "127.0.0.1", port: port)

    let gameXML = """
      <game id="game-equip-1" turn="1">
        <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
        <map id="map-0" width="2" height="2">
          <tile id="tile-0" x="0" y="0" type="model.tile.plains"/>
        </map>
        <unit id="unit-1" unitType="model.unit.freeColonist" owner="player-1" location="tile-0" movesLeft="3" state="ACTIVE"/>
      </game>
      """

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        try await client.connect()
        _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
        try await client.send(
          message: ParsedMessage(
            tag: "equipForRole",
            attributes: ["unit": "unit-1", "role": "model.role.missionary", "count": "1"],
            children: []
          ))
        await client.disconnect()
      }
      group.addTask {
        try await server.doHandshake(gameResponse: gameXML)

        let equipLine = try await server.nextLine()
        let equipMsg = try XMLDecoder.decode(equipLine)

        guard equipMsg.tag == "equipForRole" else {
          throw TestError(message: "expected equipForRole, got \(equipMsg.tag)")
        }
        guard equipMsg.attributes["unit"] == "unit-1" else {
          throw TestError(message: "equipForRole unit mismatch")
        }
        guard equipMsg.attributes["role"] == "model.role.missionary" else {
          throw TestError(message: "equipForRole role mismatch")
        }
        guard equipMsg.attributes["count"] == "1" else {
          throw TestError(message: "equipForRole count mismatch")
        }
      }
      while try await group.next() != nil {}
    }

    await server.stop()
  }

  await integrationTest("client sends missionary action") {
    let server = MockServer()
    let port = server.port
    let client = NovaloriaClient(host: "127.0.0.1", port: port)

    let gameXML = """
      <game id="game-missionary-1" turn="1">
        <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
        <map id="map-0" width="2" height="2">
          <tile id="tile-0" x="0" y="0" type="model.tile.plains"/>
        </map>
        <unit id="unit-1" unitType="model.unit.missionary" owner="player-1" location="tile-0" movesLeft="3" state="ACTIVE"/>
      </game>
      """

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        try await client.connect()
        _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
        try await client.send(
          message: ParsedMessage(
            tag: "missionary",
            attributes: ["unit": "unit-1", "direction": "N", "denounce": "true"],
            children: []
          ))
        await client.disconnect()
      }
      group.addTask {
        try await server.doHandshake(gameResponse: gameXML)

        let missionaryLine = try await server.nextLine()
        let missionaryMsg = try XMLDecoder.decode(missionaryLine)

        guard missionaryMsg.tag == "missionary" else {
          throw TestError(message: "expected missionary, got \(missionaryMsg.tag)")
        }
        guard missionaryMsg.attributes["unit"] == "unit-1" else {
          throw TestError(message: "missionary unit mismatch")
        }
        guard missionaryMsg.attributes["direction"] == "N" else {
          throw TestError(message: "missionary direction mismatch")
        }
        guard missionaryMsg.attributes["denounce"] == "true" else {
          throw TestError(message: "missionary denounce mismatch")
        }
      }
      while try await group.next() != nil {}
    }

    await server.stop()
  }

  await integrationTest("client sends learnSkill action") {
    let server = MockServer()
    let port = server.port
    let client = NovaloriaClient(host: "127.0.0.1", port: port)

    let gameXML = """
      <game id="game-learn-1" turn="1">
        <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
        <map id="map-0" width="3" height="3">
          <tile id="tile-0" x="0" y="0" type="model.tile.plains"/>
          <tile id="tile-1" x="1" y="0" type="model.tile.plains"/>
        </map>
        <unit id="unit-1" unitType="model.unit.freeColonist" owner="player-1" location="tile-0" movesLeft="3" state="ACTIVE"/>
      </game>
      """

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        try await client.connect()
        _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
        try await client.send(
          message: ParsedMessage(
            tag: "learnSkill",
            attributes: ["unit": "unit-1", "direction": "NE"],
            children: []
          ))
        await client.disconnect()
      }
      group.addTask {
        try await server.doHandshake(gameResponse: gameXML)

        let learnLine = try await server.nextLine()
        let learnMsg = try XMLDecoder.decode(learnLine)

        guard learnMsg.tag == "learnSkill" else {
          throw TestError(message: "expected learnSkill, got \(learnMsg.tag)")
        }
        guard learnMsg.attributes["unit"] == "unit-1" else {
          throw TestError(message: "learnSkill unit mismatch")
        }
        guard learnMsg.attributes["direction"] == "NE" else {
          throw TestError(message: "learnSkill direction mismatch")
        }
      }
      while try await group.next() != nil {}
    }

    await server.stop()
  }

  await integrationTest("client sends newLandName action") {
    let server = MockServer()
    let port = server.port
    let client = NovaloriaClient(host: "127.0.0.1", port: port)

    let gameXML = """
      <game id="game-newland-1" turn="1">
        <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
        <map id="map-0" width="2" height="2">
          <tile id="tile-0" x="0" y="0" type="model.tile.plains"/>
        </map>
        <unit id="unit-1" unitType="model.unit.caravel" owner="player-1" location="tile-0" movesLeft="3" state="ACTIVE"/>
      </game>
      """

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        try await client.connect()
        _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
        try await client.send(
          message: ParsedMessage(
            tag: "newLandName",
            attributes: ["unit": "unit-1", "newLandName": "New Amsterdam"],
            children: []
          ))
        await client.disconnect()
      }
      group.addTask {
        try await server.doHandshake(gameResponse: gameXML)

        let nameLine = try await server.nextLine()
        let nameMsg = try XMLDecoder.decode(nameLine)

        guard nameMsg.tag == "newLandName" else {
          throw TestError(message: "expected newLandName, got \(nameMsg.tag)")
        }
        guard nameMsg.attributes["unit"] == "unit-1" else {
          throw TestError(message: "newLandName unit mismatch")
        }
        guard nameMsg.attributes["newLandName"] == "New Amsterdam" else {
          throw TestError(message: "newLandName name mismatch")
        }
      }
      while try await group.next() != nil {}
    }

    await server.stop()
  }

  await integrationTest("client sends newRegionName action") {
    let server = MockServer()
    let port = server.port
    let client = NovaloriaClient(host: "127.0.0.1", port: port)

    let gameXML = """
      <game id="game-newregion-1" turn="1">
        <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
        <map id="map-0" width="3" height="3">
          <tile id="tile-0" x="0" y="0" type="model.tile.plains"/>
          <tile id="tile-1" x="1" y="0" type="model.tile.plains"/>
        </map>
        <unit id="unit-1" unitType="model.unit.caravel" owner="player-1" location="tile-0" movesLeft="3" state="ACTIVE"/>
      </game>
      """

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        try await client.connect()
        _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
        try await client.send(
          message: ParsedMessage(
            tag: "newRegionName",
            attributes: [
              "newRegionName": "Pacific Zone",
              "region": "region-5",
              "tile": "tile-1",
              "unit": "unit-1",
            ],
            children: []
          ))
        await client.disconnect()
      }
      group.addTask {
        try await server.doHandshake(gameResponse: gameXML)

        let regionLine = try await server.nextLine()
        let regionMsg = try XMLDecoder.decode(regionLine)

        guard regionMsg.tag == "newRegionName" else {
          throw TestError(message: "expected newRegionName, got \(regionMsg.tag)")
        }
        guard regionMsg.attributes["unit"] == "unit-1" else {
          throw TestError(message: "newRegionName unit mismatch")
        }
        guard regionMsg.attributes["region"] == "region-5" else {
          throw TestError(message: "newRegionName region mismatch")
        }
        guard regionMsg.attributes["tile"] == "tile-1" else {
          throw TestError(message: "newRegionName tile mismatch")
        }
        guard regionMsg.attributes["newRegionName"] == "Pacific Zone" else {
          throw TestError(message: "newRegionName name mismatch")
        }
      }
      while try await group.next() != nil {}
    }

    await server.stop()
  }

  await integrationTest("client sends incite action") {
    let server = MockServer()
    let port = server.port
    let client = NovaloriaClient(host: "127.0.0.1", port: port)

    let gameXML = """
      <game id="game-incite-1" turn="1">
        <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
        <player id="player-2" username="Bob" nationId="model.nation.french" gold="300"/>
        <map id="map-0" width="2" height="2">
          <tile id="tile-0" x="0" y="0" type="model.tile.plains"/>
        </map>
        <unit id="unit-1" unitType="model.unit.freeColonist" owner="player-1" location="tile-0" movesLeft="3" state="ACTIVE"/>
      </game>
      """

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        try await client.connect()
        _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
        try await client.send(
          message: ParsedMessage(
            tag: "incite",
            attributes: [
              "enemy": "player-2",
              "gold": "200",
              "settlement": "is-5",
              "unit": "unit-1",
            ],
            children: []
          ))
        await client.disconnect()
      }
      group.addTask {
        try await server.doHandshake(gameResponse: gameXML)

        let inciteLine = try await server.nextLine()
        let inciteMsg = try XMLDecoder.decode(inciteLine)

        guard inciteMsg.tag == "incite" else {
          throw TestError(message: "expected incite, got \(inciteMsg.tag)")
        }
        guard inciteMsg.attributes["unit"] == "unit-1" else {
          throw TestError(message: "incite unit mismatch")
        }
        guard inciteMsg.attributes["settlement"] == "is-5" else {
          throw TestError(message: "incite settlement mismatch")
        }
        guard inciteMsg.attributes["enemy"] == "player-2" else {
          throw TestError(message: "incite enemy mismatch")
        }
        guard inciteMsg.attributes["gold"] == "200" else {
          throw TestError(message: "incite gold mismatch")
        }
      }
      while try await group.next() != nil {}
    }

    await server.stop()
  }

  await integrationTest("client sends deliverGift action") {
    let server = MockServer()
    let port = server.port
    let client = NovaloriaClient(host: "127.0.0.1", port: port)

    let gameXML = """
      <game id="game-gift-1" turn="1">
        <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
        <map id="map-0" width="2" height="2">
          <tile id="tile-0" x="0" y="0" type="model.tile.plains"/>
        </map>
        <unit id="unit-missionary" unitType="model.unit.missionary" owner="player-1" location="tile-0" movesLeft="3" state="ACTIVE"/>
      </game>
      """

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        try await client.connect()
        _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
        try await client.send(
          message: ParsedMessage(
            tag: "deliverGift",
            attributes: [
              "settlement": "is-tribal-village",
              "unit": "unit-missionary",
            ],
            children: []
          ))
        await client.disconnect()
      }
      group.addTask {
        try await server.doHandshake(gameResponse: gameXML)

        let giftLine = try await server.nextLine()
        let giftMsg = try XMLDecoder.decode(giftLine)

        guard giftMsg.tag == "deliverGift" else {
          throw TestError(message: "expected deliverGift, got \(giftMsg.tag)")
        }
        guard giftMsg.attributes["unit"] == "unit-missionary" else {
          throw TestError(message: "deliverGift unit mismatch")
        }
        guard giftMsg.attributes["settlement"] == "is-tribal-village" else {
          throw TestError(message: "deliverGift settlement mismatch")
        }
      }
      while try await group.next() != nil {}
    }

    await server.stop()
  }

  await integrationTest("client sends demandTribute action") {
    let server = MockServer()
    let port = server.port
    let client = NovaloriaClient(host: "127.0.0.1", port: port)

    let gameXML = """
      <game id="game-tribute-1" turn="1">
        <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
        <map id="map-0" width="3" height="3">
          <tile id="tile-0" x="0" y="0" type="model.tile.plains"/>
          <tile id="tile-1" x="1" y="0" type="model.tile.plains"/>
        </map>
        <unit id="unit-scout" unitType="model.unit.scout" owner="player-1" location="tile-0" movesLeft="3" state="ACTIVE"/>
      </game>
      """

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        try await client.connect()
        _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
        try await client.send(
          message: ParsedMessage(
            tag: "demandTribute",
            attributes: [
              "direction": "N",
              "unit": "unit-scout",
            ],
            children: []
          ))
        await client.disconnect()
      }
      group.addTask {
        try await server.doHandshake(gameResponse: gameXML)

        let tributeLine = try await server.nextLine()
        let tributeMsg = try XMLDecoder.decode(tributeLine)

        guard tributeMsg.tag == "demandTribute" else {
          throw TestError(message: "expected demandTribute, got \(tributeMsg.tag)")
        }
        guard tributeMsg.attributes["unit"] == "unit-scout" else {
          throw TestError(message: "demandTribute unit mismatch")
        }
        guard tributeMsg.attributes["direction"] == "N" else {
          throw TestError(message: "demandTribute direction mismatch")
        }
      }
      while try await group.next() != nil {}
    }

    await server.stop()
  }

  await integrationTest("client sends nativeGift action") {
    let server = MockServer()
    let port = server.port
    let client = NovaloriaClient(host: "127.0.0.1", port: port)

    let gameXML = """
      <game id="game-gift-native-1" turn="1">
        <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
        <map id="map-0" width="2" height="2">
          <tile id="tile-0" x="0" y="0" type="model.tile.plains"/>
        </map>
        <unit id="unit-colonist" unitType="model.unit.freeColonist" owner="player-1" location="tile-0" movesLeft="3" state="ACTIVE"/>
      </game>
      """

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        try await client.connect()
        _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
        try await client.send(
          message: ParsedMessage(
            tag: "nativeGift",
            attributes: [
              "colony": "colony-salem",
              "unit": "unit-colonist",
            ],
            children: []
          ))
        await client.disconnect()
      }
      group.addTask {
        try await server.doHandshake(gameResponse: gameXML)

        let giftLine = try await server.nextLine()
        let giftMsg = try XMLDecoder.decode(giftLine)

        guard giftMsg.tag == "nativeGift" else {
          throw TestError(message: "expected nativeGift, got \(giftMsg.tag)")
        }
        guard giftMsg.attributes["unit"] == "unit-colonist" else {
          throw TestError(message: "nativeGift unit mismatch")
        }
        guard giftMsg.attributes["colony"] == "colony-salem" else {
          throw TestError(message: "nativeGift colony mismatch")
        }
      }
      while try await group.next() != nil {}
    }

    await server.stop()
  }

  await integrationTest("client sends spySettlement action") {
    let server = MockServer()
    let port = server.port
    let client = NovaloriaClient(host: "127.0.0.1", port: port)

    let gameXML = """
      <game id="game-spy-1" turn="1">
        <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
        <map id="map-0" width="2" height="2">
          <tile id="tile-0" x="0" y="0" type="model.tile.plains"/>
        </map>
        <unit id="unit-scout" unitType="model.unit.scout" owner="player-1" location="tile-0" movesLeft="3" state="ACTIVE"/>
      </game>
      """

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        try await client.connect()
        _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
        try await client.send(
          message: ParsedMessage(
            tag: "spySettlement",
            attributes: [
              "settlement": "is-mohawk-1",
              "unit": "unit-scout",
            ],
            children: []
          ))
        await client.disconnect()
      }
      group.addTask {
        try await server.doHandshake(gameResponse: gameXML)

        let spyLine = try await server.nextLine()
        let spyMsg = try XMLDecoder.decode(spyLine)

        guard spyMsg.tag == "spySettlement" else {
          throw TestError(message: "expected spySettlement, got \(spyMsg.tag)")
        }
        guard spyMsg.attributes["unit"] == "unit-scout" else {
          throw TestError(message: "spySettlement unit mismatch")
        }
        guard spyMsg.attributes["settlement"] == "is-mohawk-1" else {
          throw TestError(message: "spySettlement settlement mismatch")
        }
      }
      while try await group.next() != nil {}
    }

    await server.stop()
  }

  await integrationTest("client sends scoutIndianSettlement action") {
    let server = MockServer()
    let port = server.port
    let client = NovaloriaClient(host: "127.0.0.1", port: port)

    let gameXML = """
      <game id="game-scout-1" turn="1">
        <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
        <map id="map-0" width="3" height="3">
          <tile id="tile-0" x="0" y="0" type="model.tile.plains"/>
          <tile id="tile-1" x="1" y="0" type="model.tile.plains"/>
        </map>
        <unit id="unit-scout" unitType="model.unit.scout" owner="player-1" location="tile-0" movesLeft="3" state="ACTIVE"/>
      </game>
      """

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        try await client.connect()
        _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
        try await client.send(
          message: ParsedMessage(
            tag: "scoutIndianSettlement",
            attributes: [
              "direction": "E",
              "unit": "unit-scout",
            ],
            children: []
          ))
        await client.disconnect()
      }
      group.addTask {
        try await server.doHandshake(gameResponse: gameXML)

        let scoutLine = try await server.nextLine()
        let scoutMsg = try XMLDecoder.decode(scoutLine)

        guard scoutMsg.tag == "scoutIndianSettlement" else {
          throw TestError(message: "expected scoutIndianSettlement, got \(scoutMsg.tag)")
        }
        guard scoutMsg.attributes["unit"] == "unit-scout" else {
          throw TestError(message: "scoutIndianSettlement unit mismatch")
        }
        guard scoutMsg.attributes["direction"] == "E" else {
          throw TestError(message: "scoutIndianSettlement direction mismatch")
        }
      }
      while try await group.next() != nil {}
    }

    await server.stop()
  }

  await integrationTest("client sends scoutSpeakToChief action") {
    let server = MockServer()
    let port = server.port
    let client = NovaloriaClient(host: "127.0.0.1", port: port)

    let gameXML = """
      <game id="game-chief-1" turn="1">
        <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
        <map id="map-0" width="2" height="2">
          <tile id="tile-0" x="0" y="0" type="model.tile.plains"/>
        </map>
        <unit id="unit-scout" unitType="model.unit.scout" owner="player-1" location="tile-0" movesLeft="3" state="ACTIVE"/>
      </game>
      """

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        try await client.connect()
        _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
        try await client.send(
          message: ParsedMessage(
            tag: "scoutSpeakToChief",
            attributes: [
              "result": "alliance",
              "settlement": "is-iroquois-tribe",
              "unit": "unit-scout",
            ],
            children: []
          ))
        await client.disconnect()
      }
      group.addTask {
        try await server.doHandshake(gameResponse: gameXML)

        let chiefLine = try await server.nextLine()
        let chiefMsg = try XMLDecoder.decode(chiefLine)

        guard chiefMsg.tag == "scoutSpeakToChief" else {
          throw TestError(message: "expected scoutSpeakToChief, got \(chiefMsg.tag)")
        }
        guard chiefMsg.attributes["unit"] == "unit-scout" else {
          throw TestError(message: "scoutSpeakToChief unit mismatch")
        }
        guard chiefMsg.attributes["settlement"] == "is-iroquois-tribe" else {
          throw TestError(message: "scoutSpeakToChief settlement mismatch")
        }
        guard chiefMsg.attributes["result"] == "alliance" else {
          throw TestError(message: "scoutSpeakToChief result mismatch")
        }
      }
      while try await group.next() != nil {}
    }

    await server.stop()
  }

  await integrationTest("client sends diplomacy action") {
    let server = MockServer()
    let port = server.port
    let client = NovaloriaClient(host: "127.0.0.1", port: port)

    let gameXML = """
      <game id="game-diplo-1" turn="1">
       <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
       <player id="player-2" username="Bob" nationId="model.nation.french" gold="400"/>
       <map id="map-0" width="2" height="2">
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
            tag: "diplomacy",
            attributes: [
              "otherId": "player-2",
              "ourId": "player-1",
            ],
            children: []
          ))
        await client.disconnect()
      }
      group.addTask {
        try await server.doHandshake(gameResponse: gameXML)

        let diploLine = try await server.nextLine()
        let diploMsg = try XMLDecoder.decode(diploLine)

        guard diploMsg.tag == "diplomacy" else {
          throw TestError(message: "expected diplomacy, got \(diploMsg.tag)")
        }
        guard diploMsg.attributes["ourId"] == "player-1" else {
          throw TestError(message: "diplomacy ourId mismatch")
        }
        guard diploMsg.attributes["otherId"] == "player-2" else {
          throw TestError(message: "diplomacy otherId mismatch")
        }
      }
      while try await group.next() != nil {}
    }

    await server.stop()
  }
}

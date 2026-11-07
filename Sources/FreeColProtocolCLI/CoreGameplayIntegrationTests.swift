import Foundation
import NovaloriaClient
import FreeColGame
import FreeColProtocol

func runCoreGameplayIntegrationTests() async {
  await integrationTest("client asks core gameplay actions with replies") {
    let server = MockServer()
    let port = server.port
    let client = NovaloriaClient(host: "127.0.0.1", port: port)

    let gameXML = """
      <game id="game-5" turn="1">
        <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
        <unit id="unit-1" unitType="model.unit.freeColonist" owner="player-1" location="tile-0" movesLeft="3" state="ACTIVE"/>
        <map id="map-0" width="2" height="1">
          <tile id="tile-0" x="0" y="0" type="model.tile.plains"/>
          <tile id="tile-1" x="1" y="0" type="model.tile.plains"/>
        </map>
      </game>
      """

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        try await client.connect()
        _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
        _ = try await client.ask(
          message: ParsedMessage(
            tag: "moveTo", attributes: ["unit": "unit-1", "destination": "tile-1"], children: []))
        _ = try await client.ask(
          message: ParsedMessage(
            tag: "move", attributes: ["unit": "unit-1", "direction": "E"], children: []))
        _ = try await client.ask(
          message: ParsedMessage(
            tag: "buildColony", attributes: ["unit": "unit-1", "name": "Alpha"], children: []))
        _ = try await client.ask(
          message: ParsedMessage(tag: "endTurn", attributes: [:], children: []))
        await client.disconnect()
      }
      group.addTask {
        try await server.doHandshake(gameResponse: gameXML)
        let expectedActions: [(tag: String, attributes: [String: String])] = [
          ("moveTo", ["unit": "unit-1", "destination": "tile-1"]),
          ("move", ["unit": "unit-1", "direction": "E"]),
          ("buildColony", ["unit": "unit-1", "name": "Alpha"]),
          ("endTurn", [:]),
        ]
        for expected in expectedActions {
          let line = try await server.nextLine()
          let question = try XMLDecoder.decode(line)
          guard question.tag == "question",
            let replyId = question.attributes["networkReplyId"],
            let action = question.children.first
          else {
            throw TestError(message: "expected question wrapper for \(expected.tag)")
          }
          guard action.tag == expected.tag else {
            throw TestError(message: "expected \(expected.tag), got \(action.tag)")
          }
          for (key, value) in expected.attributes where action.attributes[key] != value {
            throw TestError(message: "\(expected.tag) attribute \(key) mismatch")
          }
          await server.send(
            XMLEncoder.encode(tag: "reply", attributes: ["networkReplyId": replyId]))
          await server.flush()
        }
      }
      while try await group.next() != nil {}
    }

    await server.stop()
  }

  await integrationTest("client sends joinColony/embark/disembark messages") {
    let server = MockServer()
    let port = server.port
    let client = NovaloriaClient(host: "127.0.0.1", port: port)

    let gameXML = """
      <game id="game-6" turn="1">
        <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
        <map id="map-0" width="2" height="1">
          <tile id="tile-0" x="0" y="0" type="model.tile.plains"/>
          <tile id="tile-1" x="1" y="0" type="model.tile.plains"/>
        </map>
        <unit id="unit-1" unitType="model.unit.freeColonist" owner="player-1" location="tile-0" movesLeft="3" state="ACTIVE"/>
        <unit id="unit-ship" unitType="model.unit.caravel" owner="player-1" location="tile-0" movesLeft="6" state="ACTIVE"/>
        <colony id="colony-1" name="Alpha" owner="player-1" tile="tile-0" settlementType="model.settlement.colony"/>
      </game>
      """

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        try await client.connect()
        _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
        try await client.send(
          message: ParsedMessage(
            tag: "joinColony", attributes: ["unit": "unit-1", "colony": "colony-1"], children: []))
        try await client.send(
          message: ParsedMessage(
            tag: "embark", attributes: ["unit": "unit-1", "carrier": "unit-ship"], children: []))
        try await client.send(
          message: ParsedMessage(tag: "disembark", attributes: ["unit": "unit-1"], children: []))
        await client.disconnect()
      }
      group.addTask {
        try await server.doHandshake(gameResponse: gameXML)

        let joinLine = try await server.nextLine()
        let embarkLine = try await server.nextLine()
        let disembarkLine = try await server.nextLine()

        let joinMsg = try XMLDecoder.decode(joinLine)
        let embarkMsg = try XMLDecoder.decode(embarkLine)
        let disembarkMsg = try XMLDecoder.decode(disembarkLine)

        guard joinMsg.tag == "joinColony" else {
          throw TestError(message: "expected joinColony, got \(joinMsg.tag)")
        }
        guard joinMsg.attributes["unit"] == "unit-1" else {
          throw TestError(message: "joinColony unit mismatch")
        }
        guard joinMsg.attributes["colony"] == "colony-1" else {
          throw TestError(message: "joinColony colony mismatch")
        }

        guard embarkMsg.tag == "embark" else {
          throw TestError(message: "expected embark, got \(embarkMsg.tag)")
        }
        guard embarkMsg.attributes["unit"] == "unit-1" else {
          throw TestError(message: "embark unit mismatch")
        }
        guard embarkMsg.attributes["carrier"] == "unit-ship" else {
          throw TestError(message: "embark carrier mismatch")
        }

        guard disembarkMsg.tag == "disembark" else {
          throw TestError(message: "expected disembark, got \(disembarkMsg.tag)")
        }
        guard disembarkMsg.attributes["unit"] == "unit-1" else {
          throw TestError(message: "disembark unit mismatch")
        }
      }
      while try await group.next() != nil {}
    }

    await server.stop()
  }

  await integrationTest("client sends changeState message") {
    let server = MockServer()
    let port = server.port
    let client = NovaloriaClient(host: "127.0.0.1", port: port)

    let gameXML = """
      <game id="game-7" turn="1">
        <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
        <unit id="unit-1" unitType="model.unit.freeColonist" owner="player-1" location="tile-0" movesLeft="3" state="ACTIVE"/>
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
          message: ParsedMessage(
            tag: "changeState", attributes: ["unit": "unit-1", "state": "SENTRY"], children: []))
        try await client.send(
          message: ParsedMessage(
            tag: "changeState", attributes: ["unit": "unit-1", "state": "SKIPPED"], children: []))
        await client.disconnect()
      }
      group.addTask {
        try await server.doHandshake(gameResponse: gameXML)

        let line1 = try await server.nextLine()
        let msg1 = try XMLDecoder.decode(line1)
        guard msg1.tag == "changeState" else {
          throw TestError(message: "expected first changeState, got \(msg1.tag)")
        }
        guard msg1.attributes["unit"] == "unit-1" else {
          throw TestError(message: "first changeState unit mismatch")
        }
        guard msg1.attributes["state"] == "SENTRY" else {
          throw TestError(message: "first changeState state mismatch")
        }

        let line2 = try await server.nextLine()
        let msg2 = try XMLDecoder.decode(line2)
        guard msg2.tag == "changeState" else {
          throw TestError(message: "expected second changeState, got \(msg2.tag)")
        }
        guard msg2.attributes["unit"] == "unit-1" else {
          throw TestError(message: "second changeState unit mismatch")
        }
        guard msg2.attributes["state"] == "SKIPPED" else {
          throw TestError(message: "second changeState state mismatch")
        }
      }
      while try await group.next() != nil {}
    }

    await server.stop()
  }

  await integrationTest("client sends changeWorkImprovementType message") {
    let server = MockServer()
    let port = server.port
    let client = NovaloriaClient(host: "127.0.0.1", port: port)

    let gameXML = """
      <game id="game-7b" turn="1">
        <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
        <unit id="unit-1" unitType="model.unit.freeColonist" owner="player-1" location="tile-0" movesLeft="3" state="ACTIVE"/>
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
          message: ParsedMessage(
            tag: "changeWorkImprovementType",
            attributes: ["unit": "unit-1", "improvementType": "model.improvement.plow"],
            children: []))
        await client.disconnect()
      }
      group.addTask {
        try await server.doHandshake(gameResponse: gameXML)

        let line = try await server.nextLine()
        let msg = try XMLDecoder.decode(line)
        guard msg.tag == "changeWorkImprovementType" else {
          throw TestError(message: "expected changeWorkImprovementType, got \(msg.tag)")
        }
        guard msg.attributes["unit"] == "unit-1" else {
          throw TestError(message: "changeWorkImprovementType unit mismatch")
        }
        guard msg.attributes["improvementType"] == "model.improvement.plow" else {
          throw TestError(message: "changeWorkImprovementType improvementType mismatch")
        }
      }
      while try await group.next() != nil {}
    }

    await server.stop()
  }

  await integrationTest("client sends disbandUnit message") {
    let server = MockServer()
    let port = server.port
    let client = NovaloriaClient(host: "127.0.0.1", port: port)

    let gameXML = """
      <game id="game-8" turn="1">
        <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
        <unit id="unit-1" unitType="model.unit.freeColonist" owner="player-1" location="tile-0" movesLeft="3" state="ACTIVE"/>
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
          message: ParsedMessage(tag: "disbandUnit", attributes: ["unit": "unit-1"], children: []))
        await client.disconnect()
      }
      group.addTask {
        try await server.doHandshake(gameResponse: gameXML)

        let line = try await server.nextLine()
        let msg = try XMLDecoder.decode(line)
        guard msg.tag == "disbandUnit" else {
          throw TestError(message: "expected disbandUnit, got \(msg.tag)")
        }
        guard msg.attributes["unit"] == "unit-1" else {
          throw TestError(message: "disbandUnit unit mismatch")
        }
      }
      while try await group.next() != nil {}
    }

    await server.stop()
  }

  await integrationTest("client sends setDestination message") {
    let server = MockServer()
    let port = server.port
    let client = NovaloriaClient(host: "127.0.0.1", port: port)

    let gameXML = """
      <game id="game-9" turn="1">
        <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
        <unit id="unit-1" unitType="model.unit.freeColonist" owner="player-1" location="tile-0" movesLeft="3" state="ACTIVE"/>
        <map id="map-0" width="2" height="1">
          <tile id="tile-0" x="0" y="0" type="model.tile.plains"/>
          <tile id="tile-1" x="1" y="0" type="model.tile.plains"/>
        </map>
      </game>
      """

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        try await client.connect()
        _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
        try await client.send(
          message: ParsedMessage(
            tag: "setDestination", attributes: ["unit": "unit-1", "destination": "tile-1"],
            children: []))
        try await client.send(
          message: ParsedMessage(
            tag: "setDestination", attributes: ["unit": "unit-1"], children: []))
        await client.disconnect()
      }
      group.addTask {
        try await server.doHandshake(gameResponse: gameXML)

        let setLine = try await server.nextLine()
        let clearLine = try await server.nextLine()

        let setMsg = try XMLDecoder.decode(setLine)
        let clearMsg = try XMLDecoder.decode(clearLine)

        guard setMsg.tag == "setDestination" else {
          throw TestError(message: "expected setDestination, got \(setMsg.tag)")
        }
        guard setMsg.attributes["unit"] == "unit-1" else {
          throw TestError(message: "setDestination unit mismatch")
        }
        guard setMsg.attributes["destination"] == "tile-1" else {
          throw TestError(message: "setDestination destination mismatch")
        }

        guard clearMsg.tag == "setDestination" else {
          throw TestError(message: "expected setDestination clear, got \(clearMsg.tag)")
        }
        guard clearMsg.attributes["unit"] == "unit-1" else {
          throw TestError(message: "setDestination clear unit mismatch")
        }
        guard clearMsg.attributes["destination"] == nil else {
          throw TestError(message: "setDestination clear should omit destination")
        }
      }
      while try await group.next() != nil {}
    }

    await server.stop()
  }

  await integrationTest("client sends assignTradeRoute message") {
    let server = MockServer()
    let port = server.port
    let client = NovaloriaClient(host: "127.0.0.1", port: port)

    let gameXML = """
      <game id="game-9b" turn="1">
        <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
        <map id="map-0" width="1" height="1">
          <tile id="tile-0" x="0" y="0" type="model.tile.plains"/>
        </map>
        <unit id="unit-1" unitType="model.unit.wagonTrain" owner="player-1" location="tile-0" movesLeft="3" state="ACTIVE"/>
      </game>
      """

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        try await client.connect()
        _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
        try await client.send(
          message: ParsedMessage(
            tag: "assignTradeRoute", attributes: ["unit": "unit-1", "tradeRoute": "route-1"],
            children: []))
        try await client.send(
          message: ParsedMessage(
            tag: "assignTradeRoute", attributes: ["unit": "unit-1"], children: []))
        await client.disconnect()
      }
      group.addTask {
        try await server.doHandshake(gameResponse: gameXML)

        let assignLine = try await server.nextLine()
        let clearLine = try await server.nextLine()

        let assignMsg = try XMLDecoder.decode(assignLine)
        let clearMsg = try XMLDecoder.decode(clearLine)

        guard assignMsg.tag == "assignTradeRoute" else {
          throw TestError(message: "expected assignTradeRoute, got \(assignMsg.tag)")
        }
        guard assignMsg.attributes["unit"] == "unit-1" else {
          throw TestError(message: "assignTradeRoute unit mismatch")
        }
        guard assignMsg.attributes["tradeRoute"] == "route-1" else {
          throw TestError(message: "assignTradeRoute tradeRoute mismatch")
        }

        guard clearMsg.tag == "assignTradeRoute" else {
          throw TestError(message: "expected assignTradeRoute clear, got \(clearMsg.tag)")
        }
        guard clearMsg.attributes["unit"] == "unit-1" else {
          throw TestError(message: "assignTradeRoute clear unit mismatch")
        }
        guard clearMsg.attributes["tradeRoute"] == nil else {
          throw TestError(message: "assignTradeRoute clear should omit tradeRoute")
        }
      }
      while try await group.next() != nil {}
    }

    await server.stop()
  }

  await integrationTest("client sends setCurrentStop message") {
    let server = MockServer()
    let port = server.port
    let client = NovaloriaClient(host: "127.0.0.1", port: port)

    let gameXML = """
      <game id="game-9c" turn="1">
        <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
        <map id="map-0" width="1" height="1">
          <tile id="tile-0" x="0" y="0" type="model.tile.plains"/>
        </map>
        <unit id="unit-1" unitType="model.unit.wagonTrain" owner="player-1" location="tile-0" movesLeft="3" state="ACTIVE" currentStop="0"/>
      </game>
      """

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        try await client.connect()
        _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
        try await client.send(
          message: ParsedMessage(
            tag: "setCurrentStop", attributes: ["unit": "unit-1", "index": "2"], children: []))
        await client.disconnect()
      }
      group.addTask {
        try await server.doHandshake(gameResponse: gameXML)

        let line = try await server.nextLine()
        let msg = try XMLDecoder.decode(line)

        guard msg.tag == "setCurrentStop" else {
          throw TestError(message: "expected setCurrentStop, got \(msg.tag)")
        }
        guard msg.attributes["unit"] == "unit-1" else {
          throw TestError(message: "setCurrentStop unit mismatch")
        }
        guard msg.attributes["index"] == "2" else {
          throw TestError(message: "setCurrentStop index mismatch")
        }
      }
      while try await group.next() != nil {}
    }

    await server.stop()
  }

  await integrationTest("client sends cashInTreasureTrain message") {
    let server = MockServer()
    let port = server.port
    let client = NovaloriaClient(host: "127.0.0.1", port: port)

    let gameXML = """
      <game id="game-9d" turn="1">
        <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
        <map id="map-0" width="1" height="1">
          <tile id="tile-0" x="0" y="0" type="model.tile.plains"/>
        </map>
        <unit id="unit-1" unitType="model.unit.treasureTrain" owner="player-1" location="tile-0" movesLeft="3" state="ACTIVE" treasureAmount="500"/>
      </game>
      """

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        try await client.connect()
        _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
        try await client.send(
          message: ParsedMessage(
            tag: "cashInTreasureTrain", attributes: ["unit": "unit-1"], children: []))
        await client.disconnect()
      }
      group.addTask {
        try await server.doHandshake(gameResponse: gameXML)

        let line = try await server.nextLine()
        let msg = try XMLDecoder.decode(line)

        guard msg.tag == "cashInTreasureTrain" else {
          throw TestError(message: "expected cashInTreasureTrain, got \(msg.tag)")
        }
        guard msg.attributes["unit"] == "unit-1" else {
          throw TestError(message: "cashInTreasureTrain unit mismatch")
        }
      }
      while try await group.next() != nil {}
    }

    await server.stop()
  }

  await integrationTest("client sends colony action messages") {
    let server = MockServer()
    let port = server.port
    let client = NovaloriaClient(host: "127.0.0.1", port: port)

    let gameXML = """
      <game id="game-10" turn="1">
        <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
        <map id="map-0" width="1" height="1">
          <tile id="tile-0" x="0" y="0" type="model.tile.plains"/>
        </map>
        <unit id="unit-1" unitType="model.unit.freeColonist" owner="player-1" location="colony-1" movesLeft="3" state="ACTIVE"/>
              <unit id="unit-2" unitType="model.unit.masterCarpenter" owner="player-1" location="colony-1" movesLeft="3" state="ACTIVE"/>
        <colony id="colony-1" name="Alpha" owner="player-1" tile="tile-0" settlementType="model.settlement.colony"/>
      </game>
      """

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        try await client.connect()
        _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
        try await client.send(
          message: ParsedMessage(
            tag: "changeWorkType", attributes: ["unit": "unit-1", "workType": "model.goods.grain"],
            children: []))
        try await client.send(
          message: ParsedMessage(
            tag: "clearSpeciality", attributes: ["unit": "unit-1"], children: []))
        try await client.send(
          message: ParsedMessage(
            tag: "assignTeacher", attributes: ["student": "unit-1", "teacher": "unit-2"],
            children: []))
        try await client.send(
          message: ParsedMessage(
            tag: "assignTeacher", attributes: ["student": "unit-1"], children: []))
        try await client.send(
          message: ParsedMessage(
            tag: "work", attributes: ["unit": "unit-1", "workLocation": "tile-0"], children: []))
        try await client.send(
          message: ParsedMessage(
            tag: "rename", attributes: ["name": "Beta", "nameable": "colony-1"], children: []))
        try await client.send(
          message: ParsedMessage(
            tag: "payForBuilding", attributes: ["colony": "colony-1"], children: []))
        try await client.send(
          message: ParsedMessage(
            tag: "setGoodsLevels", attributes: ["colony": "colony-1"],
            children: [
              ParsedMessage(
                tag: "exportData",
                attributes: [
                  "id": "model.goods.sugar", "exported": "true",
                  "highLevel": "90", "lowLevel": "10",
                  "importLevel": "-1", "exportLevel": "50",
                ], children: [])
            ]))
        try await client.send(
          message: ParsedMessage(
            tag: "rearrangeColony",
            attributes: [
              "colony": "colony-1", "xLength": "1",
              "x0unit": "unit-1", "x0loc": "tile-0",
              "x0role": "model.role.default", "x0count": "0",
            ], children: []))
        try await client.send(
          message: ParsedMessage(
            tag: "setBuildQueue",
            attributes: [
              "colony": "colony-1", "xLength": "2", "x0": "model.building.carpenterHouse",
              "x1": "model.unit.artillery",
            ], children: []))
        try await client.send(
          message: ParsedMessage(
            tag: "putOutsideColony", attributes: ["unit": "unit-1"], children: []))
        try await client.send(
          message: ParsedMessage(
            tag: "abandonColony", attributes: ["colony": "colony-1"], children: []))
        await client.disconnect()
      }
      group.addTask {
        try await server.doHandshake(gameResponse: gameXML)

        let workLine = try await server.nextLine()
        let clearSpecialityLine = try await server.nextLine()
        let assignTeacherLine = try await server.nextLine()
        let clearTeacherLine = try await server.nextLine()
        let workLocationLine = try await server.nextLine()
        let renameLine = try await server.nextLine()
        let payLine = try await server.nextLine()
        let goodsLevelsLine = try await server.nextLine()
        let rearrangeLine = try await server.nextLine()
        let queueLine = try await server.nextLine()
        let outsideLine = try await server.nextLine()
        let abandonLine = try await server.nextLine()

        let workMsg = try XMLDecoder.decode(workLine)
        let clearSpecialityMsg = try XMLDecoder.decode(clearSpecialityLine)
        let assignTeacherMsg = try XMLDecoder.decode(assignTeacherLine)
        let clearTeacherMsg = try XMLDecoder.decode(clearTeacherLine)
        let workLocationMsg = try XMLDecoder.decode(workLocationLine)
        let renameMsg = try XMLDecoder.decode(renameLine)
        let payMsg = try XMLDecoder.decode(payLine)
        let goodsLevelsMsg = try XMLDecoder.decode(goodsLevelsLine)
        let rearrangeMsg = try XMLDecoder.decode(rearrangeLine)
        let queueMsg = try XMLDecoder.decode(queueLine)
        let outsideMsg = try XMLDecoder.decode(outsideLine)
        let abandonMsg = try XMLDecoder.decode(abandonLine)

        guard workMsg.tag == "changeWorkType" else {
          throw TestError(message: "expected changeWorkType, got \(workMsg.tag)")
        }
        guard workMsg.attributes["unit"] == "unit-1" else {
          throw TestError(message: "changeWorkType unit mismatch")
        }
        guard workMsg.attributes["workType"] == "model.goods.grain" else {
          throw TestError(message: "changeWorkType workType mismatch")
        }

        guard clearSpecialityMsg.tag == "clearSpeciality" else {
          throw TestError(message: "expected clearSpeciality, got \(clearSpecialityMsg.tag)")
        }
        guard clearSpecialityMsg.attributes["unit"] == "unit-1" else {
          throw TestError(message: "clearSpeciality unit mismatch")
        }

        guard assignTeacherMsg.tag == "assignTeacher" else {
          throw TestError(message: "expected assignTeacher, got \(assignTeacherMsg.tag)")
        }
        guard assignTeacherMsg.attributes["student"] == "unit-1" else {
          throw TestError(message: "assignTeacher student mismatch")
        }
        guard assignTeacherMsg.attributes["teacher"] == "unit-2" else {
          throw TestError(message: "assignTeacher teacher mismatch")
        }

        guard clearTeacherMsg.tag == "assignTeacher" else {
          throw TestError(message: "expected assignTeacher clear, got \(clearTeacherMsg.tag)")
        }
        guard clearTeacherMsg.attributes["student"] == "unit-1" else {
          throw TestError(message: "assignTeacher clear student mismatch")
        }
        guard clearTeacherMsg.attributes["teacher"] == nil else {
          throw TestError(message: "assignTeacher clear should omit teacher")
        }

        guard workLocationMsg.tag == "work" else {
          throw TestError(message: "expected work, got \(workLocationMsg.tag)")
        }
        guard workLocationMsg.attributes["unit"] == "unit-1" else {
          throw TestError(message: "work unit mismatch")
        }
        guard workLocationMsg.attributes["workLocation"] == "tile-0" else {
          throw TestError(message: "work workLocation mismatch")
        }

        guard renameMsg.tag == "rename" else {
          throw TestError(message: "expected rename, got \(renameMsg.tag)")
        }
        guard renameMsg.attributes["name"] == "Beta" else {
          throw TestError(message: "rename name mismatch")
        }
        guard renameMsg.attributes["nameable"] == "colony-1" else {
          throw TestError(message: "rename nameable mismatch")
        }

        guard payMsg.tag == "payForBuilding" else {
          throw TestError(message: "expected payForBuilding, got \(payMsg.tag)")
        }
        guard payMsg.attributes["colony"] == "colony-1" else {
          throw TestError(message: "payForBuilding colony mismatch")
        }

        guard goodsLevelsMsg.tag == "setGoodsLevels" else {
          throw TestError(message: "expected setGoodsLevels, got \(goodsLevelsMsg.tag)")
        }
        guard goodsLevelsMsg.attributes["colony"] == "colony-1" else {
          throw TestError(message: "setGoodsLevels colony mismatch")
        }
        guard let exportChild = goodsLevelsMsg.children.first,
          exportChild.tag == "exportData"
        else {
          throw TestError(message: "setGoodsLevels missing exportData child")
        }
        guard exportChild.attributes["id"] == "model.goods.sugar",
          exportChild.attributes["exported"] == "true",
          exportChild.attributes["exportLevel"] == "50"
        else {
          throw TestError(message: "exportData payload mismatch")
        }

        guard rearrangeMsg.tag == "rearrangeColony" else {
          throw TestError(message: "expected rearrangeColony, got \(rearrangeMsg.tag)")
        }
        guard rearrangeMsg.attributes["colony"] == "colony-1" else {
          throw TestError(message: "rearrangeColony colony mismatch")
        }
        guard rearrangeMsg.attributes["xLength"] == "1" else {
          throw TestError(message: "rearrangeColony xLength mismatch")
        }
        guard rearrangeMsg.attributes["x0unit"] == "unit-1",
          rearrangeMsg.attributes["x0loc"] == "tile-0",
          rearrangeMsg.attributes["x0role"] == "model.role.default"
        else {
          throw TestError(message: "rearrangeColony arrangement mismatch")
        }

        guard queueMsg.tag == "setBuildQueue" else {
          throw TestError(message: "expected setBuildQueue, got \(queueMsg.tag)")
        }
        guard queueMsg.attributes["colony"] == "colony-1" else {
          throw TestError(message: "setBuildQueue colony mismatch")
        }
        guard queueMsg.attributes["xLength"] == "2" else {
          throw TestError(message: "setBuildQueue xLength mismatch")
        }
        guard queueMsg.attributes["x0"] == "model.building.carpenterHouse" else {
          throw TestError(message: "setBuildQueue x0 mismatch")
        }
        guard queueMsg.attributes["x1"] == "model.unit.artillery" else {
          throw TestError(message: "setBuildQueue x1 mismatch")
        }

        guard outsideMsg.tag == "putOutsideColony" else {
          throw TestError(message: "expected putOutsideColony, got \(outsideMsg.tag)")
        }
        guard outsideMsg.attributes["unit"] == "unit-1" else {
          throw TestError(message: "putOutsideColony unit mismatch")
        }

        guard abandonMsg.tag == "abandonColony" else {
          throw TestError(message: "expected abandonColony, got \(abandonMsg.tag)")
        }
        guard abandonMsg.attributes["colony"] == "colony-1" else {
          throw TestError(message: "abandonColony colony mismatch")
        }
      }
      while try await group.next() != nil {}
    }

    await server.stop()
  }

  await integrationTest("client sends goods load/unload messages") {
    let server = MockServer()
    let port = server.port
    let client = NovaloriaClient(host: "127.0.0.1", port: port)

    let gameXML = """
      <game id="game-11" turn="1">
        <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
        <map id="map-0" width="1" height="1">
          <tile id="tile-0" x="0" y="0" type="model.tile.plains"/>
        </map>
        <unit id="unit-ship" unitType="model.unit.caravel" owner="player-1" location="tile-0" movesLeft="6" state="ACTIVE"/>
        <colony id="colony-1" name="Alpha" owner="player-1" tile="tile-0" settlementType="model.settlement.colony"/>
      </game>
      """

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        try await client.connect()
        _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
        try await client.send(
          message: ParsedMessage(
            tag: "loadGoods",
            attributes: [
              "location": "colony-1", "type": "model.goods.grain", "amount": "20",
              "carrier": "unit-ship",
            ], children: []))
        try await client.send(
          message: ParsedMessage(
            tag: "unloadGoods",
            attributes: ["type": "model.goods.grain", "amount": "10", "carrier": "unit-ship"],
            children: []))
        await client.disconnect()
      }
      group.addTask {
        try await server.doHandshake(gameResponse: gameXML)

        let loadLine = try await server.nextLine()
        let unloadLine = try await server.nextLine()

        let loadMsg = try XMLDecoder.decode(loadLine)
        let unloadMsg = try XMLDecoder.decode(unloadLine)

        guard loadMsg.tag == "loadGoods" else {
          throw TestError(message: "expected loadGoods, got \(loadMsg.tag)")
        }
        guard loadMsg.attributes["location"] == "colony-1" else {
          throw TestError(message: "loadGoods location mismatch")
        }
        guard loadMsg.attributes["type"] == "model.goods.grain" else {
          throw TestError(message: "loadGoods type mismatch")
        }
        guard loadMsg.attributes["amount"] == "20" else {
          throw TestError(message: "loadGoods amount mismatch")
        }
        guard loadMsg.attributes["carrier"] == "unit-ship" else {
          throw TestError(message: "loadGoods carrier mismatch")
        }

        guard unloadMsg.tag == "unloadGoods" else {
          throw TestError(message: "expected unloadGoods, got \(unloadMsg.tag)")
        }
        guard unloadMsg.attributes["type"] == "model.goods.grain" else {
          throw TestError(message: "unloadGoods type mismatch")
        }
        guard unloadMsg.attributes["amount"] == "10" else {
          throw TestError(message: "unloadGoods amount mismatch")
        }
        guard unloadMsg.attributes["carrier"] == "unit-ship" else {
          throw TestError(message: "unloadGoods carrier mismatch")
        }
      }
      while try await group.next() != nil {}
    }

    await server.stop()
  }

  await integrationTest("client sends market buy/sell messages against Europe location") {
    let server = MockServer()
    let port = server.port
    let client = NovaloriaClient(host: "127.0.0.1", port: port)

    let gameXML = """
      <game id="game-42" turn="1" currentPlayer="player-1" clientUserName="Alice">
        <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500" tax="10">
          <europe id="europe:0" owner="player-1" recruitPrice="800"/>
          <market owner="player-1">
            <marketData goods-type="model.goods.food" amount="200" initialPrice="12"/>
            <marketData goods-type="model.goods.tools" amount="80" initialPrice="16"/>
          </market>
        </player>
        <map id="map-0" width="1" height="1">
          <tile id="tile-0" x="0" y="0" type="model.tile.ocean" highSeas="true" moveToEurope="true"/>
        </map>
        <unit id="unit-caravel" unitType="model.unit.caravel" owner="player-1" location="europe:0" movesLeft="6" state="ACTIVE"/>
      </game>
      """

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        try await client.connect()
        _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
        try await client.send(
          message: ParsedMessage(
            tag: "loadGoods",
            attributes: [
              "location": "europe:0", "type": "model.goods.food", "amount": "15",
              "carrier": "unit-caravel",
            ], children: []))
        try await client.send(
          message: ParsedMessage(
            tag: "unloadGoods",
            attributes: ["type": "model.goods.tools", "amount": "5", "carrier": "unit-caravel"],
            children: []))
        await client.disconnect()
      }
      group.addTask {
        try await server.doHandshake(gameResponse: gameXML)

        let buyLine = try await server.nextLine()
        let sellLine = try await server.nextLine()

        let buyMsg = try XMLDecoder.decode(buyLine)
        let sellMsg = try XMLDecoder.decode(sellLine)

        guard buyMsg.tag == "loadGoods" else {
          throw TestError(message: "expected loadGoods, got \(buyMsg.tag)")
        }
        guard buyMsg.attributes["location"] == "europe:0" else {
          throw TestError(message: "buy goods location mismatch")
        }
        guard buyMsg.attributes["type"] == "model.goods.food" else {
          throw TestError(message: "buy goods type mismatch")
        }
        guard buyMsg.attributes["amount"] == "15" else {
          throw TestError(message: "buy goods amount mismatch")
        }
        guard buyMsg.attributes["carrier"] == "unit-caravel" else {
          throw TestError(message: "buy goods carrier mismatch")
        }

        guard sellMsg.tag == "unloadGoods" else {
          throw TestError(message: "expected unloadGoods, got \(sellMsg.tag)")
        }
        guard sellMsg.attributes["type"] == "model.goods.tools" else {
          throw TestError(message: "sell goods type mismatch")
        }
        guard sellMsg.attributes["amount"] == "5" else {
          throw TestError(message: "sell goods amount mismatch")
        }
        guard sellMsg.attributes["carrier"] == "unit-caravel" else {
          throw TestError(message: "sell goods carrier mismatch")
        }
      }
      while try await group.next() != nil {}
    }

    await server.stop()
  }
}

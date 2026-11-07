import Foundation
import NovaloriaClient
import FreeColGame
import FreeColProtocol

func runMessageLoopIntegrationTests() async {
  await integrationTest("message loop forwards animate events") {
    let server = MockServer()
    let port = server.port
    let client = NovaloriaClient(host: "127.0.0.1", port: port)
    let delegate = TestDelegate()
    await client.setDelegate(delegate)

    let gameXML = """
      <game id="game-13" turn="1">
        <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
        <player id="player-2" username="Bob" nationId="model.nation.french" gold="500"/>
        <map id="map-0" width="2" height="1">
          <tile id="tile-0" x="0" y="0" type="model.tile.plains"/>
          <tile id="tile-1" x="1" y="0" type="model.tile.plains"/>
        </map>
        <unit id="unit-1" unitType="model.unit.freeColonist" owner="player-1" location="tile-0" movesLeft="3" state="ACTIVE"/>
        <unit id="unit-2" unitType="model.unit.freeColonist" owner="player-2" location="tile-1" movesLeft="3" state="ACTIVE"/>
      </game>
      """

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        try await client.connect()
        _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
        await client.startMessageLoop()
      }
      group.addTask {
        try await server.doHandshake(gameResponse: gameXML)
        try await Task.sleep(nanoseconds: 250_000_000)
        await server.send("<animateMove oldTile=\"tile-0\" unit=\"unit-1\" newTile=\"tile-1\"/>")
        await server.send(
          "<animateAttack attackerTile=\"tile-0\" defenderTile=\"tile-1\" attacker=\"unit-1\" defender=\"unit-2\" success=\"true\"/>"
        )
        await server.flush()
        try await Task.sleep(nanoseconds: 300_000_000)
        await server.stop()
      }
      try await Task.sleep(nanoseconds: 5_000_000_000)
      group.cancelAll()
    }

    guard delegate.receivedMessages.contains("animateMove") else {
      throw TestError(message: "animateMove not forwarded to delegate")
    }
    guard delegate.receivedMessages.contains("animateAttack") else {
      throw TestError(message: "animateAttack not forwarded to delegate")
    }
  }

  await integrationTest("message loop processes question payload and replies") {
    let server = MockServer()
    let port = server.port
    let client = NovaloriaClient(host: "127.0.0.1", port: port)

    let gameXML = """
      <game id="game-4" turn="1">
        <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
        <player id="player-2" username="Bob" nationId="model.nation.french" gold="400"/>
      </game>
      """

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        try await client.connect()
        _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
        await client.startMessageLoop()
      }
      group.addTask {
        try await server.doHandshake(gameResponse: gameXML)
        try await Task.sleep(nanoseconds: 200_000_000)
        await server.send(
          "<question networkReplyId=\"9\"><setCurrentPlayer player=\"player-2\"/></question>")
        await server.flush()

        let replyLine = try await server.nextLine()
        let reply = try XMLDecoder.decode(replyLine)
        guard reply.tag == "reply" else {
          throw TestError(message: "expected reply, got \(reply.tag)")
        }
        guard reply.attributes["networkReplyId"] == "9" else {
          throw TestError(message: "unexpected reply id")
        }

        try await Task.sleep(nanoseconds: 200_000_000)
        await server.stop()
      }
      try await Task.sleep(nanoseconds: 5_000_000_000)
      group.cancelAll()
    }

    let current = await client.game.currentPlayerId
    guard current == "player-2" else {
      throw TestError(message: "question payload was not applied")
    }
  }

  await integrationTest("decision-action asks use emigrateUnit and lootCargo contract") {
    let server = MockServer()
    let port = server.port
    let client = NovaloriaClient(host: "127.0.0.1", port: port)

    let gameXML = """
      <game id="game-5" turn="1">
        <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
        <player id="player-2" username="Bob" nationId="model.nation.french" gold="400"/>
      </game>
      """

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        try await server.doHandshake(gameResponse: gameXML)
        try await Task.sleep(nanoseconds: 200_000_000)

        // 1. Fountain of youth is answered with a specific emigrateUnit slot.
        let rawEmigrate = try await server.nextLine()
        let emigrateQuestion = try XMLDecoder.decode(rawEmigrate)
        guard emigrateQuestion.tag == "question",
          let emigrateReplyId = emigrateQuestion.attributes["networkReplyId"],
          let emigrate = emigrateQuestion.children.first,
          emigrate.tag == "emigrateUnit"
        else {
          throw TestError(message: "expected emigrateUnit question")
        }
        guard emigrate.attributes["slot"] == "1" else {
          throw TestError(message: "expected specific emigrate slot")
        }
        await server.send("<reply networkReplyId=\"\(emigrateReplyId)\"><emigrateUnit/></reply>")
        await server.flush()
        try await Task.sleep(nanoseconds: 150_000_000)

        // 2. Loot cargo reply must preserve winner/loser plus <goods> children.
        let rawLoot = try await server.nextLine()
        let lootQuestion = try XMLDecoder.decode(rawLoot)
        guard lootQuestion.tag == "question",
          let lootReplyId = lootQuestion.attributes["networkReplyId"],
          let loot = lootQuestion.children.first,
          loot.tag == "lootCargo"
        else {
          throw TestError(message: "expected lootCargo question")
        }
        guard loot.attributes["winner"] == "unit-9",
          loot.attributes["loser"] == "unit-2"
        else {
          throw TestError(message: "expected winner/loser in lootCargo payload")
        }
        guard let goods = loot.children.first,
          goods.tag == "goods",
          goods.attributes["type"] == "model.goods.sugar",
          goods.attributes["amount"] == "20"
        else {
          throw TestError(message: "expected goods child in lootCargo payload")
        }
        await server.send("<reply networkReplyId=\"\(lootReplyId)\"><lootCargo/></reply>")
        await server.flush()
        try await Task.sleep(nanoseconds: 150_000_000)
        await server.stop()
      }

      // No message loop here: the ask/reply pairs must be the only consumers of
      // incoming lines to stay deterministic.
      try await client.connect()
      _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")

      let emigrateReply = try await client.ask(
        message: ParsedMessage(
          tag: "emigrateUnit",
          attributes: ["slot": "1"],
          children: []
        ))
      guard emigrateReply.tag == "reply" else {
        throw TestError(message: "expected emigrateUnit reply")
      }

      let lootReply = try await client.ask(
        message: ParsedMessage(
          tag: "lootCargo",
          attributes: ["winner": "unit-9", "loser": "unit-2"],
          children: [
            ParsedMessage(
              tag: "goods",
              attributes: ["type": "model.goods.sugar", "amount": "20"],
              children: []
            )
          ]
        ))
      guard lootReply.tag == "reply" else {
        throw TestError(message: "expected lootCargo reply")
      }

      group.cancelAll()
    }
  }

  await integrationTest("message loop routes ask replies while running") {
    let server = MockServer()
    let port = server.port
    let client = NovaloriaClient(host: "127.0.0.1", port: port)

    let gameXML = """
      <game id="game-8" turn="1">
        <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
      </game>
      """

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        try await server.doHandshake(gameResponse: gameXML)
        try await Task.sleep(nanoseconds: 150_000_000)
        let raw = try await server.nextLine()
        let question = try XMLDecoder.decode(raw)
        guard question.tag == "question",
          let replyId = question.attributes["networkReplyId"],
          question.children.first?.tag == "emigrateUnit"
        else {
          throw TestError(message: "expected emigrateUnit question")
        }
        await server.send("<reply networkReplyId=\"\(replyId)\"><emigrateUnit/></reply>")
        await server.flush()
        try await Task.sleep(nanoseconds: 150_000_000)
        await server.stop()
      }
      group.addTask {
        try await client.connect()
        _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
        Task { await client.startMessageLoop() }
        try await Task.sleep(nanoseconds: 150_000_000)
        // The message loop owns the receive stream; the ask must be routed
        // through it instead of racing on nextLine().
        let reply = try await client.ask(
          message: ParsedMessage(
            tag: "emigrateUnit",
            attributes: ["slot": "1"],
            children: []
          ))
        guard reply.tag == "reply" else {
          throw TestError(message: "expected routed reply")
        }
      }
      try await Task.sleep(nanoseconds: 3_000_000_000)
      group.cancelAll()
    }
  }

  await integrationTest("prompt replies use firstContact/monarchAction/newLandName contract") {
    let server = MockServer()
    let port = server.port
    let client = NovaloriaClient(host: "127.0.0.1", port: port)

    let gameXML = """
      <game id="game-6" turn="1">
        <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
        <player id="player-2" username="Bob" nationId="model.nation.french" gold="400"/>
      </game>
      """

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        try await server.doHandshake(gameResponse: gameXML)
        try await Task.sleep(nanoseconds: 200_000_000)

        // 1. firstContact reply carries player/other/tile + boolean result.
        let rawContact = try await server.nextLine()
        let contactQuestion = try XMLDecoder.decode(rawContact)
        guard contactQuestion.tag == "question",
          let contactReplyId = contactQuestion.attributes["networkReplyId"],
          let contact = contactQuestion.children.first,
          contact.tag == "firstContact"
        else {
          throw TestError(message: "expected firstContact question")
        }
        guard contact.attributes["player"] == "player-1",
          contact.attributes["other"] == "player-4",
          contact.attributes["tile"] == "tile-2-3",
          contact.attributes["result"] == "true"
        else {
          throw TestError(message: "bad firstContact payload: \(contact.attributes)")
        }
        await server.send("<reply networkReplyId=\"\(contactReplyId)\"><firstContact/></reply>")
        await server.flush()
        try await Task.sleep(nanoseconds: 120_000_000)

        // 2. monarchAction reply carries action + boolean result.
        let rawMonarch = try await server.nextLine()
        let monarchQuestion = try XMLDecoder.decode(rawMonarch)
        guard monarchQuestion.tag == "question",
          let monarchReplyId = monarchQuestion.attributes["networkReplyId"],
          let monarch = monarchQuestion.children.first,
          monarch.tag == "monarchAction"
        else {
          throw TestError(message: "expected monarchAction question")
        }
        guard monarch.attributes["action"] == "raise_tax_act",
          monarch.attributes["result"] == "true"
        else {
          throw TestError(message: "bad monarchAction payload: \(monarch.attributes)")
        }
        await server.send("<reply networkReplyId=\"\(monarchReplyId)\"><monarchAction/></reply>")
        await server.flush()
        try await Task.sleep(nanoseconds: 120_000_000)

        // 3. newLandName reply carries unit + newLandName.
        let rawLand = try await server.nextLine()
        let landQuestion = try XMLDecoder.decode(rawLand)
        guard landQuestion.tag == "question",
          let landReplyId = landQuestion.attributes["networkReplyId"],
          let land = landQuestion.children.first,
          land.tag == "newLandName"
        else {
          throw TestError(message: "expected newLandName question")
        }
        guard land.attributes["unit"] == "unit-5",
          land.attributes["newLandName"] == "Nieuw Zeeland"
        else {
          throw TestError(message: "bad newLandName payload: \(land.attributes)")
        }
        await server.send("<reply networkReplyId=\"\(landReplyId)\"><newLandName/></reply>")
        await server.flush()
        try await Task.sleep(nanoseconds: 120_000_000)
        await server.stop()
      }

      try await client.connect()
      _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")

      let contactReply = try await client.ask(
        message: ParsedMessage(
          tag: "firstContact",
          attributes: [
            "player": "player-1", "other": "player-4", "tile": "tile-2-3", "camps": "2",
            "result": "true",
          ],
          children: []
        ))
      guard contactReply.tag == "reply" else {
        throw TestError(message: "expected firstContact reply")
      }

      let monarchReply = try await client.ask(
        message: ParsedMessage(
          tag: "monarchAction",
          attributes: [
            "action": "raise_tax_act", "monarch": "model.nation.dutch", "result": "true",
          ],
          children: []
        ))
      guard monarchReply.tag == "reply" else {
        throw TestError(message: "expected monarchAction reply")
      }

      let landReply = try await client.ask(
        message: ParsedMessage(
          tag: "newLandName",
          attributes: ["unit": "unit-5", "newLandName": "Nieuw Zeeland"],
          children: []
        ))
      guard landReply.tag == "reply" else {
        throw TestError(message: "expected newLandName reply")
      }

      group.cancelAll()
    }
  }

  await integrationTest("client sends nativeTrade and diplomacy sessions") {
    let server = MockServer()
    let port = server.port
    let client = NovaloriaClient(host: "127.0.0.1", port: port)

    let gameXML = """
      <game id="game-7" turn="1">
        <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
        <player id="player-2" username="Bob" nationId="model.nation.french" gold="400"/>
      </game>
      """

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        try await server.doHandshake(gameResponse: gameXML)
        try await Task.sleep(nanoseconds: 200_000_000)

        // 1. OPEN carries the unit/settlement in a nested <nativeTrade>.
        let rawOpen = try await server.nextLine()
        let open = try XMLDecoder.decode(rawOpen)
        guard open.tag == "nativeTrade", open.attributes["action"] == "OPEN",
          let openInner = open.children.first,
          openInner.tag == "nativeTrade",
          openInner.attributes["unit"] == "unit-1",
          openInner.attributes["settlement"] == "is-1"
        else {
          throw TestError(message: "bad nativeTrade OPEN payload: \(rawOpen)")
        }

        // 2. BUY carries the focused <nativeTradeItem> with goods.
        let rawBuy = try await server.nextLine()
        let buy = try XMLDecoder.decode(rawBuy)
        guard buy.tag == "nativeTrade", buy.attributes["action"] == "BUY",
          let buyInner = buy.children.first(where: { $0.tag == "nativeTrade" }),
          let item = buyInner.children.first(where: { $0.tag == "nativeTradeItem" }),
          item.attributes["price"] == "42",
          item.children.first?.attributes["type"] == "model.goods.sugar"
        else {
          throw TestError(message: "bad nativeTrade BUY payload: \(rawBuy)")
        }

        // 3. CLOSE.
        let rawClose = try await server.nextLine()
        let close = try XMLDecoder.decode(rawClose)
        guard close.tag == "nativeTrade", close.attributes["action"] == "CLOSE" else {
          throw TestError(message: "bad nativeTrade CLOSE payload: \(rawClose)")
        }

        // 4. Diplomacy proposal answer with status + clause.
        let rawDiplomacy = try await server.nextLine()
        let diplomacy = try XMLDecoder.decode(rawDiplomacy)
        guard diplomacy.tag == "diplomacy",
          diplomacy.attributes["ourId"] == "unit-1",
          diplomacy.attributes["otherId"] == "unit-2",
          let trade = diplomacy.children.first(where: { $0.tag == "diplomaticTrade" }),
          trade.attributes["status"] == "ACCEPT_TRADE",
          trade.attributes["context"] == "DIPLOMATIC",
          trade.children.contains(where: {
            $0.tag == "goldTradeItem" && $0.attributes["gold"] == "100"
          })
        else {
          throw TestError(message: "bad diplomacy payload: \(rawDiplomacy)")
        }

        try await Task.sleep(nanoseconds: 150_000_000)
        await server.stop()
      }

      try await client.connect()
      _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")

      var session = NativeTradeSession(unitId: "unit-1", settlementId: "is-1")
      try await client.send(message: session.toMessage(action: "OPEN", item: nil))

      let item = NativeTradeItem(
        goodsType: "model.goods.sugar",
        amount: 20,
        price: 42,
        haggleCount: 0,
        source: "is-1",
        destination: "unit-1"
      )
      try await client.send(message: session.toMessage(action: "BUY", item: item))

      session.item = item
      try await client.send(message: session.toMessage(action: "CLOSE", item: nil))

      let goldClause = ParsedMessage(
        tag: "goldTradeItem",
        attributes: ["gold": "100", "source": "player-2", "destination": "player-1"],
        children: []
      )
      let agreement = ParsedMessage(
        tag: "diplomaticTrade",
        attributes: [
          "context": "DIPLOMATIC", "sender": "player-2", "recipient": "player-1",
          "status": "ACCEPT_TRADE", "version": "1",
        ],
        children: [goldClause]
      )
      try await client.send(
        message: ParsedMessage(
          tag: "diplomacy",
          attributes: ["ourId": "unit-1", "otherId": "unit-2"],
          children: [agreement]
        ))

      group.cancelAll()
    }
  }

  await integrationTest("message loop applies inbound stance/ai/chat/logout") {
    let server = MockServer()
    let port = server.port
    let client = NovaloriaClient(host: "127.0.0.1", port: port)

    let gameXML = """
      <game id="game-43" turn="1">
        <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
        <player id="player-2" username="Bob" nationId="model.nation.french" gold="400"/>
      </game>
      """

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        try await client.connect()
        _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
        await client.startMessageLoop()
      }
      group.addTask {
        try await server.doHandshake(gameResponse: gameXML)
        try await Task.sleep(nanoseconds: 200_000_000)
        await server.send("<setStance first=\"player-1\" second=\"player-2\" stance=\"WAR\"/>")
        await server.send("<setAI player=\"player-1\" ai=\"true\"/>")
        await server.send("<chat sender=\"player-2\" message=\"Hello there\"/>")
        await server.send("<logout player=\"player-2\" reason=\"done\"/>")
        await server.flush()

        try await Task.sleep(nanoseconds: 300_000_000)
        await server.stop()
      }
      try await Task.sleep(nanoseconds: 5_000_000_000)
      group.cancelAll()
    }

    let game = await client.game
    let stance = game.players["player-1"]?.stances["player-2"]
    guard stance == .war else {
      throw TestError(message: "inbound setStance was not applied")
    }
    guard game.players["player-1"]?.ai == true else {
      throw TestError(message: "inbound setAI was not applied")
    }
    guard !game.players.keys.contains("player-2") else {
      throw TestError(message: "inbound logout did not remove the player")
    }
  }

  await integrationTest("message loop forwards founding-father and death prompts") {
    let server = MockServer()
    let port = server.port
    let client = NovaloriaClient(host: "127.0.0.1", port: port)
    let delegate = TestDelegate()
    await client.setDelegate(delegate)

    let gameXML = """
      <game id="game-54" turn="1">
        <player id="player-1" username="Alice" nationId="model.nation.dutch" gold="500"/>
        <player id="player-2" username="Bob" nationId="model.nation.french" gold="400"/>
      </game>
      """

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        try await client.connect()
        _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
        await client.startMessageLoop()
      }
      group.addTask {
        try await server.doHandshake(gameResponse: gameXML)
        try await Task.sleep(nanoseconds: 200_000_000)
        await server.send(
          "<question networkReplyId=\"21\"><chooseFoundingFather trade=\"model.foundingFather.adamSmith\"/></question>"
        )
        await server.flush()
        _ = try await server.nextLine()
        await server.send("<update><setDead player=\"player-2\"/></update>")
        await server.flush()

        try await Task.sleep(nanoseconds: 300_000_000)
        await server.stop()
      }
      try await Task.sleep(nanoseconds: 5_000_000_000)
      group.cancelAll()
    }

    let flags = delegate.receivedMessages
    guard flags.contains("chooseFoundingFather") else {
      throw TestError(message: "chooseFoundingFather prompt was not forwarded")
    }
    // The death arrives inside an update; the whole envelope must be forwarded.
    guard flags.contains("update") else {
      throw TestError(message: "setDead update was not forwarded")
    }

    let game = await client.game
    guard !game.players.keys.contains("player-2") else {
      throw TestError(message: "inbound setDead did not remove the player")
    }
  }
}

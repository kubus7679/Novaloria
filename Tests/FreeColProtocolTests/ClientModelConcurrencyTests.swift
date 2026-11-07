import XCTest
import NovaloriaClient
import FreeColGame
import FreeColProtocol
@testable import Novaloria

final class ClientModelConcurrencyTests: XCTestCase {
    @MainActor
    func testIncomingModelChangesAreSerializedWithUIReads() async throws {
        let server = MockServer()
        let client = NovaloriaClient(host: "127.0.0.1", port: server.port)
        let state = GameState()
        var events: [String] = []
        var europeOrderAvailability: [Bool] = []
        let updates = expectation(description: "All model changes reached the UI")
        updates.expectedFulfillmentCount = 103
        let delegate = MainActorClientDelegate { event in
            events.append(event)
            if event == "update" {
                XCTAssertEqual(state.selectedUnitTileId, "tile-0")
                europeOrderAvailability.append(state.canSendSelectedUnitToEurope)
                updates.fulfill()
            }
        }
        await client.setDelegate(delegate)

        let handshake = Task {
            try await server.doHandshake(gameResponse: """
            <game id="game-1" currentPlayer="player-1" clientUserName="Alice">
              <player id="player-1" username="Alice">
                <europe id="europe-1" owner="player-1"/>
              </player>
              <map id="map-1" width="1" height="1">
                <tile id="tile-0" x="0" y="0" type="model.tile.ocean"/>
              </map>
              <unit id="ship-1" owner="player-1" unitType="model.unit.caravel" location="tile-0" movesLeft="3" state="ACTIVE"/>
            </game>
            """)
        }
        do {
            try await client.connect()
            _ = try await client.login(userName: "Alice", nationId: "model.nation.dutch")
            try await handshake.value
        } catch {
            await client.disconnect()
            await server.stop()
            _ = await handshake.result
            throw error
        }

        let game = await client.game
        state.installGame(game)
        state.phase = .inGame
        state.localPlayerName = "Alice"
        state.selectedUnitId = "ship-1"
        XCTAssertFalse(state.canSendSelectedUnitToEurope)

        let loop = Task { await client.startMessageLoop() }
        do {
            await server.send(tileUpdate(canMoveToEurope: true))
            await server.send("""
            <question networkReplyId="server-question">
              \(tileUpdate(canMoveToEurope: false))
            </question>
            """.replacingOccurrences(of: "\n", with: ""))
            await server.flush()
            let questionReply = try XMLDecoder.decode(await server.nextLine())
            XCTAssertEqual(questionReply.tag, "reply")
            XCTAssertEqual(questionReply.attributes["networkReplyId"], "server-question")
            XCTAssertFalse(state.canSendSelectedUnitToEurope)

            let replyTask = Task {
                let question = try XMLDecoder.decode(await server.nextLine())
                XCTAssertEqual(question.tag, "question")
                let replyID = try XCTUnwrap(question.attributes["networkReplyId"])
                await server.send("""
                <reply networkReplyId="\(replyID)">\(tileUpdate(canMoveToEurope: true))</reply>
                """)
                await server.flush()
            }
            _ = try await client.ask(
                message: ParsedMessage(tag: "endTurn", attributes: [:], children: []),
                timeout: 3
            )
            try await replyTask.value
            XCTAssertTrue(state.canSendSelectedUnitToEurope,
                          "The reply must update the live model before ask() resumes")

            // Stay below the bounded transport queue and acknowledge each batch.
            for start in stride(from: 0, to: 100, by: 4) {
                for index in start..<(start + 4) {
                    await server.send(tileUpdate(canMoveToEurope: index.isMultiple(of: 2)))
                }
                await server.send("""
                <question networkReplyId="batch-\(start)"><chat message="barrier"/></question>
                """)
                await server.flush()
                for _ in 0..<20 {
                    XCTAssertEqual(game.resolvedTileId(for: try XCTUnwrap(state.selectedUnit)), "tile-0")
                    _ = state.canSendSelectedUnitToEurope
                    _ = state.unitsAwaitingOrders
                    await Task.yield()
                }
                let reply = try XMLDecoder.decode(await server.nextLine())
                XCTAssertEqual(reply.tag, "reply")
                XCTAssertEqual(reply.attributes["networkReplyId"], "batch-\(start)")
            }
            await fulfillment(of: [updates], timeout: 5)
        } catch {
            await client.disconnect()
            await server.stop()
            await loop.value
            throw error
        }
        await client.disconnect()
        await server.stop()
        await loop.value

        XCTAssertEqual(Array(events.prefix(2)), ["connect", "login"])
        XCTAssertEqual(events.last, "disconnect")
        XCTAssertEqual(events.filter { $0 == "chat" }.count, 25)
        XCTAssertEqual(europeOrderAvailability, [true, false, true] + (0..<100).map {
            $0.isMultiple(of: 2)
        })
        let currentGame = await client.game
        XCTAssertTrue(currentGame === game, "Model updates must preserve live model identity")
    }

    private func tileUpdate(canMoveToEurope: Bool) -> String {
        """
        <update><tile id="tile-0" x="0" y="0" type="model.tile.ocean" moveToEurope="\(canMoveToEurope)"/></update>
        """
    }
}

private final class MainActorClientDelegate: ClientDelegate {
    private let onEvent: @MainActor (String) -> Void

    init(onEvent: @escaping @MainActor (String) -> Void) {
        self.onEvent = onEvent
    }

    func clientDidConnect() { record("connect") }
    func clientDidLogin(_ result: LoginResult) { record("login") }
    func clientDidReceiveGameState(_ parsed: ParsedMessage) { record(parsed.tag) }
    func clientDidDisconnect(error: Error?) { record("disconnect") }
    func clientDidUpdate() { record("update") }

    private func record(_ event: String) {
        XCTAssertTrue(Thread.isMainThread, "Client callback '\(event)' must run on the main actor")
        guard Thread.isMainThread else { return }
        MainActor.assumeIsolated {
            onEvent(event)
        }
    }
}

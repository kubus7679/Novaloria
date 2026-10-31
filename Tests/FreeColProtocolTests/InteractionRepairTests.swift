import XCTest
import FreeColClient
import FreeColGame
import FreeColProtocol
@testable import FreeColApp

final class InteractionRepairTests: XCTestCase {
    @MainActor
    func testNestedColonyWorkersAndSelectionSurviveUpdates() throws {
        let state = try makeState()
        XCTAssertNotNil(state.game?.units["field-worker"])
        XCTAssertNotNil(state.game?.units["building-worker"])
        state.selectUnit("field-worker", onTile: "tile-2-2")
        state.syncAfterModelUpdate()
        XCTAssertEqual(state.selectedColonyWorkerUnitId, "field-worker")
        XCTAssertEqual(state.selectedTileId, "tile-2-2")
        XCTAssertEqual(state.game?.resolvedTileId(for: try XCTUnwrap(state.selectedUnit)), "tile-2-2")
        XCTAssertEqual(state.colonyPopulation(try XCTUnwrap(state.selectedColony)), 2)
        XCTAssertEqual(state.selectedColonyWorkTypeCandidates.map(\.id), ["model.goods.grain"])
        state.selectUnit("building-worker", onTile: "tile-2-2")
        XCTAssertEqual(state.selectedColonyWorkTypeCandidates.map(\.id), ["model.goods.hammers"])
        try state.game?.applyUpdate(XMLDecoder.decode("""
        <update><tile id="tile-2-2" x="2" y="2" type="model.tile.plains">
          <colony id="colony-1" name="Neuer Name" owner="player-1">
            <building id="building-1" buildingType="model.building.carpenterHouse">
              <unit id="building-worker" unitType="model.unit.freeColonist" owner="player-1"
                    location="building-1" movesLeft="0"/>
            </building>
            <colonyTile id="field-east" workTile="tile-3-2"/>
          </colony>
        </tile></update>
        """))
        state.gameUpdateID += 1
        state.syncAfterModelUpdate()
        XCTAssertEqual(state.selectedColony?.name, "Neuer Name")
        XCTAssertEqual(state.selectedColony?.tileId, "tile-2-2")
        XCTAssertEqual(state.selectedColony?.workTiles.first?.id, "field-east")
        XCTAssertEqual(state.selectedUnitId, "building-worker")
        XCTAssertEqual(state.selectedTileId, "tile-2-2")
        for _ in 0..<5 {
            state.selectMapTile("tile-2-2")
            XCTAssertTrue(["outside-worker", "ship", "wagon"].contains(state.selectedUnitId ?? ""))
        }
    }

    @MainActor
    func testColonyTerrainUsesRealWorkLocationsAndGuardsAssignments() throws {
        let state = try makeState()
        state.selectUnit("field-worker", onTile: "tile-2-2")
        XCTAssertEqual(state.selectedColonyTerrain.count, 9)
        let east = try XCTUnwrap(state.selectedColonyTerrain.first { $0.id == "tile-3-2" })
        XCTAssertEqual(east.workLocationId, "field-east")
        XCTAssertEqual(east.workers.map(\.id), ["field-worker"])
        XCTAssertNil(east.unavailableReason)
        XCTAssertEqual(east.offset.x, 1)
        XCTAssertEqual(east.offset.y, 0)
        XCTAssertNotNil(state.selectedColonyTerrain.first { $0.id == "tile-2-2" }?.unavailableReason)
        XCTAssertNotNil(state.colonyWorkLocationUnavailableReason("field-water"))
        state.assignSelectedColonyWorker(to: "field-center")
        XCTAssertNotNil(state.errorMessage)
        state.assignSelectedColonyWorker(to: "foreign-work-location")
        XCTAssertNotNil(state.errorMessage)
        state.selectUnit("ship", onTile: "tile-2-2")
        XCTAssertNotEqual(state.selectedColonyWorkerUnitId, "ship")
        state.selectUnit("wagon", onTile: "tile-2-2")
        XCTAssertFalse(state.canUnitWorkInColony(try XCTUnwrap(state.selectedUnit)))
    }

    @MainActor
    func testMissionaryEquipmentRequiresPersonAndSuitableLocation() throws {
        let state = try makeState()
        state.selectUnit("ship", onTile: "tile-2-2")
        XCTAssertFalse(state.canEquipSelectedUnitForRole)
        state.equipSelectedUnitForRole("model.role.missionary", count: 1)
        XCTAssertNotNil(state.errorMessage)
        state.selectUnit("wagon", onTile: "tile-2-2")
        XCTAssertFalse(state.canEquipSelectedUnitForRole)
        state.selectUnit("outside-worker", onTile: "tile-2-2")
        XCTAssertFalse(state.canEquipSelectedUnitForRole, "A colony without a church cannot equip missionaries")
        state.selectUnit("europe-worker", onTile: nil)
        XCTAssertTrue(state.canEquipSelectedUnitForRole)
        try state.game?.applyUpdate(XMLDecoder.decode("""
        <update><unit id="europe-worker" owner="player-1" unitType="model.unit.freeColonist"
                      role="model.role.missionary" location="europe-1"/></update>
        """))
        state.gameUpdateID += 1
        XCTAssertFalse(state.canEquipSelectedUnitForRole)
    }

    @MainActor
    func testImprovementsRequireAnOutdoorEquippedWorker() throws {
        let state = try makeState()
        for id in ["ship", "wagon", "field-worker", "building-worker", "outside-worker"] {
            state.selectUnit(id, onTile: "tile-2-2")
            XCTAssertTrue(state.selectedUnitImprovementCandidates.isEmpty)
            XCTAssertFalse(state.canChangeSelectedUnitWorkImprovement)
        }
        try state.game?.applyPartial(XMLDecoder.decode("""
        <partial id="outside-worker" role="model.role.pioneer" roleCount="1"/>
        """))
        state.gameUpdateID += 1
        XCTAssertEqual(state.selectedUnitImprovementCandidates.map(\.id), ["model.improvement.road"])
        XCTAssertTrue(state.canChangeSelectedUnitWorkImprovement)
        state.changeSelectedUnitWorkImprovement("model.improvement.unknown")
        XCTAssertNotNil(state.errorMessage)
    }

    @MainActor
    func testRemoteColonyActionsUseQuestionsApplyRepliesAndSurfaceErrors() async throws {
        let server = MockServer()
        let state = GameState()
        let serverTask = Task {
            try await server.doHandshake(gameResponse: Self.gameXML.replacingOccurrences(of: "\n", with: " "))
            let responses = [
                #"<partial id="colony-1" name="Neu-Boston"/>"#,
                #"<update><unit id="field-worker" owner="player-1" unitType="model.unit.freeColonist" location="field-west" workType="model.goods.grain" movesLeft="0"/></update>"#,
                #"<update><unit id="field-worker" owner="player-1" unitType="model.unit.freeColonist" location="building-1" movesLeft="0"/><unit id="building-worker" owner="player-1" unitType="model.unit.freeColonist" location="field-west" movesLeft="0"/></update>"#,
                #"<error message="Test: Umbenennen abgelehnt"/>"#,
            ]
            var requests: [ParsedMessage] = []
            for response in responses {
                let request = try XMLDecoder.decode(await server.nextLine())
                XCTAssertEqual(request.tag, "question", "Java actions must await a ChangeSet reply")
                let replyId = try XCTUnwrap(request.attributes["networkReplyId"])
                requests.append(try XCTUnwrap(request.children.first))
                await server.send("<reply networkReplyId=\"\(replyId)\">\(response)</reply>")
                await server.flush()
            }
            return requests
        }
        defer {
            state.disconnect()
            serverTask.cancel()
            Task { await server.stop() }
        }
        state.connect(host: "127.0.0.1", port: server.port)
        try await waitUntil { state.phase == .login }
        state.login(userName: "Alice", nationId: "model.nation.dutch")
        try await waitUntil { state.phase == .inGame && state.game != nil }
        state.selectUnit("field-worker", onTile: "tile-2-2")
        state.openColonyPanel()
        state.renameSelectedColony(to: "Neu-Boston")
        try await waitUntil { state.selectedColony?.name == "Neu-Boston" }
        state.assignSelectedColonyWorker(to: "field-west")
        try await waitUntil { state.game?.units["field-worker"]?.location == "field-west" }
        XCTAssertEqual(state.selectedColonyWorkerUnitId, "field-worker")
        XCTAssertTrue(state.showColonyPanel)
        state.selectUnit("building-worker", onTile: "tile-2-2")
        state.assignSelectedColonyWorker(to: "field-west")
        try await waitUntil { state.game?.units["building-worker"]?.location == "field-west" }
        state.renameSelectedColony(to: "Abgelehnt")
        try await waitUntil { state.errorMessage?.contains("abgelehnt") == true }
        XCTAssertEqual(state.selectedColony?.name, "Neu-Boston")
        let requests = try await serverTask.value
        XCTAssertEqual(requests.map(\.tag), ["rename", "work", "rearrangeColony", "rename"])
        XCTAssertEqual(requests[0].attributes, ["nameable": "colony-1", "name": "Neu-Boston"])
        XCTAssertEqual(requests[1].attributes, ["unit": "field-worker", "workLocation": "field-west"])
        XCTAssertEqual(requests[2].attributes["xLength"], "2")
        XCTAssertEqual(requests[2].attributes["x0work"], "model.goods.hammers")
        XCTAssertEqual(requests[2].attributes["x1work"], "model.goods.grain")
        XCTAssertEqual(requests[2].attributes["x1role"], "model.role.default")
        XCTAssertEqual(requests[2].attributes["x1count"], "0")
        await server.stop()
    }

    @MainActor
    func testRemoteRightClickWaitsForEachMovementReply() async throws {
        let server = MockServer()
        let state = GameState()
        let serverTask = Task {
            try await server.doHandshake(gameResponse: Self.gameXML.replacingOccurrences(of: "\n", with: " "))
            let responses = [
                #"<partial id="outside-worker" destination="tile-4-2"/>"#,
                #"<partial id="outside-worker" location="tile-3-2" movesLeft="2"/>"#,
                #"<partial id="outside-worker" location="tile-4-2" movesLeft="1"/>"#,
            ]
            var requests: [ParsedMessage] = []
            for response in responses {
                let question = try XMLDecoder.decode(await server.nextLine())
                XCTAssertEqual(question.tag, "question")
                let replyId = try XCTUnwrap(question.attributes["networkReplyId"])
                requests.append(try XCTUnwrap(question.children.first))
                await server.send("<reply networkReplyId=\"\(replyId)\">\(response)</reply>")
                await server.flush()
            }
            return requests
        }
        defer {
            state.disconnect()
            serverTask.cancel()
            Task { await server.stop() }
        }
        state.connect(host: "127.0.0.1", port: server.port)
        try await waitUntil { state.phase == .login }
        state.login(userName: "Alice", nationId: "model.nation.dutch")
        try await waitUntil { state.phase == .inGame && state.game != nil }
        state.selectUnit("outside-worker", onTile: "tile-2-2")
        state.rightClickMapTile("tile-4-2")
        try await waitUntil {
            state.movingUnitId == nil && state.selectedUnit?.location == "tile-4-2"
        }
        let requests = try await serverTask.value
        XCTAssertEqual(requests.map(\.tag), ["setDestination", "move", "move"])
        XCTAssertEqual(requests.dropFirst().map { $0.attributes["direction"] }, ["E", "E"])
        XCTAssertEqual(state.selectedUnit?.movesLeft, 1)
        XCTAssertNil(state.errorMessage)
        await server.stop()
    }

    @MainActor
    func testRightClickMovesMultipleStepsAndPreservesSelection() async throws {
        let state = GameState()
        defer { state.disconnect() }
        state.startLocal(userName: "Alice", nationId: "model.nation.dutch")
        try await waitUntil { state.phase == .inGame }
        let game = Game()
        try game.load(from: XMLDecoder.decode(Self.gameXML))
        state.installGame(game)
        state.selectUnit("outside-worker", onTile: "tile-2-2")
        state.rightClickMapTile("tile-4-2")
        XCTAssertNil(state.tileActionTileId)
        XCTAssertEqual(state.movingUnitId, "outside-worker")
        XCTAssertFalse(state.canEndTurn)
        try await waitUntil { state.movingUnitId == nil }
        XCTAssertNil(state.errorMessage)
        XCTAssertEqual(game.units["outside-worker"]?.location, "tile-4-2")
        XCTAssertEqual(game.units["outside-worker"]?.movesLeft, 1)
        XCTAssertEqual(state.selectedUnitId, "outside-worker")
        XCTAssertEqual(state.selectedTileId, "tile-4-2")
        state.rightClickMapTile("tile-0-2", showMenu: true)
        XCTAssertEqual(state.tileActionTileId, "tile-0-2")
        XCTAssertNil(state.movingUnitId)
        state.selectUnit("outside-worker", onTile: "tile-4-2")
        state.rightClickMapTile("tile-0-2")
        try await waitUntil { state.movingUnitId == nil }
        XCTAssertEqual(game.units["outside-worker"]?.movesLeft, 0)
        XCTAssertEqual(game.units["outside-worker"]?.destination, "tile-0-2")
        XCTAssertNotEqual(game.units["outside-worker"]?.location, "tile-0-2")
    }

    @MainActor
    func testRightClickRejectsWaterForeignTurnAndIndoorWorker() throws {
        let state = try makeState()
        state.selectUnit("outside-worker", onTile: "tile-2-2")
        state.rightClickMapTile("tile-2-4")
        XCTAssertNil(state.movingUnitId)
        XCTAssertNotNil(state.errorMessage)
        state.selectUnit("field-worker", onTile: "tile-2-2")
        state.rightClickMapTile("tile-3-2")
        XCTAssertNil(state.movingUnitId)
        state.selectUnit("outside-worker", onTile: "tile-2-2")
        state.game?.currentPlayerId = "player-2"
        state.gameUpdateID += 1
        state.rightClickMapTile("tile-3-2")
        XCTAssertNil(state.movingUnitId)
        XCTAssertNotNil(state.errorMessage)
    }

    @MainActor
    private func makeState() throws -> GameState {
        let game = Game()
        try game.load(from: XMLDecoder.decode(Self.gameXML))
        let state = GameState()
        state.phase = .inGame
        state.installGame(game)
        return state
    }

    @MainActor
    private func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(5)
        while !condition(), Date() < deadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        guard condition() else {
            XCTFail("Timed out waiting for the expected game state")
            throw FreeColProtocolError.timeout
        }
    }

    static var gameXML: String {
        let tiles = (0..<6).flatMap { y in
            (0..<5).map { x in
                let type = x == 2 && y == 4 ? "ocean" : "plains"
                return "<tile id=\"tile-\(x)-\(y)\" x=\"\(x)\" y=\"\(y)\" type=\"model.tile.\(type)\" owner=\"player-1\"/>"
            }
        }.joined()
        return """
        <game id="game-1" clientUserName="Alice" currentPlayer="player-1">
          <freecol-specification>
            <unit-type id="colonist"><ability id="model.ability.person"/><ability id="model.ability.canBeEquipped"/></unit-type>
            <unit-type id="model.unit.freeColonist" extends="colonist"/>
            <unit-type id="model.unit.caravel"><ability id="model.ability.navalUnit"/><ability id="model.ability.carryUnits"/></unit-type>
            <unit-type id="model.unit.wagonTrain"><ability id="model.ability.carryGoods"/></unit-type>
            <goods-type id="model.goods.grain"/><goods-type id="model.goods.hammers"/>
            <tile-improvement-type id="model.improvement.road" required-role="model.role.pioneer"/>
            <tile-type id="model.tile.plains">
              <production><output goods-type="model.goods.grain" value="3"/></production>
            </tile-type>
            <building-type id="model.building.carpenterHouse">
              <production><output goods-type="model.goods.hammers" value="3"/></production>
            </building-type>
          </freecol-specification>
          <player id="player-1" username="Alice" nationId="model.nation.dutch"><europe id="europe-1"/></player>
          <player id="player-2" username="Bob"/>
          <map id="map-1" width="5" height="6">\(tiles)</map>
          <colony id="colony-1" name="Boston" owner="player-1" tile="tile-2-2">
            <building id="building-1" buildingType="model.building.carpenterHouse">
              <unit id="building-worker" unitType="model.unit.freeColonist" owner="player-1" location="building-1" movesLeft="0"/>
            </building>
            <colonyTile id="field-east" workTile="tile-3-2">
              <unit id="field-worker" unitType="model.unit.freeColonist" owner="player-1" location="field-east"
                    workType="model.goods.grain" movesLeft="0"/>
            </colonyTile>
            <colonyTile id="field-west" workTile="tile-1-2"/>
            <colonyTile id="field-center" workTile="tile-2-2"/>
            <colonyTile id="field-water" workTile="tile-2-4"/>
          </colony>
          <unit id="outside-worker" owner="player-1" unitType="model.unit.freeColonist" location="tile-2-2" movesLeft="3"/>
          <unit id="ship" owner="player-1" unitType="model.unit.caravel" location="tile-2-2" movesLeft="6"/>
          <unit id="wagon" owner="player-1" unitType="model.unit.wagonTrain" location="tile-2-2" movesLeft="3"/>
          <unit id="europe-worker" owner="player-1" unitType="model.unit.freeColonist" location="europe-1"/>
        </game>
        """
    }
}

import XCTest
import FreeColGame
import FreeColProtocol
@testable import Novaloria

final class ColonyNavigationTests: XCTestCase {
    @MainActor
    func testOpenColonyDoesNotFollowPreviouslySelectedUnitOnUpdate() throws {
        let state = try makeState()
        state.selectUnit("away-worker", onTile: "tile-4-2")
        state.selectMapTile("tile-2-2", openColony: true)
        XCTAssertEqual(state.selectedColony?.id, "colony-1")

        state.syncAfterModelUpdate()

        XCTAssertTrue(state.showColonyPanel)
        XCTAssertEqual(state.selectedColony?.id, "colony-1")
        XCTAssertEqual(state.selectedTileId, "tile-2-2")
        XCTAssertNil(state.selectedUnitId)
    }

    @MainActor
    func testOpenColonyStaysSelectedWhenItsLastUnitsDisappear() throws {
        let state = try makeState()
        state.selectUnit("field-worker", onTile: "tile-2-2")
        state.openColonyPanel()
        try state.game?.applyRemove(XMLDecoder.decode("""
        <remove xLength="5" x0="field-worker" x1="building-worker"
                x2="outside-worker" x3="ship" x4="wagon"/>
        """))
        state.gameUpdateID += 1

        state.syncAfterModelUpdate()

        XCTAssertTrue(state.showColonyPanel)
        XCTAssertEqual(state.selectedColony?.id, "colony-1")
        XCTAssertEqual(state.selectedTileId, "tile-2-2")
        XCTAssertNil(state.selectedUnitId)
    }

    @MainActor
    func testOpenColonyDoesNotFollowWorkerMovedToAnotherColony() throws {
        let state = try makeState()
        state.selectUnit("field-worker", onTile: "tile-2-2")
        state.openColonyPanel()
        try state.game?.applyPartial(XMLDecoder.decode("""
        <partial id="field-worker" location="colony-2"/>
        """))
        state.gameUpdateID += 1

        state.syncAfterModelUpdate()

        XCTAssertEqual(state.selectedColony?.id, "colony-1")
        XCTAssertEqual(state.selectedTileId, "tile-2-2")
        XCTAssertNil(state.selectedUnitId)
    }

    @MainActor
    func testNavigationUsesOwnColoniesInAlphabeticalOrderAndWraps() throws {
        let state = try makeState()
        state.openColonyPanel(colonyId: "colony-1")
        XCTAssertEqual(state.coloniesForNavigation.map(\.id), ["colony-2", "colony-1", "colony-3"])
        XCTAssertTrue(state.canNavigateColonies)

        for id in ["colony-3", "colony-2", "colony-1"] {
            state.selectNextColony()
            XCTAssertEqual(state.selectedColony?.id, id)
            XCTAssertEqual(state.selectedTileId, state.selectedColony?.tileId)
            XCTAssertTrue(state.showColonyPanel)
            state.syncAfterModelUpdate()
            XCTAssertEqual(state.selectedColony?.id, id)
        }
        for id in ["colony-2", "colony-3", "colony-1"] {
            state.selectPreviousColony()
            XCTAssertEqual(state.selectedColony?.id, id)
        }
    }

    @MainActor
    func testSelectingSpecificColonyClearsPreviousWorkerAndUpdatesActionTargets() throws {
        let state = try makeState()
        state.selectUnit("field-worker", onTile: "tile-2-2")
        state.openColonyPanel()
        XCTAssertEqual(state.selectedColonyWorkerUnitId, "field-worker")

        state.openColonyPanel(colonyId: "colony-2")

        XCTAssertEqual(state.selectedColony?.id, "colony-2")
        XCTAssertEqual(state.selectedTileId, "tile-4-2")
        XCTAssertNil(state.selectedUnitId)
        XCTAssertEqual(state.selectedColonyWorkerUnitId, "away-worker")
        XCTAssertEqual(state.selectedColonyUnits.map(\.id), ["away-worker"])
        XCTAssertTrue(state.canManageSelectedColony)
        state.syncAfterModelUpdate()
        XCTAssertEqual(state.selectedColony?.id, "colony-2")
        XCTAssertNil(state.selectedUnitId)
    }

    @MainActor
    func testColonyUpdatesRefreshContentsWithoutChangingSelection() throws {
        let state = try makeState()
        state.selectUnit("field-worker", onTile: "tile-2-2")
        state.openColonyPanel()
        try state.game?.applyPartial(XMLDecoder.decode("""
        <partial id="colony-1" name="New Boston"/>
        """))
        state.gameUpdateID += 1
        state.syncAfterModelUpdate()

        XCTAssertEqual(state.selectedColony?.id, "colony-1")
        XCTAssertEqual(state.selectedColony?.name, "New Boston")
        XCTAssertEqual(state.selectedUnitId, "field-worker")
        XCTAssertEqual(state.selectedColonyWorkerUnitId, "field-worker")
        state.openColonyPanel(colonyId: "colony-1")
        XCTAssertEqual(state.selectedUnitId, "field-worker")
    }

    @MainActor
    func testRemovedColonyClosesPanelInsteadOfOpeningAnotherColony() throws {
        let state = try makeState()
        state.openColonyPanel(colonyId: "colony-3")
        try state.game?.applyRemove(XMLDecoder.decode(#"<remove xLength="1" x0="colony-3"/>"#))
        state.gameUpdateID += 1

        state.syncAfterModelUpdate()

        XCTAssertFalse(state.showColonyPanel)
        XCTAssertFalse(state.coloniesForNavigation.contains { $0.id == "colony-3" })
    }

    @MainActor
    func testClosingPanelRestoresMapSelectionAndAllowsReopeningAnotherColony() throws {
        let state = try makeState()
        state.openColonyPanel(colonyId: "colony-1")
        state.closeColonyPanel()
        state.selectUnit("away-worker", onTile: "tile-4-2")
        state.syncAfterModelUpdate()
        XCTAssertEqual(state.selectedColony?.id, "colony-2")

        state.openColonyPanel()
        XCTAssertEqual(state.selectedColony?.id, "colony-2")
        XCTAssertEqual(state.selectedUnitId, "away-worker")
        state.disconnect()
        XCTAssertFalse(state.showColonyPanel)
        XCTAssertNil(state.selectedColony)
    }

    @MainActor
    func testUnavailableColonyReportsErrorWithoutChangingOpenColony() throws {
        let state = try makeState()
        state.openColonyPanel(colonyId: "colony-1")
        state.openColonyPanel(colonyId: "missing-colony")

        XCTAssertEqual(state.selectedColony?.id, "colony-1")
        XCTAssertTrue(state.showColonyPanel)
        XCTAssertNotNil(state.errorMessage)
    }

    @MainActor
    func testSingleColonyDisablesCyclingAndForeignColonyRemainsReadOnly() throws {
        let state = try makeState()
        try state.game?.applyRemove(XMLDecoder.decode("""
        <remove xLength="2" x0="colony-2" x1="colony-3"/>
        """))
        state.gameUpdateID += 1
        state.openColonyPanel(colonyId: "colony-1")
        XCTAssertEqual(state.coloniesForNavigation.map(\.id), ["colony-1"])
        XCTAssertFalse(state.canNavigateColonies)

        state.openColonyPanel(colonyId: "foreign-colony")
        XCTAssertEqual(state.selectedColony?.id, "foreign-colony")
        XCTAssertFalse(state.canManageSelectedColony)
        XCTAssertTrue(state.canNavigateColonies)
        state.selectNextColony()
        XCTAssertEqual(state.selectedColony?.id, "colony-1")
        XCTAssertTrue(state.canManageSelectedColony)
    }

    @MainActor
    private func makeState() throws -> GameState {
        let game = Game()
        try game.load(from: XMLDecoder.decode(InteractionRepairTests.gameXML))
        try game.applyUpdate(XMLDecoder.decode("""
        <update>
          <colony id="colony-2" name="Amsterdam" owner="player-1" tile="tile-4-2"/>
          <colony id="colony-3" name="Charleston" owner="player-1" tile="tile-0-0"/>
          <colony id="foreign-colony" name="Aachen" owner="player-2" tile="tile-0-4"/>
          <unit id="away-worker" owner="player-1" unitType="model.unit.freeColonist"
                location="tile-4-2" state="ACTIVE" movesLeft="3"/>
        </update>
        """))
        let state = GameState()
        state.phase = .inGame
        state.installGame(game)
        return state
    }
}

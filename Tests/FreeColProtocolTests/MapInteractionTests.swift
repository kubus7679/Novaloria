import AppKit
import SwiftUI
import XCTest
import Observation
import FreeColGame
import FreeColProtocol
@testable import Novaloria

final class MapInteractionTests: XCTestCase {
    @MainActor
    func testGermanTradeRouteEditorFitsNativeWindow() throws {
        let state = try makeState()
        state.game?.specification = Specification(parsed: try XMLDecoder.decode("""
        <freecol-specification id="spec"><goods-types>
          <goods-type id="model.goods.grain"/><goods-type id="model.goods.tools"/>
          <goods-type id="model.goods.lumber"/><goods-type id="model.goods.ore"/>
          <goods-type id="model.goods.silver"/><goods-type id="model.goods.cloth"/>
        </goods-types></freecol-specification>
        """))
        try state.game?.applyUpdate(XMLDecoder.decode("""
        <update><tradeRoute id="route-1" name="Versorgung Boston" owner="player-1">
          <tradeRouteStop location="colony-1"><cargo id="model.goods.grain"/></tradeRouteStop>
          <tradeRouteStop location="europe-1"/>
        </tradeRoute></update>
        """))
        state.gameUpdateID += 1
        try checkPanel(TradeRoutePanelView().environment(state), name: "trade-routes-german",
                       width: 680, height: 680)
    }

    @MainActor
    func testOriginalResourceGraphicsCoverClassicTypesAndUpdateWithTiles() throws {
        let state = try makeState()
        let game = try XCTUnwrap(state.game)
        for type in ["game", "minerals", "ore", "silver", "lumber", "furs",
                     "tobacco", "sugar", "cotton", "oasis", "grain", "fish"] {
            let image = try XCTUnwrap(TileImageCache.shared.resourceImage(for: "model.resource.\(type)"))
            XCTAssertGreaterThan(image.size.width, 0)
        }
        XCTAssertNil(TileImageCache.shared.resourceImage(for: nil))
        XCTAssertNil(TileImageCache.shared.resourceImage(for: "model.resource.unknown"))
        try game.applyUpdate(XMLDecoder.decode("""
        <update><tile id="tile-3-2" x="3" y="2" type="model.tile.plains">
          <tileItemContainer id="resources-1">
            <resource id="resource-1" type="model.resource.grain" quantity="-1"/>
          </tileItemContainer>
        </tile></update>
        """))
        state.selectedUnitId = nil
        state.selectedTileId = "tile-3-2"
        state.gameUpdateID += 1
        XCTAssertEqual(game.tiles["tile-3-2"]?.resources.first?.quantity, -1)
        for overlay in [GameState.MapOverlay.none, .resources] {
            state.mapOverlay = overlay
            try checkPanel(GameView().environment(state), name: "resources-\(overlay.rawValue)", width: 1200, height: 800)
        }
        try game.applyUpdate(XMLDecoder.decode("""
        <update><tile id="tile-3-2" x="3" y="2" type="model.tile.plains">
          <tileItemContainer id="resources-1"/>
        </tile></update>
        """))
        XCTAssertTrue(try XCTUnwrap(game.tiles["tile-3-2"]).resources.isEmpty)
    }

    func testOriginalTileImprovementGraphicsCoverRiverStylesAndPlowing() throws {
        let cache = TileImageCache.shared
        for styleNumber in 0..<81 {
            var value = styleNumber
            var style = ""
            for _ in 0..<4 {
                style.append(String(value % 3))
                value /= 3
            }
            let image = try XCTUnwrap(cache.riverImage(forStyle: style), style)
            XCTAssertGreaterThan(image.size.width, 0)
        }
        XCTAssertNil(cache.riverImage(forStyle: "000"))
        XCTAssertNil(cache.riverImage(forStyle: "0003"))
        XCTAssertGreaterThan(try XCTUnwrap(cache.improvementImage(forType: "model.improvement.plow")).size.width, 0)
        let fishBonus = try XCTUnwrap(cache.improvementBonusImage(forType: "model.improvement.fishBonusRiver"))
        XCTAssertTrue(fishBonus === cache.resourceImage(for: "model.resource.fish"))
        XCTAssertTrue(try XCTUnwrap(cache.improvementBonusImage(forType: "model.improvement.fishBonusLand")) === fishBonus)
    }

    @MainActor
    func testRumourMarkerAppearsWithoutSecretTypeAndDisappearsAfterExploration() throws {
        let state = try makeState()
        let game = try XCTUnwrap(state.game)
        let update = try XMLDecoder.decode("""
        <update><tile id="tile-3-2" x="3" y="2" type="model.tile.plains">
          <tileItemContainer id="items-1"><lostCityRumour id="rumour-1"/></tileItemContainer>
        </tile></update>
        """)
        try game.applyUpdate(update)
        let rumour = try XCTUnwrap(game.tiles["tile-3-2"])
        XCTAssertTrue(rumour.hasLostCityRumour)
        XCTAssertNil(rumour.lostCityRumourType, "The server need not reveal the outcome")
        XCTAssertNotNil(TileImageCache.shared.lostCityRumourImage(for: rumour))
        var unexplored = rumour
        unexplored.type = nil
        XCTAssertNil(TileImageCache.shared.lostCityRumourImage(for: unexplored))
        state.selectedUnitId = nil
        state.selectedTileId = rumour.id
        state.gameUpdateID += 1
        try checkPanel(GameView().environment(state), name: "lost-city-rumour", width: 1200, height: 800)
        try game.applyRemove(XMLDecoder.decode(#"<remove xLength="1" x0="rumour-1"/>"#))
        XCTAssertFalse(try XCTUnwrap(game.tiles[rumour.id]).hasLostCityRumour)
        XCTAssertNil(TileImageCache.shared.lostCityRumourImage(for: try XCTUnwrap(game.tiles[rumour.id])))
        try game.applyUpdate(update)
        try game.applyUpdate(XMLDecoder.decode("""
        <update><tile id="tile-3-2" x="3" y="2" type="model.tile.plains">
          <tileItemContainer id="items-1"/>
        </tile></update>
        """))
        XCTAssertFalse(try XCTUnwrap(game.tiles[rumour.id]).hasLostCityRumour)
    }

    @MainActor
    func testSavedMovementRouteIsVisibleWithoutEnablingPathOverlay() throws {
        let state = try makeState()
        let game = try XCTUnwrap(state.game)
        game.setUnitDestination(unitId: "unit-1", destinationId: "tile-4-2")
        state.gameUpdateID += 1
        state.selectUnit("unit-1", onTile: "tile-2-2")
        XCTAssertEqual(state.mapOverlay, .none)
        let route = state.movementPath(for: try XCTUnwrap(game.units["unit-1"]))
        XCTAssertEqual(route.first, "tile-2-2")
        XCTAssertEqual(route.last, "tile-4-2")
        try checkPanel(GameView().environment(state), name: "saved-movement-route", width: 1200, height: 800)
        game.setUnitDestination(unitId: "unit-1", destinationId: nil)
        XCTAssertTrue(state.movementPath(for: try XCTUnwrap(game.units["unit-1"])).isEmpty)
    }

    @MainActor
    func testEuropeDockRecruitmentAndPurchasesUseUnitGraphics() throws {
        let state = try makeState()
        state.game?.specification = Specification(parsed: try XMLDecoder.decode("""
        <freecol-specification>
          <unit-type id="model.unit.masterCarpenter" price="900"/>
          <unit-type id="model.unit.caravel" price="1000">
            <ability id="model.ability.navalUnit"/><ability id="model.ability.carryUnits"/>
          </unit-type>
          <unit-type id="model.unit.artillery" price="500"/>
        </freecol-specification>
        """))
        try state.game?.applyUpdate(XMLDecoder.decode("""
        <update>
          <player id="player-1" username="Alice" gold="1500" immigrationRequired="12">
            <europe id="europe-1" owner="player-1" recruitPrice="120">
              <recruit id="model.unit.masterCarpenter" number="1"/>
              <recruit id="model.unit.freeColonist" number="1"/>
              <recruit id="model.unit.expertFarmer" number="1"/>
            </europe>
          </player>
          <unit id="ship-port" unitType="model.unit.caravel" owner="player-1" location="europe-1"/>
          <unit id="carpenter" unitType="model.unit.masterCarpenter" owner="player-1" location="europe-1"/>
        </update>
        """))
        state.gameUpdateID += 1
        XCTAssertEqual(state.purchasableEuropeUnits.count, 3)
        for type in ["masterCarpenter", "freeColonist", "expertFarmer", "caravel", "artillery"] {
            let image = try XCTUnwrap(TileImageCache.shared.unitImage(forUnitType: "model.unit.\(type)"))
            XCTAssertGreaterThan(image.size.width, 0)
        }
        let pioneerImage = try XCTUnwrap(TileImageCache.shared.unitImage(
            forUnitType: "model.unit.pettyCriminal", role: "model.role.pioneer"
        ))
        let roleImage = try XCTUnwrap(TileImageCache.shared.loadImage(named: "pioneer", folder: "units"))
        XCTAssertTrue(pioneerImage === roleImage)
        for section in [EuropePanelView.EuropeSection.harbor, .recruitment] {
            try checkPanel(EuropePanelView(section: section).environment(state),
                           name: "europe-return-\(section)", width: 600, height: 480)
        }
    }

    @MainActor
    func testHighSeasExitsUseOriginalCloudsOnlyOnEnabledExploredTiles() throws {
        let game = try makeGame()
        for (type, override, marked) in [
            ("model.tile.highSeas", "", true),
            ("model.tile.ocean", "moveToEurope=\"true\"", true),
            ("model.tile.ocean", "", false),
            ("model.tile.highSeas", "moveToEurope=\"false\"", false),
            ("", "moveToEurope=\"true\"", false),
        ] {
            let tile = try Tile(id: "exit", attributes: XMLDecoder.decode(
                "<tile x=\"0\" y=\"2\" \(type.isEmpty ? "" : "type=\"\(type)\"") \(override)/>"
            ).attributes, children: [], game: game)
            let image = TileImageCache.shared.highSeasExitImage(for: tile)
            XCTAssertEqual(image != nil, marked, "\(type) \(override)")
            if marked {
                XCTAssertTrue(image === TileImageCache.shared.cloudImage(forX: tile.x, y: tile.y))
            }
        }
        for x in 0..<4 {
            XCTAssertNotNil(TileImageCache.shared.cloudImage(forX: x, y: 0))
        }
    }

    @MainActor
    func testHighSeasExitMapAndInspectorFitNativeWindow() throws {
        let state = try makeState()
        try state.game?.applyUpdate(XMLDecoder.decode("""
        <update>
          <tile id="tile-0-0" x="0" y="0" type="model.tile.highSeas"/>
          <tile id="tile-0-1" x="0" y="1" type="model.tile.ocean" moveToEurope="true"/>
          <tile id="tile-0-2" x="0" y="2" type="model.tile.highSeas" moveToEurope="false"/>
          <tile id="tile-1-0" x="1" y="0" type="model.tile.ocean"/>
        </update>
        """))
        state.showFogOfWar = false
        state.gameUpdateID += 1
        state.selectedUnitId = nil
        state.selectedTileId = "tile-0-0"
        try checkPanel(GameView().environment(state).frame(width: 1200, height: 800),
                       name: "high-seas-exits", width: 1200, height: 800)
    }

    @MainActor
    func testCoastalDisembarkControlsFitWithAndWithoutMoves() throws {
        let state = try makeState()
        try state.game?.applyUpdate(XMLDecoder.decode("""
        <update>
          <tile id="tile-1-0" x="1" y="0" type="model.tile.ocean"/>
          <unit id="ship" owner="player-1" unitType="model.unit.caravel" location="tile-1-0" movesLeft="0"/>
          <unit id="unit-1" owner="player-1" unitType="model.unit.freeColonist"
                location="ship" state="sentry" movesLeft="3"/>
        </update>
        """))
        state.gameUpdateID += 1
        state.selectUnit("unit-1", onTile: "tile-1-0")
        XCTAssertTrue(state.canDisembarkSelectedUnit)
        try checkPanel(GameView().environment(state).frame(width: 900, height: 620),
                       name: "disembark-coast-ready", width: 900, height: 620)
        try state.game?.applyPartial(XMLDecoder.decode("""
        <partial id="unit-1" movesLeft="0"/>
        """))
        state.gameUpdateID += 1
        XCTAssertFalse(state.canDisembarkSelectedUnit)
        try checkPanel(GameView().environment(state).frame(width: 900, height: 620),
                       name: "disembark-coast-no-moves", width: 900, height: 620)
        try state.game?.applyPartial(XMLDecoder.decode("""
        <partial id="ship" location="europe-1"/>
        """))
        state.gameUpdateID += 1
        XCTAssertTrue(state.canDisembarkSelectedUnit)
        try checkPanel(EuropePanelView(section: .harbor).environment(state),
                       name: "disembark-europe-no-moves", width: 600, height: 480)
    }

    @MainActor
    func testTributeEditorFitsNativePanel() throws {
        let state = try makeState()
        state.game?.specification = Specification(parsed: try XMLDecoder.decode("""
        <freecol-specification><unit-type id="model.unit.freeColonist"/></freecol-specification>
        """))
        try state.game?.applyUpdate(XMLDecoder.decode("""
        <update><colony id="foreign-colony" owner="player-2" tile="tile-2-0" name="Quebec"/></update>
        """))
        try state.game?.applyPartial(XMLDecoder.decode("""
        <partial id="unit-1" role="model.role.soldier"/>
        """))
        state.gameUpdateID += 1
        state.selectUnit("unit-1", onTile: "tile-2-2")
        state.beginDiplomacy(otherColonyId: "foreign-colony")
        XCTAssertEqual(state.pendingDiplomacy?.context, "TRIBUTE")
        try checkPanel(DiplomacyView().environment(state).frame(width: 760, height: 480),
                       name: "diplomacy-tribute", width: 760, height: 480)
        state.applySessionMessage(try XMLDecoder.decode("""
        <diplomacy ourId="unit-1" otherId="foreign-colony">
          <diplomaticTrade id="" context="tribute" status="propose_trade"
                          sender="player-1" recipient="player-2" version="2">
            <goldTradeItem id="model.tradeItem.gold" source="player-2" destination="player-1" gold="50"/>
          </diplomaticTrade>
        </diplomacy>
        """))
        XCTAssertTrue(state.pendingDiplomacyIsIncoming)
        try checkPanel(DiplomacyView().environment(state).frame(width: 760, height: 480),
                       name: "diplomacy-tribute-counteroffer", width: 760, height: 480)
    }

    @MainActor
    func testShipTravelArrivalAndSpecificationPricesFitNativePanels() throws {
        let state = try makeState()
        let game = try XCTUnwrap(state.game)
        game.specification = Specification(parsed: try XMLDecoder.decode("""
        <freecol-specification><unit-types>
          <unit-type id="model.unit.caravel" price="1000">
            <ability id="model.ability.navalUnit"/><ability id="model.ability.carryUnits"/>
          </unit-type>
          <unit-type id="model.unit.artillery" price="500"/>
        </unit-types></freecol-specification>
        """))
        try game.applyUpdate(XMLDecoder.decode("""
        <update>
          <player id="player-1" username="Alice" gold="1500" immigrationRequired="12">
            <europe id="europe-1" owner="player-1" recruitPrice="120">
              \(String(repeating: "<recruit id=\"model.unit.freeColonist\" number=\"1\"/>", count: 3))
            </europe>
          </player>
          <unit id="ship-transit" owner="player-1" unitType="model.unit.caravel" name="Hoffnung"
                location="highSeas:1" destination="europe-1" state="SAILING" workLeft="2"/>
        </update>
        """))
        state.gameUpdateID += 1
        state.selectUnit("ship-transit", onTile: nil)
        state.syncAfterModelUpdate()
        XCTAssertEqual(state.selectedUnitId, "ship-transit")
        XCTAssertEqual(state.purchasableEuropeUnits.map(\.price), [500, 1000])
        for turns in [2, 1] {
            try game.applyPartial(ParsedMessage(tag: "partial", attributes: [
                "id": "ship-transit", "workLeft": String(turns),
            ], children: []))
            state.gameUpdateID += 1
            try checkPanel(InfoPanelView().environment(state).frame(width: 360, height: 220), name: "ship-transit-\(turns)",
                           width: 360, height: 220)
        }
        try checkPanel(EuropePanelView(section: .harbor).environment(state),
                       name: "europe-transit-600", width: 600, height: 480)
        try checkPanel(EuropePanelView(section: .recruitment).environment(state),
                       name: "europe-specification-prices-600", width: 600, height: 480)
        try game.applyPartial(try XMLDecoder.decode("""
        <partial id="ship-transit" location="europe-1" state="ACTIVE" workLeft="0"/>
        """))
        state.gameUpdateID += 1
        state.syncAfterModelUpdate()
        XCTAssertEqual(state.selectedUnitId, "ship-transit")
        try checkPanel(InfoPanelView().environment(state).frame(width: 360, height: 220),
                       name: "ship-arrived", width: 360, height: 220)
        try checkPanel(EuropePanelView(section: .harbor).environment(state),
                       name: "europe-arrived-600", width: 600, height: 480)
    }

    func testResizePreservesCameraCenterAndClampsAtMapEdges() {
        let canvas = CGSize(width: 10000, height: 8000)
        let large = CGSize(width: 2000, height: 1100)
        let small = CGSize(width: 640, height: 380)
        let camera = CGPoint(x: 2400, y: 1800)
        let resized = MapGeometry.resizedCamera(camera, from: large, to: small, canvas: canvas)
        XCTAssertEqual(resized.x + small.width / 2, camera.x + large.width / 2)
        XCTAssertEqual(resized.y + small.height / 2, camera.y + large.height / 2)
        XCTAssertEqual(MapGeometry.resizedCamera(resized, from: small, to: large, canvas: canvas), camera)
        XCTAssertEqual(MapGeometry.resizedCamera(.zero, from: small, to: large,
                                                 canvas: CGSize(width: 100, height: 100)), .zero)
        let clamped = MapGeometry.resizedCamera(CGPoint(x: 9999, y: 7999), from: large, to: small, canvas: canvas)
        XCTAssertEqual(clamped, CGPoint(x: canvas.width - small.width, y: canvas.height - small.height))
    }

    @MainActor
    func testOriginalTerrainLayersCoverAllClassicTypesAndBeachStyles() throws {
        let forests = ["mixedForest", "coniferForest", "broadleafForest", "tropicalForest",
                       "wetlandForest", "rainForest", "scrubForest", "borealForest"]
        let types = forests + ["plains", "grassland", "prairie", "savannah", "marsh", "swamp",
                               "desert", "tundra", "hills", "mountains", "arctic", "ocean",
                               "lake", "highSeas", "greatRiver"]
        for type in types {
            let image = try XCTUnwrap(TileImageCache.shared.terrainImage(forType: "model.tile.\(type)"), type)
            XCTAssertGreaterThan(image.size.width, 0)
        }
        for type in forests + ["hills", "mountains"] {
            XCTAssertNotNil(TileImageCache.shared.terrainOverlay(forType: "model.tile.\(type)"), type)
        }
        for style in 1...15 {
            XCTAssertEqual(TileImageCache.shared.beachImages(style: style).count, 1)
            XCTAssertEqual(TileImageCache.shared.beachImages(style: style << 4).count, 1)
            XCTAssertEqual(TileImageCache.shared.beachImages(style: style << 4 | style).count, 2)
        }
        XCTAssertTrue(TileImageCache.shared.beachImages(style: 0).isEmpty)
    }

    func testObjectNamesAndImprovementConnections() throws {
        XCTAssertEqual(GameLabels.name("model.unit.hardyPioneer"), "Zäher Pionier")
        XCTAssertEqual(GameLabels.name("model.unit.caravel"), "Karavelle")
        XCTAssertEqual(GameLabels.name("model.goods.horses"), "Pferde")
        XCTAssertEqual(GameLabels.name("model.tile.mixedForest"), "Mischwald")
        XCTAssertEqual(GameLabels.name("mod.customUnit"), "Custom Unit")
        XCTAssertEqual(GameLabels.name("mod.customUnit", fallback: "Mod-Kolonist"), "Mod-Kolonist")
        XCTAssertEqual(GameLabels.name("model.unit.caravel", fallback: "Caravel"), "Karavelle")
        XCTAssertEqual(GameLabels.state(.sailing), "Auf See")
        let game = try makeGame()
        try game.applyUpdate(XMLDecoder.decode("""
        <update><tile id="tile-2-2" x="2" y="2" type="model.tile.mixedForest">
          <tileItemContainer><tileImprovement id="road-1" type="model.improvement.road"
             turns="0" style="10001000" magnitude="1"/></tileItemContainer>
        </tile></update>
        """))
        XCTAssertEqual(game.tiles["tile-2-2"]?.improvements.first?.style, "10001000")
    }

    @MainActor
    func testRecruitmentAffordabilityFreeMigrationAndTurnGuards() throws {
        let state = try makeState()
        XCTAssertNil(state.europeRecruitmentCost)
        XCTAssertFalse(state.canRecruitInEurope)
        try state.game?.applyPartial(ParsedMessage(tag: "partial", attributes: [
            "id": "player-1", "immigrationRequired": "12", "immigration": "6", "gold": "59",
        ], children: []))
        state.gameUpdateID += 1
        XCTAssertEqual(state.europeRecruitmentCost, 60)
        XCTAssertFalse(state.canRecruitInEurope)
        state.recruitUnitInEurope(slot: 1)
        XCTAssertNotNil(state.errorMessage)
        XCTAssertEqual(state.purchasesRecruits, 0)
        try state.game?.applyPartial(ParsedMessage(tag: "partial", attributes: [
            "id": "player-1", "gold": "60",
        ], children: []))
        state.gameUpdateID += 1
        XCTAssertTrue(state.canRecruitInEurope)
        XCTAssertTrue(state.canChooseEuropeRecruit)
        try state.game?.applyPartial(ParsedMessage(tag: "partial", attributes: [
            "id": "player-1", "gold": "0", "immigration": "12",
        ], children: []))
        state.gameUpdateID += 1
        XCTAssertEqual(state.europeRecruitmentCost, 0)
        XCTAssertTrue(state.canRecruitInEurope)
        XCTAssertFalse(state.canChooseEuropeRecruit)
        state.recruitUnitInEurope(slot: 1)
        XCTAssertEqual(state.purchasesRecruits, 0)
        try state.game?.applyUpdate(XMLDecoder.decode("""
        <update><player id="player-1" username="Alice" gold="0" immigration="12" immigrationRequired="12">
          <ability id="model.ability.selectRecruit" value="true"/>
          <europe id="europe-1"><recruit id="model.unit.freeColonist"/></europe>
        </player></update>
        """))
        state.gameUpdateID += 1
        XCTAssertTrue(state.canChooseEuropeRecruit)
        state.game?.currentPlayerId = "player-2"
        state.gameUpdateID += 1
        XCTAssertFalse(state.canRecruitInEurope)
    }

    @MainActor
    func testEuropeOnlyListsUnitsActuallyInPort() throws {
        let state = try makeState()
        try state.game?.applyUpdate(XMLDecoder.decode("""
        <update>
          <unit id="ship-port" unitType="model.unit.caravel" owner="player-1" location="europe-1"/>
          <unit id="ship-sea" unitType="model.unit.caravel" owner="player-1" location="highSeas:1"/>
          <unit id="dock-unit" unitType="model.unit.freeColonist" owner="player-1" location="europe-1"/>
          <unit id="passenger" unitType="model.unit.freeColonist" owner="player-1" location="ship-port"/>
          <unit id="worker" unitType="model.unit.freeColonist" owner="player-1" location="colony-1"/>
        </update>
        """))
        state.gameUpdateID += 1
        XCTAssertEqual(Set(state.europeUnits.map(\.id)), ["ship-port", "dock-unit"])
        XCTAssertEqual(state.europeCarrierUnits.map(\.id), ["ship-port"])
    }

    @MainActor
    func testPlayerColorsUseNationAndStableFallback() throws {
        let state = try makeState()
        try state.game?.applyPartial(ParsedMessage(tag: "partial", attributes: [
            "id": "player-1", "nationId": "model.nation.french",
        ], children: []))
        state.gameUpdateID += 1
        XCTAssertEqual(state.playerColor(for: "player-1"), .blue)
        XCTAssertEqual(state.playerColor(for: "player-2"), try makeState().playerColor(for: "player-2"))
    }

    @MainActor
    func testColonyPopulationExcludesOutdoorUnitsAndWorkerSelectionExcludesShips() throws {
        let state = try makeState()
        try state.game?.applyUpdate(XMLDecoder.decode("""
        <update>
          <colony id="colony-1" name="Boston" owner="player-1" tile="tile-2-2">
            <building id="building-1" buildingType="model.building.townHall"/>
          </colony>
          <unit id="worker-1" owner="player-1" unitType="model.unit.freeColonist" location="building-1"/>
          <unit id="aaa-ship" owner="player-1" unitType="model.unit.caravel" location="tile-2-2"/>
        </update>
        """))
        state.gameUpdateID += 1
        state.selectUnit("aaa-ship", onTile: "tile-2-2")
        let colony = try XCTUnwrap(state.selectedColony)
        XCTAssertEqual(state.colonyPopulation(colony), 1)
        XCTAssertTrue(state.selectedColonyUnits.contains(where: { $0.id == "worker-1" }))
        XCTAssertNotEqual(state.selectedColonyWorkerUnitId, "aaa-ship")
        state.selectUnit("worker-1", onTile: "tile-2-2")
        XCTAssertEqual(state.selectedColonyWorkerUnitId, "worker-1")
    }

    @MainActor
    func testColopediaHasGermanDescriptionsIconsAndCompleteCategories() throws {
        let entries = ColopediaCatalog.entries(specification: nil)
        XCTAssertGreaterThan(entries.count, 200)
        XCTAssertEqual(Set(entries.map(\.id)).count, entries.count)
        XCTAssertEqual(Set(entries.map(\.category)), Set(ColopediaCategory.allCases))
        for goods in ["model.goods.grain", "model.goods.cotton", "model.goods.food"] {
            XCTAssertNotNil(TileImageCache.shared.goodsImage(for: goods), goods)
        }
        let colonist = try XCTUnwrap(entries.first { $0.id == "model.unit.freeColonist" })
        XCTAssertEqual(colonist.title, "Freier Kolonist")
        XCTAssertTrue(colonist.summary.contains("Kolonist"))
        let father = try XCTUnwrap(entries.first { $0.id == "model.foundingFather.adamSmith" })
        XCTAssertEqual(father.title, "Adam Smith")
        XCTAssertFalse(father.text.isEmpty)
        XCTAssertFalse(ColopediaCatalog.search(entries, query: "Lagerhaus").isEmpty)
        XCTAssertTrue(ColopediaCatalog.search(entries, query: "nichtvorhanden123").isEmpty)
        for entry in entries {
            XCTAssertFalse(entry.title.contains("{{"), entry.id)
            XCTAssertFalse(entry.summary.contains("%"), entry.id)
            if entry.icon != nil || entry.category == .units || entry.category == .terrain {
                XCTAssertNotNil(TileImageCache.shared.colopediaImage(for: entry), entry.id)
            }
        }
        let warehouse = try XCTUnwrap(entries.first { $0.id == "model.building.warehouse" })
        XCTAssertTrue(warehouse.related.contains("model.goods.hammers"))
    }

    @MainActor
    func testColopediaAndTerrainFitSmallPanelsWithPopulatedContents() throws {
        let game = Game()
        try game.load(from: XMLDecoder.decode(InteractionRepairTests.gameXML))
        let state = GameState()
        state.phase = .inGame
        state.installGame(game)
        state.selectUnit("field-worker", onTile: "tile-2-2")
        for category in ColopediaCategory.allCases {
            let entry = try XCTUnwrap(ColopediaCatalog.classicEntries.first { $0.category == category })
            try checkPanel(ColopediaView(selectedEntryId: entry.id).environment(state),
                           name: "colopedia-\(category)", width: 900, height: 620)
        }
        try checkPanel(ColopediaView(selectedEntryId: "model.unit.freeColonist").environment(state)
            .frame(width: 700, height: 420),
                       name: "colopedia-minimum", width: 700, height: 420)
        try checkPanel(ColonyTerrainView(
            fields: state.selectedColonyTerrain, selectedWorkerId: state.selectedColonyWorkerUnitId,
            canManage: true, onAssign: { state.assignSelectedColonyWorker(to: $0) }
        ), name: "colony-terrain", width: 600, height: 370)
        let colony = try XCTUnwrap(state.selectedColony)
        try checkPanel(ColonyPanelView(
            colony: colony, ownerName: "Alice", units: state.selectedColonyUnits.filter { state.canUnitWorkInColony($0) },
            canManage: true, selectedWorkerUnitId: state.selectedColonyWorkerUnitId,
            population: state.colonyPopulation(colony), terrainFields: state.selectedColonyTerrain,
            onSelectWorker: { state.selectUnit($0, onTile: colony.tileId) },
            onChangeWorkType: { _ in }, onChangeWorkImprovementType: { _ in },
            onClearSpeciality: {}, onAssignTeacher: { _ in }, onClearTeacher: {},
            onWorkAtLocation: { location, workType in
                state.assignSelectedColonyWorker(to: location, workTypeId: workType)
            }, onRenameColony: { _ in },
            onPayForBuilding: {}, onSetGoodsLevel: { _ in },
            workLocationCandidates: state.selectedColonyWorkLocationCandidates,
            buildingWorkplaces: state.selectedColonyBuildingWorkplaces,
            workTypeCandidates: state.selectedColonyWorkTypeCandidates, goodsCandidates: state.colonyGoodsCandidates,
            onAbandonColony: {}, canAbandonColony: false, onSetBuildQueue: { _ in },
            onPutOutsideColony: {}, canPutOutsideColony: false, selectedCarrierId: nil,
            onLoadGoods: { _, _ in }, onUnloadGoods: { _, _ in }, section: .workers
        ), name: "colony-workers-interactive", width: 760, height: 600)
    }

    @MainActor
    func testBuildingWorkplaceSummaryAndPanel() throws {
        let game = Game()
        try game.load(from: XMLDecoder.decode(InteractionRepairTests.gameXML))
        let state = GameState()
        state.phase = .inGame
        state.installGame(game)
        state.selectUnit("building-worker", onTile: "tile-2-2")

        let workplace = try XCTUnwrap(state.selectedColonyBuildingWorkplaces.first)
        XCTAssertEqual(workplace.id, "building-1", "The building instance, not its type, is the workplace identity")
        XCTAssertEqual(workplace.workers.map(\.id), ["building-worker"])
        XCTAssertEqual(workplace.capacity, 3)
        XCTAssertEqual(workplace.goodsTypeId, "model.goods.hammers")
        XCTAssertEqual(workplace.productionPerTurn, 3)

        let colony = try XCTUnwrap(state.selectedColony)
        try checkPanel(ColonyPanelView(
            colony: colony,
            ownerName: "Alice",
            units: state.selectedColonyUnits.filter { state.canUnitWorkInColony($0) },
            canManage: true,
            selectedWorkerUnitId: state.selectedColonyWorkerUnitId,
            terrainFields: state.selectedColonyTerrain,
            onSelectWorker: { state.selectUnit($0, onTile: colony.tileId) },
            onChangeWorkType: { _ in },
            onChangeWorkImprovementType: { _ in },
            onClearSpeciality: {},
            onAssignTeacher: { _ in },
            onClearTeacher: {},
            onWorkAtLocation: { _, _ in },
            onRenameColony: { _ in },
            onPayForBuilding: {},
            onSetGoodsLevel: { _ in },
            workLocationCandidates: state.selectedColonyWorkLocationCandidates,
            buildingWorkplaces: state.selectedColonyBuildingWorkplaces,
            onAbandonColony: {},
            canAbandonColony: false,
            onSetBuildQueue: { _ in },
            onPutOutsideColony: {},
            canPutOutsideColony: false,
            selectedCarrierId: nil,
            onLoadGoods: { _, _ in },
            onUnloadGoods: { _, _ in },
            section: .workers
        ), name: "colony-worker-and-workplace-layout", width: 900, height: 720)
    }

    @MainActor
    func testTeachingBuildingIsAssignableAndOnlyQualifiedTeachersAreListed() throws {
        let xml = InteractionRepairTests.gameXML
            .replacingOccurrences(
                of: "<unit-type id=\"model.unit.freeColonist\" extends=\"colonist\"/>",
                with: """
                <unit-type id="model.unit.freeColonist" extends="colonist" skill="0"/>
                <unit-type id="model.unit.expertFarmer" extends="colonist" skill="1"/>
                """
            )
            .replacingOccurrences(
                of: "<building-type id=\"model.building.carpenterHouse\">",
                with: """
                <building-type id="model.building.schoolhouse" workplaces="1"
                               minimum-skill="1" maximum-skill="1">
                  <ability id="model.ability.teach" value="true"/>
                </building-type>
                <building-type id="model.building.carpenterHouse">
                """
            )
            .replacingOccurrences(
                of: "<colonyTile id=\"field-west\" workTile=\"tile-1-2\"/>",
                with: """
                <colonyTile id="field-west" workTile="tile-1-2">
                  <unit id="potential-teacher" unitType="model.unit.expertFarmer"
                        owner="player-1" location="field-west" movesLeft="0"/>
                  <unit id="unqualified-teacher" unitType="model.unit.freeColonist"
                        owner="player-1" location="field-west" movesLeft="0"/>
                </colonyTile>
                """
            )
            .replacingOccurrences(
                of: "</colony>",
                with: """
                <building id="schoolhouse-1" buildingType="model.building.schoolhouse"/>
                </colony>
                """
            )

        let game = Game()
        try game.load(from: XMLDecoder.decode(xml))
        let state = GameState()
        state.phase = .inGame
        state.installGame(game)
        state.selectUnit("potential-teacher", onTile: "tile-2-2")

        XCTAssertTrue(state.selectedColonyWorkLocationCandidates.contains {
            $0.id == "schoolhouse-1" && $0.label == "Schule"
        })
        XCTAssertTrue(state.selectedColonyTeacherCandidates.contains {
            $0.id == "potential-teacher"
        })
        XCTAssertFalse(state.selectedColonyTeacherCandidates.contains {
            $0.id == "unqualified-teacher"
        })
    }

    @MainActor
    func testEveryEuropeAndColonySectionFitsSmallPanel() throws {
        let state = try makeState()
        try state.game?.applyUpdate(XMLDecoder.decode("""
        <update>
          <player id="player-1" username="Alice" gold="600" immigrationRequired="12">
            <europe id="europe-1" owner="player-1" recruitPrice="120">
              \(String(repeating: "<recruit id=\"model.unit.freeColonist\" number=\"1\"/>", count: 40))
              <unitPrice unitType="model.unit.caravel" price="1000"/>
              <unitPrice unitType="model.unit.artillery" price="500"/>
              <unit id="ship-port" unitType="model.unit.caravel" name="Hoffnung" owner="player-1" location="europe-1">
                <goodsContainer><storedGoods><goods type="model.goods.horses" amount="50"/></storedGoods></goodsContainer>
              </unit>
              <unit id="dock-unit" unitType="model.unit.freeColonist" owner="player-1" location="europe-1"/>
            </europe>
            <market><marketData goods-type="model.goods.horses" amount="100" initialPrice="3"/>
              <marketData goods-type="model.goods.tools" amount="150" initialPrice="4" arrears="200"/>
            </market>
          </player>
          <tile id="tile-0-0" x="0" y="0" type="model.tile.mixedForest"/>
          <tile id="tile-1-0" x="1" y="0" type="model.tile.ocean" style="17"/>
          <tile id="tile-0-1" x="0" y="1" type="model.tile.hills"/>
        </update>
        """))
        state.gameUpdateID += 1
        XCTAssertEqual(state.europeCarrierUnits.first?.id, "ship-port")
        XCTAssertEqual(state.europeCarrierUnits.first?.goods["model.goods.horses"], 50)
        state.selectUnit("unit-1", onTile: "tile-2-2")
        let colony = try XCTUnwrap(state.game?.colonies["colony-1"])
        for section in EuropePanelView.EuropeSection.allCases {
            try checkPanel(EuropePanelView(section: section).environment(state),
                           name: "europe-\(section)", width: 760, height: 480)
            try checkPanel(EuropePanelView(section: section).environment(state),
                           name: "europe-\(section)-600", width: 600, height: 480)
        }
        for section in ColonyPanelView.ColonySection.allCases {
            let panel = ColonyPanelView(
                colony: colony, ownerName: "Alice", units: state.selectedColonyUnits,
                canManage: true, selectedWorkerUnitId: "unit-1",
                population: state.colonyPopulation(colony),
                onChangeWorkType: { _ in }, onChangeWorkImprovementType: { _ in },
                onClearSpeciality: {}, onAssignTeacher: { _ in }, onClearTeacher: {},
                onWorkAtLocation: { _, _ in }, onRenameColony: { _ in }, onPayForBuilding: {},
                onSetGoodsLevel: { _ in },
                workTypeCandidates: [("model.goods.food", "Nahrung"), ("model.goods.tools", "Werkzeuge")],
                onAbandonColony: {}, canAbandonColony: false,
                onSetBuildQueue: { _ in }, onPutOutsideColony: {}, canPutOutsideColony: false,
                selectedCarrierId: "carrier-1",
                carrierCandidates: [("carrier-1", "Wagenzug"), ("carrier-2", "Schiff")],
                onSelectCarrier: { _ in },
                onLoadGoods: { _, _ in }, onUnloadGoods: { _, _ in },
                buildableCandidates: [("model.building.warehouse", "Lagerhaus")],
                currentBuildQueue: ["model.building.warehouse", "model.building.carpenterHouse"],
                buildingLabel: { GameLabels.name($0) },
                storedGoods: [("model.goods.food", "Nahrung", 100), ("model.goods.tools", "Werkzeuge", 20)],
                carrierGoods: [("model.goods.food", "Nahrung", 100), ("model.goods.tools", "Werkzeuge", 40)],
                buildTargetLabel: "Lagerhaus",
                estimatedProduction: [
                    ColonyGoodsFlow(
                        id: "model.goods.grain", label: "Getreide",
                        produced: 8, consumed: 5, explanation: ""
                    ),
                    ColonyGoodsFlow(
                        id: "model.goods.tools", label: "Werkzeuge",
                        produced: 4, consumed: 1, explanation: ""
                    )
                ],
                growthETATurns: 3,
                section: section
            )
            try checkPanel(panel, name: "colony-\(section)", width: 760, height: 480)
            try checkPanel(panel, name: "colony-\(section)-640", width: 640, height: 480)
        }
        state.selectedUnitId = nil
        state.selectedTileId = "tile-2-2"
        state.errorMessage = "Ziel kann nicht erreicht werden. Diese lange Meldung muss auch bei schmaler Ansicht vollständig lesbar bleiben."
        try checkPanel(GameView().environment(state), name: "game-unselected-error-900", width: 900, height: 620)
        state.errorMessage = nil
        state.selectUnit("unit-1", onTile: "tile-2-2")
        for size in [CGSize(width: 900, height: 620), CGSize(width: 1200, height: 800)] {
            try checkPanel(GameView().environment(state), name: "game-\(Int(size.width))",
                           width: size.width, height: size.height)
        }
    }

    @MainActor
    private func checkPanel<V: View>(_ panel: V, name: String, width: Double, height: Double) throws {
        let host = NSHostingView(rootView: panel.environment(\.colorScheme, .dark))
        host.frame = CGRect(x: 0, y: 0, width: width, height: height)
        host.layoutSubtreeIfNeeded()
        XCTAssertLessThanOrEqual(host.fittingSize.width, width, name)
        XCTAssertLessThanOrEqual(host.fittingSize.height, height, name)
        if let directory = ProcessInfo.processInfo.environment["FREECOL_UI_SNAPSHOTS"] {
            let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.appearance = NSAppearance(named: .darkAqua)
            window.contentView = host
            defer { window.close() }
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
            let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds), name)
            host.cacheDisplay(in: host.bounds, to: bitmap)
            XCTAssertGreaterThanOrEqual(bitmap.pixelsWide, Int(width))
            XCTAssertGreaterThanOrEqual(bitmap.pixelsHigh, Int(height))
            let url = URL(fileURLWithPath: directory, isDirectory: true)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            try png.write(to: url.appendingPathComponent("\(name).png"))
        }
    }

    @MainActor
    func testModelUpdatesInvalidateTurnAndUnitControls() async throws {
        let state = try makeState()
        state.selectUnit("unit-1", onTile: "tile-2-2")
        let turnChanged = expectation(description: "Turn controls observe model revisions")
        let unitChanged = expectation(description: "Unit controls observe model revisions")
        let playerChanged = expectation(description: "Player displays observe model revisions")
        withObservationTracking {
            XCTAssertTrue(state.canEndTurn)
        } onChange: {
            turnChanged.fulfill()
        }
        withObservationTracking {
            XCTAssertEqual(state.selectedUnit?.movesLeft, 3)
        } onChange: {
            unitChanged.fulfill()
        }
        withObservationTracking {
            XCTAssertNotNil(state.localPlayer)
        } onChange: {
            playerChanged.fulfill()
        }
        try state.game?.applyUpdate(XMLDecoder.decode("""
        <update><unit id="unit-1" owner="player-1" unitType="model.unit.freeColonist"
          location="tile-2-2" movesLeft="0" state="ACTIVE"/></update>
        """))
        state.game?.currentPlayerId = "player-2"
        state.gameUpdateID += 1
        await fulfillment(of: [turnChanged, unitChanged, playerChanged], timeout: 1)
        XCTAssertFalse(state.canEndTurn)
        XCTAssertFalse(state.canChooseMoveDestination)
        XCTAssertEqual(state.selectedUnit?.movesLeft, 0)

        let nextTurn = expectation(description: "Controls observe the next local turn")
        withObservationTracking {
            XCTAssertFalse(state.canEndTurn)
            XCTAssertFalse(state.canChooseMoveDestination)
        } onChange: {
            nextTurn.fulfill()
        }
        try state.game?.applyUpdate(XMLDecoder.decode("""
        <update><unit id="unit-1" owner="player-1" unitType="model.unit.freeColonist"
          location="tile-2-2" movesLeft="3" state="ACTIVE"/></update>
        """))
        state.game?.currentPlayerId = "player-1"
        state.gameUpdateID += 1
        await fulfillment(of: [nextTurn], timeout: 1)
        XCTAssertTrue(state.canEndTurn)
        XCTAssertTrue(state.canChooseMoveDestination)
    }

    @MainActor
    func testDisabledMoveReasonAndDisplayedShortcutsUseRegisteredSources() throws {
        let state = try makeState()
        state.selectUnit("unit-1", onTile: "tile-2-2")
        XCTAssertTrue(state.canChooseMoveDestination)
        XCTAssertNil(state.selectedUnitMoveDisabledReason)

        try state.game?.applyPartial(XMLDecoder.decode("""
        <partial id="unit-1" movesLeft="0"/>
        """))
        state.gameUpdateID += 1
        XCTAssertFalse(state.canChooseMoveDestination)
        XCTAssertEqual(state.selectedUnitMoveDisabledReason, "Diese Einheit hat keine Bewegungspunkte mehr.")

        let shortcuts = try XCTUnwrap(state.keyboardShortcutsManager).shortcuts
        XCTAssertEqual(shortcuts.first(where: { $0.description == "Kolonie bauen" })?.fullDisplay, "b")
        XCTAssertEqual(shortcuts.first(where: { $0.description == "Warten / Überspringen" })?.fullDisplay, "w")
        XCTAssertEqual(shortcuts.first(where: { $0.description == "Nächste Einheit auswählen" })?.fullDisplay, "n")
        XCTAssertEqual(shortcuts.first(where: { $0.description == "Fernkampf" })?.fullDisplay, "⇧t")
        XCTAssertFalse(shortcuts.contains(where: { $0.description == "Bewegen" }),
                       "Das Einheitenpanel darf kein nicht registriertes Bewegungskürzel anzeigen")
    }

    @MainActor
    func testUnresolvableUnitLocationShowsSpecificMoveError() throws {
        let state = try makeState()
        let game = try XCTUnwrap(state.game)
        try game.applyPartial(XMLDecoder.decode("""
        <partial id="unit-1" location="unknown-location" movesLeft="3" state="ACTIVE"/>
        """))
        state.selectUnit("unit-1", onTile: "tile-2-2")

        state.moveSelectedUnitTo(destinationTileId: "tile-3-2")

        XCTAssertEqual(state.errorMessage,
                       "Diese Einheit befindet sich nicht auf einer gültigen Kartenposition.")
    }

    @MainActor
    func testActiveUnitAtResolvableColonyLocationCanMove() throws {
        let state = try makeState()
        let game = try XCTUnwrap(state.game)
        try game.applyPartial(XMLDecoder.decode("""
        <partial id="unit-1" location="colony-1" movesLeft="1" state="ACTIVE"/>
        """))
        state.selectUnit("unit-1", onTile: "tile-2-2")

        XCTAssertEqual(state.selectedUnitTileId, "tile-2-2")
        XCTAssertTrue(state.canMoveSelectedUnitTo(destinationTileId: "tile-3-2"))
        XCTAssertNil(state.selectedUnitMoveDisabledReason)
    }

    @MainActor
    func testSettlementLabelsLayoutAtMultipleZoomLevelsAndCanBeHidden() throws {
        let state = try makeState()
        state.selectedUnitId = nil
        state.selectedTileId = "tile-2-2"
        state.showFogOfWar = true

        for zoom in [0.5, 1.0, 2.0, 5.0] {
            state.mapZoomScale = zoom
            try checkPanel(GameView().environment(state), name: "settlement-labels-\(zoom)",
                           width: 900, height: 620)
        }
        state.showSettlementLabels = false
        try checkPanel(GameView().environment(state), name: "settlement-labels-hidden",
                       width: 900, height: 620)
    }

    func testTileCentersAndBoundsMatchDrawingAtEveryZoom() throws {
        let game = try makeGame()
        let index = TileSpatialIndex(tiles: Array(game.tiles.values))
        for zoom in [0.5, 1, 2, 4, 5] {
            let width = 64 * zoom
            let height = 32 * zoom
            let canvas = MapGeometry.canvasSize(maxX: 4, maxY: 5, tileW: width, tileH: height)
            for tile in game.tiles.values {
                let center = MapGeometry.origin(x: tile.x, y: tile.y, tileW: width, tileH: height)
                XCTAssertEqual(index.hitTest(location: center, tileW: width, tileH: height)?.id, tile.id)
                XCTAssertTrue(canvas.width >= center.x + width / 2)
                XCTAssertTrue(canvas.height >= center.y + height / 2)
                let viewport = CGRect(x: center.x - 1, y: center.y - 1, width: 2, height: 2)
                let expected = Set(game.tiles.values.filter { candidate in
                    let origin = MapGeometry.origin(x: candidate.x, y: candidate.y, tileW: width, tileH: height)
                    return CGRect(x: origin.x - width / 2, y: origin.y - height / 2,
                                  width: width, height: height).intersects(viewport)
                }.map(\.id))
                XCTAssertEqual(Set(index.visibleTiles(in: viewport, tileW: width, tileH: height).map(\.id)), expected)
            }
        }
    }

    @MainActor
    func testAllEightNeighborsAreDrawnInTheirMovementDirections() throws {
        let state = GameState()
        let game = try makeGame()
        state.installGame(game)
        let expected: [String: CGPoint] = [
            "N": CGPoint(x: 0, y: -32), "NE": CGPoint(x: 32, y: -16),
            "E": CGPoint(x: 64, y: 0), "SE": CGPoint(x: 32, y: 16),
            "S": CGPoint(x: 0, y: 32), "SW": CGPoint(x: -32, y: 16),
            "W": CGPoint(x: -64, y: 0), "NW": CGPoint(x: -32, y: -16),
        ]
        for sourceID in ["tile-2-2", "tile-2-3"] {
            let source = try XCTUnwrap(game.tiles[sourceID])
            let origin = MapGeometry.origin(x: source.x, y: source.y, tileW: 64, tileH: 32)
            var directions = Set<String>()
            for target in game.tiles.values {
                guard let direction = state.attackDirection(fromTileId: sourceID, toTileId: target.id, in: game) else { continue }
                let targetOrigin = MapGeometry.origin(x: target.x, y: target.y, tileW: 64, tileH: 32)
                XCTAssertEqual(CGPoint(x: targetOrigin.x - origin.x, y: targetOrigin.y - origin.y), expected[direction])
                directions.insert(direction)
            }
            XCTAssertEqual(directions, Set(expected.keys))
        }
    }

    @MainActor
    func testInspectingDestinationPreservesUnitAndStackCycling() throws {
        let state = try makeState()
        state.selectMapTile("tile-2-2")
        XCTAssertEqual(state.selectedUnitId, "unit-1")
        state.selectMapTile("tile-2-2")
        XCTAssertEqual(state.selectedUnitId, "unit-2")
        state.selectMapTile("tile-3-2")
        XCTAssertEqual(state.selectedUnitId, "unit-2")
        XCTAssertEqual(state.selectedTileId, "tile-3-2")
        XCTAssertTrue(state.canMoveSelectedUnitTo(destinationTileId: "tile-3-2"))
    }

    @MainActor
    func testColonyCanBeReopenedWithSelectedUnit() throws {
        let state = try makeState()
        state.selectUnit("unit-1", onTile: "tile-2-2")
        state.selectMapTile("tile-2-2", openColony: true)
        XCTAssertEqual(state.selectedUnitId, "unit-1")
        XCTAssertEqual(state.selectedColony?.id, "colony-1")
        XCTAssertTrue(state.showColonyPanel)
        state.closeColonyPanel()
        state.selectMapTile("tile-2-2", openColony: true)
        XCTAssertTrue(state.showColonyPanel)
        state.closeColonyPanel()
        state.openColonyPanel(colonyId: "colony-1")
        XCTAssertTrue(state.showColonyPanel)
    }

    @MainActor
    func testMoveModeCancellationAndTurnGuards() throws {
        let state = try makeState()
        state.selectUnit("unit-1", onTile: "tile-2-2")
        state.openTileActions("tile-3-2")
        state.beginChoosingMoveDestination()
        XCTAssertTrue(state.isChoosingMoveDestination)
        XCTAssertNil(state.tileActionTileId)
        state.cancelChoosingMoveDestination()
        XCTAssertFalse(state.isChoosingMoveDestination)
        state.game?.currentPlayerId = "player-2"
        state.beginChoosingMoveDestination()
        XCTAssertFalse(state.isChoosingMoveDestination)
        XCTAssertNotNil(state.errorMessage)
        state.game?.currentPlayerId = "player-1"
        state.selectUnit("unit-cargo", onTile: "tile-2-2")
        XCTAssertFalse(state.canChooseMoveDestination)
        state.selectUnit("unit-1", onTile: "tile-2-2")
        try state.game?.applyUpdate(XMLDecoder.decode("""
        <update><unit id="unit-1" movesLeft="0"/></update>
        """))
        XCTAssertFalse(state.canChooseMoveDestination)
    }

    @MainActor
    func testMoveModeMovesUnitThroughLocalConnection() async throws {
        let state = GameState()
        defer { state.disconnect() }
        state.startLocal(userName: "Alice", nationId: "model.nation.dutch")
        let deadline = Date().addingTimeInterval(5)
        while state.phase != .inGame, Date() < deadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertEqual(state.phase, .inGame)
        let game = try makeGame()
        state.installGame(game)
        state.selectUnit("unit-1", onTile: "tile-2-2")
        state.beginChoosingMoveDestination()
        state.selectMapTile("tile-3-2")
        XCTAssertFalse(state.isChoosingMoveDestination)
        let moveDeadline = Date().addingTimeInterval(3)
        while game.units["unit-1"]?.location != "tile-3-2", state.errorMessage == nil, Date() < moveDeadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertEqual(game.units["unit-1"]?.location, "tile-3-2")
        XCTAssertEqual(state.selectedUnitId, "unit-1")
        XCTAssertEqual(state.selectedTileId, "tile-3-2")
        XCTAssertNil(state.errorMessage)
    }

    @MainActor
    func testEuropeCanCloseAndSessionResetClearsInteractionState() throws {
        let state = try makeState()
        state.openEuropePanel()
        XCTAssertTrue(state.showEuropePanel)
        state.closeEuropePanel()
        XCTAssertFalse(state.showEuropePanel)
        state.selectUnit("unit-1", onTile: "tile-2-2")
        state.beginChoosingMoveDestination()
        state.openEuropePanel()
        state.disconnect()
        XCTAssertFalse(state.isChoosingMoveDestination)
        XCTAssertFalse(state.showEuropePanel)
        XCTAssertFalse(state.showColonyPanel)
    }

    @MainActor
    func testEuropeLayoutHasBoundedHeightWithLongContent() throws {
        let state = try makeState()
        let host = NSHostingView(rootView: EuropePanelView().environment(state))
        host.frame = CGRect(x: 0, y: 0, width: 600, height: 400)
        host.layoutSubtreeIfNeeded()
        XCTAssertLessThanOrEqual(host.fittingSize.height, 760)
        XCTAssertLessThanOrEqual(host.fittingSize.width, 1000)
        XCTAssertGreaterThanOrEqual(host.fittingSize.height, 400)
    }

    @MainActor
    func testGameControlsFitMinimumWindow() throws {
        let state = try makeState()
        state.selectUnit("unit-1", onTile: "tile-2-2")
        let host = NSHostingView(rootView: GameView().environment(state))
        host.frame = CGRect(x: 0, y: 0, width: 900, height: 620)
        host.layoutSubtreeIfNeeded()
        XCTAssertLessThanOrEqual(host.fittingSize.width, 900)
        XCTAssertLessThanOrEqual(host.fittingSize.height, 620)
    }

    @MainActor
    func testServerEventsOverlayMapWithoutReducingItsSize() throws {
        let state = try makeState()
        let size = CGSize(width: 900, height: 620)

        func mapFrame() throws -> CGRect {
            let host = NSHostingView(rootView: GameView().environment(state))
            host.frame = CGRect(origin: .zero, size: size)
            host.layoutSubtreeIfNeeded()
            func findMap(in view: NSView) -> ClickCaptureNSView? {
                if let map = view as? ClickCaptureNSView { return map }
                return view.subviews.lazy.compactMap { findMap(in: $0) }.first
            }
            let map = try XCTUnwrap(findMap(in: host))
            return map.convert(map.bounds, to: host)
        }

        let originalFrame = try mapFrame()
        XCTAssertGreaterThan(originalFrame.height, 200)
        let types: [GameState.PendingServerDecisionType] = [
            .foundingFather, .newRegionName, .newLandName, .firstContact,
            .monarchAction, .indianDemand, .lootCargo, .fountainOfYouth,
            .scoutReport, .incite, .nativeTrade, .diplomacy,
        ]
        for type in types {
            state.pendingServerDecision = GameState.PendingServerDecision(
                type: type,
                rawPayload: [
                    "newLandName": "Neu-Amsterdam",
                    "newRegionName": "Neue Region",
                    "trade": "model.foundingFather.adamSmith",
                    "exploration": "model.foundingFather.henryHudson",
                    "military": "model.foundingFather.hernanCortes",
                    "political": "model.foundingFather.pocahontas",
                    "religious": "model.foundingFather.williamBrewster",
                ]
            )
            XCTAssertEqual(try mapFrame(), originalFrame, type.rawValue)
            try checkPanel(GameView().environment(state), name: "map-event-\(type.rawValue)",
                           width: size.width, height: size.height)
        }
        state.clearPendingDecision()
        XCTAssertEqual(try mapFrame(), originalFrame)
    }

    @MainActor
    func testFoundingFatherSelectionFitsMinimumWindowWithAllFiveOffers() throws {
        let state = try makeState()
        state.applySessionMessage(ParsedMessage(tag: "chooseFoundingFather", attributes: [
            "trade": "model.foundingFather.adamSmith",
            "exploration": "model.foundingFather.henryHudson",
            "military": "model.foundingFather.hernanCortes",
            "political": "model.foundingFather.pocahontas",
            "religious": "model.foundingFather.williamBrewster",
        ], children: []))
        XCTAssertEqual(state.pendingFoundingFathers.count, 5)
        XCTAssertEqual(state.pendingFoundingFathers.last?.fatherId, "model.foundingFather.williamBrewster")
        XCTAssertTrue(state.canRespondToPendingDecision())

        for width in [900.0, 1453.0] {
            let panel = FoundingFatherSelectionView(
                options: state.pendingFoundingFathers,
                canChoose: state.canRespondToPendingDecision(),
                onChoose: { _ in XCTFail("Layout must not choose a candidate.") }
            ).frame(width: width, height: 588)
            let host = NSHostingView(rootView: panel)
            // The panel uses the minimum-window height after its 16pt margins.
            host.frame = CGRect(x: 0, y: 0, width: width, height: 620)
            host.layoutSubtreeIfNeeded()
            XCTAssertEqual(host.fittingSize.height, 588)
            XCTAssertLessThanOrEqual(host.fittingSize.width, width)
            let renderer = ImageRenderer(content: panel)
            let image = try XCTUnwrap(renderer.nsImage)
            XCTAssertEqual(image.size.width, width)
            XCTAssertEqual(image.size.height, 588)
        }

        let gameHost = NSHostingView(rootView: GameView().environment(state))
        gameHost.frame = CGRect(x: 0, y: 0, width: 900, height: 620)
        gameHost.layoutSubtreeIfNeeded()
        XCTAssertLessThanOrEqual(gameHost.fittingSize.height, 620)
        XCTAssertLessThanOrEqual(gameHost.fittingSize.width, 900)
        state.game?.currentPlayerId = "player-2"
        XCTAssertFalse(state.canRespondToPendingDecision())
    }

    @MainActor
    func testMouseCaptureDistinguishesClickDoubleClickAndDrag() throws {
        let view = ClickCaptureNSView(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        var clicks = 0
        var doubleClicks = 0
        var drags = 0
        view.onLeftClick = { _ in clicks += 1 }
        view.onDoubleClick = { _ in doubleClicks += 1 }
        view.onDrag = { _ in drags += 1 }
        func event(_ type: NSEvent.EventType, x: Double, clickCount: Int = 1) throws -> NSEvent {
            try XCTUnwrap(NSEvent.mouseEvent(with: type, location: CGPoint(x: x, y: 80),
                                             modifierFlags: [], timestamp: 0, windowNumber: 0,
                                             context: nil, eventNumber: 0, clickCount: clickCount, pressure: 1))
        }
        view.mouseDown(with: try event(.leftMouseDown, x: 80))
        view.mouseDragged(with: try event(.leftMouseDragged, x: 81))
        view.mouseUp(with: try event(.leftMouseUp, x: 81))
        XCTAssertEqual(clicks, 1)
        XCTAssertEqual(drags, 0)
        view.mouseDown(with: try event(.leftMouseDown, x: 80, clickCount: 2))
        view.mouseUp(with: try event(.leftMouseUp, x: 80, clickCount: 2))
        XCTAssertEqual(doubleClicks, 1)
        XCTAssertEqual(clicks, 1)
        view.mouseDown(with: try event(.leftMouseDown, x: 80))
        view.mouseDragged(with: try event(.leftMouseDragged, x: 110))
        view.mouseUp(with: try event(.leftMouseUp, x: 110))
        XCTAssertEqual(drags, 1)
        XCTAssertEqual(clicks, 1)
        XCTAssertEqual(doubleClicks, 1)
    }

    @MainActor
    private func makeState() throws -> GameState {
        let state = GameState()
        state.phase = .inGame
        state.installGame(try makeGame())
        return state
    }

    private func makeGame() throws -> Game {
        let tiles = (0..<6).flatMap { y in
            (0..<5).map { x in
                "<tile id=\"tile-\(x)-\(y)\" x=\"\(x)\" y=\"\(y)\" type=\"model.tile.plains\"/>"
            }
        }.joined()
        let game = Game()
        try game.load(from: XMLDecoder.decode("""
        <game id="game-1" clientUserName="Alice" currentPlayer="player-1">
          <player id="player-1" username="Alice">
            <europe id="europe-1" owner="player-1" recruitPrice="120">
              \(String(repeating: "<recruit id=\"model.unit.freeColonist\" number=\"1\"/>", count: 40))
            </europe>
          </player>
          <player id="player-2" username="Bob"/>
          <map id="map-1" width="5" height="6">\(tiles)</map>
          <colony id="colony-1" name="Boston" owner="player-1" tile="tile-2-2" unitCount="2"/>
          <unit id="unit-1" owner="player-1" unitType="model.unit.freeColonist"
                location="tile-2-2" movesLeft="3" state="ACTIVE"/>
          <unit id="unit-2" owner="player-1" unitType="model.unit.freeColonist"
                location="tile-2-2" movesLeft="3" state="ACTIVE"/>
          <unit id="unit-cargo" owner="player-1" unitType="model.unit.freeColonist"
                location="unit-2" movesLeft="3" state="ACTIVE"/>
        </game>
        """))
        return game
    }
}

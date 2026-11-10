import AppKit
import SwiftUI
import XCTest
import FreeColGame
import FreeColProtocol
@testable import Novaloria

final class MapPresentationTests: XCTestCase {
    func testAdjacentTerritoriesMergeAcrossBothRowParities() throws {
        for row in [2, 3] {
            let stagger = row.isMultiple(of: 2) ? 0 : 1
            for (x, y) in [(2 + stagger, row - 1), (2 + stagger, row + 1),
                           (1 + stagger, row + 1), (1 + stagger, row - 1)] {
                let tiles = try [tile(x: 2, y: row), tile(x: x, y: y)]
                let borders = TerritoryBorders(tiles: tiles)
                let contours = try XCTUnwrap(borders.contoursByOwner["owner"])
                XCTAssertEqual(contours.count, 1)
                XCTAssertEqual(contours[0].count, 6, "The shared edge must not be drawn")
            }
        }
    }

    func testDifferentOwnersAndCornerTouchingRegionsStaySeparate() throws {
        let touching = TerritoryBorders(tiles: try [tile(x: 1, y: 2), tile(x: 2, y: 2)])
        XCTAssertEqual(touching.contoursByOwner["owner"]?.count, 2)
        XCTAssertEqual(touching.contoursByOwner["owner"]?.map(\.count).sorted(), [4, 4])

        let different = TerritoryBorders(tiles: try [
            tile(x: 1, y: 2), tile(x: 1, y: 3, owner: "other"),
        ])
        XCTAssertEqual(different.contoursByOwner["owner"]?.first?.count, 4)
        XCTAssertEqual(different.contoursByOwner["other"]?.first?.count, 4)

        var unexplored = try tile(x: 2, y: 2)
        unexplored.type = nil
        let hidden = TerritoryBorders(tiles: [unexplored, try tile(x: 2, y: 3, owner: nil)])
        XCTAssertTrue(hidden.contoursByOwner.isEmpty)
    }

    func testTerritoryContoursCloseWithHolesAndIrregularShapes() throws {
        // All subsets also cover concave corners, narrow connections and holes.
        let positions = (0..<3).flatMap { row in (0..<3).map { (x: $0, y: row) } }
        for mask in 1..<(1 << positions.count) {
            let tiles = try positions.enumerated().compactMap { index, position in
                mask & (1 << index) == 0 ? nil : try tile(x: position.x, y: position.y)
            }
            let contours = try XCTUnwrap(TerritoryBorders(tiles: tiles).contoursByOwner["owner"])
            var actualEdges = Set<String>()
            for contour in contours {
                XCTAssertGreaterThanOrEqual(contour.count, 4)
                for index in contour.indices {
                    let a = contour[index]
                    let b = contour[(index + 1) % contour.count]
                    XCTAssertEqual(abs(a.x - b.x), 1)
                    XCTAssertEqual(abs(a.y - b.y), 1)
                    XCTAssertTrue(actualEdges.insert(edgeKey(a, b)).inserted)
                }
            }
            var expectedEdges = Set<String>()
            for tile in tiles {
                let center = MapGeometry.origin(x: tile.x, y: tile.y, tileW: 2, tileH: 2)
                let vertices = [
                    CGPoint(x: center.x, y: center.y - 1),
                    CGPoint(x: center.x + 1, y: center.y),
                    CGPoint(x: center.x, y: center.y + 1),
                    CGPoint(x: center.x - 1, y: center.y),
                ]
                for index in vertices.indices {
                    let a = vertices[index]
                    let b = vertices[(index + 1) % vertices.count]
                    if expectedEdges.remove(edgeKey(b, a)) == nil {
                        expectedEdges.insert(edgeKey(a, b))
                    }
                }
            }
            XCTAssertEqual(actualEdges, expectedEdges, "Territory subset \(mask)")
        }
    }

    func testBorderPathUsesRoundedClosedContoursAndScalesWithZoom() throws {
        let borders = TerritoryBorders(tiles: try [tile(x: 1, y: 2), tile(x: 1, y: 3)])
        let path = borders.path(for: "owner", tileW: 64, tileH: 32)
        var curves = 0
        var closes = 0
        path.forEach {
            switch $0 {
            case .quadCurve: curves += 1
            case .closeSubpath: closes += 1
            default: break
            }
        }
        XCTAssertEqual(curves, 6)
        XCTAssertEqual(closes, 1)
        let enlarged = borders.path(for: "owner", tileW: 128, tileH: 64).boundingRect
        XCTAssertEqual(enlarged.width, path.boundingRect.width * 2, accuracy: 0.001)
        XCTAssertEqual(enlarged.height, path.boundingRect.height * 2, accuracy: 0.001)
    }

    func testEnclosedUnownedTileRetainsAnInnerBorder() throws {
        let tiles = try (0..<5).flatMap { y in
            try (0..<5).compactMap { x in
                x == 2 && y == 2 ? nil : try tile(x: x, y: y)
            }
        }
        let contours = try XCTUnwrap(TerritoryBorders(tiles: tiles).contoursByOwner["owner"])
        XCTAssertEqual(contours.count, 2)
        XCTAssertTrue(contours.contains { $0.count == 4 })
    }

    @MainActor
    func testColonyLabelsUseTheirOwnPopulationQueueAndAllRequiredGoods() throws {
        let state = try makeState()
        let game = try XCTUnwrap(state.game)
        var colony = try XCTUnwrap(game.colonies["colony"])
        state.selectedTileId = "tile-5-7"
        XCTAssertEqual(state.colonyPopulation(colony), 7)
        XCTAssertEqual(state.colonyEstimatedBuildTurns(colony), 3)
        XCTAssertEqual(state.colonyMapBuildLabel(colony),
                       "\(state.buildingDisplayName("model.building.warehouseExpansion")) 3")
        let other = try XCTUnwrap(game.colonies["other"])
        XCTAssertEqual(state.colonyEstimatedBuildTurns(other), 0)
        XCTAssertNil(state.colonyMapBuildLabel(other), "Foreign construction must not be shown")

        colony.goods["model.goods.tools"] = 6
        XCTAssertEqual(state.colonyEstimatedBuildTurns(colony), 2)
        colony.goods["model.goods.hammers"] = 12
        XCTAssertEqual(state.colonyEstimatedBuildTurns(colony), 0)
    }

    @MainActor
    func testBuildTimeAccountsForRecurringConsumptionAndSelectedColonyMatches() throws {
        let state = try makeState()
        let game = try XCTUnwrap(state.game)
        try game.applyUpdate(XMLDecoder.decode("""
        <update><unit id="consumer" owner="owner" unitType="model.unit.consumer" location="colony"/></update>
        """))
        state.gameUpdateID += 1
        state.selectedTileId = "tile-2-4"
        let colony = try XCTUnwrap(game.colonies["colony"])
        XCTAssertEqual(state.colonyEstimatedBuildTurns(colony), 6)
        XCTAssertEqual(state.selectedColonyEstimatedBuildTurns, 6)
        XCTAssertEqual(state.colonyMapBuildLabel(colony),
                       "\(state.buildingDisplayName("model.building.warehouseExpansion")) 6")
    }

    @MainActor
    func testUnknownAndEmptyConstructionQueuesAreExplicit() throws {
        let state = try makeState()
        let game = try XCTUnwrap(state.game)
        var colony = try XCTUnwrap(game.colonies["colony"])
        colony.buildings = []
        XCTAssertNil(state.colonyEstimatedBuildTurns(colony))
        XCTAssertEqual(state.colonyMapBuildLabel(colony),
                       "\(state.buildingDisplayName("model.building.warehouseExpansion")) ?")
        colony.buildQueue = []
        XCTAssertNil(state.colonyEstimatedBuildTurns(colony))
        XCTAssertEqual(state.colonyMapBuildLabel(colony),
                       L10n.text("Keine Bauliste festgelegt.", table: "ColonyPanelView"))
        colony.buildQueue = ["model.building.unknown"]
        XCTAssertNil(state.colonyEstimatedBuildTurns(colony))
    }

    @MainActor
    func testMapPresentationAtMultipleZooms() throws {
        let state = try makeState()
        for zoom in [0.5, 1, 2, 3, 5] {
            state.mapZoomScale = zoom
            let host = NSHostingView(rootView: MapView().environment(state))
            host.frame = CGRect(x: 0, y: 0, width: 1000, height: 650)
            let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = host
            defer { window.close() }
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
            XCTAssertLessThanOrEqual(host.fittingSize.width, 1000)
            if let directory = ProcessInfo.processInfo.environment["FREECOL_UI_SNAPSHOTS"] {
                let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                host.cacheDisplay(in: host.bounds, to: bitmap)
                let url = URL(fileURLWithPath: directory, isDirectory: true)
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                    .write(to: url.appendingPathComponent("colony-map-\(zoom).png"))
            }
        }
    }

    private func edgeKey(_ a: CGPoint, _ b: CGPoint) -> String {
        "\(Int(a.x)),\(Int(a.y)):\(Int(b.x)),\(Int(b.y))"
    }

    private func tile(x: Int, y: Int, owner: String? = "owner") throws -> Tile {
        var attributes = ["x": String(x), "y": String(y), "type": "model.tile.plains"]
        attributes["owner"] = owner
        return try Tile(id: "\(x)-\(y)", attributes: attributes, children: [], game: Game())
    }

    @MainActor
    private func makeState() throws -> GameState {
        let tiles = (0..<14).flatMap { y in
            (0..<12).map { x in
                let owner = x < 5 && (2...8).contains(y) ? "owner" : (x >= 5 && y > 5 ? "foreign" : "")
                return """
                <tile id="tile-\(x)-\(y)" x="\(x)" y="\(y)" type="model.tile.plains" owner="\(owner)"/>
                """
            }
        }.joined()
        let game = Game()
        try game.load(from: XMLDecoder.decode("""
        <game id="game" clientUserName="Alice" currentPlayer="owner">
          <player id="owner" username="Alice" nationId="model.nation.dutch"/>
          <player id="foreign" username="Bob" nationId="model.nation.french"/>
          <map id="map" width="12" height="14">\(tiles)</map>
          <colony id="colony" name="Christina" owner="owner" tile="tile-2-4" unitCount="7">
            <buildQueueItem id="model.building.warehouseExpansion"/>
            <building id="carpenter" buildingType="model.building.carpenterHouse"/>
            <building id="smith" buildingType="model.building.blacksmithHouse"/>
            <goodsContainer><storedGoods><goods type="model.goods.hammers" amount="4"/></storedGoods></goodsContainer>
          </colony>
          <colony id="other" name="Boston" owner="foreign" tile="tile-5-7" unitCount="4">
            <buildQueueItem id="model.unit.caravel"/>
            <goodsContainer><storedGoods><goods type="model.goods.hammers" amount="10"/></storedGoods></goodsContainer>
          </colony>
          <freecol-specification id="spec">
            <goods-type id="model.goods.hammers" storable="false"/>
            <goods-type id="model.goods.tools"/>
            <building-type id="model.building.carpenterHouse">
              <production unattended="true"><output goods-type="model.goods.hammers" value="4"/></production>
            </building-type>
            <building-type id="model.building.blacksmithHouse">
              <production unattended="true"><output goods-type="model.goods.tools" value="2"/></production>
            </building-type>
            <building-type id="model.building.warehouseExpansion">
              <required-goods id="model.goods.hammers" value="12"/>
              <required-goods id="model.goods.tools" value="6"/>
            </building-type>
            <unit-type id="model.unit.caravel"><required-goods id="model.goods.hammers" value="10"/></unit-type>
            <unit-type id="model.unit.consumer"><consumes id="model.goods.tools" value="1"/></unit-type>
          </freecol-specification>
        </game>
        """))
        let state = GameState()
        state.phase = .inGame
        state.installGame(game)
        state.showFogOfWar = false
        return state
    }
}

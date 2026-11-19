import AppKit
import Foundation
import SwiftUI
import XCTest
import FreeColGame
import FreeColProtocol
@testable import Novaloria

final class MapPerformanceTests: XCTestCase {
    private final class ViewportCapture {
        var value: MapViewportInfo?
    }

    @MainActor
    func testAtlasMapJumpBenchmark() throws {
        guard ProcessInfo.processInfo.environment["NOVALORIA_MAP_BENCHMARK"] == "1" else {
            throw XCTSkip("Set NOVALORIA_MAP_BENCHMARK=1 to run the map benchmark.")
        }

        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let atlas = root.appendingPathComponent("Mods/NovaloriaAtlas", isDirectory: true)
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let mods = temporary.appendingPathComponent("data/mods", isDirectory: true)
        try FileManager.default.createDirectory(at: mods, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let fixture = mods.appendingPathComponent("NovaloriaAtlas", isDirectory: true)
        try FileManager.default.copyItem(at: atlas, to: fixture)
        let modID = "novaloria-benchmark-\(UUID().uuidString)"
        try "<mod id=\"\(modID)\"/>".write(
            to: fixture.appendingPathComponent("mod.xml"), atomically: true, encoding: .utf8
        )

        let defaults = UserDefaults.standard
        let installationKey = "freecol.javaInstallation"
        let modsKey = FreeColModSelection.storageKey
        let oldInstallation = defaults.object(forKey: installationKey)
        let oldMods = defaults.object(forKey: modsKey)
        defer {
            if let oldInstallation { defaults.set(oldInstallation, forKey: installationKey) }
            else { defaults.removeObject(forKey: installationKey) }
            if let oldMods { defaults.set(oldMods, forKey: modsKey) }
            else { defaults.removeObject(forKey: modsKey) }
            _ = ModImageCatalog.shared.currentSignature()
        }
        defaults.set(temporary.path, forKey: installationKey)
        let selection = try JSONEncoder().encode([modID])
        defaults.set(try XCTUnwrap(String(data: selection, encoding: .utf8)), forKey: modsKey)

        let cache = TileImageCache.shared
        XCTAssertNotNil(ModImageCatalog.shared.image(
            forResourceKeys: ["image.tile.model.tile.plains.center"], variationSeed: 0
        ), "Benchmark requires the Atlas mod, not the built-in fallback images")
        XCTAssertNotNil(cache.terrainImage(forType: "model.tile.plains", x: 0, y: 0))
        let lookupStart = DispatchTime.now().uptimeNanoseconds
        for index in 0..<200 {
            XCTAssertNotNil(cache.terrainImage(forType: "model.tile.plains", x: index % 20, y: index / 20))
        }
        let lookupMS = milliseconds(since: lookupStart)

        let coldTypes = ["arctic", "desert", "grassland", "marsh", "ocean",
                         "prairie", "savannah", "swamp", "tundra"]
        let coldStart = DispatchTime.now().uptimeNanoseconds
        for type in coldTypes {
            XCTAssertNotNil(ModImageCatalog.shared.image(
                forResourceKeys: ["image.tile.model.tile.\(type).center"], variationSeed: 0
            ))
        }
        let coldLookupMS = milliseconds(since: coldStart)

        let types = ["model.tile.plains", "model.tile.grassland", "model.tile.hills",
                     "model.tile.borealForest", "model.tile.ocean"]
        let tiles = (0..<80).flatMap { y in
            (0..<80).map { x in
                let type = types[(x + y) % types.count]
                return #"<tile id="t-\#(x)-\#(y)" x="\#(x)" y="\#(y)" type="\#(type)"/>"#
            }
        }.joined()
        let game = Game()
        try game.load(from: XMLDecoder.decode("""
        <game id="game" clientUserName="Alice" currentPlayer="owner">
          <player id="owner" username="Alice" nationId="model.nation.dutch"/>
          <map id="map" width="80" height="80">\(tiles)</map>
        </game>
        """))
        let state = GameState()
        state.phase = .inGame
        state.installGame(game)
        state.showFogOfWar = true
        state.mapZoomScale = 1
        let capture = ViewportCapture()
        let host = NSHostingView(rootView: MapView().environment(state)
            .onPreferenceChange(MapViewportKey.self) { capture.value = $0 })
        host.frame = CGRect(x: 0, y: 0, width: 1000, height: 650)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        defer { window.close() }
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)

        var samples: [Double] = []
        var cameraSamples: [Double] = []
        var snapshotSamples: [Double] = []
        for (x, y) in [(15, 20), (60, 55), (20, 55), (60, 20), (15, 20), (60, 55)] {
            let started = DispatchTime.now().uptimeNanoseconds
            state.requestMapScroll(to: "t-\(x)-\(y)")
            let deadline = Date().addingTimeInterval(30)
            repeat {
                _ = RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.01))
            } while state.requestedMapScrollTileId != nil && Date() < deadline
            XCTAssertNil(state.requestedMapScrollTileId, "Map did not consume the scroll request")
            cameraSamples.append(milliseconds(since: started))
            host.layoutSubtreeIfNeeded()
            let snapshotStart = DispatchTime.now().uptimeNanoseconds
            host.cacheDisplay(in: host.bounds, to: bitmap)
            snapshotSamples.append(milliseconds(since: snapshotStart))
            samples.append(milliseconds(since: started))
            let rect = try XCTUnwrap(capture.value?.visibleRect)
            XCTAssertTrue(rect.contains(MapGeometry.origin(x: x, y: y, tileW: 64, tileH: 32)))
        }
        let sorted = samples.sorted()
        let median = (sorted[2] + sorted[3]) / 2
        let cameraSorted = cameraSamples.sorted()
        let snapshotSorted = snapshotSamples.sorted()
        print(String(format: "MAP_BENCHMARK atlas_lookups_200_ms=%.2f atlas_cold_lookups_9_ms=%.2f jump_p50_ms=%.2f jump_p95_ms=%.2f camera_p50_ms=%.2f snapshot_p50_ms=%.2f samples=%@",
                     lookupMS, coldLookupMS, median, sorted[sorted.count - 1],
                     (cameraSorted[2] + cameraSorted[3]) / 2, (snapshotSorted[2] + snapshotSorted[3]) / 2,
                     samples.map { String(format: "%.2f", $0) }.joined(separator: ",")))
    }

    private func milliseconds(since start: UInt64) -> Double {
        Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
    }
}

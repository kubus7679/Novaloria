import Darwin
import AppKit
import XCTest
import FreeColProtocol
import NovaloriaClient
@testable import Novaloria

final class NewGameTests: XCTestCase {
    private func fixture() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        for folder in ["data/rules/classic", "data/rules/freecol", "data/strings", "data/base"] {
            try FileManager.default.createDirectory(at: directory.appendingPathComponent(folder), withIntermediateDirectories: true)
        }
        try Data().write(to: directory.appendingPathComponent("FreeCol.jar"))
        try """
        <freecol-specification id="classic">
          <unit-types><unit-type id="model.unit.freeColonist"/></unit-types>
          <roles><role id="model.role.default"/></roles>
          <options>
            <optionGroup id="difficultyLevels">
              <optionGroup id="model.difficulty.custom">
                <optionGroup id="model.difficulty.other">
                  <integerOption id="model.option.startingMoney" value="1000" minimumValue="0" maximumValue="5000"/>
                  <stringOption id="model.option.tileProduction" value="good">
                    <choice value="good"/><choice value="bad"/>
                  </stringOption>
                  <unitListOption id="model.option.immigrants" maximumNumber="999"/>
                </optionGroup>
              </optionGroup>
              <optionGroup id="model.difficulty.medium">
                <optionGroup id="model.difficulty.other">
                  <integerOption id="model.option.startingMoney" value="500"/>
                  <unitListOption id="model.option.immigrants">
                    <unitOption id="immigrant">
                      <unitType value="model.unit.freeColonist"/>
                      <role value="model.role.default"/><number value="1"/>
                    </unitOption>
                  </unitListOption>
                </optionGroup>
              </optionGroup>
            </optionGroup>
            <optionGroup id="gameOptions">
              <optionGroup id="gameOptions.map">
                <booleanOption id="model.option.fogOfWar" value="true"/>
                <percentageOption id="model.option.giftProbability" defaultValue="5"/>
                <textOption id="model.option.ages" defaultValue="1600,1700"/>
              </optionGroup>
            </optionGroup>
            <optionGroup id="mapGeneratorOptions">
              <optionGroup id="mapGeneratorOptions.landGenerator">
                <integerOption id="model.option.mapWidth" value="40" minimumValue="30" maximumValue="200"/>
                <selectOption id="model.option.landGeneratorType" defaultValue="0">
                  <selectValue value="0" label="Classic"/><selectValue value="1" label="Continent"/>
                </selectOption>
                <fileOption id="model.option.importFile" type="map"/>
              </optionGroup>
            </optionGroup>
          </options>
        </freecol-specification>
        """.write(to: directory.appendingPathComponent("data/rules/classic/specification.xml"), atomically: true, encoding: .utf8)
        try """
        <freecol-specification id="freecol" extends="classic">
          <options><optionGroup id="gameOptions"><optionGroup id="gameOptions.map">
            <booleanOption id="model.option.fogOfWar" defaultValue="false"/>
          </optionGroup></optionGroup></options>
        </freecol-specification>
        """.write(to: directory.appendingPathComponent("data/rules/freecol/specification.xml"), atomically: true, encoding: .utf8)
        try "model.option.fogOfWar.name=Fog of war\n"
            .write(to: directory.appendingPathComponent("data/strings/FreeColMessages.properties"), atomically: true, encoding: .utf8)
        try "model.option.fogOfWar.name=Kriegsnebel\n"
            .write(to: directory.appendingPathComponent("data/strings/FreeColMessages_de.properties"), atomically: true, encoding: .utf8)
        return directory
    }

    private func find(_ id: String, in node: ParsedMessage) -> ParsedMessage? {
        if node.attributes["id"] == id { return node }
        for child in node.children {
            if let found = find(id, in: child) { return found }
        }
        return nil
    }

    func testLoadsInheritedOptionsAndDifficultyConstraints() throws {
        let directory = try fixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        let config = try NewGameConfiguration.load(installation: directory, difficulty: .medium)
        XCTAssertEqual(config.values.count, 9)
        XCTAssertEqual(config.values["model.option.fogOfWar"], "false")
        XCTAssertEqual(config.values["model.option.startingMoney"], "500")
        XCTAssertEqual(config.label("model.option.fogOfWar"), "Kriegsnebel")
        let gold = try XCTUnwrap(config.sections.flatMap(\.options).first { $0.id == "model.option.startingMoney" })
        XCTAssertEqual(gold.node.attributes["maximumValue"], "5000")
        let root = try XMLDecoder.decode(config.specificationXML())
        XCTAssertEqual(root.attributes["extends"], "freecol")
        XCTAssertEqual(find("model.option.startingMoney", in: root)?.attributes["value"], "500")
        XCTAssertNil(find("model.option.importFile", in: root)?.attributes["value"])
        XCTAssertEqual(find("model.option.immigrants", in: root)?.children.count, 1)
    }

    func testActivatingInstalledModAddsItsSpecificationToLocalGame() throws {
        let directory = try fixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        let modDirectory = directory.appendingPathComponent("data/mods/test-mod")
        try FileManager.default.createDirectory(at: modDirectory, withIntermediateDirectories: true)
        try #"<mod id="test-mod"/>"#
            .write(to: modDirectory.appendingPathComponent("mod.xml"), atomically: true, encoding: .utf8)
        try """
        <freecol-specification id="test-mod">
          <unit-types><unit-type id="model.unit.modColonist"/></unit-types>
        </freecol-specification>
        """.write(to: modDirectory.appendingPathComponent("specification.xml"), atomically: true, encoding: .utf8)
        try "mod.test-mod.name=Test-Mod\n"
            .write(to: modDirectory.appendingPathComponent("FreeColMessages.properties"), atomically: true, encoding: .utf8)

        let found = try XCTUnwrap(FreeColMod.discover(installation: directory).first { $0.id == "test-mod" })
        XCTAssertEqual(found.name, "Test-Mod")
        XCTAssertTrue(found.hasSpecification)

        let config = try NewGameConfiguration.load(
            installation: directory, difficulty: .medium, activeModIDs: ["test-mod"]
        )
        XCTAssertEqual(config.activeMods.map(\.id), ["test-mod"])
        let root = try XMLDecoder.decode(config.specificationXML())
        XCTAssertNotNil(find("model.unit.modColonist", in: root))
        let launch = try JavaServerLaunch.prepare(
            configuration: config, java: URL(fileURLWithPath: "/usr/bin/false"), port: 34569,
            name: "Mod test", seed: "", root: directory.appendingPathComponent("games")
        )
        let stagedMod = launch.directory.appendingPathComponent("freecol-data/mods/test-mod")
        XCTAssertTrue(FileManager.default.fileExists(atPath: stagedMod.appendingPathComponent("mod.xml").path))

        let withoutMod = try NewGameConfiguration.load(installation: directory, difficulty: .medium)
        XCTAssertNil(find("model.unit.modColonist", in: try XMLDecoder.decode(withoutMod.specificationXML())))
    }

    func testActiveGraphicModResolvesImageFromItsResourcesProperties() throws {
        let directory = try fixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        let modDirectory = directory.appendingPathComponent("data/mods/graphic-test")
        let imageDirectory = modDirectory.appendingPathComponent("images")
        try FileManager.default.createDirectory(at: imageDirectory, withIntermediateDirectories: true)
        try #"<mod id="graphic-test"/>"#
            .write(to: modDirectory.appendingPathComponent("mod.xml"), atomically: true, encoding: .utf8)
        try "image.unit.model.unit.modColonist=images/mod-colonist.png\n"
            .write(to: modDirectory.appendingPathComponent("resources.properties"), atomically: true, encoding: .utf8)
        let imageData = Data([0x4D, 0x4F, 0x44])
        try imageData.write(to: imageDirectory.appendingPathComponent("mod-colonist.png"))

        let defaults = UserDefaults.standard
        let oldInstallation = defaults.object(forKey: "freecol.javaInstallation")
        let oldMods = defaults.object(forKey: FreeColModSelection.storageKey)
        defer {
            if let oldInstallation { defaults.set(oldInstallation, forKey: "freecol.javaInstallation") }
            else { defaults.removeObject(forKey: "freecol.javaInstallation") }
            if let oldMods { defaults.set(oldMods, forKey: FreeColModSelection.storageKey) }
            else { defaults.removeObject(forKey: FreeColModSelection.storageKey) }
        }
        defaults.set(directory.path, forKey: "freecol.javaInstallation")
        defaults.set(#"["graphic-test"]"#, forKey: FreeColModSelection.storageKey)

        XCTAssertEqual(
            ModImageCatalog.shared.data(forResourceKeys: ["image.unit.model.unit.modColonist"]),
            imageData
        )
    }

    func testActiveGraphicArchiveResolvesImageFromZip() throws {
        let directory = try fixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        let modDirectory = directory.appendingPathComponent("archive-source")
        let imageDirectory = modDirectory.appendingPathComponent("images")
        try FileManager.default.createDirectory(at: imageDirectory, withIntermediateDirectories: true)
        try #"<mod id="graphic-archive-test"/>"#
            .write(to: modDirectory.appendingPathComponent("mod.xml"), atomically: true, encoding: .utf8)
        try "image.tile.model.tile.plains.center=images/plains.png\n"
            .write(to: modDirectory.appendingPathComponent("resources.properties"), atomically: true, encoding: .utf8)
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 3, pixelsHigh: 2,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )!
        bitmap.setColor(NSColor(deviceRed: 0.2, green: 0.6, blue: 0.4, alpha: 1), atX: 0, y: 0)
        let imageData = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        try imageData.write(to: imageDirectory.appendingPathComponent("plains.png"))

        let modsDirectory = directory.appendingPathComponent("data/mods")
        try FileManager.default.createDirectory(at: modsDirectory, withIntermediateDirectories: true)
        let archive = modsDirectory.appendingPathComponent("graphic-archive-test.zip")
        let zip = Process()
        zip.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        zip.arguments = ["-q", "-r", archive.path, "mod.xml", "resources.properties", "images"]
        zip.currentDirectoryURL = modDirectory
        try zip.run()
        zip.waitUntilExit()
        XCTAssertEqual(zip.terminationStatus, 0)

        let defaults = UserDefaults.standard
        let oldInstallation = defaults.object(forKey: "freecol.javaInstallation")
        let oldMods = defaults.object(forKey: FreeColModSelection.storageKey)
        defer {
            if let oldInstallation { defaults.set(oldInstallation, forKey: "freecol.javaInstallation") }
            else { defaults.removeObject(forKey: "freecol.javaInstallation") }
            if let oldMods { defaults.set(oldMods, forKey: FreeColModSelection.storageKey) }
            else { defaults.removeObject(forKey: FreeColModSelection.storageKey) }
        }
        defaults.set(directory.path, forKey: "freecol.javaInstallation")
        defaults.set(#"["graphic-archive-test"]"#, forKey: FreeColModSelection.storageKey)

        let asset = try XCTUnwrap(ModImageCatalog.shared.image(
            forResourceKeys: ["image.tile.model.tile.plains.center"]
        ))
        XCTAssertEqual(asset.data, imageData)
        XCTAssertEqual(asset.logicalSize, CGSize(width: 3, height: 2))
    }

    func testModImageCatalogPrefersLargestHiResAndSelectsVariationsDeterministically() throws {
        let directory = try fixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        let modDirectory = directory.appendingPathComponent("data/mods/hires-test")
        let images = modDirectory.appendingPathComponent("images/terrain")
        try FileManager.default.createDirectory(at: images, withIntermediateDirectories: true)
        try #"<mod id="hires-test"/>"#
            .write(to: modDirectory.appendingPathComponent("mod.xml"), atomically: true, encoding: .utf8)
        try "image.tile.model.tile.plains.center=images/terrain/center0.png\n"
            .write(to: modDirectory.appendingPathComponent("resources.properties"), atomically: true, encoding: .utf8)

        func png(width: Int, height: Int, color: NSColor) throws -> Data {
            let bitmap = NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
            )!
            for y in 0..<height {
                for x in 0..<width { bitmap.setColor(color, atX: x, y: y) }
            }
            return try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        }

        let base = try png(width: 8, height: 4, color: .red)
        let second = try png(width: 8, height: 4, color: .green)
        let hires = try png(width: 16, height: 8, color: .blue)
        try base.write(to: images.appendingPathComponent("center0.png"))
        try second.write(to: images.appendingPathComponent("center1.png"))
        try hires.write(to: images.appendingPathComponent("center0.size2.png"))
        let unrelatedImages = modDirectory.appendingPathComponent("images/other")
        try FileManager.default.createDirectory(at: unrelatedImages, withIntermediateDirectories: true)
        try second.write(to: unrelatedImages.appendingPathComponent("center2.png"))
        try second.write(to: unrelatedImages.appendingPathComponent("center0.size3.png"))

        let defaults = UserDefaults.standard
        let oldInstallation = defaults.object(forKey: "freecol.javaInstallation")
        let oldMods = defaults.object(forKey: FreeColModSelection.storageKey)
        defer {
            if let oldInstallation { defaults.set(oldInstallation, forKey: "freecol.javaInstallation") }
            else { defaults.removeObject(forKey: "freecol.javaInstallation") }
            if let oldMods { defaults.set(oldMods, forKey: FreeColModSelection.storageKey) }
            else { defaults.removeObject(forKey: FreeColModSelection.storageKey) }
        }
        defaults.set(directory.path, forKey: "freecol.javaInstallation")
        defaults.set(#"["hires-test"]"#, forKey: FreeColModSelection.storageKey)

        let baseAsset = try XCTUnwrap(ModImageCatalog.shared.image(
            forResourceKeys: ["image.tile.model.tile.plains.center"]
        ))
        XCTAssertEqual(baseAsset.data, hires)
        XCTAssertEqual(baseAsset.logicalSize, CGSize(width: 8, height: 4))
        let variation = try XCTUnwrap(ModImageCatalog.shared.image(
            forResourceKeys: ["image.tile.model.tile.plains.center"], variationSeed: 1
        ))
        XCTAssertEqual(variation.data, second)
        XCTAssertEqual(variation.logicalSize, CGSize(width: 8, height: 4))

        let cache = TileImageCache.shared
        let first = try XCTUnwrap(cache.terrainImage(forType: "model.tile.plains", x: 0, y: 0))
        let sameVariant = try XCTUnwrap(cache.terrainImage(forType: "model.tile.plains", x: 2, y: 0))
        let otherVariant = try XCTUnwrap(cache.terrainImage(forType: "model.tile.plains", x: 1, y: 0))
        XCTAssertTrue(first === sameVariant)
        XCTAssertFalse(first === otherVariant)
        XCTAssertEqual(ModImageCatalog.shared.image(
            forResourceKeys: ["image.tile.model.tile.plains.center"], variationSeed: -1
        )?.data, second)

        try FileManager.default.removeItem(at: images.appendingPathComponent("center1.png"))
        defaults.set("[]", forKey: FreeColModSelection.storageKey)
        XCTAssertNil(ModImageCatalog.shared.image(forResourceKeys: ["image.tile.model.tile.plains.center"]))
        defaults.set(#"["hires-test"]"#, forKey: FreeColModSelection.storageKey)
        XCTAssertEqual(ModImageCatalog.shared.image(
            forResourceKeys: ["image.tile.model.tile.plains.center"], variationSeed: 1
        )?.data, hires)
    }

    func testAtlasFiguresUseOneLogicalSizeAcrossProfessionsAndRoles() throws {
        let directory = try fixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        let mods = directory.appendingPathComponent("data/mods", isDirectory: true)
        try FileManager.default.createDirectory(at: mods, withIntermediateDirectories: true)
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let modID = "novaloria-figure-test-\(UUID().uuidString)"
        let installedAtlas = mods.appendingPathComponent(modID, isDirectory: true)
        try FileManager.default.copyItem(
            at: root.appendingPathComponent("Mods/NovaloriaAtlas", isDirectory: true),
            to: installedAtlas
        )
        try "<mod id=\"\(modID)\"/>".write(
            to: installedAtlas.appendingPathComponent("mod.xml"), atomically: true, encoding: .utf8
        )

        let defaults = UserDefaults.standard
        let oldInstallation = defaults.object(forKey: "freecol.javaInstallation")
        let oldMods = defaults.object(forKey: FreeColModSelection.storageKey)
        defer {
            if let oldInstallation { defaults.set(oldInstallation, forKey: "freecol.javaInstallation") }
            else { defaults.removeObject(forKey: "freecol.javaInstallation") }
            if let oldMods { defaults.set(oldMods, forKey: FreeColModSelection.storageKey) }
            else { defaults.removeObject(forKey: FreeColModSelection.storageKey) }
            _ = ModImageCatalog.shared.currentSignature()
        }
        defaults.set(directory.path, forKey: "freecol.javaInstallation")
        let selection = try JSONEncoder().encode([modID])
        defaults.set(try XCTUnwrap(String(data: selection, encoding: .utf8)), forKey: FreeColModSelection.storageKey)

        let figures: [(String, String?)] = [
            ("model.unit.freeColonist", nil),
            ("model.unit.expertFarmer", nil),
            ("model.unit.jesuitMissionary", nil),
            ("model.unit.masterBlacksmith", nil),
            ("model.unit.freeColonist", "model.role.pioneer"),
            ("model.unit.freeColonist", "model.role.soldier"),
            ("model.unit.freeColonist", "model.role.scout"),
            ("model.unit.freeColonist", "model.role.dragoon"),
        ]
        let logicalSize = CGSize(width: 88, height: 96)
        for (unit, role) in figures {
            let suffix = role.flatMap { $0.split(separator: ".").last }.map { ".\($0)" } ?? ""
            let key = "image.unit.\(unit)\(suffix)"
            let asset = try XCTUnwrap(ModImageCatalog.shared.image(forResourceKeys: [key]), key)
            XCTAssertEqual(asset.logicalSize, logicalSize, key)
            let bitmap = try XCTUnwrap(NSBitmapImageRep(data: asset.data), key)
            XCTAssertEqual(bitmap.pixelsWide, 176, key)
            XCTAssertEqual(bitmap.pixelsHigh, 192, key)
            XCTAssertEqual(TileImageCache.shared.unitImage(forUnitType: unit, role: role)?.size, logicalSize, key)
        }
    }

    func testActiveGraphicModResolvesMapLayersAndColopediaCategories() throws {
        let directory = try fixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        let modDirectory = directory.appendingPathComponent("data/mods/atlas-test")
        let imageDirectory = modDirectory.appendingPathComponent("images")
        try FileManager.default.createDirectory(at: imageDirectory, withIntermediateDirectories: true)
        try #"<mod id="atlas-test"/>"#
            .write(to: modDirectory.appendingPathComponent("mod.xml"), atomically: true, encoding: .utf8)
        let properties = """
        image.tile.model.tile.plains.center=images/terrain.png
        image.tileforest.model.tile.mixedForest=images/forest.png
        image.tileoverlay.model.tile.hills=images/hills.png
        image.tile.model.tile.beach.edge1=images/beach.png
        image.tile.model.improvement.river.s1000=images/river.png
        image.abovetile.model.tile.highSeas=images/cloud.png
        image.icon.model.goods.food=images/food.png
        image.tileitem.model.resource.fish=images/fish.png
        image.tile.model.improvement.plow=images/plow.png
        image.unit.model.unit.freeColonist.pioneer=images/pioneer.png
        """
        try properties.write(to: modDirectory.appendingPathComponent("resources.properties"),
                             atomically: true, encoding: .utf8)

        func png(width: Int, height: Int, color: NSColor) throws -> Data {
            let bitmap = NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
            )!
            for y in 0..<height {
                for x in 0..<width { bitmap.setColor(color, atX: x, y: y) }
            }
            return try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        }

        let files = [
            "terrain.png": (8, 4), "terrain.size2.png": (16, 8), "forest.png": (12, 8),
            "hills.png": (14, 10), "beach.png": (10, 5), "river.png": (16, 8),
            "cloud.png": (20, 15), "food.png": (7, 7), "fish.png": (9, 6),
            "plow.png": (11, 6), "pioneer.png": (13, 20),
        ]
        for (index, (name, size)) in files.enumerated() {
            let data = try png(width: size.0, height: size.1,
                               color: NSColor(deviceRed: CGFloat(index + 1) / 12, green: 0.4, blue: 0.2, alpha: 1))
            try data.write(to: imageDirectory.appendingPathComponent(name))
        }

        let defaults = UserDefaults.standard
        let oldInstallation = defaults.object(forKey: "freecol.javaInstallation")
        let oldMods = defaults.object(forKey: FreeColModSelection.storageKey)
        defer {
            if let oldInstallation { defaults.set(oldInstallation, forKey: "freecol.javaInstallation") }
            else { defaults.removeObject(forKey: "freecol.javaInstallation") }
            if let oldMods { defaults.set(oldMods, forKey: FreeColModSelection.storageKey) }
            else { defaults.removeObject(forKey: FreeColModSelection.storageKey) }
        }
        defaults.set(directory.path, forKey: "freecol.javaInstallation")
        defaults.set(#"["atlas-test"]"#, forKey: FreeColModSelection.storageKey)

        let cache = TileImageCache.shared
        XCTAssertEqual(cache.terrainImage(forType: "model.tile.plains", x: 2, y: 3)?.size, CGSize(width: 8, height: 4))
        XCTAssertEqual(cache.terrainOverlay(forType: "model.tile.mixedForest", x: 2, y: 3)?.size,
                       CGSize(width: 12, height: 8))
        XCTAssertEqual(cache.terrainOverlay(forType: "model.tile.hills", x: 1, y: 1)?.size,
                       CGSize(width: 14, height: 10))
        XCTAssertEqual(cache.beachImages(style: 16, x: 1, y: 2).first?.size, CGSize(width: 10, height: 5))
        XCTAssertEqual(cache.riverImage(forStyle: "1000")?.size, CGSize(width: 16, height: 8))
        XCTAssertEqual(cache.cloudImage(forX: 1, y: 2)?.size, CGSize(width: 20, height: 15))
        XCTAssertEqual(
            ModImageCatalog.shared.image(forResourceKeys: ["image.icon.model.goods.food"])?.logicalSize,
            CGSize(width: 7, height: 7)
        )
        XCTAssertEqual(cache.goodsImage(for: "model.goods.food")?.size, CGSize(width: 32, height: 32))

        let resource = ColopediaEntry(id: "model.resource.fish", category: .resources, title: "Fish",
                                      summary: "", text: "", facts: [], related: [], icon: nil)
        let improvement = ColopediaEntry(id: "model.improvement.plow", category: .improvements, title: "Plow",
                                         summary: "", text: "", facts: [], related: [], icon: nil)
        let role = ColopediaEntry(id: "model.role.pioneer", category: .roles, title: "Pioneer",
                                  summary: "", text: "", facts: [], related: [], icon: nil)
        XCTAssertEqual(cache.colopediaImage(for: resource)?.size, CGSize(width: 9, height: 6))
        XCTAssertEqual(cache.colopediaImage(for: improvement)?.size, CGSize(width: 11, height: 6))
        XCTAssertEqual(cache.colopediaImage(for: role)?.size, CGSize(width: 13, height: 20))
    }

    func testBuildingColopediaImageUsesActiveGraphicMod() throws {
        let directory = try fixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        let modDirectory = directory.appendingPathComponent("data/mods/building-graphic-test")
        let imageDirectory = modDirectory.appendingPathComponent("images")
        try FileManager.default.createDirectory(at: imageDirectory, withIntermediateDirectories: true)
        try #"<mod id="building-graphic-test"/>"#
            .write(to: modDirectory.appendingPathComponent("mod.xml"), atomically: true, encoding: .utf8)
        try "image.buildingicon.model.building.townHall=images/town-hall.png\n"
            .write(to: modDirectory.appendingPathComponent("resources.properties"), atomically: true, encoding: .utf8)
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )!
        bitmap.setColor(NSColor(deviceRed: 0.1, green: 0.7, blue: 0.4, alpha: 1), atX: 0, y: 0)
        let imageData = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        try imageData.write(to: imageDirectory.appendingPathComponent("town-hall.png"))

        let defaults = UserDefaults.standard
        let oldInstallation = defaults.object(forKey: "freecol.javaInstallation")
        let oldMods = defaults.object(forKey: FreeColModSelection.storageKey)
        defer {
            if let oldInstallation { defaults.set(oldInstallation, forKey: "freecol.javaInstallation") }
            else { defaults.removeObject(forKey: "freecol.javaInstallation") }
            if let oldMods { defaults.set(oldMods, forKey: FreeColModSelection.storageKey) }
            else { defaults.removeObject(forKey: FreeColModSelection.storageKey) }
        }
        defaults.set(directory.path, forKey: "freecol.javaInstallation")
        defaults.set(#"["building-graphic-test"]"#, forKey: FreeColModSelection.storageKey)

        let entry = ColopediaEntry(
            id: "model.building.townHall", category: .buildings, title: "Town Hall",
            summary: "", text: "", facts: [], related: [], icon: "model.building.townHall.png"
        )
        XCTAssertNotNil(TileImageCache.shared.colopediaImage(for: entry))
    }

    func testExportsAllValuesAndEscapesXML() throws {
        let directory = try fixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        var config = try NewGameConfiguration.load(installation: directory, difficulty: .medium)
        config.values["model.option.ages"] = "A&B \"<test>\"\n"
        config.values["model.option.mapWidth"] = "80"
        config.values["model.option.startingMoney"] = "3000"
        config.values["model.option.landGeneratorType"] = "1"
        let root = try XMLDecoder.decode(config.specificationXML())
        for option in config.sections.flatMap(\.options) {
            let exported = try XCTUnwrap(find(option.id, in: root))
            if !option.isXML && option.node.tag != "fileOption" {
                XCTAssertEqual(exported.attributes["value"], config.values[option.id], option.id)
            }
        }
    }

    func testImportsExportedOptionsAndRejectsInvalidValuesWithoutPartialChanges() throws {
        let directory = try fixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        var source = try NewGameConfiguration.load(installation: directory, difficulty: .medium)
        source.values["model.option.mapWidth"] = "80"
        source.values["model.option.fogOfWar"] = "false"
        let xml = try source.specificationXML().replacingOccurrences(
            of: "<integerOption id=\"model.option.mapWidth\"",
            with: "<rangeOption id=\"model.option.mapWidth\""
        ).replacingOccurrences(
            of: "<unitListOption id=\"model.option.immigrants\"",
            with: "<customListOption id=\"model.option.immigrants\""
        ).replacingOccurrences(of: "</unitListOption>", with: "</customListOption>")

        var imported = try NewGameConfiguration.load(installation: directory, difficulty: .medium)
        try imported.importOptions(from: xml)
        XCTAssertEqual(imported.values["model.option.mapWidth"], "80")
        XCTAssertEqual(imported.values["model.option.fogOfWar"], "false")
        XCTAssertEqual(imported.values["model.option.immigrants"], source.values["model.option.immigrants"])

        let invalidXML = xml.replacingOccurrences(of: "value=\"80\"", with: "value=\"999\"")
        let originalValues = imported.values
        XCTAssertThrowsError(try imported.importOptions(from: invalidXML))
        XCTAssertEqual(imported.values, originalValues)
    }

        func testImportsMainOptionsWhenModOptionsAppearFirst() throws {
                let directory = try fixture()
                defer { try? FileManager.default.removeItem(at: directory) }
                let modDirectory = directory.appendingPathComponent("data/mods/options-test")
                try FileManager.default.createDirectory(at: modDirectory, withIntermediateDirectories: true)
                try #"<mod id="options-test"/>"#
                        .write(to: modDirectory.appendingPathComponent("mod.xml"), atomically: true, encoding: .utf8)
                try """
                <freecol-specification id="options-test">
                    <options><optionGroup id="gameOptions">
                        <booleanOption id="model.option.fogOfWar" value="true"/>
                    </optionGroup></options>
                </freecol-specification>
                """.write(to: modDirectory.appendingPathComponent("specification.xml"), atomically: true, encoding: .utf8)

                var source = try NewGameConfiguration.load(installation: directory, difficulty: .medium,
                                                                                                     activeModIDs: ["options-test"])
                source.values["model.option.fogOfWar"] = "false"
                source.values["model.option.mapWidth"] = "80"
                let xml = try source.specificationXML()
                var imported = try NewGameConfiguration.load(installation: directory, difficulty: .medium,
                                                                                                         activeModIDs: ["options-test"])

                try imported.importOptions(from: xml)
                XCTAssertEqual(imported.values["model.option.fogOfWar"], "false")
                XCTAssertEqual(imported.values["model.option.mapWidth"], "80")
        }

    func testRejectsInvalidValuesRatherThanClampingOrDroppingThem() throws {
        let directory = try fixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        let base = try NewGameConfiguration.load(installation: directory, difficulty: .medium)
        for (id, value) in [
            ("model.option.mapWidth", "29"), ("model.option.mapWidth", "201"),
            ("model.option.mapWidth", "2147483648"), ("model.option.mapWidth", "abc"),
            ("model.option.startingMoney", "-1"), ("model.option.startingMoney", "5001"),
            ("model.option.giftProbability", "101"), ("model.option.fogOfWar", "yes"),
            ("model.option.landGeneratorType", "7"), ("model.option.tileProduction", "unknown"),
            ("model.option.importFile", "/no/such/map.fsg"),
            ("model.option.immigrants", "<broken"),
            ("model.option.immigrants", "<unitListOption id=\"wrong\"/>"),
            ("model.option.immigrants", """
            <unitListOption id="model.option.immigrants"><unitOption>
            <unitType value="unknown"/><role value="model.role.default"/><number value="1"/>
            </unitOption></unitListOption>
            """),
            ("model.option.immigrants", """
            <unitListOption id="model.option.immigrants"><unitOption>
            <unitType value="model.role.default"/><role value="model.unit.freeColonist"/><number value="1"/>
            </unitOption></unitListOption>
            """),
        ] {
            var config = base
            config.values[id] = value
            XCTAssertThrowsError(try config.specificationXML(), "\(id)=\(value)")
        }
        for value in ["30", "200"] {
            var config = base
            config.values["model.option.mapWidth"] = value
            XCTAssertNoThrow(try config.specificationXML())
        }
    }

    func testRejectsCyclicRulesAndMissingInstallation() throws {
        let directory = try fixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        try """
        <freecol-specification id="classic" extends="freecol"/>
        """.write(to: directory.appendingPathComponent("data/rules/classic/specification.xml"), atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try NewGameConfiguration.load(installation: directory, difficulty: .medium))
        XCTAssertThrowsError(try NewGameConfiguration.load(installation: directory.appendingPathComponent("missing"), difficulty: .medium))
    }

    func testJavaTranslationKeysUseWireValuesForStringChoices() throws {
        let node = try XMLDecoder.decode("""
        <stringOption id="model.option.tileProduction" value="high">
          <choice value="model.option.tileProduction.low.name"/>
          <choice value="model.option.tileProduction.high.name"/>
        </stringOption>
        """)
        let option = GameSetupOption(node: node)
        XCTAssertEqual(option.choices.map(\.value), ["low", "high"])
        XCTAssertEqual(try option.validatedNode(value: "high", unitTypeIDs: [], roleIDs: []).attributes["value"], "high")
        XCTAssertThrowsError(try option.validatedNode(value: "model.option.tileProduction.high.name", unitTypeIDs: [], roleIDs: []))
    }

    func testInvalidBoundsAndChronologyAreRejected() throws {
        for attributes in [
            "minimumValue=\"invalid\"", "minimumValue=\"10\" maximumValue=\"1\""
        ] {
            let option = GameSetupOption(node: try XMLDecoder.decode("""
            <integerOption id="test" value="5" \(attributes)/>
            """))
            XCTAssertThrowsError(try option.validatedNode(value: "5", unitTypeIDs: [], roleIDs: []))
        }
        let directory = try fixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        var config = try NewGameConfiguration.load(installation: directory, difficulty: .medium)
        config.values["model.option.startingYear"] = "1800"
        config.values["model.option.lastColonialYear"] = "1700"
        XCTAssertThrowsError(try config.specificationXML())
        config.values["model.option.lastColonialYear"] = "1800"
        XCTAssertNoThrow(try config.specificationXML())
        config.values["model.option.importFile"] = directory.path
        XCTAssertThrowsError(try config.specificationXML())
    }

    @MainActor
    func testInvalidNewGameDoesNotDisconnectExistingLobby() throws {
        let directory = try fixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        let config = try NewGameConfiguration.load(installation: directory, difficulty: .medium)
        let state = GameState()
        state.phase = .lobby
        XCTAssertThrowsError(try state.createJavaGame(configuration: config, java: URL(fileURLWithPath: "/usr/bin/false"),
                                                      port: 0, name: "Test", seed: ""))
        XCTAssertEqual(state.phase, .lobby)
        XCTAssertNil(state.hostedGameDirectory)
    }

    func testLaunchPersistsOptionsAndLeavesInstallationUnchanged() throws {
        let directory = try fixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        let config = try NewGameConfiguration.load(installation: directory, difficulty: .medium)
        let source = directory.appendingPathComponent("data/rules/freecol/specification.xml")
        let before = try Data(contentsOf: source)
        let launch = try JavaServerLaunch.prepare(configuration: config, java: URL(fileURLWithPath: "/usr/bin/false"),
                                                  port: 34567, name: "A & B; $(false)", seed: "42",
                                                  root: directory.appendingPathComponent("games"))
        XCTAssertEqual(try String(contentsOf: XCTUnwrap(launch.optionsFile)), try config.specificationXML())
        XCTAssertEqual(try Data(contentsOf: source), before)
        XCTAssertEqual(launch.arguments[try XCTUnwrap(launch.arguments.firstIndex(of: "--server-name")) + 1], "A & B; $(false)")
        XCTAssertTrue(launch.arguments.contains("--private"))
        XCTAssertTrue(launch.arguments.contains("127.0.0.1"))
        let europeanCountIndex = try XCTUnwrap(launch.arguments.firstIndex(of: "--europeans"))
        XCTAssertEqual(launch.arguments[europeanCountIndex + 1], "8")
        let spec = launch.directory.appendingPathComponent("freecol-data/rules/\(NewGameConfiguration.rulesID)/specification.xml")
        XCTAssertEqual(spec.resolvingSymlinksInPath(), launch.optionsFile)
        let savegame = directory.appendingPathComponent("autosave.fsg")
        try Data("save".utf8).write(to: savegame)
        let saveLaunch = try JavaServerLaunch.prepareSavegame(savegame, installation: directory, java: launch.executable,
                                                              port: 34568, name: "Geladen", root: directory.appendingPathComponent("games"))
        XCTAssertNil(saveLaunch.optionsFile)
        XCTAssertEqual(saveLaunch.arguments.suffix(2), ["--load-savegame", saveLaunch.directory.appendingPathComponent("savegame.fsg").path])
        XCTAssertFalse(saveLaunch.arguments.contains("--rules"))
        XCTAssertEqual(try Data(contentsOf: saveLaunch.directory.appendingPathComponent("savegame.fsg")), Data("save".utf8))
        XCTAssertThrowsError(try JavaServerLaunch.prepareSavegame(directory.appendingPathComponent("notes.txt"), installation: directory,
                                                                  java: launch.executable, port: 34568, name: "", root: directory))
        let manifest = try JSONSerialization.jsonObject(with: Data(contentsOf: launch.directory.appendingPathComponent("launch-arguments.json")))
        XCTAssertEqual(manifest as? [String], [launch.executable.path] + launch.arguments)
        for invalidPort in [0, 65536] {
            XCTAssertThrowsError(try JavaServerLaunch.prepare(configuration: config, java: launch.executable,
                                                              port: invalidPort, name: "", seed: "", root: directory))
        }
        XCTAssertThrowsError(try JavaServerLaunch.prepare(configuration: config, java: launch.executable,
                                                          port: 34567, name: "", seed: "abc", root: directory))
    }

    private func reservePort() throws -> (fd: Int32, port: Int) {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { throw NewGameError.invalid("socket failed") }
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        let result = withUnsafeMutablePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard result == 0 else { close(fd); throw NewGameError.invalid("bind failed") }
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let status = withUnsafeMutablePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(fd, $0, &length) }
        }
        guard status == 0 else { close(fd); throw NewGameError.invalid("getsockname failed") }
        return (fd, Int(UInt16(bigEndian: address.sin_port)))
    }

    @MainActor
    func testStartupFailureAndOccupiedPortAreExplicit() async throws {
        let directory = try fixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        let config = try NewGameConfiguration.load(installation: directory, difficulty: .medium)
        let reserved = try reservePort()
        let launch = try JavaServerLaunch.prepare(configuration: config, java: URL(fileURLWithPath: "/usr/bin/false"),
                                                  port: reserved.port, name: "", seed: "", root: directory.appendingPathComponent("games"))
        let server = LocalJavaServer()
        do {
            try await server.start(launch)
            XCTFail("Occupied port must fail")
        } catch { XCTAssertTrue(error.localizedDescription.contains("belegt")) }
        close(reserved.fd)
        do {
            try await server.start(launch)
            XCTFail("Non-Java process must fail")
        } catch { XCTAssertTrue(error.localizedDescription.contains("Status")) }
        server.stop()
    }

    @MainActor
    func testRealJavaServerConsumesConfiguration() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let path = environment["FREECOL_NEW_GAME_E2E_DIR"],
              let java = environment["FREECOL_JAVA_BIN"] else {
            throw XCTSkip("Set FREECOL_NEW_GAME_E2E_DIR and FREECOL_JAVA_BIN to test the installed Java server.")
        }
        var config = try NewGameConfiguration.load(installation: URL(fileURLWithPath: path), difficulty: .easy)
        for difficulty in GameDifficulty.allCases {
            let preset = try NewGameConfiguration.load(installation: config.installation, difficulty: difficulty)
            XCTAssertNoThrow(try preset.specificationXML(), difficulty.rawValue)
        }
        config.values["model.option.mapWidth"] = "50"
        config.values["model.option.mapHeight"] = "70"
        config.values["model.option.startingMoney"] = "4321"
        config.values["model.option.fogOfWar"] = "false"
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {
            if FileManager.default.fileExists(atPath: root.path) {
                try? FileManager.default.removeItem(at: root)
            }
        }
        let reserved = try reservePort()
        close(reserved.fd)
        let launch = try JavaServerLaunch.prepare(configuration: config, java: URL(fileURLWithPath: java),
                                                  port: reserved.port, name: "Swift option test", seed: "12345", root: root)
        let server = LocalJavaServer()
        defer { server.stop() }
        try await server.start(launch)
        let client = NovaloriaClient(host: "127.0.0.1", port: reserved.port)
        do {
            try await client.connect()
            let login = try await client.login(userName: "OptionTest", nationId: "model.nation.dutch")
            XCTAssertEqual(login.serverState, .preGame)
            let game = try XCTUnwrap(login.game)
            XCTAssertEqual(find("model.option.mapWidth", in: game)?.attributes["value"], "50")
            XCTAssertEqual(find("model.option.mapHeight", in: game)?.attributes["value"], "70")
            let difficulty = try XCTUnwrap(find(config.difficulty.optionID, in: game))
            XCTAssertEqual(find("model.option.startingMoney", in: difficulty)?.attributes["value"], "4321")
            XCTAssertEqual(find("model.option.fogOfWar", in: game)?.attributes["value"], "false")
            try await client.send(message: ParsedMessage(tag: "ready", attributes: ["value": "true"], children: []))
            try await client.send(message: ParsedMessage(tag: "requestLaunch", attributes: [:], children: []))
            let loop = Task { await client.startMessageLoop() }
            defer { loop.cancel() }
            for _ in 0..<300 {
                let game = await client.game
                if game.currentPlayerId != nil, game.map != nil {
                    XCTAssertEqual(game.map?.width, 50)
                    XCTAssertEqual(game.map?.height, 70)
                    XCTAssertEqual(game.players.values.first { $0.name == "OptionTest" }?.gold, 4321)
                    await client.disconnect()
                    server.stop()
                    try await server.waitForShutdown()
                    // Reusing the same port must work after stopping an owned server.
                    try await server.start(launch)
                    server.stop()
                    try await server.waitForShutdown()
                    return
                }
                try await Task.sleep(for: .milliseconds(100))
            }
            XCTFail("Configured Java game did not launch within 30 seconds.")
            await client.disconnect()
        } catch {
            await client.disconnect()
            throw error
        }
    }

    @MainActor
    func testSwedishSelectionIsAppliedBeforeStartingUnitsAreGenerated() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let path = environment["FREECOL_NEW_GAME_E2E_DIR"],
              let java = environment["FREECOL_JAVA_BIN"] else {
            throw XCTSkip("Set FREECOL_NEW_GAME_E2E_DIR and FREECOL_JAVA_BIN to test the installed Java server.")
        }

        let config = try NewGameConfiguration.load(installation: URL(fileURLWithPath: path), difficulty: .easy)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {
            if FileManager.default.fileExists(atPath: root.path) {
                try? FileManager.default.removeItem(at: root)
            }
        }
        let reserved = try reservePort()
        close(reserved.fd)
        let launch = try JavaServerLaunch.prepare(configuration: config, java: URL(fileURLWithPath: java),
                                                  port: reserved.port, name: "Swedish nation test", seed: "12345", root: root)
        let server = LocalJavaServer()
        let state = GameState()
        defer {
            state.disconnect()
            server.stop()
        }

        try await server.start(launch)
        state.connect(host: "127.0.0.1", port: reserved.port)
        try await waitUntil { state.phase == .login }

        state.login(userName: "SwedishTest", nationId: "model.nation.swedish")
        try await waitUntil { state.phase == .lobby || state.errorMessage != nil }
        XCTAssertNil(state.errorMessage)
        XCTAssertEqual(state.localPlayer?.nationId, "model.nation.swedish")
        XCTAssertTrue(state.isLocalPlayerAdmin)

        state.setReady(true)
        try await Task.sleep(for: .milliseconds(200))
        state.requestLaunch()
        try await waitUntil { state.phase == .inGame || state.errorMessage != nil }
        XCTAssertNil(state.errorMessage)

        let playerId = try XCTUnwrap(state.localPlayerId)
        let startingUnits = state.game?.units.values.filter { $0.owner == playerId } ?? []
        let startingUnitTypes = Set(startingUnits.compactMap(\.unitType))
        XCTAssertEqual(state.localPlayer?.nationId, "model.nation.swedish")
        XCTAssertEqual(state.localPlayer?.nationType, "model.nationType.building")
        XCTAssertEqual(state.game?.specification?.nationType(forNationId: "model.nation.swedish"), "model.nationType.building")
        XCTAssertTrue(startingUnitTypes.contains("model.unit.masterCarpenter"), "Starting units: \(startingUnitTypes)")
        XCTAssertTrue(startingUnitTypes.contains("model.unit.caravel"), "Starting units: \(startingUnitTypes)")
        XCTAssertFalse(startingUnitTypes.contains("model.unit.merchantman"), "Starting units: \(startingUnitTypes)")
    }

    @MainActor
    private func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(30)
        while !condition(), Date() < deadline {
            try await Task.sleep(for: .milliseconds(50))
        }
        guard condition() else {
            XCTFail("Timed out waiting for the expected game state.")
            throw FreeColProtocolError.timeout
        }
    }
}

import Darwin
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
}

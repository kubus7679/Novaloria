import Darwin
import Foundation
import FreeColProtocol

struct JavaServerLaunch {
    let directory: URL
    let optionsFile: URL
    let executable: URL
    let arguments: [String]
    let port: Int

    static func prepare(configuration: NewGameConfiguration, java: URL, port: Int,
                        name: String, seed: String, root: URL) throws -> Self {
        guard (1...65535).contains(port) else {
            throw NewGameError.invalid("Der Serverport muss zwischen 1 und 65535 liegen.")
        }
        guard FileManager.default.isExecutableFile(atPath: java.path) else {
            throw NewGameError.invalid("Die gewählte Java-Datei ist nicht ausführbar.")
        }
        guard seed.isEmpty || Int64(seed) != nil else {
            throw NewGameError.invalid("Der Zufallsstartwert muss eine ganze 64-Bit-Zahl sein.")
        }
        let xml = try configuration.specificationXML()
        let fm = FileManager.default
        let directory = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        let data = directory.appendingPathComponent("freecol-data")
        let rules = data.appendingPathComponent("rules")
        try fm.createDirectory(at: rules, withIntermediateDirectories: true)
        let originalData = configuration.installation.appendingPathComponent("data")
        for entry in try fm.contentsOfDirectory(at: originalData, includingPropertiesForKeys: nil)
            where entry.lastPathComponent != "rules" {
            try fm.createSymbolicLink(at: data.appendingPathComponent(entry.lastPathComponent), withDestinationURL: entry)
        }
        for entry in try fm.contentsOfDirectory(at: originalData.appendingPathComponent("rules"),
                                               includingPropertiesForKeys: nil) {
            guard entry.lastPathComponent != NewGameConfiguration.rulesID else {
                throw NewGameError.invalid("Das reservierte Regelset \(NewGameConfiguration.rulesID) existiert bereits.")
            }
            try fm.createSymbolicLink(at: rules.appendingPathComponent(entry.lastPathComponent), withDestinationURL: entry)
        }
        let customRules = rules.appendingPathComponent(NewGameConfiguration.rulesID)
        try fm.createDirectory(at: customRules, withIntermediateDirectories: true)
        let optionsFile = directory.appendingPathComponent("game-options.xml")
        try xml.write(to: optionsFile, atomically: true, encoding: .utf8)
        try fm.createSymbolicLink(at: customRules.appendingPathComponent("specification.xml"), withDestinationURL: optionsFile)
        try XMLEncoder.encode(tag: "mod", attributes: ["id": NewGameConfiguration.rulesID])
            .write(to: customRules.appendingPathComponent("mod.xml"), atomically: true, encoding: .utf8)
        for folder in ["config", "cache", "data"] {
            try fm.createDirectory(at: directory.appendingPathComponent(folder), withIntermediateDirectories: true)
        }
        let clientOptions = directory.appendingPathComponent("client-options.xml")
        try """
        <?xml version="1.0" encoding="UTF-8"?>
        <clientOptions>
          <option id="model.option.languageOption" value="clientOptions.gui.languageOption.autoDetectLanguage"/>
          <option id="model.option.usePixmaps" value="true"/>
          <option id="model.option.useOpenGL" value="false"/>
          <option id="model.option.useXRender" value="false"/>
        </clientOptions>
        """.write(to: clientOptions, atomically: true, encoding: .utf8)
        var arguments = [
            "-Djava.awt.headless=true", "-Xmx2G", "-jar", configuration.installation.appendingPathComponent("FreeCol.jar").path,
            "--freecol-data", data.path, "--default-locale", "en", "--server", "--private",
            "--server-ip", "127.0.0.1", "--server-port", String(port),
            "--server-name", name, "--rules", NewGameConfiguration.rulesID,
            "--difficulty", configuration.difficulty.argument,
            "--user-config-directory", directory.appendingPathComponent("config").path,
            "--user-cache-directory", directory.appendingPathComponent("cache").path,
            "--user-data-directory", directory.appendingPathComponent("data").path,
            "--clientOptions", clientOptions.path,
            "--log-file", directory.appendingPathComponent("server.log").path,
        ]
        if !seed.isEmpty { arguments += ["--seed", seed] }
        let launch = Self(directory: directory, optionsFile: optionsFile, executable: java,
                          arguments: arguments, port: port)
        // Keep the exact argument vector, without shell interpolation, for reproducing a startup.
        let manifest = try JSONSerialization.data(withJSONObject: [java.path] + arguments, options: [.prettyPrinted])
        try manifest.write(to: directory.appendingPathComponent("launch-arguments.json"), options: .atomic)
        return launch
    }
}

@MainActor
final class LocalJavaServer {
    private var process: Process?
    private var terminatingProcess: Process?
    private var console: FileHandle?
    private(set) var launch: JavaServerLaunch?
    var onUnexpectedExit: ((String) -> Void)?

    deinit {
        if let process, process.isRunning { process.terminate() }
    }

    func start(_ launch: JavaServerLaunch) async throws {
        guard process == nil else { throw NewGameError.invalid("Es läuft bereits ein eigener Java-Server.") }
        try await waitForShutdown()
        try Self.requireFreePort(launch.port)
        self.launch = launch
        let log = launch.directory.appendingPathComponent("console.log")
        guard FileManager.default.createFile(atPath: log.path, contents: nil) else {
            throw NewGameError.invalid("Das Serverprotokoll konnte nicht angelegt werden: \(log.path)")
        }
        let console = try FileHandle(forWritingTo: log)
        self.console = console
        let process = Process()
        process.executableURL = launch.executable
        process.arguments = launch.arguments
        process.currentDirectoryURL = launch.directory
        process.standardOutput = console
        process.standardError = console
        process.standardInput = FileHandle.nullDevice
        self.process = process
        do {
            try process.run()
            for _ in 0..<300 {
                try Task.checkCancellation()
                guard process.isRunning else {
                    throw NewGameError.invalid("Java-Server beendet (Status \(process.terminationStatus)). Protokoll: \(log.path)")
                }
                if try Self.isListening(port: launch.port) {
                    process.terminationHandler = { [weak self] terminated in
                        Task { @MainActor [weak self] in
                            guard let self, self.process === terminated else { return }
                            self.onUnexpectedExit?("Java-Server unerwartet beendet (Status \(terminated.terminationStatus)). Protokoll: \(log.path)")
                        }
                    }
                    return
                }
                try await Task.sleep(for: .milliseconds(100))
            }
            throw NewGameError.invalid("Java-Server nach 30 Sekunden nicht erreichbar. Protokoll: \(log.path)")
        } catch {
            stop()
            throw error
        }
    }

    func stop() {
        if let process {
            process.terminationHandler = nil
            if process.isRunning {
                terminatingProcess = process
                process.terminate()
                DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
                    if process.isRunning { kill(process.processIdentifier, SIGKILL) }
                }
            }
        }
        process = nil
        if let console {
            do { try console.close() }
            catch { FreeColLogger.shared.error("Serverprotokoll konnte nicht geschlossen werden: \(error)") }
        }
        console = nil
    }

    func waitForShutdown() async throws {
        guard let terminatingProcess else { return }
        for _ in 0..<50 {
            if !terminatingProcess.isRunning {
                self.terminatingProcess = nil
                return
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw NewGameError.invalid("Der bisherige Java-Server wurde nicht rechtzeitig beendet.")
    }

    private static func address(port: Int) -> sockaddr_in {
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = UInt16(port).bigEndian
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        return address
    }

    private static func requireFreePort(_ port: Int) throws {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { throw NewGameError.invalid("Serverport konnte nicht geprüft werden: \(String(cString: strerror(errno)))") }
        defer { close(fd) }
        var address = address(port: port)
        let result = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard result == 0 else {
            throw NewGameError.invalid("Port \(port) ist belegt oder nicht nutzbar. Bitte einen anderen Port wählen.")
        }
    }

    private static func isListening(port: Int) throws -> Bool {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw NewGameError.invalid("Serververbindung konnte nicht geprüft werden: \(String(cString: strerror(errno)))")
        }
        defer { close(fd) }
        var timeout = timeval(tv_sec: 0, tv_usec: 100_000)
        guard setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size)) == 0 else {
            throw NewGameError.invalid("Server-Zeitlimit konnte nicht gesetzt werden: \(String(cString: strerror(errno)))")
        }
        var address = address(port: port)
        let status = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        if status == 0 { return true }
        if [ECONNREFUSED, ETIMEDOUT, EINPROGRESS, EINTR].contains(errno) { return false }
        throw NewGameError.invalid("Serververbindung fehlgeschlagen: \(String(cString: strerror(errno)))")
    }
}

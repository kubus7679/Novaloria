import Foundation
import AppKit
import FreeColProtocol

private final class ArchiveProcessResult: @unchecked Sendable {
    var status: Int32 = -1
    var output: Data?
    var directory: URL?
}

struct FreeColMod: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let location: URL
    let isArchive: Bool
    let hasSpecification: Bool

    static func discover(installation: URL?) -> [FreeColMod] {
        var roots: [URL] = []
        if let installation {
            roots.append(installation.appendingPathComponent("data/mods", isDirectory: true))
        }
        if let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            roots.append(support.appendingPathComponent("freecol/mods", isDirectory: true))
        }

        var modsByID: [String: FreeColMod] = [:]
        for root in roots {
            guard let directories = try? FileManager.default.contentsOfDirectory(
                at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
            ) else { continue }
            for directory in directories {
                let isArchive = !FileManager.default.fileExists(atPath: directory.appendingPathComponent("mod.xml").path)
                guard (!isArchive || ["zip", "fmd"].contains(directory.pathExtension.lowercased())),
                      let descriptor = readEntry("mod.xml", from: directory, isArchive: isArchive),
                      let parsed = try? XMLDecoder.decode(descriptor),
                      parsed.tag == "mod",
                      let id = parsed.attributes["id"], !id.isEmpty,
                      !id.contains("/"), !id.contains("..") else { continue }
                let labels = loadLabels(in: directory, isArchive: isArchive)
                let key = "mod.\(id)"
                modsByID[id] = FreeColMod(
                    id: id,
                    name: labels[key + ".name"] ?? id,
                    description: labels[key + ".shortDescription"] ?? labels[key + ".description"] ?? "",
                    location: directory,
                    isArchive: isArchive,
                    hasSpecification: readEntry("specification.xml", from: directory, isArchive: isArchive) != nil
                )
            }
        }
        return modsByID.values.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    func readSpecification() throws -> String {
        guard let text = Self.readEntry("specification.xml", from: location, isArchive: isArchive) else {
            throw NewGameError.invalid(L10n.text("Die Mod enthält keine lesbare Spezifikation: \(id)", table: "NewGameConfiguration"))
        }
        return text
    }

    func resourceProperties() -> [String: String] {
        guard let text = Self.readEntry("resources.properties", from: location, isArchive: isArchive) else {
            return [:]
        }
        var result: [String: String] = [:]
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#"), !trimmed.hasPrefix("!") else { continue }
            guard let separator = trimmed.firstIndex(of: "=") else { continue }
            let key = String(trimmed[..<separator]).trimmingCharacters(in: .whitespaces)
            let value = String(trimmed[trimmed.index(after: separator)...]).trimmingCharacters(in: .whitespaces)
            if !key.isEmpty, !value.isEmpty { result[key] = value }
        }
        return result
    }

    func imageData(at resourcePath: String) -> Data? {
        guard !resourcePath.hasPrefix("/"),
              !resourcePath.split(separator: "/").contains(".."),
              !resourcePath.hasPrefix("resource:") else { return nil }
        if isArchive {
            guard let root = Self.extractedArchiveDirectory(for: location) else { return nil }
            return try? Data(contentsOf: root.appendingPathComponent(resourcePath))
        }
        return try? Data(contentsOf: location.appendingPathComponent(resourcePath))
    }

    func entryPaths() -> Set<String> {
        let root = isArchive ? Self.extractedArchiveDirectory(for: location) : location
        guard let root,
              let enumerator = FileManager.default.enumerator(
                at: root, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]
              ) else { return [] }
        return Set(enumerator.compactMap { file in
            guard let file = file as? URL,
                  (try? file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { return nil }
            return String(file.path.dropFirst(root.path.count + 1))
        })
    }

    private static func loadLabels(in location: URL, isArchive: Bool) -> [String: String] {
        let files = [
            "FreeColMessages.properties",
            "ModMessages.properties",
            "data/strings/FreeColModMessages.properties",
            "data/strings/FreeColMessages.properties",
        ]
        var result: [String: String] = [:]
        for file in files {
            guard let text = readEntry(file, from: location, isArchive: isArchive) else {
                continue
            }
            for line in text.components(separatedBy: .newlines) where !line.hasPrefix("#") {
                guard let separator = line.firstIndex(of: "=") else { continue }
                result[String(line[..<separator]).trimmingCharacters(in: .whitespaces)] =
                    String(line[line.index(after: separator)...]).trimmingCharacters(in: .whitespaces)
            }
        }
        return result
    }

    private static func readEntry(_ path: String, from location: URL, isArchive: Bool) -> String? {
        guard isArchive else {
            return try? String(contentsOf: location.appendingPathComponent(path), encoding: .utf8)
        }
        guard let data = readDataEntry(path, from: location) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func readDataEntry(_ path: String, from location: URL) -> Data? {
        guard let result = runArchiveProcess(arguments: ["-p", location.path, path], captureOutput: true),
              result.status == 0 else { return nil }
        return result.output
    }

    private static let archiveQueue = DispatchQueue(label: "Novaloria.FreeColMod.archive", qos: .utility)
    private static var extractedArchives: [String: URL] = [:]

    private static func extractedArchiveDirectory(for archive: URL) -> URL? {
        let attributes = try? FileManager.default.attributesOfItem(atPath: archive.path)
        let size = (attributes?[.size] as? NSNumber)?.intValue ?? 0
        let modified = (attributes?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        let cacheKey = "\(archive.path)|\(size)|\(modified)"
        let result = ArchiveProcessResult()
        let semaphore = DispatchSemaphore(value: 0)
        archiveQueue.async {
            defer { semaphore.signal() }
            if let cached = extractedArchives[cacheKey],
               FileManager.default.fileExists(atPath: cached.appendingPathComponent("mod.xml").path) {
                result.directory = cached
                return
            }

            guard let listing = runArchiveProcessOnQueue(
                arguments: ["-Z1", archive.path], captureOutput: true
            ), listing.status == 0,
                  let text = listing.output.flatMap({ String(data: $0, encoding: .utf8) }) else { return }
            let entries = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
            guard entries.allSatisfy({ !$0.hasPrefix("/") && !$0.split(separator: "/").contains("..") }) else {
                return
            }

            guard let cacheRoot = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
                .appendingPathComponent("Novaloria/FreeColMods", isDirectory: true) else { return }
            let cacheName = "\(archive.deletingPathExtension().lastPathComponent)-\(size)-\(Int64(modified * 1000))"
                .replacingOccurrences(of: #"[^A-Za-z0-9._-]"#, with: "_", options: .regularExpression)
            let destination = cacheRoot.appendingPathComponent(cacheName, isDirectory: true)
            if !FileManager.default.fileExists(atPath: destination.appendingPathComponent("mod.xml").path) {
                try? FileManager.default.removeItem(at: destination)
                do {
                    try FileManager.default.createDirectory(at: cacheRoot, withIntermediateDirectories: true)
                } catch {
                    return
                }
                guard let extraction = runArchiveProcessOnQueue(
                    arguments: ["-q", archive.path, "-d", destination.path], captureOutput: false
                ), extraction.status == 0,
                      FileManager.default.fileExists(atPath: destination.appendingPathComponent("mod.xml").path) else {
                    try? FileManager.default.removeItem(at: destination)
                    return
                }
            }
            extractedArchives[cacheKey] = destination
            result.directory = destination
        }
        semaphore.wait()
        return result.directory
    }

    private static func runArchiveProcess(
        arguments: [String], captureOutput: Bool
    ) -> (status: Int32, output: Data?)? {
        let result = ArchiveProcessResult()
        let semaphore = DispatchSemaphore(value: 0)
        archiveQueue.async {
            defer { semaphore.signal() }
            guard let processResult = runArchiveProcessOnQueue(arguments: arguments, captureOutput: captureOutput) else {
                return
            }
            result.status = processResult.status
            result.output = processResult.output
        }
        semaphore.wait()
        guard result.status >= 0 else { return nil }
        return (result.status, result.output)
    }

    private static func runArchiveProcessOnQueue(
        arguments: [String], captureOutput: Bool
    ) -> (status: Int32, output: Data?)? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = arguments
        let output = captureOutput ? Pipe() : nil
        process.standardOutput = output ?? FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            let data = output?.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return (process.terminationStatus, data)
        } catch {
            return nil
        }
    }
}

enum FreeColModSelection {
    static let storageKey = "freecol.activeModIDs"
}

final class ModImageCatalog {
    static let shared = ModImageCatalog()

    private struct Resource {
        let mod: FreeColMod
        let path: String
        let entryPaths: Set<String>
    }

    struct ImageAsset {
        let data: Data
        let logicalSize: CGSize
    }

    private(set) var signature = ""
    private var resources: [String: Resource] = [:]

    private func refreshIfNeeded() {
        let installationPath = NSString(string: UserDefaults.standard.string(forKey: "freecol.javaInstallation") ?? "")
            .expandingTildeInPath
        let installation = installationPath.isEmpty ? nil : URL(fileURLWithPath: installationPath)
        let activeIDs = Set((try? JSONDecoder().decode(
            [String].self,
            from: Data((UserDefaults.standard.string(forKey: FreeColModSelection.storageKey) ?? "[]").utf8)
        )) ?? [])
        let nextSignature = "\(installation?.path ?? "")|\(activeIDs.sorted().joined(separator: ","))"
        guard nextSignature != signature else { return }
        signature = nextSignature
        resources = [:]
        for mod in FreeColMod.discover(installation: installation) where activeIDs.contains(mod.id) {
            let entryPaths = mod.entryPaths()
            for (key, value) in mod.resourceProperties() {
                resources[key] = Resource(mod: mod, path: value, entryPaths: entryPaths)
            }
        }
    }

    func currentSignature() -> String {
        refreshIfNeeded()
        return signature
    }

    func data(forResourceKeys keys: [String]) -> Data? {
        refreshIfNeeded()
        for key in keys {
            if let resource = resource(for: key, visited: []),
               let data = resource.mod.imageData(at: resource.path) { return data }
        }
        return nil
    }

    func image(forResourceKeys keys: [String], variationSeed: Int? = nil) -> ImageAsset? {
        refreshIfNeeded()
        for key in keys {
            guard let resource = resource(for: key, visited: []),
                  let basePath = selectedPath(resource.path, entryPaths: resource.entryPaths,
                                              variationSeed: variationSeed),
                  let baseData = resource.mod.imageData(at: basePath),
                  let bitmap = NSBitmapImageRep(data: baseData) else { continue }
            let hires = hiresPath(for: basePath, entryPaths: resource.entryPaths)
            let data = hires.flatMap { resource.mod.imageData(at: $0) } ?? baseData
            return ImageAsset(data: data, logicalSize: CGSize(width: bitmap.pixelsWide, height: bitmap.pixelsHigh))
        }
        return nil
    }

    private func resource(for key: String, visited: Set<String>) -> Resource? {
        guard !visited.contains(key), visited.count < 8, let resource = resources[key] else { return nil }
        if resource.path.hasPrefix("resource:") {
            return self.resource(for: String(resource.path.dropFirst("resource:".count)), visited: visited.union([key]))
        }
        return resource
    }

    private func selectedPath(_ path: String, entryPaths: Set<String>, variationSeed: Int?) -> String? {
        guard entryPaths.contains(path) else { return nil }
        guard let variationSeed else { return path }
        let variations = siblingPaths(for: path, entryPaths: entryPaths)
        let choices = [path] + variations
        let index = ((variationSeed % choices.count) + choices.count) % choices.count
        return choices[index]
    }

    private func siblingPaths(for path: String, entryPaths: Set<String>) -> [String] {
        let url = URL(fileURLWithPath: path)
        let stem = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        let prefix = stem.replacingOccurrences(of: #"\d+$"#, with: "", options: .regularExpression)
        let pattern = "^" + NSRegularExpression.escapedPattern(for: prefix) + #"\d{1,2}\."#
            + NSRegularExpression.escapedPattern(for: ext) + "$"
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        let parent = url.deletingLastPathComponent().path
        return entryPaths.filter { candidate in
            let candidateURL = URL(fileURLWithPath: candidate)
            return candidateURL.deletingLastPathComponent().path == parent
                && candidate != path
                && expression.firstMatch(in: candidateURL.lastPathComponent,
                                         range: NSRange(candidateURL.lastPathComponent.startIndex..., in: candidateURL.lastPathComponent)) != nil
        }.sorted { variationNumber($0) < variationNumber($1) }
    }

    private func hiresPath(for path: String, entryPaths: Set<String>) -> String? {
        let url = URL(fileURLWithPath: path)
        let stem = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        let pattern = "^" + NSRegularExpression.escapedPattern(for: stem) + #"\.size(\d+)\."#
            + NSRegularExpression.escapedPattern(for: ext) + "$"
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return nil }
        let parent = url.deletingLastPathComponent().path
        return entryPaths.filter { candidate in
            let candidateURL = URL(fileURLWithPath: candidate)
            return candidateURL.deletingLastPathComponent().path == parent
                && expression.firstMatch(in: candidateURL.lastPathComponent,
                                         range: NSRange(candidateURL.lastPathComponent.startIndex..., in: candidateURL.lastPathComponent)) != nil
        }.max { hiresFactor($0) < hiresFactor($1) }
    }

    private func variationNumber(_ path: String) -> Int {
        let stem = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        let digits = String(stem.reversed().prefix(while: \.isNumber).reversed())
        return Int(digits) ?? 0
    }

    private func hiresFactor(_ path: String) -> Int {
        let filename = URL(fileURLWithPath: path).lastPathComponent
        guard let range = filename.range(of: #"\.size\d+\."#, options: .regularExpression) else { return 0 }
        let digits = filename[range].dropFirst(".size".count).dropLast()
        return Int(digits) ?? 0
    }
}

import Foundation
import AppKit
import FreeColProtocol

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
            return Self.readDataEntry(resourcePath, from: location)
        }
        return try? Data(contentsOf: location.appendingPathComponent(resourcePath))
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
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-p", location.path, path]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            return data
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
            for (key, value) in mod.resourceProperties() {
                resources[key] = Resource(mod: mod, path: value)
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
            if let data = data(for: key, visited: []) { return data }
        }
        return nil
    }

    private func data(for key: String, visited: Set<String>) -> Data? {
        guard !visited.contains(key), visited.count < 8, let resource = resources[key] else { return nil }
        if resource.path.hasPrefix("resource:") {
            return data(for: String(resource.path.dropFirst("resource:".count)), visited: visited.union([key]))
        }
        return resource.mod.imageData(at: resource.path)
    }
}

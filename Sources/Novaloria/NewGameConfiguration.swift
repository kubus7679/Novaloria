import Foundation
import FreeColProtocol

enum NewGameError: LocalizedError {
    case invalid(String)

    var errorDescription: String? {
        switch self {
        case .invalid(let message): return message
        }
    }
}

enum GameDifficulty: String, CaseIterable, Identifiable {
    case veryEasy, easy, medium, hard, veryHard

    var id: String { rawValue }
    var optionID: String { "model.difficulty.\(rawValue)" }
    var argument: String {
        switch self {
        case .veryEasy: return "Very Easy"
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        case .veryHard: return "Very Hard"
        }
    }
    var title: String {
        switch self {
        case .veryEasy: return "Sehr leicht"
        case .easy: return "Leicht"
        case .medium: return "Normal"
        case .hard: return "Schwer"
        case .veryHard: return "Sehr schwer"
        }
    }
}

struct GameSetupOption: Identifiable {
    let node: ParsedMessage
    var id: String { node.attributes["id"]! }
    var isBoolean: Bool { node.tag == "booleanOption" }
    var isXML: Bool {
        !["booleanOption", "integerOption", "percentageOption", "rangeOption",
          "selectOption", "stringOption", "textOption", "fileOption"].contains(node.tag)
    }
    var choices: [(value: String, label: String)] {
        node.children.compactMap {
            guard ["choice", "selectValue", "rangeValue"].contains($0.tag),
                  let value = $0.attributes["value"] else { return nil }
            // Some Java string choices store the translation key instead of the wire value.
            if node.tag == "stringOption", value.hasPrefix(id + "."), value.hasSuffix(".name") {
                return (String(value.dropFirst(id.count + 1).dropLast(5)), value)
            }
            return (value, $0.attributes["label"] ?? value)
        }
    }
    var initialValue: String {
        if isXML { return XMLEncoder.encode(tag: node.tag, attributes: node.attributes, children: node.children) }
        return node.attributes["value"] ?? node.attributes["defaultValue"] ?? ""
    }

    func validatedNode(value: String, unitTypeIDs: Set<String>, roleIDs: Set<String>) throws -> ParsedMessage {
        func invalid(_ reason: String) -> NewGameError { .invalid("\(id): \(reason)") }
        if isXML {
            let parsed = try XMLDecoder.decode(value)
            guard parsed.tag == node.tag, parsed.attributes["id"] == id else {
                throw invalid("XML-Typ und Options-ID dürfen nicht geändert werden.")
            }
            if parsed.tag == "unitListOption" {
                for unit in parsed.children where unit.tag != "template" {
                    guard unit.tag == "unitOption",
                          let type = unit.children.first(where: { $0.tag == "unitType" })?.attributes["value"],
                          unitTypeIDs.contains(type),
                          let role = unit.children.first(where: { $0.tag == "role" })?.attributes["value"],
                          roleIDs.contains(role),
                          let count = unit.children.first(where: { $0.tag == "number" })?.attributes["value"],
                          let number = Int32(count), number > 0 else {
                        throw invalid("Einheiten benötigen gültige unitType-, role- und positive number-Werte.")
                    }
                }
            }
            return parsed
        }
        if isBoolean, !["true", "false"].contains(value) {
            throw invalid("Bitte true oder false wählen.")
        }
        if ["integerOption", "percentageOption", "rangeOption", "selectOption"].contains(node.tag) {
            guard let number = Int32(value) else { throw invalid("Bitte eine ganze 32-Bit-Zahl eingeben.") }
            func bound(_ key: String, defaultValue: Int32) throws -> Int32 {
                guard let text = node.attributes[key] else { return defaultValue }
                guard let bound = Int32(text) else { throw invalid("Ungültige Bereichsdefinition: \(key).") }
                return bound
            }
            let minimum = try bound("minimumValue", defaultValue: node.tag == "percentageOption" ? 0 : Int32.min)
            let maximum = try bound("maximumValue", defaultValue: node.tag == "percentageOption" ? 100 : Int32.max)
            guard minimum <= maximum else { throw invalid("Minimum ist größer als Maximum.") }
            guard (minimum...maximum).contains(number) else {
                throw invalid("Erlaubter Bereich: \(minimum) bis \(maximum).")
            }
        }
        if !choices.isEmpty, !choices.contains(where: { $0.value == value }) {
            throw invalid("Bitte einen der angebotenen Werte wählen.")
        }
        if node.tag == "fileOption", !value.isEmpty {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: value, isDirectory: &isDirectory),
                  !isDirectory.boolValue, FileManager.default.isReadableFile(atPath: value) else {
                throw invalid("Die Importdatei ist keine lesbare Datei.")
            }
        }
        var attributes = node.attributes
        attributes.removeValue(forKey: "defaultValue")
        if node.tag == "fileOption", value.isEmpty {
            attributes.removeValue(forKey: "value")
        } else if node.tag == "fileOption" {
            attributes["value"] = URL(fileURLWithPath: value).standardizedFileURL.path
        } else {
            attributes["value"] = value
        }
        return ParsedMessage(tag: node.tag, attributes: attributes, children: node.children)
    }
}

struct GameSetupSection: Identifiable {
    let id: String
    let options: [GameSetupOption]
}

struct NewGameConfiguration {
    static let rulesID = "swift-client-game"
    let installation: URL
    let difficulty: GameDifficulty
    let groups: [ParsedMessage]
    let labels: [String: String]
    let unitTypeIDs: Set<String>
    let roleIDs: Set<String>
    var values: [String: String]

    var sections: [GameSetupSection] {
        func collect(_ node: ParsedMessage, path: String) -> [GameSetupSection] {
            let options = node.children.filter { $0.tag != "optionGroup" && $0.attributes["id"] != nil }
                .map { GameSetupOption(node: $0) }
            var result = options.isEmpty ? [] : [GameSetupSection(id: path, options: options)]
            for child in node.children where child.tag == "optionGroup" {
                result += collect(child, path: child.attributes["id"] ?? path)
            }
            return result
        }
        return groups.flatMap { collect($0, path: $0.attributes["id"] ?? $0.tag) }
    }

    func label(_ key: String) -> String {
        labels[key + ".name"] ?? labels[key] ?? key
    }

    static func load(installation: URL, difficulty: GameDifficulty) throws -> Self {
        let installation = installation.standardizedFileURL.resolvingSymlinksInPath()
        guard FileManager.default.isReadableFile(atPath: installation.appendingPathComponent("FreeCol.jar").path) else {
            throw NewGameError.invalid("Im Installationsordner fehlt eine lesbare FreeCol.jar.")
        }
        let rules = installation.appendingPathComponent("data/rules")
        func readSpec(_ id: String, visited: Set<String>) throws -> [ParsedMessage] {
            guard !visited.contains(id), !id.contains("/"), !id.contains("..") else {
                throw NewGameError.invalid("Ungültige oder zyklische Regelset-Vererbung: \(id)")
            }
            let xml = try String(contentsOf: rules.appendingPathComponent("\(id)/specification.xml"), encoding: .utf8)
            let root = try XMLDecoder.decode(xml)
            guard root.tag == "freecol-specification" else {
                throw NewGameError.invalid("Ungültige FreeCol-Spezifikation: \(id)")
            }
            var parents: [ParsedMessage] = []
            if let parent = root.attributes["extends"] {
                parents = try readSpec(parent, visited: visited.union([id]))
            }
            return parents + [root]
        }
        let specs = try readSpec("freecol", visited: [])
        var options = ParsedMessage(tag: "options", attributes: [:], children: [])
        var unitTypeIDs = Set<String>()
        var roleIDs = Set<String>()
        for spec in specs {
            if let child = spec.children.first(where: { $0.tag == "options" }) {
                options = merge(options, child)
            }
            for group in spec.children {
                for child in group.children {
                    guard let id = child.attributes["id"] else { continue }
                    if child.tag == "unit-type" { unitTypeIDs.insert(id) }
                    if child.tag == "role" { roleIDs.insert(id) }
                }
            }
        }
        guard let levels = options.children.first(where: { $0.attributes["id"] == "difficultyLevels" }),
              let selected = levels.children.first(where: { $0.attributes["id"] == difficulty.optionID }),
              let game = options.children.first(where: { $0.attributes["id"] == "gameOptions" }),
              let map = options.children.first(where: { $0.attributes["id"] == "mapGeneratorOptions" }) else {
            throw NewGameError.invalid("Spiel-, Karten- oder Schwierigkeitsoptionen fehlen im Regelset.")
        }
        // Custom contains the bounds and choices omitted by the preset difficulty levels.
        let template = levels.children.first { $0.attributes["id"] == "model.difficulty.custom" }
        let difficultyGroup = template.map { merge($0, selected) } ?? selected
        var labels: [String: String] = [:]
        for name in ["FreeColMessages.properties", "FreeColMessages_de.properties"] {
            let text = try String(contentsOf: installation.appendingPathComponent("data/strings/\(name)"), encoding: .utf8)
            for line in text.components(separatedBy: .newlines) where !line.hasPrefix("#") {
                if let separator = line.firstIndex(of: "=") {
                    labels[String(line[..<separator]).trimmingCharacters(in: .whitespaces)] =
                        String(line[line.index(after: separator)...]).trimmingCharacters(in: .whitespaces)
                }
            }
        }
        var result = Self(installation: installation, difficulty: difficulty,
                          groups: [game, map, difficultyGroup], labels: labels,
                          unitTypeIDs: unitTypeIDs, roleIDs: roleIDs, values: [:])
        func validateIDs(_ node: ParsedMessage) throws {
            guard let id = node.attributes["id"], !id.isEmpty else {
                throw NewGameError.invalid("Optionsdefinition ohne ID: \(node.tag)")
            }
            if node.tag == "optionGroup" {
                try node.children.forEach(validateIDs)
            }
        }
        try result.groups.forEach(validateIDs)
        for option in result.sections.flatMap(\.options) {
            guard result.values[option.id] == nil else {
                throw NewGameError.invalid("Doppelte Optionsdefinition: \(option.id)")
            }
            result.values[option.id] = option.initialValue
        }
        return result
    }

    private static func merge(_ base: ParsedMessage, _ override: ParsedMessage) -> ParsedMessage {
        var children = base.children
        for child in override.children {
            if let id = child.attributes["id"],
               let index = children.firstIndex(where: { $0.attributes["id"] == id }) {
                children[index] = merge(children[index], child)
            } else {
                children.append(child)
            }
        }
        // Presets replace list contents but inherit bounds and choice metadata.
        if base.tag != "optionGroup", base.tag != "options" {
            children = override.children.isEmpty && override.tag != "unitListOption" ? base.children : override.children
        }
        var attributes = base.attributes.merging(override.attributes) { _, new in new }
        if override.attributes["defaultValue"] != nil, override.attributes["value"] == nil {
            attributes.removeValue(forKey: "value")
        }
        return ParsedMessage(tag: override.tag, attributes: attributes,
                             children: children)
    }

    func specificationXML() throws -> String {
        func configured(_ node: ParsedMessage) throws -> ParsedMessage {
            if node.tag != "optionGroup" {
                let option = GameSetupOption(node: node)
                guard let value = values[option.id] else {
                    throw NewGameError.invalid("Optionswert fehlt: \(option.id)")
                }
                return try option.validatedNode(value: value, unitTypeIDs: unitTypeIDs, roleIDs: roleIDs)
            }
            return ParsedMessage(tag: node.tag, attributes: node.attributes,
                                 children: try node.children.map(configured))
        }
        for (lower, upper) in [("minimumLatitude", "maximumLatitude"), ("startingYear", "seasonYear"),
                               ("seasonYear", "lastYear"), ("startingYear", "lastColonialYear"),
                               ("lastColonialYear", "lastYear")] {
            if let low = values["model.option.\(lower)"].flatMap(Int.init),
               let high = values["model.option.\(upper)"].flatMap(Int.init), low > high {
                throw NewGameError.invalid("\(label("model.option." + lower)) darf nicht größer als \(label("model.option." + upper)) sein.")
            }
        }
        let configuredGroups = try groups.map(configured)
        let levels = ParsedMessage(tag: "optionGroup", attributes: ["id": "difficultyLevels", "recursive": "false"],
                                   children: [configuredGroups[2]])
        let options = ParsedMessage(tag: "options", attributes: [:],
                                    children: [configuredGroups[0], configuredGroups[1], levels])
        return "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
            XMLEncoder.encode(tag: "freecol-specification",
                              attributes: ["id": Self.rulesID, "extends": "freecol", "version": "0.120"],
                              children: [options]) + "\n"
    }
}

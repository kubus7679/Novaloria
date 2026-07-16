import Foundation

public struct LoginMessage: FreeColMessage {
    public static let tag = "login"

    public let nationId: String?
    public let version: String?
    public let currentPlayer: String?
    public let userName: String?
    public let singlePlayer: String?
    public let state: String?
    public let children: [ParsedMessage]

    public init(
        nationId: String? = nil,
        version: String? = nil,
        currentPlayer: String? = nil,
        userName: String? = nil,
        singlePlayer: String? = nil,
        state: String? = nil
    ) {
        self.nationId = nationId
        self.version = version
        self.currentPlayer = currentPlayer
        self.userName = userName
        self.singlePlayer = singlePlayer
        self.state = state
        self.children = []
    }

    public init(attributes: Attributes, children: Children) throws {
        self.nationId = attributes["nationId"]
        self.version = attributes["version"]
        self.currentPlayer = attributes["currentPlayer"]
        self.userName = attributes["userName"]
        self.singlePlayer = attributes["singlePlayer"]
        self.state = attributes["state"]
        self.children = children.compactMap { dict in
            guard let tag = dict.keys.first else { return nil }
            return ParsedMessage(tag: tag, attributes: [:], children: [])
        }
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = nationId { attrs["nationId"] = v }
        if let v = version { attrs["version"] = v }
        if let v = currentPlayer { attrs["currentPlayer"] = v }
        if let v = userName { attrs["userName"] = v }
        if let v = singlePlayer { attrs["singlePlayer"] = v }
        if let v = state { attrs["state"] = v }
        return (attrs, [])
    }
}

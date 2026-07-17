import Foundation

public struct LoginMessage: FreeColMessage {
    public static let tag = "login"

    public let userName: String?
    public let nationId: String?
    public let singlePlayer: String?
    public let currentPlayer: String?
    public let version: String?
    public let state: String?
    public let children: [ParsedMessage]

    public init(
        userName: String? = nil,
        nationId: String? = nil,
        singlePlayer: String? = nil,
        currentPlayer: String? = nil,
        version: String? = nil,
        state: String? = nil
    ) {
        self.userName = userName
        self.nationId = nationId
        self.singlePlayer = singlePlayer
        self.currentPlayer = currentPlayer
        self.version = version
        self.state = state
        self.children = []
    }

    public init(attributes: Attributes, children: Children) throws {
        self.userName = attributes["userName"]
        self.nationId = attributes["nationId"]
        self.singlePlayer = attributes["singlePlayer"]
        self.currentPlayer = attributes["currentPlayer"]
        self.version = attributes["version"]
        self.state = attributes["state"]
        self.children = children.compactMap { dict in
            guard let tag = dict.keys.first else { return nil }
            return ParsedMessage(tag: tag, attributes: [:], children: [])
        }
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = userName { attrs["userName"] = v }
        if let v = nationId { attrs["nationId"] = v }
        if let v = singlePlayer { attrs["singlePlayer"] = v }
        if let v = currentPlayer { attrs["currentPlayer"] = v }
        if let v = version { attrs["version"] = v }
        if let v = state { attrs["state"] = v }
        return (attrs, [])
    }
}

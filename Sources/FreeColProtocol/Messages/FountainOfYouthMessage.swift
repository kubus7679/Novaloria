import Foundation

public struct FountainOfYouthMessage: FreeColMessage {
    public static let tag = "fountainOfYouth"

    public let migrants: String?

    public init(
        migrants: String? = nil
    ) {
        self.migrants = migrants
    }

    public init(attributes: Attributes, children: Children) throws {
        self.migrants = attributes["migrants"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = migrants { attrs["migrants"] = v }
        return (attrs, [])
    }
}

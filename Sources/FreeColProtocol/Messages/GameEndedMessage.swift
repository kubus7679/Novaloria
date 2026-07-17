import Foundation

public struct GameEndedMessage: FreeColMessage {
    public static let tag = "gameEnded"

    public let highScore: String?
    public let winner: String?

    public init(
        highScore: String? = nil,
        winner: String? = nil
    ) {
        self.highScore = highScore
        self.winner = winner
    }

    public init(attributes: Attributes, children: Children) throws {
        self.highScore = attributes["highScore"]
        self.winner = attributes["winner"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = highScore { attrs["highScore"] = v }
        if let v = winner { attrs["winner"] = v }
        return (attrs, [])
    }
}

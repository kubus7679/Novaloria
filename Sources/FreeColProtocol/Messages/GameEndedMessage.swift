import Foundation

public struct GameEndedMessage: FreeColMessage {
    public static let tag = "gameEnded"

    public let winner: String?
    public let highScore: String?

    public init(
        winner: String? = nil,
        highScore: String? = nil
    ) {
        self.winner = winner
        self.highScore = highScore
    }

    public init(attributes: Attributes, children: Children) throws {
        self.winner = attributes["winner"]
        self.highScore = attributes["highScore"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = winner { attrs["winner"] = v }
        if let v = highScore { attrs["highScore"] = v }
        return (attrs, [])
    }
}

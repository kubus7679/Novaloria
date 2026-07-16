import Foundation
import FreeColProtocol

public struct GameMap: GameObject {
    public var id: String
    public var width: Int = 0
    public var height: Int = 0

    public init(id: String, attributes: Attributes, children: [ParsedMessage], game: Game) throws {
        self.id = id
        width = attributes.int("width")
        height = attributes.int("height")
    }
}

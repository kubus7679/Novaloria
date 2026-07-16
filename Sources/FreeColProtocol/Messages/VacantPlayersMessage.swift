import Foundation

public struct VacantPlayersMessage: FreeColMessage {
    public static let tag = "vacantPlayers"


    public init(

    ) {
    }

    public init(attributes: Attributes, children: Children) throws {
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        return (attrs, [])
    }
}

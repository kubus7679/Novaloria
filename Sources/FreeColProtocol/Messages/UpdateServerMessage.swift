import Foundation

public struct UpdateServerMessage: FreeColMessage {
    public static let tag = "updateServer"


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

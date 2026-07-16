import Foundation

public struct PartialMessage: FreeColMessage {
    public static let tag = "partial"


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

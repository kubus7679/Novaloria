import Foundation

public struct MultipleMessage: FreeColMessage {
    public static let tag = "multiple"


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

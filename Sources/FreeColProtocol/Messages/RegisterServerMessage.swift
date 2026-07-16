import Foundation

public struct RegisterServerMessage: FreeColMessage {
    public static let tag = "registerServer"


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

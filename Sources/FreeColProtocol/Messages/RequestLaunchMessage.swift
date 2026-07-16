import Foundation

public struct RequestLaunchMessage: FreeColMessage {
    public static let tag = "requestLaunch"

    public init() {}

    public init(attributes: Attributes, children: Children) throws {
        // No attributes or children expected
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        return ([:], [])
    }
}

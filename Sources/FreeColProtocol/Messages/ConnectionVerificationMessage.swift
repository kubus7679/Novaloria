import Foundation

public struct ConnectionVerificationMessage: FreeColMessage {
    public static let tag = "connectionVerification"

    public let connectable: String?

    public init(
        connectable: String? = nil
    ) {
        self.connectable = connectable
    }

    public init(attributes: Attributes, children: Children) throws {
        self.connectable = attributes["connectable"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = connectable { attrs["connectable"] = v }
        return (attrs, [])
    }
}

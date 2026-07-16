import Foundation

public struct EmigrateUnitMessage: FreeColMessage {
    public static let tag = "emigrateUnit"

    public let slot: String?

    public init(
        slot: String? = nil
    ) {
        self.slot = slot
    }

    public init(attributes: Attributes, children: Children) throws {
        self.slot = attributes["slot"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = slot { attrs["slot"] = v }
        return (attrs, [])
    }
}

import Foundation

public struct SetDestinationMessage: FreeColMessage {
    public static let tag = "setDestination"

    public let unit: String?
    public let destination: String?

    public init(
        unit: String? = nil,
        destination: String? = nil
    ) {
        self.unit = unit
        self.destination = destination
    }

    public init(attributes: Attributes, children: Children) throws {
        self.unit = attributes["unit"]
        self.destination = attributes["destination"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = unit { attrs["unit"] = v }
        if let v = destination { attrs["destination"] = v }
        return (attrs, [])
    }
}

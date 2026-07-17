import Foundation

public struct SetDestinationMessage: FreeColMessage {
    public static let tag = "setDestination"

    public let destination: String?
    public let unit: String?

    public init(
        destination: String? = nil,
        unit: String? = nil
    ) {
        self.destination = destination
        self.unit = unit
    }

    public init(attributes: Attributes, children: Children) throws {
        self.destination = attributes["destination"]
        self.unit = attributes["unit"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = destination { attrs["destination"] = v }
        if let v = unit { attrs["unit"] = v }
        return (attrs, [])
    }
}

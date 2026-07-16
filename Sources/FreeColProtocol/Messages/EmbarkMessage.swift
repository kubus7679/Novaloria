import Foundation

public struct EmbarkMessage: FreeColMessage {
    public static let tag = "embark"

    public let direction: String?
    public let carrier: String?
    public let unit: String?

    public init(
        direction: String? = nil,
        carrier: String? = nil,
        unit: String? = nil
    ) {
        self.direction = direction
        self.carrier = carrier
        self.unit = unit
    }

    public init(attributes: Attributes, children: Children) throws {
        self.direction = attributes["direction"]
        self.carrier = attributes["carrier"]
        self.unit = attributes["unit"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = direction { attrs["direction"] = v }
        if let v = carrier { attrs["carrier"] = v }
        if let v = unit { attrs["unit"] = v }
        return (attrs, [])
    }
}

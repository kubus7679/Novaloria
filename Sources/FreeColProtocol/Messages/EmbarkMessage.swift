import Foundation

public struct EmbarkMessage: FreeColMessage {
    public static let tag = "embark"

    public let carrier: String?
    public let unit: String?
    public let direction: String?

    public init(
        carrier: String? = nil,
        unit: String? = nil,
        direction: String? = nil
    ) {
        self.carrier = carrier
        self.unit = unit
        self.direction = direction
    }

    public init(attributes: Attributes, children: Children) throws {
        self.carrier = attributes["carrier"]
        self.unit = attributes["unit"]
        self.direction = attributes["direction"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = carrier { attrs["carrier"] = v }
        if let v = unit { attrs["unit"] = v }
        if let v = direction { attrs["direction"] = v }
        return (attrs, [])
    }
}

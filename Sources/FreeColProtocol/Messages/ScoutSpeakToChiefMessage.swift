import Foundation

public struct ScoutSpeakToChiefMessage: FreeColMessage {
    public static let tag = "scoutSpeakToChief"

    public let unit: String?
    public let result: String?
    public let settlement: String?

    public init(
        unit: String? = nil,
        result: String? = nil,
        settlement: String? = nil
    ) {
        self.unit = unit
        self.result = result
        self.settlement = settlement
    }

    public init(attributes: Attributes, children: Children) throws {
        self.unit = attributes["unit"]
        self.result = attributes["result"]
        self.settlement = attributes["settlement"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = unit { attrs["unit"] = v }
        if let v = result { attrs["result"] = v }
        if let v = settlement { attrs["settlement"] = v }
        return (attrs, [])
    }
}

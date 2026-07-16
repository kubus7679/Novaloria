import Foundation

public struct SetBuildQueueMessage: FreeColMessage {
    public static let tag = "setBuildQueue"

    public let colony: String?

    public init(
        colony: String? = nil
    ) {
        self.colony = colony
    }

    public init(attributes: Attributes, children: Children) throws {
        self.colony = attributes["colony"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = colony { attrs["colony"] = v }
        return (attrs, [])
    }
}

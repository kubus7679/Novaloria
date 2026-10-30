import Foundation
import FreeColProtocol

public struct GameRegion: Sendable, Identifiable {
    public var id: String
    public var name: String?
    public var key: String?
    public var type: String?
    public var parent: String?
    public var discoverable: Bool
    public var claimable: Bool

    public init(id: String, attributes: Attributes) {
        self.id = id
        name = attributes["name"]
        key = attributes["key"]
        type = attributes["type"]
        parent = attributes["parent"]
        discoverable = attributes.bool("discoverable")
        claimable = attributes.bool("claimable")
    }

    public var displayName: String {
        name ?? key ?? id
    }
}

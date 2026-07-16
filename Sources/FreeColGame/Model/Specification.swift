import Foundation
import FreeColProtocol

public final class Specification: @unchecked Sendable {
    public var id: String?
    public var difficultyLevel: String?
    public var version: String?

    public init(parsed: ParsedMessage) {
        id = parsed.attributes["id"]
        difficultyLevel = parsed.attributes["difficulty-level"]
        version = parsed.attributes["version"]
    }
}

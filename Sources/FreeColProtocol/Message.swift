import Foundation

public typealias Attributes = [String: String]
public typealias Children = [[String: Any]]

public protocol FreeColMessage {
    static var tag: String { get }
    var tag: String { get }
    init(attributes: Attributes, children: Children) throws
    func encode() -> (attributes: Attributes, children: Children)
}

extension FreeColMessage {
    public var tag: String { Self.tag }
}

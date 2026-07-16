import Foundation

public struct Turn: Equatable, CustomStringConvertible {
    public let number: Int

    public init(_ number: Int) {
        self.number = number
    }

    public var description: String { "\(number)" }
}

import Foundation

enum ProtocolLimits {
    static let maximumFrameBytes = 16 * 1024 * 1024
    static let maximumXMLDepth = 128
    static let maximumXMLNodes = 250_000
    static let maximumQueuedFrames = 8
}

struct LineFramer {
    private(set) var bufferedData = Data()
    private let maximumLineBytes: Int

    init(maximumLineBytes: Int = ProtocolLimits.maximumFrameBytes) {
        self.maximumLineBytes = maximumLineBytes
    }

    mutating func append(_ data: Data) throws -> [String] {
        var lines: [String] = []
        var startIndex = data.startIndex

        while let newlineIndex = data[startIndex...].firstIndex(of: 0x0A) {
            try appendFragment(data[startIndex..<newlineIndex])
            guard let line = String(data: bufferedData, encoding: .utf8) else {
                throw FreeColProtocolError.invalidUTF8Message
            }
            lines.append(line)
            bufferedData.removeAll(keepingCapacity: true)
            startIndex = data.index(after: newlineIndex)
        }

        try appendFragment(data[startIndex..<data.endIndex])
        return lines
    }

    mutating func finish() throws -> String? {
        guard !bufferedData.isEmpty else { return nil }
        defer { bufferedData.removeAll(keepingCapacity: true) }
        guard let line = String(data: bufferedData, encoding: .utf8) else {
            throw FreeColProtocolError.invalidUTF8Message
        }
        return line
    }

    private mutating func appendFragment(_ fragment: Data.SubSequence) throws {
        guard fragment.count <= maximumLineBytes - bufferedData.count else {
            throw FreeColProtocolError.resourceLimitExceeded(
                "message exceeds \(maximumLineBytes) bytes"
            )
        }
        bufferedData.append(contentsOf: fragment)
    }
}

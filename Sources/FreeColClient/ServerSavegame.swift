import Foundation
import FreeColProtocol

public enum ServerSavegame {
    public static let maximumBytes = 8 * 1024 * 1024

    public static func decode(_ reply: ParsedMessage) throws -> Data {
        guard let save = reply.tag == "saveGame" ? reply : reply.children.first(where: { $0.tag == "saveGame" }),
              save.attributes["encoding"] == "base64",
              let encoded = save.attributes["data"],
              encoded.utf8.count <= ((maximumBytes + 2) / 3) * 4,
              let data = Data(base64Encoded: encoded),
              data.count <= maximumBytes,
              data.starts(with: [0x50, 0x4b, 0x03, 0x04]) else {
            throw FreeColProtocolError.invalidState("Der Server hat keinen gültigen FreeCol-Spielstand geliefert.")
        }
        return data
    }
}

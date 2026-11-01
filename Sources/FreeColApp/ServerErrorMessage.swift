import Foundation
import FreeColClient
import FreeColProtocol

enum ServerErrorMessage {
  static func description(for error: Error) -> String {
    guard let protocolError = error as? FreeColProtocolError else { return error.localizedDescription }
    switch protocolError {
    case .serverError(let raw): return userFacing(raw)
    case .timeout: return "Der Server hat nicht rechtzeitig geantwortet. Bitte den Spielstand prüfen, bevor du die Aktion erneut ausführst."
    case .disconnected: return "Die Verbindung zum Server wurde getrennt."
    default: return protocolError.localizedDescription
    }
  }

  static func userFacing(_ raw: String) -> String {
    ServerRejectMapper.userFacingMessage(forServerMessage: raw)
  }
}

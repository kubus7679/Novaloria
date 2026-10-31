import Foundation
import Network

public enum FreeColProtocolError: Error {
    case parseError(Error?)
    case unknownTag(String)
    case connectionFailed(Error)
    case disconnected
    case timeout
    case serverError(String)
    case invalidState(String)
    case invalidUTF8Message
    case resourceLimitExceeded(String)
}

extension FreeColProtocolError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .parseError(let error):
            return "Parse error: \(error?.localizedDescription ?? "unknown")"
        case .unknownTag(let tag):
            return "Unknown message: \(tag)"
        case .connectionFailed(let error):
            if let nwError = error as? NWError {
                return "Connection failed: \(nwError.debugDescription)"
            }
            return "Connection failed: \(error.localizedDescription)"
        case .disconnected:
            return "Disconnected"
        case .timeout:
            return "Request timed out"
        case .serverError(let msg):
            return "Server error: \(msg)"
        case .invalidState(let msg):
            return "Protocol error: \(msg)"
        case .invalidUTF8Message:
            return "Protocol error: incoming message is not valid UTF-8"
        case .resourceLimitExceeded(let msg):
            return "Protocol resource limit exceeded: \(msg)"
        }
    }
}

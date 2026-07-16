import Foundation

public enum LogLevel: Int, Comparable {
    case error = 0
    case info = 1
    case debug = 2

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public final class FreeColLogger: @unchecked Sendable {
    public static let shared = FreeColLogger()

    public var level: LogLevel = {
        let env = ProcessInfo.processInfo.environment["FREECOL_LOG"]?.lowercased()
        switch env {
        case "error": return .error
        case "info": return .info
        case "debug", "verbose", "trace": return .debug
        default: return .error
        }
    }()

    private let queue = DispatchQueue(label: "freecol-log")

    private init() {}

    public func error(_ message: @autoclosure @Sendable () -> String,
                      file: String = #file, line: Int = #line) {
        log(.error, message(), file: file, line: line)
    }

    public func info(_ message: @autoclosure @Sendable () -> String,
                     file: String = #file, line: Int = #line) {
        log(.info, message(), file: file, line: line)
    }

    public func debug(_ message: @autoclosure @Sendable () -> String,
                      file: String = #file, line: Int = #line) {
        log(.debug, message(), file: file, line: line)
    }

    private func log(_ lvl: LogLevel, _ message: @autoclosure () -> String,
                     file: String, line: Int) {
        guard lvl <= level else { return }
        let ts = DateFormatter.localizedString(
            from: Date(), dateStyle: .none, timeStyle: .medium)
        let f = (file as NSString).lastPathComponent
        queue.sync {
            print("[\(ts)] [\(lvl)] \(f):\(line) \(message())",
                  to: &stderrStream)
        }
    }
}

private var stderrStream = StderrStream()

private struct StderrStream: TextOutputStream {
    mutating func write(_ string: String) {
        FileHandle.standardError.write(Data(string.utf8))
    }
}

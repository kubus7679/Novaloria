import Foundation
import Network

public actor Connection {
    private let host: String
    private let port: Int
    private var connection: NWConnection?
    private var continuation: AsyncStream<String>.Continuation?
    private let stream: AsyncStream<String>
    private var terminalError: Error?
    private var nextReplyId = 0
    private var pending: [Int: CheckedContinuation<ParsedMessage, Error>] = [:]
    private var isDispatching = false
    private var lineFramer = LineFramer()

    public init(host: String = "localhost", port: Int = 3541) {
        self.host = host
        self.port = port
        var cont: AsyncStream<String>.Continuation?
        self.stream = AsyncStream(
            bufferingPolicy: .bufferingOldest(ProtocolLimits.maximumQueuedFrames)
        ) { cont = $0 }
        self.continuation = cont
        FreeColLogger.shared.debug("Connection init \(host):\(port)")
    }

    public func connect() async throws {
        guard let rawPort = UInt16(exactly: port),
              rawPort != 0,
              let networkPort = NWEndpoint.Port(rawValue: rawPort) else {
            throw FreeColProtocolError.invalidState("Port must be between 1 and 65535")
        }
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: networkPort
        )
        FreeColLogger.shared.info("Connecting to \(host):\(port)...")
        let conn = NWConnection(to: endpoint, using: .tcp)
        self.connection = conn

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            conn.stateUpdateHandler = { state in
                FreeColLogger.shared.debug("NWConnection state: \(state)")
                switch state {
                case .ready:
                    cont.resume()
                case .failed(let error):
                    cont.resume(throwing: FreeColProtocolError.connectionFailed(error))
                case .waiting(let error):
                    FreeColLogger.shared.info("NWConnection waiting: \(error)")
                    cont.resume(throwing: FreeColProtocolError.connectionFailed(error))
                default:
                    break
                }
            }
            if conn.state == .ready {
                cont.resume()
                return
            }
            conn.start(queue: .global())
        }

        FreeColLogger.shared.info("Connected to \(host):\(port)")

        // Set a permanent handler for later disconnects
        conn.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            FreeColLogger.shared.debug("NWConnection state (permanent): \(state)")
            switch state {
            case .failed(let error), .waiting(let error):
                Task { await self.handleDisconnect(error) }
            default:
                break
            }
        }

        receiveLoop(conn)
    }

    public func disconnect() {
        FreeColLogger.shared.info("Disconnecting from \(host):\(port)")
        terminalError = FreeColProtocolError.disconnected
        connection?.cancel()
        connection = nil
        continuation?.finish()
        for (_, c) in pending {
            c.resume(throwing: FreeColProtocolError.disconnected)
        }
        pending.removeAll()
    }

    public func send(message: ParsedMessage) async throws {
        let xml = XMLEncoder.encode(
            tag: message.tag,
            attributes: message.attributes,
            children: message.children
        )
        FreeColLogger.shared.debug("Sending <\(message.tag)>")
        try await send(raw: xml)
    }

    public func send(raw xml: String) async throws {
        guard let conn = connection, conn.state == .ready else {
            throw FreeColProtocolError.disconnected
        }
        guard !xml.contains("\n") else {
            throw FreeColProtocolError.invalidState("Protocol messages must be single-line")
        }
        guard xml.utf8.count <= ProtocolLimits.maximumFrameBytes else {
            throw FreeColProtocolError.resourceLimitExceeded(
                "message exceeds \(ProtocolLimits.maximumFrameBytes) bytes"
            )
        }
        var data = Data(xml.utf8)
        data.append(0x0A)
        let frameSize = data.count - 1
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            conn.send(content: data, completion: .contentProcessed { error in
                if let error {
                    FreeColLogger.shared.error("Send failed: \(error)")
                    cont.resume(throwing: FreeColProtocolError.connectionFailed(error))
                } else {
                    FreeColLogger.shared.debug("Sent protocol frame (\(frameSize) bytes)")
                    cont.resume()
                }
            })
        }
    }

    /// Mark whether a central message loop is consuming incoming lines.
    /// When true, `ask` relies on the loop to route `<reply>` messages
    /// instead of reading lines itself (which would race with the loop).
    public func setDispatching(_ value: Bool) {
        isDispatching = value
    }

    public func ask(message: ParsedMessage, timeout: TimeInterval = 30) async throws -> ParsedMessage {
        let replyId = nextReplyId
        nextReplyId += 1

        let question = ParsedMessage(
            tag: "question",
            attributes: ["networkReplyId": "\(replyId)"],
            children: [message]
        )

        FreeColLogger.shared.info("Asking <\(message.tag)> (replyId=\(replyId))")

        if isDispatching {
            // The message loop owns the receive stream. Register a pending
            // continuation and let it resolve the matching <reply>.
            return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<ParsedMessage, Error>) in
                pending[replyId] = cont
                Task {
                    do {
                        try await self.send(message: question)
                    } catch {
                        self.failPending(replyId, error: error)
                    }
                }
                Task {
                    try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    self.failPending(replyId, error: FreeColProtocolError.timeout)
                }
            }
        }

        return try await withThrowingTaskGroup(of: ParsedMessage.self) { group in
            group.addTask {
                try await self.send(message: question)

                while true {
                    let line = try await self.nextLine()
                    let parsed = try XMLDecoder.decode(line)
                    if parsed.tag == "reply",
                       parsed.attributes["networkReplyId"] == "\(replyId)" {
                        if let errorChild = parsed.children.first, errorChild.tag == "error" {
                            let msg = Self.serverErrorText(errorChild)
                            FreeColLogger.shared.error("Server error reply: \(msg)")
                            throw FreeColProtocolError.serverError(msg)
                        }
                        FreeColLogger.shared.info("Got reply for \(replyId)")
                        return parsed
                    }
                    FreeColLogger.shared.debug("Skipping unrelated message <\(parsed.tag)> while waiting for reply \(replyId)")
                }
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                FreeColLogger.shared.error("Timeout waiting for reply \(replyId)")
                throw FreeColProtocolError.timeout
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    /// Resolve a pending `ask` continuation if `parsed` is its `<reply>`.
    /// Returns true when a waiter was released.
    @discardableResult
    public func resolveReply(_ parsed: ParsedMessage) -> Bool {
        guard parsed.tag == "reply",
              let raw = parsed.attributes["networkReplyId"],
              let id = Int(raw),
              let cont = pending.removeValue(forKey: id) else {
            return false
        }
        if let errorChild = parsed.children.first, errorChild.tag == "error" {
            let msg = Self.serverErrorText(errorChild)
            FreeColLogger.shared.error("Server error reply: \(msg)")
            cont.resume(throwing: FreeColProtocolError.serverError(msg))
        } else {
            FreeColLogger.shared.info("Routed reply for \(id)")
            cont.resume(returning: parsed)
        }
        return true
    }

    private static func serverErrorText(_ error: ParsedMessage) -> String {
        if let message = error.attributes["message"], !message.isEmpty { return message }
        return error.children.first(where: { $0.tag == "stringTemplate" })?.attributes["id"]
            ?? "Unknown error"
    }

    private func failPending(_ replyId: Int, error: Error) {
        guard let cont = pending.removeValue(forKey: replyId) else { return }
        cont.resume(throwing: error)
    }

    public func nextLine() async throws -> String {
        for await line in stream {
            FreeColLogger.shared.debug("<<< received protocol frame (\(line.utf8.count) bytes)")
            return line
        }
        FreeColLogger.shared.error("Stream ended (disconnected)")
        throw terminalError ?? FreeColProtocolError.disconnected
    }

    public func nextLine(timeout: TimeInterval) async throws -> String? {
        try await withThrowingTaskGroup(of: String?.self) { group in
            group.addTask {
                try await self.nextLine()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                return nil
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    private func handleDisconnect(_ error: Error) {
        guard terminalError == nil else { return }
        FreeColLogger.shared.error("Connection error: \(error)")
        terminalError = error
        continuation?.finish()
        for (_, c) in pending {
            c.resume(throwing: FreeColProtocolError.connectionFailed(error))
        }
        pending.removeAll()
    }

    private func receiveLoop(_ conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            Task {
                await self.handleReceivedData(data, isComplete: isComplete, error: error, from: conn)
            }
        }
    }

    private func handleReceivedData(
        _ data: Data?,
        isComplete: Bool,
        error: NWError?,
        from conn: NWConnection
    ) {
        if let data, !data.isEmpty {
            FreeColLogger.shared.debug("Received \(data.count) bytes")
            do {
                for line in try lineFramer.append(data) {
                    FreeColLogger.shared.debug(
                        "<<< received protocol frame (\(line.utf8.count) bytes)"
                    )
                    guard enqueue(line, on: conn) else { return }
                }
                let bufferedByteCount = lineFramer.bufferedData.count
                if bufferedByteCount > 0 {
                    FreeColLogger.shared.debug("Buffer retains \(bufferedByteCount) unlined bytes")
                }
            } catch {
                FreeColLogger.shared.error("Invalid incoming frame: \(error.localizedDescription)")
                conn.cancel()
                handleDisconnect(error)
                return
            }
        }

        if isComplete || error != nil {
            do {
                if let finalLine = try lineFramer.finish() {
                    FreeColLogger.shared.debug(
                        "Flushing final protocol frame (\(finalLine.utf8.count) bytes)"
                    )
                    guard enqueue(finalLine, on: conn) else { return }
                }
            } catch {
                FreeColLogger.shared.error("Invalid final frame: \(error.localizedDescription)")
                handleDisconnect(error)
                return
            }
            if let error {
                FreeColLogger.shared.error("Receive error: \(error)")
            }
            FreeColLogger.shared.info("Receive stream ended")
            handleDisconnect(error ?? FreeColProtocolError.disconnected)
            return
        }

        receiveLoop(conn)
    }

    private func enqueue(_ line: String, on conn: NWConnection) -> Bool {
        guard let continuation else {
            let error = FreeColProtocolError.invalidState("Protocol stream is unavailable")
            conn.cancel()
            handleDisconnect(error)
            return false
        }
        switch continuation.yield(line) {
        case .enqueued:
            return true
        case .dropped:
            let error = FreeColProtocolError.resourceLimitExceeded(
                "too many queued protocol frames"
            )
            FreeColLogger.shared.error("Incoming frame queue limit exceeded")
            conn.cancel()
            handleDisconnect(error)
            return false
        case .terminated:
            return false
        @unknown default:
            let error = FreeColProtocolError.invalidState("Unknown protocol stream state")
            conn.cancel()
            handleDisconnect(error)
            return false
        }
    }
}

import Foundation
import Network

public actor Connection {
    private let host: String
    private let port: Int
    private var connection: NWConnection?
    private var continuation: AsyncStream<String>.Continuation?
    private let stream: AsyncStream<String>
    private var nextReplyId = 0
    private var pending: [Int: CheckedContinuation<ParsedMessage, Error>] = [:]
    private var receiveBuffer = ""

    public init(host: String = "localhost", port: Int = 3541) {
        self.host = host
        self.port = port
        var cont: AsyncStream<String>.Continuation?
        self.stream = AsyncStream { cont = $0 }
        self.continuation = cont
        FreeColLogger.shared.debug("Connection init \(host):\(port)")
    }

    public func connect() async throws {
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: UInt16(port))!
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
        let data = Data((xml + "\n").utf8)
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            conn.send(content: data, completion: .contentProcessed { error in
                if let error {
                    FreeColLogger.shared.error("Send failed: \(error)")
                    cont.resume(throwing: FreeColProtocolError.connectionFailed(error))
                } else {
                    FreeColLogger.shared.debug("Sent \(xml.prefix(200))")
                    cont.resume()
                }
            })
        }
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

        return try await withThrowingTaskGroup(of: ParsedMessage.self) { group in
            group.addTask {
                try await self.send(message: question)

                while true {
                    let line = try await self.nextLine()
                    let parsed = try XMLDecoder.decode(line)
                    if parsed.tag == "reply",
                       parsed.attributes["networkReplyId"] == "\(replyId)" {
                        if let errorChild = parsed.children.first, errorChild.tag == "error" {
                            let msg = errorChild.attributes["message"]
                                ?? errorChild.children.first?.attributes["id"]
                                ?? "Unknown error"
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

    public func nextLine() async throws -> String {
        for await line in stream {
            FreeColLogger.shared.debug("<<< \(line.prefix(200))")
            return line
        }
        FreeColLogger.shared.error("Stream ended (disconnected)")
        throw FreeColProtocolError.disconnected
    }

    private func handleDisconnect(_ error: Error) {
        FreeColLogger.shared.error("Connection error: \(error)")
        continuation?.finish()
        for (_, c) in pending {
            c.resume(throwing: FreeColProtocolError.connectionFailed(error))
        }
        pending.removeAll()
    }

    private func receiveLoop(_ conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return }

            if let data, !data.isEmpty {
                let text = String(decoding: data, as: UTF8.self)
                FreeColLogger.shared.debug("Received \(data.count) bytes")
                receiveBuffer += text
                // Yield complete lines (separated by \n), keep remainder in buffer
                var i = receiveBuffer.startIndex
                while true {
                    if let j = receiveBuffer[i...].firstIndex(of: "\n") {
                        let line = String(receiveBuffer[i..<j])
                        FreeColLogger.shared.debug("<<< \(line.prefix(300))")
                        self.continuation?.yield(line)
                        i = receiveBuffer.index(after: j)
                    } else {
                        break
                    }
                }
                receiveBuffer = String(receiveBuffer[i...])
                if !receiveBuffer.isEmpty {
                    FreeColLogger.shared.debug("Buffer retains \(receiveBuffer.count) unlined bytes")
                }
            }

            if isComplete || error != nil {
                // Flush any remaining buffered content
                if !receiveBuffer.isEmpty {
                    FreeColLogger.shared.debug("Flushing final buffer: \(receiveBuffer.prefix(300))")
                    self.continuation?.yield(receiveBuffer)
                    receiveBuffer = ""
                }
                if let error {
                    FreeColLogger.shared.error("Receive error: \(error)")
                }
                FreeColLogger.shared.info("Receive stream ended")
                self.continuation?.finish()
                return
            }

            self.receiveLoop(conn)
        }
    }
}

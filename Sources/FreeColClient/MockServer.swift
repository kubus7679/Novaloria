import Foundation
import FreeColProtocol

public actor MockServer {
    private let serverIOWrapper: ServerIO
    private let stream: AsyncStream<String>
    private var continuation: AsyncStream<String>.Continuation?
    private var pendingMessages: [String] = []

    public var port: Int { serverIOWrapper.port }

    public init() {
        let wrapper = ServerIO()
        self.serverIOWrapper = wrapper
        var cont: AsyncStream<String>.Continuation?
        self.stream = AsyncStream { cont = $0 }
        self.continuation = cont
        FreeColLogger.shared.info("MockServer starting on port ...")
        wrapper.start { [weak self] result in
            Task { await self?.handleClientRead(result) }
        }
    }

    deinit {
        continuation?.finish()
        serverIOWrapper.stop()
    }

    private func handleClientRead(_ result: ServerIO.ReadResult) {
        switch result {
        case .lines(let lines):
            for line in lines {
                FreeColLogger.shared.debug("MockServer <<< \(line.prefix(200))")
                continuation?.yield(line)
            }
        case .disconnected:
            FreeColLogger.shared.info("MockServer client disconnected")
            continuation?.finish()
        }
    }

    public func send(_ xml: String) {
        FreeColLogger.shared.debug("MockServer queuing: \(xml.prefix(200))")
        pendingMessages.append(xml)
    }

    public func flush() {
        let batch = pendingMessages
        pendingMessages.removeAll()
        FreeColLogger.shared.debug("MockServer flushing \(batch.count) messages")
        serverIOWrapper.send(batch)
    }

    public func nextLine() async throws -> String {
        for await line in stream {
            FreeColLogger.shared.debug("MockServer <<< \(line.prefix(200))")
            return line
        }
        throw FreeColProtocolError.disconnected
    }

    public func waitForConnection() async throws {
        FreeColLogger.shared.info("MockServer waiting for client connection...")
        while serverIOWrapper.clientFd < 0 {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        FreeColLogger.shared.info("MockServer client connected (fd=\(serverIOWrapper.clientFd))")
    }

    public func doHandshake(gameResponse: String) async throws {
        try await waitForConnection()
        FreeColLogger.shared.info("MockServer starting handshake")
        send("<gameState state=\"PRE_GAME\"/>")
        send("<vacantPlayers><player id=\"nation-dutch\" nationId=\"model.nation.dutch\" nationName=\"Dutch\"/><player id=\"nation-english\" nationId=\"model.nation.english\" nationName=\"English\"/></vacantPlayers>")
        flush()

        let ql = try await nextLine()
        let q = try XMLDecoder.decode(ql)
        guard q.tag == "question",
              let rid = q.attributes["networkReplyId"],
              let lc = q.children.first, lc.tag == "login" else {
            throw FreeColProtocolError.invalidState("Expected question with login")
        }

        FreeColLogger.shared.info("MockServer received login for user=\(lc.attributes["userName"] ?? "?")")

        let flatGameXML = gameResponse
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined()
        let reply = "<reply networkReplyId=\"\(rid)\"><login userName=\"\(lc.attributes["userName"] ?? "")\" nationId=\"\(lc.attributes["nationId"] ?? "")\" state=\"IN_GAME\">\(flatGameXML)</login></reply>"
        FreeColLogger.shared.debug("MockServer sending login reply")
        send(reply)
        flush()
    }

    public func stop() {
        FreeColLogger.shared.info("MockServer stopping")
        continuation?.finish()
        serverIOWrapper.stop()
    }
}

/// Non-actor, synchronous socket I/O. Runs on a background thread.
final class ServerIO {
    private let listenerFd: Int32
    private var _clientFd: Int32 = -1
    private let queue = DispatchQueue(label: "mock-server-io")
    private var isRunning = false
    private(set) var port: Int = 0

    var clientFd: Int32 { _clientFd }

    enum ReadResult {
        case lines([String])
        case disconnected
    }

    init() {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        precondition(fd >= 0, "socket() failed")
        listenerFd = fd
        var val: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &val, socklen_t(MemoryLayout<Int32>.size))
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = 0
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        let sz = socklen_t(MemoryLayout<sockaddr_in>.size)
        let br = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, sz) }
        }
        precondition(br >= 0, "bind() failed")
        var addrOut = sockaddr_in()
        var addrOutLen = socklen_t(MemoryLayout<sockaddr_in>.size)
        let gsr = withUnsafeMutablePointer(to: &addrOut) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(fd, $0, &addrOutLen) }
        }
        precondition(gsr >= 0, "getsockname() failed")
        port = Int(CFSwapInt16BigToHost(addrOut.sin_port))
        precondition(listen(fd, 1) >= 0, "listen() failed")
    }

    deinit {
        stop()
        if listenerFd >= 0 { close(listenerFd) }
    }

    /// Start accepting connections and reading in the background.
    func start(onRead: @escaping (ReadResult) -> Void) {
        isRunning = true
        queue.async { [weak self] in
            guard let self else { return }
            self.acceptAndReadLoop(onRead: onRead)
        }
    }

    private func acceptAndReadLoop(onRead: @escaping (ReadResult) -> Void) {
        var addr = sockaddr()
        var addrLen = socklen_t(MemoryLayout<sockaddr>.size)
        let cf = withUnsafeMutablePointer(to: &addr) { accept(listenerFd, $0, &addrLen) }
        guard cf >= 0 else { return }
        _clientFd = cf

        // Set non-blocking
        let flags = fcntl(cf, F_GETFL)
        _ = fcntl(cf, F_SETFL, flags | O_NONBLOCK)

        // Read loop
        var buf = [UInt8](repeating: 0, count: 65536)
        while isRunning {
            let n = read(cf, &buf, 65536)
            if n > 0 {
                let text = String(decoding: Data(bytes: buf, count: n), as: UTF8.self)
                let lines = text.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
                if !lines.isEmpty {
                    onRead(.lines(lines))
                }
            } else if n == 0 {
                onRead(.disconnected)
                break
            } else if errno != EAGAIN {
                onRead(.disconnected)
                break
            }
            usleep(50_000) // 50ms poll interval
        }
    }

    func send(_ messages: [String]) {
        guard clientFd >= 0 else { return }
        for xml in messages {
            let data = Data((xml + "\n").utf8)
            _ = data.withUnsafeBytes { write(clientFd, $0.baseAddress, $0.count) }
        }
    }

    func stop() {
        isRunning = false
        if clientFd >= 0 { close(clientFd); _clientFd = -1 }
    }
}

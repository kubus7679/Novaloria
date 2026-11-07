import Foundation
import NovaloriaClient
import FreeColGame
import FreeColProtocol

var passed = 0
var skipped = 0
var failed = 0
let realServerOnly = ProcessInfo.processInfo.environment["FREECOL_CLI_REAL_SERVER_ONLY"] == "1"

struct TestError: Error, CustomStringConvertible {
  let message: String
  var description: String { message }
}

struct ProbeSkipped: Error, CustomStringConvertible {
  let message: String
  var description: String { message }
}

func assertEqual<T: Equatable>(_ a: T, _ b: T) throws {
  if a != b { throw TestError(message: "\(a) != \(b)") }
}

func assertNotNil<T>(_ a: T?) throws {
  if a == nil { throw TestError(message: "nil") }
}

func test(_ name: String, closure: () throws -> Void) {
  guard !realServerOnly else { return }
  do {
    try closure()
    passed += 1
    print("  PASS  \(name)")
  } catch {
    failed += 1
    print("  FAIL  \(name): \(error)")
  }
}

class TestDelegate: ClientDelegate {
  var receivedMessages: [String] = []
  var receivedPayloads: [ParsedMessage] = []
  func clientDidConnect() {}
  func clientDidLogin(_ result: LoginResult) {}
  func clientDidReceiveGameState(_ parsed: ParsedMessage) {
    receivedMessages.append(parsed.tag)
    receivedPayloads.append(parsed)
  }
  func clientDidDisconnect(error: Error?) {}
  func clientDidUpdate() { receivedMessages.append("__update__") }
}

func connectAndLogin(
  _ client: NovaloriaClient,
  userName: String,
  fallbackNationId: String = "model.nation.dutch"
) async throws -> LoginResult {
  try await client.connect()
  let vacantPlayers = await client.initialVacantPlayers
  let nationId =
    vacantPlayers?.children.first?.attributes["nationId"]
    ?? vacantPlayers?.children.first?.attributes["id"]
    ?? fallbackNationId
  return try await client.login(userName: userName, nationId: nationId)
}

func endTurnAndWait(
  client: NovaloriaClient,
  localPlayerId: String,
  maxPolls: Int = 180
) async throws {
  let turnBefore = await client.game.turn.number
  _ = try await client.ask(
    message: ParsedMessage(tag: "endTurn", attributes: [:], children: []),
    timeout: 45
  )
  for _ in 0..<maxPolls {
    let current = await client.game
    if current.turn.number > turnBefore && current.currentPlayerId == localPlayerId {
      return
    }
    try await Task.sleep(nanoseconds: 500_000_000)
  }
  throw TestError(message: "local player's turn did not return after endTurn")
}

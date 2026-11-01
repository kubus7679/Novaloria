import Foundation
import FreeColClient
import FreeColGame
import FreeColProtocol

func integrationTest(_ name: String, closure: @escaping () async throws -> Void) async {
  if realServerOnly && !name.contains("real Java server") { return }
  do {
    try await closure()
    passed += 1
    print("  PASS  \(name)")
  } catch let error as ProbeSkipped {
    skipped += 1
    print("  SKIP  \(name): skipped - \(error)")
  } catch {
    failed += 1
    print("  FAIL  \(name): \(error)")
  }
}

func runIntegrationTests() async {
  print("\n--- Integration Tests ---\n")
  await runClientLifecycleIntegrationTests()
  await runSessionMessageIntegrationTests()
  await runCoreGameplayIntegrationTests()
  await runGameplayActionIntegrationTests()
  await runMessageLoopIntegrationTests()

  await runLegacyE2EProbes()

  // Multiplayer Turn Gating probe: verify turn ownership and endTurn rejection.
  if ProcessInfo.processInfo.environment["REAL_SERVER_MULTIPLAYER_E2E"] == "1" {
    await integrationTest("real Java server multiplayer turn gating probe") {
      try await MultiplayerE2EHarness.runFromEnvironment()
    }
  }

  if ProcessInfo.processInfo.environment["REAL_SERVER_ABANDON_E2E"] == "1" {
    await integrationTest(
      "real Java server colony abandonment probe", closure: abandonColonyE2EProbe)
  }
  if ProcessInfo.processInfo.environment["REAL_SERVER_DISEMBARK_E2E"] == "1" {
    await integrationTest("real Java server disembark probe", closure: disembarkE2EProbe)
  }
  if ProcessInfo.processInfo.environment["REAL_SERVER_SAVE_E2E"] == "1" {
    await integrationTest("real Java server savegame export probe", closure: saveGameE2EProbe)
  }

  // Native Trade E2E probe: verify open, buy, haggle and close against a real native settlement.
  if ProcessInfo.processInfo.environment["REAL_SERVER_NATIVE_TRADE_E2E"] == "1" {
    await integrationTest("real Java server native trade probe", closure: nativeTradeE2EProbe)
  }

  // Diplomacy E2E probe: report a missing asynchronous AI response as a skip.
  if ProcessInfo.processInfo.environment["REAL_SERVER_DIPLOMACY_E2E"] == "1" {
    await integrationTest("real Java server diplomacy probe", closure: diplomacyE2EProbe)
  }
  if ProcessInfo.processInfo.environment["REAL_SERVER_TRIBUTE_E2E"] == "1" {
    await integrationTest("real Java server tribute probe", closure: diplomacyE2EProbe)
  }

  // Combat E2E probe: verify attack on enemy unit and combat result handling.
  if ProcessInfo.processInfo.environment["REAL_SERVER_COMBAT_E2E"] == "1" {
    await integrationTest("real Java server combat probe", closure: combatE2EProbe)
  }

  // Missionary & Spy E2E probe: verify sendMissionary and spySettlement against real targets.
  if ProcessInfo.processInfo.environment["REAL_SERVER_MISSIONARY_SPY_E2E"] == "1" {
    await integrationTest("real Java server missionary & spy probe", closure: missionarySpyE2EProbe)
  }

  // Recruitment E2E probe: verify sail to Europe, recruit, emigrate, purchase and cargo.
  if ProcessInfo.processInfo.environment["REAL_SERVER_RECRUITMENT_E2E"] == "1" {
    await integrationTest("real Java server recruitment probe", closure: recruitmentE2EProbe)
  }
}

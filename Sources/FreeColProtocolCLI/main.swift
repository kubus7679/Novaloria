import Foundation

setbuf(stdout, nil)
print(realServerOnly ? "FreeColProtocol Real-Server Probe" : "FreeColProtocol Tests")
print("=====================")
runOfflineTests()
await runIntegrationTests()
print("\n\(passed) passed, \(skipped) skipped, \(failed) failed")
exit(failed > 0 ? 1 : 0)

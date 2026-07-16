import SwiftUI
import FreeColClient

@main
struct FreeColApp: App {
    @State private var gameState = GameState()

    var body: some Scene {
        WindowGroup {
            Group {
                switch gameState.phase {
                case .disconnected, .connecting:
                    LoginView()
                case .login:
                    LoginView()
                case .inGame:
                    GameView()
                }
            }
            .environment(gameState)
            .frame(minWidth: 500, minHeight: 400)
        }
    }
}

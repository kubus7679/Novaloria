import SwiftUI

/// Local display preferences mirroring the Java client's View options.
struct PreferencesView: View {
    @Environment(GameState.self) private var state
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Einstellungen")
                    .font(.title3.bold())
                Spacer()
                Button("Schließen") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }

            GroupBox("Anzeige") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Kartengitter", isOn: Binding(
                        get: { state.showMapGrid },
                        set: { state.showMapGrid = $0 }
                    ))
                    Toggle("Gebietsgrenzen", isOn: Binding(
                        get: { state.showBorders },
                        set: { state.showBorders = $0 }
                    ))
                    Toggle("Nebel des Krieges", isOn: Binding(
                        get: { state.showFogOfWar },
                        set: { state.showFogOfWar = $0 }
                    ))
                    Toggle("Siedlungsnamen", isOn: Binding(
                        get: { state.showSettlementLabels },
                        set: { state.showSettlementLabels = $0 }
                    ))
                }
                .padding(.vertical, 4)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(minWidth: 380, minHeight: 260)
    }
}

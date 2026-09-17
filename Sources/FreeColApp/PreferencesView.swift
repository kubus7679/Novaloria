import SwiftUI

/// Local display preferences mirroring the Java client's View options.
struct PreferencesView: View {
    @Environment(GameState.self) private var state
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Preferences")
                    .font(.title3.bold())
                Spacer()
                Button("Close") { dismiss() }
            }

            GroupBox("Display") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Map Grid", isOn: Binding(
                        get: { state.showMapGrid },
                        set: { state.showMapGrid = $0 }
                    ))
                    Toggle("Territorial Borders", isOn: Binding(
                        get: { state.showBorders },
                        set: { state.showBorders = $0 }
                    ))
                    Toggle("Fog of War", isOn: Binding(
                        get: { state.showFogOfWar },
                        set: { state.showFogOfWar = $0 }
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

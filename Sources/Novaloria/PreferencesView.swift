import SwiftUI

/// Local display preferences mirroring the Java client's View options.
struct PreferencesView: View {
    @Environment(GameState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @AppStorage(InterfaceLanguage.preferenceKey) private var interfaceLanguage = InterfaceLanguage.system.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.text("Einstellungen", table: "PreferencesView"))
                    .font(.title3.bold())
                Spacer()
                Button(L10n.text("Schließen", table: "PreferencesView")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }

            GroupBox(L10n.text("Sprache", table: "PreferencesView")) {
                Picker(L10n.text("Sprache", table: "PreferencesView"), selection: $interfaceLanguage) {
                    ForEach(InterfaceLanguage.allCases) { language in
                        Text(language == .system ? L10n.text("Systemsprache", table: "PreferencesView") : language.title)
                            .tag(language.rawValue)
                    }
                }
                .pickerStyle(.menu)
            }

            GroupBox(L10n.text("Anzeige", table: "PreferencesView")) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(L10n.text("Kartengitter", table: "PreferencesView"), isOn: Binding(
                        get: { state.showMapGrid },
                        set: { state.showMapGrid = $0 }
                    ))
                    Toggle(L10n.text("Gebietsgrenzen", table: "PreferencesView"), isOn: Binding(
                        get: { state.showBorders },
                        set: { state.showBorders = $0 }
                    ))
                    Toggle(L10n.text("Nebel des Krieges", table: "PreferencesView"), isOn: Binding(
                        get: { state.showFogOfWar },
                        set: { state.showFogOfWar = $0 }
                    ))
                    Toggle(L10n.text("Siedlungsnamen", table: "PreferencesView"), isOn: Binding(
                        get: { state.showSettlementLabels },
                        set: { state.showSettlementLabels = $0 }
                    ))
                }
                .padding(.vertical, 4)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(minWidth: 380, minHeight: 320)
    }
}

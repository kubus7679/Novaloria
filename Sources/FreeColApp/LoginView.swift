import SwiftUI
import FreeColClient

struct LoginView: View {
    private static let fallbackNations: [(id: String, name: String)] = [
        (id: "model.nation.dutch", name: "Dutch"),
        (id: "model.nation.english", name: "English"),
        (id: "model.nation.french", name: "French"),
        (id: "model.nation.spanish", name: "Spanish"),
        (id: "model.nation.portuguese", name: "Portuguese")
    ]

    @Environment(GameState.self) private var state

    @State private var host: String = "localhost"
    @State private var portString: String = "3541"
    @State private var userName: String = "Alice"
    @State private var selectedNation: String = ""
    @State private var nationTypeId: String = "model.nationType.default"
    @State private var playerColorValue: String = "#336699"
    @State private var gameOptionId: String = "model.option.startingMoney"
    @State private var gameOptionValue: String = "3000"
    @State private var mapOptionId: String = "model.option.mapWidth"
    @State private var mapOptionValue: String = "80"
    @State private var foundingFatherId: String = "model.foundingFather.adamSmith"

    private var availableNations: [(id: String, name: String)] {
        guard let vp = state.vacantPlayers else { return Self.fallbackNations }
        let advertisedNations: [(id: String, name: String)] = vp.children.compactMap { child in
            guard child.tag == "player" else { return nil }
            let id = child.attributes["nationId"] ?? child.attributes["id"] ?? ""
            let name = child.attributes["nationName"] ?? id
            return (id: id, name: name)
        }
        return advertisedNations.isEmpty ? Self.fallbackNations : advertisedNations
    }

    private var availableNationIds: [String] {
        availableNations.map(\.id)
    }

    private func syncSelectedNation() {
        let ids = availableNationIds
        guard !ids.isEmpty else {
            selectedNation = ""
            return
        }
        if !ids.contains(selectedNation) {
            selectedNation = ids[0]
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("FreeCol")
                .font(.largeTitle)
                .padding(.top, 20)

            Text("DEBUG phase=\(state.phase.description) serverState=\(state.serverState?.rawValue ?? "nil")")
                .font(.caption)
                .foregroundColor(.orange)

            if case .lobby = state.phase {
                VStack(spacing: 6) {
                    Text("Logged in, waiting for game start…")
                        .foregroundColor(.secondary)
                    Text(state.isReadyToStart ? "Status: Ready" : "Status: Not ready")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(state.isLocalPlayerAdmin ? "Rolle: Admin" : "Rolle: Spieler")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if let err = state.errorMessage {
                Text(err)
                    .foregroundColor(.red)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if case .connecting = state.phase {
                ProgressView(state.statusMessage)
                    .padding()
            }

            GroupBox("Server") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Host:").frame(width: 50, alignment: .trailing)
                        TextField("localhost", text: $host)
                            .textFieldStyle(.roundedBorder)
                            .disabled(state.phase != .disconnected)
                    }
                    HStack {
                        Text("Port:").frame(width: 50, alignment: .trailing)
                        TextField("3541", text: $portString)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                            .disabled(state.phase != .disconnected)
                        Spacer()
                    }
                    HStack(spacing: 12) {
                        if state.phase == .disconnected {
                            Button("Connect") {
                                let p = Int(portString) ?? 3541
                                state.connect(host: host, port: p)
                            }
                            .buttonStyle(.borderedProminent)

                            Button("Local Game") {
                                state.startLocal(userName: userName, nationId: selectedNation)
                            }
                            .buttonStyle(.bordered)
                        } else {
                            Button("Disconnect") {
                                state.disconnect()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            GroupBox("Player") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Name:").frame(width: 50, alignment: .trailing)
                        TextField("Player", text: $userName)
                            .textFieldStyle(.roundedBorder)
                    }
                    HStack {
                        Text("Nation:").frame(width: 50, alignment: .trailing)
                        Picker("Nation", selection: $selectedNation) {
                            ForEach(availableNations, id: \.id) { nation in
                                Text(nation.name).tag(nation.id)
                            }
                        }
                        .onAppear {
                            syncSelectedNation()
                        }
                    }
                    HStack {
                        Text("Type:").frame(width: 50, alignment: .trailing)
                        TextField("model.nationType.default", text: $nationTypeId)
                            .textFieldStyle(.roundedBorder)
                    }
                    HStack {
                        Text("Color:").frame(width: 50, alignment: .trailing)
                        TextField("#336699", text: $playerColorValue)
                            .textFieldStyle(.roundedBorder)
                    }
                    HStack {
                        Text("Opt ID:").frame(width: 50, alignment: .trailing)
                        TextField("model.option.startingMoney", text: $gameOptionId)
                            .textFieldStyle(.roundedBorder)
                    }
                    HStack {
                        Text("Opt Val:").frame(width: 50, alignment: .trailing)
                        TextField("3000", text: $gameOptionValue)
                            .textFieldStyle(.roundedBorder)
                    }
                    HStack {
                        Text("Map ID:").frame(width: 50, alignment: .trailing)
                        TextField("model.option.mapWidth", text: $mapOptionId)
                            .textFieldStyle(.roundedBorder)
                    }
                    HStack {
                        Text("Map Val:").frame(width: 50, alignment: .trailing)
                        TextField("80", text: $mapOptionValue)
                            .textFieldStyle(.roundedBorder)
                    }
                    HStack {
                        Text("Father:").frame(width: 50, alignment: .trailing)
                        TextField("model.foundingFather.adamSmith", text: $foundingFatherId)
                            .textFieldStyle(.roundedBorder)
                    }
                    HStack {
                        Spacer()
                        if state.phase == .login, !selectedNation.isEmpty {
                            Button("Login") {
                                state.login(userName: userName, nationId: selectedNation)
                            }
                            .buttonStyle(.borderedProminent)
                        } else if state.phase == .lobby {
                            Button("Apply Nation") {
                                state.setLocalPlayerNation(selectedNation)
                            }
                            .buttonStyle(.bordered)
                            .disabled(selectedNation.isEmpty)

                            Button("Apply Nation Type") {
                                state.setLocalPlayerNationType(nationTypeId)
                            }
                            .buttonStyle(.bordered)
                            .disabled(nationTypeId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                            Button("Apply Color") {
                                state.setLocalPlayerColor(playerColorValue)
                            }
                            .buttonStyle(.bordered)
                            .disabled(playerColorValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                            Button("Apply Game Option") {
                                state.updateSingleGameOption(id: gameOptionId, value: gameOptionValue)
                            }
                            .buttonStyle(.bordered)
                            .disabled(
                                gameOptionId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                || gameOptionValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            )

                            Button("Apply Map Option") {
                                state.updateSingleMapGeneratorOption(id: mapOptionId, value: mapOptionValue)
                            }
                            .buttonStyle(.bordered)
                            .disabled(
                                mapOptionId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                || mapOptionValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            )

                            Button("Choose Father") {
                                state.chooseFoundingFather(foundingFatherId)
                            }
                            .buttonStyle(.bordered)
                            .disabled(foundingFatherId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                            Button(state.isReadyToStart ? "Unready" : "Ready") {
                                state.setReady(!state.isReadyToStart)
                            }
                            .buttonStyle(.bordered)

                            Button("Start Game") {
                                state.requestLaunch()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!state.isLocalPlayerAdmin)
                        }
                    }
                    if state.phase == .lobby, !state.isLocalPlayerAdmin {
                        Text("Nur der Admin kann das Spiel starten.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }


            Spacer()

            Text("FreeColClient \(AppVersion.displayString)")
                .font(.caption2)
                .foregroundColor(Color(white: 0.45))
        }
        .frame(width: 380)
        .frame(maxHeight: .infinity)
        .padding()
        .onChange(of: availableNationIds) { _, _ in
            syncSelectedNation()
        }
    }
}

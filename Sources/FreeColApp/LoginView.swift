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

    // Persisted so reconnect after a disconnect keeps the last used values.
    @AppStorage("freecol.host") private var host: String = "localhost"
    @AppStorage("freecol.port") private var portString: String = "3541"
    @AppStorage("freecol.userName") private var userName: String = "Alice"
    @State private var selectedNation: String = ""
    @State private var nationTypeId: String = "model.nationType.default"
    @State private var playerColorValue: String = "#336699"
    @State private var gameOptionId: String = "model.option.startingMoney"
    @State private var gameOptionValue: String = "3000"
    @State private var mapOptionId: String = "model.option.mapWidth"
    @State private var mapOptionValue: String = "80"
    @State private var foundingFatherId: String = "model.foundingFather.adamSmith"

    private static let gameOptionPresets: [(id: String, value: String)] = [
        ("model.option.startingMoney", "3000"),
        ("model.option.numPlayers", "4"),
        ("model.option.difficulty", "model.difficulty.medium"),
        ("model.option.giftToAllies", "true"),
        ("model.option.customHouse", "false"),
    ]

    private static let mapOptionPresets: [(id: String, value: String)] = [
        ("model.option.mapWidth", "80"),
        ("model.option.mapHeight", "100"),
        ("model.option.landMass", "model.landMass.normal"),
        ("model.option.mapGenerator", "model.mapGenerator.classic"),
    ]

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

    private var isLobby: Bool { state.phase == .lobby }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .frame(width: 58, alignment: .trailing)
            .fixedSize()
    }

    private func shortOptionId(_ id: String) -> String {
        id.split(separator: ".").last.map(String.init) ?? id
    }

    private func applyButton(_ title: String,
                             disabled: Bool,
                             action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.bordered)
            .controlSize(.small)
            .fixedSize()
            .disabled(disabled)
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 12) {
                Text("FreeCol")
                    .font(.largeTitle)
                    .padding(.top, 20)

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
                        fieldLabel("Name:")
                        TextField("Player", text: $userName)
                            .textFieldStyle(.roundedBorder)
                    }
                    HStack {
                        fieldLabel("Nation:")
                        Picker("Nation", selection: $selectedNation) {
                            ForEach(availableNations, id: \.id) { nation in
                                Text(nation.name).tag(nation.id)
                            }
                        }
                        .onAppear {
                            syncSelectedNation()
                        }
                        if isLobby {
                            applyButton("Apply Nation", disabled: selectedNation.isEmpty) {
                                state.setLocalPlayerNation(selectedNation)
                            }
                        }
                    }
                    HStack {
                        fieldLabel("Type:")
                        TextField("model.nationType.default", text: $nationTypeId)
                            .textFieldStyle(.roundedBorder)
                        if isLobby {
                            applyButton("Apply Type",
                                        disabled: nationTypeId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                                state.setLocalPlayerNationType(nationTypeId)
                            }
                        }
                    }
                    HStack {
                        fieldLabel("Color:")
                        TextField("#336699", text: $playerColorValue)
                            .textFieldStyle(.roundedBorder)
                        if isLobby {
                            applyButton("Apply Color",
                                        disabled: playerColorValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                                state.setLocalPlayerColor(playerColorValue)
                            }
                        }
                    }
                    HStack {
                        fieldLabel("Opt:")
                        TextField("model.option.startingMoney", text: $gameOptionId)
                            .textFieldStyle(.roundedBorder)
                        TextField("3000", text: $gameOptionValue)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 70)
                        Menu("Presets") {
                            ForEach(Self.gameOptionPresets, id: \.id) { preset in
                                Button("\(shortOptionId(preset.id)) = \(preset.value)") {
                                    gameOptionId = preset.id
                                    gameOptionValue = preset.value
                                }
                            }
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                        if isLobby {
                            applyButton("Apply",
                                        disabled: gameOptionId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                            || gameOptionValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                                state.updateSingleGameOption(id: gameOptionId, value: gameOptionValue)
                            }
                        }
                    }
                    if let serverValue = state.serverOptionValue(id: gameOptionId), !serverValue.isEmpty {
                        Text("Server: \(shortOptionId(gameOptionId)) = \(serverValue)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        fieldLabel("Map:")
                        TextField("model.option.mapWidth", text: $mapOptionId)
                            .textFieldStyle(.roundedBorder)
                        TextField("80", text: $mapOptionValue)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 70)
                        Menu("Presets") {
                            ForEach(Self.mapOptionPresets, id: \.id) { preset in
                                Button("\(shortOptionId(preset.id)) = \(preset.value)") {
                                    mapOptionId = preset.id
                                    mapOptionValue = preset.value
                                }
                            }
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                        if isLobby {
                            applyButton("Apply",
                                        disabled: mapOptionId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                            || mapOptionValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                                state.updateSingleMapGeneratorOption(id: mapOptionId, value: mapOptionValue)
                            }
                        }
                    }
                    if let serverValue = state.serverOptionValue(id: mapOptionId), !serverValue.isEmpty {
                        Text("Server: \(shortOptionId(mapOptionId)) = \(serverValue)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        fieldLabel("Father:")
                        TextField("model.foundingFather.adamSmith", text: $foundingFatherId)
                            .textFieldStyle(.roundedBorder)
                        if isLobby {
                            applyButton("Choose",
                                        disabled: foundingFatherId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                                state.chooseFoundingFather(foundingFatherId)
                            }
                        }
                    }

                    if state.phase == .login, !selectedNation.isEmpty {
                        HStack {
                            Spacer()
                            Button("Login") {
                                state.login(userName: userName, nationId: selectedNation)
                            }
                            .buttonStyle(.borderedProminent)
                            Spacer()
                        }
                    }

                    // Ready / Start Game centered below the option fields.
                    if isLobby {
                        HStack {
                            Spacer()
                            Button(state.isReadyToStart ? "Unready" : "Ready") {
                                state.setReady(!state.isReadyToStart)
                            }
                            .buttonStyle(.bordered)

                            Button("Start Game") {
                                state.requestLaunch()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!state.isLocalPlayerAdmin)
                            Spacer()
                        }
                    }
                    if isLobby, !state.isLocalPlayerAdmin {
                        Text("Nur der Admin kann das Spiel starten.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }


            if !state.lobbyPlayers.isEmpty {
                GroupBox("Players") {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(state.lobbyPlayers) { player in
                            HStack(spacing: 8) {
                                Text(player.name ?? player.id)
                                    .font(.caption)
                                    .frame(width: 90, alignment: .leading)
                                    .foregroundColor(player.id == state.localPlayerId ? .yellow : .primary)
                                Text(shortOptionId(player.nationId ?? "—"))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .frame(width: 90, alignment: .leading)
                                Text(player.playerType == .european ? (player.ai ? "AI" : "Human") : player.playerType.rawValue)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .frame(width: 60, alignment: .leading)
                                if player.admin {
                                    Text("Admin")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                }
                                Spacer()
                                Text(player.ready ? "Ready" : "Not ready")
                                    .font(.caption2)
                                    .foregroundColor(player.ready ? .green : .secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Text("FreeColClient \(AppVersion.displayString)")
                .font(.caption2)
                .foregroundColor(Color(white: 0.45))
                .padding(.top, 8)
                .padding(.bottom, 12)
            }
            .frame(width: 460)
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: availableNationIds) { _, _ in
            syncSelectedNation()
        }
    }
}

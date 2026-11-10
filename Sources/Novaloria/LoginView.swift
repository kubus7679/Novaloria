import SwiftUI
import NovaloriaClient
import FreeColProtocol

// MARK: - LoginView

struct LoginView: View {
    static let backgroundImage: NSImage? = {
        guard let url = Bundle.module.url(forResource: "lobby-background", withExtension: "jpg"),
              let image = NSImage(contentsOf: url) else {
            FreeColLogger.shared.error("Lobby background resource could not be loaded")
            return nil
        }
        return image
    }()

    // Fallback-Völker für den Fall, dass keine Serverdaten verfügbar sind
    private static var fallbackNations: [(id: String, name: String, description: String)] {
        [
            (id: "model.nation.dutch", name: L10n.text("Niederländer", table: "LoginView"), description: L10n.text("+10% Handel, ideal für Kaufleute", table: "LoginView")),
            (id: "model.nation.english", name: L10n.text("Engländer", table: "LoginView"), description: L10n.text("Ausgewogen, gut für Anfänger", table: "LoginView")),
            (id: "model.nation.french", name: L10n.text("Franzosen", table: "LoginView"), description: L10n.text("+Kultur, bessere Beziehungen zu Eingeborenen", table: "LoginView")),
            (id: "model.nation.spanish", name: L10n.text("Spanier", table: "LoginView"), description: L10n.text("+Militär, aber langsamer Bau", table: "LoginView")),
            (id: "model.nation.portuguese", name: L10n.text("Portugiesen", table: "LoginView"), description: L10n.text("+Erkundung, schnellere Schiffe", table: "LoginView"))
        ]
    }

    // Verfügbare Farben mit deutschen Namen
    private static var playerColors: [(id: String, name: String)] {
        [
            (id: "#FF0000", name: L10n.text("Rot", table: "LoginView")),
            (id: "#00FF00", name: L10n.text("Grün", table: "LoginView")),
            (id: "#0000FF", name: L10n.text("Blau", table: "LoginView")),
            (id: "#FFFF00", name: L10n.text("Gelb", table: "LoginView")),
            (id: "#FF00FF", name: L10n.text("Magenta", table: "LoginView")),
            (id: "#00FFFF", name: L10n.text("Cyan", table: "LoginView")),
            (id: "#FFFFFF", name: L10n.text("Weiß", table: "LoginView")),
            (id: "#000000", name: L10n.text("Schwarz", table: "LoginView")),
            (id: "#FF8000", name: L10n.text("Orange", table: "LoginView")),
            (id: "#8000FF", name: L10n.text("Lila", table: "LoginView")),
            (id: "#336699", name: L10n.text("Dunkelblau", table: "LoginView")),
            (id: "#996633", name: L10n.text("Braun", table: "LoginView")),
            (id: "#CC9900", name: L10n.text("Gold", table: "LoginView")),
            (id: "#669966", name: L10n.text("Olive", table: "LoginView")),
            (id: "#FF6699", name: L10n.text("Rosa", table: "LoginView"))
        ]
    }

    @Environment(GameState.self) private var state

    // Gespeicherte Einstellungen (persistiert)
    @AppStorage("freecol.host") private var host: String = "localhost"
    @AppStorage("freecol.port") private var portString: String = "3541"
    @AppStorage("freecol.userName") private var userName: String = "Alice"
    @AppStorage("freecol.showAdvancedOptions") private var showAdvancedOptions: Bool = false
    @AppStorage(InterfaceLanguage.preferenceKey) private var interfaceLanguage = InterfaceLanguage.system.rawValue

    // Spielerauswahl
    @State private var selectedNation: String = ""
    @State private var selectedColor: String = "#336699"

    // Erweiterte Optionen (vorselektioniert)
    @State private var startingMoneyValue: String = "3000"
    @State private var showNewGame = false
    @State private var showLoadSavegame = false

    // Berechnete Eigenschaften
    private var availableNations: [(id: String, name: String, description: String)] {
        if isLobby {
            var ids = state.availableLobbyNationIds
            if let current = state.localPlayer?.nationId, !ids.contains(current) {
                ids.append(current)
            }
            return ids.sorted().map { id in
                (id: id, name: GameLabels.name(id),
                 description: Self.fallbackNations.first { $0.id == id }?.description ?? "")
            }
        }
        guard let vp = state.vacantPlayers else { return Self.fallbackNations }
        let advertisedNations: [(id: String, name: String, description: String)] = vp.children.compactMap { child in
            guard child.tag == "player" else { return nil }
            let id = child.attributes["nationId"] ?? child.attributes["id"] ?? ""
            let name = child.attributes["nationName"] ?? id
            // Beschreibungen für Fallback-Nationen verwenden
            let description = Self.fallbackNations.first { $0.id == id }?.description ?? ""
            return (id: id, name: name, description: description)
        }
        return advertisedNations.isEmpty ? Self.fallbackNations : advertisedNations
    }

    private var availableNationIds: [String] {
        availableNations.map(\.id)
    }

    private var validPort: Int? {
        guard let port = Int(portString), (1...65_535).contains(port) else { return nil }
        return port
    }

    private var isLobby: Bool { state.phase == .lobby }

    private var validStartingMoney: Int? {
        guard let value = Int(startingMoneyValue), (0...Int(Int32.max)).contains(value) else { return nil }
        return value
    }

    private var readyButtonTitle: String {
        state.isReadyToStart
            ? L10n.text("Nicht bereit", table: "LoginView")
            : L10n.text("Bereit", table: "LoginView")
    }

    private func hostedSavegameMessage(_ name: String) -> String {
        L10n.text(
            "Spielstand „\(name)“ läuft auf diesem Mac. Melde dich mit dem Namen eines menschlichen Spielers aus dem Spielstand an.",
            table: "LoginView"
        )
    }

    @ViewBuilder
    private var lobbyControls: some View {
        GroupBox {
            HStack {
                Spacer()
                Button {
                    state.setReady(!state.isReadyToStart)
                } label: {
                    Text(readyButtonTitle)
                }
                .buttonStyle(.bordered)
                .tint(state.isReadyToStart ? .orange : .green)

                if state.isLocalPlayerAdmin {
                    Button(L10n.text("Spiel starten", table: "LoginView")) {
                        state.requestLaunch()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
                Spacer()
            }
            .padding(.vertical, 8)

            if !state.isLocalPlayerAdmin {
                Text(L10n.text("Nur der Administrator kann das Spiel starten.", table: "LoginView"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
        }
        .groupBoxStyle(FreeColGroupBoxStyle())
    }

    // Synchronisiert die ausgewählte Nation mit den verfügbaren Optionen
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

    // Hilfsfunktion: Kürzt eine ID für die Anzeige
    private func shortOptionId(_ id: String) -> String {
        id.split(separator: ".").last.map(String.init) ?? id
    }

    // Hilfsfunktion: Erstellt einen standardisierten Label-Text
    private func labelText(_ text: String) -> some View {
        Text(text)
            .frame(width: 100, alignment: .trailing)
            .fixedSize()
    }

    // Hilfsfunktion: Erstellt einen Button mit einheitlichem Stil
    private func actionButton(_ title: String,
                             disabled: Bool = false,
                             action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.bordered)
            .controlSize(.small)
            .fixedSize()
            .disabled(disabled)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            backgroundLayer
            ScrollView(.vertical) {
                VStack(spacing: 16) {
                    loginHeader
                    statusMessages
                    serverConnectionPanel
                    playerCharacterPanel
                    advancedOptionsPanel
                    if isLobby { lobbyControls }
                    lobbyPlayersPanel
                    versionLabel
                }
                .frame(width: 500)
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $showNewGame) {
            NewGameView { port in
                host = "127.0.0.1"
                portString = String(port)
            }
            .environment(state)
        }
        .sheet(isPresented: $showLoadSavegame) {
            LoadSavegameView { port in
                host = "127.0.0.1"
                portString = String(port)
            }
            .environment(state)
        }
        .onChange(of: availableNationIds) { _, _ in
            syncSelectedNation()
        }
        .onChange(of: state.localPlayer?.nationId) { _, nationId in
            if isLobby, let nationId {
                selectedNation = nationId
            }
        }
        .onAppear {
            if selectedNation.isEmpty, let firstNation = availableNationIds.first {
                selectedNation = firstNation
            }
        }
    }

    private var backgroundLayer: some View {
        ZStack {
            Color(red: 0.08, green: 0.07, blue: 0.06).ignoresSafeArea()
            if let backgroundImage = Self.backgroundImage {
                GeometryReader { geometry in
                    Image(nsImage: backgroundImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .overlay {
                            LinearGradient(
                                colors: [
                                    Color(red: 0.08, green: 0.07, blue: 0.06).opacity(0.72),
                                    Color.black.opacity(0.28),
                                    Color(red: 0.08, green: 0.07, blue: 0.06).opacity(0.78)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
    }

    private var loginHeader: some View {
        VStack(spacing: 5) {
            Image(systemName: "sailboat.fill")
                .font(.system(size: 25))
                .foregroundStyle(Color(red: 0.88, green: 0.71, blue: 0.39))
                .padding(.bottom, 2)
            Text(L10n.text("novaloria", table: "LoginView"))
                .font(.system(size: 42, weight: .bold, design: .serif))
                .foregroundStyle(Color(red: 0.98, green: 0.94, blue: 0.84))
            Text(L10n.text("EINE NEUE WELT ERWARTET DICH", table: "LoginView"))
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .tracking(2.4)
                .foregroundStyle(Color(red: 0.88, green: 0.71, blue: 0.39))
            languagePicker
        }
        .shadow(color: .black.opacity(0.55), radius: 8, y: 3)
        .padding(.top, 28)
        .padding(.bottom, 4)
    }

    private var languagePicker: some View {
        Picker(L10n.text("Sprache", table: "LoginView"), selection: $interfaceLanguage) {
            ForEach(InterfaceLanguage.allCases) { language in
                Text(language == .system ? L10n.text("Systemsprache", table: "LoginView") : language.title)
                    .tag(language.rawValue)
            }
        }
        .pickerStyle(.menu)
        .frame(maxWidth: 180)
    }

    @ViewBuilder
    private var statusMessages: some View {
        if case .lobby = state.phase {
            VStack(spacing: 6) {
                Text(L10n.text("Angemeldet – Warten auf Spielstart…", table: "LoginView"))
                    .foregroundColor(.secondary)
                Text(L10n.text(state.isReadyToStart ? "Status: Bereit" : "Status: Nicht bereit", table: "LoginView"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(L10n.text(state.isLocalPlayerAdmin ? "Rolle: Administrator" : "Rolle: Spieler", table: "LoginView"))
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
                .padding(8)
                .background(Color(.controlBackgroundColor).opacity(0.8))
                .cornerRadius(8)
        }
        if case .connecting = state.phase {
            ProgressView(state.statusMessage)
                .progressViewStyle(.linear)
                .tint(.white)
                .padding()
        }
    }

    private var serverConnectionPanel: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.text("🌍 Serververbindung", table: "LoginView"))
                    .font(.headline)
                    .foregroundColor(.white)
                serverSettings
                gameCreationButtons
                connectionButtons
                hostedServerLogs
                securityNotice
            }
            .padding(.vertical, 4)
        }
        .groupBoxStyle(FreeColGroupBoxStyle())
    }

    @ViewBuilder
    private var serverSettings: some View {
        if state.phase == .disconnected {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    labelText(L10n.text("Server-Adresse:", table: "LoginView"))
                    TextField(L10n.text("localhost", table: "LoginView"), text: $host)
                        .textFieldStyle(.roundedBorder)
                        .help(L10n.text("Die IP oder URL des Spielservers (z. B. 'localhost' für lokalen Server).", table: "LoginView"))
                }
                HStack {
                    labelText(L10n.text("Port:", table: "LoginView"))
                    TextField(L10n.text("3541", table: "LoginView"), text: $portString)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                        .help(L10n.text("Die Netzwerk-Portnummer des Servers (Standard: 3541).", table: "LoginView"))
                    Spacer()
                }
                if validPort == nil {
                    Text(L10n.text("Bitte gib einen Port zwischen 1 und 65535 ein.", table: "LoginView"))
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        } else {
            Text(L10n.text("Server: \(host):\(portString)", table: "LoginView"))
                .font(.callout)
        }
    }

    @ViewBuilder
    private var gameCreationButtons: some View {
        if state.phase == .disconnected || isLobby {
            HStack(spacing: 12) {
                Button(L10n.text("Neues Spiel erstellen…", table: "LoginView"), systemImage: "plus.circle") {
                    showNewGame = true
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.72, green: 0.48, blue: 0.19))
                Button(L10n.text("Spielstand laden…", table: "LoginView"), systemImage: "square.and.arrow.down") {
                    showLoadSavegame = true
                }
                .buttonStyle(.bordered)
                .tint(Color(red: 0.88, green: 0.71, blue: 0.39))
            }
        }
    }

    private var connectionButtons: some View {
        HStack(spacing: 12) {
            if state.phase == .disconnected {
                Button(L10n.text("Verbinden", table: "LoginView"), systemImage: "globe") {
                    guard let validPort else { return }
                    state.connect(host: host, port: validPort)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.72, green: 0.48, blue: 0.19))
                .disabled(validPort == nil)

                Button(L10n.text("Lokales Spiel", table: "LoginView"), systemImage: "desktopcomputer") {
                    guard let validStartingMoney else { return }
                    state.setGameOption("model.option.startingMoney", value: String(validStartingMoney))
                    state.startLocal(userName: userName, nationId: selectedNation)
                }
                .buttonStyle(.bordered)
                .tint(Color(red: 0.88, green: 0.71, blue: 0.39))
                .disabled(validStartingMoney == nil || selectedNation.isEmpty)
            } else {
                Button(L10n.text("Verbindung trennen", table: "LoginView"), systemImage: "arrow.left") {
                    state.disconnect()
                }
                .buttonStyle(.bordered)
                .tint(.orange)
            }
        }
    }

    @ViewBuilder
    private var hostedServerLogs: some View {
        if let directory = state.hostedGameDirectory {
            HStack {
                Text(L10n.text("Optionen und Serverprotokolle:", table: "LoginView"))
                Button(L10n.text("Im Finder zeigen", table: "LoginView")) {
                    NSWorkspace.shared.open(directory)
                }
            }
            .font(.caption)
        }
    }

    private var securityNotice: some View {
        Label(
            L10n.text("Hinweis: Verbindung ist unverschlüsselt. Nutze sie nur in vertrauenswürdigen Netzwerken.", table: "LoginView"),
            systemImage: "lock.open"
        )
        .font(.caption)
        .foregroundStyle(.orange)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var playerCharacterPanel: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.text("👤 Dein Spielcharakter", table: "LoginView"))
                    .font(.headline)
                    .foregroundColor(.white)
                playerNameRow
                nationRow
                playerColorRow
                hostedSavegameInfo
                loginButton
            }
            .padding(.vertical, 4)
        }
        .groupBoxStyle(FreeColGroupBoxStyle())
    }

    private var playerNameRow: some View {
        HStack {
            labelText(L10n.text("Dein Name:", table: "LoginView"))
            if state.phase == .disconnected || state.phase == .login {
                TextField(L10n.text("Spielername", table: "LoginView"), text: $userName)
                    .textFieldStyle(.roundedBorder)
                    .help(L10n.text("Dein Spielername im Spiel (wird von anderen Spielern gesehen).", table: "LoginView"))
            } else {
                Text(state.localPlayer?.name ?? userName)
            }
        }
    }

    private var nationRow: some View {
        HStack {
            labelText(L10n.text("Volk:", table: "LoginView"))
            nationSelection
        }
    }

    @ViewBuilder
    private var nationSelection: some View {
        if state.phase == .disconnected || state.phase == .login
            || (isLobby && !state.availableLobbyNationIds.isEmpty) {
            HStack {
                Picker("", selection: $selectedNation) {
                    ForEach(availableNations, id: \.id) { nation in
                        Text(nation.name).tag(nation.id)
                    }
                }
                .pickerStyle(.menu)
                .onAppear(perform: syncSelectedNation)
                .help(L10n.text("Wähle eines der verfügbaren Völker.", table: "LoginView"))

                if let selected = availableNations.first(where: { $0.id == selectedNation }) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.gray)
                        .help(selected.description)
                }

                if isLobby, state.availableLobbyNationIds.contains(selectedNation),
                   selectedNation != state.localPlayer?.nationId {
                    actionButton(L10n.text("Übernehmen", table: "LoginView")) {
                        state.setLocalPlayerNation(selectedNation)
                    }
                }
            }
        } else {
            Text(GameLabels.name(state.localPlayer?.nationId ?? selectedNation))
        }
    }

    @ViewBuilder
    private var playerColorRow: some View {
        if isLobby, state.localPlayer?.nationId != nil {
            HStack {
                labelText(L10n.text("Farbe:", table: "LoginView"))
                Picker("", selection: $selectedColor) {
                    ForEach(Self.playerColors, id: \.id) { color in
                        Text(color.name).tag(color.id)
                    }
                }
                .pickerStyle(.menu)
                .help(L10n.text("Wähle die Farbe deiner Einheiten auf der Karte.", table: "LoginView"))
                Color(hex: selectedColor)
                    .frame(width: 24, height: 24)
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.white, lineWidth: 1)
                    )
                actionButton(L10n.text("Übernehmen", table: "LoginView"), disabled: selectedColor.isEmpty) {
                    state.setLocalPlayerColor(selectedColor)
                }
            }
        }
    }

    @ViewBuilder
    private var hostedSavegameInfo: some View {
        if state.phase == .login, let savegameName = state.hostedSavegameName {
            Text(hostedSavegameMessage(savegameName))
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var loginButton: some View {
        if state.phase == .login, !selectedNation.isEmpty {
            HStack {
                Spacer()
                Button(L10n.text("Anmelden", table: "LoginView"), systemImage: "person.crop.circle") {
                    state.login(userName: userName, nationId: selectedNation)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                Spacer()
            }
        }
    }

    @ViewBuilder
    private var advancedOptionsPanel: some View {
        if state.phase == .disconnected {
            DisclosureGroup(isExpanded: $showAdvancedOptions) {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            labelText(L10n.text("Startkapital:", table: "LoginView"))
                            TextField(L10n.text("Gold", table: "LoginView"), text: $startingMoneyValue)
                                .textFieldStyle(.roundedBorder)
                                .help(L10n.text("Wie viel Gold du zu Spielbeginn erhältst. Mehr Gold = schnellerer Start.", table: "LoginView"))
                        }
                        Text(L10n.text("Startkapital in Gold. Empfohlener Wert: 3000-5000 für Anfänger.", table: "LoginView"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 102)
                    }
                    Text(L10n.text("Gilt nur für „Lokales Spiel“ (Mock-Start). Bei einer Serververbindung legt der Server Startgold, Karte und Spielregeln fest.", table: "LoginView"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if validStartingMoney == nil {
                        Text(L10n.text("Bitte einen ganzzahligen Goldbetrag zwischen 0 und 2147483647 eingeben.", table: "LoginView"))
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            } label: {
                Text(L10n.text("🔧 Optionen für lokales Spiel", table: "LoginView"))
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .groupBoxStyle(FreeColGroupBoxStyle())
        }
    }

    @ViewBuilder
    private var lobbyPlayersPanel: some View {
        if !state.lobbyPlayers.isEmpty {
            GroupBox {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.text("👥 Spieler in der Lobby", table: "LoginView"))
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.bottom, 4)
                    ForEach(state.lobbyPlayers) { player in
                        let type = player.playerType == .european
                            ? L10n.text(player.ai ? "KI" : "Mensch", table: "LoginView")
                            : player.playerType.rawValue
                        LoginLobbyPlayerRow(
                            name: player.name ?? player.id,
                            nation: shortOptionId(player.nationId ?? "—"),
                            type: type,
                            isLocalPlayer: player.id == state.localPlayerId,
                            isAdmin: player.admin,
                            isReady: player.ready
                        )
                    }
                }
                .padding(.vertical, 4)
            }
            .groupBoxStyle(FreeColGroupBoxStyle())
        }
    }

    private var versionLabel: some View {
        Text(L10n.text("Novaloria \(AppVersion.displayString)", table: "LoginView"))
            .font(.caption2)
            .foregroundColor(Color(white: 0.6))
            .padding(.top, 8)
            .padding(.bottom, 12)
    }
}

private struct LoginLobbyPlayerRow: View {
    let name: String
    let nation: String
    let type: String
    let isLocalPlayer: Bool
    let isAdmin: Bool
    let isReady: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(name)
                .font(.caption)
                .frame(width: 90, alignment: .leading)
                .foregroundColor(isLocalPlayer ? .yellow : .primary)
            Text(nation)
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 90, alignment: .leading)
            Text(type)
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
            if isAdmin {
                Text(L10n.text("Admin", table: "LoginView"))
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
            Spacer()
            Text(L10n.text(isReady ? "Bereit" : "Nicht bereit", table: "LoginView"))
                .font(.caption2)
                .foregroundColor(isReady ? .green : .secondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - GroupBox-Stil für FreeCol

struct FreeColGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            configuration.label
                .padding(.leading, 4)
            configuration.content
                .padding()
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 0.12, green: 0.105, blue: 0.085).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(red: 0.78, green: 0.62, blue: 0.34).opacity(0.55), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.24), radius: 10, y: 4)
    }
}

// MARK: - Hilfsfunktionen für Farben

fileprivate extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

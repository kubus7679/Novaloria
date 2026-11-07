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
    private static let fallbackNations: [(id: String, name: String, description: String)] = [
        (id: "model.nation.dutch", name: "Niederländer", description: "+10% Handel, ideal für Kaufleute"),
        (id: "model.nation.english", name: "Engländer", description: "Ausgewogen, gut für Anfänger"),
        (id: "model.nation.french", name: "Franzosen", description: "+Kultur, bessere Beziehungen zu Eingeborenen"),
        (id: "model.nation.spanish", name: "Spanier", description: "+Militär, aber langsamer Bau"),
        (id: "model.nation.portuguese", name: "Portugiesen", description: "+Erkundung, schnellere Schiffe")
    ]

    // Verfügbare Farben mit deutschen Namen
    private static let playerColors: [(id: String, name: String)] = [
        (id: "#FF0000", name: "Rot"),
        (id: "#00FF00", name: "Grün"),
        (id: "#0000FF", name: "Blau"),
        (id: "#FFFF00", name: "Gelb"),
        (id: "#FF00FF", name: "Magenta"),
        (id: "#00FFFF", name: "Cyan"),
        (id: "#FFFFFF", name: "Weiß"),
        (id: "#000000", name: "Schwarz"),
        (id: "#FF8000", name: "Orange"),
        (id: "#8000FF", name: "Lila"),
        (id: "#336699", name: "Dunkelblau"),
        (id: "#996633", name: "Braun"),
        (id: "#CC9900", name: "Gold"),
        (id: "#669966", name: "Olive"),
        (id: "#FF6699", name: "Rosa")
    ]

    @Environment(GameState.self) private var state

    // Gespeicherte Einstellungen (persistiert)
    @AppStorage("freecol.host") private var host: String = "localhost"
    @AppStorage("freecol.port") private var portString: String = "3541"
    @AppStorage("freecol.userName") private var userName: String = "Alice"
    @AppStorage("freecol.showAdvancedOptions") private var showAdvancedOptions: Bool = false

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

    // MARK: - Körper der View

    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.07, blue: 0.06)
                .ignoresSafeArea()
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

            ScrollView(.vertical) {
                VStack(spacing: 16) {
                    VStack(spacing: 5) {
                        Image(systemName: "sailboat.fill")
                            .font(.system(size: 25))
                            .foregroundStyle(Color(red: 0.88, green: 0.71, blue: 0.39))
                            .padding(.bottom, 2)
                        Text("novaloria")
                            .font(.system(size: 42, weight: .bold, design: .serif))
                            .foregroundStyle(Color(red: 0.98, green: 0.94, blue: 0.84))
                        Text("EINE NEUE WELT ERWARTET DICH")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .tracking(2.4)
                            .foregroundStyle(Color(red: 0.88, green: 0.71, blue: 0.39))
                    }
                    .shadow(color: .black.opacity(0.55), radius: 8, y: 3)
                    .padding(.top, 28)
                    .padding(.bottom, 4)

                    // Statusmeldungen (Lobby, Verbindung, Fehler)
                    if case .lobby = state.phase {
                        VStack(spacing: 6) {
                            Text("Angemeldet – Warten auf Spielstart…")
                                .foregroundColor(.secondary)
                            Text(state.isReadyToStart ? "Status: Bereit" : "Status: Nicht bereit")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(state.isLocalPlayerAdmin ? "Rolle: Administrator" : "Rolle: Spieler")
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

                    // ============================================
                    // SERVERVERBINDUNG (Standard)
                    // ============================================
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("🌍 Serververbindung")
                                .font(.headline)
                                .foregroundColor(.white)

                            if state.phase == .disconnected {
                                HStack {
                                    labelText("Server-Adresse:")
                                    TextField("localhost", text: $host)
                                        .textFieldStyle(.roundedBorder)
                                        .help("Die IP oder URL des Spielservers (z. B. 'localhost' für lokalen Server).")
                                }

                                HStack {
                                    labelText("Port:")
                                    TextField("3541", text: $portString)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 100)
                                        .help("Die Netzwerk-Portnummer des Servers (Standard: 3541).")
                                    Spacer()
                                }

                                if validPort == nil {
                                    Text("Bitte gib einen Port zwischen 1 und 65535 ein.")
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                            } else {
                                Text("Server: \(host):\(portString)")
                                    .font(.callout)
                            }

                            // Verbindungsbuttons
                            if state.phase == .disconnected || isLobby {
                                HStack(spacing: 12) {
                                    Button("Neues Spiel erstellen…", systemImage: "plus.circle") {
                                        showNewGame = true
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(Color(red: 0.72, green: 0.48, blue: 0.19))

                                    Button("Spielstand laden…", systemImage: "square.and.arrow.down") {
                                        showLoadSavegame = true
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(Color(red: 0.88, green: 0.71, blue: 0.39))
                                }
                            }
                            HStack(spacing: 12) {
                                if state.phase == .disconnected {
                                    Button(action: {
                                        guard let validPort else { return }
                                        state.connect(host: host, port: validPort)
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "globe")
                                            Text("Verbinden")
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(Color(red: 0.72, green: 0.48, blue: 0.19))
                                    .disabled(validPort == nil)

                                    Button(action: {
                                        guard let validStartingMoney else { return }
                                        // Setze Spieloptionen für lokales Spiel
                                        state.setGameOption("model.option.startingMoney", value: String(validStartingMoney))
                                        state.startLocal(userName: userName, nationId: selectedNation)
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "desktopcomputer")
                                            Text("Lokales Spiel")
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(Color(red: 0.88, green: 0.71, blue: 0.39))
                                    .disabled(validStartingMoney == nil || selectedNation.isEmpty)
                                } else {
                                    Button(action: {
                                        state.disconnect()
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "arrow.left")
                                            Text("Verbindung trennen")
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.orange)
                                }
                            }

                            if let directory = state.hostedGameDirectory {
                                HStack {
                                    Text("Optionen und Serverprotokolle:")
                                    Button("Im Finder zeigen") { NSWorkspace.shared.open(directory) }
                                }
                                .font(.caption)
                            }

                            // Sicherheitshinweis
                            Label(
                                "Hinweis: Verbindung ist unverschlüsselt. Nutze sie nur in vertrauenswürdigen Netzwerken.",
                                systemImage: "lock.open"
                            )
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 4)
                    }
                    .groupBoxStyle(FreeColGroupBoxStyle())

                    // ============================================
                    // SPIELCHARAKTER (Standard)
                    // ============================================
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("👤 Dein Spielcharakter")
                                .font(.headline)
                                .foregroundColor(.white)

                            // Name
                            HStack {
                                labelText("Dein Name:")
                                if state.phase == .disconnected || state.phase == .login {
                                    TextField("Spielername", text: $userName)
                                        .textFieldStyle(.roundedBorder)
                                        .help("Dein Spielername im Spiel (wird von anderen Spielern gesehen).")
                                } else {
                                    Text(state.localPlayer?.name ?? userName)
                                }
                            }

                            // Volk
                            HStack {
                                labelText("Volk:")
                                if state.phase == .disconnected || state.phase == .login
                                    || (isLobby && !state.availableLobbyNationIds.isEmpty) {
                                    Picker("", selection: $selectedNation) {
                                        ForEach(availableNations, id: \.id) { nation in
                                            Text(nation.name).tag(nation.id)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .onAppear {
                                        syncSelectedNation()
                                    }
                                    .help("Wähle eines der verfügbaren Völker.")

                                    if let selected = availableNations.first(where: { $0.id == selectedNation }) {
                                        Image(systemName: "info.circle")
                                            .foregroundColor(.gray)
                                            .help(selected.description)
                                    }

                                    if isLobby, state.availableLobbyNationIds.contains(selectedNation),
                                       selectedNation != state.localPlayer?.nationId {
                                        actionButton("Übernehmen") {
                                            state.setLocalPlayerNation(selectedNation)
                                        }
                                    }
                                } else {
                                    Text(GameLabels.name(state.localPlayer?.nationId ?? selectedNation))
                                }
                            }

                            // Farbe
                            if isLobby, state.localPlayer?.nationId != nil {
                                HStack {
                                    labelText("Farbe:")
                                    Picker("", selection: $selectedColor) {
                                        ForEach(Self.playerColors, id: \.id) { color in
                                            Text(color.name).tag(color.id)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .help("Wähle die Farbe deiner Einheiten auf der Karte.")

                                    Color(hex: selectedColor)
                                        .frame(width: 24, height: 24)
                                        .cornerRadius(4)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(Color.white, lineWidth: 1)
                                        )

                                    actionButton("Übernehmen", disabled: selectedColor.isEmpty) {
                                        state.setLocalPlayerColor(selectedColor)
                                    }
                                }
                            }

                            if state.phase == .login, let savegameName = state.hostedSavegameName {
                                Text("Spielstand „\(savegameName)“ läuft auf diesem Mac. Melde dich mit dem Namen eines menschlichen Spielers aus dem Spielstand an.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            // Anmeldebutton (nur in Login-Phase)
                            if state.phase == .login, !selectedNation.isEmpty {
                                HStack {
                                    Spacer()
                                    Button(action: {
                                        state.login(userName: userName, nationId: selectedNation)
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "person.crop.circle")
                                            Text("Anmelden")
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.green)
                                    Spacer()
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .groupBoxStyle(FreeColGroupBoxStyle())

                    // ============================================
                    // ERWEITERTE OPTIONEN (ausklappbar)
                    // ============================================
                    if state.phase == .disconnected {
                        DisclosureGroup(isExpanded: $showAdvancedOptions) {
                            VStack(alignment: .leading, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        labelText("Startkapital:")
                                        TextField("Gold", text: $startingMoneyValue)
                                            .textFieldStyle(.roundedBorder)
                                            .help("Wie viel Gold du zu Spielbeginn erhältst. Mehr Gold = schnellerer Start.")
                                    }
                                    Text("Startkapital in Gold. Empfohlener Wert: 3000-5000 für Anfänger.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 102)
                                }

                                Text("Gilt nur für „Lokales Spiel“ (Mock-Start). Bei einer Serververbindung legt der Server Startgold, Karte und Spielregeln fest.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                if validStartingMoney == nil {
                                    Text("Bitte einen ganzzahligen Goldbetrag zwischen 0 und 2147483647 eingeben.")
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                            }
                        } label: {
                            Text("🔧 Optionen für lokales Spiel")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .groupBoxStyle(FreeColGroupBoxStyle())
                    }

                    // ============================================
                    // LOBBY-STEUERUNG (falls in Lobby)
                    // ============================================
                    if isLobby {
                        GroupBox {
                            HStack {
                                Spacer()
                                Button(state.isReadyToStart ? "Nicht bereit" : "Bereit") {
                                    state.setReady(!state.isReadyToStart)
                                }
                                .buttonStyle(.bordered)
                                .tint(state.isReadyToStart ? .orange : .green)

                                if state.isLocalPlayerAdmin {
                                    Button("Spiel starten") {
                                        state.requestLaunch()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.blue)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 8)

                            if !state.isLocalPlayerAdmin {
                                Text("Nur der Administrator kann das Spiel starten.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.top, 4)
                            }
                        }
                        .groupBoxStyle(FreeColGroupBoxStyle())
                    }

                    // ============================================
                    // SPIELERLISTE (falls in Lobby)
                    // ============================================
                    if !state.lobbyPlayers.isEmpty {
                        GroupBox {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("👥 Spieler in der Lobby")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                    .padding(.bottom, 4)

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

                                        Text(player.playerType == .european ? (player.ai ? "KI" : "Mensch") : player.playerType.rawValue)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .frame(width: 60, alignment: .leading)

                                        if player.admin {
                                            Text("Admin")
                                                .font(.caption2)
                                                .foregroundColor(.blue)
                                        }

                                        Spacer()

                                        Text(player.ready ? "Bereit" : "Nicht bereit")
                                            .font(.caption2)
                                            .foregroundColor(player.ready ? .green : .secondary)
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .groupBoxStyle(FreeColGroupBoxStyle())
                    }

                    // Versionsinfo
                    Text("Novaloria \(AppVersion.displayString)")
                        .font(.caption2)
                        .foregroundColor(Color(white: 0.6))
                        .padding(.top, 8)
                        .padding(.bottom, 12)
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
            // Standard-Nation setzen, falls leer
            if selectedNation.isEmpty, let firstNation = availableNationIds.first {
                selectedNation = firstNation
            }
        }
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

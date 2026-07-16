import SwiftUI
import FreeColClient

private let nations: [(name: String, id: String)] = [
    ("Dutch", "model.nation.dutch"),
    ("English", "model.nation.english"),
    ("French", "model.nation.french"),
    ("Spanish", "model.nation.spanish"),
    ("Portuguese", "model.nation.portuguese"),
    ("Swedish", "model.nation.swedish"),
    ("Russian", "model.nation.russian"),
    ("Danish", "model.nation.danish"),
    ("German", "model.nation.german"),
]

struct LoginView: View {
    @Environment(GameState.self) private var state

    @State private var host: String = "localhost"
    @State private var portString: String = "3541"
    @State private var userName: String = "Alice"
    @State private var selectedNation: String = "model.nation.dutch"

    var body: some View {
        VStack(spacing: 12) {
            Text("FreeCol")
                .font(.largeTitle)
                .padding(.top, 20)

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
                        Button("Connect") {
                            let p = Int(portString) ?? 3541
                            state.connect(host: host, port: p)
                        }
                        .disabled(state.phase != .disconnected)
                        .buttonStyle(.borderedProminent)

                        Button("Local Game") {
                            state.startLocal(userName: userName, nationId: selectedNation)
                        }
                        .disabled(state.phase != .disconnected)
                        .buttonStyle(.bordered)
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
                            ForEach(nations, id: \.id) { nation in
                                Text(nation.name).tag(nation.id)
                            }
                        }
                    }
                    HStack {
                        Spacer()
                        if case .login = state.phase {
                            Button("Login") {
                                state.login(userName: userName, nationId: selectedNation)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Spacer()
        }
        .frame(width: 380)
        .frame(maxHeight: .infinity)
        .padding()
    }
}

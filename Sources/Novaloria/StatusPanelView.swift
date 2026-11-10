import SwiftUI
import FreeColGame

/// Game status / statistics overview (Java `StatusPanel` / `StatisticsPanel`).
struct StatusPanelView: View {
    @Environment(GameState.self) private var state
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.text("Spielstatus", table: "StatusPanelView"))
                    .font(.title2.bold())
                Spacer()
                Button(L10n.text("Schließen", table: "StatusPanelView")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }

            ScrollView([.horizontal, .vertical]) {
                VStack(alignment: .leading, spacing: 12) {
            if let game = state.game {
                GroupBox(L10n.text("Spiel", table: "StatusPanelView")) {
                    VStack(alignment: .leading, spacing: 4) {
                        row("Spielkennung", game.id)
                        row(L10n.text("Runde", table: "StatusPanelView"), "\(game.turn.number)")
                        row(L10n.text("Aktueller Spieler", table: "StatusPanelView"), game.players[game.currentPlayerId ?? ""]?.name ?? "—")
                        row(L10n.text("Spieler", table: "StatusPanelView"), "\(game.players.count)")
                        row(L10n.text("Kolonien", table: "StatusPanelView"), "\(game.colonies.count)")
                        row(L10n.text("Einheiten", table: "StatusPanelView"), "\(game.units.count)")
                        if !game.tiles.isEmpty {
                            let explored = game.exploredTileIds().count
                            let total = game.tiles.count
                            let percent = total > 0 ? Int(Double(explored) / Double(total) * 100) : 0
                             row(L10n.text("Erkundet", table: "StatusPanelView"), "\(explored) / \(total) (\(percent)%)")
                        }
                    }
                    .padding(.vertical, 4)
                }

                GroupBox(L10n.text("Spieler", table: "StatusPanelView")) {
                    playerTable(game: game)
                        .padding(.vertical, 4)
                }

                GroupBox(L10n.text("Eigener Spieler", table: "StatusPanelView")) {
                    if let local = state.localPlayer {
                        VStack(alignment: .leading, spacing: 4) {
                            row(L10n.text("Name", table: "StatusPanelView"), local.name ?? local.id)
                            row(L10n.text("Gold", table: "StatusPanelView"), "\(local.gold)")
                            row("Steuern", "\(local.tax)%")
                            row(L10n.text("Einwanderung", table: "StatusPanelView"), "\(local.immigration)")
                            row(L10n.text("Freiheit", table: "StatusPanelView"), "\(local.liberty)")
                            row(L10n.text("Punkte", table: "StatusPanelView"), "\(local.score)")
                            row(L10n.text("Gründerväter", table: "StatusPanelView"), "\(local.foundingFathers.count)")
                            row("Spielmeldungen", "\(local.modelMessages.count)")
                        }
                        .padding(.vertical, 4)
                    } else {
                        Text(L10n.text("Kein eigener Spieler.", table: "StatusPanelView"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text(L10n.text("Kein Spiel geladen.", table: "StatusPanelView"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .frame(minWidth: 640, idealWidth: 720,
               minHeight: 400, idealHeight: 640, maxHeight: 760)
    }

    @ViewBuilder
    private func playerTable(game: Game) -> some View {
        let players = state.lobbyPlayers
        if players.isEmpty {
            Text(L10n.text("Keine Spieler.", table: "StatusPanelView"))
                .font(.caption)
                .foregroundColor(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 0) {
                    Text(L10n.text("Spieler", table: "StatusPanelView")).frame(width: 110, alignment: .leading)
                    Text(L10n.text("Nation", table: "StatusPanelView")).frame(width: 90, alignment: .leading)
                    Text(L10n.text("Typ", table: "StatusPanelView")).frame(width: 150, alignment: .leading)
                    Text(L10n.text("Gold", table: "StatusPanelView")).frame(width: 60, alignment: .trailing)
                    Text(L10n.text("Punkte", table: "StatusPanelView")).frame(width: 50, alignment: .trailing)
                    Text(L10n.text("Einheiten", table: "StatusPanelView")).frame(width: 45, alignment: .trailing)
                    Text(L10n.text("Kolonien", table: "StatusPanelView")).frame(width: 60, alignment: .trailing)
                }
                .font(.caption2.bold())
                .foregroundColor(.secondary)

                ForEach(players) { player in
                    let units = game.units.values.filter { $0.owner == player.id }.count
                    let colonies = game.colonies.values.filter { $0.owner == player.id }.count
                    HStack(spacing: 0) {
                        Text(player.name ?? player.id)
                            .frame(width: 110, alignment: .leading)
                            .foregroundColor(player.id == state.localPlayerId ? .yellow : .primary)
                        Text(short(player.nationId, prefix: "model.nation."))
                            .frame(width: 90, alignment: .leading)
                        Text(playerTypeLabel(player))
                            .frame(width: 150, alignment: .leading)
                        Text("\(player.gold)")
                            .frame(width: 60, alignment: .trailing)
                        Text("\(player.score)")
                            .frame(width: 50, alignment: .trailing)
                        Text("\(units)")
                            .frame(width: 45, alignment: .trailing)
                        Text("\(colonies)")
                            .frame(width: 60, alignment: .trailing)
                    }
                    .font(.caption)
                }
            }
        }
    }

    private func playerTypeLabel(_ player: Player) -> String {
        switch player.playerType {
        case .indian: return L10n.text("Ureinwohner", table: "StatusPanelView")
        case .ref: return L10n.text("Königliche Expeditionsstreitkräfte", table: "StatusPanelView")
        case .undead: return L10n.text("Untot", table: "StatusPanelView")
        case .european: return player.ai ? "KI" : "Mensch"
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .font(.caption)
        }
    }

    private func short(_ value: String?, prefix: String) -> String {
        guard let value else { return "—" }
        return value.hasPrefix(prefix) ? String(value.dropFirst(prefix.count)) : value
    }
}

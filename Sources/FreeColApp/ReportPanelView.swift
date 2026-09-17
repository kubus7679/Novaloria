import SwiftUI
import FreeColGame
import FreeColProtocol

/// Report identifiers mirroring the Java client's `Report*Panel` set.
enum ReportKind: String, CaseIterable, Identifiable {
    case colonies
    case unitTypes
    case military
    case naval
    case cargo
    case trade
    case foreignAffairs
    case indian
    case exploration
    case turn
    case highScores
    case financial

    var id: String { rawValue }

    var title: String {
        switch self {
        case .colonies: return "Colonies"
        case .unitTypes: return "Units"
        case .military: return "Military"
        case .naval: return "Naval"
        case .cargo: return "Cargo"
        case .trade: return "Trade"
        case .foreignAffairs: return "Foreign Affairs"
        case .indian: return "Indian"
        case .exploration: return "Exploration"
        case .turn: return "Turn"
        case .highScores: return "High Scores"
        case .financial: return "Financial"
        }
    }
}

/// Read-only report browser derived from the current game model.
struct ReportPanelView: View {
    @Environment(GameState.self) private var state
    @Environment(\.dismiss) private var dismiss

    @State private var selected: ReportKind = .colonies

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(ReportKind.allCases) { kind in
                    Button {
                        selected = kind
                    } label: {
                        Text(kind.title)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(selected == kind ? Color.accentColor.opacity(0.25) : Color.clear)
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .frame(width: 160)
            .padding(8)

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(selected.title)
                        .font(.title3.bold())
                    Spacer()
                    Button("Close") { dismiss() }
                }
                ScrollView {
                    reportBody
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
            .padding(16)
        }
        .frame(minWidth: 620, minHeight: 420)
        .onAppear {
            if let requested = state.requestedReport {
                selected = requested
            }
        }
    }

    @ViewBuilder
    private var reportBody: some View {
        switch selected {
        case .colonies: coloniesReport
        case .unitTypes: unitTypesReport
        case .military: unitFilterReport(naval: false)
        case .naval: unitFilterReport(naval: true)
        case .cargo: cargoReport
        case .trade: tradeReport
        case .foreignAffairs: foreignReport
        case .indian: indianReport
        case .exploration: explorationReport
        case .turn: turnReport
        case .highScores: highScoresReport
        case .financial: financialReport
        }
    }

    // MARK: - Helpers

    private var game: Game? { state.game }
    private var localPlayerId: String? { state.localPlayerId }

    private func shortName(_ value: String?, prefix: String) -> String {
        guard let value else { return "?" }
        return value.hasPrefix(prefix) ? String(value.dropFirst(prefix.count)) : value
    }

    private var ownColonies: [Colony] {
        guard let game, let localPlayerId else { return [] }
        return game.colonies.values
            .filter { $0.owner == localPlayerId }
            .sorted { ($0.name ?? "") < ($1.name ?? "") }
    }

    private var ownUnits: [FreeColGame.Unit] {
        guard let game, let localPlayerId else { return [] }
        return game.units.values
            .filter { $0.owner == localPlayerId }
            .sorted { ($0.unitType ?? "") < ($1.unitType ?? "") }
    }

    private func isNaval(_ unit: FreeColGame.Unit) -> Bool {
        if let info = game?.specification?.unitTypes[unit.unitType ?? ""] {
            return info.isNaval
        }
        return Specification.fallbackLineOfSight(forUnitType: unit.unitType) > 1
    }

    // MARK: - Reports

    private var coloniesReport: some View {
        GroupBox {
            if ownColonies.isEmpty {
                empty("No colonies.")
            } else {
                table(
                    headers: ["Name", "Pop", "SoL", "Liberty", "Bonus"],
                    widths: [160, 50, 50, 70, 60],
                    rows: ownColonies.map { colony in
                        [
                            colony.name ?? "?",
                            "\(colony.unitCount)",
                            "\(colony.sonsOfLiberty)",
                            "\(colony.liberty)",
                            "\(colony.productionBonus)"
                        ]
                    }
                )
            }
        }
    }

    private var unitTypesReport: some View {
        let grouped = Dictionary(grouping: ownUnits) { $0.unitType ?? "?" }
        let rows = grouped
            .map { ($0.key, $0.value.count) }
            .sorted { $0.0 < $1.0 }
        return GroupBox {
            if rows.isEmpty {
                empty("No units.")
            } else {
                table(
                    headers: ["Unit Type", "Count"],
                    widths: [240, 60],
                    rows: rows.map { [shortName($0.0, prefix: "model.unit."), "\($0.1)"] }
                )
            }
        }
    }

    private func unitFilterReport(naval: Bool) -> some View {
        let units = ownUnits.filter { isNaval($0) == naval }
        return GroupBox {
            if units.isEmpty {
                empty(naval ? "No naval units." : "No military units.")
            } else {
                table(
                    headers: ["Unit", "State", "MP", "Location"],
                    widths: [200, 90, 40, 160],
                    rows: units.map { unit in
                        [
                            shortName(unit.unitType, prefix: "model.unit."),
                            unit.state.rawValue,
                            "\(unit.movesLeft)",
                            unit.location ?? "-"
                        ]
                    }
                )
            }
        }
    }

    private var cargoReport: some View {
        let carriers = ownUnits.filter { carrier in
            ownUnits.contains { $0.id != carrier.id && $0.location == carrier.id }
        }
        return GroupBox {
            if carriers.isEmpty {
                empty("No cargo carriers.")
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(carriers) { carrier in
                        let cargo = ownUnits.filter { $0.location == carrier.id }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(shortName(carrier.unitType, prefix: "model.unit.")) (\(cargo.count))")
                                .font(.caption.bold())
                            if cargo.isEmpty {
                                Text("empty")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            } else {
                                Text(cargo.map { shortName($0.unitType, prefix: "model.unit.") }
                                    .joined(separator: ", "))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var tradeReport: some View {
        GroupBox {
            if let market = state.localPlayer?.market, !market.data.isEmpty {
                let rows = market.data.values
                    .sorted { ($0.goodsType ?? "") < ($1.goodsType ?? "") }
                    .map { entry in
                        let prices = state.marketPrices(for: entry.goodsType)
                        return [
                            shortName(entry.goodsType, prefix: "model.goods."),
                            "\(entry.amount)",
                            "\(prices.costToBuy)",
                            "\(prices.paidForSale)",
                            "\(entry.arrears)"
                        ]
                    }
                table(headers: ["Goods", "In stock", "Buy", "Sell", "Arrears"],
                      widths: [160, 70, 50, 50, 70], rows: rows)
            } else {
                empty("No market data.")
            }
        }
    }

    private var financialReport: some View {
        let player = state.localPlayer
        let arrears = state.localPlayerMarketData.reduce(0) { $0 + $1.arrears }
        let rows: [[String]] = [
            ["Gold", "\(player?.gold ?? 0)"],
            ["Tax rate", "\(player?.tax ?? 0)%"],
            ["Arrears", "\(arrears)"],
            ["Recruits purchased", "\(state.purchasesRecruits)"],
            ["Units trained", "\(state.purchasesTrained)"],
            ["Total purchases", "\(state.purchasesTotal)"],
            ["Total sales", "\(state.salesTotal)"],
            ["Net balance", "\(state.purchasesNetProfit)"],
        ]
        return GroupBox {
            table(headers: ["Item", "Value"], widths: [220, 120], rows: rows)
        }
    }

    private var foreignReport: some View {
        guard let game, let localPlayerId else { return AnyView(empty("No game.")) }
        let others = game.players.values
            .filter { $0.id != localPlayerId && $0.playerType == .european }
            .sorted { ($0.name ?? "") < ($1.name ?? "") }
        let local = game.players[localPlayerId]
        return AnyView(GroupBox {
            if others.isEmpty {
                empty("No other European powers.")
            } else {
                table(
                    headers: ["Player", "Nation", "Stance", "Gold", "Score"],
                    widths: [140, 150, 100, 70, 60],
                    rows: others.map { player in
                        [
                            player.name ?? "?",
                            shortName(player.nationId, prefix: "model.nation."),
                            local?.stances[player.id]?.rawValue ?? "UNCONTACTED",
                            "\(player.gold)",
                            "\(player.score)"
                        ]
                    }
                )
            }
        })
    }

    private var indianReport: some View {
        guard let game else { return AnyView(empty("No game.")) }
        let indians = game.players.values
            .filter { $0.playerType == .indian }
            .sorted { ($0.name ?? "") < ($1.name ?? "") }
        let settlements = game.colonies.values
            .filter { $0.settlementType?.lowercased().contains("indian") == true
                || $0.settlementType?.lowercased().contains("native") == true }
        return AnyView(GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                if indians.isEmpty {
                    empty("No native peoples.")
                } else {
                    table(
                        headers: ["People", "Nation", "Stance"],
                        widths: [160, 160, 110],
                        rows: indians.map { player in
                            [
                                player.name ?? "?",
                                shortName(player.nationId, prefix: "model.nation."),
                                game.players[state.localPlayerId ?? ""]?.stances[player.id]?.rawValue ?? "UNCONTACTED"
                            ]
                        }
                    )
                }
                if !settlements.isEmpty {
                    Text("Known settlements: \(settlements.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        })
    }

    private var explorationReport: some View {
        GroupBox {
            if let game {
                let explored = game.exploredTileIds().count
                let total = game.tiles.count
                let percent = total > 0 ? Int(Double(explored) / Double(total) * 100) : 0
                VStack(alignment: .leading, spacing: 6) {
                    row("Explored tiles", "\(explored) / \(total)")
                    row("Explored", "\(percent)%")
                }
            } else {
                empty("No map.")
            }
        }
    }

    private var turnReport: some View {
        GroupBox {
            if let game {
                VStack(alignment: .leading, spacing: 6) {
                    row("Turn", "\(game.turn.number)")
                    row("Current player", game.players[game.currentPlayerId ?? ""]?.name ?? "-")
                    if let local = state.localPlayer {
                        row("Your gold", "\(local.gold)")
                        row("Your tax", "\(local.tax)%")
                        row("Your score", "\(local.score)")
                    }
                }
            } else {
                empty("No game.")
            }
        }
    }

    private var highScoresReport: some View {
        GroupBox {
            if let report = state.highScoresReport {
                let entries = report.children.filter { $0.tag == "highScore" }
                if entries.isEmpty {
                    empty("No entries.")
                } else {
                    table(
                        headers: ["Player", "Nation", "Score", "Units", "Colonies"],
                        widths: [140, 120, 70, 60, 80],
                        rows: entries.map { entry in
                            [
                                entry.attributes["playerName"] ?? "?",
                                entry.attributes["nationName"] ?? entry.attributes["nationId"] ?? "?",
                                entry.attributes["score"] ?? "?",
                                entry.attributes["units"] ?? "?",
                                entry.attributes["colonies"] ?? "?"
                            ]
                        }
                    )
                }
            } else {
                empty("No high scores available.")
            }
        }
    }

    // MARK: - Building blocks

    private func table(headers: [String], widths: [Double], rows: [[String]]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 0) {
                ForEach(Array(headers.enumerated()), id: \.offset) { index, header in
                    Text(header)
                        .frame(width: CGFloat(widths[index]), alignment: .leading)
                }
            }
            .font(.caption2.bold())
            .foregroundColor(.secondary)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { index, value in
                        Text(value)
                            .frame(width: CGFloat(widths[min(index, widths.count - 1)]), alignment: .leading)
                            .lineLimit(1)
                    }
                }
                .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
        }
    }

    private func empty(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.vertical, 4)
    }
}

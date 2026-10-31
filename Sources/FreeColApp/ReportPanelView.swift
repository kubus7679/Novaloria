import SwiftUI
import FreeColGame
import FreeColProtocol
import AppKit

private struct ReportTableSnapshot: Equatable {
    let headers: [String]
    let rows: [[String]]
}

private struct ReportTablePreferenceKey: PreferenceKey {
    static var defaultValue: [ReportTableSnapshot] = []

    static func reduce(value: inout [ReportTableSnapshot],
                       nextValue: () -> [ReportTableSnapshot]) {
        value.append(contentsOf: nextValue())
    }
}

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
    case continentalCongress
    case labour
    case religious
    case production
    case education
    case requirements
    case history

    var id: String { rawValue }

    var title: String {
        switch self {
        case .colonies: return "Kolonien"
        case .unitTypes: return "Einheiten"
        case .military: return "Militär"
        case .naval: return "Flotte"
        case .cargo: return "Fracht"
        case .trade: return "Handel"
        case .foreignAffairs: return "Außenpolitik"
        case .indian: return "Ureinwohner"
        case .exploration: return "Erkundung"
        case .turn: return "Zugbericht"
        case .highScores: return "Bestenliste"
        case .financial: return "Finanzen"
        case .continentalCongress: return "Kontinentalkongress"
        case .labour: return "Arbeit"
        case .religious: return "Religion"
        case .production: return "Produktion"
        case .education: return "Ausbildung"
        case .requirements: return "Bedarf"
        case .history: return "Geschichte"
        }
    }
}

/// Read-only report browser derived from the current game model.
struct ReportPanelView: View {
    @Environment(GameState.self) private var state
    @Environment(\.dismiss) private var dismiss

    @State private var selected: ReportKind = .colonies
    @State private var summaryPlayerId: String = ""
    @State private var searchText = ""
    @State private var sortAscending = true
    @State private var tableSnapshots: [ReportTableSnapshot] = []
    @State private var exportError: String?

    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
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
            }
            .frame(width: 176)

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(selected.title)
                        .font(.title3.bold())
                    TextField("Filter rows", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 220)
                    Button(sortAscending ? "Sort ↑" : "Sort ↓") {
                        sortAscending.toggle()
                    }
                    .help("Sort rows by the first column")
                    Button("Export CSV…") {
                        exportCSV()
                    }
                    .disabled(tableSnapshots.isEmpty)
                    Spacer()
                    Button("Close") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
                ScrollView([.horizontal, .vertical]) {
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
        .onPreferenceChange(ReportTablePreferenceKey.self) {
            tableSnapshots = $0
        }
        .alert("CSV export failed", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("OK") { exportError = nil }
        } message: {
            Text(exportError ?? "")
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
        case .continentalCongress: continentalCongressReport
        case .labour: labourReport
        case .religious: religiousReport
        case .production: productionReport
        case .education: educationReport
        case .requirements: requirementsReport
        case .history: historyReport
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
                        return VStack(alignment: .leading, spacing: 2) {
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
            VStack(alignment: .leading, spacing: 10) {
                if others.isEmpty {
                    empty("No other European powers.")
                } else {
                    table(
                        headers: ["Player", "Nation", "Stance", "Tension", "Gold", "Score"],
                        widths: [130, 140, 100, 70, 70, 60],
                        rows: others.map { player in
                            [
                                player.name ?? "?",
                                shortName(player.nationId, prefix: "model.nation."),
                                local?.stances[player.id]?.rawValue ?? "UNCONTACTED",
                                "\(local?.tension[player.id] ?? 0)",
                                "\(player.gold)",
                                "\(player.score)"
                            ]
                        }
                    )
                }

                Divider()
                Text("Nation Summary")
                    .font(.caption.bold())
                HStack {
                    Picker("Player", selection: $summaryPlayerId) {
                        Text("Select…").tag("")
                        ForEach(others) { player in
                            Text(player.name ?? player.id).tag(player.id)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 200)
                    Button("Request") { state.requestNationSummary(playerId: summaryPlayerId) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(summaryPlayerId.isEmpty)
                }
                if let summary = state.nationSummaryReport {
                    let attrs = summary.attributes
                    table(
                        headers: ["Settlements", "Units", "Military", "Naval", "Gold", "SoL", "Fathers"],
                        widths: [80, 60, 70, 60, 60, 50, 60],
                        rows: [[
                            attrs["numberOfSettlements"] ?? "?",
                            attrs["numberOfUnits"] ?? "?",
                            attrs["militaryStrength"] ?? "?",
                            attrs["navalStrength"] ?? "?",
                            attrs["gold"] ?? "?",
                            attrs["SoL"] ?? "?",
                            attrs["foundingFathers"] ?? "?"
                        ]]
                    )
                }
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
                if let local = state.localPlayer, !local.bannedMissions.isEmpty {
                    Text("Missions banned by: \(local.bannedMissions.map { game.players[$0]?.name ?? $0 }.sorted().joined(separator: ", "))")
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
                    let messages = state.localPlayerModelMessages
                    if !messages.isEmpty {
                        Divider()
                        Text("Events")
                            .font(.caption.bold())
                        ForEach(Array(messages.suffix(8).reversed().enumerated()),
                                id: \.offset) { _, message in
                            Text("• \(message.label)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else {
                empty("No game.")
            }
        }
    }

    private var highScoresReport: some View {
        GroupBox {
            HStack {
                Spacer()
                Button("Request from Server") { state.requestHighScores() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
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

    private var continentalCongressReport: some View {
        let fathers = state.localPlayerFoundingFathers
        let offered = state.localPlayerOfferedFathers
        let current = state.localPlayerCurrentFather
        return GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                if let current {
                    row("In progress", state.foundingFatherDisplayName(current))
                }
                if fathers.isEmpty && offered.isEmpty && current == nil {
                    empty("No founding fathers yet.")
                } else {
                    if !fathers.isEmpty {
                        Text("In Congress (\(fathers.count))")
                            .font(.caption.bold())
                        table(headers: ["Founding Father"], widths: [260],
                              rows: fathers.map { [state.foundingFatherDisplayName($0)] })
                    }
                    if !offered.isEmpty {
                        Text("Offered")
                            .font(.caption.bold())
                        table(headers: ["Founding Father"], widths: [260],
                              rows: offered.map { [state.foundingFatherDisplayName($0)] })
                    }
                }
            }
        }
    }

    private var labourReport: some View {
        let colonies = state.localColonies
        return GroupBox {
            if colonies.isEmpty {
                empty("No colonies.")
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(colonies) { colony in
                        let workers = state.colonyWorkerUnits(colony)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(colony.name ?? colony.id) (\(workers.count))")
                                .font(.caption.bold())
                            if workers.isEmpty {
                                empty("No workers.")
                            } else {
                                table(headers: ["Unit", "Work", "Location"],
                                      widths: [140, 120, 150],
                                      rows: workers.map { unit in
                                          [
                                            unit.unitType.map { shortName($0, prefix: "model.unit.") } ?? unit.id,
                                            unit.workType.map { shortName($0, prefix: "model.goods.") } ?? "—",
                                            unit.location ?? "—"
                                          ]
                                      })
                            }
                        }
                    }
                }
            }
        }
    }

    private var religiousReport: some View {
        let missionaries = state.missionaryUnits
        let settlements = state.game?.colonies.values.filter {
            $0.settlementType?.lowercased().contains("indian") == true
        } ?? []
        return GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                row("Missionaries", "\(missionaries.count)")
                row("Native settlements", "\(settlements.count)")
                if missionaries.isEmpty {
                    empty("No missionaries.")
                } else {
                    table(headers: ["Unit", "Location"], widths: [180, 160],
                          rows: missionaries.map {
                              [$0.unitType.map { shortName($0, prefix: "model.unit.") } ?? $0.id,
                               $0.location ?? "—"]
                          })
                }
            }
        }
    }

    private var productionReport: some View {
        let colonies = state.localColonies
        return GroupBox {
            if colonies.isEmpty {
                empty("No colonies.")
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(colonies) { colony in
                        let production = state.colonyProductionSummary(colony)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(colony.name ?? colony.id)
                                .font(.caption.bold())
                            if production.isEmpty {
                                empty("No estimated production.")
                            } else {
                                table(headers: ["Goods", "Per turn"],
                                      widths: [180, 80],
                                      rows: production.map { [$0.label, "\($0.amount)"] })
                            }
                        }
                    }
                }
            }
        }
    }

    private var educationReport: some View {
        let assignments = state.educationAssignments
        return GroupBox {
            if assignments.isEmpty {
                empty("No education in progress.")
            } else {
                table(headers: ["Student", "Teacher", "Colony"],
                      widths: [150, 150, 140],
                      rows: assignments.map { unit in
                          [
                            unit.unitType.map { shortName($0, prefix: "model.unit.") } ?? unit.id,
                            unit.teacher.map { shortName($0, prefix: "model.unit.") } ?? "—",
                            unit.location ?? "—"
                          ]
                      })
            }
        }
    }

    private var requirementsReport: some View {
        let colonies = state.localColonies
        return GroupBox {
            if colonies.isEmpty {
                empty("No colonies.")
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(colonies) { colony in
                        if let requirements = state.colonyBuildRequirements(colony) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(colony.name ?? colony.id) → \(requirements.target)")
                                    .font(.caption.bold())
                                if requirements.items.isEmpty {
                                    empty("No material requirements.")
                                } else {
                                    table(headers: ["Goods", "Stored", "Required"],
                                          widths: [160, 70, 80],
                                          rows: requirements.items.map {
                                              [$0.label, "\($0.stored)", "\($0.required)"]
                                          })
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var historyReport: some View {
        let messages = state.localPlayerModelMessages
        return GroupBox {
            if messages.isEmpty {
                empty("No events recorded.")
            } else {
                table(headers: ["Event", "Source", "Type"],
                      widths: [220, 120, 100],
                      rows: messages.reversed().map {
                          [$0.label, $0.source ?? "—", $0.messageType ?? "—"]
                      })
            }
        }
    }

    // MARK: - Building blocks

    private func table(headers: [String], widths: [Double], rows: [[String]]) -> some View {
        let filteredRows = rows.filter { row in
            searchText.isEmpty || row.contains {
                $0.localizedCaseInsensitiveContains(searchText)
            }
        }
        let sortedRows = filteredRows.sorted { left, right in
            let lhs = left.first ?? ""
            let rhs = right.first ?? ""
            return sortAscending
                ? lhs.localizedStandardCompare(rhs) == .orderedAscending
                : lhs.localizedStandardCompare(rhs) == .orderedDescending
        }
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 0) {
                ForEach(Array(headers.enumerated()), id: \.offset) { index, header in
                    Text(header)
                        .frame(width: CGFloat(widths[index]), alignment: .leading)
                }
            }
            .font(.caption2.bold())
            .foregroundColor(.secondary)
            ForEach(Array(sortedRows.enumerated()), id: \.offset) { _, row in
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
        .preference(key: ReportTablePreferenceKey.self, value: [
            ReportTableSnapshot(headers: headers, rows: sortedRows)
        ])
    }

    private func exportCSV() {
        guard !tableSnapshots.isEmpty else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(selected.rawValue)-turn-\(game?.turn.number ?? 0).csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let csv = tableSnapshots.map { snapshot in
            ([snapshot.headers] + snapshot.rows)
                .map { row in row.map(csvField).joined(separator: ",") }
                .joined(separator: "\n")
        }
        .joined(separator: "\n\n")

        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func csvField(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
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

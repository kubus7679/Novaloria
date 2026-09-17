import SwiftUI
import FreeColGame

/// Lightweight in-game help browser for unit and goods types from the specification.
struct ColopediaView: View {
    @Environment(GameState.self) private var state
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""

    private var spec: Specification? { state.game?.specification }

    private var unitTypes: [UnitTypeInfo] {
        let all = spec?.unitTypes.values.sorted { $0.id < $1.id } ?? []
        guard !query.isEmpty else { return all }
        return all.filter { $0.id.localizedCaseInsensitiveContains(query) }
    }

    private var goodsTypes: [GoodsTypeInfo] {
        let all = spec?.goodsTypes.values.sorted { $0.id < $1.id } ?? []
        guard !query.isEmpty else { return all }
        return all.filter { $0.id.localizedCaseInsensitiveContains(query) }
    }

    private var tileTypes: [TileTypeInfo] {
        let all = spec?.tileTypes.values.sorted { $0.id < $1.id } ?? []
        guard !query.isEmpty else { return all }
        return all.filter { $0.id.localizedCaseInsensitiveContains(query) }
    }

    private var buildingTypes: [BuildingTypeInfo] {
        let all = spec?.buildingTypes.values.sorted { $0.id < $1.id } ?? []
        guard !query.isEmpty else { return all }
        return all.filter { $0.id.localizedCaseInsensitiveContains(query) }
    }

    private var improvementTypes: [ImprovementTypeInfo] {
        let all = spec?.improvementTypes.values.sorted { $0.id < $1.id } ?? []
        guard !query.isEmpty else { return all }
        return all.filter { $0.id.localizedCaseInsensitiveContains(query) }
    }

    private var foundingFathers: [String] {
        let ids = Set(state.localPlayerFoundingFathers + state.localPlayerOfferedFathers)
        let all = ids.sorted()
        guard !query.isEmpty else { return all }
        return all.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    private var nations: [String] {
        let players = state.game.map { Array($0.players.values) } ?? []
        let ids = Set(players.compactMap { $0.nationId })
        let all = ids.sorted()
        guard !query.isEmpty else { return all }
        return all.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Colopedia")
                    .font(.title3.bold())
                Spacer()
                Button("Close") { dismiss() }
            }

            TextField("Search", text: $query)
                .textFieldStyle(.roundedBorder)

            if spec == nil {
                Spacer()
                Text("No specification data available.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if !unitTypes.isEmpty {
                            GroupBox("Unit Types") {
                                VStack(alignment: .leading, spacing: 3) {
                                    ForEach(unitTypes, id: \.id) { info in
                                        HStack {
                                            Text(short(info.id, prefix: "model.unit."))
                                                .frame(width: 200, alignment: .leading)
                                            Text("Sight: \(info.lineOfSight)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Text("Atk \(info.offence) / Def \(info.defence) / Mov \(info.movement)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        if !goodsTypes.isEmpty {
                            GroupBox("Goods Types") {
                                VStack(alignment: .leading, spacing: 3) {
                                    ForEach(goodsTypes, id: \.id) { info in
                                        Text(short(info.id, prefix: "model.goods."))
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        if !tileTypes.isEmpty {
                            GroupBox("Terrain") {
                                VStack(alignment: .leading, spacing: 3) {
                                    ForEach(tileTypes, id: \.id) { info in
                                        HStack {
                                            Text(short(info.id, prefix: "model.tile."))
                                                .frame(width: 200, alignment: .leading)
                                            Text("Center output: \(outputSummary(info.centerOutputs))")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        if !buildingTypes.isEmpty {
                            GroupBox("Buildings") {
                                VStack(alignment: .leading, spacing: 3) {
                                    ForEach(buildingTypes, id: \.id) { info in
                                        HStack {
                                            Text(short(info.id, prefix: "model.building."))
                                                .frame(width: 200, alignment: .leading)
                                            Text("Pop \(info.requiredPopulation) · Upkeep \(info.upkeep)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            if !info.requiredGoods.isEmpty {
                                                Text("Cost: \(costSummary(info.requiredGoods))")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        if !improvementTypes.isEmpty {
                            GroupBox("Tile Improvements") {
                                VStack(alignment: .leading, spacing: 3) {
                                    ForEach(improvementTypes, id: \.id) { info in
                                        HStack {
                                            Text(short(info.id, prefix: "model.improvement."))
                                                .frame(width: 200, alignment: .leading)
                                            Text("Work turns +\(info.addWorkTurns)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            if let role = info.requiredRole {
                                                Text("Role: \(short(role, prefix: "model.role."))")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        if !foundingFathers.isEmpty {
                            GroupBox("Founding Fathers") {
                                VStack(alignment: .leading, spacing: 3) {
                                    ForEach(foundingFathers, id: \.self) { id in
                                        Text(GameState.foundingFatherLabel(id))
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        if !nations.isEmpty {
                            GroupBox("Nations") {
                                VStack(alignment: .leading, spacing: 3) {
                                    ForEach(nations, id: \.self) { id in
                                        Text(short(id, prefix: "model.nation."))
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(minWidth: 520, minHeight: 420)
    }

    private func short(_ value: String, prefix: String) -> String {
        value.hasPrefix(prefix) ? String(value.dropFirst(prefix.count)) : value
    }

    private func outputSummary(_ outputs: [String: Int]) -> String {
        guard !outputs.isEmpty else { return "—" }
        return outputs
            .sorted { $0.key < $1.key }
            .map { "\(short($0.key, prefix: "model.goods.")) \($0.value)" }
            .joined(separator: ", ")
    }

    private func costSummary(_ goods: [String: Int]) -> String {
        goods
            .sorted { $0.key < $1.key }
            .map { "\(short($0.key, prefix: "model.goods.")) \($0.value)" }
            .joined(separator: ", ")
    }
}

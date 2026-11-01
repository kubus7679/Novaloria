import SwiftUI
import FreeColGame

/// Bottom-right unit/tile/end-of-turn info panel, modelled on the Java client's InfoPanel.
struct InfoPanelView: View {
    @Environment(GameState.self) private var state
    @State private var showUnitDetails = false

    var body: some View {
        Group {
            if let unit = state.selectedUnit {
                unitContent(unit)
            } else if let tile = selectedTile {
                tileContent(tile)
            } else {
                endTurnContent
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 90)
        .background(Color.black.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(radius: 3)
    }

    private var selectedTile: FreeColGame.Tile? {
        guard let game = state.game, let tileId = state.selectedTileId else { return nil }
        return game.tiles[tileId]
    }

    // MARK: - UNIT mode

    private func unitContent(_ unit: FreeColGame.Unit) -> some View {
        HStack(spacing: 10) {
            if state.game != nil,
               let nsImg = TileImageCache.shared.unitImage(forUnitType: unit.unitType) {
                Image(nsImage: nsImg)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
            } else {
                let ownerColor = unit.owner.map { state.playerColor(for: $0) } ?? .gray
                Circle()
                    .fill(ownerColor)
                    .frame(width: 44, height: 44)
                    .overlay(Circle().stroke(.black, lineWidth: 2))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(displayUnitName(unit.unitType))
                    .font(.headline)
                    .lineLimit(2)
                    .foregroundColor(.white)
                Text(GameLabels.state(unit.state))
                    .font(.caption)
                    .foregroundColor(.yellow)
                Text(movesLabel(unit))
                    .font(.caption)
                    .foregroundColor(.white)
                Button {
                    showUnitDetails.toggle()
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showUnitDetails) {
                    unitDetails(unit)
                }
            }
            if !state.nativeTradeTargetsForSelectedUnit.isEmpty {
                Menu("Handel") {
                    ForEach(state.nativeTradeTargetsForSelectedUnit) { target in
                        Button(target.name) {
                            state.openNativeTradeWithSelectedUnit(settlementId: target.settlementId)
                        }
                    }
                }
                .font(.caption)
                .menuStyle(.borderlessButton)
                .fixedSize()
                .disabled(!state.isLocalPlayersTurn)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .overlay(alignment: .bottom) {
            if !state.selectedUnitCargoUnits.isEmpty {
                HStack(spacing: 4) {
                    ForEach(Array(state.selectedUnitCargoUnits.prefix(6)), id: \.id) { cargoUnit in
                        if let nsImg = TileImageCache.shared.unitImage(forUnitType: cargoUnit.unitType) {
                            Image(nsImage: nsImg)
                                .resizable()
                                .interpolation(.high)
                                .frame(width: 20, height: 20)
                        } else {
                            Image(systemName: "person.circle")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                        }
                    }
                    if state.selectedUnitCargoUnits.count > 6 {
                        Text("+\(state.selectedUnitCargoUnits.count - 6)")
                            .font(.caption2)
                            .foregroundColor(.white)
                    }
                }
                .padding(.bottom, 4)
            }
        }
    }

    private func unitDetails(_ unit: FreeColGame.Unit) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(displayUnitName(unit.unitType))
                .font(.headline)
            detailRow("Erfahrung", "\(unit.experience)")
            detailRow("Rolle", unit.role.map { displayIdentifier($0) } ?? "Standard")
            if unit.roleCount > 0 {
                detailRow("Ausrüstung", "\(unit.roleCount)")
            }
            if unit.hitPoints > 0 {
                detailRow("Trefferpunkte", "\(unit.hitPoints)")
            }

            if let game = state.game,
               let specification = game.specification,
               let unitType = unit.unitType {
                let abilityIds = Set(specification.unitTypes.values.flatMap { $0.abilities.keys })
                let abilities = abilityIds
                    .filter { specification.hasAbility($0, unitType: unitType) }
                    .sorted()
                if !abilities.isEmpty {
                    Divider()
                    Text("Fähigkeiten")
                        .font(.caption.bold())
                    Text(abilities.map(displayIdentifier).joined(separator: ", "))
                        .font(.caption)
                        .textSelection(.enabled)
                }
            }

            if !unit.goods.isEmpty {
                Divider()
                Text("Ladung")
                    .font(.caption.bold())
                ForEach(unit.goods.keys.sorted(), id: \.self) { goodsType in
                    detailRow(displayIdentifier(goodsType), "\(unit.goods[goodsType] ?? 0)")
                }
            }
            if unit.id == state.selectedUnitId, !state.selectedUnitCargoUnits.isEmpty {
                Divider()
                Text("Passagiere")
                    .font(.caption.bold())
                ForEach(state.selectedUnitCargoUnits) { cargoUnit in
                    detailRow(
                        displayUnitName(cargoUnit.unitType),
                        cargoUnit.name ?? "An Bord"
                    )
                }
            }
        }
        .padding(12)
        .frame(minWidth: 220, alignment: .leading)
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.caption)
    }

    private func displayIdentifier(_ value: String) -> String {
        GameLabels.name(value)
    }

    private func displayUnitName(_ unitType: String?) -> String {
        guard let unitType else { return "?" }
        return state.unitDisplayName(unitType)
    }

    private func movesLabel(_ unit: FreeColGame.Unit) -> String {
        state.unitTravelStatus(unit) ?? "Bewegungspunkte: \(unit.movesLeft)"
    }

    // MARK: - TILE mode

    private func tileContent(_ tile: FreeColGame.Tile) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                if let nsImg = TileImageCache.shared.terrainImage(forType: tile.type) {
                    Image(nsImage: nsImg)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 56, height: 40)
                        .clipShape(DiamondShape())
                        .overlay {
                            if let image = TileImageCache.shared.highSeasExitImage(for: tile) {
                                Image(nsImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 56, height: 40)
                            }
                        }
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(colorForTileType(tile.type))
                        .frame(width: 56, height: 40)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(typeLabel(tile.type))
                        .font(.headline)
                        .foregroundColor(.white)
                    if tile.type != nil, tile.moveToEurope {
                        Text("Hochsee-Ausfahrt nach Europa")
                            .font(.caption2)
                            .foregroundColor(.cyan)
                    }
                    Text(tile.type == nil ? "Unerforscht" : "Erforscht")
                        .font(.caption2)
                        .foregroundColor(tile.type == nil ? .secondary : .green)
                    if let ownerId = tile.owner, let game = state.game {
                        Text(game.players[ownerId]?.name ?? ownerId)
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                    Text("(\(tile.x), \(tile.y))")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                Spacer(minLength: 0)
            }

            if let region = tile.region {
                let regionName = state.game?.regions[region]?.displayName
                    ?? short(region, prefix: "model.region.")
                Text("Region: \(regionName)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            ForEach(tile.resources) { resource in
                HStack {
                    if let image = TileImageCache.shared.resourceImage(for: resource.type) {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 24)
                    }
                    Text("\(GameLabels.name(resource.type ?? resource.id))\(resource.quantity >= 0 ? " (\(resource.quantity))" : "")")
                }
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            if !tile.improvements.isEmpty {
                Text("Verbesserungen: \(tile.improvements.compactMap { $0.type.map(GameLabels.name) }.joined(separator: ", "))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            if tile.hasLostCityRumour {
                HStack {
                    if let image = TileImageCache.shared.lostCityRumourImage(for: tile) {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 24)
                    }
                    Text("Gerücht einer verlorenen Stadt")
                }
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
            if let settlementId = tile.settlement,
               let settlement = state.game?.colonies[settlementId] {
                Text("Settlement: \(settlement.name ?? settlementId)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                if settlement.learnableSkill != nil
                    || !settlement.wantedGoods.isEmpty
                    || settlement.mostHated != nil {
                    VStack(alignment: .leading, spacing: 2) {
                        if let skill = settlement.learnableSkill {
                            Text("Skill: \(short(skill, prefix: "model.unit."))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        if !settlement.wantedGoods.isEmpty {
                            Text("Wants: \(settlement.wantedGoods.map { short($0, prefix: "model.goods.") }.joined(separator: ", "))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        if let hated = settlement.mostHated {
                            Text("Most hated: \(state.game?.players[hated]?.name ?? hated)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        if let localId = state.localPlayerId, let alarm = settlement.alarm[localId] {
                            Text("Alarm: \(alarm)")
                                .font(.caption2)
                                .foregroundColor(alarm > 50 ? .red : .secondary)
                        }
                    }
                }
            }
            let units = units(on: tile.id)
            if !units.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Einheiten")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    ForEach(units) { unit in
                        Button {
                            state.selectUnit(unit.id, onTile: tile.id)
                        } label: {
                            HStack(spacing: 4) {
                                if unit.id == state.selectedUnitId {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                }
                                Text("\(displayUnitName(unit.unitType)) (\(unit.movesLeft) BP)")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 6) {
                Button("Als Ziel setzen") {
                    state.setSelectedUnitDestination(to: tile.id)
                }
                .font(.caption2)
                .disabled(!state.canSetDestinationToSelectedTile)

                Button("Ziel löschen") {
                    state.clearSelectedUnitDestination()
                }
                .font(.caption2)
                .disabled(!state.canClearSelectedUnitDestination)
            }
        }
        .padding(10)
    }

    private func units(on tileId: String) -> [FreeColGame.Unit] {
        guard let game = state.game else { return [] }
        return game.units.values
            .filter { game.resolvedTileId(for: $0) == tileId }
            .sorted { ($0.unitType ?? "") < ($1.unitType ?? "") }
    }

    private func short(_ value: String, prefix: String) -> String {
        value.hasPrefix(prefix) ? String(value.dropFirst(prefix.count)) : value
    }

    private func typeLabel(_ type: String?) -> String {
        guard let type else { return "?" }
        return GameLabels.name(type)
    }

    private func colorForTileType(_ type: String?) -> Color {
        let colors: [String: Color] = [
            "model.tile.ocean": .blue, "model.tile.plains": .green,
            "model.tile.grassland": .green, "model.tile.mountains": .gray,
            "model.tile.desert": .yellow, "model.tile.hills": .brown,
        ]
        guard let type else { return .gray }
        return colors[type] ?? .gray
    }

    // MARK: - END mode

    private var endTurnContent: some View {
        VStack(spacing: 8) {
            Text(state.isLocalPlayersTurn ? "Alle Einheiten fertig?" : "Warten auf Gegner…")
                .font(.caption)
                .foregroundColor(.white)
            Text("Einheit oder Feld auf der Karte auswählen.\nKolonie: Doppelklick · Feldaktionen: Rechtsklick")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(10)
    }

}

private struct DiamondShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}
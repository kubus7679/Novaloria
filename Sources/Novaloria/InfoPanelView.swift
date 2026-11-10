import SwiftUI
import FreeColGame

/// Bottom-right unit/tile/end-of-turn info panel, modelled on the Java client's InfoPanel.
struct InfoPanelView: View {
    @Environment(GameState.self) private var state
    @State private var showUnitDetails = false
    @State private var showLandPurchaseSheet = false
    @State private var landPurchaseTileId: String?

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
        .sheet(isPresented: $showLandPurchaseSheet) {
            if let landPurchaseTileId,
               let tile = state.game?.tiles[landPurchaseTileId] {
                NativeLandPurchaseSheet(
                    tile: tile,
                    availableGold: state.localPlayer?.gold ?? 0
                ) { offer in
                    state.claimLand(price: offer, tileId: landPurchaseTileId)
                }
            }
        }
    }

    private var selectedTile: FreeColGame.Tile? {
        guard let game = state.game, let tileId = state.selectedTileId else { return nil }
        return game.tiles[tileId]
    }

    // MARK: - UNIT mode

    private func unitContent(_ unit: FreeColGame.Unit) -> some View {
        HStack(spacing: 10) {
            if state.game != nil,
               let nsImg = TileImageCache.shared.unitImage(
                   forUnitType: unit.unitType, role: unit.role
               ) {
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
                Text(state.unitDisplayLabel(unit))
                    .font(.headline)
                    .lineLimit(2)
                    .foregroundColor(.white)
                Text(GameLabels.state(unit.state))
                    .font(.caption)
                    .foregroundColor(.yellow)
                Text(unitLocationLabel(unit))
                    .font(.caption)
                    .foregroundColor(.white)
                    .lineLimit(2)
                Text(L10n.text("Bewegungspunkte: \(unit.displayMovesLeft)", table: "InfoPanelView"))
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
                Menu(L10n.text("Handel", table: "InfoPanelView")) {
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
            if let landTile = state.nativeLandTileForSelectedUnit {
                Button(L10n.text("Land kaufen…", table: "InfoPanelView")) {
                    landPurchaseTileId = landTile.id
                    showLandPurchaseSheet = true
                }
                .font(.caption)
                .disabled(!state.canClaimSelectedNativeLand)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .overlay(alignment: .bottom) {
            if !state.selectedUnitCargoUnits.isEmpty {
                HStack(spacing: 4) {
                    ForEach(Array(state.selectedUnitCargoUnits.prefix(6)), id: \.id) { cargoUnit in
                        if let nsImg = TileImageCache.shared.unitImage(
                            forUnitType: cargoUnit.unitType, role: cargoUnit.role
                        ) {
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
            Text(state.unitDisplayLabel(unit))
                .font(.headline)
            detailRow(L10n.text("Erfahrung", table: "InfoPanelView"), "\(unit.experience)")
            detailRow(L10n.text("Rolle", table: "InfoPanelView"), unit.role.map { displayIdentifier($0) } ?? L10n.text("Standard", table: "InfoPanelView"))
            if unit.roleCount > 0 {
                detailRow(L10n.text("Ausrüstung", table: "InfoPanelView"), "\(unit.roleCount)")
            }
            if unit.role == "model.role.pioneer" {
                let toolsPerRoleCount = state.game?.specification?.roleTypes["model.role.pioneer"]?
                    .requiredGoods["model.goods.tools"] ?? 20
                detailRow(L10n.text("Verbleibende Werkzeuge", table: "InfoPanelView"), "\(unit.roleCount * toolsPerRoleCount)")
            }
            if unit.hitPoints > 0 {
                detailRow(L10n.text("Trefferpunkte", table: "InfoPanelView"), "\(unit.hitPoints)")
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
                    Text(L10n.text("Fähigkeiten", table: "InfoPanelView"))
                        .font(.caption.bold())
                    Text(abilities.map(displayIdentifier).joined(separator: ", "))
                        .font(.caption)
                        .textSelection(.enabled)
                }
            }

            if !unit.goods.isEmpty {
                Divider()
                Text(L10n.text("Ladung", table: "InfoPanelView"))
                    .font(.caption.bold())
                ForEach(unit.goods.keys.sorted(), id: \.self) { goodsType in
                    detailRow(displayIdentifier(goodsType), "\(unit.goods[goodsType] ?? 0)")
                }
            }
            if unit.id == state.selectedUnitId, !state.selectedUnitCargoUnits.isEmpty {
                Divider()
                Text(L10n.text("Passagiere", table: "InfoPanelView"))
                    .font(.caption.bold())
                ForEach(state.selectedUnitCargoUnits) { cargoUnit in
                    detailRow(
                        displayUnitName(cargoUnit.unitType),
                        cargoUnit.name ?? L10n.text("An Bord", table: "InfoPanelView")
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

    private func unitLocationLabel(_ unit: FreeColGame.Unit) -> String {
        if let travelStatus = state.unitTravelStatus(unit) { return travelStatus }
        guard let game = state.game,
              let tileId = state.selectedUnitTileId,
              let tile = game.tiles[tileId] else { return L10n.text("Standort unbekannt", table: "InfoPanelView") }
        if let colony = game.colonies.values.first(where: { $0.tileId == tileId }) {
            return L10n.text("Standort: \(colony.name ?? L10n.text("Kolonie", table: "InfoPanelView"))", table: "InfoPanelView")
        }
        return L10n.text("Standort: \(tile.x), \(tile.y)", table: "InfoPanelView")
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
                        Text(L10n.text("Hochsee-Ausfahrt nach Europa", table: "InfoPanelView"))
                            .font(.caption2)
                            .foregroundColor(.cyan)
                    }
                    Text(tile.type == nil ? L10n.text("Unerforscht", table: "InfoPanelView") : L10n.text("Erforscht", table: "InfoPanelView"))
                        .font(.caption2)
                        .foregroundColor(tile.type == nil ? .secondary : .green)
                    if let ownerId = tile.owner, let game = state.game {
                         Text(game.players[ownerId]?.name ?? L10n.text("Unbekannt", table: "InfoPanelView"))
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
                    ?? GameLabels.name(region)
                Text(L10n.text("Region: \(regionName)", table: "InfoPanelView"))
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
                Text(L10n.text("Verbesserungen: \(tile.improvements.compactMap { $0.type.map(GameLabels.name) }.joined(separator: ", "))", table: "InfoPanelView"))
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
                    Text(L10n.text("Gerücht einer verlorenen Stadt", table: "InfoPanelView"))
                }
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
            if let settlementId = tile.settlement,
               let settlement = state.game?.colonies[settlementId] {
                     Text(L10n.text("Siedlung: \(settlement.name ?? L10n.text("Siedlung", table: "InfoPanelView"))", table: "InfoPanelView"))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                if settlement.learnableSkill != nil
                    || !settlement.wantedGoods.isEmpty
                    || settlement.mostHated != nil {
                    VStack(alignment: .leading, spacing: 2) {
                        if let skill = settlement.learnableSkill {
                            Text(L10n.text("Fähigkeit: \(GameLabels.name(skill))", table: "InfoPanelView"))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        if !settlement.wantedGoods.isEmpty {
                            Text(L10n.text("Gesuchte Waren: \(settlement.wantedGoods.map(state.goodsDisplayName).joined(separator: ", "))", table: "InfoPanelView"))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        if let hated = settlement.mostHated {
                            Text(L10n.text("Am meisten verhasst: \(state.game?.players[hated]?.name ?? L10n.text("Unbekannt", table: "InfoPanelView"))", table: "InfoPanelView"))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        if let localId = state.localPlayerId, let alarm = settlement.alarm[localId] {
                            Text(L10n.text("Alarmstufe: \(alarm)", table: "InfoPanelView"))
                                .font(.caption2)
                                .foregroundColor(alarm > 50 ? .red : .secondary)
                        }
                    }
                }
            }
            let units = units(on: tile.id)
            if !units.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.text("Einheiten", table: "InfoPanelView"))
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
                                Text("\(displayUnitName(unit.unitType)) (\(unit.displayMovesLeft) BP)")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 6) {
                Button(L10n.text("Als Ziel setzen", table: "InfoPanelView")) {
                    state.setSelectedUnitDestination(to: tile.id)
                }
                .font(.caption2)
                .disabled(!state.canSetDestinationToSelectedTile)

                Button(L10n.text("Ziel löschen", table: "InfoPanelView")) {
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
            Text(state.isLocalPlayersTurn ? L10n.text("Alle Einheiten fertig?", table: "InfoPanelView") : L10n.text("Warten auf Gegner…", table: "InfoPanelView"))
                .font(.caption)
                .foregroundColor(.white)
            Text(L10n.text("Einheit oder Feld auf der Karte auswählen.\nKolonie oder Dorf: Doppelklick · Feldaktionen: Rechtsklick", table: "InfoPanelView"))
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

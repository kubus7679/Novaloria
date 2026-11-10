import SwiftUI
import FreeColGame

struct NativeSettlementPanelView: View {
    @Environment(GameState.self) private var state
    @State private var denounceWithMissionary = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let settlement = state.selectedNativeSettlement {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(settlement.name ?? L10n.text("Ureinwohner-Siedlung", table: "GameView"))
                            .font(.title2.bold())
                        Text(L10n.text("Informationen zum Dorf", table: "NativeSettlementPanelView"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(L10n.text("Schließen", table: "GameView")) {
                        state.closeNativeSettlementPanel()
                    }
                    .keyboardShortcut(.cancelAction)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        settlementInformation(settlement)
                        interactionOptions(for: settlement)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(16)
        .frame(minWidth: 480, idealWidth: 560, minHeight: 420, idealHeight: 520)
    }

    private func settlementInformation(_ settlement: Colony) -> some View {
        GroupBox(L10n.text("Dorf", table: "NativeSettlementPanelView")) {
            VStack(alignment: .leading, spacing: 6) {
                if let ownerId = settlement.owner,
                   let owner = state.game?.players[ownerId] {
                    detailRow(L10n.text("Volk", table: "NativeSettlementPanelView"),
                              owner.name ?? GameLabels.name(owner.nationId ?? ownerId))
                }
                if let settlementType = settlement.settlementType {
                    detailRow(L10n.text("Siedlungstyp", table: "NativeSettlementPanelView"),
                              GameLabels.name(settlementType))
                }
                detailRow(L10n.text("Bewohner", table: "NativeSettlementPanelView"),
                          "\(settlement.unitCount)")
                if let skill = settlement.learnableSkill {
                    detailRow(L10n.text("Erlernbare Fähigkeit", table: "NativeSettlementPanelView"),
                              GameLabels.name(skill))
                }
                if !settlement.wantedGoods.isEmpty {
                    detailRow(L10n.text("Gesuchte Waren", table: "NativeSettlementPanelView"),
                              settlement.wantedGoods.map(state.goodsDisplayName).joined(separator: ", "))
                }
                if let hatedId = settlement.mostHated {
                    let hatedName = state.game?.players[hatedId]?.name ?? hatedId
                    detailRow(L10n.text("Am meisten verhasst", table: "NativeSettlementPanelView"), hatedName)
                }
                if let localPlayerId = state.localPlayerId,
                   let alarm = settlement.alarm[localPlayerId] {
                    detailRow(L10n.text("Alarmstufe", table: "NativeSettlementPanelView"), "\(alarm)")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.caption)
    }

    private func interactionOptions(for settlement: Colony) -> some View {
        let nearbyUnits = nearbyOwnUnits(for: settlement)
        let isSelectedUnitNearby = nearbyUnits.contains { $0.id == state.selectedUnitId }
        let direction = state.directionToAdjacentSettlement(settlement.id)
        let isValidTarget = state.nativeTradeTargetsForSelectedUnit.contains {
            $0.settlementId == settlement.id
        }

        return GroupBox(L10n.text("Interaktionsmöglichkeiten", table: "NativeSettlementPanelView")) {
            VStack(alignment: .leading, spacing: 8) {
                if nearbyUnits.isEmpty {
                    Text(L10n.text("Keine eigene Einheit ist in Reichweite.", table: "NativeSettlementPanelView"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Menu {
                        ForEach(nearbyUnits) { unit in
                            Button {
                                let tileId = state.game?.resolvedTileId(for: unit)
                                state.selectUnit(unit.id, onTile: tileId)
                            } label: {
                                if unit.id == state.selectedUnitId {
                                    Label(state.unitDisplayLabel(unit), systemImage: "checkmark")
                                } else {
                                    Text(state.unitDisplayLabel(unit))
                                }
                            }
                        }
                    } label: {
                        Label(
                            state.selectedUnit.map(state.unitDisplayLabel)
                                ?? L10n.text("Einheit auswählen", table: "NativeSettlementPanelView"),
                            systemImage: "person"
                        )
                    }
                    .accessibilityIdentifier("native-settlement-unit-picker")

                    if !isSelectedUnitNearby {
                        Text(L10n.text("Wähle eine benachbarte Einheit für Aktionen.", table: "NativeSettlementPanelView"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Divider()
                    Button(L10n.text("Handeln…", table: "GameView")) {
                        state.openNativeTradeWithSelectedUnit(settlementId: settlement.id)
                    }
                    .disabled(!isValidTarget || !state.canOpenNativeTrade)

                    Menu(L10n.text("Geschenk überbringen", table: "GameView")) {
                        ForEach(state.selectedUnitCargoGoods, id: \.id) { goods in
                            Button(L10n.text("\(goods.label) (\(goods.amount))", table: "NativeSettlementPanelView")) {
                                state.deliverGiftToSettlement(
                                    settlement.id,
                                    goodsType: goods.id,
                                    amount: goods.amount
                                )
                            }
                        }
                    }
                    .disabled(!isValidTarget || !state.canDeliverGiftWithSelectedUnit
                              || state.selectedUnitCargoGoods.isEmpty)

                    Button(L10n.text("Tribut fordern", table: "GameView")) {
                        if let direction {
                            state.demandTributeFromSettlement(direction: direction)
                        }
                    }
                    .disabled(!isValidTarget || !state.canDemandTributeWithSelectedUnit || direction == nil)

                    Button(L10n.text("Siedlung erkunden", table: "GameView")) {
                        if let direction {
                            state.scoutIndianSettlement(direction: direction)
                        }
                    }
                    .disabled(!isValidTarget || !state.canScoutIndianSettlement || direction == nil)

                    Button(L10n.text("Mit Häuptling sprechen", table: "GameView")) {
                        state.scoutSpeakToChief(settlementId: settlement.id)
                    }
                    .disabled(!isValidTarget || !state.canScoutSpeakToChief || direction == nil)

                    Toggle(
                        L10n.text("Anprangern", table: "DebugControlsView"),
                        isOn: $denounceWithMissionary
                    )
                    .disabled(!isValidTarget || !state.canSendMissionaryAction || direction == nil)
                    Button(L10n.text("Missionarsaktion", table: "DebugControlsView")) {
                        if let direction {
                            state.sendMissionaryAction(
                                direction: direction,
                                denounce: denounceWithMissionary
                            )
                        }
                    }
                    .disabled(!isValidTarget || !state.canSendMissionaryAction || direction == nil)

                    Button(L10n.text("Fähigkeit erlernen…", table: "GameView")) {
                        if let direction {
                            state.beginNativeSkillLearning(
                                settlementId: settlement.id,
                                direction: direction
                            )
                        }
                    }
                    .disabled(!isValidTarget || !state.canLearnSkillAtSelectedUnit || direction == nil)

                    Menu(L10n.text("Aufstand anzetteln…", table: "GameView")) {
                        ForEach(state.diplomacyVictimOptions(), id: \.id) { victim in
                            Button(victim.label) {
                                state.inciteSettlement(
                                    settlementId: settlement.id,
                                    enemyPlayerId: victim.id
                                )
                            }
                        }
                    }
                    .disabled(!isValidTarget || !state.canInciteSelectedUnit
                              || state.diplomacyVictimOptions().isEmpty)
                }
                if let error = state.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func nearbyOwnUnits(for settlement: Colony) -> [FreeColGame.Unit] {
        guard let game = state.game,
              let tileId = settlement.tileId,
              let playerId = state.localPlayerId else { return [] }
        let neighboringTiles = Set(game.neighborTileIds(of: tileId))
        return game.units.values
            .filter { unit in
                unit.owner == playerId
                    && game.resolvedTileId(for: unit).map(neighboringTiles.contains) == true
            }
            .sorted {
                state.unitDisplayLabel($0).localizedStandardCompare(state.unitDisplayLabel($1))
                    == .orderedAscending
            }
    }
}

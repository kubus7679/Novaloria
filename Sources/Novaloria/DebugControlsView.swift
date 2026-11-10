import SwiftUI
import NovaloriaClient
import FreeColGame

/// Protocol-/Server-Test-Werkzeuge, die vom Java-Client-Debug-Menue inspiriert sind.
struct DebugControlsView: View {
    @Environment(GameState.self) private var state

    @State private var colonyName: String = "New Amsterdam"
    @State private var tradeRouteId: String = ""
    @State private var currentStopIndex: String = "0"
    @State private var monarchActionType: String = "RAISE_TAX_ACT"
    @State private var aiEnabled: Bool = false
    @State private var stanceValue: String = "WAR"
    @State private var stanceTargetPlayerId: String = "player-2"
    @State private var independenceCountryName: String = "Freedonia"
    @State private var independenceNationName: String = "Free Colonials"
    @State private var chatMessageText: String = ""
    @State private var chatPrivateRecipientId: String = ""
    @State private var claimLandPrice: String = "100"
    @State private var nativeSettlementId: String = ""
    @State private var nativeEnemyPlayerId: String = "player-2"
    @State private var missionaryDirection: String = "N"
    @State private var missionaryDenounce: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let game = state.game {
                    GroupBox(L10n.text("Spieler", table: "DebugControlsView")) {
                        let sorted = game.players.values
                            .filter { $0.playerType == .european }
                        ForEach(Array(sorted), id: \.id) { player in
                            HStack {
                                Circle().fill(colorFor(player: player))
                                    .frame(width: 8, height: 8)
                                Text(player.name ?? player.nationId ?? "?")
                                    .lineLimit(1)
                                Spacer()
                                Text("\(player.gold) G")
                                    .foregroundColor(.secondary)
                            }
                            .font(.caption)
                        }
                    }

                    GroupBox(L10n.text("Einheiten", table: "DebugControlsView")) {
                        ForEach(
                            game.units.values.filter { unit in
                                guard let localPlayerId = state.localPlayerId else { return false }
                                return unit.owner == localPlayerId
                            },
                            id: \.id
                        ) { unit in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(unit.unitType.map(state.unitDisplayName) ?? L10n.text("Einheit", table: "DebugControlsView"))
                                        .font(.caption)
                                    Text(unitLocationLabel(unit, in: game))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    let economyLabel = unitEconomyLabel(unit, in: game)
                                    if !economyLabel.isEmpty {
                                        Text(economyLabel)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(unit.movesLeft) BP")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text(GameLabels.state(unit.state))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }

                    GroupBox(L10n.text("Kolonien", table: "DebugControlsView")) {
                        let colonyList = Array(game.colonies.values)
                        ForEach(colonyList, id: \.id) { colony in
                            HStack {
                                Text(colony.name ?? "?")
                                    .font(.caption)
                                Spacer()
                                Text("\(colony.sonsOfLiberty)% " + L10n.text("Freiheit", table: "DebugControlsView"))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    GroupBox("Handelsroute") {
                        VStack(alignment: .leading, spacing: 6) {
                            TextField("Handelsrouten-ID", text: $tradeRouteId)
                                .textFieldStyle(.roundedBorder)

                            Button(L10n.text("Handelsroute zuweisen (ausgewählte Einheit)", table: "DebugControlsView")) {
                                state.assignSelectedUnitTradeRoute(tradeRouteId)
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .disabled(!state.canAssignSelectedUnitTradeRoute(tradeRouteId))

                            Button(L10n.text("Handelsroute entfernen", table: "DebugControlsView")) {
                                state.clearSelectedUnitTradeRoute()
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .disabled(!state.canClearSelectedUnitTradeRoute)

                            TextField(L10n.text("Index des aktuellen Halts", table: "DebugControlsView"), text: $currentStopIndex)
                                .textFieldStyle(.roundedBorder)

                            Button(L10n.text("Aktuellen Halt festlegen", table: "DebugControlsView")) {
                                state.setSelectedUnitCurrentStop(currentStopIndex)
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 4)
                    }

                    if let selected = state.selectedUnit, selected.treasureAmount > 0 {
                        GroupBox(L10n.text("Schatz", table: "DebugControlsView")) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(L10n.text("Menge: \(selected.treasureAmount)", table: "DebugControlsView"))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)

                                Button(L10n.text("Schatztransport einlösen", table: "DebugControlsView")) {
                                    state.cashInSelectedTreasureTrain()
                                }
                                .buttonStyle(.bordered)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .disabled(!state.canCashInSelectedTreasureTrain)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    if state.selectedUnit != nil {
                        Button(L10n.text("Hügel ablehnen", table: "DebugControlsView")) {
                            state.declineMoundsForSelectedUnit()
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    GroupBox(L10n.text("Ureinwohner", table: "DebugControlsView")) {
                        VStack(alignment: .leading, spacing: 6) {
                            TextField("Siedlungs-ID", text: $nativeSettlementId)
                                .textFieldStyle(.roundedBorder)

                            HStack {
                                Button(L10n.text("Geschenk überbringen", table: "DebugControlsView")) {
                                    state.deliverGiftToSettlement(nativeSettlementId)
                                }
                                .buttonStyle(.bordered)
                                .disabled(!state.canDeliverGiftWithSelectedUnit || nativeSettlementId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }

                            HStack {
                                Button(L10n.text("Geschenk annehmen", table: "DebugControlsView")) {
                                    state.acceptGiftFromNativeSettlement(colonyId: nativeSettlementId)
                                }
                                .buttonStyle(.bordered)
                                .disabled(!state.canAcceptNativeGift || nativeSettlementId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                                Button(L10n.text("Aufstand anzetteln", table: "DebugControlsView")) {
                                    state.inciteSettlement(settlementId: nativeSettlementId,
                                                           enemyPlayerId: nativeEnemyPlayerId)
                                }
                                .buttonStyle(.bordered)
                                .disabled(!state.canInciteSelectedUnit || nativeSettlementId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || nativeEnemyPlayerId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }

                            HStack {
                                Button(L10n.text("Tribut N", table: "DebugControlsView")) { state.demandTributeFromSettlement(direction: "N") }
                                Button("NO") { state.demandTributeFromSettlement(direction: "NE") }
                                Button("O") { state.demandTributeFromSettlement(direction: "E") }
                                Button("SO") { state.demandTributeFromSettlement(direction: "SE") }
                            }
                            .buttonStyle(.bordered)
                            .disabled(!state.canDemandTributeWithSelectedUnit)

                            HStack {
                                Button("S") { state.demandTributeFromSettlement(direction: "S") }
                                Button("SW") { state.demandTributeFromSettlement(direction: "SW") }
                                Button("W") { state.demandTributeFromSettlement(direction: "W") }
                                Button("NW") { state.demandTributeFromSettlement(direction: "NW") }
                            }
                            .buttonStyle(.bordered)
                            .disabled(!state.canDemandTributeWithSelectedUnit)

                            HStack {
                                Button(L10n.text("Erkunden N", table: "DebugControlsView")) { state.scoutIndianSettlement(direction: "N") }
                                Button("NO") { state.scoutIndianSettlement(direction: "NE") }
                                Button("O") { state.scoutIndianSettlement(direction: "E") }
                                Button("SO") { state.scoutIndianSettlement(direction: "SE") }
                            }
                            .buttonStyle(.bordered)
                            .disabled(!state.canScoutIndianSettlement)

                            HStack {
                                Button(L10n.text("Erkunden S", table: "DebugControlsView")) { state.scoutIndianSettlement(direction: "S") }
                                Button("SW") { state.scoutIndianSettlement(direction: "SW") }
                                Button("W") { state.scoutIndianSettlement(direction: "W") }
                                Button("NW") { state.scoutIndianSettlement(direction: "NW") }
                            }
                            .buttonStyle(.bordered)
                            .disabled(!state.canScoutIndianSettlement)

                            Button(L10n.text("Mit Häuptling sprechen", table: "DebugControlsView")) {
                                state.scoutSpeakToChief(settlementId: nativeSettlementId)
                            }
                            .buttonStyle(.bordered)
                            .disabled(!state.canScoutSpeakToChief || nativeSettlementId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                            Divider()

                            Text(L10n.text("Missionar", table: "DebugControlsView"))
                                .font(.caption)
                                .foregroundColor(.secondary)

                            TextField(L10n.text("Richtung", table: "DebugControlsView"), text: $missionaryDirection)
                                .textFieldStyle(.roundedBorder)

                            Toggle(L10n.text("Anprangern", table: "DebugControlsView"), isOn: $missionaryDenounce)

                            Button(L10n.text("Missionarsaktion", table: "DebugControlsView")) {
                                state.sendMissionaryAction(direction: missionaryDirection, denounce: missionaryDenounce)
                            }
                            .buttonStyle(.bordered)
                            .disabled(!state.canSendMissionaryAction || missionaryDirection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                            TextField(L10n.text("Spieler-ID des Gegners", table: "DebugControlsView"), text: $nativeEnemyPlayerId)
                                .textFieldStyle(.roundedBorder)
                        }
                        .padding(.vertical, 4)
                    }

                    Button(L10n.text("Weiterspielen", table: "DebugControlsView")) {
                        state.sendContinue()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)

                    Button(L10n.text("Aufgeben", table: "DebugControlsView")) {
                        state.retireGame()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)

                    Button(L10n.text("Rachemodus starten", table: "DebugControlsView")) {
                        state.enterRevengeMode()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)

                    TextField(L10n.text("Monarch-Aktionstyp", table: "DebugControlsView"), text: $monarchActionType)
                        .textFieldStyle(.roundedBorder)

                    Button(L10n.text("Monarch-Aktion", table: "DebugControlsView")) {
                        state.sendMonarchAction(monarchActionType)
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .disabled(monarchActionType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Toggle(L10n.text("KI aktiv", table: "DebugControlsView"), isOn: $aiEnabled)

                    Button(L10n.text("KI-Einstellung übernehmen", table: "DebugControlsView")) {
                        state.setLocalPlayerAI(aiEnabled)
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)

                    Button(L10n.text("Als verfügbar markieren", table: "DebugControlsView")) {
                        state.setLocalPlayerAvailable()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)

                    TextField(L10n.text("Haltung", table: "DebugControlsView"), text: $stanceValue)
                        .textFieldStyle(.roundedBorder)

                    TextField(L10n.text("Zielspieler-ID der Haltung", table: "DebugControlsView"), text: $stanceTargetPlayerId)
                        .textFieldStyle(.roundedBorder)

                    Button(L10n.text("Haltung festlegen", table: "DebugControlsView")) {
                        state.setStance(stance: stanceValue, targetPlayerId: stanceTargetPlayerId)
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .disabled(
                        stanceValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || stanceTargetPlayerId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )

                    TextField(L10n.text("Name des unabhängigen Landes", table: "DebugControlsView"), text: $independenceCountryName)
                        .textFieldStyle(.roundedBorder)

                    TextField(L10n.text("Name der unabhängigen Nation", table: "DebugControlsView"), text: $independenceNationName)
                        .textFieldStyle(.roundedBorder)

                    Button(L10n.text("Unabhängigkeit erklären", table: "DebugControlsView")) {
                        state.declareIndependence(
                            countryName: independenceCountryName,
                            nationName: independenceNationName
                        )
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .disabled(
                        independenceCountryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || independenceNationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )

                    TextField(L10n.text("Chatnachricht", table: "DebugControlsView"), text: $chatMessageText)
                        .textFieldStyle(.roundedBorder)

                    TextField(L10n.text("Optionale Empfänger-Spieler-ID", table: "DebugControlsView"), text: $chatPrivateRecipientId)
                        .textFieldStyle(.roundedBorder)

                    if !state.incomingChatLog.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(state.incomingChatLog, id: \.self) { line in
                                Text(line)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }

                    Button(L10n.text("Chatnachricht senden", table: "DebugControlsView")) {
                        state.sendChatMessage(
                            message: chatMessageText,
                            privateRecipientId: chatPrivateRecipientId
                        )
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .disabled(chatMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button(L10n.text("Als ausgeschieden markieren", table: "DebugControlsView")) {
                        state.setLocalPlayerDead()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)

                    TextField(L10n.text("Preis für Land beanspruchen", table: "DebugControlsView"), text: $claimLandPrice)
                        .textFieldStyle(.roundedBorder)

                    Button(L10n.text("Ausgewähltes Feld beanspruchen", table: "DebugControlsView")) {
                        if let tileId = state.selectedTileId {
                            state.claimLand(price: claimLandPrice, tileId: tileId)
                        }
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .disabled(state.selectedTileId == nil
                              || state.nativeLandTileForSelectedUnit?.id != state.selectedTileId
                              || !state.canClaimSelectedNativeLand
                              || claimLandPrice.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding()
        }
    }

    private func unitLocationLabel(_ unit: FreeColGame.Unit, in game: Game) -> String {
        guard let location = unit.location else { return "?" }
        if let carrier = game.units[location] {
            return L10n.text("An Bord von \(carrier.unitType.map(state.unitDisplayName) ?? L10n.text("Transporter", table: "DebugControlsView"))", table: "DebugControlsView")
        }
        if game.tiles[location] != nil {
            return location
        }
        if game.colonies[location] != nil {
            return L10n.text("In der Kolonie", table: "DebugControlsView")
        }
        return location
    }

    private func unitEconomyLabel(_ unit: FreeColGame.Unit, in game: Game) -> String {
        var parts: [String] = []
        if let tradeRoute = unit.tradeRoute, !tradeRoute.isEmpty {
            parts.append(L10n.text("Route: \(tradeRoute)", table: "DebugControlsView"))
        }
        if unit.currentStop > 0 || unit.tradeRoute != nil {
            parts.append(L10n.text("Halt: \(unit.currentStop)", table: "DebugControlsView"))
        }
        if unit.treasureAmount > 0 {
            parts.append(L10n.text("Schatz: \(unit.treasureAmount)", table: "DebugControlsView"))
        }
        if let carrierId = unit.location, game.units[carrierId] != nil {
            let cargoCount = game.units.values.filter { $0.location == carrierId }.count
            parts.append(L10n.text("Fracht: \(cargoCount)", table: "DebugControlsView"))
        }
        return parts.joined(separator: " | ")
    }

    private func colorFor(player: Player) -> Color {
        let colors: [Color] = [.blue, .red, .green, .orange, .purple, .brown, .cyan, .mint]
        let idx = abs(player.id.hashValue) % colors.count
        return colors[idx]
    }
}

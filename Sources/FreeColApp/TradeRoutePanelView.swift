import SwiftUI
import FreeColGame

/// Trade route editor mirroring the Java client's `TradeRoutePanel`:
/// list/create/edit/delete routes and assign them to the selected carrier.
struct TradeRoutePanelView: View {
    @Environment(GameState.self) private var state
    @Environment(\.dismiss) private var dismiss

    @State private var selectedRouteId: String?
    @State private var draft: TradeRoute?
    @State private var awaitingNewRoute = false
    @State private var knownRouteIds: Set<String> = []

    private var routes: [TradeRoute] { state.localPlayerTradeRoutes }
    private var candidates: [(id: String, label: String)] { state.tradeRouteStopCandidates }
    private var goodsTypes: [(id: String, label: String)] { state.tradeRouteGoodsTypes }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if state.canManageTradeRoutes {
                HStack(spacing: 0) {
                    routeList
                    Divider()
                    editor
                }
            } else {
                Text("Handelsrouten können nur im eigenen Zug verwaltet werden.")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 680, minHeight: 460)
        .onAppear { syncSelection() }
        .onChange(of: state.gameUpdateID) { _, _ in syncSelection() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Handelsrouten")
                    .font(.headline)
                Spacer()
                if let message = state.errorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(1)
                }
                Button("Neue Route") {
                    knownRouteIds = Set(routes.map(\.id))
                    awaitingNewRoute = true
                    state.createTradeRoute()
                }
                .disabled(!state.canManageTradeRoutes)
                Button("Schließen") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            
            HStack {
                Toggle("Routen beim Zugende automatisch ausführen", isOn: Binding(
                    get: { state.autoExecuteTradeRoutes },
                    set: { state.autoExecuteTradeRoutes = $0 }
                ))
                .toggleStyle(.checkbox)
                .font(.caption)
                
                Button("Jetzt ausführen") {
                    state.executeTradeRoutes()
                }
                .buttonStyle(.bordered)
                .disabled(!state.canManageTradeRoutes)
                
                Spacer()
            }
        }
        .padding(12)
    }

    // MARK: - Route list

    private var routeList: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(routes) { route in
                HStack {
                    Button {
                        select(route)
                    } label: {
                        Text(route.name ?? route.id)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(selectedRouteId == route.id
                                        ? Color.accentColor.opacity(0.25)
                                        : Color.clear)
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)

                    Button {
                        state.deleteTradeRoute(route.id)
                        if selectedRouteId == route.id {
                            selectedRouteId = nil
                            draft = nil
                        }
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                }
            }
            if routes.isEmpty {
                Text("Noch keine Handelsrouten.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
            }
            Spacer()
        }
        .frame(width: 200)
        .padding(8)
    }

    // MARK: - Editor

    @ViewBuilder
    private var editor: some View {
        if let draft {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Name")
                        TextField("Routenname", text: Binding(
                            get: { draft.name ?? "" },
                            set: { self.draft?.name = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                    }

                    if let validationMessage = state.tradeRouteValidationError(for: draft) {
                        Text(validationMessage)
                            .font(.caption)
                            .foregroundColor(.orange)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Haltepunkte").font(.subheadline.weight(.semibold))
                            Spacer()
                            Button("Halt hinzufügen") {
                                var updated = draft
                                let defaultLocation = candidates.first?.id
                                updated.stops.append(TradeRouteStop(locationId: defaultLocation))
                                self.draft = updated
                            }
                            .disabled(candidates.isEmpty)
                        }

                        if draft.stops.isEmpty {
                            Text("Mindestens zwei Haltepunkte hinzufügen.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(Array(draft.stops.enumerated()), id: \.offset) { index, stop in
                                stopEditor(index: index, stop: stop)
                            }
                        }
                    }

                    Divider()

                    FlowLayout(spacing: 8) {
                        Button("Speichern") { state.saveTradeRoute(draft) }
                            .buttonStyle(.borderedProminent)
                            .disabled(state.tradeRouteValidationError(for: draft) != nil)

                        Button("Einheit zuweisen") {
                            state.assignSelectedUnitTradeRoute(draft.id)
                        }
                        .buttonStyle(.bordered)
                        .disabled(!state.canAssignSelectedUnitTradeRoute(draft.id))

                        Button("Zuweisung entfernen") { state.clearSelectedUnitTradeRoute() }
                            .buttonStyle(.bordered)
                            .disabled(!state.canClearSelectedUnitTradeRoute)

                    }

                    if let unit = state.selectedUnit, unit.tradeRoute == draft.id {
                        HStack {
                            Text("Aktueller Halt")
                                .font(.caption)
                            Stepper("Halt \(unit.currentStop + 1) von \(state.game?.tradeRoutes[draft.id]?.stops.count ?? 0)",
                                    value: Binding(
                                        get: { unit.currentStop },
                                        set: { state.setSelectedUnitCurrentStop(String($0)) }
                                    ),
                                    in: 0...max(0, (state.game?.tradeRoutes[draft.id]?.stops.count ?? 0) - 1))
                                .font(.caption)
                                .disabled(state.movingUnitId != nil || state.isSavingGame)
                            Spacer()
                        }
                    }
                }
                .padding(12)
            }
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        } else {
            Text("Eine Handelsroute auswählen oder erstellen.")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func stopEditor(index: Int, stop: TradeRouteStop) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Halt \(index + 1)")
                    .font(.caption.weight(.semibold))
                Picker("", selection: Binding(
                    get: { self.draft?.stops[index].locationId ?? "" },
                    set: { self.draft?.stops[index].locationId = $0.isEmpty ? nil : $0 }
                )) {
                    Text("Ort auswählen").tag("")
                    ForEach(candidates, id: \.id) { candidate in
                        Text(candidate.label).tag(candidate.id)
                    }
                }
                .labelsHidden()
                .frame(width: 180)

                Spacer()

                Button {
                    guard index > 0, var updated = self.draft else { return }
                    updated.stops.swapAt(index, index - 1)
                    self.draft = updated
                } label: {
                    Image(systemName: "arrow.up")
                }
                .buttonStyle(.plain)
                .disabled(index == 0)

                Button {
                    guard let count = self.draft?.stops.count, index < count - 1,
                          var updated = self.draft else { return }
                    updated.stops.swapAt(index, index + 1)
                    self.draft = updated
                } label: {
                    Image(systemName: "arrow.down")
                }
                .buttonStyle(.plain)
                .disabled(index >= (self.draft?.stops.count ?? 1) - 1)

                Button {
                    self.draft?.stops.remove(at: index)
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.plain)
            }

            if goodsTypes.isEmpty {
                Text("Keine Warenarten verfügbar.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(goodsTypes, id: \.id) { goods in
                        Toggle(goods.label, isOn: Binding(
                            get: { self.draft?.stops[index].cargoTypeIds.contains(goods.id) ?? false },
                            set: { isOn in
                                guard var updated = self.draft else { return }
                                if isOn {
                                    if !updated.stops[index].cargoTypeIds.contains(goods.id) {
                                        updated.stops[index].cargoTypeIds.append(goods.id)
                                    }
                                } else {
                                    updated.stops[index].cargoTypeIds.removeAll { $0 == goods.id }
                                }
                                self.draft = updated
                            }
                        ))
                        .toggleStyle(.checkbox)
                        .font(.caption)
                    }
                }
            }
        }
        .padding(8)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(6)
    }

    // MARK: - Selection

    private func select(_ route: TradeRoute) {
        selectedRouteId = route.id
        draft = route
        awaitingNewRoute = false
    }

    private func syncSelection() {
        let routes = state.localPlayerTradeRoutes
        if awaitingNewRoute {
            if let newest = routes.first(where: { !knownRouteIds.contains($0.id) }) {
                select(newest)
                awaitingNewRoute = false
            }
            return
        }
        if let id = selectedRouteId, let current = routes.first(where: { $0.id == id }) {
            if draft == nil { draft = current }
            return
        }
        if let first = routes.first {
            select(first)
        } else {
            selectedRouteId = nil
            draft = nil
        }
    }
}

/// Wrapping layout for cargo toggles and editor actions.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

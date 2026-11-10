import SwiftUI
import FreeColGame

/// Review a diplomatic proposal, accept/reject it, or build a counter-proposal.
struct DiplomacyView: View {
    @Environment(GameState.self) private var state
    @Environment(\.dismiss) private var dismiss

    var onClose: (() -> Void)?

    @State private var drafts: [DiplomaticClauseDraft] = []
    @State private var newKind: DiplomaticClauseKind = .gold
    @State private var newWeGive = true
    @State private var newGold = "100"
    @State private var newGoodsType = ""
    @State private var newGoodsAmount = "10"
    @State private var newColonyId = ""
    @State private var newStance = "PEACE"
    @State private var newUnitId = ""
    @State private var newVictimId = ""

    private let stanceOptions = ["PEACE", "WAR", "CEASE_FIRE", "ALLIANCE", "UNCONTACTED"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(state.pendingDiplomacy?.context == "TRIBUTE" ? L10n.text("Tributverhandlung", table: "DiplomacyView") : L10n.text("Diplomatie", table: "DiplomacyView"))
                    .font(.title2.bold())
                Spacer()
                if state.pendingDiplomacyIsIncoming {
                    Button(L10n.text("Ablehnen", table: "DiplomacyView")) { state.rejectDiplomacy() }
                        .buttonStyle(.bordered)
                    Button(L10n.text("Akzeptieren", table: "DiplomacyView")) { state.acceptDiplomacy() }
                        .buttonStyle(.borderedProminent)
                }
                Button(L10n.text("Schließen", table: "DiplomacyView")) {
                    if !state.pendingDiplomacyIsIncoming { state.clearPendingDecision() }
                    if let onClose {
                        onClose()
                    } else {
                        dismiss()
                    }
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
            }

            if let error = state.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
            ScrollView([.horizontal, .vertical]) {
                VStack(alignment: .leading, spacing: 12) {
            if let proposal = state.pendingDiplomacy {
                HStack(spacing: 12) {
                    Text(L10n.text("Kontext: \(contextLabel(proposal.context))", table: "DiplomacyView"))
                    Text(L10n.text("Von: \(proposal.sender.flatMap { state.game?.players[$0]?.name } ?? L10n.text("Unbekannt", table: "DiplomacyView"))", table: "DiplomacyView"))
                        .foregroundColor(.secondary)
                    Text(L10n.text("Version: \(proposal.version)", table: "DiplomacyView"))
                        .foregroundColor(.secondary)
                }
                .font(.caption)

                GroupBox(L10n.text("Eingehende Klauseln", table: "DiplomacyView")) {
                    if proposal.clauses.isEmpty {
                        Text(L10n.text("Keine Klauseln.", table: "DiplomacyView"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(proposal.clauses) { clause in
                                HStack {
                                    Text(clause.tag)
                                        .font(.caption.bold())
                                        .frame(width: 130, alignment: .leading)
                                    Text(clause.summary)
                                        .font(.caption)
                                    Spacer()
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                counterProposalEditor
            } else {
                Text(L10n.text("Kein diplomatischer Vorschlag.", table: "DiplomacyView"))
                    .foregroundColor(.secondary)
            }

                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .frame(minWidth: 640, idealWidth: 820,
               minHeight: 400, idealHeight: 640, maxHeight: 760)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear { syncDrafts() }
        .onChange(of: state.pendingServerDecision?.id) { _, _ in
            newKind = .gold
            syncDrafts()
        }
    }

    private func contextLabel(_ context: String?) -> String {
        switch context?.uppercased() {
        case "TRIBUTE": return L10n.text("Tribut", table: "DiplomacyView")
        case "DIPLOMATIC": return L10n.text("Diplomatie", table: "DiplomacyView")
        default: return context.map(GameLabels.name) ?? L10n.text("Unbekannt", table: "DiplomacyView")
        }
    }

    // MARK: - Counter-proposal

    private var counterProposalEditor: some View {
        GroupBox(L10n.text("Gegenvorschlag", table: "DiplomacyView")) {
            VStack(alignment: .leading, spacing: 8) {
                if drafts.isEmpty {
                    Text(L10n.text("Keine Klauseln. Füge eine unten hinzu.", table: "DiplomacyView"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach($drafts) { $draft in
                        clauseRow(draft: $draft)
                    }
                }

                Divider()

                HStack {
                    Picker(L10n.text("Typ", table: "DiplomacyView"), selection: $newKind) {
                        ForEach(state.pendingDiplomacyClauseKinds) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .frame(width: 140)

                    Picker(L10n.text("Richtung", table: "DiplomacyView"), selection: $newWeGive) {
                        Text(L10n.text("Wir geben", table: "DiplomacyView")).tag(true)
                        Text(L10n.text("Sie geben", table: "DiplomacyView")).tag(false)
                    }
                    .frame(width: 160)
                }

                clauseFields(
                    kind: newKind,
                    weGive: newWeGive,
                    gold: $newGold,
                    goodsType: $newGoodsType,
                    goodsAmount: $newGoodsAmount,
                    colonyId: $newColonyId,
                    stance: $newStance,
                    unitId: $newUnitId,
                    victimId: $newVictimId
                )

                HStack {
                    Button(L10n.text("Klausel hinzufügen", table: "DiplomacyView")) { addClause() }
                        .buttonStyle(.bordered)
                    Spacer()
                    Button(L10n.text("Gegenvorschlag senden", table: "DiplomacyView")) {
                        state.sendDiplomacyCounterProposal(drafts)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(drafts.isEmpty)
                }
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private func clauseRow(draft: Binding<DiplomaticClauseDraft>) -> some View {
        HStack(spacing: 8) {
            Text(draft.wrappedValue.kind.title)
                .font(.caption.bold())
                .frame(width: 60, alignment: .leading)

            Picker("", selection: draft.weGive) {
                Text(L10n.text("Wir geben", table: "DiplomacyView")).tag(true)
                Text(L10n.text("Sie geben", table: "DiplomacyView")).tag(false)
            }
            .labelsHidden()
            .frame(width: 120)

            clauseFields(
                kind: draft.wrappedValue.kind,
                weGive: draft.wrappedValue.weGive,
                gold: Binding(get: { String(draft.wrappedValue.goldAmount) },
                              set: { draft.wrappedValue.goldAmount = Int($0) ?? 0 }),
                goodsType: draft.goodsType,
                goodsAmount: Binding(get: { String(draft.wrappedValue.goodsAmount) },
                                     set: { draft.wrappedValue.goodsAmount = Int($0) ?? 0 }),
                colonyId: draft.colonyId,
                stance: draft.stance,
                unitId: draft.unitId,
                victimId: draft.victimId
            )

            Spacer()

            Button {
                drafts.removeAll { $0.id == draft.wrappedValue.id }
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func clauseFields(kind: DiplomaticClauseKind,
                              weGive: Bool,
                              gold: Binding<String>,
                              goodsType: Binding<String>,
                              goodsAmount: Binding<String>,
                              colonyId: Binding<String>,
                              stance: Binding<String>,
                              unitId: Binding<String>,
                              victimId: Binding<String>) -> some View {
        switch kind {
        case .gold:
            TextField(L10n.text("Gold", table: "DiplomacyView"), text: gold)
                .textFieldStyle(.roundedBorder)
                .frame(width: 100)
        case .goods:
            Picker("", selection: goodsType) {
                Text(L10n.text("Ware auswählen", table: "DiplomacyView")).tag("")
                ForEach(goodsOptions, id: \.id) { option in
                    Text(option.label).tag(option.id)
                }
            }
            .labelsHidden()
            .frame(width: 160)
            TextField(L10n.text("Menge", table: "DiplomacyView"), text: goodsAmount)
                .textFieldStyle(.roundedBorder)
                .frame(width: 70)
        case .colony:
            Picker("", selection: colonyId) {
                Text(L10n.text("Kolonie auswählen", table: "DiplomacyView")).tag("")
                ForEach(colonyOptions, id: \.id) { option in
                    Text(option.label).tag(option.id)
                }
            }
            .labelsHidden()
            .frame(width: 200)
        case .stance:
            Picker("", selection: stance) {
                ForEach(stanceOptions, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .labelsHidden()
            .frame(width: 140)
        case .unit:
            Picker("", selection: unitId) {
                Text(L10n.text("Einheit auswählen", table: "DiplomacyView")).tag("")
                ForEach(state.diplomacyUnitOptions(weGive: weGive), id: \.id) { option in
                    Text(option.label).tag(option.id)
                }
            }
            .labelsHidden()
            .frame(width: 200)
        case .incite:
            Picker("", selection: victimId) {
                Text(L10n.text("Ziel auswählen", table: "DiplomacyView")).tag("")
                ForEach(state.diplomacyVictimOptions(), id: \.id) { option in
                    Text(option.label).tag(option.id)
                }
            }
            .labelsHidden()
            .frame(width: 180)
        }
    }

    // MARK: - Options

    private var goodsOptions: [(id: String, label: String)] {
        state.tradeRouteGoodsTypes
    }

    private var colonyOptions: [(id: String, label: String)] {
        guard let game = state.game else { return [] }
        return game.colonies.values
            .map { (id: $0.id, label: "\($0.name ?? $0.id) [\($0.owner ?? "?")]") }
            .sorted { $0.label < $1.label }
    }

    // MARK: - Actions

    private func syncDrafts() {
        drafts = state.pendingDiplomacyDrafts
    }

    private func addClause() {
        var draft = DiplomaticClauseDraft(kind: newKind, weGive: newWeGive)
        draft.goldAmount = Int(newGold) ?? 0
        draft.goodsType = newGoodsType
        draft.goodsAmount = Int(newGoodsAmount) ?? 0
        if newKind == .colony {
            draft.colonyId = newColonyId
            draft.colonyName = colonyOptions.first { $0.id == newColonyId }?.label ?? newColonyId
        }
        draft.stance = newStance
        draft.unitId = newUnitId
        draft.victimId = newVictimId
        drafts.append(draft)
    }
}

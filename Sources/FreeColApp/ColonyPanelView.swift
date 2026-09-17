import SwiftUI
import FreeColGame

struct ColonyPanelView: View {
    let colony: Colony
    let ownerName: String
    let units: [FreeColGame.Unit]
    let canManage: Bool
    let selectedWorkerUnitId: String?
    let onChangeWorkType: (String) -> Void
    let onChangeWorkImprovementType: (String) -> Void
    let onClearSpeciality: () -> Void
    let onAssignTeacher: (String) -> Void
    let onClearTeacher: () -> Void
    let onWorkAtLocation: (String) -> Void
    let onRenameColony: (String) -> Void
    let onPayForBuilding: () -> Void
    let onSetGoodsLevel: (ColonyExportData) -> Void
    let exportData: [ColonyExportData]
    let workLocationCandidates: [(id: String, label: String)]
    let workTypeCandidates: [(id: String, label: String)]
    let onAbandonColony: () -> Void
    let canAbandonColony: Bool
    let onSetBuildQueue: ([String]) -> Void
    let onPutOutsideColony: () -> Void
    let canPutOutsideColony: Bool
    let selectedCarrierId: String?
    let onLoadGoods: (String, Int) -> Void
    let onUnloadGoods: (String, Int) -> Void
    let buildableCandidates: [(id: String, label: String)]
    let buildings: [(id: String, label: String)]
    let currentBuildQueue: [String]
    let buildingLabel: (String) -> String
    let storedGoods: [(id: String, label: String, amount: Int)]
    let buildTargetLabel: String?
    let buildRequirements: [(id: String, label: String, required: Int, stored: Int)]
    let buildETATurns: Int?
    let estimatedBuildPerTurn: Int
    let estimatedProduction: [(id: String, label: String, amount: Int)]

    @State private var workTypeId: String = "model.goods.grain"
    @State private var workImprovementTypeId: String = "model.improvement.plow"
    @State private var teacherId: String = ""
    @State private var workLocationId: String = ""
    @State private var colonyNameInput: String
    @State private var buildQueueItems: [String] = []
    @State private var selectedBuildableId: String = ""
    @State private var goodsTypeId: String = "model.goods.grain"
    @State private var goodsAmountInput: String = "10"
    @State private var showAbandonConfirmation: Bool = false
    @State private var showWarehouse: Bool = false

    init(
        colony: Colony,
        ownerName: String,
        units: [FreeColGame.Unit],
        canManage: Bool,
        selectedWorkerUnitId: String?,
        onChangeWorkType: @escaping (String) -> Void,
        onChangeWorkImprovementType: @escaping (String) -> Void,
        onClearSpeciality: @escaping () -> Void,
        onAssignTeacher: @escaping (String) -> Void,
        onClearTeacher: @escaping () -> Void,
        onWorkAtLocation: @escaping (String) -> Void,
        onRenameColony: @escaping (String) -> Void,
        onPayForBuilding: @escaping () -> Void,
        onSetGoodsLevel: @escaping (ColonyExportData) -> Void,
        exportData: [ColonyExportData] = [],
        workLocationCandidates: [(id: String, label: String)] = [],
        workTypeCandidates: [(id: String, label: String)] = [],
        onAbandonColony: @escaping () -> Void,
        canAbandonColony: Bool,
        onSetBuildQueue: @escaping ([String]) -> Void,
        onPutOutsideColony: @escaping () -> Void,
        canPutOutsideColony: Bool,
        selectedCarrierId: String?,
        onLoadGoods: @escaping (String, Int) -> Void,
        onUnloadGoods: @escaping (String, Int) -> Void,
        buildableCandidates: [(id: String, label: String)] = [],
        buildings: [(id: String, label: String)] = [],
        currentBuildQueue: [String] = [],
        buildingLabel: @escaping (String) -> String = { $0 },
        storedGoods: [(id: String, label: String, amount: Int)] = [],
        buildTargetLabel: String? = nil,
        buildRequirements: [(id: String, label: String, required: Int, stored: Int)] = [],
        buildETATurns: Int? = nil,
        estimatedBuildPerTurn: Int = 0,
        estimatedProduction: [(id: String, label: String, amount: Int)] = []
    ) {
        self.colony = colony
        self.ownerName = ownerName
        self.units = units
        self.canManage = canManage
        self.selectedWorkerUnitId = selectedWorkerUnitId
        self.onChangeWorkType = onChangeWorkType
        self.onChangeWorkImprovementType = onChangeWorkImprovementType
        self.onClearSpeciality = onClearSpeciality
        self.onAssignTeacher = onAssignTeacher
        self.onClearTeacher = onClearTeacher
        self.onWorkAtLocation = onWorkAtLocation
        self.onRenameColony = onRenameColony
        self.onPayForBuilding = onPayForBuilding
        self.onSetGoodsLevel = onSetGoodsLevel
        self.exportData = exportData
        self.workLocationCandidates = workLocationCandidates
        self.workTypeCandidates = workTypeCandidates
        self.onAbandonColony = onAbandonColony
        self.canAbandonColony = canAbandonColony
        self.onSetBuildQueue = onSetBuildQueue
        self.onPutOutsideColony = onPutOutsideColony
        self.canPutOutsideColony = canPutOutsideColony
        self.selectedCarrierId = selectedCarrierId
        self.onLoadGoods = onLoadGoods
        self.onUnloadGoods = onUnloadGoods
        self.buildableCandidates = buildableCandidates
        self.buildings = buildings
        self.currentBuildQueue = currentBuildQueue
        self.buildingLabel = buildingLabel
        self.storedGoods = storedGoods
        self.buildTargetLabel = buildTargetLabel
        self.buildRequirements = buildRequirements
        self.buildETATurns = buildETATurns
        self.estimatedBuildPerTurn = estimatedBuildPerTurn
        self.estimatedProduction = estimatedProduction
        _colonyNameInput = State(initialValue: colony.name ?? "")
        _buildQueueItems = State(initialValue: currentBuildQueue)
        _selectedBuildableId = State(initialValue: buildableCandidates.first?.id ?? "")
    }

    var body: some View {
        GroupBox("Colony") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(colony.name ?? colony.id)
                        .font(.headline)
                    Spacer()
                    Text("\(colony.sonsOfLiberty)% SoL")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 4) {
                    GridRow {
                        Text("Owner")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(ownerName)
                            .font(.caption)
                    }
                    GridRow {
                        Text("Population")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(max(colony.unitCount, units.count))")
                            .font(.caption)
                    }
                    GridRow {
                        Text("Liberty")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(colony.liberty)")
                            .font(.caption)
                    }
                    GridRow {
                        Text("Immigration")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(colony.immigration)")
                            .font(.caption)
                    }
                }

                Divider()

                Text("Production")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 4) {
                    GridRow {
                        Text("Established")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(colony.established)")
                            .font(.caption2)
                    }
                    GridRow {
                        Text("Population")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(colony.unitCount)")
                            .font(.caption2)
                    }
                    GridRow {
                        Text("Production Bonus")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(colony.productionBonus)%")
                            .font(.caption2)
                    }
                    GridRow {
                        Text("Liberty / Immigration")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(colony.liberty) / \(colony.immigration)")
                            .font(.caption2)
                    }
                }

                Divider()

                Text("Units")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if units.isEmpty {
                    Text("No visible units in colony")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(units, id: \.id) { unit in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(unit.unitType ?? unit.id)
                                        .font(.caption)
                                    if selectedWorkerUnitId == unit.id {
                                        Text("Selected")
                                            .font(.caption2)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color.accentColor.opacity(0.15))
                                            .cornerRadius(4)
                                    }
                                }
                                Text(unitWorkLabel(unit))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(unit.state.rawValue)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("\(unit.movesLeft) MP")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Divider()

                Text("Actions")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField("Colony Name", text: $colonyNameInput)
                    .textFieldStyle(.roundedBorder)
                Button("Rename Colony") {
                    onRenameColony(colonyNameInput)
                }
                .buttonStyle(.bordered)
                .disabled(!canManage || colonyNameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || colonyNameInput.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(colony.name ?? "") == .orderedSame)

                Button("Pay For Building") {
                    onPayForBuilding()
                }
                .buttonStyle(.bordered)
                .disabled(!canManage)

                Button("Warehouse…") {
                    showWarehouse = true
                }
                .buttonStyle(.bordered)
                .disabled(!canManage)

                Button("Abandon Colony") {
                    showAbandonConfirmation = true
                }
                .buttonStyle(.bordered)
                .disabled(!canManage || !canAbandonColony)

                Text("Worker: \(selectedWorkerUnitId ?? "none")")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Picker("Work Type", selection: $workTypeId) {
                    ForEach(workTypeCandidates, id: \.id) { candidate in
                        Text(candidate.label).tag(candidate.id)
                    }
                }
                .disabled(!canManage || selectedWorkerUnitId == nil)
                Button("Change Work Type") {
                    onChangeWorkType(workTypeId)
                }
                .buttonStyle(.bordered)
                .disabled(!canManage || selectedWorkerUnitId == nil || workTypeId.isEmpty)

                TextField("Work Improvement Type ID", text: $workImprovementTypeId)
                    .textFieldStyle(.roundedBorder)
                Button("Change Work Improvement Type") {
                    onChangeWorkImprovementType(workImprovementTypeId)
                }
                .buttonStyle(.bordered)
                .disabled(!canManage || selectedWorkerUnitId == nil)

                Button("Clear Speciality") {
                    onClearSpeciality()
                }
                .buttonStyle(.bordered)
                .disabled(!canManage || selectedWorkerUnitId == nil)

                Picker("Teacher", selection: $teacherId) {
                    Text("None").tag("")
                    ForEach(units.filter { $0.id != selectedWorkerUnitId }, id: \.id) { candidate in
                        Text(candidate.unitType ?? candidate.id).tag(candidate.id)
                    }
                }
                .disabled(!canManage || selectedWorkerUnitId == nil)
                Button("Assign Teacher") {
                    onAssignTeacher(teacherId)
                }
                .buttonStyle(.bordered)
                .disabled(!canManage || selectedWorkerUnitId == nil || teacherId.isEmpty)

                Button("Clear Teacher") {
                    onClearTeacher()
                }
                .buttonStyle(.bordered)
                .disabled(!canManage || selectedWorkerUnitId == nil)

                if let selectedWorkerUnitId,
                   let selectedWorker = units.first(where: { $0.id == selectedWorkerUnitId }) {
                    Divider()
                    Text("Selected Worker")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(selectedWorker.unitType ?? selectedWorker.id)
                        .font(.caption)
                    Text(unitWorkLabel(selectedWorker))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("Teacher: \(selectedWorker.teacher ?? "none")")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                if workLocationCandidates.isEmpty {
                    Text("Keine Arbeitsplaetze verfügbar.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Picker("Work Location", selection: $workLocationId) {
                        ForEach(workLocationCandidates, id: \.id) { candidate in
                            Text(candidate.label).tag(candidate.id)
                        }
                    }
                    .disabled(!canManage || selectedWorkerUnitId == nil)
                    Button("Assign Worker") {
                        onWorkAtLocation(workLocationId)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!canManage || selectedWorkerUnitId == nil || workLocationId.isEmpty)
                }

                if buildTargetLabel != nil || !storedGoods.isEmpty {
                    Divider()

                    Text("Production Estimate")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let target = buildTargetLabel {
                        Text("Building: \(target)")
                            .font(.caption2)
                        ForEach(buildRequirements, id: \.id) { requirement in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(requirement.label)
                                        .font(.caption2)
                                    Spacer()
                                    Text("\(requirement.stored)/\(requirement.required)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                ProgressView(value: requirement.required > 0
                                             ? min(1.0, Double(requirement.stored) / Double(requirement.required))
                                             : 1.0)
                                    .frame(width: 180)
                            }
                        }
                        HStack {
                            Text("Estimated output")
                                .font(.caption2)
                            Spacer()
                            Text(estimatedBuildPerTurn > 0 ? "\(estimatedBuildPerTurn)/turn" : "—")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        if let eta = buildETATurns {
                            Text(eta == 0 ? "Ready next turn" : "≈ \(eta) turn(s) remaining")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    if !storedGoods.isEmpty {
                        Text("Stored Goods")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        ForEach(storedGoods, id: \.id) { item in
                            HStack {
                                Text(item.label)
                                    .font(.caption2)
                                Spacer()
                                Text("\(item.amount)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    if !estimatedProduction.isEmpty {
                        Text("Per-turn (estimated)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        ForEach(estimatedProduction, id: \.id) { item in
                            HStack {
                                Text(item.label)
                                    .font(.caption2)
                                Spacer()
                                Text(item.amount >= 0 ? "+\(item.amount)" : "\(item.amount)")
                                    .font(.caption2)
                                    .foregroundColor(item.amount >= 0 ? .green : .red)
                            }
                        }
                    }
                }

                Text("Buildings")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if buildings.isEmpty {
                    Text("No buildings reported.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(buildings, id: \.id) { building in
                        Text(building.label)
                            .font(.caption2)
                    }
                }

                Text("Build Queue")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if buildableCandidates.isEmpty {
                    Text("No buildable options available.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    HStack {
                        Picker("Buildable", selection: $selectedBuildableId) {
                            ForEach(buildableCandidates, id: \.id) { candidate in
                                Text(candidate.label).tag(candidate.id)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: 220)

                        Button("Add") {
                            addBuildQueueItem()
                        }
                        .buttonStyle(.bordered)
                        .disabled(!canManage || selectedBuildableId.isEmpty)
                    }
                }

                if buildQueueItems.isEmpty {
                    Text("No build queue set.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(buildQueueItems.enumerated()), id: \.offset) { index, item in
                            HStack {
                                Text(buildingLabel(item))
                                    .font(.caption2)
                                Spacer()
                                Button("Up") {
                                    moveBuildQueueItem(from: index, to: index - 1)
                                }
                                .buttonStyle(.bordered)
                                .disabled(!canManage || index == 0)

                                Button("Down") {
                                    moveBuildQueueItem(from: index, to: index + 1)
                                }
                                .buttonStyle(.bordered)
                                .disabled(!canManage || index == buildQueueItems.count - 1)

                                Button("Remove") {
                                    buildQueueItems.remove(at: index)
                                }
                                .buttonStyle(.bordered)
                                .disabled(!canManage)
                            }
                        }
                    }
                }

                HStack {
                    Button("Set Build Queue") {
                        onSetBuildQueue(buildQueueItems)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!canManage)

                    Button("Reset") {
                        buildQueueItems = currentBuildQueue
                    }
                    .buttonStyle(.bordered)
                    .disabled(!canManage || buildQueueItems == currentBuildQueue)
                }

                Button("Put Outside Colony") {
                    onPutOutsideColony()
                }
                .buttonStyle(.bordered)
                .disabled(!canManage || !canPutOutsideColony)

                Divider()

                Text("Goods")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Carrier: \(selectedCarrierId ?? "none")")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                TextField("Goods Type ID", text: $goodsTypeId)
                    .textFieldStyle(.roundedBorder)
                TextField("Amount", text: $goodsAmountInput)
                    .textFieldStyle(.roundedBorder)

                Button("Load Goods") {
                    let amount = Int(goodsAmountInput) ?? 0
                    onLoadGoods(goodsTypeId, amount)
                }
                .buttonStyle(.bordered)
                .disabled(!canManage || selectedCarrierId == nil)

                Button("Unload Goods") {
                    let amount = Int(goodsAmountInput) ?? 0
                    onUnloadGoods(goodsTypeId, amount)
                }
                .buttonStyle(.bordered)
                .disabled(!canManage || selectedCarrierId == nil)
            }
            .padding(.vertical, 4)
        }
        .confirmationDialog(
            "Abandon this colony?",
            isPresented: $showAbandonConfirmation,
            titleVisibility: .visible
        ) {
            Button("Abandon Colony", role: .destructive) {
                onAbandonColony()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the colony and cannot be undone.")
        }
        .sheet(isPresented: $showWarehouse) {
            WarehouseSheet(exportData: exportData, onApply: onSetGoodsLevel)
        }
        .onAppear {
            if workTypeId.isEmpty, let first = workTypeCandidates.first {
                workTypeId = first.id
            }
            if workLocationId.isEmpty, let first = workLocationCandidates.first {
                workLocationId = first.id
            }
        }
        .onChange(of: colony.buildQueue) { _, newQueue in
            // Keep the draft in sync with server-driven queue changes.
            buildQueueItems = newQueue
        }
    }

    private func addBuildQueueItem() {
        let trimmed = selectedBuildableId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !buildQueueItems.contains(trimmed) else { return }
        buildQueueItems.append(trimmed)
    }

    private func moveBuildQueueItem(from sourceIndex: Int, to targetIndex: Int) {
        guard buildQueueItems.indices.contains(sourceIndex),
              buildQueueItems.indices.contains(targetIndex) else {
            return
        }
        let item = buildQueueItems.remove(at: sourceIndex)
        buildQueueItems.insert(item, at: targetIndex)
    }

    private func unitWorkLabel(_ unit: FreeColGame.Unit) -> String {
        var parts: [String] = []
        if let workType = unit.workType, !workType.isEmpty {
            parts.append("Work: \(workType)")
        }
        if let workImprovement = unit.workImprovementType, !workImprovement.isEmpty {
            parts.append("Improvement: \(workImprovement)")
        }
        if let teacher = unit.teacher, !teacher.isEmpty {
            parts.append("Teacher: \(teacher)")
        }
        if parts.isEmpty {
            return "No work assignment"
        }
        return parts.joined(separator: " | ")
    }
}

/// Custom-house export/import settings for one colony (Java `WarehouseDialog`).
private struct WarehouseSheet: View {
    let exportData: [ColonyExportData]
    let onApply: (ColonyExportData) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var drafts: [String: ColonyExportData] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Warehouse")
                .font(.title3.bold())
            Text("Custom-house export and import levels per goods type.")
                .font(.caption)
                .foregroundColor(.secondary)

            if exportData.isEmpty {
                Text("No export settings received from the server.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(exportData) { entry in
                            if let binding = draftBinding(for: entry.goodsType) {
                                row(binding)
                                Divider()
                            }
                        }
                    }
                }
                .frame(maxHeight: 340)
            }

            HStack {
                Spacer()
                Button("Close") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(width: 480)
        .onAppear {
            drafts = Dictionary(uniqueKeysWithValues: exportData.map { ($0.goodsType, $0) })
        }
    }

    private func draftBinding(for goodsType: String) -> Binding<ColonyExportData>? {
        guard drafts[goodsType] != nil else { return nil }
        return Binding(
            get: { drafts[goodsType] ?? ColonyExportData(goodsType: goodsType,
                                                         exported: false,
                                                         importLevel: -1,
                                                         exportLevel: 50,
                                                         highLevel: 90,
                                                         lowLevel: 10) },
            set: { drafts[goodsType] = $0 }
        )
    }

    @ViewBuilder
    private func row(_ binding: Binding<ColonyExportData>) -> some View {
        let entry = binding.wrappedValue
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(goodsLabel(entry.goodsType))
                    .font(.caption.bold())
                Spacer()
                Toggle("Export", isOn: binding.exported)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                Button("Apply") { onApply(binding.wrappedValue) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            HStack(spacing: 12) {
                stepper("Import", value: binding.importLevel, range: -1...999)
                stepper("Export", value: binding.exportLevel, range: 0...999)
                stepper("Low", value: binding.lowLevel, range: 0...999)
                stepper("High", value: binding.highLevel, range: 0...999)
            }
        }
    }

    private func stepper(_ title: String,
                         value: Binding<Int>,
                         range: ClosedRange<Int>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            HStack(spacing: 4) {
                Text("\(value.wrappedValue)")
                    .font(.caption)
                    .frame(minWidth: 24, alignment: .trailing)
                Stepper("", value: value, in: range)
                    .labelsHidden()
            }
        }
    }

    private func goodsLabel(_ id: String) -> String {
        guard let range = id.range(of: "model.goods.") else { return id }
        return String(id[range.upperBound...])
    }
}

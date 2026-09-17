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
    let onSetGoodsLevels: () -> Void
    let onAbandonColony: () -> Void
    let canAbandonColony: Bool
    let onRearrangeColony: () -> Void
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
        onSetGoodsLevels: @escaping () -> Void,
        onAbandonColony: @escaping () -> Void,
        canAbandonColony: Bool,
        onRearrangeColony: @escaping () -> Void,
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
        self.onSetGoodsLevels = onSetGoodsLevels
        self.onAbandonColony = onAbandonColony
        self.canAbandonColony = canAbandonColony
        self.onRearrangeColony = onRearrangeColony
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

                Button("Set Goods Levels") {
                    onSetGoodsLevels()
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

                TextField("WorkType ID", text: $workTypeId)
                    .textFieldStyle(.roundedBorder)
                Button("Change Work Type") {
                    onChangeWorkType(workTypeId)
                }
                .buttonStyle(.bordered)
                .disabled(!canManage || selectedWorkerUnitId == nil)

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

                TextField("Teacher ID", text: $teacherId)
                    .textFieldStyle(.roundedBorder)
                Button("Assign Teacher") {
                    onAssignTeacher(teacherId)
                }
                .buttonStyle(.bordered)
                .disabled(!canManage || selectedWorkerUnitId == nil)

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

                TextField("Work Location ID", text: $workLocationId)
                    .textFieldStyle(.roundedBorder)
                Button("Work At Location") {
                    onWorkAtLocation(workLocationId)
                }
                .buttonStyle(.bordered)
                .disabled(!canManage || selectedWorkerUnitId == nil)

                Button("Rearrange Colony") {
                    onRearrangeColony()
                }
                .buttonStyle(.bordered)
                .disabled(!canManage)

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

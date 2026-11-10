import SwiftUI
import FreeColGame

struct ColonyTerrainProduction: Identifiable {
    var id: String { goodsType }
    let goodsType: String
    let baseAmount: Int?
    var estimatedAmount: Int? = nil
    var explanation: String? = nil

    var label: String {
        if let estimatedAmount {
            return L10n.text("\(GameLabels.name(goodsType)): etwa \(estimatedAmount) pro Runde", table: "ColonyTerrainView")
        }
        return GameLabels.name(goodsType) + (baseAmount.map {
            L10n.text(": Basis \($0)", table: "ColonyTerrainView")
        } ?? "")
    }
}

struct ColonyTerrainField: Identifiable {
    var id: String { tile.id }
    let tile: Tile
    let offset: CGPoint
    let workLocationId: String?
    let workers: [FreeColGame.Unit]
    let unavailableReason: String?
    var canBuyLand: Bool = false
    var production: [ColonyTerrainProduction] = []
    var workOptions: [ColonyTerrainProduction] = []
}

struct ColonyTerrainView: View {
    let fields: [ColonyTerrainField]
    let selectedWorkerId: String?
    let canManage: Bool
    let onAssign: (String) -> Void
    var onSelectWorker: ((String) -> Void)? = nil
    var onSelectField: ((ColonyTerrainField) -> Void)? = nil
    var onClaimLand: ((ColonyTerrainField) -> Void)? = nil
    var showsHeader: Bool = true
    var showsInstructions: Bool = true
    var onDropWorker: ((String, ColonyTerrainField) -> Bool)? = nil
    var workerContextMenu: ((String) -> AnyView)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if showsHeader {
                Text(L10n.text("Koloniegelände", table: "ColonyTerrainView")).font(.headline)
            }
            if showsInstructions {
                Text(L10n.text("Arbeiter auswählen, dann ein Feld anklicken. Ein belegtes Feld tauscht die Arbeiter.", table: "ColonyTerrainView"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(L10n.text("Besetzte Felder zeigen die Produktionsvorhersage mit Boni; freie Felder zeigen Basiswerte. Details stehen im Tooltip.", table: "ColonyTerrainView"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geometry in
                let width = geometry.size.width / 3
                let height = width / 2
                ZStack {
                    ForEach(fields) { field in
                        Button {
                            guard !field.canBuyLand else { return }
                            if let onSelectField {
                                onSelectField(field)
                            } else if let locationId = field.workLocationId {
                                onAssign(locationId)
                            }
                        } label: {
                            ZStack {
                                if let image = TileImageCache.shared.terrainImage(forType: field.tile.type) {
                                    Image(nsImage: image)
                                        .resizable()
                                        .frame(width: width, height: height)
                                } else {
                                    Diamond().fill(.gray)
                                }
                                if let image = TileImageCache.shared.terrainOverlay(forType: field.tile.type) {
                                    Image(nsImage: image)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: width, height: height)
                                }
                                Canvas { context, size in
                                    TileImprovementRenderer.draw(
                                        field.tile.improvements, in: &context,
                                        rect: CGRect(origin: .zero, size: size)
                                    )
                                }
                                .frame(width: width, height: height)
                                if let image = TileImageCache.shared.highSeasExitImage(for: field.tile) {
                                    Image(nsImage: image)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: width, height: width * image.size.height / max(1, image.size.width))
                                }
                                ForEach(field.tile.resources) { resource in
                                    if let image = TileImageCache.shared.resourceImage(for: resource.type) {
                                        Image(nsImage: image)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: width * 0.35, height: height * 0.7)
                                            .offset(x: -width * 0.22, y: -height * 0.1)
                                    }
                                }
                                Diamond().stroke(
                                    field.workers.contains(where: { $0.id == selectedWorkerId }) ? .yellow : .white.opacity(0.5),
                                    lineWidth: 2
                                )
                                if field.offset == .zero {
                                    VStack(spacing: 2) {
                                        Label(L10n.text("Zentrum", table: "ColonyTerrainView"), systemImage: "house.fill")
                                            .font(.caption2.bold())
                                            .labelStyle(.iconOnly)
                                        productionBadges(field)
                                    }
                                    .padding(3)
                                    .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 3))
                                } else if let worker = field.workers.first, onSelectWorker == nil {
                                    VStack(spacing: 0) {
                                        workerPortrait(worker, height: height)
                                        productionBadges(field)
                                    }
                                } else if !field.workers.isEmpty {
                                    productionBadges(field)
                                } else if field.unavailableReason != nil {
                                    Image(systemName: "lock.fill")
                                        .foregroundStyle(.white)
                                        .shadow(color: .black, radius: 2)
                                }
                            }
                            .foregroundStyle(.white)
                            .frame(width: width, height: height)
                            .contentShape(Diamond())
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(TapGesture(count: 2).onEnded {
                            guard field.canBuyLand else { return }
                            onClaimLand?(field)
                        })
                        .disabled(
                            !canManage || (!field.canBuyLand && (
                                selectedWorkerId == nil || field.unavailableReason != nil
                                    || field.workLocationId == nil
                            ))
                        )
                        .help(fieldHelp(field))
                        .accessibilityLabel(fieldHelp(field))
                        .accessibilityIdentifier("colony-field-\(field.id)")
                        .position(
                            x: geometry.size.width / 2 + field.offset.x * width,
                            y: geometry.size.height / 2 + field.offset.y * height)

                        if let worker = field.workers.first,
                            field.offset != .zero,
                            let onSelectWorker
                        {
                            Button {
                                onSelectWorker(worker.id)
                            } label: {
                                workerPortrait(worker, height: height * 0.62)
                                    .frame(width: width * 0.36, height: height * 0.64)
                                    .background(.black.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(
                                                worker.id == selectedWorkerId ? .yellow : .clear,
                                                lineWidth: 2
                                            )
                                    }
                            }
                            .buttonStyle(.plain)
                            .disabled(!canManage)
                            .draggable(worker.id)
                            .contextMenu {
                                if worker.id == selectedWorkerId, let workerContextMenu {
                                    workerContextMenu(worker.id)
                                }
                            }
                            .help(
                                worker.id == selectedWorkerId
                                    ? L10n.text("Rechtsklick für Ausbildungsaktionen", table: "ColonyPanelView")
                                    : L10n.text(
                                        "\(worker.unitType.map(GameLabels.name) ?? L10n.text("Arbeiter", table: "ColonyTerrainView")) auswählen",
                                        table: "ColonyTerrainView")
                            )
                            .accessibilityLabel(
                                L10n.text(
                                    "\(worker.unitType.map(GameLabels.name) ?? L10n.text("Arbeiter", table: "ColonyTerrainView")) auswählen",
                                    table: "ColonyTerrainView")
                            )
                            .accessibilityIdentifier("colony-field-worker-\(worker.id)")
                            .position(
                                x: geometry.size.width / 2 + field.offset.x * width,
                                y: geometry.size.height / 2 + field.offset.y * height - height * 0.08
                            )
                            .zIndex(1)
                        }
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .dropDestination(for: String.self) { items, point in
                    guard items.count == 1, let onDropWorker,
                        let field = fields.first(where: { field in
                              let centerX = geometry.size.width / 2 + field.offset.x * width
                              let centerY = geometry.size.height / 2 + field.offset.y * height
                              return abs(point.x - centerX) / (width / 2)
                                  + abs(point.y - centerY) / (height / 2) <= 1
                          }) else { return false }
                    return onDropWorker(items[0], field)
                }
            }
            .aspectRatio(2, contentMode: .fit)
            .frame(maxWidth: 540)
        }
    }

    private func productionBadges(_ field: ColonyTerrainField) -> some View {
        let outputs = field.workers.isEmpty && field.offset != .zero
            ? field.workOptions : field.production
        return HStack(spacing: 4) {
            ForEach(outputs) { output in
                HStack(spacing: 2) {
                    if let image = TileImageCache.shared.goodsImage(for: output.goodsType) {
                        Image(nsImage: image).resizable().scaledToFit().frame(width: 20, height: 20)
                    } else {
                        Image(systemName: "shippingbox.fill")
                    }
                    if let amount = output.estimatedAmount ?? output.baseAmount {
                        Text("\(amount)").font(.caption2.bold())
                    }
                }
                .padding(2)
                .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 3))
                .help(output.explanation ?? output.label)
                .accessibilityLabel(output.label)
                .accessibilityIdentifier("colony-production-\(field.id)-\(output.goodsType)")
            }
        }
    }

    private func workerPortrait(_ worker: FreeColGame.Unit, height: CGFloat) -> some View {
        Group {
            if let image = TileImageCache.shared.unitImage(
                forUnitType: worker.unitType, role: worker.role
            ) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: height)
            } else {
                Image(systemName: "person.fill")
                    .font(.caption)
                    .frame(height: height)
            }
        }
    }

    private func fieldHelp(_ field: ColonyTerrainField) -> String {
        let name = field.tile.type.map(GameLabels.name) ?? L10n.text("Unbekanntes Gelände", table: "ColonyTerrainView")
        if field.canBuyLand {
            return L10n.text("\(name): Doppelklick auf das Schlosssymbol, um dieses Land zu kaufen.", table: "ColonyTerrainView")
        }
        let production = field.production.isEmpty ? "" : "\n" + L10n.text("Produktion:", table: "ColonyTerrainView") + "\n"
            + field.production.map { $0.explanation ?? $0.label }.joined(separator: "\n")
        if let reason = field.unavailableReason {
            return L10n.text("\(name): \(reason)\(production)", table: "ColonyTerrainView")
        }
        let workers = field.workers.map { $0.unitType.map(GameLabels.name) ?? L10n.text("Arbeiter", table: "ColonyTerrainView") }.joined(separator: ", ")
        let work = workers.isEmpty
            ? L10n.text("Freies Feld – Arbeiter zuweisen", table: "ColonyTerrainView")
            : workers + " – " + L10n.text("Arbeiter tauschen", table: "ColonyTerrainView")
        return L10n.text("\(name): \(work)\(production)", table: "ColonyTerrainView")
    }

    private struct Diamond: Shape {
        func path(in rect: CGRect) -> Path {
            Path { path in
                path.move(to: CGPoint(x: rect.midX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
                path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
                path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
                path.closeSubpath()
            }
        }
    }
}

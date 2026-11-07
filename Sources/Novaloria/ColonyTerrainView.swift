import SwiftUI
import FreeColGame

struct ColonyTerrainProduction: Identifiable {
    var id: String { goodsType }
    let goodsType: String
    let baseAmount: Int?

    var label: String {
        GameLabels.name(goodsType) + (baseAmount.map { ": Basis \($0)" } ?? "")
    }
}

struct ColonyTerrainField: Identifiable {
    var id: String { tile.id }
    let tile: Tile
    let offset: CGPoint
    let workLocationId: String?
    let workers: [FreeColGame.Unit]
    let unavailableReason: String?
    var production: [ColonyTerrainProduction] = []
    var workOptions: [ColonyTerrainProduction] = []
}

struct ColonyTerrainView: View {
    let fields: [ColonyTerrainField]
    let selectedWorkerId: String?
    let canManage: Bool
    let onAssign: (String) -> Void
    var onSelectField: ((ColonyTerrainField) -> Void)? = nil
    var showsHeader: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if showsHeader {
                Text("Koloniegelände").font(.headline)
            }
            Text("Arbeiter auswählen, dann ein Feld anklicken. Ein belegtes Feld tauscht die Arbeiter.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Warensymbole zeigen die Produktion. Mengen sind Basiswerte ohne Arbeiter- und Geländeboni.")
                .font(.caption2)
                .foregroundStyle(.secondary)
            GeometryReader { geometry in
                let width = geometry.size.width / 3
                let height = width / 2
                ForEach(fields) { field in
                    Button {
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
                                    Label("Zentrum", systemImage: "house.fill")
                                        .font(.caption2.bold())
                                    productionBadges(field)
                                }
                                .padding(3)
                                .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 3))
                            } else if let worker = field.workers.first {
                                VStack(spacing: 0) {
                                    if let image = TileImageCache.shared.unitImage(
                                        forUnitType: worker.unitType, role: worker.role
                                    ) {
                                        Image(nsImage: image).resizable().scaledToFit().frame(height: height * 0.6)
                                    }
                                    productionBadges(field)
                                }
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
                    .disabled(!canManage || selectedWorkerId == nil || field.unavailableReason != nil
                              || field.workLocationId == nil)
                    .help(fieldHelp(field))
                    .accessibilityLabel(fieldHelp(field))
                    .accessibilityIdentifier("colony-field-\(field.id)")
                    .position(x: geometry.size.width / 2 + field.offset.x * width,
                              y: geometry.size.height / 2 + field.offset.y * height)
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
                    if let amount = output.baseAmount {
                        Text("\(amount)").font(.caption2.bold())
                    }
                }
                .padding(2)
                .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 3))
                .help(output.label)
                .accessibilityLabel(output.label)
                .accessibilityIdentifier("colony-production-\(field.id)-\(output.goodsType)")
            }
        }
    }

    private func fieldHelp(_ field: ColonyTerrainField) -> String {
        let name = field.tile.type.map(GameLabels.name) ?? "Unbekanntes Gelände"
        let production = field.production.isEmpty ? "" : " Produktion: "
            + field.production.map(\.label).joined(separator: ", ") + "."
        if let reason = field.unavailableReason { return "\(name): \(reason)\(production)" }
        let workers = field.workers.map { $0.unitType.map(GameLabels.name) ?? "Arbeiter" }.joined(separator: ", ")
        return "\(name): \(workers.isEmpty ? "Freies Feld – Arbeiter zuweisen" : workers + " – Arbeiter tauschen")\(production)"
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

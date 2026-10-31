import SwiftUI
import FreeColGame

struct ColonyTerrainField: Identifiable {
    var id: String { tile.id }
    let tile: Tile
    let offset: CGPoint
    let workLocationId: String?
    let workers: [FreeColGame.Unit]
    let unavailableReason: String?
}

struct ColonyTerrainView: View {
    let fields: [ColonyTerrainField]
    let selectedWorkerId: String?
    let canManage: Bool
    let onAssign: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Koloniegelände").font(.headline)
            Text("Arbeiter auswählen, dann ein Feld anklicken. Ein belegtes Feld tauscht die Arbeiter.")
                .font(.caption)
                .foregroundStyle(.secondary)
            GeometryReader { geometry in
                let width = geometry.size.width / 3
                let height = width / 2
                ForEach(fields) { field in
                    Button {
                        if let locationId = field.workLocationId { onAssign(locationId) }
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
                            Diamond().stroke(
                                field.workers.contains(where: { $0.id == selectedWorkerId }) ? .yellow : .white.opacity(0.5),
                                lineWidth: 2
                            )
                            if field.offset == .zero {
                                Label("Zentrum", systemImage: "house.fill")
                                    .font(.caption2.bold())
                                    .padding(3)
                                    .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 3))
                            } else if let worker = field.workers.first {
                                VStack(spacing: 0) {
                                    if let image = TileImageCache.shared.unitImage(forUnitType: worker.unitType) {
                                        Image(nsImage: image).resizable().scaledToFit().frame(height: height * 0.6)
                                    }
                                    Text(worker.workType.map(GameLabels.name) ?? "Arbeiter")
                                        .font(.caption2)
                                        .lineLimit(1)
                                        .padding(2)
                                        .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 3))
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

    private func fieldHelp(_ field: ColonyTerrainField) -> String {
        let name = field.tile.type.map(GameLabels.name) ?? "Unbekanntes Gelände"
        if let reason = field.unavailableReason { return "\(name): \(reason)" }
        let workers = field.workers.map { $0.unitType.map(GameLabels.name) ?? "Arbeiter" }.joined(separator: ", ")
        return "\(name): \(workers.isEmpty ? "Freies Feld – Arbeiter zuweisen" : workers + " – Arbeiter tauschen")"
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

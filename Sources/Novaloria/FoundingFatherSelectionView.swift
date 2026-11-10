import SwiftUI

struct FoundingFatherSelectionView: View {
    let options: [GameState.FoundingFatherOption]
    let canChoose: Bool
    let onChoose: (String) -> Void

    private var entriesById: [String: ColopediaEntry] {
        Dictionary(
            uniqueKeysWithValues: ColopediaCatalog.classicEntries
                .filter { $0.category == .fathers }
                .map { ($0.id, $0) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.text("Kontinentalkongress", table: "FoundingFatherSelectionView"))
                .font(.title2.bold())
            Text(L10n.text("Wähle einen Gründervater aus.", table: "FoundingFatherSelectionView"))
                .font(.body)
                .foregroundColor(.secondary)
            GeometryReader { geometry in
                let spacing: CGFloat = 16
                let minimumCardWidth: CGFloat = 640
                let columnCount = max(1, min(2, Int((geometry.size.width + spacing)
                                                    / (minimumCardWidth + spacing))))
                let rows = stride(from: 0, to: options.count, by: columnCount).map { start in
                    Array(options[start..<min(start + columnCount, options.count)])
                }

                ScrollView(.vertical) {
                    Grid(alignment: .leading, horizontalSpacing: spacing, verticalSpacing: spacing) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                            GridRow(alignment: .top) {
                                ForEach(row) { option in
                                    fatherButton(option, entry: entriesById[option.fatherId])
                                        .frame(maxWidth: .infinity, alignment: .topLeading)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(4)
                    if options.isEmpty {
                        Text(L10n.text("Keine Kandidaten verfügbar.", table: "FoundingFatherSelectionView"))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .scrollIndicators(.visible)
            }
        }
        .padding(16)
        .frame(minWidth: 0, maxWidth: .infinity)
        .frame(minHeight: 360, maxHeight: .infinity)
        .background(.regularMaterial)
    }

    private func fatherButton(
        _ option: GameState.FoundingFatherOption,
        entry: ColopediaEntry?
    ) -> some View {
        Button {
            onChoose(option.fatherId)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 14) {
                    if let entry {
                        entryIcon(entry)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry?.title ?? option.label)
                            .font(.title3.bold())
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(2)
                        Text(categoryLabel(option.typeKey))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                if let entry {
                    if !entry.summary.isEmpty {
                        Text(entry.summary)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(4)
                    }
                    if !entry.text.isEmpty {
                        Text(entry.text)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(5)
                    }
                    ForEach(Array(entry.facts.enumerated()), id: \.offset) { _, fact in
                        LabeledContent(fact.label, value: fact.value)
                            .font(.callout)
                    }
                }
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, minHeight: 320, alignment: .topLeading)
            .padding(16)
            .contentShape(Rectangle())
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.primary.opacity(0.14), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(!canChoose)
        .accessibilityIdentifier("founding-father-entry-\(option.fatherId)")
    }

    private func categoryLabel(_ key: String) -> String {
        switch key.lowercased() {
        case "trade": return L10n.text("Handel", table: "FoundingFatherSelectionView")
        case "exploration": return L10n.text("Erkundung", table: "FoundingFatherSelectionView")
        case "military": return L10n.text("Militär", table: "FoundingFatherSelectionView")
        case "political": return L10n.text("Politik", table: "FoundingFatherSelectionView")
        case "religious": return L10n.text("Religion", table: "FoundingFatherSelectionView")
        default: return GameLabels.name(key)
        }
    }

    @ViewBuilder
    private func entryIcon(_ entry: ColopediaEntry) -> some View {
        if let image = TileImageCache.shared.colopediaImage(for: entry) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
        } else {
            Image(systemName: entry.category.symbol)
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
                .frame(width: 64, height: 64)
                .foregroundStyle(Color.accentColor)
        }
    }
}

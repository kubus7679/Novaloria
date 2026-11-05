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
        VStack(alignment: .leading, spacing: 8) {
            Text("Continental Congress")
                .font(.headline)
            Text("Choose a founding father.")
                .font(.callout)
                .foregroundColor(.secondary)
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 8)], spacing: 8) {
                    ForEach(options) { option in
                        fatherButton(option, entry: entriesById[option.fatherId])
                    }
                }
                .padding(4)
                if options.isEmpty {
                    Text("No candidates available.")
                        .foregroundColor(.secondary)
                }
            }
            .scrollIndicators(.visible)
            .clipped()
        }
        .padding(12)
        .frame(minWidth: 0, maxWidth: .infinity)
        .frame(height: 220)
        .background(.regularMaterial)
    }

    private func fatherButton(
        _ option: GameState.FoundingFatherOption,
        entry: ColopediaEntry?
    ) -> some View {
        Button {
            onChoose(option.fatherId)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 8) {
                    if let entry {
                        entryIcon(entry)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(entry?.title ?? option.label)
                            .font(.callout.bold())
                        Text(option.typeKey.capitalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if let entry {
                    if !entry.summary.isEmpty {
                        Text(entry.summary)
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !entry.text.isEmpty {
                        Text(entry.text)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    ForEach(Array(entry.facts.enumerated()), id: \.offset) { _, fact in
                        LabeledContent(fact.label, value: fact.value)
                            .font(.caption2)
                    }
                }
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.bordered)
        .disabled(!canChoose)
        .accessibilityIdentifier("founding-father-entry-\(option.fatherId)")
    }

    @ViewBuilder
    private func entryIcon(_ entry: ColopediaEntry) -> some View {
        if let image = TileImageCache.shared.colopediaImage(for: entry) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)
        } else {
            Image(systemName: entry.category.symbol)
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
                .frame(width: 48, height: 48)
                .foregroundStyle(Color.accentColor)
        }
    }
}

import SwiftUI
import FreeColGame

struct ColopediaView: View {
    @Environment(GameState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var selectedEntryId: String?
    @State private var categoryFilter: ColopediaCategory?

    init(selectedEntryId: String? = nil, categoryFilter: ColopediaCategory? = nil) {
        _selectedEntryId = State(initialValue: selectedEntryId)
        _categoryFilter = State(initialValue: categoryFilter)
    }

    private var entries: [ColopediaEntry] {
        ColopediaCatalog.entries(specification: state.game?.specification)
    }

    private var selectedEntry: ColopediaEntry? {
        entries.first { $0.id == selectedEntryId }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.text("Colopädie", table: "ColopediaView")).font(.title2.bold())
                Spacer()
                Button(L10n.text("Schließen", table: "ColopediaView")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            TextField(L10n.text("Einträge auf Deutsch durchsuchen", table: "ColopediaView"), text: $query)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("colopedia-search")
            Picker(L10n.text("Kategorie", table: "ColopediaView"), selection: $categoryFilter) {
                Text(L10n.text("Alle Kategorien", table: "ColopediaView")).tag(Optional<ColopediaCategory>.none)
                ForEach(ColopediaCategory.allCases, id: \.self) { category in
                    Text(category.title).tag(Optional(category))
                }
            }
            HStack(spacing: 0) {
                let filtered = ColopediaCatalog.search(entries, query: query)
                    .filter { categoryFilter == nil || $0.category == categoryFilter }
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(ColopediaCategory.allCases, id: \.self) { category in
                            let items = filtered.filter { $0.category == category }
                            if !items.isEmpty {
                                Label(category.title, systemImage: category.symbol)
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 10)
                                ForEach(items) { entry in
                                    Button {
                                        selectedEntryId = entry.id
                                    } label: {
                                        HStack {
                                            entryIcon(entry, size: 28)
                                            Text(entry.title)
                                                .lineLimit(2)
                                                .multilineTextAlignment(.leading)
                                            Spacer(minLength: 0)
                                        }
                                        .padding(5)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(
                                            selectedEntryId == entry.id ? Color.accentColor.opacity(0.25) : .clear,
                                            in: RoundedRectangle(cornerRadius: 5)
                                        )
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("colopedia-entry-\(entry.id)")
                                }
                            }
                        }
                        if filtered.isEmpty {
                            Text(L10n.text("Keine passenden Einträge.", table: "ColopediaView")).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.trailing, 10)
                }
                .frame(width: 220)
                Divider()
                ScrollView {
                    if let entry = selectedEntry {
                        entryDetails(entry)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                    } else {
                        Text(entries.isEmpty
                             ? L10n.text("Die Colopädie-Ressourcen konnten nicht geladen werden.", table: "ColopediaView")
                             : L10n.text("Wähle links einen Eintrag, um Beschreibung und Spielwerte zu sehen.", table: "ColopediaView"))
                            .foregroundStyle(entries.isEmpty ? .red : .secondary)
                            .padding()
                    }
                }
            }
            Text(L10n.text("Klassisches Regelwerk. Verfügbare Spielwerte werden aus der aktuellen Serverspezifikation übernommen.", table: "ColopediaView"))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(minWidth: 700, idealWidth: 900, maxWidth: 1100, minHeight: 420, idealHeight: 620, maxHeight: 760)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            if selectedEntryId == nil {
                selectedEntryId = entries.first {
                    categoryFilter == nil || $0.category == categoryFilter
                }?.id
            } else {
                categoryFilter = selectedEntry?.category
            }
        }
        .onChange(of: query) { _, value in
            if !value.isEmpty { categoryFilter = nil }
        }
        .onChange(of: categoryFilter) { _, category in
            if let category, selectedEntry?.category != category {
                selectedEntryId = entries.first { $0.category == category }?.id
            }
        }
    }

    private func entryDetails(_ entry: ColopediaEntry) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                entryIcon(entry, size: 80)
                VStack(alignment: .leading) {
                    Text(entry.title).font(.title2.bold())
                    Text(entry.category.title).foregroundStyle(.secondary)
                }
            }
            if !entry.summary.isEmpty { Text(entry.summary).textSelection(.enabled) }
            if !entry.text.isEmpty { Text(entry.text).textSelection(.enabled) }
            let facts = entry.facts(using: state.game?.specification)
            if !facts.isEmpty {
                Divider()
                ForEach(Array(facts.enumerated()), id: \.offset) { _, fact in
                    LabeledContent(fact.label, value: fact.value)
                        .font(.callout)
                }
            }
            let related = entries.filter { entry.related.contains($0.id) }
            if !related.isEmpty {
                Divider()
                Text(L10n.text("Verwandte Einträge", table: "ColopediaView")).font(.headline)
                ForEach(related) { item in
                    Button {
                        query = ""
                        categoryFilter = item.category
                        selectedEntryId = item.id
                    } label: {
                        HStack {
                            entryIcon(item, size: 24)
                            Text(item.title)
                            Image(systemName: "arrow.right")
                        }
                    }
                    .buttonStyle(.link)
                    .accessibilityIdentifier("colopedia-link-\(item.id)")
                }
            }
            if entry.summary.isEmpty && entry.text.isEmpty && facts.isEmpty {
                Text(L10n.text("Für diesen Eintrag sind im Regelwerk keine weiteren Informationen hinterlegt.", table: "ColopediaView"))
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("colopedia-detail-\(entry.id)")
    }

    @ViewBuilder
    private func entryIcon(_ entry: ColopediaEntry, size: CGFloat) -> some View {
        if let image = TileImageCache.shared.colopediaImage(for: entry) {
            Image(nsImage: image).resizable().scaledToFit().frame(width: size, height: size)
        } else {
            Image(systemName: entry.category.symbol)
                .resizable().scaledToFit().frame(width: size * 0.6, height: size * 0.6)
                .frame(width: size, height: size)
                .foregroundStyle(Color.accentColor)
        }
    }
}

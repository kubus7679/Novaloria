import SwiftUI

struct FoundingFatherSelectionView: View {
    let options: [GameState.FoundingFatherOption]
    let canChoose: Bool
    let onChoose: (String) -> Void

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
                        Button {
                            onChoose(option.fatherId)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(option.label)
                                    .font(.callout.bold())
                                Text(option.typeKey.capitalized)
                                    .font(.caption)
                            }
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .padding(4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.bordered)
                        .disabled(!canChoose)
                        .accessibilityIdentifier(option.fatherId)
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
}

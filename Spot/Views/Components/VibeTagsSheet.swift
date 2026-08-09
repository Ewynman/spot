import SwiftUI

/// Full-width informational sheet listing all vibes on a Spot.
struct VibeTagsSheet: View {
    let labels: [String]
    let activeLabel: String?

    private let columns = [
        GridItem(.flexible(), spacing: 10, alignment: .leading),
        GridItem(.flexible(), spacing: 10, alignment: .leading)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Capsule()
                .fill(Color.gray.opacity(0.4))
                .frame(width: 42, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

            HStack(alignment: .firstTextBaseline) {
                Text("Vibe Tags")
                    .font(FontManager.sectionHeader())
                    .foregroundColor(Constants.Colors.primary)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                Text("\(labels.count) \(labels.count == 1 ? "Vibe" : "Vibes")")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            ScrollView {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                    ForEach(labels, id: \.self) { tag in
                        let isActive = tag == activeLabel
                        Text(tag)
                            .font(FontManager.primaryText())
                            .foregroundColor(Constants.Colors.primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Constants.Colors.accent)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Constants.Colors.primary.opacity(isActive ? 0.55 : 0), lineWidth: 1.5)
                            )
                            .overlay(alignment: .topTrailing) {
                                if isActive {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(Constants.Colors.primary)
                                        .offset(x: 6, y: -6)
                                }
                            }
                            .accessibilityLabel(isActive ? "\(tag), currently showing" : tag)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Constants.Colors.background)
        .presentationDetents([.height(sheetHeight), .medium])
        .presentationDragIndicator(.hidden)
        .presentationBackground(Constants.Colors.background)
        .accessibilityIdentifier("vibeTagsSheet")
    }

    private var sheetHeight: CGFloat {
        let rows = max(1, Int(ceil(Double(labels.count) / 2.0)))
        return CGFloat(140 + rows * 48)
    }
}

#if DEBUG
#Preview {
    VibeTagsSheet(
        labels: ["Scenic View", "Cruising", "Nature Escape"],
        activeLabel: "Cruising"
    )
}
#endif

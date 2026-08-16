import SwiftUI

/// Non-interactive, cached MapKit snapshot used by the back of a Home card.
struct HomeSpotMapPreview: View {
    let spot: Spot
    let width: CGFloat
    let height: CGFloat
    let onOpen: () -> Void

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?
    @State private var failed = false

    private var requestIdentity: String {
        let latitude = spot.latitude.map { String($0) } ?? "nil"
        let longitude = spot.longitude.map { String($0) } ?? "nil"
        let pixelWidth = String(Int(width.rounded()))
        let pixelHeight = String(Int(height.rounded()))
        return "\(spot.safeId)|\(latitude)|\(longitude)|\(pixelWidth)|\(pixelHeight)|\(displayScale)"
    }

    var body: some View {
        ZStack {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Constants.Colors.accent.opacity(0.72)
                        .overlay {
                            if failed {
                                Label("Map unavailable", systemImage: "map")
                                    .font(FontManager.primaryText())
                                    .foregroundColor(Constants.Colors.primary.opacity(0.7))
                            }
                        }
                }
            }
            .frame(width: width, height: height)
            .clipped()
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpen)

            if image != nil {
                SpotMarkerView()
                    .offset(y: -(Constants.MapDesign.pinHeight / 2))
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: onOpen) {
                        Label("Open in Map", systemImage: "arrow.up.right")
                            .font(FontManager.buttonText())
                            .foregroundColor(Constants.Colors.buttonText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Constants.Colors.primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("home.spotCard.openInMap")
                }
                .padding(12)
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.CornerRadius.medium))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Map showing \(SpotPlaceFormatting.title(for: spot))")
        .task(id: requestIdentity) {
            image = nil
            failed = false
            do {
                image = try await SpotMapPreviewSnapshotService.shared.snapshot(
                    for: spot,
                    size: CGSize(width: width, height: height),
                    displayScale: displayScale
                )
            } catch is CancellationError {
                return
            } catch {
                failed = true
                SpotLogger.log(SpotCardLogs.mapPreviewFailed, details: [
                    "spotId": spot.safeId,
                    "error": error.localizedDescription
                ])
                AnalyticsService.shared.logEvent("home_spot_map_preview_failed", parameters: [
                    "spot_id": spot.safeId,
                    "source": "home"
                ])
            }
        }
    }
}


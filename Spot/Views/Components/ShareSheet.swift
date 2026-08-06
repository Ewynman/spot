//
//  ShareSheet.swift
//  Spot
//
//  Created by Wynman, Edward on 8/14/25.
//

import SwiftUI
import LinkPresentation

struct ShareSheet: View {
    let spot: Spot
    @Environment(\.dismiss) private var dismiss
    @State private var shareItems: [Any] = []
    @State private var isLoading = true

    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Preparing share...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ShareActivityView(activityItems: shareItems)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Share Spot")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(FontManager.primaryText())
                        .foregroundColor(Constants.Colors.primary)
                        .buttonStyle(.plain)
                }
            }
        }
        .onAppear {
            prepareShareItems()
        }
    }

    private func prepareShareItems() {
        Task {
            // Universal link that will deep link to app or redirect to App Store
            let spotUrl = URLConfiguration.shared.shareURL(for: spot.safeId)
            let metadata = LPLinkMetadata()
            metadata.originalURL = URL(string: spotUrl)
            metadata.url = metadata.originalURL
            metadata.title = spot.locationName ?? "Check out this Spot"
            metadata.imageProvider = nil

            // Create subtitle with vibe and username
            var subtitle = ""
            if let vibe = spot.vibeTag, !vibe.isEmpty {
                subtitle += vibe
            }
            if let username = spot.username, !username.isEmpty {
                if !subtitle.isEmpty { subtitle += " • " }
                subtitle += "by @\(username)"
            }

            if !subtitle.isEmpty {
                metadata.setValue(subtitle, forKey: "summary")
            }

            // Try to load image for preview
            if let imageURL = spot.imageURL, let url = URL(string: imageURL) {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    if let image = UIImage(data: data) {
                        metadata.imageProvider = NSItemProvider(object: image)
                    }
                } catch {
                    SpotLogger.log(ShareSheetLogs.imageLoadFailed, details: ["error": error.localizedDescription])
                }
            }

            let linkItem = SpotShareItem(url: spotUrl, metadata: metadata)

            await MainActor.run {
                shareItems = [linkItem, spotUrl]
                isLoading = false
                SpotLogger.log(ShareSheetLogs.sharePrepared, details: ["spotId": spot.safeId])
            }
        }
    }
}

#Preview {
    let sample = Spot(
        id: "s1",
        userId: "u1",
        username: "eddie",
        imageURL: "https://picsum.photos/seed/share/800/600",
        vibeTag: "Sunset",
        latitude: 37.7749,
        longitude: -122.4194,
        locationName: "San Francisco",
        createdAt: Date()
    )
    return ShareSheet(spot: sample)
}

// Custom NSItemProvider for rich link previews
class SpotShareItem: NSObject, UIActivityItemSource {
    private let url: String
    private let metadata: LPLinkMetadata

    init(url: String, metadata: LPLinkMetadata) {
        self.url = url
        self.metadata = metadata
        super.init()
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return url
    }

    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        return url
    }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        return metadata
    }
}

// UIViewControllerRepresentable for native share sheet
struct ShareActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

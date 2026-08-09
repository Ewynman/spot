import SwiftUI

struct SpotImageGallery: View {
    let urls: [String]
    let fallback: String?
    /// Optional: when set, allows the gallery to lazily fetch the full image
    /// array for this spot the first time the user pages past the primary
    /// image. Used by the v2 home feed where each row only carries its primary.
    var spotId: String? = nil
    /// Fixed height for every carousel page (from metadata-driven layout).
    var mediaHeight: CGFloat
    /// Stable key for resetting pager/async state when the host cell is reused for another Spot.
    var galleryIdentity: String
    /// When false, paging gestures are disabled (e.g. while vibe sheet is open).
    var isPagingEnabled: Bool = true
    var onPageCommitted: ((Int) -> Void)? = nil

    @State private var selection: Int = 0
    @State private var failedIndices: Set<Int> = []
    @State private var lazilyLoaded: [String] = []
    @State private var didRequestFullSet = false

    var body: some View {
        let all = orderedURLs
        let slotWidthKey = galleryIdentity
        TabView(selection: $selection) {
            ForEach(Array(all.enumerated()), id: \.offset) { idx, urlString in
                if let url = URL(string: urlString) {
                    RemoteImage(url: url, maxPixelSize: 1200, transaction: Transaction(animation: .default)) { phase in
                        switch phase {
                        case .empty:
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Constants.Colors.background)
                                .frame(maxWidth: .infinity)
                                .frame(height: mediaHeight)
                        case .success(let image):
                            image.resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: mediaHeight)
                                .clipped()
                                .cornerRadius(12)
                                .onAppear {
                                    failedIndices.remove(idx)
                                }
                        case .failure:
                            Image("image_placeholder")
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: mediaHeight)
                                .clipped()
                                .cornerRadius(12)
                                .onAppear {
                                    failedIndices.insert(idx)
                                    if selection == idx, let next = firstRenderableIndex(excluding: failedIndices, count: all.count) {
                                        selection = next
                                    }
                                }
                        @unknown default:
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Constants.Colors.background)
                                .frame(maxWidth: .infinity)
                                .frame(height: mediaHeight)
                        }
                    }
                    .tag(idx)
                }
            }
        }
        .tabViewStyle(.page(indexDisplayMode: all.count > 1 ? .automatic : .never))
        .frame(maxWidth: .infinity)
        .frame(height: mediaHeight)
        .clipped()
        .id(slotWidthKey)
        .allowsHitTesting(isPagingEnabled)
        .onAppear {
            if selection >= all.count {
                selection = 0
            }
            requestFullSetIfNeeded()
            onPageCommitted?(selection)
            SpotLogger.log(SpotMediaLayoutLogs.carouselLayout, details: [
                "galleryIdentity": galleryIdentity,
                "photoCount": all.count,
                "mediaHeight": String(describing: Double(mediaHeight)),
            ])
        }
        .onChange(of: galleryIdentity) { _, _ in
            selection = 0
            failedIndices.removeAll()
            lazilyLoaded = []
            didRequestFullSet = false
            onPageCommitted?(0)
        }
        .onChange(of: selection) { _, newValue in
            if newValue > 0 { requestFullSetIfNeeded() }
            onPageCommitted?(newValue)
        }
    }

    /// Preserve server `sort_index` / input order (do not alphabetize URLs).
    private var orderedURLs: [String] {
        let combined = urls + lazilyLoaded
        let base = combined.isEmpty ? (fallback.map { [$0] } ?? []) : combined
        var seen = Set<String>()
        return base.filter { seen.insert($0).inserted }
    }

    /// On the v2 home feed each row carries only its primary image. The first
    /// time the user opens or pages this gallery, fetch the full array.
    private func requestFullSetIfNeeded() {
        guard !didRequestFullSet else { return }
        guard let spotId, let uuid = UUID(uuidString: spotId) else { return }
        if Set(urls).count > 1 { return }
        didRequestFullSet = true
        Task {
            let all = await FeedAPI.fetchAllImageURLs(for: uuid)
            await MainActor.run {
                let extra = all.filter { !urls.contains($0) }
                if !extra.isEmpty {
                    lazilyLoaded = extra
                }
            }
        }
    }

    private func firstRenderableIndex(excluding excluded: Set<Int>, count: Int) -> Int? {
        for idx in 0..<count where !excluded.contains(idx) { return idx }
        return nil
    }
}

#Preview("Multi square") {
    SpotImageGallery(
        urls: [
            "https://picsum.photos/seed/a/800/800",
            "https://picsum.photos/seed/b/800/800",
        ],
        fallback: nil,
        mediaHeight: 320,
        galleryIdentity: "preview-1"
    )
    .padding()
    .background(Color(hex: "F5F3EF"))
}

#Preview("Landscape") {
    SpotImageGallery(
        urls: ["https://picsum.photos/seed/lscape/1200/600"],
        fallback: nil,
        mediaHeight: SpotMediaAspectRatio.mediaHeight(
            containerWidth: 350,
            displayRatio: SpotMediaAspectRatio.display(width: 1200, height: 600),
            minHeight: 180,
            maxHeight: 520
        ),
        galleryIdentity: "preview-2"
    )
    .frame(width: 350)
    .padding()
    .background(Color(hex: "F5F3EF"))
}

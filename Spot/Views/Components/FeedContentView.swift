//
//  FeedContentView.swift
//  Spot
//
//  Created By: Wynman, Edward
//  Date: 03/02/2025
//

import SwiftUI

struct FeedContentView: View {
    @Binding var isLoading: Bool
    let isLoadingMore: Bool
    let spots: [Spot]
    let mapSpots: [Spot]
    let selectedTab: String
    let onScrolledToBottom: () -> Void
    let onRefresh: () async -> Void
    let userId: String?
    let onDeleteSpot: (Spot) -> Void
    var onFirstItemAppeared: (() -> Void)? = nil
    /// Optional: when set and feed is non-empty, surfaced as a non-blocking
    /// toast over the existing list (e.g. failed refresh while preserving
    /// previously-loaded content).
    var refreshErrorMessage: String? = nil
    /// Status string from `get_home_feed_status_v1` to vary the empty-state copy.
    var emptyStatus: String? = nil
    var onCellAppear: ((Spot) -> Void)? = nil
    var onCellDisappear: ((Spot) -> Void)? = nil

    @State private var firstItemRecorded = false
    @State private var failedImageSpotIds: Set<String> = []
    @State private var lastLoadTriggerSpotId: String?
    @State private var visibleErrorMessage: String?

    private static let feedScrollTopId = "feedScrollTopAnchor"

    var body: some View {
        Group {
            if selectedTab == "Map" {
                MapView(spots: mapSpots)
                    .ignoresSafeArea(edges: .all)
            } else if isLoading && spots.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            Color.clear.frame(height: 0).id(Self.feedScrollTopId)
                            ForEach(0..<3, id: \.self) { _ in
                                SkeletonSpotCard()
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .mainTabReselectSame)) { output in
                        scrollFeedToTopIfNeeded(proxy: proxy, output: output)
                    }
                }
            } else if !spots.isEmpty {
                ZStack(alignment: .top) {
                    feedScroll
                    if let visibleErrorMessage {
                        refreshFailedToast(message: visibleErrorMessage)
                            .padding(.top, 8)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
            } else {
                emptyState
            }
        }
        .background(Color(hex: "F5F3EF"))
        .onChange(of: refreshErrorMessage) { _, newValue in
            updateToast(newValue)
        }
    }

    // MARK: - Subviews

    /// Empty-state hosted inside a `ScrollView` so SwiftUI's `.refreshable`
    /// gesture is available on iOS, even when there are no items to scroll.
    /// Without this wrapper, pulling down on the empty state does nothing.
    private var emptyState: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Color.clear.frame(height: 0).id(Self.feedScrollTopId)
                EmptyFeedView(
                    status: emptyStatus ?? "no_spots_global",
                    onRetry: { Task { await onRefresh() } }
                )
                .frame(maxWidth: .infinity, minHeight: 480)
            }
            .refreshable { await onRefresh() }
            .background(Color(hex: "F5F3EF"))
            .onReceive(NotificationCenter.default.publisher(for: .mainTabReselectSame)) { output in
                scrollFeedToTopIfNeeded(proxy: proxy, output: output)
            }
        }
    }

    private var feedScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    Color.clear.frame(height: 0).id(Self.feedScrollTopId)
                    ForEach(Array(spots.enumerated()), id: \.element.safeId) { idx, spot in
                        Group {
                            if (spot.imageURL ?? "").isEmpty {
                                SkeletonSpotCard()
                            } else {
                                SpotCard(
                                    spot: spot,
                                    showUserInfo: true,
                                    userId: userId,
                                    onDelete: { onDeleteSpot(spot) },
                                    source: "Feed",
                                    onImageFailure: { failed in
                                        if let failedId = failed.id { failedImageSpotIds.insert(failedId) }
                                    },
                                    onImageRetry: { retrySpot in
                                        if let rid = retrySpot.id { failedImageSpotIds.remove(rid) }
                                    }
                                )
                            }
                        }
                        .onAppear {
                            if (spot.imageURL ?? "").isEmpty {
                                SpotLogger.log(FeedContentViewLogs.missingImageUrl, details: ["spotId": spot.safeId])
                            }
                            if !firstItemRecorded {
                                onFirstItemAppeared?()
                                firstItemRecorded = true
                            }
                            let thresholdIndex = max(spots.count - 5, 0)
                            if idx >= thresholdIndex {
                                let triggerId = spot.safeId
                                if lastLoadTriggerSpotId != triggerId {
                                    lastLoadTriggerSpotId = triggerId
                                    onScrolledToBottom()
                                }
                            }
                            onCellAppear?(spot)
                        }
                        .onDisappear {
                            onCellDisappear?(spot)
                        }
                    }
                    if isLoadingMore {
                        ProgressView()
                            .tint(Constants.Colors.primary)
                            .padding()
                    }
                }
            }
            .refreshable {
                failedImageSpotIds.removeAll()
                lastLoadTriggerSpotId = nil
                await onRefresh()
            }
            .coordinateSpace(name: "RefreshControl")
            .background(Color(hex: "F5F3EF"))
            .onChange(of: spots.count) { _, _ in
                if spots.isEmpty {
                    lastLoadTriggerSpotId = nil
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .mainTabReselectSame)) { output in
                scrollFeedToTopIfNeeded(proxy: proxy, output: output)
            }
        }
    }

    private func scrollFeedToTopIfNeeded(proxy: ScrollViewProxy, output: Notification) {
        guard selectedTab == "Feed" else { return }
        guard (output.userInfo?[SpotMainTabNotification.userInfoTabIndexKey] as? Int) == 0 else { return }
        Task { @MainActor in
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo(Self.feedScrollTopId, anchor: .top)
            }
        }
    }

    private func refreshFailedToast(message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "wifi.exclamationmark")
                .foregroundColor(Constants.Colors.buttonText)
            Text(message)
                .font(FontManager.primaryText())
                .foregroundColor(Constants.Colors.buttonText)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            Button {
                Task { await onRefresh() }
            } label: {
                Text("Retry")
                    .font(FontManager.primaryText())
                    .fontWeight(.semibold)
                    .foregroundColor(Constants.Colors.buttonText)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule().fill(Color.black.opacity(0.85))
        )
        .padding(.horizontal, 16)
    }

    private func updateToast(_ next: String?) {
        guard let next else {
            withAnimation(.easeOut(duration: 0.2)) { visibleErrorMessage = nil }
            return
        }
        withAnimation(.easeOut(duration: 0.2)) { visibleErrorMessage = next }
        Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            await MainActor.run {
                if visibleErrorMessage == next {
                    withAnimation(.easeOut(duration: 0.2)) { visibleErrorMessage = nil }
                }
            }
        }
    }
}

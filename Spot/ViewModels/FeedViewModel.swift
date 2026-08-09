//
//  FeedViewModel.swift
//  Spot
//
//  Created By: Wynman, Edward
//  Date: 03/02/2025
//

import Foundation
import Combine

final class FeedViewModel: ObservableObject {
    @Published var spots: [Spot] = []
    @Published var mapSpots: [Spot] = []
    @Published var isLoading = false
    @Published var hasMore = true
    @Published var deletingSpotIds: Set<String> = []
    /// Last refresh-failure message; cleared on the next successful load.
    /// The view shows this as a non-blocking toast over preserved feed content.
    @Published var refreshErrorMessage: String? = nil
    /// Distinct empty-state status from `get_home_feed_status_v1`. `nil` while
    /// content is loading or available.
    @Published var emptyStatus: HomeFeedStatus? = nil
    /// Mirror of repository load state for the view layer.
    @Published var loadState: FeedLoadState = .idle

    private var loadTask: Task<Void, Never>?
    private var isLoadingPage = false
    private let repo = FeedRepository.shared
    private var hasRecordedFirstItem = false
    private var observationCancellables: Set<AnyCancellable> = []

    init() {
        observeRepository()
    }

    deinit {
        loadTask?.cancel()
    }

    private func observeRepository() {
        repo.$spots
            .receive(on: DispatchQueue.main)
            .assign(to: \.spots, on: self)
            .store(in: &observationCancellables)
        repo.$loadState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }
                self.loadState = state
                switch state {
                case .loadingInitial, .loadingMore:
                    self.isLoading = true
                default:
                    self.isLoading = false
                }
            }
            .store(in: &observationCancellables)
        repo.$refreshErrorMessage
            .receive(on: DispatchQueue.main)
            .assign(to: \.refreshErrorMessage, on: self)
            .store(in: &observationCancellables)
        repo.$emptyStatus
            .receive(on: DispatchQueue.main)
            .assign(to: \.emptyStatus, on: self)
            .store(in: &observationCancellables)
    }

    var validSpots: [Spot] { spots }

    var validMapSpots: [Spot] {
        mapSpots.filter { $0.latitude != nil && $0.longitude != nil }
    }

    func recordFirstItemIfNeeded() {
        guard !hasRecordedFirstItem, !spots.isEmpty else { return }
        hasRecordedFirstItem = true
        let t = PerfMetrics.shared.measure("t_first_item") ?? 0
        PerfMetrics.shared.recordOnce("t_first_item", value: t)
    }

    func loadInitialSpots() async {
        if !spots.isEmpty { return }
        guard !isLoadingPage else { return }
        loadTask = Task { [weak self] in
            guard let self else { return }
            await MainActor.run { self.isLoadingPage = true }
            await self.repo.loadInitial()
            let cancelledAfterLoad = Task.isCancelled
            await MainActor.run {
                if cancelledAfterLoad {
                    self.isLoadingPage = false
                    return
                }
                self.hasMore = self.repo.moreAvailable
                self.recordFirstItemIfNeeded()
                self.isLoadingPage = false
            }
        }
        await loadTask?.value
    }

    func loadMoreSpots() {
        guard hasMore else { return }
        guard !isLoadingPage else { return }

        loadTask = Task { [weak self] in
            guard let self else { return }
            await MainActor.run { self.isLoadingPage = true }
            await self.repo.loadMore()
            let cancelledAfterLoad = Task.isCancelled
            await MainActor.run {
                if cancelledAfterLoad {
                    self.isLoadingPage = false
                    return
                }
                self.hasMore = self.repo.moreAvailable
                self.recordFirstItemIfNeeded()
                self.isLoadingPage = false
            }
        }
    }

    /// Pull-to-refresh must run even when infinite-scroll (`loadMore`) has the page busy;
    /// that used to no-op via `guard !isLoadingPage` while `isLoadingPage` stayed true for seconds.
    func refreshFeed() async {
        loadTask?.cancel()
        await MainActor.run { self.isLoadingPage = true }

        let task = Task { [weak self] in
            guard let self else { return }
            await self.repo.loadInitial()
            let cancelledAfterLoad = Task.isCancelled
            await MainActor.run {
                if cancelledAfterLoad {
                    self.isLoadingPage = false
                    return
                }
                self.hasMore = self.repo.moreAvailable
                self.recordFirstItemIfNeeded()
                self.isLoadingPage = false
            }
        }
        loadTask = task
        await task.value
    }

    // MARK: - Insert newly posted spot

    @MainActor
    func insertNewSpot(_ spot: Spot) {
        repo.insertSpotAtTop(spot)
        SpotLogger.log(FeedViewModelLogs.insertedNewSpotAtTop, details: ["spotId": spot.safeId])
    }

    @MainActor
    func locallyReplaceSpot(_ spot: Spot) {
        repo.locallyReplaceSpot(spot)
        if let index = mapSpots.firstIndex(where: { $0.id == spot.id }) {
            mapSpots[index] = spot
        }
    }

    func loadMapSpots(forceRefresh: Bool = false) {
        SpotLogger.log(FeedViewModelLogs.mapSpotsWarmDisabled)
        Task { @MainActor in self.mapSpots = [] }
    }

    // MARK: - Delete

    @MainActor
    func delete(spot: Spot) async {
        guard let id = spot.id else {
            SpotLogger.log(FeedViewModelLogs.deleteRequestedWithoutId)
            return
        }
        guard let uuid = UUID(uuidString: id) else {
            SpotLogger.log(FeedViewModelLogs.deleteInvalidSpotId, details: ["spotId": id])
            return
        }
        if deletingSpotIds.contains(id) { return }
        deletingSpotIds.insert(id)

        let prevSpots = repo.spots
        let prevMap = mapSpots
        repo.locallyRemoveSpot(id: id)
        mapSpots.removeAll { $0.id == id }

        do {
            SpotLogger.log(FeedViewModelLogs.deletingSpot, details: ["spotId": id])
            try await SpotSupabaseRepository.deleteSpot(id: uuid)
            deletingSpotIds.remove(id)
            loadMapSpots(forceRefresh: true)
        } catch {
            SpotLogger.log(FeedViewModelLogs.deleteFailed, details: ["spotId": id, "error": error.localizedDescription])
            repo.replaceSpots(prevSpots)
            mapSpots = prevMap
            deletingSpotIds.remove(id)
        }
    }

    // MARK: - Hide / Not interested

    /// Locally remove a spot from the feed. Used by report/block/hide actions
    /// so the feed reflects the change immediately while the server-side
    /// `user_hidden_spots` write completes.
    @MainActor
    func locallyRemoveSpot(id: String) {
        repo.locallyRemoveSpot(id: id)
        mapSpots.removeAll { $0.id == id }
    }

    @MainActor
    func locallyRemoveSpotsFromAuthor(userId: String) {
        repo.locallyRemoveSpotsFromAuthor(userId: userId)
        mapSpots.removeAll { $0.userId == userId }
    }
}

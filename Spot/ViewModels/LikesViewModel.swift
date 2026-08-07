//
//  LikesViewModel.swift
//  Spot
//
//  Created by Edward Wynman on 1/27/25.
//

import Foundation

@MainActor
class LikesViewModel: ObservableObject {
    @Published var spots: [Spot] = []
    @Published var isLoading = false
    @Published var hasMore = true
    @Published var errorMessage: String?

    private var lastCursor: String?
    private var loadedSpotIds = Set<String>() // For deduplication within session
    private let pageSize = 24

    func loadInitial() async {
        guard !isLoading else {
            SpotLogger.log(LikesViewModelLogs.alreadyLoading)
            return
        }

        SpotLogger.log(LikesViewModelLogs.startingLoadInitial)
        isLoading = true
        errorMessage = nil

        do {
            let result = try await UserSpotService.shared.fetchLikedSpots(pageSize: pageSize)
            SpotLogger.log(LikesViewModelLogs.fetchedSpotsFromService, details: ["count": result.spots.count])

            let newSpots = SpotListDeduper.accepting(result.spots, into: &loadedSpotIds)

            spots = newSpots
            lastCursor = result.lastCursor
            hasMore = result.hasMore

            SpotLogger.log(LikesViewModelLogs.loadedSpots, details: ["count": newSpots.count, "hasMore": hasMore])
        } catch {
            errorMessage = "Failed to load liked spots"
            SpotLogger.log(LikesViewModelLogs.loadInitialFailed, details: ["error": error.localizedDescription])
        }

        isLoading = false
        SpotLogger.log(LikesViewModelLogs.loadInitialCompleted)
    }

    func loadMore() async {
        // No pagination for array-based approach
        // This method is kept for future subcollection implementation
        return
    }

    func refresh() async {
        // Reset state for fresh load
        spots = []
        loadedSpotIds.removeAll()
        lastCursor = nil
        hasMore = true

        await loadInitial()
    }

    func removeSpot(_ spot: Spot) {
        guard let spotId = spot.id else { return }
        spots.removeAll { $0.id == spotId }
        loadedSpotIds.remove(spotId)
    }
}

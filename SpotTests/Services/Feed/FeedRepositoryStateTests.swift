//
//  FeedRepositoryStateTests.swift
//  SpotTests
//
//  Created By: Wynman, Edward
//  Date: 04/27/2026
//
//  In-memory state mutations on FeedRepository (locallyRemoveSpot,
//  insertSpotAtTop, replaceSpots, reset). FeedRepository is a singleton, so
//  every test calls `reset()` first to guarantee a clean published state.
//

import Foundation
import Testing
@testable import Spot

@MainActor
struct FeedRepositoryStateTests {

    private func freshRepository() -> FeedRepository {
        let repo = FeedRepository.shared
        repo.reset()
        return repo
    }

    @Test func resetClearsSpotsAndState() {
        let repo = freshRepository()
        repo.insertSpotAtTop(SpotTestHelpers.makeSpot(id: "a"))
        repo.reset()
        #expect(repo.spots.isEmpty)
        #expect(repo.loadState == .idle)
        #expect(repo.emptyStatus == nil)
    }

    @Test func insertSpotAtTopAddsAtFront() {
        let repo = freshRepository()
        repo.insertSpotAtTop(SpotTestHelpers.makeSpot(id: "old"))
        repo.insertSpotAtTop(SpotTestHelpers.makeSpot(id: "new"))
        #expect(repo.spots.first?.id == "new")
        #expect(repo.spots.count == 2)
    }

    @Test func insertSpotAtTopReplacesDuplicateById() {
        let repo = freshRepository()
        repo.insertSpotAtTop(SpotTestHelpers.makeSpot(id: "a", vibeTag: "Chill"))
        repo.insertSpotAtTop(SpotTestHelpers.makeSpot(id: "a", vibeTag: "Updated"))
        #expect(repo.spots.count == 1)
        #expect(repo.spots.first?.vibeTag == "Updated")
    }

    @Test func locallyRemoveSpotDropsMatchingId() {
        let repo = freshRepository()
        repo.replaceSpots([
            SpotTestHelpers.makeSpot(id: "a"),
            SpotTestHelpers.makeSpot(id: "b"),
            SpotTestHelpers.makeSpot(id: "c")
        ])
        repo.locallyRemoveSpot(id: "b")
        let ids = repo.spots.compactMap { $0.id }
        #expect(ids == ["a", "c"])
    }

    @Test func locallyRemoveLastSpotEntersEmptyState() {
        let repo = freshRepository()
        repo.replaceSpots([SpotTestHelpers.makeSpot(id: "only")])
        repo.locallyRemoveSpot(id: "only")
        #expect(repo.spots.isEmpty)
        if case .empty = repo.loadState { } else {
            Issue.record("Expected .empty load state when feed becomes empty")
        }
    }

    @Test func replaceSpotsWithEmptyEntersEmptyState() {
        let repo = freshRepository()
        repo.replaceSpots([])
        if case .empty = repo.loadState { } else {
            Issue.record("Expected .empty load state when replaced with empty array")
        }
    }

    @Test func replaceSpotsWithNonEmptyEntersLoadedState() {
        let repo = freshRepository()
        repo.replaceSpots([SpotTestHelpers.makeSpot(id: "a")])
        #expect(repo.loadState == .loaded)
        #expect(repo.spots.count == 1)
    }
}

struct FeedLoadStateEqualityTests {

    @Test func sameCasesAreEqual() {
        #expect(FeedLoadState.idle == .idle)
        #expect(FeedLoadState.loaded == .loaded)
        #expect(FeedLoadState.loadingInitial == .loadingInitial)
        #expect(FeedLoadState.loadingMore == .loadingMore)
    }

    @Test func emptyEqualityComparesReason() {
        #expect(FeedLoadState.empty(reason: "caught_up") == .empty(reason: "caught_up"))
        #expect(FeedLoadState.empty(reason: "caught_up") != .empty(reason: "no_spots_global"))
    }

    @Test func errorEqualityComparesMessage() {
        #expect(FeedLoadState.error(message: "boom") == .error(message: "boom"))
        #expect(FeedLoadState.error(message: "boom") != .error(message: "different"))
    }
}

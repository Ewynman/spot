//
//  PostPurchaseProOnboardingManagerTests.swift
//  SpotTests
//
//  Created By: Wynman, Edward
//  Date: 04/27/2026
//
//  Behavior contract for the post-purchase Pro onboarding tour. These tests
//  intentionally do NOT change Pro onboarding behavior or constants — they
//  exist so future refactors of the manager have regression coverage.
//

import Foundation
import Testing
@testable import Spot

@MainActor
struct PostPurchaseProOnboardingManagerTests {

    private func storageKey(for userId: String) -> String {
        "hasSeenPostPurchaseProOnboarding.\(userId)"
    }

    private func freshUserId() -> String {
        "test-pro-\(UUID().uuidString)"
    }

    private func cleanup(_ userId: String) {
        UserDefaults.standard.removeObject(forKey: storageKey(for: userId))
    }

    @Test func defaultStepIsWelcomeAndSubstepZero() {
        let manager = PostPurchaseProOnboardingManager()
        #expect(manager.step == .welcome)
        #expect(manager.collectionsSubstep == 0)
        #expect(manager.isOnWelcome == true)
        #expect(manager.isFinale == false)
    }

    @Test func shouldShowFalseForNilOrEmptyUserId() {
        #expect(PostPurchaseProOnboardingManager.shouldShow(userId: nil) == false)
        #expect(PostPurchaseProOnboardingManager.shouldShow(userId: "") == false)
    }

    @Test func shouldShowTrueForUserWithoutPersistedFlag() {
        let userId = freshUserId()
        defer { cleanup(userId) }
        #expect(PostPurchaseProOnboardingManager.shouldShow(userId: userId) == true)
    }

    @Test func markSeenPersistsAndPreventsReshow() {
        let userId = freshUserId()
        defer { cleanup(userId) }
        PostPurchaseProOnboardingManager.markSeen(userId: userId)
        #expect(PostPurchaseProOnboardingManager.shouldShow(userId: userId) == false)
        #expect(UserDefaults.standard.bool(forKey: storageKey(for: userId)) == true)
    }

    @Test func markSeenIgnoresNilOrEmptyUserId() {
        PostPurchaseProOnboardingManager.markSeen(userId: nil)
        PostPurchaseProOnboardingManager.markSeen(userId: "")
        // Sanity: a nil user id never persists anything; non-nil unique id stays unset.
        let userId = freshUserId()
        defer { cleanup(userId) }
        #expect(PostPurchaseProOnboardingManager.shouldShow(userId: userId) == true)
    }

    @Test func skipEntireTourMarksSeen() {
        let userId = freshUserId()
        defer { cleanup(userId) }
        let manager = PostPurchaseProOnboardingManager()
        manager.skipEntireTour(userId: userId)
        #expect(PostPurchaseProOnboardingManager.shouldShow(userId: userId) == false)
    }

    @Test func nextWalksThroughEntireSequence() {
        let manager = PostPurchaseProOnboardingManager()
        let order: [PostPurchaseProOnboardingManager.Step] = [
            .welcome, .fivePhotos, .customVibes, .editSpots, .bookmarks,
            .collections, .searchFilters, .supporterBadge, .finale
        ]
        var visited: [PostPurchaseProOnboardingManager.Step] = [manager.step]
        var safety = 0
        while manager.step != .finale, safety < 100 {
            let before = manager.step
            manager.next()
            // collections has a sub-step that does not advance the major step.
            if before == .collections, manager.collectionsSubstep == 1 {
                manager.next()
            }
            if visited.last != manager.step {
                visited.append(manager.step)
            }
            safety += 1
        }
        #expect(visited == order)
    }

    @Test func collectionsHasSubstepBeforeAdvancing() {
        let manager = PostPurchaseProOnboardingManager()
        manager.step = .collections
        manager.collectionsSubstep = 0
        manager.next()
        #expect(manager.step == .collections)
        #expect(manager.collectionsSubstep == 1)
        manager.next()
        #expect(manager.step == .searchFilters)
    }

    @Test func goBackFromCollectionsSubstepRevertsSubstepFirst() {
        let manager = PostPurchaseProOnboardingManager()
        manager.step = .collections
        manager.collectionsSubstep = 1
        manager.goBack()
        #expect(manager.step == .collections)
        #expect(manager.collectionsSubstep == 0)
        manager.goBack()
        #expect(manager.step == .bookmarks)
    }

    @Test func goBackAtWelcomeIsNoop() {
        let manager = PostPurchaseProOnboardingManager()
        manager.step = .welcome
        manager.goBack()
        #expect(manager.step == .welcome)
    }

    @Test func nextAtFinaleIsNoop() {
        let manager = PostPurchaseProOnboardingManager()
        manager.step = .finale
        manager.next()
        #expect(manager.step == .finale)
        #expect(manager.isFinale == true)
    }

    @Test func progressMonotonicallyIncreases() {
        let manager = PostPurchaseProOnboardingManager()
        let welcomeProgress = manager.progress
        manager.step = .collections
        let midProgress = manager.progress
        manager.step = .finale
        let endProgress = manager.progress
        #expect(welcomeProgress < midProgress)
        #expect(midProgress < endProgress)
        #expect(abs(endProgress - 1.0) < 0.0001)
    }

    @Test func steppingIntoCollectionsResetsSubstep() {
        let manager = PostPurchaseProOnboardingManager()
        manager.step = .bookmarks
        manager.collectionsSubstep = 1
        manager.next()
        #expect(manager.step == .collections)
        #expect(manager.collectionsSubstep == 0)
    }
}

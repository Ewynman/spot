//
//  SpotFirstRunOnboardingManagerTests.swift
//  SpotTests
//
//  Created By: Wynman, Edward
//  Date: 04/27/2026
//
//  Behavior contract for the redesigned first-run onboarding manager.
//  Covers eligibility gating, step progression, persistence keys, legacy
//  HomeTourManager migration, and the map-tab handoff used by
//  BottomTabNavigationView.
//

import Foundation
import Testing
@testable import Spot

@MainActor
struct SpotFirstRunOnboardingManagerTests {

    private static let completedKey = "spotFirstRunOnboarding.completed.v1"
    private static let completedAtKey = "spotFirstRunOnboarding.completedAt.v1"
    private static let skippedKey = "spotFirstRunOnboarding.skipped.v1"
    private static let lastStepKey = "spotFirstRunOnboarding.lastStep.v1"

    @Test func defaultsAreClearOnFreshStorage() {
        let defaults = SpotTestHelpers.makeIsolatedDefaults()
        let manager = SpotFirstRunOnboardingManager(storage: defaults)
        #expect(manager.isPresented == false)
        #expect(manager.currentStep == .welcome)
        #expect(manager.hasCompletedOrSkipped == false)
    }

    @Test func startIfNeededShowsWelcomeForEligibleUser() {
        let defaults = SpotTestHelpers.makeIsolatedDefaults()
        let manager = SpotFirstRunOnboardingManager(storage: defaults)
        manager.startIfNeeded(isAuthenticated: true, isFirstSessionCandidate: true, userId: "u1")
        #expect(manager.isPresented == true)
        #expect(manager.currentStep == .welcome)
        #expect(defaults.integer(forKey: Self.lastStepKey) == SpotFirstRunOnboardingManager.Step.welcome.rawValue)
    }

    @Test func startIfNeededIgnoredWhenUnauthenticated() {
        let defaults = SpotTestHelpers.makeIsolatedDefaults()
        let manager = SpotFirstRunOnboardingManager(storage: defaults)
        manager.startIfNeeded(isAuthenticated: false, isFirstSessionCandidate: true, userId: "u1")
        #expect(manager.isPresented == false)
    }

    @Test func startIfNeededIgnoredWhenNotFirstSession() {
        let defaults = SpotTestHelpers.makeIsolatedDefaults()
        let manager = SpotFirstRunOnboardingManager(storage: defaults)
        manager.startIfNeeded(isAuthenticated: true, isFirstSessionCandidate: false, userId: "u1")
        #expect(manager.isPresented == false)
    }

    @Test func startIfNeededIgnoredWhenAlreadyCompleted() {
        let defaults = SpotTestHelpers.makeIsolatedDefaults()
        defaults.set(true, forKey: Self.completedKey)
        let manager = SpotFirstRunOnboardingManager(storage: defaults)
        manager.startIfNeeded(isAuthenticated: true, isFirstSessionCandidate: true, userId: "u1")
        #expect(manager.isPresented == false)
        #expect(manager.hasCompletedOrSkipped == true)
    }

    @Test func startIfNeededIgnoredWhenAlreadySkipped() {
        let defaults = SpotTestHelpers.makeIsolatedDefaults()
        defaults.set(true, forKey: Self.skippedKey)
        let manager = SpotFirstRunOnboardingManager(storage: defaults)
        manager.startIfNeeded(isAuthenticated: true, isFirstSessionCandidate: true, userId: "u1")
        #expect(manager.isPresented == false)
        #expect(manager.hasCompletedOrSkipped == true)
    }

    @Test func startTourMovesPastWelcomeToFirstGuidedStep() {
        let defaults = SpotTestHelpers.makeIsolatedDefaults()
        let manager = SpotFirstRunOnboardingManager(storage: defaults)
        manager.startIfNeeded(isAuthenticated: true, isFirstSessionCandidate: true, userId: "u1")
        manager.startTour()
        #expect(manager.currentStep == .spotCard)
        #expect(defaults.integer(forKey: Self.lastStepKey) == SpotFirstRunOnboardingManager.Step.spotCard.rawValue)
    }

    @Test func nextAdvancesThroughGuidedStepsInOrder() {
        let defaults = SpotTestHelpers.makeIsolatedDefaults()
        let manager = SpotFirstRunOnboardingManager(storage: defaults)
        let order: [SpotFirstRunOnboardingManager.Step] = [
            .welcome, .spotCard, .spotDetails, .vibeTag, .like, .bookmark, .creator,
            .mapTab, .userLocation, .mapMarkers, .markerPreview, .finale
        ]
        for step in order {
            #expect(manager.currentStep == step)
            if step != order.last {
                manager.next()
            }
        }
    }

    @Test func nextOnFinaleMarksCompleteAndDismisses() {
        let defaults = SpotTestHelpers.makeIsolatedDefaults()
        let manager = SpotFirstRunOnboardingManager(storage: defaults)
        manager.startIfNeeded(isAuthenticated: true, isFirstSessionCandidate: true, userId: "u1")
        manager.currentStep = .finale
        manager.next()
        #expect(manager.isPresented == false)
        #expect(manager.hasCompletedOrSkipped == true)
        #expect(defaults.bool(forKey: Self.completedKey) == true)
        #expect(defaults.bool(forKey: Self.skippedKey) == false)
        #expect(defaults.double(forKey: Self.completedAtKey) > 0)
    }

    @Test func backRespectsCanGoBack() {
        let defaults = SpotTestHelpers.makeIsolatedDefaults()
        let manager = SpotFirstRunOnboardingManager(storage: defaults)
        // Welcome cannot go back
        #expect(manager.canGoBack == false)
        manager.back()
        #expect(manager.currentStep == .welcome)

        manager.currentStep = .userLocation
        // userLocation is the first map step, blocked from going back
        #expect(manager.canGoBack == false)
        manager.back()
        #expect(manager.currentStep == .userLocation)
    }

    @Test func backFromMidStepDecrements() {
        let defaults = SpotTestHelpers.makeIsolatedDefaults()
        let manager = SpotFirstRunOnboardingManager(storage: defaults)
        manager.currentStep = .vibeTag
        #expect(manager.canGoBack == true)
        manager.back()
        #expect(manager.currentStep == .spotDetails)
        #expect(defaults.integer(forKey: Self.lastStepKey) == SpotFirstRunOnboardingManager.Step.spotDetails.rawValue)
    }

    @Test func skipMarksSkippedAndDismisses() {
        let defaults = SpotTestHelpers.makeIsolatedDefaults()
        let manager = SpotFirstRunOnboardingManager(storage: defaults)
        manager.startIfNeeded(isAuthenticated: true, isFirstSessionCandidate: true, userId: "u1")
        manager.skip()
        #expect(manager.isPresented == false)
        #expect(manager.hasCompletedOrSkipped == true)
        #expect(defaults.bool(forKey: Self.completedKey) == true)
        #expect(defaults.bool(forKey: Self.skippedKey) == true)
    }

    @Test func finishMarksCompletedNotSkipped() {
        let defaults = SpotTestHelpers.makeIsolatedDefaults()
        let manager = SpotFirstRunOnboardingManager(storage: defaults)
        manager.currentStep = .finale
        manager.finish()
        #expect(manager.hasCompletedOrSkipped == true)
        #expect(defaults.bool(forKey: Self.completedKey) == true)
        #expect(defaults.bool(forKey: Self.skippedKey) == false)
    }

    @Test func mapTabSelectedAdvancesOnlyWhenOnMapTabStep() {
        let defaults = SpotTestHelpers.makeIsolatedDefaults()
        let manager = SpotFirstRunOnboardingManager(storage: defaults)
        manager.startIfNeeded(isAuthenticated: true, isFirstSessionCandidate: true, userId: "u1")
        manager.currentStep = .creator
        manager.mapTabSelected()
        #expect(manager.currentStep == .creator)

        manager.currentStep = .mapTab
        manager.mapTabSelected()
        #expect(manager.currentStep == .userLocation)
    }

    @Test func mapTabSelectedDoesNothingWhenNotPresented() {
        let defaults = SpotTestHelpers.makeIsolatedDefaults()
        let manager = SpotFirstRunOnboardingManager(storage: defaults)
        manager.currentStep = .mapTab
        // not presented
        manager.mapTabSelected()
        #expect(manager.currentStep == .mapTab)
    }

    @Test func legacyHomeTourAcceptedBlocksNewTour() {
        let defaults = SpotTestHelpers.makeIsolatedDefaults()
        defaults.set(true, forKey: Constants.UserDefaultsKeys.homeTourAccepted)
        let manager = SpotFirstRunOnboardingManager(storage: defaults)
        manager.configure(userId: "u1")
        #expect(manager.hasCompletedOrSkipped == true)
        manager.startIfNeeded(isAuthenticated: true, isFirstSessionCandidate: true, userId: "u1")
        #expect(manager.isPresented == false)
        #expect(defaults.bool(forKey: Self.completedKey) == true)
    }

    @Test func legacyPerUserKeyMigratesToGlobalAndCompleted() {
        let defaults = SpotTestHelpers.makeIsolatedDefaults()
        defaults.set(true, forKey: "hasSeenHomeTour.legacy-user")
        let manager = SpotFirstRunOnboardingManager(storage: defaults)
        manager.configure(userId: "legacy-user")
        #expect(manager.hasCompletedOrSkipped == true)
        #expect(defaults.bool(forKey: Constants.UserDefaultsKeys.homeTourAccepted) == true)
        #expect(defaults.bool(forKey: Self.completedKey) == true)
    }

    @Test func progressGrowsAcrossSteps() {
        let defaults = SpotTestHelpers.makeIsolatedDefaults()
        let manager = SpotFirstRunOnboardingManager(storage: defaults)
        let initial = manager.progress
        manager.currentStep = .creator
        let mid = manager.progress
        manager.currentStep = .finale
        let end = manager.progress
        #expect(initial < mid)
        #expect(mid < end)
        #expect(abs(end - 1.0) < 0.0001)
    }

    @Test func prefersFullScreenOnlyOnWelcomeAndFinale() {
        let defaults = SpotTestHelpers.makeIsolatedDefaults()
        let manager = SpotFirstRunOnboardingManager(storage: defaults)
        manager.currentStep = .welcome
        #expect(manager.prefersFullScreenCard == true)
        manager.currentStep = .spotCard
        #expect(manager.prefersFullScreenCard == false)
        manager.currentStep = .finale
        #expect(manager.prefersFullScreenCard == true)
    }

    @Test func eachGuidedStepHasTitleBodyAndTarget() {
        for step in SpotFirstRunOnboardingManager.Step.allCases {
            #expect(!step.title.isEmpty)
            #expect(!step.body.isEmpty)
            switch step {
            case .welcome, .finale:
                #expect(step.target == nil)
            default:
                #expect(step.target != nil)
            }
        }
    }
}

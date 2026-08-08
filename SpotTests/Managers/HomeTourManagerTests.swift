//
//  HomeTourManagerTests.swift
//  SpotTests
//
//  Created By: Wynman, Edward
//  Date: 04/27/2026
//
//  Regression tests for the legacy `HomeTourManager`. The new first-run
//  onboarding migrates off this manager (see SpotFirstRunOnboardingManager),
//  but several call sites still wire it through `HomeTourHost`, so the
//  behavior must remain stable.
//

import Foundation
import Testing
@testable import Spot

@MainActor
struct HomeTourManagerTests {

    @Test func defaultsAreClearOnFreshStorage() {
        let defaults = SpotTestHelpers.makeIsolatedDefaults()
        let manager = HomeTourManager(userId: "u1", storage: defaults)
        #expect(manager.hasSeenHomeTour == false)
        #expect(manager.isWelcomePresented == false)
        #expect(manager.isCoachPresented == false)
        #expect(manager.currentStep == .username)
    }

    @Test func startIfNeededShowsWelcomeForFirstSessionUser() {
        let defaults = SpotTestHelpers.makeIsolatedDefaults()
        let manager = HomeTourManager(userId: "u1", storage: defaults)
        manager.startIfNeeded(isFirstSessionAfterSignup: true)
        #expect(manager.isWelcomePresented == true)
    }

    @Test func startIfNeededDoesNothingForReturningUser() {
        let defaults = SpotTestHelpers.makeIsolatedDefaults()
        defaults.set(true, forKey: Constants.UserDefaultsKeys.homeTourAccepted)
        let manager = HomeTourManager(userId: "u1", storage: defaults)
        manager.startIfNeeded(isFirstSessionAfterSignup: true)
        #expect(manager.isWelcomePresented == false)
    }

    @Test func startIfNeededIgnoredWhenNotFirstSession() {
        let defaults = SpotTestHelpers.makeIsolatedDefaults()
        let manager = HomeTourManager(userId: "u1", storage: defaults)
        manager.startIfNeeded(isFirstSessionAfterSignup: false)
        #expect(manager.isWelcomePresented == false)
    }

    @Test func startCoachClosesWelcomeAndOpensCoach() {
        let defaults = SpotTestHelpers.makeIsolatedDefaults()
        let manager = HomeTourManager(userId: "u1", storage: defaults)
        manager.startIfNeeded(isFirstSessionAfterSignup: true)
        manager.startCoach()
        #expect(manager.isWelcomePresented == false)
        #expect(manager.isCoachPresented == true)
        #expect(manager.currentStep == .username)
    }

    @Test func nextAdvancesThroughEachStep() {
        let defaults = SpotTestHelpers.makeIsolatedDefaults()
        let manager = HomeTourManager(userId: "u1", storage: defaults)
        manager.startCoach()

        manager.next()
        #expect(manager.currentStep == .location)
        manager.next()
        #expect(manager.currentStep == .vibe)
        manager.next()
        #expect(manager.currentStep == .likeSave)
    }

    @Test func nextAfterLastStepCompletesAndPersists() {
        let defaults = SpotTestHelpers.makeIsolatedDefaults()
        let manager = HomeTourManager(userId: "u1", storage: defaults)
        manager.startCoach()
        manager.currentStep = .likeSave
        manager.next()
        #expect(manager.hasSeenHomeTour == true)
        #expect(manager.isCoachPresented == false)
        #expect(manager.isWelcomePresented == false)
        #expect(defaults.bool(forKey: Constants.UserDefaultsKeys.homeTourAccepted) == true)
    }

    @Test func skipCompletesAndPersists() {
        let defaults = SpotTestHelpers.makeIsolatedDefaults()
        let manager = HomeTourManager(userId: "u1", storage: defaults)
        manager.startIfNeeded(isFirstSessionAfterSignup: true)
        manager.skip()
        #expect(manager.hasSeenHomeTour == true)
        #expect(manager.isWelcomePresented == false)
        #expect(manager.isCoachPresented == false)
        #expect(defaults.bool(forKey: Constants.UserDefaultsKeys.homeTourAccepted) == true)
    }

    @Test func legacyPerUserKeyIsMigratedToGlobalKey() {
        let defaults = SpotTestHelpers.makeIsolatedDefaults()
        let userId = "user-123"
        defaults.set(true, forKey: "hasSeenHomeTour.\(userId)")
        let manager = HomeTourManager(userId: userId, storage: defaults)
        #expect(manager.hasSeenHomeTour == true)
        #expect(defaults.bool(forKey: Constants.UserDefaultsKeys.homeTourAccepted) == true)
    }

    @Test func legacyGuestKeyIsMigratedWhenUserIdMissing() {
        let defaults = SpotTestHelpers.makeIsolatedDefaults()
        defaults.set(true, forKey: "hasSeenHomeTour.guest")
        let manager = HomeTourManager(userId: nil, storage: defaults)
        #expect(manager.hasSeenHomeTour == true)
        #expect(defaults.bool(forKey: Constants.UserDefaultsKeys.homeTourAccepted) == true)
    }

    @Test func configureCanBeCalledAgainWithoutUndoingCompletion() {
        let defaults = SpotTestHelpers.makeIsolatedDefaults()
        let manager = HomeTourManager(userId: "u1", storage: defaults)
        manager.skip()
        manager.configure(userId: "different-user")
        #expect(manager.hasSeenHomeTour == true)
    }
}

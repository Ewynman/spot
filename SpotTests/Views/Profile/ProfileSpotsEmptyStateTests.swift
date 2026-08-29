//
//  ProfileSpotsEmptyStateTests.swift
//  SpotTests
//
//  Created by Edward Wynman on 8/28/26.
//

import Testing
@testable import Spot

struct ProfileSpotsEmptyStateTests {

    @Test func ownProfilePromptsUserToShareFirstSpot() {
        let state = ProfileSpotsEmptyState.resolve(
            isOwnProfile: true,
            canViewContent: true
        )

        #expect(state == .ownProfile)
        #expect(state.title == "Share your first Spot")
        #expect(state.showsPostButton)
    }

    @Test func emptyPublicProfileDoesNotShowPostingAction() {
        let state = ProfileSpotsEmptyState.resolve(
            isOwnProfile: false,
            canViewContent: true
        )

        #expect(state == .otherProfile)
        #expect(state.title == "No Spots yet")
        #expect(state.showsPostButton == false)
    }

    @Test func hiddenPrivateProfileExplainsWhySpotsAreUnavailable() {
        let state = ProfileSpotsEmptyState.resolve(
            isOwnProfile: false,
            canViewContent: false
        )

        #expect(state == .privateProfile)
        #expect(state.title == "This account is private")
        #expect(state.showsPostButton == false)
    }

    @Test func postingActionTargetsPostTab() {
        #expect(SpotMainTabNotification.postTabIndex == 2)
    }
}

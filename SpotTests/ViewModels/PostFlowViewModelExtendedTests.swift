//
//  PostFlowViewModelExtendedTests.swift
//  SpotTests
//
//  Created By: Wynman, Edward
//  Date: 04/27/2026
//
//  Extended coverage for PostFlowViewModel state machine: draft readiness,
//  submit gating, toast plumbing, and current-step boundary handling.
//

import CoreLocation
import Foundation
import Testing
import UIKit
@testable import Spot

@MainActor
struct PostFlowViewModelExtendedTests {

    private func makeLocation(name: String = "Test Place") -> LocationData {
        LocationData(
            coordinate: CLLocationCoordinate2D(latitude: 40.7, longitude: -74.0),
            placeName: name,
            address: nil,
            isCustomName: false
        )
    }

    @Test func canSaveDraftRequiresAtLeastOneInput() {
        let vm = PostFlowViewModel()
        #expect(vm.canSaveDraft == false)
        vm.selectedImages = [UIImage()]
        #expect(vm.canSaveDraft == true)
        vm.selectedImages = []
        vm.selectedLocation = makeLocation()
        #expect(vm.canSaveDraft == true)
        vm.selectedLocation = nil
        vm.selectedVibes = ["Chill"]
        #expect(vm.canSaveDraft == true)
    }

    @Test func canSubmitPostRequiresAllThreeInputs() {
        let vm = PostFlowViewModel()
        #expect(vm.canSubmitPost == false)

        vm.selectedImages = [UIImage()]
        #expect(vm.canSubmitPost == false)

        vm.selectedLocation = makeLocation()
        #expect(vm.canSubmitPost == false)

        vm.selectedVibes = ["Chill"]
        #expect(vm.canSubmitPost == true)

        vm.selectedImages = []
        #expect(vm.canSubmitPost == false)
    }

    @Test func canProceedToNextStepStep3UsesSelectedVibes() {
        let vm = PostFlowViewModel()
        vm.currentStep = 3
        vm.selectedVibes = []
        #expect(vm.canProceedToNextStep == false)
        vm.selectedVibes = ["Chill"]
        #expect(vm.canProceedToNextStep == true)
    }

    @Test func canProceedReturnsFalseForUnknownStep() {
        let vm = PostFlowViewModel()
        vm.currentStep = 99
        #expect(vm.canProceedToNextStep == false)
    }

    @Test func goNextStopsAtTotalSteps() {
        let vm = PostFlowViewModel()
        vm.currentStep = vm.totalSteps
        vm.goNext()
        #expect(vm.currentStep == vm.totalSteps)
    }

    @Test func goBackStopsAtFirstStep() {
        let vm = PostFlowViewModel()
        vm.currentStep = 1
        vm.goBack()
        #expect(vm.currentStep == 1)
    }

    @Test func showToastWithUpdatesPublishedFlagsImmediately() {
        let vm = PostFlowViewModel()
        vm.showToastWith(message: "Saved", isError: false)
        #expect(vm.showToast == true)
        #expect(vm.toastMessage == "Saved")
        #expect(vm.toastIsError == false)

        vm.showToastWith(message: "Oops", isError: true)
        #expect(vm.toastMessage == "Oops")
        #expect(vm.toastIsError == true)
    }

    @Test func submitWithMissingFieldsShowsValidationToast() {
        let vm = PostFlowViewModel()
        vm.submitPost()
        #expect(vm.showToast == true)
        #expect(vm.toastIsError == true)
        #expect(vm.isEncodingPost == false)
    }

    @Test func submitWithoutAuthShowsSignedInToast() {
        let vm = PostFlowViewModel()
        vm.selectedImages = [UIImage()]
        vm.selectedLocation = makeLocation()
        vm.selectedVibes = ["Chill"]
        // No authViewModel attached → should fail on missing user id.
        vm.submitPost()
        #expect(vm.showToast == true)
        #expect(vm.toastIsError == true)
    }

    @Test func saveDraftManuallyFailsToastWhenNoDraftableInputs() {
        let vm = PostFlowViewModel()
        let result = vm.saveDraftManually()
        #expect(result == false)
        #expect(vm.showToast == true)
        #expect(vm.toastIsError == true)
    }

    @Test func vibePhotoMappingRequiresProEqualCountsAndOrdersPublishVibes() {
        let vm = PostFlowViewModel()
        let auth = AuthViewModel()
        auth.cancelAuthStateListeningForTests()
        auth.isPro = true
        vm.authViewModel = auth

        let p1 = PostComposerPhoto(image: UIImage())
        let p2 = PostComposerPhoto(image: UIImage())
        vm.selectedPhotos = [p1, p2]
        vm.selectedVibes = ["A", "B"]

        #expect(vm.canMatchVibesToPhotos)
        vm.setMatchVibesToPhotos(true)
        #expect(vm.matchVibesToPhotos)
        #expect(vm.vibePhotoMappings[p1.id] == "A")
        #expect(vm.resolvedPublishVibeDisplayMode == .photoSynced)

        vm.assignVibe("B", toPhotoId: p1.id)
        #expect(vm.vibePhotoMappings[p1.id] == "B")
        #expect(vm.vibePhotoMappings[p2.id] == "A")
        #expect(vm.orderedVibesForPublish == ["B", "A"])

        vm.selectedVibes = ["A"]
        vm.reconcileVibePhotoMappings()
        #expect(vm.matchVibesToPhotos == false)
        #expect(vm.vibeMappingStatusMessage == VibePhotoMappingPolicy.unequalCountsMessage)
        #expect(vm.resolvedPublishVibeDisplayMode == .rotating)

        vm.selectedVibes = ["A", "B"]
        vm.setMatchVibesToPhotos(true)
        vm.setMatchVibesToPhotos(false)
        #expect(vm.matchVibesToPhotos == false)
        #expect(vm.vibePhotoMappings.isEmpty)
    }

    @Test func setMatchVibesToPhotosNoopsWhenIneligible() {
        let vm = PostFlowViewModel()
        let auth = AuthViewModel()
        auth.cancelAuthStateListeningForTests()
        auth.isPro = false
        vm.authViewModel = auth
        vm.selectedPhotos = [PostComposerPhoto(image: UIImage()), PostComposerPhoto(image: UIImage())]
        vm.selectedVibes = ["A", "B"]
        vm.setMatchVibesToPhotos(true)
        #expect(vm.matchVibesToPhotos == false)
        #expect(vm.canMatchVibesToPhotos == false)
    }

    @Test func orderedVibesForPublishFallsBackWhenNotMatching() {
        let vm = PostFlowViewModel()
        vm.selectedVibes = ["A", "B"]
        vm.matchVibesToPhotos = false
        #expect(vm.orderedVibesForPublish == ["A", "B"])
        #expect(vm.resolvedPublishVibeDisplayMode == .rotating)
        vm.assignVibe("B", toPhotoId: UUID())
        #expect(vm.vibePhotoMappings.isEmpty)
    }

    @Test func draftPersistLoadAndManualSaveRoundTripVibeMappings() {
        PostDraftStore.clearAutosave()
        defer { PostDraftStore.clearAutosave() }

        let vm = PostFlowViewModel()
        let auth = AuthViewModel()
        auth.cancelAuthStateListeningForTests()
        auth.isPro = true
        vm.authViewModel = auth

        let p1 = PostComposerPhoto(image: solidImage())
        let p2 = PostComposerPhoto(image: solidImage())
        vm.selectedPhotos = [p1, p2]
        vm.selectedVibes = ["A", "B"]
        vm.selectedLocation = makeLocation()
        vm.setMatchVibesToPhotos(true)
        vm.persistDraftSnapshot()
        #expect(vm.activeDraftID != nil)

        let vm2 = PostFlowViewModel()
        let auth2 = AuthViewModel()
        auth2.cancelAuthStateListeningForTests()
        auth2.isPro = true
        vm2.authViewModel = auth2
        #expect(vm2.loadPersistedDraftIfAvailable())
        #expect(vm2.matchVibesToPhotos)
        #expect(vm2.vibePhotoMappings.count == 2)

        #expect(vm2.saveDraftManually())
        #expect(vm2.matchVibesToPhotos == false)
        #expect(vm2.vibePhotoMappings.isEmpty)
    }

    @Test func submitPostQueuesDraftWithPhotoSyncedMode() async {
        let vm = PostFlowViewModel()
        let auth = AuthViewModel()
        auth.cancelAuthStateListeningForTests()
        auth.applyUITestSyntheticAuthConfigurationForTests(
            .loggedIn(userId: SpotLaunchConfiguration.uiTestSyntheticUserId, isPro: true)
        )
        vm.authViewModel = auth

        let publisher = FakeSpotPublisher()
        vm.spotPublisher = publisher
        let p1 = PostComposerPhoto(image: solidImage())
        let p2 = PostComposerPhoto(image: solidImage())
        vm.selectedPhotos = [p1, p2]
        vm.selectedVibes = ["A", "B"]
        vm.selectedLocation = makeLocation()
        vm.setMatchVibesToPhotos(true)

        var queued = false
        vm.onPostQueued = { queued = true }
        vm.submitPost()

        for _ in 0..<100 where publisher.lastDraft == nil {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        #expect(publisher.lastDraft?.vibeDisplayMode == .photoSynced)
        #expect(publisher.lastDraft?.vibeTags == ["A", "B"])
        #expect(queued)
        #expect(vm.matchVibesToPhotos == false)
    }

    private func solidImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8))
        return renderer.image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
    }
}

@MainActor
private final class FakeSpotPublisher: SpotPublishing {
    private(set) var lastDraft: SpotPublishDraft?

    func enqueue(draft: SpotPublishDraft, onQueued: @escaping () -> Void) {
        lastDraft = draft
        onQueued()
    }
}

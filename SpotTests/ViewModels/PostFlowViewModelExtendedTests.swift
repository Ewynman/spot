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
}

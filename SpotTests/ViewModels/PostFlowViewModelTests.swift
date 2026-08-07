//
//  PostFlowViewModelTests.swift
//  SpotTests
//
//  Created By: Wynman, Edward
//  Date: 03/02/2025
//

import CoreLocation
import Testing
import UIKit
@testable import Spot

@MainActor
struct PostFlowViewModelTests {

    @Test func isEmailVerifiedWhenAuthViewModelNilReturnsFalse() {
        let vm = PostFlowViewModel()
        vm.authViewModel = nil
        #expect(vm.isEmailVerified == false)
    }

    @Test func isEmailVerifiedWhenAuthViewModelNotVerifiedReturnsFalse() {
        let vm = PostFlowViewModel()
        let auth = AuthViewModel()
        auth.isEmailVerified = false
        vm.authViewModel = auth
        #expect(vm.isEmailVerified == false)
    }

    @Test func isEmailVerifiedWhenAuthViewModelVerifiedReturnsTrue() {
        let vm = PostFlowViewModel()
        let auth = AuthViewModel()
        auth.isEmailVerified = true
        vm.authViewModel = auth
        #expect(vm.isEmailVerified == true)
    }

    @Test func canProceedToNextStepStep1RequiresImages() {
        let vm = PostFlowViewModel()
        vm.currentStep = 1
        vm.selectedImages = []
        #expect(vm.canProceedToNextStep == false)
        vm.selectedImages = [UIImage()]
        #expect(vm.canProceedToNextStep == true)
    }

    @Test func canProceedToNextStepStep2RequiresLocation() {
        let vm = PostFlowViewModel()
        vm.currentStep = 2
        vm.selectedLocation = nil
        #expect(vm.canProceedToNextStep == false)
        vm.selectedLocation = LocationData(
            coordinate: CLLocationCoordinate2D(latitude: 40.7, longitude: -74.0),
            placeName: "Test",
            address: nil,
            isCustomName: false
        )
        #expect(vm.canProceedToNextStep == true)
    }

    @Test func canProceedToNextStepStep3RequiresVibe() {
        let vm = PostFlowViewModel()
        vm.currentStep = 3
        vm.selectedVibes = []
        #expect(vm.canProceedToNextStep == false)
        vm.selectedVibes = ["Chill"]
        #expect(vm.canProceedToNextStep == true)
    }

    @Test func goBackAtStep1DoesNothing() {
        let vm = PostFlowViewModel()
        vm.currentStep = 1
        vm.goBack()
        #expect(vm.currentStep == 1)
    }

    @Test func goBackDecrementsStep() {
        let vm = PostFlowViewModel()
        vm.currentStep = 2
        vm.goBack()
        #expect(vm.currentStep == 1)
        vm.currentStep = 3
        vm.goBack()
        #expect(vm.currentStep == 2)
    }

    @Test func goNextIncrementsStep() {
        let vm = PostFlowViewModel()
        vm.currentStep = 1
        vm.goNext()
        #expect(vm.currentStep == 2)
        vm.goNext()
        #expect(vm.currentStep == 3)
    }

    @Test func goNextAtLastStepDoesNotExceedTotalSteps() {
        let vm = PostFlowViewModel()
        vm.currentStep = 3
        vm.goNext()
        #expect(vm.currentStep == 3)
    }

    @Test func totalStepsIsThree() {
        let vm = PostFlowViewModel()
        #expect(vm.totalSteps == 3)
    }
}

//
//  HomepageViewModelTests.swift
//  SpotTests
//
//  Created By: Wynman, Edward
//  Date: 03/02/2025
//

import Testing
@testable import Spot

struct HomepageViewModelTests {

    @Test func initialState() {
        let vm = HomepageViewModel()
        #expect(vm.selectedTab == "Home")
        #expect(vm.feedViewType == "Feed")
        #expect(vm.showUploadView == false)
        #expect(vm.showRulesSheet == false)
        #expect(vm.showVerifyToast == false)
        #expect(vm.showPostSuccessToast == false)
    }

    @Test func onPlusTappedShowsRulesSheet() {
        let vm = HomepageViewModel()
        #expect(vm.showRulesSheet == false)
        vm.onPlusTapped()
        #expect(vm.showRulesSheet == true)
    }

    @Test func agreeToRulesThenOpenUploadWhenVerifiedOpensUpload() {
        let vm = HomepageViewModel()
        vm.showRulesSheet = true
        vm.agreeToRulesThenOpenUpload(isEmailVerified: true)
        #expect(vm.showRulesSheet == false)
        #expect(vm.showUploadView == true)
    }

    @Test func agreeToRulesThenOpenUploadWhenNotVerifiedDoesNothing() {
        let vm = HomepageViewModel()
        vm.showRulesSheet = true
        vm.showUploadView = false
        vm.agreeToRulesThenOpenUpload(isEmailVerified: false)
        #expect(vm.showRulesSheet == true)
        #expect(vm.showUploadView == false)
    }

    @Test func dismissVerifyToastClearsFlag() {
        let vm = HomepageViewModel()
        vm.showVerifyToast = true
        vm.dismissVerifyToast()
        #expect(vm.showVerifyToast == false)
    }

    @Test func dismissPostSuccessToastClearsFlag() {
        let vm = HomepageViewModel()
        vm.showPostSuccessToast = true
        vm.dismissPostSuccessToast()
        #expect(vm.showPostSuccessToast == false)
    }
}

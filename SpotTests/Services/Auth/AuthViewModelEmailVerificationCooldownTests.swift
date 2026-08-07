//
//  AuthViewModelEmailVerificationCooldownTests.swift
//  SpotTests
//

import Foundation
import Testing
@testable import Spot

@MainActor
struct AuthViewModelEmailVerificationCooldownTests {

    @Test func beginEmailVerificationPending_clearsResendCooldown() {
        let vm = AuthViewModel()
        vm.emailResendAvailableAt = Date().addingTimeInterval(30)
        vm.beginEmailVerificationPending(email: "hello@example.com", avatar: nil)
        #expect(vm.emailResendAvailableAt == nil)
    }

    @Test func clearEmailVerificationPending_clearsResendCooldown() {
        let vm = AuthViewModel()
        vm.beginEmailVerificationPending(email: "hello@example.com", avatar: nil)
        vm.emailResendAvailableAt = Date().addingTimeInterval(30)
        vm.clearEmailVerificationPending()
        #expect(vm.emailResendAvailableAt == nil)
    }
}

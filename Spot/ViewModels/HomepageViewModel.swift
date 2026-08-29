//
//  HomepageViewModel.swift
//  Spot
//
//  Created by Edward Wynman on 3/2/25.
//

import Foundation
import SwiftUI

final class HomepageViewModel: ObservableObject {
    @Published var selectedTab: String = "Home"
    @Published var feedViewType: String = "Feed"
    @Published var showUploadView: Bool = false
    @Published var showRulesSheet: Bool = false
    @Published var showVerifyToast: Bool = false
    @Published var showPostSuccessToast: Bool = false

    private let toastDismissDuration: TimeInterval = 2.0
    private var verifyToastTask: Task<Void, Never>?
    private var postSuccessToastTask: Task<Void, Never>?

    /// Call when + is tapped; shows posting rules first.
    func onPlusTapped() {
        showRulesSheet = true
    }

    /// Call when user agrees to rules; opens upload if email is verified.
    func agreeToRulesThenOpenUpload(isEmailVerified: Bool) {
        if isEmailVerified {
            showRulesSheet = false
            showUploadView = true
        }
    }

    /// Show verify-email toast and auto-dismiss after delay.
    func showVerifyEmailToast() {
        verifyToastTask?.cancel()
        showVerifyToast = true
        verifyToastTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(toastDismissDuration * 1_000_000_000))
            if !Task.isCancelled {
                withAnimation { self.showVerifyToast = false }
            }
        }
    }

    /// Show post-success toast and auto-dismiss after delay.
    func showPostSuccessToastBanner() {
        postSuccessToastTask?.cancel()
        showPostSuccessToast = true
        postSuccessToastTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(toastDismissDuration * 1_000_000_000))
            if !Task.isCancelled {
                withAnimation { self.showPostSuccessToast = false }
            }
        }
    }

    func dismissVerifyToast() {
        verifyToastTask?.cancel()
        showVerifyToast = false
    }

    func dismissPostSuccessToast() {
        postSuccessToastTask?.cancel()
        showPostSuccessToast = false
    }
}

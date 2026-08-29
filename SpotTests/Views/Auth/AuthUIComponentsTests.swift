//
//  AuthUIComponentsTests.swift
//  SpotTests
//
//  Created by Edward Wynman on 8/28/26.
//

import SwiftUI
import Testing
@testable import Spot

@MainActor
struct AuthUIComponentsTests {
    @Test func sharedAuthenticationComponentsBuildTheirBodies() {
        _ = AuthWordmark().body
        _ = AuthScreenHeader(title: "Welcome back", subtitle: "Glad to see you.").body

        _ = AuthPrimaryButton(
            title: "Continue",
            isLoading: false,
            isEnabled: true,
            action: {}
        ).body
        _ = AuthPrimaryButton(
            title: "Loading",
            isLoading: true,
            isEnabled: false,
            action: {}
        ).body

        _ = AuthSecondaryButton(title: "Use another account", action: {}).body
        _ = AuthDivider().body
        _ = AuthLegalFooter().body
    }
}

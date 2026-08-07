//
//  SpotLaunchConfigurationTests.swift
//  SpotTests
//

import Foundation
import Testing
@testable import Spot

struct SpotLaunchConfigurationTests {

    @Test func uiTestModeIsOffInUnitTestProcessByDefault() {
        #expect(SpotLaunchConfiguration.isUITestMode == false)
    }

    @Test func syntheticUserIdIsStableUuidString() {
        #expect(UUID(uuidString: SpotLaunchConfiguration.uiTestSyntheticUserId) != nil)
    }
}

//
//  URLConfigurationTests.swift
//  SpotTests
//
//  Created By: Wynman, Edward
//  Date: 03/02/2025
//

import Testing
@testable import Spot

struct URLConfigurationTests {

    @Test func isAllowedUniversalLinkHostForKnownHost() {
        let config = URLConfiguration.shared
        #expect(config.isAllowedUniversalLinkHost("spotapp.online"))
    }

    @Test func isAllowedUniversalLinkHostForLocalhostMatchesBuildConfiguration() {
        let config = URLConfiguration.shared
        #if DEBUG
        #expect(config.isAllowedUniversalLinkHost("localhost"))
        #else
        #expect(!config.isAllowedUniversalLinkHost("localhost"))
        #endif
    }

    @Test func isAllowedUniversalLinkHostForUnknownHost() {
        let config = URLConfiguration.shared
        #expect(!config.isAllowedUniversalLinkHost("evil.com"))
    }

    @Test func shareURLForSpotId() {
        let config = URLConfiguration.shared
        let url = config.shareURL(for: "abc123")
        #expect(url.contains("/s/abc123"))
    }

    @Test func customScheme() {
        let config = URLConfiguration.shared
        #expect(config.customScheme == "spotapp")
    }

    @Test func shareURLBase() {
        let config = URLConfiguration.shared
        #expect(config.shareURLBase.contains("spotapp"))
    }
}

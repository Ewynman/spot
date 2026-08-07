//
//  DeepLinkRouterTests.swift
//  SpotTests
//
//  Created By: Wynman, Edward
//  Date: 03/02/2025
//

import Foundation
import Testing
@testable import Spot

struct DeepLinkRouterTests {

    private let router = DeepLinkRouter.shared

    @Test func parseUniversalLinkSpotDetail() {
        let url = URL(string: "https://spotapp.online/s/abc123xyz")!
        let route = router.parseURL(url)
        if case .spotDetail(let spotId) = route {
            #expect(spotId == "abc123xyz")
        } else { Issue.record("Expected spotDetail") }
    }

    @Test func parseLocalhostUniversalLink() {
        let url = URL(string: "http://localhost/s/validSpotId")!
        let route = router.parseURL(url)
        if case .spotDetail(let spotId) = route {
            #expect(spotId == "validSpotId")
        } else { Issue.record("Expected spotDetail") }
    }

    @Test func parseCustomSchemeHostVariant() {
        let url = URL(string: "spotapp://spot/abc123")!
        let route = router.parseURL(url)
        if case .spotDetail(let spotId) = route {
            #expect(spotId == "abc123")
        } else { Issue.record("Expected spotDetail") }
    }

    @Test func parseCustomSchemePathVariant() {
        let url = URL(string: "spotapp:///spot/xyz789")!
        let route = router.parseURL(url)
        if case .spotDetail(let spotId) = route {
            #expect(spotId == "xyz789")
        } else { Issue.record("Expected spotDetail") }
    }

    @Test func parseCustomSchemeQueryVariant() {
        let url = URL(string: "spotapp://open?spotId=querySpotId")!
        let route = router.parseURL(url)
        if case .spotDetail(let spotId) = route {
            #expect(spotId == "querySpotId")
        } else { Issue.record("Expected spotDetail") }
    }

    @Test func parseSubscriptionReturn() {
        let url = URL(string: "spotapp://subscription/return")!
        let route = router.parseURL(url)
        if case .subscriptionReturn = route { } else { Issue.record("Expected subscriptionReturn") }
    }

    @Test func parseUnknownScheme() {
        let url = URL(string: "mailto:test@example.com")!
        let route = router.parseURL(url)
        if case .unknown = route { } else { Issue.record("Expected unknown") }
    }

    @Test func parseInvalidSpotIdEmpty() {
        let url = URL(string: "https://spotapp.online/s/")!
        let route = router.parseURL(url)
        if case .unknown = route { } else { Issue.record("Expected unknown for empty spotId") }
    }

    @Test func parseInvalidSpotIdTooLong() {
        let longId = String(repeating: "a", count: 51)
        let url = URL(string: "https://spotapp.online/s/\(longId)")!
        let route = router.parseURL(url)
        if case .unknown = route { } else { Issue.record("Expected unknown for too long spotId") }
    }

    @Test func parseInvalidSpotIdInvalidChars() {
        let url = URL(string: "https://spotapp.online/s/spot%20id")!
        let route = router.parseURL(url)
        if case .unknown = route { } else { Issue.record("Expected unknown for invalid chars") }
    }

    @Test func urlQueryParameters() {
        let url = URL(string: "https://example.com?foo=bar&baz=qux")!
        let params = url.queryParameters
        #expect(params != nil)
        #expect(params?["foo"] == "bar")
        #expect(params?["baz"] == "qux")
    }

    @Test func urlQueryParametersNilWhenNoQuery() {
        let url = URL(string: "https://example.com/path")!
        #expect(url.queryParameters == nil)
    }
}

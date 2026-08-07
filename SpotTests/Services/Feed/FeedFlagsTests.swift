//
//  FeedFlagsTests.swift
//  SpotTests
//
//  Smoke-tests the production defaults for `FeedFlags`. If any of these flip
//  to a non-production-ready value (e.g. v2 RPC disabled, primary-image
//  hydration off, debug logging on globally) CI will fail loudly so a
//  reviewer catches it before merge.
//

import Testing
@testable import Spot

struct FeedFlagsTests {

    @Test func hydrateOnlyPrimaryFeedImageDefaultIsOn() {
        #expect(FeedFlags.hydrateOnlyPrimaryFeedImage == true)
    }

    @Test func useServerSideImpressionsDefaultIsOn() {
        #expect(FeedFlags.useServerSideImpressions == true)
    }

    @Test func diagnosticLoggingDefaultIsOff() {
        // Diagnostic logging is verbose and only meant to be flipped on at
        // runtime when investigating a feed regression.
        #expect(FeedFlags.enableDiagnosticLogging == false)
    }

    @Test func disablePersistentDedupeDefaultIsOff() {
        // Local seen state is a transient safety net; we never want it
        // disabled by default in production.
        #expect(FeedFlags.disablePersistentDedupe == false)
    }

    @Test func pageSizeMatchesServerLimit() {
        // Server-side `get_home_feed_v1` clamps p_limit to 1..50. Page size
        // must stay within that range.
        #expect(FeedFlags.pageSize >= 1)
        #expect(FeedFlags.pageSize <= 50)
    }
}

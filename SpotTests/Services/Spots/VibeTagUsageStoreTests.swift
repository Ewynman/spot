//
//  VibeTagUsageStoreTests.swift
//  SpotTests
//
//  Created By: Wynman, Edward
//  Date: 04/27/2026
//
//  Coverage for the pure logic of `VibeTagUsageStore`. The store currently
//  writes to `UserDefaults.standard`, so tests reset the relevant key in
//  setup/teardown to remain hermetic.
//

import Foundation
import Testing
@testable import Spot

// Serialized because `VibeTagUsageStore` reads/writes `UserDefaults.standard`
// directly. Running these tests in parallel would let them clobber each
// other's state through the shared default suite.
@Suite(.serialized)
struct VibeTagUsageStoreTests {

    private static let usageKey = "postFlow.vibeTagUsage"

    private func clearUsage() {
        UserDefaults.standard.removeObject(forKey: Self.usageKey)
    }

    @Test func recentAndFrequentEmptyByDefault() {
        clearUsage()
        defer { clearUsage() }
        #expect(VibeTagUsageStore.recentAndFrequent().isEmpty)
    }

    @Test func recordUsageBumpsCountForTags() {
        clearUsage()
        defer { clearUsage() }
        VibeTagUsageStore.recordUsage(tags: ["Chill"])
        VibeTagUsageStore.recordUsage(tags: ["Chill", "Adventure"])
        let recent = VibeTagUsageStore.recentAndFrequent(limit: 5)
        // Chill is used twice, Adventure once. Chill should outrank Adventure.
        #expect(recent.count == 2)
        #expect(recent.first == "Chill")
        #expect(recent.contains("Adventure"))
    }

    @Test func recordUsageNormalizesWhitespaceAndIgnoresEmpty() {
        clearUsage()
        defer { clearUsage() }
        VibeTagUsageStore.recordUsage(tags: ["  Chill  ", "", "  "])
        let recent = VibeTagUsageStore.recentAndFrequent(limit: 5)
        #expect(recent == ["Chill"])
    }

    @Test func recordUsageNoopForEmptyArray() {
        clearUsage()
        defer { clearUsage() }
        VibeTagUsageStore.recordUsage(tags: [])
        #expect(VibeTagUsageStore.recentAndFrequent().isEmpty)
    }

    @Test func recentAndFrequentExcludesSelectedTags() {
        clearUsage()
        defer { clearUsage() }
        VibeTagUsageStore.recordUsage(tags: ["Chill", "Adventure", "Foodie"])
        let filtered = VibeTagUsageStore.recentAndFrequent(limit: 5, excluding: ["Chill"])
        #expect(!filtered.contains("Chill"))
        #expect(filtered.contains("Adventure"))
        #expect(filtered.contains("Foodie"))
    }

    @Test func recentAndFrequentRespectsLimit() {
        clearUsage()
        defer { clearUsage() }
        for tag in ["A", "B", "C", "D", "E"] {
            VibeTagUsageStore.recordUsage(tags: [tag])
        }
        let limited = VibeTagUsageStore.recentAndFrequent(limit: 2)
        #expect(limited.count == 2)
    }

    @Test func tagsWithEqualCountSortByRecency() {
        clearUsage()
        defer { clearUsage() }
        VibeTagUsageStore.recordUsage(tags: ["First"])
        // Slight pause to ensure separate timestamps.
        Thread.sleep(forTimeInterval: 0.01)
        VibeTagUsageStore.recordUsage(tags: ["Second"])
        let recent = VibeTagUsageStore.recentAndFrequent(limit: 5)
        #expect(recent.count == 2)
        #expect(recent.first == "Second")
    }
}

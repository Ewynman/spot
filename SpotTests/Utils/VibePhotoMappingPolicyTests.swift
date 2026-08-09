import Foundation
import Testing
@testable import Spot

struct VibePhotoMappingPolicyTests {
    @Test func eligibilityRequiresProEqualCountsAtLeastTwo() {
        #expect(VibePhotoMappingPolicy.isEligible(photoCount: 2, vibeCount: 2, isPro: true))
        #expect(VibePhotoMappingPolicy.isEligible(photoCount: 5, vibeCount: 5, isPro: true))
        #expect(!VibePhotoMappingPolicy.isEligible(photoCount: 2, vibeCount: 2, isPro: false))
        #expect(!VibePhotoMappingPolicy.isEligible(photoCount: 3, vibeCount: 2, isPro: true))
        #expect(!VibePhotoMappingPolicy.isEligible(photoCount: 1, vibeCount: 1, isPro: true))
        #expect(!VibePhotoMappingPolicy.isEligible(photoCount: 5, vibeCount: 3, isPro: true))
    }

    @Test func initialMappingsPairByOrder() {
        let p1 = UUID()
        let p2 = UUID()
        let p3 = UUID()
        let map = VibePhotoMappingPolicy.initialMappings(
            photoIds: [p1, p2, p3],
            vibes: ["Scenic View", "Cruising", "Nature Escape"]
        )
        #expect(map[p1] == "Scenic View")
        #expect(map[p2] == "Cruising")
        #expect(map[p3] == "Nature Escape")
    }

    @Test func swapMappingExchangesAssignments() {
        let p1 = UUID()
        let p2 = UUID()
        let before: [UUID: String] = [p1: "Scenic View", p2: "Cruising"]
        let after = VibePhotoMappingPolicy.swapMapping(
            mappings: before,
            photoId: p1,
            newVibe: "Cruising"
        )
        #expect(after[p1] == "Cruising")
        #expect(after[p2] == "Scenic View")
    }

    @Test func reconcileInvalidatesWhenCountsDiverge() {
        let p1 = UUID()
        let p2 = UUID()
        let result = VibePhotoMappingPolicy.reconcile(
            photoIds: [p1, p2],
            vibes: ["A"],
            mappings: [p1: "A", p2: "B"],
            matchEnabled: true,
            isPro: true
        )
        #expect(result.matchEnabled == false)
        #expect(result.didInvalidate == true)
        #expect(result.mappings.isEmpty)
    }

    @Test func orderedVibesFollowPhotoOrder() {
        let p1 = UUID()
        let p2 = UUID()
        let ordered = VibePhotoMappingPolicy.orderedVibes(
            photoIds: [p2, p1],
            mappings: [p1: "First", p2: "Second"]
        )
        #expect(ordered == ["Second", "First"])
    }

    @Test func syncedLabelUsesPhotoSyncedArray() {
        let label = VibePhotoMappingPolicy.syncedLabel(
            photoSyncedVibeLabels: ["A", "B", "C"],
            index: 1,
            fallback: ["X"]
        )
        #expect(label == "B")
    }
}

struct SpotVibeDisplayModeTests {
    @Test func cardVibeLabelUsesSyncedIndex() {
        var spot = Spot(
            id: UUID().uuidString,
            vibeTags: ["A", "B", "C"],
            authorIsPro: true,
            vibeDisplayMode: .photoSynced,
            photoSyncedVibeLabels: ["A", "B", "C"]
        )
        #expect(spot.cardVibeLabel(forCommittedPhotoIndex: 2) == "C")
        #expect(spot.vibeLabelsForSheet() == ["A", "B", "C"])
        spot.vibeDisplayMode = .rotating
        #expect(spot.vibeLabelsForSheet() == ["A", "B", "C"])
    }

    @Test func vibeDisplayModeDefaultsFromRaw() {
        #expect(VibeDisplayMode(rawValueOrDefault: nil) == .rotating)
        #expect(VibeDisplayMode(rawValueOrDefault: "photo_synced") == .photoSynced)
        #expect(VibeDisplayMode(rawValueOrDefault: "nope") == .rotating)
    }
}

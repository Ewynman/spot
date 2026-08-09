import Foundation
import Testing
@testable import Spot

struct SpotVibeSyncHydrationTests {
    @Test func photoSyncedLabelsBySpotIdOrdersAndSkipsMissingNames() {
        let spot = UUID()
        let vibeA = UUID()
        let vibeB = UUID()
        let labels = SpotVibeSyncHydration.photoSyncedLabelsBySpotId(
            rows: [
                .init(spotId: spot, sortIndex: 1, vibeTagId: vibeB),
                .init(spotId: spot, sortIndex: 0, vibeTagId: vibeA),
                .init(spotId: spot, sortIndex: 2, vibeTagId: UUID())
            ],
            namesByVibeId: [vibeA: "A", vibeB: "B"]
        )
        #expect(labels[spot] == ["A", "B"])
        #expect(SpotVibeSyncHydration.photoSyncedLabelsBySpotId(rows: [], namesByVibeId: [:]).isEmpty)
    }

    @Test func displayModesMapRawValues() {
        let id = UUID()
        let modes = SpotVibeSyncHydration.displayModesBySpotId(
            rows: [
                .init(id: id, vibeDisplayMode: "photo_synced"),
                .init(id: UUID(), vibeDisplayMode: "nope")
            ]
        )
        #expect(modes[id] == .photoSynced)
    }

    @Test func displayModesEmptyShortCircuitsLoader() async throws {
        var loaded = false
        let modes = try await SpotVibeSyncHydration.displayModes(spotIds: []) { _ in
            loaded = true
            return []
        }
        #expect(modes.isEmpty)
        #expect(loaded == false)
    }

    @Test func displayModesUsesLoader() async throws {
        let id = UUID()
        let modes = try await SpotVibeSyncHydration.displayModes(spotIds: [id]) { ids in
            #expect(ids == [id])
            return [.init(id: id, vibeDisplayMode: "photo_synced")]
        }
        #expect(modes[id] == .photoSynced)
    }

    @Test func photoSyncedLabelsDerivesFromJunctionWhenSynced() {
        #expect(
            SpotVibeSyncHydration.photoSyncedLabels(
                mode: .photoSynced,
                junctionLabels: ["A", "B"]
            ) == ["A", "B"]
        )
        #expect(
            SpotVibeSyncHydration.photoSyncedLabels(
                mode: .rotating,
                junctionLabels: ["A", "B"]
            ) == nil
        )
        #expect(
            SpotVibeSyncHydration.photoSyncedLabels(
                mode: .photoSynced,
                junctionLabels: ["A"],
                explicitSynced: ["X", "Y"]
            ) == ["X", "Y"]
        )
    }

    @Test func attachingAndCardEnrichmentApplyModeAndSyncedLabels() {
        let spotId = UUID()
        let userId = UUID()
        let base = SpotTestHelpers.makeSpot(
            id: spotId.uuidString,
            userId: userId.uuidString,
            vibeTags: ["A", "B"]
        )
        let attached = SpotVibeSyncHydration.attaching(
            to: base,
            vibeDisplayModeRaw: "photo_synced",
            junctionLabels: ["A", "B"]
        )
        #expect(attached.vibeDisplayMode == .photoSynced)
        #expect(attached.photoSyncedVibeLabels == ["A", "B"])

        let enriched = SpotVibeSyncHydration.applyCardEnrichment(
            spots: [base],
            labelsBySpotId: [spotId: ["Scenic", "Chill"]],
            modeBySpotId: [spotId: .photoSynced],
            authorProByUserId: [userId.uuidString: true]
        )
        #expect(enriched.first?.vibeTags == ["Scenic", "Chill"])
        #expect(enriched.first?.vibeDisplayMode == .photoSynced)
        #expect(enriched.first?.photoSyncedVibeLabels == ["Scenic", "Chill"])
        #expect(enriched.first?.authorIsPro == true)
        #expect(SpotVibeSyncHydration.publishDisplayModeParam(.photoSynced) == "photo_synced")
        let chained = base.withVibeSync(modeRaw: "photo_synced", junctionLabels: ["A", "B"])
        #expect(chained.photoSyncedVibeLabels == ["A", "B"])

        let applied = SpotVibeSyncHydration.applyingRowModes(
            spots: [base],
            modeBySpotId: [spotId: "photo_synced"],
            labelsBySpotId: [spotId: ["A", "B"]]
        )
        #expect(applied.first?.photoSyncedVibeLabels == ["A", "B"])
    }

    @Test func enrichSpotsForCardPresentationOrchestratesFetchers() async throws {
        let spotId = UUID()
        let userId = UUID()
        let spots = [
            SpotTestHelpers.makeSpot(id: spotId.uuidString, userId: userId.uuidString, vibeTag: "A")
        ]
        let enriched = try await SpotVibeSyncHydration.enrichSpotsForCardPresentation(
            spots,
            fetchLabels: { ids in
                #expect(ids == [spotId])
                return [spotId: ["A", "B"]]
            },
            fetchModes: { _ in [spotId: .photoSynced] },
            fetchPro: { _ in [userId.uuidString: true] }
        )
        #expect(enriched.first?.photoSyncedVibeLabels == ["A", "B"])
        #expect(enriched.first?.authorIsPro == true)

        let empty = try await SpotVibeSyncHydration.enrichSpotsForCardPresentation(
            [],
            fetchLabels: { _ in [:] },
            fetchModes: { _ in [:] },
            fetchPro: { _ in [:] }
        )
        #expect(empty.isEmpty)
    }
}

struct SpotVibeSyncRemoteTests {
    @Test func fetchDisplayModesUsesInjectedLoader() async throws {
        let id = UUID()
        let modes = try await SpotVibeSyncRemote.fetchDisplayModes(spotIds: [id]) { ids in
            #expect(ids == [id])
            return [.init(id: id, vibeDisplayMode: "rotating")]
        }
        #expect(modes[id] == .rotating)
    }

    @Test func fetchDisplayModesEmptyIdsSkipsLoader() async throws {
        var loaded = false
        let modes = try await SpotVibeSyncRemote.fetchDisplayModes(spotIds: []) { _ in
            loaded = true
            return []
        }
        #expect(modes.isEmpty)
        #expect(loaded == false)
    }
}

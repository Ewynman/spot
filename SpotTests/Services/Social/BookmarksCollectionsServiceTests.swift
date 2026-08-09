import Foundation
import Testing
@testable import Spot

private actor FakeBookmarkCollectionsStore: BookmarkCollectionsPersisting {
    var ownedCollectionIds: [UUID] = []
    var membershipsBySpot: [UUID: [UUID]] = [:]
    private(set) var insertedNames: [String] = []
    private(set) var upserts: [(collectionId: UUID, spotId: UUID, sortIndex: Int)] = []
    private(set) var deletes: [(collectionId: UUID, spotId: UUID)] = []
    var ownershipShouldFail = false
    var nextSortIndexValue = 3

    func insertCollection(userId: UUID, name: String) async throws -> UUID {
        insertedNames.append(name)
        let id = UUID()
        ownedCollectionIds.append(id)
        return id
    }

    func assertOwnsCollection(userId: UUID, collectionId: UUID) async throws {
        if ownershipShouldFail {
            throw NSError(domain: "BookmarksCollectionsService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Collection not found"])
        }
    }

    func nextSortIndex(collectionId: UUID) async throws -> Int {
        nextSortIndexValue
    }

    func upsertSpotLink(collectionId: UUID, spotId: UUID, sortIndex: Int) async throws {
        upserts.append((collectionId, spotId, sortIndex))
    }

    func deleteSpotLink(collectionId: UUID, spotId: UUID) async throws {
        deletes.append((collectionId, spotId))
    }

    func listOwnedCollectionIds(userId: UUID) async throws -> [UUID] {
        ownedCollectionIds
    }

    func listMemberships(spotId: UUID, in collectionIds: [UUID]) async throws -> [UUID] {
        let owned = Set(collectionIds)
        return (membershipsBySpot[spotId] ?? []).filter { owned.contains($0) }
    }
}

private actor ActionTracker {
    private(set) var actions: [(String, String, String)] = []

    func track(_ action: String, _ contentType: String, _ contentId: String) {
        actions.append((action, contentType, contentId))
    }
}

struct BookmarksCollectionsServiceTests {
    private let userId = UUID()
    private let spotId = UUID()
    private let collectionId = UUID()

    @Test func createCollectionTracksAnalytics() async throws {
        let store = FakeBookmarkCollectionsStore()
        let tracker = ActionTracker()
        let service = BookmarksCollectionsService(
            store: store,
            userIdProvider: { self.userId.uuidString },
            trackUserAction: { action, contentType, contentId in
                await tracker.track(action, contentType, contentId)
            }
        )

        let createdId = try await service.createCollection(name: "Weekend")
        #expect(UUID(uuidString: createdId) != nil)
        #expect(await store.insertedNames == ["Weekend"])

        let actions = await tracker.actions
        #expect(actions.count == 1)
        #expect(actions[0].0 == "collection_created")
        #expect(actions[0].1 == "collection")
        #expect(actions[0].2 == createdId)
    }

    @Test func addSpotUsesConflictSafeUpsertAndTracks() async throws {
        let store = FakeBookmarkCollectionsStore()
        let tracker = ActionTracker()
        let service = BookmarksCollectionsService(
            store: store,
            userIdProvider: { self.userId.uuidString },
            trackUserAction: { action, contentType, contentId in
                await tracker.track(action, contentType, contentId)
            }
        )

        try await service.addSpot(spotId.uuidString, to: collectionId.uuidString)

        let upserts = await store.upserts
        #expect(upserts.count == 1)
        #expect(upserts[0].collectionId == collectionId)
        #expect(upserts[0].spotId == spotId)
        #expect(upserts[0].sortIndex == 3)

        let actions = await tracker.actions
        #expect(actions.count == 1)
        #expect(actions[0].0 == "spot_added_to_collection")
        #expect(actions[0].1 == "spot")
        #expect(actions[0].2 == spotId.uuidString)
    }

    @Test func addSpotRejectsInvalidIds() async {
        let service = BookmarksCollectionsService(
            store: FakeBookmarkCollectionsStore(),
            userIdProvider: { self.userId.uuidString },
            trackUserAction: { _, _, _ in }
        )

        await #expect(throws: NSError.self) {
            try await service.addSpot("bad", to: collectionId.uuidString)
        }
    }

    @Test func removeSpotDeletesMembershipAndTracks() async throws {
        let store = FakeBookmarkCollectionsStore()
        let tracker = ActionTracker()
        let service = BookmarksCollectionsService(
            store: store,
            userIdProvider: { self.userId.uuidString },
            trackUserAction: { action, contentType, contentId in
                await tracker.track(action, contentType, contentId)
            }
        )

        try await service.removeSpot(spotId.uuidString, from: collectionId.uuidString)

        #expect(await store.deletes.count == 1)
        #expect(await store.deletes[0].collectionId == collectionId)
        #expect(await store.deletes[0].spotId == spotId)

        let actions = await tracker.actions
        #expect(actions.count == 1)
        #expect(actions[0].0 == "spot_removed_from_collection")
        #expect(actions[0].1 == "spot")
        #expect(actions[0].2 == spotId.uuidString)
    }

    @Test func collectionIdsReturnsMembershipSet() async throws {
        let otherCollection = UUID()
        let store = FakeBookmarkCollectionsStore()
        await store.setOwned([collectionId, otherCollection])
        await store.setMemberships(spotId: spotId, collections: [collectionId])

        let service = BookmarksCollectionsService(
            store: store,
            userIdProvider: { self.userId.uuidString },
            trackUserAction: { _, _, _ in }
        )

        let ids = try await service.collectionIds(containing: spotId.uuidString)
        #expect(ids == [collectionId.uuidString])
    }

    @Test func collectionIdsReturnsEmptyWhenUserHasNoCollections() async throws {
        let store = FakeBookmarkCollectionsStore()
        let service = BookmarksCollectionsService(
            store: store,
            userIdProvider: { self.userId.uuidString },
            trackUserAction: { _, _, _ in }
        )

        let ids = try await service.collectionIds(containing: spotId.uuidString)
        #expect(ids.isEmpty)
    }

    @Test func collectionIdsRejectsInvalidSpotId() async {
        let service = BookmarksCollectionsService(
            store: FakeBookmarkCollectionsStore(),
            userIdProvider: { self.userId.uuidString },
            trackUserAction: { _, _, _ in }
        )

        await #expect(throws: NSError.self) {
            try await service.collectionIds(containing: "nope")
        }
    }

    @Test func mutatingMethodsRequireAuthenticatedUser() async {
        let service = BookmarksCollectionsService(
            store: FakeBookmarkCollectionsStore(),
            userIdProvider: { nil },
            trackUserAction: { _, _, _ in }
        )

        await #expect(throws: NSError.self) {
            try await service.createCollection(name: "X")
        }
        await #expect(throws: NSError.self) {
            try await service.addSpot(spotId.uuidString, to: collectionId.uuidString)
        }
        await #expect(throws: NSError.self) {
            try await service.collectionIds(containing: spotId.uuidString)
        }
    }
}

private extension FakeBookmarkCollectionsStore {
    func setOwned(_ ids: [UUID]) {
        ownedCollectionIds = ids
    }

    func setMemberships(spotId: UUID, collections: [UUID]) {
        membershipsBySpot[spotId] = collections
    }
}

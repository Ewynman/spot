import Foundation
import Testing
@testable import Spot

private actor FakeSpotBookmarkStore: SpotBookmarkPersisting {
    private(set) var upsertCalls: [(userId: UUID, spotId: UUID)] = []
    private(set) var removeCalls: [UUID] = []
    var errorToThrow: Error?

    func upsertBookmark(userId: UUID, spotId: UUID) async throws {
        if let errorToThrow { throw errorToThrow }
        upsertCalls.append((userId, spotId))
    }

    func removeSavedSpot(spotId: UUID) async throws {
        if let errorToThrow { throw errorToThrow }
        removeCalls.append(spotId)
    }
}

private actor ActionTracker {
    private(set) var actions: [(String, String, String)] = []

    func track(_ action: String, _ contentType: String, _ contentId: String) {
        actions.append((action, contentType, contentId))
    }
}

struct UserSpotServiceBookmarkTests {
    private let userId = UUID()
    private let spotId = UUID()

    @Test func setBookmarkSavePersistsAndTracks() async throws {
        let store = FakeSpotBookmarkStore()
        let tracker = ActionTracker()
        let service = UserSpotService(
            bookmarkStore: store,
            mutationGate: SpotSaveMutationGate(),
            userIdProvider: { self.userId.uuidString },
            trackUserAction: { action, contentType, contentId in
                await tracker.track(action, contentType, contentId)
            }
        )

        try await service.setBookmark(spotId: spotId.uuidString, isSaved: true)

        let upserts = await store.upsertCalls
        #expect(upserts.count == 1)
        #expect(upserts[0].userId == userId)
        #expect(upserts[0].spotId == spotId)
        #expect(await store.removeCalls.isEmpty)

        let actions = await tracker.actions
        #expect(actions == [("spot_saved", "spot", spotId.uuidString)])
    }

    @Test func setBookmarkUnsaveUsesRemoveRPCPathAndTracks() async throws {
        let store = FakeSpotBookmarkStore()
        let tracker = ActionTracker()
        let service = UserSpotService(
            bookmarkStore: store,
            mutationGate: SpotSaveMutationGate(),
            userIdProvider: { self.userId.uuidString },
            trackUserAction: { action, contentType, contentId in
                await tracker.track(action, contentType, contentId)
            }
        )

        try await service.setBookmark(spotId: spotId.uuidString, isSaved: false)

        #expect(await store.upsertCalls.isEmpty)
        #expect(await store.removeCalls == [spotId])

        let actions = await tracker.actions
        #expect(actions == [("spot_unsaved", "spot", spotId.uuidString)])
    }

    @Test func setBookmarkRequiresAuthenticatedUser() async {
        let service = UserSpotService(
            bookmarkStore: FakeSpotBookmarkStore(),
            mutationGate: SpotSaveMutationGate(),
            userIdProvider: { nil },
            trackUserAction: { _, _, _ in }
        )

        await #expect(throws: NSError.self) {
            try await service.setBookmark(spotId: spotId.uuidString, isSaved: true)
        }
    }

    @Test func setBookmarkRejectsInvalidSpotId() async {
        let service = UserSpotService(
            bookmarkStore: FakeSpotBookmarkStore(),
            mutationGate: SpotSaveMutationGate(),
            userIdProvider: { self.userId.uuidString },
            trackUserAction: { _, _, _ in }
        )

        await #expect(throws: NSError.self) {
            try await service.setBookmark(spotId: "not-a-uuid", isSaved: true)
        }
    }

    @Test func bookmarkSpotCompletionReportsSuccess() async {
        let store = FakeSpotBookmarkStore()
        let service = UserSpotService(
            bookmarkStore: store,
            mutationGate: SpotSaveMutationGate(),
            userIdProvider: { self.userId.uuidString },
            trackUserAction: { _, _, _ in }
        )

        let result = await withCheckedContinuation { continuation in
            service.bookmarkSpot(spotId: spotId.uuidString) { result in
                continuation.resume(returning: result)
            }
        }

        #expect((try? result.get()) != nil)
        #expect(await store.upsertCalls.count == 1)
    }

    @Test func unbookmarkSpotCompletionReportsFailure() async {
        struct Boom: Error {}
        let store = FakeSpotBookmarkStore()
        await store.setError(Boom())
        let service = UserSpotService(
            bookmarkStore: store,
            mutationGate: SpotSaveMutationGate(),
            userIdProvider: { self.userId.uuidString },
            trackUserAction: { _, _, _ in }
        )

        let result = await withCheckedContinuation { continuation in
            service.unbookmarkSpot(spotId: spotId.uuidString) { result in
                continuation.resume(returning: result)
            }
        }

        guard case .failure = result else {
            Issue.record("Expected unbookmarkSpot to fail")
            return
        }
    }
}

private extension FakeSpotBookmarkStore {
    func setError(_ error: Error?) {
        errorToThrow = error
    }
}

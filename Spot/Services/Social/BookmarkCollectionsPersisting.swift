import Foundation

protocol BookmarkCollectionsPersisting: Sendable {
    func insertCollection(userId: UUID, name: String) async throws -> UUID
    func assertOwnsCollection(userId: UUID, collectionId: UUID) async throws
    func nextSortIndex(collectionId: UUID) async throws -> Int
    func upsertSpotLink(collectionId: UUID, spotId: UUID, sortIndex: Int) async throws
    func deleteSpotLink(collectionId: UUID, spotId: UUID) async throws
    func listOwnedCollectionIds(userId: UUID) async throws -> [UUID]
    func listMemberships(spotId: UUID, in collectionIds: [UUID]) async throws -> [UUID]
}

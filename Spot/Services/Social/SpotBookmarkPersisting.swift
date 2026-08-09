import Foundation

protocol SpotBookmarkPersisting: Sendable {
    func upsertBookmark(userId: UUID, spotId: UUID) async throws
    func removeSavedSpot(spotId: UUID) async throws
}

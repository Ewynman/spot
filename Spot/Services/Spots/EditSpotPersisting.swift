import Foundation

protocol EditSpotPersisting: Sendable {
    func fetchEditableSpotImages(id: UUID) async throws -> [EditableSpotImage]
    func prepareApprovedSpotImage(userId: UUID, jpeg: Data) async throws -> UUID
    func updateSpotFromEditor(
        id: UUID,
        vibeTags: [String],
        latitude: Double,
        longitude: Double,
        locationName: String,
        media: [EditSpotMediaReference],
        vibeDisplayMode: VibeDisplayMode
    ) async throws
    func fetchSpotsByIds(_ ids: [UUID]) async throws -> [Spot]
}

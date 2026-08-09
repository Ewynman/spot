import Foundation

struct SupabaseEditSpotStore: EditSpotPersisting {
    func fetchEditableSpotImages(id: UUID) async throws -> [EditableSpotImage] {
        try await EditSpotEditorSupport.fetchEditableSpotImages(id: id, loadRows: SpotSupabaseRepository.loadEditSpotImageRows, resolveURLs: SpotSupabaseRepository.resolveStoredImageURLs)
    }

    func prepareApprovedSpotImage(userId: UUID, jpeg: Data) async throws -> UUID {
        try await EditSpotEditorSupport.prepareApprovedSpotImage(userId: userId, jpeg: jpeg, insert: SpotSupabaseRepository.insertPendingMediaAsset, upload: SpotSupabaseRepository.uploadPendingMediaAsset, moderate: SpotSupabaseRepository.moderatePendingImageAsset)
    }

    func updateSpotFromEditor(id: UUID, vibeTags: [String], latitude: Double, longitude: Double, locationName: String, media: [EditSpotMediaReference]) async throws {
        try await EditSpotEditorSupport.updateSpotFromEditor(id: id, vibeTags: vibeTags, latitude: latitude, longitude: longitude, locationName: locationName, media: media, resolveVibeId: SpotSupabaseRepository.resolveOrCreateVibeTagId, invokeRPC: SpotSupabaseRepository.invokeUpdateSpotEditorRPC)
    }

    func fetchSpotsByIds(_ ids: [UUID]) async throws -> [Spot] {
        try await SpotSupabaseRepository.fetchSpotsByIds(ids)
    }
}

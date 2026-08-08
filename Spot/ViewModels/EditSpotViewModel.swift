import CoreLocation
import Foundation
import UIKit

struct EditSpotDraftPhoto: Identifiable {
    let id: UUID
    let remoteURL: String
    var replacement: PostComposerPhoto?
    var approvedAssetID: UUID?

    var isReplacement: Bool { replacement != nil }
}

enum EditSpotDraftOperations {
    static func hydrate(_ media: [EditableSpotImage]) -> [EditSpotDraftPhoto] {
        media
            .sorted { $0.sortIndex < $1.sortIndex }
            .map {
                EditSpotDraftPhoto(
                    id: $0.id,
                    remoteURL: $0.url,
                    replacement: nil,
                    approvedAssetID: nil
                )
            }
    }

    static func reorder(
        _ photos: [EditSpotDraftPhoto],
        id: UUID,
        to destination: Int
    ) -> [EditSpotDraftPhoto] {
        guard let source = photos.firstIndex(where: { $0.id == id }),
              photos.indices.contains(destination),
              source != destination else { return photos }
        var result = photos
        let photo = result.remove(at: source)
        result.insert(photo, at: destination)
        return result
    }

    static func mediaReferences(
        for photos: [EditSpotDraftPhoto]
    ) throws -> [EditSpotMediaReference] {
        try photos.map { photo in
            if photo.isReplacement {
                guard let assetID = photo.approvedAssetID else {
                    throw NSError(
                        domain: "EditSpotViewModel",
                        code: 500,
                        userInfo: [NSLocalizedDescriptionKey: "A replacement photo isn’t ready."]
                    )
                }
                return .replacement(assetID)
            }
            return .existing(photo.id)
        }
    }
}

@MainActor
final class EditSpotViewModel: ObservableObject {
    let spot: Spot

    @Published private(set) var photos: [EditSpotDraftPhoto] = []
    @Published private(set) var selectedVibes: [String] = []
    @Published private(set) var selectedLocation: LocationData?
    @Published private(set) var isLoading = true
    @Published private(set) var isSaving = false
    @Published private(set) var isDirty = false
    @Published var errorMessage: String?

    private(set) var initialVibeCount = 0
    private var hasLoaded = false

    init(spot: Spot) {
        self.spot = spot
    }

    func load() async {
        guard !hasLoaded else { return }
        isLoading = true
        errorMessage = nil
        guard let rawID = spot.id, let spotID = UUID(uuidString: rawID) else {
            errorMessage = "This Spot couldn’t be loaded."
            isLoading = false
            return
        }

        do {
            let media = try await SpotSupabaseRepository.fetchEditableSpotImages(id: spotID)
            guard !media.isEmpty else {
                throw NSError(
                    domain: "EditSpotViewModel",
                    code: 404,
                    userInfo: [NSLocalizedDescriptionKey: "This Spot has no editable photos."]
                )
            }
            photos = EditSpotDraftOperations.hydrate(media)
            selectedVibes = spot.displayVibeTags
            initialVibeCount = selectedVibes.count
            if let latitude = spot.latitude, let longitude = spot.longitude {
                selectedLocation = LocationData(
                    coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                    placeName: spot.locationName ?? "",
                    address: nil,
                    isCustomName: false
                )
            }
            hasLoaded = true
        } catch {
            errorMessage = ErrorMessageSanitizer.sanitize(error)
        }
        isLoading = false
    }

    func replacePhoto(id: UUID, with photo: PostComposerPhoto) {
        guard !isSaving, let index = photos.firstIndex(where: { $0.id == id }) else { return }
        photos[index].replacement = photo
        photos[index].approvedAssetID = nil
        isDirty = true
    }

    @discardableResult
    func deletePhoto(id: UUID) -> Bool {
        guard !isSaving else { return false }
        guard photos.count > 1 else {
            errorMessage = "A spot needs at least one photo."
            return false
        }
        guard let index = photos.firstIndex(where: { $0.id == id }) else { return false }
        photos.remove(at: index)
        isDirty = true
        return true
    }

    func movePhoto(id: UUID, to destination: Int) {
        guard !isSaving,
              let source = photos.firstIndex(where: { $0.id == id }),
              photos.indices.contains(destination),
              source != destination else { return }
        photos = EditSpotDraftOperations.reorder(photos, id: id, to: destination)
        isDirty = true
    }

    @discardableResult
    func toggleVibe(_ vibe: String, maximum: Int) -> Bool {
        guard !isSaving else { return false }
        if let index = selectedVibes.firstIndex(of: vibe) {
            selectedVibes.remove(at: index)
            isDirty = true
            return true
        }
        guard selectedVibes.count < maximum else {
            errorMessage = "You can select up to \(maximum) vibes."
            return false
        }
        selectedVibes.append(vibe)
        isDirty = true
        return true
    }

    func selectLocation(_ location: LocationData) {
        guard !isSaving else { return }
        selectedLocation = location
        isDirty = true
    }

    func save(userId: String?) async -> Spot? {
        guard !isSaving, isDirty else { return nil }
        guard let rawSpotID = spot.id, let spotID = UUID(uuidString: rawSpotID),
              let rawUserID = userId, let ownerID = UUID(uuidString: rawUserID) else {
            errorMessage = "Your session has expired. Please sign in again."
            return nil
        }
        guard !photos.isEmpty else {
            errorMessage = "A spot needs at least one photo."
            return nil
        }
        guard !selectedVibes.isEmpty else {
            errorMessage = "Select at least one vibe."
            return nil
        }
        guard let location = selectedLocation else {
            errorMessage = "Select a location."
            return nil
        }

        isSaving = true
        errorMessage = nil
        do {
            for index in photos.indices where photos[index].isReplacement && photos[index].approvedAssetID == nil {
                guard let image = photos[index].replacement?.image,
                      let jpeg = image.spot_jpegDataOpaque(compressionQuality: 0.82) else {
                    throw NSError(
                        domain: "EditSpotViewModel",
                        code: 400,
                        userInfo: [NSLocalizedDescriptionKey: "A replacement photo couldn’t be prepared."]
                    )
                }
                photos[index].approvedAssetID = try await SpotSupabaseRepository.prepareApprovedSpotImage(
                    userId: ownerID,
                    jpeg: jpeg
                )
            }

            let media = try EditSpotDraftOperations.mediaReferences(for: photos)

            try await SpotSupabaseRepository.updateSpotFromEditor(
                id: spotID,
                vibeTags: selectedVibes,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                locationName: location.placeName,
                media: media
            )

            guard let refreshed = try await SpotSupabaseRepository.fetchSpotsByIds([spotID]).first else {
                throw NSError(
                    domain: "EditSpotViewModel",
                    code: 500,
                    userInfo: [NSLocalizedDescriptionKey: "The Spot saved, but couldn’t be refreshed."]
                )
            }
            isSaving = false
            isDirty = false
            return refreshed
        } catch {
            isSaving = false
            errorMessage = ErrorMessageSanitizer.sanitize(error)
            return nil
        }
    }
}

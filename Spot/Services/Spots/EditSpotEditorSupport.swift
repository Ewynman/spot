import Foundation

struct EditableSpotImage: Identifiable, Equatable, Sendable {
    let id: UUID
    let url: String
    let sortIndex: Int
}

struct EditSpotMediaReference: Encodable, Equatable, Sendable {
    let existing_image_id: UUID?
    let media_asset_id: UUID?

    static func existing(_ id: UUID) -> Self {
        Self(existing_image_id: id, media_asset_id: nil)
    }

    static func replacement(_ id: UUID) -> Self {
        Self(existing_image_id: nil, media_asset_id: id)
    }
}

struct EditSpotImageRowDTO: Decodable, Equatable, Sendable {
    let id: UUID
    let storage_path: String?
    let public_url: String?
    let sort_index: Int
    let storage_bucket: String?
}

enum EditSpotEditorSupport {
    static let pendingImagesBucketId = "pending_images"
    static let spotsStorageBucketId = "spots"

    static func storageReference(storagePath: String?, publicURL: String?) -> String {
        let path = storagePath?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return path.isEmpty
            ? (publicURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
            : path
    }

    static func isAbsoluteURL(_ value: String) -> Bool {
        let lower = value.lowercased()
        return lower.hasPrefix("https://") || lower.hasPrefix("http://")
    }

    static func resolutionPlan(
        from rows: [EditSpotImageRowDTO],
        defaultBucket: String = spotsStorageBucketId
    ) -> (paths: [String], buckets: [String?]) {
        let paths = rows.map {
            storageReference(storagePath: $0.storage_path, publicURL: $0.public_url)
        }
        let buckets = rows.enumerated().map { index, row in
            isAbsoluteURL(paths[index]) ? nil : (row.storage_bucket ?? defaultBucket)
        }
        return (paths, buckets)
    }

    static func images(rows: [EditSpotImageRowDTO], urls: [String]) -> [EditableSpotImage] {
        zip(rows, urls).map { row, url in
            EditableSpotImage(id: row.id, url: url, sortIndex: row.sort_index)
        }
    }

    static func fetchEditableSpotImages(
        id: UUID,
        loadRows: (UUID) async throws -> [EditSpotImageRowDTO],
        resolveURLs: ([String], [String?]) async throws -> [String]
    ) async throws -> [EditableSpotImage] {
        let rows = try await loadRows(id)
        let plan = resolutionPlan(from: rows)
        let urls = try await resolveURLs(plan.paths, plan.buckets)
        return images(rows: rows, urls: urls)
    }

    static func validateEditorUpdate(
        media: [EditSpotMediaReference],
        vibeTags: [String],
        latitude: Double,
        longitude: Double,
        locationName: String
    ) throws {
        guard !media.isEmpty else {
            throw NSError(
                domain: "SpotSupabaseRepository",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "A spot needs at least one photo."]
            )
        }
        guard !vibeTags.isEmpty else {
            throw NSError(
                domain: "SpotSupabaseRepository",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "At least one vibe is required."]
            )
        }
        if let coordError = InputValidation.validateCoordinates(latitude: latitude, longitude: longitude) {
            throw NSError(
                domain: "SpotSupabaseRepository",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: coordError]
            )
        }
        if let locationError = InputValidation.validateLocationName(locationName) {
            throw NSError(
                domain: "SpotSupabaseRepository",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: locationError]
            )
        }
    }

    static func moderationRejectionError(reason: String?) -> NSError {
        if reason == "image_policy_rejected" {
            return NSError(
                domain: "SpotImageModeration",
                code: 422,
                userInfo: [NSLocalizedDescriptionKey: "This photo can’t be used. Please choose another."]
            )
        }
        return NSError(
            domain: "SpotImageModeration",
            code: 503,
            userInfo: [NSLocalizedDescriptionKey: "We couldn’t check this photo. Please try again."]
        )
    }

    static func pendingAssetPath(userId: UUID, assetId: UUID) -> String {
        "\(userId.uuidString.lowercased())/\(assetId.uuidString.lowercased()).jpg"
    }

    struct PendingMediaAssetInsert: Encodable, Equatable {
        let id: UUID
        let owner_id: UUID
        let kind: String
        let status: String
        let pending_bucket: String
        let pending_path: String
        let mime_type: String
        let byte_size: Int
        let width: Int?
        let height: Int?
    }

    static func pendingMediaInsert(
        userId: UUID,
        assetId: UUID,
        jpeg: Data,
        pendingBucket: String = pendingImagesBucketId
    ) -> PendingMediaAssetInsert {
        let pixelSize = SpotJPEGImageDimensions.pixelSize(jpeg: jpeg)
        return PendingMediaAssetInsert(
            id: assetId,
            owner_id: userId,
            kind: "spot_image",
            status: "pending",
            pending_bucket: pendingBucket,
            pending_path: pendingAssetPath(userId: userId, assetId: assetId),
            mime_type: "image/jpeg",
            byte_size: jpeg.count,
            width: pixelSize?.width,
            height: pixelSize?.height
        )
    }

    static func prepareApprovedSpotImage(
        userId: UUID,
        jpeg: Data,
        insert: (PendingMediaAssetInsert) async throws -> Void,
        upload: (String, Data) async throws -> Void,
        moderate: (UUID) async throws -> (approved: Bool, reason: String?)
    ) async throws -> UUID {
        let assetId = UUID()
        let payload = pendingMediaInsert(userId: userId, assetId: assetId, jpeg: jpeg)
        try await insert(payload)
        try await upload(payload.pending_path, jpeg)
        let moderation = try await moderate(assetId)
        guard moderation.approved else {
            throw moderationRejectionError(reason: moderation.reason)
        }
        return assetId
    }

    struct EditorRPCParams: Encodable, Equatable {
        let p_spot_id: UUID
        let p_vibe_tag_ids: [UUID]
        let p_latitude: Double
        let p_longitude: Double
        let p_location_name: String
        let p_media_items: [EditSpotMediaReference]
    }

    static func editorRPCParams(
        spotId: UUID,
        vibeIds: [UUID],
        latitude: Double,
        longitude: Double,
        locationName: String,
        media: [EditSpotMediaReference]
    ) -> EditorRPCParams {
        EditorRPCParams(
            p_spot_id: spotId,
            p_vibe_tag_ids: vibeIds,
            p_latitude: latitude,
            p_longitude: longitude,
            p_location_name: locationName.trimmingCharacters(in: .whitespacesAndNewlines),
            p_media_items: media
        )
    }

    static func updateSpotFromEditor(
        id: UUID,
        vibeTags: [String],
        latitude: Double,
        longitude: Double,
        locationName: String,
        media: [EditSpotMediaReference],
        resolveVibeId: (String) async throws -> UUID,
        invokeRPC: (EditorRPCParams) async throws -> Void
    ) async throws {
        try validateEditorUpdate(
            media: media,
            vibeTags: vibeTags,
            latitude: latitude,
            longitude: longitude,
            locationName: locationName
        )
        var vibeIds: [UUID] = []
        vibeIds.reserveCapacity(vibeTags.count)
        for tag in vibeTags {
            vibeIds.append(try await resolveVibeId(tag))
        }
        try await invokeRPC(
            editorRPCParams(
                spotId: id,
                vibeIds: vibeIds,
                latitude: latitude,
                longitude: longitude,
                locationName: locationName,
                media: media
            )
        )
    }
}

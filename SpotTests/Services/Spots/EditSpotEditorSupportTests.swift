import Foundation
import Testing
@testable import Spot

struct EditSpotEditorSupportTests {
    @Test func storageReferencePrefersStoragePathOverPublicURL() {
        #expect(
            EditSpotEditorSupport.storageReference(
                storagePath: " users/a.jpg ",
                publicURL: "https://cdn.example/a.jpg"
            ) == "users/a.jpg"
        )
        #expect(
            EditSpotEditorSupport.storageReference(
                storagePath: " ",
                publicURL: " https://cdn.example/b.jpg "
            ) == "https://cdn.example/b.jpg"
        )
        #expect(EditSpotEditorSupport.storageReference(storagePath: nil, publicURL: nil) == "")
    }

    @Test func resolutionPlanUsesBucketOnlyForRelativePaths() {
        let absoluteID = UUID()
        let relativeID = UUID()
        let rows = [
            EditSpotImageRowDTO(
                id: absoluteID,
                storage_path: nil,
                public_url: "https://cdn.example/a.jpg",
                sort_index: 0,
                storage_bucket: "custom"
            ),
            EditSpotImageRowDTO(
                id: relativeID,
                storage_path: "users/b.jpg",
                public_url: nil,
                sort_index: 1,
                storage_bucket: nil
            )
        ]

        let plan = EditSpotEditorSupport.resolutionPlan(from: rows)

        #expect(plan.paths == ["https://cdn.example/a.jpg", "users/b.jpg"])
        #expect(plan.buckets == [nil, "spots"])
    }

    @Test func fetchEditableSpotImagesResolvesThroughInjectedDependencies() async throws {
        let id = UUID()
        let rowID = UUID()
        let images = try await EditSpotEditorSupport.fetchEditableSpotImages(
            id: id,
            loadRows: { requested in
                #expect(requested == id)
                return [
                    EditSpotImageRowDTO(
                        id: rowID,
                        storage_path: "users/a.jpg",
                        public_url: nil,
                        sort_index: 3,
                        storage_bucket: "spots"
                    )
                ]
            },
            resolveURLs: { paths, buckets in
                #expect(paths == ["users/a.jpg"])
                #expect(buckets == ["spots"])
                return ["https://signed.example/a.jpg"]
            }
        )

        #expect(images == [EditableSpotImage(id: rowID, url: "https://signed.example/a.jpg", sortIndex: 3)])
    }

    @Test func validateEditorUpdateRejectsEmptyMediaVibesAndInvalidInputs() throws {
        let media = [EditSpotMediaReference.existing(UUID())]
        #expect(throws: NSError.self) {
            try EditSpotEditorSupport.validateEditorUpdate(
                media: [],
                vibeTags: ["Chill"],
                latitude: 40,
                longitude: -74,
                locationName: "NYC"
            )
        }
        #expect(throws: NSError.self) {
            try EditSpotEditorSupport.validateEditorUpdate(
                media: media,
                vibeTags: [],
                latitude: 40,
                longitude: -74,
                locationName: "NYC"
            )
        }
        #expect(throws: NSError.self) {
            try EditSpotEditorSupport.validateEditorUpdate(
                media: media,
                vibeTags: ["Chill"],
                latitude: 120,
                longitude: -74,
                locationName: "NYC"
            )
        }
        #expect(throws: NSError.self) {
            try EditSpotEditorSupport.validateEditorUpdate(
                media: media,
                vibeTags: ["Chill"],
                latitude: 40,
                longitude: -74,
                locationName: "   "
            )
        }
        try EditSpotEditorSupport.validateEditorUpdate(
            media: media,
            vibeTags: ["Chill"],
            latitude: 40,
            longitude: -74,
            locationName: " NYC "
        )
    }

    @Test func moderationRejectionMapsPolicyAndUnavailableReasons() {
        let policy = EditSpotEditorSupport.moderationRejectionError(reason: "image_policy_rejected")
        #expect(policy.domain == "SpotImageModeration")
        #expect(policy.code == 422)

        let unavailable = EditSpotEditorSupport.moderationRejectionError(reason: "moderation_unavailable")
        #expect(unavailable.code == 503)
    }

    @Test func pendingMediaInsertBuildsLowercasedPathAndByteSize() {
        let userId = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let assetId = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        let jpeg = Data([0xFF, 0xD8, 0xFF, 0xD9])

        let insert = EditSpotEditorSupport.pendingMediaInsert(userId: userId, assetId: assetId, jpeg: jpeg)

        #expect(insert.owner_id == userId)
        #expect(insert.id == assetId)
        #expect(insert.pending_path == "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa/bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb.jpg")
        #expect(insert.byte_size == jpeg.count)
        #expect(insert.kind == "spot_image")
        #expect(insert.status == "pending")
        #expect(insert.mime_type == "image/jpeg")
    }

    @Test func prepareApprovedSpotImageRequiresModerationApproval() async throws {
        let userId = UUID()
        let jpeg = Data([0xFF, 0xD8, 0xFF, 0xD9])
        var insertedPath: String?

        let approved = try await EditSpotEditorSupport.prepareApprovedSpotImage(
            userId: userId,
            jpeg: jpeg,
            insert: { payload in insertedPath = payload.pending_path },
            upload: { path, data in
                #expect(path == insertedPath)
                #expect(data == jpeg)
            },
            moderate: { _ in (true, "ok") }
        )
        #expect(insertedPath?.contains(userId.uuidString.lowercased()) == true)
        #expect(approved.uuidString.isEmpty == false)

        await #expect(throws: NSError.self) {
            try await EditSpotEditorSupport.prepareApprovedSpotImage(
                userId: userId,
                jpeg: jpeg,
                insert: { _ in },
                upload: { _, _ in },
                moderate: { _ in (false, "image_policy_rejected") }
            )
        }
    }

    @Test func updateSpotFromEditorResolvesVibesAndInvokesRPC() async throws {
        let spotId = UUID()
        let vibeId = UUID()
        let media = [EditSpotMediaReference.existing(UUID())]
        var resolvedTags: [String] = []
        var rpcParams: EditSpotEditorSupport.EditorRPCParams?

        try await EditSpotEditorSupport.updateSpotFromEditor(
            id: spotId,
            vibeTags: ["Chill", "Scenic"],
            latitude: 40.7,
            longitude: -74.0,
            locationName: "  NYC  ",
            media: media,
            resolveVibeId: { tag in
                resolvedTags.append(tag)
                return vibeId
            },
            invokeRPC: { params in rpcParams = params }
        )

        #expect(resolvedTags == ["Chill", "Scenic"])
        #expect(rpcParams?.p_spot_id == spotId)
        #expect(rpcParams?.p_vibe_tag_ids == [vibeId, vibeId])
        #expect(rpcParams?.p_location_name == "NYC")
        #expect(rpcParams?.p_media_items == media)
    }

    @Test func mediaReferenceFactoriesEncodeExistingAndReplacement() {
        let existingID = UUID()
        let assetID = UUID()
        #expect(EditSpotMediaReference.existing(existingID) == EditSpotMediaReference(existing_image_id: existingID, media_asset_id: nil))
        #expect(EditSpotMediaReference.replacement(assetID) == EditSpotMediaReference(existing_image_id: nil, media_asset_id: assetID))
    }
}

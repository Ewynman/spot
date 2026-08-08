import Testing
import UIKit
@testable import Spot

struct PostComposerPhotoTests {
    @Test func reorderingPreservesStableIdentityAndMakesCover() {
        let first = PostComposerPhoto(image: testImage(.red))
        let second = PostComposerPhoto(image: testImage(.green))
        let third = PostComposerPhoto(image: testImage(.blue))

        let reordered = PostComposerPhotoOperations.reordered(
            [first, second, third],
            from: 2,
            to: 0
        )

        #expect(reordered.map(\.id) == [third.id, first.id, second.id])
        #expect(PostComposerPhotoOperations.makingCover(reordered, id: second.id).first?.id == second.id)
    }

    @Test func invalidReorderLeavesPhotosUnchanged() {
        let photos = [
            PostComposerPhoto(image: testImage(.red)),
            PostComposerPhoto(image: testImage(.blue))
        ]

        #expect(PostComposerPhotoOperations.reordered(photos, from: -1, to: 0).map(\.id) == photos.map(\.id))
        #expect(PostComposerPhotoOperations.reordered(photos, from: 0, to: 8).map(\.id) == photos.map(\.id))
    }

    @Test func editNormalizationClampsAllValues() {
        var edits = PostComposerPhotoEdits(
            rotationQuarterTurns: -5,
            straightenDegrees: 99,
            flipHorizontal: true,
            flipVertical: false,
            crop: PostComposerPhotoCrop(
                normalizedX: -1,
                normalizedY: 2,
                normalizedWidth: 4,
                normalizedHeight: -2,
                aspectRatio: "1:1"
            ),
            adjustments: PostComposerPhotoAdjustments(
                brightness: 4,
                contrast: -4,
                saturation: 2,
                warmth: -2
            )
        )

        edits.normalize()

        #expect(edits.rotationQuarterTurns == 3)
        #expect(edits.straightenDegrees == 15)
        #expect(edits.crop.normalizedX == 0)
        #expect(edits.crop.normalizedY == 0.99)
        #expect(edits.crop.normalizedWidth == 1)
        #expect(abs(edits.crop.normalizedHeight - 0.01) < 0.0001)
        #expect(edits.adjustments.brightness == 1)
        #expect(edits.adjustments.contrast == -1)
        #expect(edits.adjustments.saturation == 1)
        #expect(edits.adjustments.warmth == -1)
    }

    @Test func resetEditsRestoresNeutralState() {
        var photo = PostComposerPhoto(image: testImage(.red))
        photo.edits.rotationQuarterTurns = 1
        photo.edits.adjustments.brightness = 0.5
        #expect(!photo.edits.isNeutral)

        photo.edits = .neutral

        #expect(photo.edits.isNeutral)
        #expect(photo.edits.crop == .fullImage)
    }

    @Test func processorRejectsNonImageAndNormalizesCameraOrientation() throws {
        #expect(throws: PostPhotoImportError.self) {
            _ = try PostPhotoProcessor.importImage(
                data: Data("not an image".utf8),
                source: .gallery
            )
        }

        let source = testImage(.red, size: CGSize(width: 1_000, height: 500))
        let imported = try PostPhotoProcessor.importCameraImage(source)
        #expect(imported.image.imageOrientation == .up)
        #expect(imported.source == .camera)
        #expect(imported.pixelWidth == 1_000)
        #expect(imported.pixelHeight == 500)
    }

    @Test func processingAppliesRotationCropAndAdjustments() throws {
        let source = testImage(.orange, size: CGSize(width: 400, height: 200))
        var edits = PostComposerPhotoEdits.neutral
        edits.rotationQuarterTurns = 1
        edits.crop = PostComposerPhotoCrop(
            normalizedX: 0,
            normalizedY: 0.25,
            normalizedWidth: 1,
            normalizedHeight: 0.5,
            aspectRatio: "1:1"
        )
        edits.adjustments.contrast = 0.2

        let rendered = try PostPhotoProcessor.render(original: source, edits: edits)

        #expect(rendered.imageOrientation == .up)
        #expect(rendered.size.width > 0)
        #expect(rendered.size.height > 0)
        #expect(rendered !== source)
    }

    @Test func editorPreviewUsesSmallerInteractiveRenderBudget() throws {
        let source = testImage(.purple, size: CGSize(width: 1_800, height: 1_200))
        var edits = PostComposerPhotoEdits.neutral
        edits.crop = PostComposerPhotoCrop(
            normalizedX: 0.1,
            normalizedY: 0.1,
            normalizedWidth: 0.8,
            normalizedHeight: 0.8,
            aspectRatio: "Free"
        )

        let preview = try PostPhotoProcessor.renderEditorPreview(original: source, edits: edits)

        #expect(max(preview.size.width, preview.size.height) <= PostPhotoProcessor.editorPreviewMaxPixelSize)
        #expect(preview.size.width > 0)
        #expect(preview.size.height > 0)
    }

    @Test func legacyDraftDecodesWithoutPhotoMetadata() throws {
        let json = """
        {
          "id": "legacy",
          "step": 1,
          "status": "autosaved",
          "vibeTags": [],
          "isCustomName": false,
          "imageFileNames": ["draft_legacy_image_0.jpg"],
          "updatedAt": 0
        }
        """

        let draft = try JSONDecoder().decode(PostComposerDraft.self, from: Data(json.utf8))

        #expect(draft.id == "legacy")
        #expect(draft.schemaVersion == nil)
        #expect(draft.photoRecords == nil)
        #expect(draft.imageFileNames == ["draft_legacy_image_0.jpg"])
    }

    @Test func draftPhotoMetadataRoundTripsStableIdentityAndEdits() throws {
        var edits = PostComposerPhotoEdits.neutral
        edits.rotationQuarterTurns = 3
        edits.flipHorizontal = true
        edits.adjustments.warmth = 0.4
        let record = PostComposerDraftPhoto(
            id: UUID(),
            originalFileName: "original.jpg",
            previewFileName: "preview.jpg",
            source: .camera,
            edits: edits,
            processingState: .ready,
            processingError: nil,
            createdAt: Date(timeIntervalSinceReferenceDate: 1_000)
        )

        let decoded = try JSONDecoder().decode(
            PostComposerDraftPhoto.self,
            from: JSONEncoder().encode(record)
        )

        #expect(decoded == record)
        #expect(decoded.edits.rotationQuarterTurns == 3)
        #expect(decoded.source == .camera)
    }

    private func testImage(
        _ color: UIColor,
        size: CGSize = CGSize(width: 40, height: 30)
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}

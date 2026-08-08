import XCTest
import UIKit
@testable import Spot

final class EditSpotViewModelTests: XCTestCase {
    func testHydrateKeepsAllFiveImagesInStoredOrder() {
        let ids = (0..<5).map { _ in UUID() }
        let media = [
            EditableSpotImage(id: ids[4], url: "E", sortIndex: 4),
            EditableSpotImage(id: ids[1], url: "B", sortIndex: 1),
            EditableSpotImage(id: ids[3], url: "D", sortIndex: 3),
            EditableSpotImage(id: ids[0], url: "A", sortIndex: 0),
            EditableSpotImage(id: ids[2], url: "C", sortIndex: 2)
        ]

        let draft = EditSpotDraftOperations.hydrate(media)

        XCTAssertEqual(draft.count, 5)
        XCTAssertEqual(draft.map(\.remoteURL), ["A", "B", "C", "D", "E"])
        XCTAssertEqual(draft.map(\.id), ids)
    }

    func testFinalScenarioPersistsReorderReplacementAndDeletion() throws {
        let ids = (0..<5).map { _ in UUID() }
        let replacementAssetID = UUID()
        var draft = EditSpotDraftOperations.hydrate(
            zip(ids, ["A", "B", "C", "D", "E"]).enumerated().map { index, pair in
                EditableSpotImage(id: pair.0, url: pair.1, sortIndex: index)
            }
        )

        draft = EditSpotDraftOperations.reorder(draft, id: ids[4], to: 0)
        let bIndex = try XCTUnwrap(draft.firstIndex(where: { $0.id == ids[1] }))
        draft[bIndex].replacement = PostComposerPhoto(image: UIImage())
        draft[bIndex].approvedAssetID = replacementAssetID
        draft.removeAll { $0.id == ids[2] }

        let references = try EditSpotDraftOperations.mediaReferences(for: draft)

        XCTAssertEqual(
            references,
            [
                .existing(ids[4]),
                .existing(ids[0]),
                .replacement(replacementAssetID),
                .existing(ids[3])
            ]
        )
    }

    func testReplacementMustBeModeratedBeforeFinalMutation() {
        let imageID = UUID()
        let draft = [
            EditSpotDraftPhoto(
                id: imageID,
                remoteURL: "B",
                replacement: PostComposerPhoto(image: UIImage()),
                approvedAssetID: nil
            )
        ]

        XCTAssertThrowsError(try EditSpotDraftOperations.mediaReferences(for: draft))
    }
}

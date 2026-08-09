import CoreLocation
import UIKit
import XCTest
@testable import Spot

@MainActor
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

    func testReorderNoopsForUnknownOrSameIndex() {
        let id = UUID()
        let draft = [EditSpotDraftPhoto(id: id, remoteURL: "A", replacement: nil, approvedAssetID: nil)]
        XCTAssertEqual(EditSpotDraftOperations.reorder(draft, id: UUID(), to: 0).map(\.id), draft.map(\.id))
        XCTAssertEqual(EditSpotDraftOperations.reorder(draft, id: id, to: 0).map(\.id), draft.map(\.id))
        XCTAssertEqual(EditSpotDraftOperations.reorder(draft, id: id, to: 5).map(\.id), draft.map(\.id))
    }

    func testLoadHydratesPhotosVibesAndLocation() async {
        let spotID = UUID()
        let userID = UUID()
        let photoA = UUID()
        let photoB = UUID()
        let store = FakeEditSpotStore(
            images: [
                EditableSpotImage(id: photoB, url: "B", sortIndex: 1),
                EditableSpotImage(id: photoA, url: "A", sortIndex: 0)
            ]
        )
        let spot = SpotTestHelpers.makeSpot(
            id: spotID.uuidString,
            userId: userID.uuidString,
            vibeTag: "Chill",
            vibeTags: ["Chill", "Scenic"],
            latitude: 40.7,
            longitude: -74.0,
            locationName: "NYC"
        )
        let vm = EditSpotViewModel(spot: spot, store: store)

        await vm.load()

        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage)
        XCTAssertEqual(vm.photos.map(\.remoteURL), ["A", "B"])
        XCTAssertEqual(vm.selectedVibes, ["Chill", "Scenic"])
        XCTAssertEqual(vm.initialVibeCount, 2)
        XCTAssertEqual(vm.selectedLocation?.placeName, "NYC")
        XCTAssertFalse(vm.isDirty)
    }

    func testLoadFailsForInvalidSpotIDAndEmptyMedia() async {
        let emptyStore = FakeEditSpotStore(images: [])
        let invalid = EditSpotViewModel(
            spot: SpotTestHelpers.makeSpot(id: "not-a-uuid"),
            store: emptyStore
        )
        await invalid.load()
        XCTAssertEqual(invalid.errorMessage, "This Spot couldn’t be loaded.")
        XCTAssertFalse(invalid.isLoading)

        let spotID = UUID()
        let empty = EditSpotViewModel(
            spot: SpotTestHelpers.makeSpot(id: spotID.uuidString, latitude: 1, longitude: 2, locationName: "X"),
            store: emptyStore
        )
        await empty.load()
        XCTAssertNotNil(empty.errorMessage)
        XCTAssertTrue(empty.photos.isEmpty)
    }

    func testDraftMutationsAndGuards() async throws {
        let spotID = UUID()
        let userID = UUID()
        let ids = (0..<3).map { _ in UUID() }
        let store = FakeEditSpotStore(
            images: ids.enumerated().map { EditableSpotImage(id: $1, url: "\($0)", sortIndex: $0) }
        )
        let vm = EditSpotViewModel(
            spot: SpotTestHelpers.makeSpot(
                id: spotID.uuidString,
                userId: userID.uuidString,
                vibeTags: ["Chill"],
                latitude: 40,
                longitude: -70,
                locationName: "Place"
            ),
            store: store
        )
        await vm.load()

        vm.movePhoto(id: ids[2], to: 0)
        XCTAssertEqual(vm.photos.map(\.id), [ids[2], ids[0], ids[1]])
        XCTAssertTrue(vm.isDirty)

        let replacement = PostComposerPhoto(image: solidImage())
        vm.replacePhoto(id: ids[0], with: replacement)
        XCTAssertTrue(vm.photos.first(where: { $0.id == ids[0] })?.isReplacement == true)

        XCTAssertTrue(vm.deletePhoto(id: ids[1]))
        XCTAssertEqual(vm.photos.count, 2)
        let remainingSecondary = try XCTUnwrap(vm.photos.first(where: { $0.id != ids[2] })?.id)
        XCTAssertTrue(vm.deletePhoto(id: remainingSecondary))
        XCTAssertEqual(vm.photos.count, 1)
        XCTAssertFalse(vm.deletePhoto(id: vm.photos[0].id))
        XCTAssertEqual(vm.errorMessage, "A spot needs at least one photo.")

        XCTAssertTrue(vm.toggleVibe("Scenic", maximum: 2))
        XCTAssertEqual(vm.selectedVibes, ["Chill", "Scenic"])
        XCTAssertFalse(vm.toggleVibe("Quiet", maximum: 2))
        XCTAssertEqual(vm.errorMessage, "You can select up to 2 vibes.")
        XCTAssertTrue(vm.toggleVibe("Scenic", maximum: 2))
        XCTAssertEqual(vm.selectedVibes, ["Chill"])

        let location = LocationData(
            coordinate: CLLocationCoordinate2D(latitude: 41, longitude: -71),
            placeName: "Boston",
            address: nil,
            isCustomName: false
        )
        vm.selectLocation(location)
        XCTAssertEqual(vm.selectedLocation?.placeName, "Boston")
    }

    func testSaveHappyPathPreparesReplacementAndClearsDirty() async {
        let spotID = UUID()
        let userID = UUID()
        let photoID = UUID()
        let assetID = UUID()
        let refreshed = SpotTestHelpers.makeSpot(
            id: spotID.uuidString,
            userId: userID.uuidString,
            vibeTag: "Updated",
            latitude: 40.7,
            longitude: -74.0,
            locationName: "NYC"
        )
        let store = FakeEditSpotStore(
            images: [EditableSpotImage(id: photoID, url: "A", sortIndex: 0)],
            approvedAssetID: assetID,
            refreshedSpots: [refreshed]
        )
        let vm = EditSpotViewModel(
            spot: SpotTestHelpers.makeSpot(
                id: spotID.uuidString,
                userId: userID.uuidString,
                vibeTags: ["Chill"],
                latitude: 40.7,
                longitude: -74.0,
                locationName: "NYC"
            ),
            store: store
        )
        await vm.load()
        vm.replacePhoto(id: photoID, with: PostComposerPhoto(image: solidImage()))
        vm.toggleVibe("Scenic", maximum: 3)

        let saved = await vm.save(userId: userID.uuidString)

        XCTAssertEqual(saved?.id, spotID.uuidString)
        XCTAssertFalse(vm.isDirty)
        XCTAssertFalse(vm.isSaving)
        XCTAssertEqual(store.prepareCalls.count, 1)
        XCTAssertEqual(store.updateCalls.count, 1)
        XCTAssertEqual(store.updateCalls.first?.media, [.replacement(assetID)])
        XCTAssertEqual(store.updateCalls.first?.vibeTags, ["Chill", "Scenic"])
    }

    func testSaveGuardsRequireAuthVibesLocationAndDirtyState() async {
        let spotID = UUID()
        let userID = UUID()
        let store = FakeEditSpotStore(
            images: [EditableSpotImage(id: UUID(), url: "A", sortIndex: 0)]
        )
        let vm = EditSpotViewModel(
            spot: SpotTestHelpers.makeSpot(
                id: spotID.uuidString,
                userId: userID.uuidString,
                vibeTags: ["Chill"],
                latitude: 40.7,
                longitude: -74.0,
                locationName: "NYC"
            ),
            store: store
        )
        await vm.load()

        let cleanSave = await vm.save(userId: userID.uuidString)
        XCTAssertNil(cleanSave)

        vm.selectLocation(
            LocationData(
                coordinate: CLLocationCoordinate2D(latitude: 41, longitude: -71),
                placeName: "Boston",
                address: nil,
                isCustomName: false
            )
        )
        let authSave = await vm.save(userId: "bad-user")
        XCTAssertNil(authSave)
        XCTAssertEqual(vm.errorMessage, "Your session has expired. Please sign in again.")

        _ = vm.toggleVibe("Chill", maximum: 3)
        XCTAssertTrue(vm.selectedVibes.isEmpty)
        let vibeSave = await vm.save(userId: userID.uuidString)
        XCTAssertNil(vibeSave)
        XCTAssertEqual(vm.errorMessage, "Select at least one vibe.")
    }

    func testSaveSurfacesStoreFailures() async {
        let spotID = UUID()
        let userID = UUID()
        let store = FakeEditSpotStore(
            images: [EditableSpotImage(id: UUID(), url: "A", sortIndex: 0)],
            updateError: NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "boom"])
        )
        let vm = EditSpotViewModel(
            spot: SpotTestHelpers.makeSpot(
                id: spotID.uuidString,
                userId: userID.uuidString,
                vibeTags: ["Chill"],
                latitude: 40.7,
                longitude: -74.0,
                locationName: "NYC"
            ),
            store: store
        )
        await vm.load()
        vm.toggleVibe("Scenic", maximum: 3)

        let saved = await vm.save(userId: userID.uuidString)

        XCTAssertNil(saved)
        XCTAssertFalse(vm.isSaving)
        XCTAssertNotNil(vm.errorMessage)
    }

    private func solidImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8))
        return renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
    }
}

private final class FakeEditSpotStore: EditSpotPersisting, @unchecked Sendable {
    var images: [EditableSpotImage]
    var approvedAssetID: UUID
    var refreshedSpots: [Spot]
    var updateError: Error?
    private(set) var prepareCalls: [Data] = []
    private(set) var updateCalls: [(vibeTags: [String], media: [EditSpotMediaReference])] = []

    init(
        images: [EditableSpotImage],
        approvedAssetID: UUID = UUID(),
        refreshedSpots: [Spot] = [],
        updateError: Error? = nil
    ) {
        self.images = images
        self.approvedAssetID = approvedAssetID
        self.refreshedSpots = refreshedSpots
        self.updateError = updateError
    }

    func fetchEditableSpotImages(id: UUID) async throws -> [EditableSpotImage] {
        images
    }

    func prepareApprovedSpotImage(userId: UUID, jpeg: Data) async throws -> UUID {
        prepareCalls.append(jpeg)
        return approvedAssetID
    }

    func updateSpotFromEditor(
        id: UUID,
        vibeTags: [String],
        latitude: Double,
        longitude: Double,
        locationName: String,
        media: [EditSpotMediaReference]
    ) async throws {
        if let updateError { throw updateError }
        updateCalls.append((vibeTags, media))
    }

    func fetchSpotsByIds(_ ids: [UUID]) async throws -> [Spot] {
        if refreshedSpots.isEmpty {
            return ids.map { SpotTestHelpers.makeSpot(id: $0.uuidString) }
        }
        return refreshedSpots
    }
}

import Foundation
import Testing

struct SpotSaveFlowGuardTests {
    private static let repoRoot: URL = {
        var url = URL(fileURLWithPath: #filePath)
        while !url.pathComponents.isEmpty {
            if FileManager.default.fileExists(
                atPath: url.appendingPathComponent("Spot", isDirectory: true).path
            ) {
                return url
            }
            url.deleteLastPathComponent()
        }
        fatalError("Could not locate repo root")
    }()

    @Test func collectionManagerNeverInvokesCanonicalSave() throws {
        let source = try contents("Spot/Views/Components/CollectionManagerSheet.swift")
        #expect(!source.contains("bookmarkSpot("))
        #expect(!source.contains("setBookmark("))
        #expect(source.contains("addSpot(spotId, to: collectionId)"))
    }

    @Test func canonicalWritesAreConflictSafe() throws {
        let saveService = try contents("Spot/Services/Profile/UserSpotService.swift")
        let collectionService = try contents("Spot/Services/Social/BookmarksCollectionsService.swift")
        #expect(saveService.contains("onConflict: \"user_id,spot_id\""))
        #expect(collectionService.contains("onConflict: \"collection_id,spot_id\""))
    }

    @Test func databaseEnforcesCanonicalUniqueness() throws {
        let migration = try contents("supabase/migrations/20260808220600_canonical_spot_saves_v1.sql")
        #expect(migration.contains("spot_bookmarks_user_spot_uidx"))
        #expect(migration.contains("(user_id, spot_id)"))
        #expect(migration.contains("bookmark_collection_spots_collection_spot_uidx"))
        #expect(migration.contains("(collection_id, spot_id)"))
    }

    @Test func bookmarkDoesNotAutomaticallyOpenCollections() throws {
        let source = try contents("Spot/Views/Components/SpotCard.swift")
        #expect(!source.contains("if authVM.isPro && !isSaved"))
        #expect(source.contains("showToast(target ? \"Saved\""))
        #expect(source.contains("actionTitle: toastShowsCollectionAction ? \"Add to collection\""))
    }

    @Test func obsoleteCollectionChoiceUIIsRemoved() throws {
        let source = try contents("Spot/Views/Components/SpotCard.swift")
        #expect(!source.contains("Text(\"Just Save\")"))
        #expect(!source.contains("NewCollectionTile"))
        #expect(source.contains("Text(\"Manage collections\")"))
    }

    private static func contents(_ relativePath: String) throws -> String {
        try String(
            contentsOf: repoRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }
}

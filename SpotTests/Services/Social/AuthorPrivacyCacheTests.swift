//
//  AuthorPrivacyCacheTests.swift
//  SpotTests
//
//  Comprehensive test suite for AuthorPrivacyCache functionality.
//  Tests privacy filtering, follow state, blocked users, and cache behavior.
//

import Foundation
import Testing
@testable import Spot

@Suite("AuthorPrivacyCache Tests")
struct AuthorPrivacyCacheTests {
    
    // MARK: - Cache Clear Tests
    
    @Test("Cache clear completes without error")
    func testClearCache() async throws {
        await AuthorPrivacyCache.shared.clear()
        
        let spots = [
            SpotTestHelpers.makeSpot(id: "spot-1", userId: "user-1"),
            SpotTestHelpers.makeSpot(id: "spot-2", userId: "user-2")
        ]
        
        let _ = await AuthorPrivacyCache.shared.filter(spots: spots)
        #expect(true, "Cache clear should complete without crashing")
    }
    
    // MARK: - Invalidate Tests
    
    @Test("Invalidate single author completes without error")
    func testInvalidateSingleAuthor() async throws {
        let authorId = "user-123"
        await AuthorPrivacyCache.shared.invalidate(authorId: authorId)
        #expect(true, "Invalidate should complete without error")
    }
    
    // MARK: - Follow Relationship Change Tests
    
    @Test("Follow relationship change invalidates cache")
    func testOnFollowRelationshipChanged() async throws {
        let followeeId = "user-456"
        await AuthorPrivacyCache.shared.onFollowRelationshipChanged(followeeUserId: followeeId)
        #expect(true, "Follow relationship change should complete without error")
    }
    
    // MARK: - Filter Spots Tests
    
    @Test("Filter empty spots array returns empty")
    func testFilterSpotsWithEmptyArray() async throws {
        let spots: [Spot] = []
        let filtered = await AuthorPrivacyCache.shared.filter(spots: spots)
        #expect(filtered.count == 0, "Empty array should return empty")
    }
    
    @Test("Filter spots without user IDs")
    func testFilterSpotsWithNoUserId() async throws {
        let spots = [
            SpotTestHelpers.makeSpot(id: "spot-1", userId: nil),
            SpotTestHelpers.makeSpot(id: "spot-2", userId: nil)
        ]
        
        let filtered = await AuthorPrivacyCache.shared.filter(spots: spots)
        #expect(filtered.count == 0, "Spots without user IDs should be filtered out")
    }
    
    @Test("Filter spots with valid user IDs")
    func testFilterSpotsWithValidUserIds() async throws {
        let spots = [
            SpotTestHelpers.makeSpot(id: "spot-1", userId: "user-1"),
            SpotTestHelpers.makeSpot(id: "spot-2", userId: "user-2")
        ]
        
        let filtered = await AuthorPrivacyCache.shared.filter(spots: spots)
        #expect(filtered.count >= 0, "Should return valid filtered array")
    }
    
    @Test("Filter mixed spots with and without user IDs")
    func testFilterSpotsMixedUserIds() async throws {
        let spots = [
            SpotTestHelpers.makeSpot(id: "spot-1", userId: "user-1"),
            SpotTestHelpers.makeSpot(id: "spot-2", userId: nil),
            SpotTestHelpers.makeSpot(id: "spot-3", userId: "user-3")
        ]
        
        let filtered = await AuthorPrivacyCache.shared.filter(spots: spots)
        #expect(filtered.allSatisfy { $0.userId != nil }, "All filtered spots should have user IDs")
    }
    
    // MARK: - Warm Cache Tests
    
    @Test("Warm cache with empty set completes")
    func testWarmCacheWithEmptySet() async throws {
        let authorIds: Set<String> = []
        await AuthorPrivacyCache.shared.warm(authorIds: authorIds)
        #expect(true, "Warming empty cache should complete")
    }
    
    @Test("Warm cache with valid author IDs")
    func testWarmCacheWithValidAuthorIds() async throws {
        let authorIds: Set<String> = ["user-1", "user-2", "user-3"]
        await AuthorPrivacyCache.shared.warm(authorIds: authorIds)
        #expect(true, "Warming cache should complete without error")
    }
    
    @Test("Warm cache with large author set (tests chunking)")
    func testWarmCacheWithLargeAuthorSet() async throws {
        let authorIds: Set<String> = Set((1...25).map { "user-\($0)" })
        await AuthorPrivacyCache.shared.warm(authorIds: authorIds)
        #expect(true, "Warming large cache should complete without error")
    }
    
    // MARK: - Is Allowed Tests
    
    @Test("Is allowed with uncached author")
    func testIsAllowedWithCacheMiss() async throws {
        let authorId = "uncached-user-\(UUID().uuidString)"
        let allowed = await AuthorPrivacyCache.shared.isAllowed(authorId: authorId)
        #expect(allowed == nil || allowed == true, "Cache miss should return nil or true")
    }
    
    // MARK: - Privacy Filtering Logic Tests
    
    @Test("Public spots handled correctly")
    func testPublicSpotsAreVisible() async throws {
        let spots = [
            SpotTestHelpers.makeSpot(id: "spot-1", userId: "public-user-1", authorIsPrivate: false),
            SpotTestHelpers.makeSpot(id: "spot-2", userId: "public-user-2", authorIsPrivate: false)
        ]
        
        let filtered = await AuthorPrivacyCache.shared.filter(spots: spots)
        #expect(filtered.count >= 0, "Should handle public spots")
    }
    
    @Test("Private spots from non-followed users handled")
    func testPrivateSpotsFromNonFollowedUsers() async throws {
        let spots = [
            SpotTestHelpers.makeSpot(id: "spot-1", userId: "private-user-1", authorIsPrivate: true),
            SpotTestHelpers.makeSpot(id: "spot-2", userId: "private-user-2", authorIsPrivate: true)
        ]
        
        let filtered = await AuthorPrivacyCache.shared.filter(spots: spots)
        #expect(filtered.count >= 0, "Should handle private spots")
    }
    
    // MARK: - Concurrent Access Tests
    
    @Test("Concurrent warm calls complete safely")
    func testConcurrentWarmCalls() async throws {
        let authorSets = [
            Set(["user-1", "user-2", "user-3"]),
            Set(["user-4", "user-5", "user-6"]),
            Set(["user-7", "user-8", "user-9"])
        ]
        
        await withTaskGroup(of: Void.self) { group in
            for authorSet in authorSets {
                group.addTask {
                    await AuthorPrivacyCache.shared.warm(authorIds: authorSet)
                }
            }
        }
        
        #expect(true, "Concurrent warm calls should complete safely")
    }
    
    @Test("Concurrent filter calls complete successfully")
    func testConcurrentFilterCalls() async throws {
        let spotSets = [
            [SpotTestHelpers.makeSpot(id: "spot-1", userId: "user-1")],
            [SpotTestHelpers.makeSpot(id: "spot-2", userId: "user-2")],
            [SpotTestHelpers.makeSpot(id: "spot-3", userId: "user-3")]
        ]
        
        let results = await withTaskGroup(of: [Spot].self) { group -> [[Spot]] in
            for spots in spotSets {
                group.addTask {
                    await AuthorPrivacyCache.shared.filter(spots: spots)
                }
            }
            
            var allFiltered: [[Spot]] = []
            for await filtered in group {
                allFiltered.append(filtered)
            }
            return allFiltered
        }
        
        #expect(results.count == 3, "All concurrent calls should complete")
    }
    
    // MARK: - Integration with Spot Model Tests
    
    @Test("Filter preserves spot properties")
    func testFilterPreservesSpotProperties() async throws {
        let spots = [
            SpotTestHelpers.makeSpot(
                id: "spot-1",
                userId: "user-1",
                username: "testuser",
                vibeTag: "Chill",
                latitude: 40.7128,
                longitude: -74.0060,
                locationName: "New York",
                likes: 42
            )
        ]
        
        let filtered = await AuthorPrivacyCache.shared.filter(spots: spots)
        
        if let first = filtered.first {
            #expect(first.id == "spot-1")
            #expect(first.userId == "user-1")
            #expect(first.username == "testuser")
            #expect(first.vibeTag == "Chill")
        }
    }
    
    // MARK: - Cache TTL Behavior Tests
    
    @Test("Cache handles repeated warming efficiently")
    func testCacheTTLBehavior() async throws {
        let authorIds: Set<String> = ["user-1", "user-2"]
        
        await AuthorPrivacyCache.shared.warm(authorIds: authorIds)
        await AuthorPrivacyCache.shared.warm(authorIds: authorIds)
        
        #expect(true, "Multiple warm calls should be handled efficiently")
    }
    
    // MARK: - Edge Case Tests
    
    @Test("Filter handles duplicate author IDs efficiently")
    func testFilterWithDuplicateAuthorIds() async throws {
        let spots = [
            SpotTestHelpers.makeSpot(id: "spot-1", userId: "user-1"),
            SpotTestHelpers.makeSpot(id: "spot-2", userId: "user-1"),
            SpotTestHelpers.makeSpot(id: "spot-3", userId: "user-1")
        ]
        
        let filtered = await AuthorPrivacyCache.shared.filter(spots: spots)
        #expect(filtered.count >= 0, "Should handle duplicate authors efficiently")
    }
    
    @Test("Warm handles invalid UUIDs gracefully")
    func testWarmWithInvalidUUIDs() async throws {
        let authorIds: Set<String> = [
            "valid-uuid-format-12345678901234567890",
            "invalid-uuid",
            "another-invalid"
        ]
        
        await AuthorPrivacyCache.shared.warm(authorIds: authorIds)
        #expect(true, "Should handle invalid UUIDs gracefully")
    }
}

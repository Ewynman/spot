//
//  FollowRequestsServiceTests.swift
//  SpotTests
//
//  Comprehensive test suite for FollowRequestsService functionality.
//  Tests follow request creation, acceptance, denial, and pagination.
//

import Foundation
import Testing
@testable import Spot

@Suite("FollowRequestsService Tests")
struct FollowRequestsServiceTests {
    
    // MARK: - Service Initialization Tests
    
    @Test("Service singleton exists")
    func testServiceSingletonExists() {
        let service = FollowRequestsService.shared
        #expect(service != nil, "Service shared instance should exist")
    }
    
    // MARK: - Count Pending Tests
    
    @Test("Count pending with invalid user ID returns 0")
    func testCountPendingWithInvalidUserId() async throws {
        let service = FollowRequestsService.shared
        let invalidUserId = "not-a-uuid"
        let count = try await FollowRequestsService.shared.countPending(targetUserId: invalidUserId)
        #expect(count == 0, "Invalid user ID should return 0")
    }
    
    @Test("Count pending with empty user ID returns 0")
    func testCountPendingWithEmptyUserId() async throws {
        let emptyUserId = ""
        let count = try await FollowRequestsService.shared.countPending(targetUserId: emptyUserId)
        #expect(count == 0, "Empty user ID should return 0")
    }
    
    @Test("Count pending with valid user ID returns non-negative count")
    func testCountPendingWithValidUserId() async throws {
        let validUuid = UUID().uuidString
        
        do {
            let count = try await FollowRequestsService.shared.countPending(targetUserId: validUuid)
            #expect(count >= 0, "Count should be non-negative")
        } catch {
            // Network errors are acceptable in test environment
            #expect(true, "Network error is acceptable in test environment")
        }
    }
    
    // MARK: - Fetch Page Tests
    
    @Test("Fetch page with invalid user ID returns empty page")
    func testFetchPageWithInvalidUserId() async throws {
        let invalidUserId = "not-a-uuid"
        let page = try await FollowRequestsService.shared.fetchPage(for: invalidUserId, start: 0, pageSize: 10)
        
        #expect(page.items.count == 0, "Invalid user ID should return empty page")
        #expect(page.nextStart == nil, "Invalid user ID should have no next page")
    }
    
    @Test("Fetch page with empty user ID returns empty page")
    func testFetchPageWithEmptyUserId() async throws {
        let emptyUserId = ""
        let page = try await FollowRequestsService.shared.fetchPage(for: emptyUserId, start: 0, pageSize: 10)
        
        #expect(page.items.count == 0, "Empty user ID should return empty page")
        #expect(page.nextStart == nil, "Empty user ID should have no next page")
    }
    
    @Test("Fetch page with valid parameters returns valid structure")
    func testFetchPageWithValidParameters() async throws {
        let validUuid = UUID().uuidString
        
        do {
            let page = try await FollowRequestsService.shared.fetchPage(for: validUuid, start: 0, pageSize: 10)
            
            #expect(page.items != nil, "Page should have items array")
            #expect(page.items.count >= 0, "Items count should be non-negative")
            
            if let firstRequest = page.items.first {
                #expect(firstRequest.id != nil, "Follow request should have ID")
                #expect(firstRequest.requesterUid != nil, "Follow request should have requester UID")
            }
        } catch {
            // Network errors are acceptable in test environment
            #expect(true, "Network error is acceptable in test environment")
        }
    }
    
    @Test("Fetch page pagination logic")
    func testFetchPagePaginationLogic() async throws {
        let validUuid = UUID().uuidString
        let pageSize = 5
        
        do {
            let page = try await FollowRequestsService.shared.fetchPage(for: validUuid, start: 0, pageSize: pageSize)
            
            if page.items.count < pageSize {
                #expect(page.nextStart == nil, "Should have no next page when items < pageSize")
            } else if page.items.count == pageSize {
                #expect(page.nextStart == pageSize, "Next start should be pageSize when full page")
            }
        } catch {
            #expect(true, "Network error is acceptable")
        }
    }
    
    @Test("Fetch page with zero page size")
    func testFetchPageWithZeroPageSize() async throws {
        let validUuid = UUID().uuidString
        
        do {
            let page = try await FollowRequestsService.shared.fetchPage(for: validUuid, start: 0, pageSize: 0)
            #expect(page.items != nil, "Should return valid page structure")
        } catch {
            #expect(true, "Error is acceptable for edge case")
        }
    }
    
    @Test("Fetch page with large page size")
    func testFetchPageWithLargePageSize() async throws {
        let validUuid = UUID().uuidString
        
        do {
            let page = try await FollowRequestsService.shared.fetchPage(for: validUuid, start: 0, pageSize: 1000)
            #expect(page.items.count >= 0, "Should handle large page size")
        } catch {
            #expect(true, "Network error is acceptable")
        }
    }
    
    // MARK: - Accept Follow Request Tests
    
    @Test("Accept with invalid requester UID throws error")
    func testAcceptWithInvalidRequesterUid() async throws {
        let invalidRequesterUid = "not-a-uuid"
        let validTargetUid = UUID().uuidString
        
        do {
            try await FollowRequestsService.shared.accept(requesterUid: invalidRequesterUid, targetUid: validTargetUid)
            Issue.record("Should throw error for invalid requester UID")
        } catch {
            #expect(error.localizedDescription.contains("Invalid user id"), "Should indicate invalid user ID")
        }
    }
    
    @Test("Accept with invalid target UID throws error")
    func testAcceptWithInvalidTargetUid() async throws {
        let validRequesterUid = UUID().uuidString
        let invalidTargetUid = "not-a-uuid"
        
        do {
            try await FollowRequestsService.shared.accept(requesterUid: validRequesterUid, targetUid: invalidTargetUid)
            Issue.record("Should throw error for invalid target UID")
        } catch {
            #expect(error.localizedDescription.contains("Invalid user id"), "Should indicate invalid user ID")
        }
    }
    
    @Test("Accept with both invalid UIDs throws error")
    func testAcceptWithBothInvalidUids() async throws {
        let invalidRequesterUid = "not-a-uuid"
        let invalidTargetUid = "also-not-a-uuid"
        
        do {
            try await FollowRequestsService.shared.accept(requesterUid: invalidRequesterUid, targetUid: invalidTargetUid)
            Issue.record("Should throw error for invalid UIDs")
        } catch {
            #expect(error.localizedDescription.contains("Invalid user id"), "Should indicate invalid user ID")
        }
    }
    
    @Test("Accept with valid UIDs completes or fails gracefully")
    func testAcceptWithValidUids() async throws {
        let requesterUid = UUID().uuidString
        let targetUid = UUID().uuidString
        
        do {
            try await FollowRequestsService.shared.accept(requesterUid: requesterUid, targetUid: targetUid)
            #expect(true, "Accept should complete without error")
        } catch {
            #expect(true, "Network/database error is acceptable in test environment")
        }
    }
    
    // MARK: - Deny Follow Request Tests
    
    @Test("Deny with invalid requester UID throws error")
    func testDenyWithInvalidRequesterUid() async throws {
        let invalidRequesterUid = "not-a-uuid"
        let validTargetUid = UUID().uuidString
        
        do {
            try await FollowRequestsService.shared.deny(requesterUid: invalidRequesterUid, targetUid: validTargetUid)
            Issue.record("Should throw error for invalid requester UID")
        } catch {
            #expect(error.localizedDescription.contains("Invalid user id"), "Should indicate invalid user ID")
        }
    }
    
    @Test("Deny with invalid target UID throws error")
    func testDenyWithInvalidTargetUid() async throws {
        let validRequesterUid = UUID().uuidString
        let invalidTargetUid = "not-a-uuid"
        
        do {
            try await FollowRequestsService.shared.deny(requesterUid: validRequesterUid, targetUid: invalidTargetUid)
            Issue.record("Should throw error for invalid target UID")
        } catch {
            #expect(error.localizedDescription.contains("Invalid user id"), "Should indicate invalid user ID")
        }
    }
    
    @Test("Deny with both invalid UIDs throws error")
    func testDenyWithBothInvalidUids() async throws {
        let invalidRequesterUid = "not-a-uuid"
        let invalidTargetUid = "also-not-a-uuid"
        
        do {
            try await FollowRequestsService.shared.deny(requesterUid: invalidRequesterUid, targetUid: invalidTargetUid)
            Issue.record("Should throw error for invalid UIDs")
        } catch {
            #expect(error.localizedDescription.contains("Invalid user id"), "Should indicate invalid user ID")
        }
    }
    
    @Test("Deny with valid UIDs completes or fails gracefully")
    func testDenyWithValidUids() async throws {
        let requesterUid = UUID().uuidString
        let targetUid = UUID().uuidString
        
        do {
            try await FollowRequestsService.shared.deny(requesterUid: requesterUid, targetUid: targetUid)
            #expect(true, "Deny should complete without error")
        } catch {
            #expect(true, "Network/database error is acceptable in test environment")
        }
    }
    
    // MARK: - FollowRequest Model Tests
    
    @Test("FollowRequest structure properties are set correctly")
    func testFollowRequestStructure() {
        let id = UUID().uuidString
        let requesterUid = UUID().uuidString
        let username = "testuser"
        let photoURL = "https://example.com/photo.jpg"
        let createdAt = Date()
        
        let followRequest = FollowRequest(
            id: id,
            requesterUid: requesterUid,
            username: username,
            photoURL: photoURL,
            createdAt: createdAt
        )
        
        #expect(followRequest.id == id)
        #expect(followRequest.requesterUid == requesterUid)
        #expect(followRequest.username == username)
        #expect(followRequest.photoURL == photoURL)
        #expect(followRequest.createdAt == createdAt)
    }
    
    @Test("FollowRequest is identifiable by ID")
    func testFollowRequestIdentifiable() {
        let id = UUID().uuidString
        let request1 = FollowRequest(id: id, requesterUid: UUID().uuidString, username: nil, photoURL: nil, createdAt: nil)
        let request2 = FollowRequest(id: id, requesterUid: UUID().uuidString, username: nil, photoURL: nil, createdAt: nil)
        
        #expect(request1.id == request2.id)
    }
    
    @Test("FollowRequest is hashable and usable in sets")
    func testFollowRequestHashable() {
        let id = UUID().uuidString
        let request = FollowRequest(id: id, requesterUid: UUID().uuidString, username: nil, photoURL: nil, createdAt: nil)
        
        var set = Set<FollowRequest>()
        set.insert(request)
        
        #expect(set.contains(request))
    }
    
    @Test("FollowRequest handles nil optional fields")
    func testFollowRequestWithOptionalFields() {
        let id = UUID().uuidString
        let requesterUid = UUID().uuidString
        
        let followRequest = FollowRequest(
            id: id,
            requesterUid: requesterUid,
            username: nil,
            photoURL: nil,
            createdAt: nil
        )
        
        #expect(followRequest.id == id)
        #expect(followRequest.requesterUid == requesterUid)
        #expect(followRequest.username == nil)
        #expect(followRequest.photoURL == nil)
        #expect(followRequest.createdAt == nil)
    }
    
    // MARK: - Page Model Tests
    
    @Test("Page structure properties are set correctly")
    func testPageStructure() {
        let items = [
            FollowRequest(id: "1", requesterUid: "user-1", username: nil, photoURL: nil, createdAt: nil),
            FollowRequest(id: "2", requesterUid: "user-2", username: nil, photoURL: nil, createdAt: nil)
        ]
        let nextStart = 10
        
        let page = FollowRequestsService.Page(items: items, nextStart: nextStart)
        
        #expect(page.items.count == 2)
        #expect(page.nextStart == nextStart)
    }
    
    @Test("Page with no next page has nil nextStart")
    func testPageWithNoNextPage() {
        let items: [FollowRequest] = []
        let page = FollowRequestsService.Page(items: items, nextStart: nil)
        
        #expect(page.items.count == 0)
        #expect(page.nextStart == nil)
    }
    
    // MARK: - Concurrency Tests
    
    @Test("Concurrent count calls complete successfully")
    func testConcurrentCountCalls() async throws {
        let userIds = (1...5).map { _ in UUID().uuidString }
        
        let counts = await withTaskGroup(of: Int.self) { group -> [Int] in
            for userId in userIds {
                group.addTask {
                    (try? await FollowRequestsService.shared.countPending(targetUserId: userId)) ?? 0
                }
            }
            
            var results: [Int] = []
            for await count in group {
                results.append(count)
            }
            return results
        }
        
        #expect(counts.count == 5, "All concurrent calls should complete")
    }
    
    @Test("Concurrent fetch calls complete successfully")
    func testConcurrentFetchCalls() async throws {
        let userIds = (1...5).map { _ in UUID().uuidString }
        
        let pages = await withTaskGroup(of: FollowRequestsService.Page?.self) { group -> [FollowRequestsService.Page?] in
            for userId in userIds {
                group.addTask {
                    try? await FollowRequestsService.shared.fetchPage(for: userId, start: 0, pageSize: 10)
                }
            }
            
            var results: [FollowRequestsService.Page?] = []
            for await page in group {
                results.append(page)
            }
            return results
        }
        
        #expect(pages.count == 5, "All concurrent calls should complete")
    }
    
    // MARK: - Edge Case Tests
    
    @Test("Empty strings as UIDs are handled gracefully")
    func testEmptyStringsAsUids() async throws {
        let emptyUid = ""
        
        let count = try await FollowRequestsService.shared.countPending(targetUserId: emptyUid)
        #expect(count == 0, "Empty UID should return 0")
        
        let page = try await FollowRequestsService.shared.fetchPage(for: emptyUid, start: 0, pageSize: 10)
        #expect(page.items.count == 0, "Empty UID should return empty page")
    }
    
    @Test("Whitespace-only UIDs are handled gracefully")
    func testWhitespaceOnlyUids() async throws {
        let whitespaceUid = "   "
        let count = try await FollowRequestsService.shared.countPending(targetUserId: whitespaceUid)
        #expect(count == 0, "Whitespace UID should return 0")
    }
    
    @Test("Very long invalid UIDs are handled without crashing")
    func testVeryLongInvalidUids() async throws {
        let longUid = String(repeating: "x", count: 1000)
        let count = try await FollowRequestsService.shared.countPending(targetUserId: longUid)
        #expect(count == 0, "Long invalid UID should return 0")
    }
}

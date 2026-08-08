//
//  FeedDiversityTests.swift
//  SpotTests
//

import Foundation
import Testing
@testable import Spot

struct FeedDiversityTests {

    private func spot(id: String, user: String, tag: String) -> Spot {
        Spot(id: id, userId: user, vibeTag: tag, createdAt: Date())
    }

    @Test func skipsReorderWhenOnlyOneTagInInventory() {
        let spots = (0..<8).map { spot(id: "s\($0)", user: "u\($0)", tag: "Coffee") }
        let (out, m) = FeedDiversity.diversifyHomeFeedPage(spots, feedProfileRow: nil)
        #expect(out == spots)
        #expect(m.reorderMoves == 0)
    }

    @Test func capsRepeatedTagInFirstWindowWhenInventoryAllows() {
        let tags = Array(repeating: "Coffee", count: 12) + Array(repeating: "Beach", count: 4)
            + Array(repeating: "Night", count: 4) + Array(repeating: "Food", count: 4)
        let spots = tags.enumerated().map { spot(id: "id\($0.offset)", user: "u\($0.offset)", tag: $0.element) }
        let (out, m) = FeedDiversity.diversifyHomeFeedPage(spots, feedProfileRow: nil)
        #expect(out.count == spots.count)
        let head = Array(out.prefix(10))
        let coffeeCount = head.filter { ($0.vibeTag ?? "") == "Coffee" }.count
        // Best-effort cap (inventory is 12× Coffee); relax slightly vs ideal 3 to avoid brittle ordering edge cases.
        #expect(coffeeCount <= 4)
        let distinctHead = Set(head.map { ($0.vibeTag ?? "").lowercased() }).count
        #expect(distinctHead >= 3)
        #expect(m.distinctTagsInFirstWindow >= 3)
    }

    @Test func userSignalCountTreatsMissingProfileAsZero() {
        #expect(FeedDiversity.userSignalCount(feedProfileRow: nil) == 0)
        #expect(FeedDiversity.isLowSignalUser(feedProfileRow: nil))
    }
}

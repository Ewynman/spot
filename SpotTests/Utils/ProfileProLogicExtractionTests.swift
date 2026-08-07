import Foundation
import Testing
@testable import Spot

struct SettingsDateFormatterTests {
    @Test func formatsMediumDateWithoutTime() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(from: DateComponents(year: 2026, month: 8, day: 6))!
        let formatted = SettingsDateFormatter.mediumDate(date)
        #expect(formatted.contains("2026"))
        #expect(formatted.contains("6") || formatted.contains("06"))
    }
}

struct SpotListDeduperTests {
    @Test func acceptsNewIdsAndSkipsDuplicatesAndNil() {
        var known = Set<String>()
        let first = SpotListDeduper.accepting(
            [
                SpotTestHelpers.makeSpot(id: "a"),
                SpotTestHelpers.makeSpot(id: nil),
                SpotTestHelpers.makeSpot(id: "b")
            ],
            into: &known
        )
        #expect(first.map(\.id) == ["a", "b"])
        #expect(known == ["a", "b"])

        let second = SpotListDeduper.accepting(
            [SpotTestHelpers.makeSpot(id: "a"), SpotTestHelpers.makeSpot(id: "c")],
            into: &known
        )
        #expect(second.map(\.id) == ["c"])
        #expect(known == ["a", "b", "c"])
    }
}

struct FeedProfileContentPolicyTests {
    @Test func emptyWhenNilOrZeroCounts() {
        #expect(FeedProfileContentPolicy.hasContent(topVibes: 0, topCreators: 0, events30d: 0) == false)
    }

    @Test func hasContentWhenAnyBucketNonZero() {
        #expect(FeedProfileContentPolicy.hasContent(topVibes: 1, topCreators: 0, events30d: 0))
        #expect(FeedProfileContentPolicy.hasContent(topVibes: 0, topCreators: 2, events30d: 0))
        #expect(FeedProfileContentPolicy.hasContent(topVibes: 0, topCreators: 0, events30d: 3))
    }
}

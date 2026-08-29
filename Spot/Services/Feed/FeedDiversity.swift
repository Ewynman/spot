//
//  FeedDiversity.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum FeedDiversity {
    /// PRD-aligned defaults; tuned for first-window variety without reshaping tail order.
    struct Options: Equatable {
        let windowSize: Int
        let maxSameTagInWindow: Int
        let maxSameCreatorInWindow: Int
        let minDistinctTagsInWindow: Int
        /// Only enforce `minDistinctTagsInWindow` when the page has at least this many items.
        let minSpotsForMinDistinct: Int
    }

    struct Metrics: Equatable {
        let userSignalCount: Int
        let lowSignalMode: Bool
        let inputCount: Int
        let outputCount: Int
        let distinctTagsInFirstWindow: Int
        let maxTagRepeatsInFirstWindow: Int
        let maxCreatorRepeatsInFirstWindow: Int
        let reorderMoves: Int
    }

    static let lowSignalThreshold: Int = 10

    /// Approximates PRD “likes + bookmarks + follows + views” using stored stats + light event totals.
    static func userSignalCount(feedProfileRow: FeedProfileRow?) -> Int {
        guard let row = feedProfileRow else { return 0 }
        let s = row.profile.stats
        let eventViews = min(row.profile.eventSummary30d.total, 50)
        return s.likesCount + s.savesCount + s.followsCount + eventViews
    }

    static func isLowSignalUser(feedProfileRow: FeedProfileRow?) -> Bool {
        userSignalCount(feedProfileRow: feedProfileRow) < lowSignalThreshold
    }

    static func options(forLowSignal: Bool) -> Options {
        if forLowSignal {
            return Options(
                windowSize: 10,
                maxSameTagInWindow: 2,
                maxSameCreatorInWindow: 2,
                minDistinctTagsInWindow: 4,
                minSpotsForMinDistinct: 10
            )
        }
        return Options(
            windowSize: 10,
            maxSameTagInWindow: 3,
            maxSameCreatorInWindow: 2,
            minDistinctTagsInWindow: 4,
            minSpotsForMinDistinct: 10
        )
    }

    /// Reorders `spots` (same multiset) to satisfy first-window diversity when possible.
    static func diversifyHomeFeedPage(
        _ spots: [Spot],
        feedProfileRow: FeedProfileRow?
    ) -> (spots: [Spot], metrics: Metrics) {
        guard spots.count > 1 else {
            let m = makeMetrics(
                row: feedProfileRow,
                input: spots,
                output: spots,
                moves: 0
            )
            return (spots, m)
        }

        let low = isLowSignalUser(feedProfileRow: feedProfileRow)
        let opts = options(forLowSignal: low)
        let distinctInFull = distinctTagKeys(in: spots).count
        if distinctInFull <= 1 {
            let m = makeMetrics(row: feedProfileRow, input: spots, output: spots, moves: 0)
            return (spots, m)
        }

        var remaining: [RankedSpot] = spots.enumerated().map { RankedSpot(rank: $0.offset, spot: $0.element) }
        var result: [Spot] = []
        var moves = 0

        while !remaining.isEmpty {
            let pos = result.count
            let inStrictWindow = pos < opts.windowSize

            let pick: RankedSpot?
            if inStrictWindow {
                pick = chooseNext(
                    remaining: remaining,
                    result: result,
                    pos: pos,
                    options: opts,
                    distinctInFull: distinctInFull,
                    relaxMinDistinct: false
                ) ?? chooseNext(
                    remaining: remaining,
                    result: result,
                    pos: pos,
                    options: opts,
                    distinctInFull: distinctInFull,
                    relaxMinDistinct: true
                )
            } else {
                pick = remaining.min(by: { $0.rank < $1.rank })
            }

            let fallback = remaining.min(by: { $0.rank < $1.rank })!
            let chosen = pick ?? fallback
            if pos < opts.windowSize {
                let lowestRank = remaining.map(\.rank).min()!
                if chosen.rank != lowestRank { moves += 1 }
            }
            if let idx = remaining.firstIndex(where: { $0.rank == chosen.rank }) {
                result.append(remaining.remove(at: idx).spot)
            } else {
                result.append(remaining.removeFirst().spot)
            }
        }

        let m = makeMetrics(row: feedProfileRow, input: spots, output: result, moves: moves)
        return (result, m)
    }

    // MARK: - Internals

    private struct RankedSpot: Equatable {
        let rank: Int
        let spot: Spot
    }

    private static func chooseNext(
        remaining: [RankedSpot],
        result: [Spot],
        pos: Int,
        options: Options,
        distinctInFull: Int,
        relaxMinDistinct: Bool
    ) -> RankedSpot? {
        let candidates = remaining.sorted { $0.rank < $1.rank }
        for item in candidates {
            if canAppend(
                item.spot,
                to: result,
                pos: pos,
                options: options,
                distinctInFull: distinctInFull,
                relaxMinDistinct: relaxMinDistinct
            ) {
                return item
            }
        }
        return nil
    }

    private static func tagKey(_ s: Spot) -> String {
        let t = (s.vibeTag ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return t.isEmpty ? "_none_" : t
    }

    private static func creatorKey(_ s: Spot) -> String {
        s.userId ?? "_unknown_"
    }

    private static func distinctTagKeys(in spots: [Spot]) -> Set<String> {
        Set(spots.map { tagKey($0) })
    }

    private static func canAppend(
        _ s: Spot,
        to result: [Spot],
        pos: Int,
        options: Options,
        distinctInFull: Int,
        relaxMinDistinct: Bool
    ) -> Bool {
        let sliceLen = min(options.windowSize, pos + 1)
        let slice = Array((result + [s]).prefix(sliceLen))

        var tagCounts: [String: Int] = [:]
        var creatorCounts: [String: Int] = [:]
        for x in slice {
            tagCounts[tagKey(x), default: 0] += 1
            creatorCounts[creatorKey(x), default: 0] += 1
        }
        if let maxT = tagCounts.values.max(), maxT > options.maxSameTagInWindow { return false }
        if let maxC = creatorCounts.values.max(), maxC > options.maxSameCreatorInWindow { return false }

        let canRequireDistinct = !relaxMinDistinct
            && sliceLen == options.windowSize
            && result.count + 1 >= options.minSpotsForMinDistinct
            && distinctInFull >= options.minDistinctTagsInWindow

        if canRequireDistinct {
            let distinct = Set(slice.map { tagKey($0) }).count
            if distinct < options.minDistinctTagsInWindow { return false }
        }

        return true
    }

    private static func makeMetrics(
        row: FeedProfileRow?,
        input: [Spot],
        output: [Spot],
        moves: Int
    ) -> Metrics {
        let w = min(10, output.count)
        let head = Array(output.prefix(w))
        var tagCounts: [String: Int] = [:]
        var creatorCounts: [String: Int] = [:]
        for s in head {
            tagCounts[tagKey(s), default: 0] += 1
            creatorCounts[creatorKey(s), default: 0] += 1
        }
        return Metrics(
            userSignalCount: userSignalCount(feedProfileRow: row),
            lowSignalMode: isLowSignalUser(feedProfileRow: row),
            inputCount: input.count,
            outputCount: output.count,
            distinctTagsInFirstWindow: Set(head.map { tagKey($0) }).count,
            maxTagRepeatsInFirstWindow: tagCounts.values.max() ?? 0,
            maxCreatorRepeatsInFirstWindow: creatorCounts.values.max() ?? 0,
            reorderMoves: moves
        )
    }
}

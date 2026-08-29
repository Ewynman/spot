//
//  VibeTagUsageStore.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum VibeTagUsageStore {
    private static let usageKey = "postFlow.vibeTagUsage"

    private struct VibeUsage: Codable {
        var count: Int
        var lastUsedAt: Date
    }

    static func recordUsage(tags: [String]) {
        guard !tags.isEmpty else {
            SpotLogger.log(VibeTagUsageStoreLogs.noTagsToRecord)
            return
        }
        var usage = loadUsage()
        let now = Date()
        let normalizedTags = Set(tags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }).filter({ !$0.isEmpty })
        for tag in normalizedTags {
            let old = usage[tag] ?? VibeUsage(count: 0, lastUsedAt: .distantPast)
            usage[tag] = VibeUsage(count: old.count + 1, lastUsedAt: now)
        }
        saveUsage(usage)
        SpotLogger.log(VibeTagUsageStoreLogs.usageRecorded, details: ["tagCount": normalizedTags.count])
    }

    static func recentAndFrequent(limit: Int = 8, excluding selected: [String] = []) -> [String] {
        let excluded = Set(selected)
        return loadUsage()
            .filter { !excluded.contains($0.key) }
            .sorted {
                if $0.value.count == $1.value.count {
                    return $0.value.lastUsedAt > $1.value.lastUsedAt
                }
                return $0.value.count > $1.value.count
            }
            .map(\.key)
            .prefix(limit)
            .map { $0 }
    }
}

private extension VibeTagUsageStore {
    private static func loadUsage() -> [String: VibeUsage] {
        guard let data = UserDefaults.standard.data(forKey: usageKey) else {
            return [:]
        }
        guard let decoded = try? JSONDecoder().decode([String: VibeUsage].self, from: data) else {
            SpotLogger.log(VibeTagUsageStoreLogs.usageDecodeFailed)
            return [:]
        }
        return decoded
    }

    private static func saveUsage(_ usage: [String: VibeUsage]) {
        guard let encoded = try? JSONEncoder().encode(usage) else {
            SpotLogger.log(VibeTagUsageStoreLogs.usageEncodeFailed)
            return
        }
        UserDefaults.standard.set(encoded, forKey: usageKey)
    }
}

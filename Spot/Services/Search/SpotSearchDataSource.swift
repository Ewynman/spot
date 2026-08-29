//
//  SpotSearchDataSource.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation
import Supabase

struct SearchPage<T> {
    let items: [T]
    let lastDocument: String?
}

final class SpotSearchDataSource {
    private let pageSize = 24
    private let placesPage = 20

    private struct UserRow: Decodable {
        let id: UUID
        let username: String
        let profile_image_url: String?
    }

    // MARK: Users
    func searchUsers(prefix: String, last: String? = nil) async throws -> SearchPage<[String: Any]> {
        guard !prefix.isEmpty else { return SearchPage(items: [], lastDocument: nil) }
        let lower = prefix.lowercased()
        let rows: [UserRow] = try await supabase
            .from(SupabaseTableName.usersPublic)
            .select("id,username,profile_image_url")
            .limit(400)
            .execute()
            .value
        let filtered = rows.filter { $0.username.lowercased().hasPrefix(lower) }
            .prefix(pageSize)
        let items = filtered.map { row in
            [
                "uid": row.id.uuidString,
                "username": row.username,
                "profileImageURL": row.profile_image_url as Any
            ]
        }
        return SearchPage(items: items, lastDocument: nil)
    }

    // MARK: Locations (suggestions)
    func searchLocationSuggestions(prefix: String, limit: Int = 20) async throws -> [String] {
        guard !prefix.isEmpty else { return [] }
        let lower = prefix.lowercased()
        let escaped = SpotSupabaseRepository.postgresILikeEscaped(lower)
        struct PlaceRow: Decodable { let location_name: String? }
        // Server-side prefix filter; cap rows then dedupe for distinct suggestion strings.
        let rows: [PlaceRow] = try await supabase
            .from("spots")
            .select("location_name")
            .ilike("location_name", pattern: escaped + "%")
            .order("location_name", ascending: true)
            .limit(200)
            .execute()
            .value
        let names = rows.compactMap { $0.location_name?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let titles = Array(Set(names.filter { $0.lowercased().hasPrefix(lower) })).sorted()
        SpotLogger.log(SearchDataSourceLogs.locationSuggestions, details: ["prefix": prefix, "count": titles.count])
        return Array(titles.prefix(limit))
    }

    // MARK: Vibes (suggestions)
    func searchVibeSuggestions(prefix: String, limit: Int = 20) async throws -> [String] {
        guard !prefix.isEmpty else { return [] }
        let lower = prefix.lowercased()
        struct Row: Decodable { let name: String }
        let rows: [Row] = try await supabase
            .from("vibe_tags")
            .select("name")
            .limit(300)
            .execute()
            .value
        let titles = Array(Set(rows.map(\.name).filter { $0.lowercased().hasPrefix(lower) })).sorted()
        SpotLogger.log(SearchDataSourceLogs.vibeSuggestions, details: ["prefix": prefix, "count": titles.count])
        return Array(titles.prefix(limit))
    }

    // MARK: Spots by exact location/vibe
    func fetchSpotsByLocation(_ locationLower: String, last: String? = nil) async throws -> SearchPage<Spot> {
        let offset = Int(last ?? "") ?? 0
        let spots = try await SpotSupabaseRepository.fetchSpotsForSearchGridByLocation(
            locationNameLower: locationLower,
            limit: pageSize,
            offset: offset
        )
        let next = spots.count < pageSize ? nil : String(offset + spots.count)
        return SearchPage(items: spots, lastDocument: next)
    }

    func fetchSpotsByVibe(_ vibeLower: String, last: String? = nil) async throws -> SearchPage<Spot> {
        let offset = Int(last ?? "") ?? 0
        let ids = try await SpotSupabaseRepository.fetchVibeTagIds(nameLowers: [vibeLower])
        guard !ids.isEmpty else { return SearchPage(items: [], lastDocument: nil) }
        let spots = try await SpotSupabaseRepository.fetchSpotsForSearchGridByVibeTagIds(
            vibeTagIds: ids,
            limit: pageSize,
            offset: offset
        )
        let next = spots.count < pageSize ? nil : String(offset + spots.count)
        return SearchPage(items: spots, lastDocument: next)
    }

    // MARK: Multiple vibes (Pro)
    func fetchSpotsByVibes(_ vibeLowers: [String], last: String? = nil) async throws -> SearchPage<Spot> {
        let lowers = Array(Set(vibeLowers.map { $0.lowercased() }))
        guard !lowers.isEmpty else { return SearchPage(items: [], lastDocument: nil) }
        let offset = Int(last ?? "") ?? 0
        let ids = try await SpotSupabaseRepository.fetchVibeTagIds(nameLowers: lowers)
        guard !ids.isEmpty else { return SearchPage(items: [], lastDocument: nil) }
        let spots = try await SpotSupabaseRepository.fetchSpotsForSearchGridByVibeTagIds(
            vibeTagIds: ids,
            limit: pageSize,
            offset: offset
        )
        let next = spots.count < pageSize ? nil : String(offset + spots.count)
        return SearchPage(items: spots, lastDocument: next)
    }

    // MARK: Location + Multiple vibes (Pro)
    func fetchSpotsByLocationAndVibes(_ locationLower: String, vibeLowers: [String], last: String? = nil) async throws -> SearchPage<Spot> {
        let lowers = Array(Set(vibeLowers.map { $0.lowercased() }))
        guard !lowers.isEmpty else { return SearchPage(items: [], lastDocument: nil) }
        let offset = Int(last ?? "") ?? 0
        let ids = try await SpotSupabaseRepository.fetchVibeTagIds(nameLowers: lowers)
        guard !ids.isEmpty else { return SearchPage(items: [], lastDocument: nil) }
        let spots = try await SpotSupabaseRepository.fetchSpotsForSearchGridByLocationAndVibeTagIds(
            locationNameLower: locationLower,
            vibeTagIds: ids,
            limit: pageSize,
            offset: offset
        )
        let next = spots.count < pageSize ? nil : String(offset + spots.count)
        return SearchPage(items: spots, lastDocument: next)
    }
}

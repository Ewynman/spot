//
//  SpotSupabaseRepository.swift
//  Spot
//
//  Reads / deletes spots stored in Postgres (public.spots + spot_images + vibe_tags).
//

import Foundation
import Supabase

enum SpotSupabaseRepository {
    /// Private bucket: `spot_images.storage_path` is the object key in the `spots` bucket (e.g. `userId/spotId_0.jpg`).
    /// `public_url` (if present) may hold the same path or a legacy full `https://` URL; signing uses `storage_path` first.
    private static let spotsStorageBucketId = "spots"
    private static let pendingImagesBucketId = "pending_images"

    private enum SupabasePlist {
        static let baseURL: URL = {
            guard let path = Bundle.main.path(forResource: "Info", ofType: "plist"),
                  let root = NSDictionary(contentsOfFile: path) as? [String: Any],
                  let supabase = root["Supabase"] as? [String: Any],
                  let urlString = supabase["url"] as? String,
                  let url = URL(string: urlString)
            else {
                fatalError("Supabase.url missing in Info.plist")
            }
            return url
        }()

        static let anonKey: String = {
            guard let path = Bundle.main.path(forResource: "Info", ofType: "plist"),
                  let root = NSDictionary(contentsOfFile: path) as? [String: Any],
                  let supabase = root["Supabase"] as? [String: Any],
                  let key = supabase["anonKey"] as? String,
                  !key.isEmpty
            else {
                fatalError("Supabase.anonKey missing in Info.plist")
            }
            return key
        }()
    }
    /// Signed URL lifetime for spot images (feed / grids refresh on reload).
    private static let spotImageSignedURLExpirySeconds = 604_800 // 7 days

    private static let iso8601Fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let iso8601Plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func parseTimestamptz(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        if let d = iso8601Fractional.date(from: raw) { return d }
        return iso8601Plain.date(from: raw)
    }

    private struct SpotRow: Decodable {
        let id: UUID
        let user_id: UUID
        let vibe_tag_id: UUID?
        let caption: String?
        let latitude: Double
        let longitude: Double
        let location_name: String?
        let likes_count: Int64?
        let author_is_private_snapshot: Bool?
        let created_at: String
        let media_display_aspect_ratio: Double?
        let media_count: Int64?
    }

    private struct SpotImageRow: Decodable {
        let spot_id: UUID
        let sort_index: Int
        let storage_path: String?
        let public_url: String?
        let storage_bucket: String?

        /// Object path inside the `spots` bucket, or a legacy absolute URL in `public_url`.
        var imageReference: String {
            let fromStorage = storage_path?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !fromStorage.isEmpty { return fromStorage }
            return public_url?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
    }

    private static func isStoredAbsoluteURL(_ s: String) -> Bool {
        let lower = s.lowercased()
        return lower.hasPrefix("https://") || lower.hasPrefix("http://")
    }

    /// Exposed for unit tests.
    static func isStoredAbsoluteURLForTests(_ s: String) -> Bool {
        isStoredAbsoluteURL(s)
    }

    /// Maps stored object paths to HTTPS URLs (signed per `storage_bucket`, default `spots`).
    static func resolveStoredImageURLs(paths: [String], buckets: [String?]) async throws -> [String] {
        guard !paths.isEmpty else { return [] }
        precondition(paths.count == buckets.count)

        struct BucketPath: Hashable {
            let bucket: String
            let path: String
        }

        var toSign = Set<BucketPath>()
        for (p, b) in zip(paths, buckets) where !isStoredAbsoluteURL(p) && !p.isEmpty {
            let bucket = b ?? spotsStorageBucketId
            toSign.insert(BucketPath(bucket: bucket, path: p))
        }

        var signedByKey: [BucketPath: String] = [:]
        let grouped = Dictionary(grouping: toSign, by: \.bucket)
        for (bucket, keys) in grouped {
            let uniquePaths = Array(Set(keys.map(\.path)))
            var offset = 0
            let chunkSize = 100
            while offset < uniquePaths.count {
                let end = min(offset + chunkSize, uniquePaths.count)
                let chunk = Array(uniquePaths[offset..<end])
                let signedResults = try await supabase.storage
                    .from(bucket)
                    .createSignedURLs(paths: chunk, expiresIn: spotImageSignedURLExpirySeconds)
                for item in signedResults {
                    if case let .success(path, url) = item {
                        signedByKey[BucketPath(bucket: bucket, path: path)] = url.absoluteString
                    }
                }
                offset = end
            }
        }

        return zip(paths, buckets).map { path, bucket in
            if isStoredAbsoluteURL(path) { return path }
            if path.isEmpty { return path }
            let b = bucket ?? spotsStorageBucketId
            return signedByKey[BucketPath(bucket: b, path: path)] ?? path
        }
    }

    private struct VibeRow: Decodable {
        let id: UUID
        let name: String
    }

    /// Spots for a profile grid, newest first.
    static func fetchSpotsForUser(
        userId: UUID,
        authorUsername: String,
        authorProfileImageURL: String?
    ) async throws -> [Spot] {
        let rows: [SpotRow] = try await supabase
            .from("spots")
            .select(spotRowSelectColumns)
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value

        return try await mapRowsToSpots(
            rows,
            defaultUsername: authorUsername,
            defaultProfileURL: authorProfileImageURL
        )
    }

    /// Load spots by id (e.g. bookmark collection). Order matches input when possible.
    static func fetchSpotsByIds(_ ids: [UUID]) async throws -> [Spot] {
        guard !ids.isEmpty else { return [] }
        let rows: [SpotRow] = try await supabase
            .from("spots")
            .select(spotRowSelectColumns)
            .in("id", values: ids)
            .execute()
            .value

        let mapped = try await mapRowsToSpotsPerAuthor(rows)
        let byId = Dictionary(uniqueKeysWithValues: mapped.compactMap { s -> (String, Spot)? in
            guard let id = s.id else { return nil }
            return (id, s)
        })
        return ids.compactMap { byId[$0.uuidString] }
    }

    /// First image URL per spot id (for collection cards). Order follows `spotIds`.
    static func fetchPreviewImageURLs(spotIds: [String]) async -> [String] {
        let uuids = spotIds.compactMap { UUID(uuidString: $0) }
        guard !uuids.isEmpty else { return [] }
        do {
            let images: [SpotImageRow] = try await supabase
                .from("spot_images")
                .select("spot_id,storage_path,public_url,sort_index,storage_bucket")
                .in("spot_id", values: uuids)
                .execute()
                .value
            var bestRow: [UUID: SpotImageRow] = [:]
            for img in images {
                if let cur = bestRow[img.spot_id] {
                    if img.sort_index < cur.sort_index { bestRow[img.spot_id] = img }
                } else {
                    bestRow[img.spot_id] = img
                }
            }
            var paths: [String] = []
            var buckets: [String?] = []
            for sid in spotIds {
                guard let u = UUID(uuidString: sid), let row = bestRow[u] else { continue }
                let ref = row.imageReference
                paths.append(ref)
                buckets.append(isStoredAbsoluteURL(ref) ? nil : (row.storage_bucket ?? spotsStorageBucketId))
            }
            return (try? await resolveStoredImageURLs(paths: paths, buckets: buckets)) ?? paths
        } catch {
            return []
        }
    }

    static func deleteSpot(id: UUID) async throws {
        try await supabase
            .from("spots")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    static func updateSpotMetadata(
        id: UUID,
        vibeTags: [String],
        latitude: Double,
        longitude: Double,
        locationName: String
    ) async throws {
        guard !vibeTags.isEmpty else {
            throw NSError(domain: "SpotSupabaseRepository", code: 0, userInfo: [NSLocalizedDescriptionKey: "At least one vibe is required"])
        }
        
        // Validate coordinates
        if let coordError = InputValidation.validateCoordinates(latitude: latitude, longitude: longitude) {
            throw NSError(domain: "SpotSupabaseRepository", code: 400, userInfo: [NSLocalizedDescriptionKey: coordError])
        }
        
        // Validate location name
        if let locationError = InputValidation.validateLocationName(locationName) {
            throw NSError(domain: "SpotSupabaseRepository", code: 400, userInfo: [NSLocalizedDescriptionKey: locationError])
        }
        let trimmedPlace = locationName.trimmingCharacters(in: .whitespacesAndNewlines)
        var vibeIds: [UUID] = []
        vibeIds.reserveCapacity(vibeTags.count)
        for tag in vibeTags {
            vibeIds.append(try await resolveOrCreateVibeTagId(displayName: tag))
        }

        struct UpdateSpotRpcParams: Encodable {
            let p_spot_id: UUID
            let p_vibe_tag_ids: [UUID]
            let p_latitude: Double
            let p_longitude: Double
            let p_location_name: String
        }

        try await supabase.rpc(
            "update_spot_metadata_v1",
            params: UpdateSpotRpcParams(
                p_spot_id: id,
                p_vibe_tag_ids: vibeIds,
                p_latitude: latitude,
                p_longitude: longitude,
                p_location_name: trimmedPlace
            )
        )
        .execute()
    }

    // MARK: - Mapping

    private struct SpotVibeJunctionRow: Decodable {
        let spot_id: UUID
        let vibe_tag_id: UUID
        let sort_order: Int
    }

    private static func fetchVibeLabelListsBySpotId(spotIds: [UUID]) async throws -> [UUID: [String]] {
        guard !spotIds.isEmpty else { return [:] }
        let svt: [SpotVibeJunctionRow] = try await supabase
            .from("spot_vibe_tags")
            .select("spot_id,vibe_tag_id,sort_order")
            .in("spot_id", values: spotIds)
            .execute()
            .value

        let distinctVibeIds = Array(Set(svt.map(\.vibe_tag_id)))
        var idToName: [UUID: String] = [:]
        if !distinctVibeIds.isEmpty {
            let vibes: [VibeRow] = try await supabase
                .from("vibe_tags")
                .select("id,name")
                .in("id", values: distinctVibeIds)
                .execute()
                .value
            for v in vibes { idToName[v.id] = v.name }
        }

        var bySpot: [UUID: [String]] = [:]
        let grouped = Dictionary(grouping: svt, by: \.spot_id)
        for (sid, rows) in grouped {
            let sorted = rows.sorted { $0.sort_order < $1.sort_order }
            let names = sorted.compactMap { idToName[$0.vibe_tag_id] }.filter { !$0.isEmpty }
            if !names.isEmpty { bySpot[sid] = names }
        }
        return bySpot
    }

    private static func fetchAuthorProFlag(userId: UUID) async throws -> Bool {
        struct Row: Decodable {
            let is_pro: Bool?
            let pro_until: String?
        }
        let rows: [Row] = try await supabase
            .from(SupabaseTableName.usersPublic)
            .select("is_pro,pro_until")
            .eq("id", value: userId)
            .limit(1)
            .execute()
            .value
        guard let r = rows.first else { return false }
        return EffectiveProResolver.effectiveIsPro(isPro: r.is_pro ?? false, proUntilRaw: r.pro_until)
    }

    private static func mapRowsToSpots(
        _ rows: [SpotRow],
        defaultUsername: String,
        defaultProfileURL: String?
    ) async throws -> [Spot] {
        guard !rows.isEmpty else { return [] }

        async let authorIsProTask = fetchAuthorProFlag(userId: rows[0].user_id)

        let vibeIds = Set(rows.compactMap(\.vibe_tag_id))
        var vibeNames: [UUID: String] = [:]
        if !vibeIds.isEmpty {
            let vibes: [VibeRow] = try await supabase
                .from("vibe_tags")
                .select("id,name")
                .in("id", values: Array(vibeIds))
                .execute()
                .value
            for v in vibes { vibeNames[v.id] = v.name }
        }

        let spotIds = rows.map(\.id)
        async let labelsBySpotTask = fetchVibeLabelListsBySpotId(spotIds: spotIds)
        async let imagesTask: [SpotImageRow] = supabase
            .from("spot_images")
            .select("spot_id,storage_path,public_url,sort_index,storage_bucket")
            .in("spot_id", values: spotIds)
            .execute()
            .value
        let (authorIsPro, labelsBySpot, images) = try await (
            authorIsProTask,
            labelsBySpotTask,
            imagesTask
        )

        var imagesBySpot: [UUID: [SpotImageRow]] = [:]
        for img in images {
            imagesBySpot[img.spot_id, default: []].append(img)
        }
        for sid in imagesBySpot.keys {
            imagesBySpot[sid]?.sort { $0.sort_index < $1.sort_index }
        }

        let spotIdOrder = rows.map(\.id)
        var flatPaths: [String] = []
        var flatBuckets: [String?] = []
        for sid in spotIdOrder {
            for img in imagesBySpot[sid] ?? [] {
                let ref = img.imageReference
                flatPaths.append(ref)
                flatBuckets.append(isStoredAbsoluteURL(ref) ? nil : (img.storage_bucket ?? spotsStorageBucketId))
            }
        }
        let flatResolved = try await resolveStoredImageURLs(paths: flatPaths, buckets: flatBuckets)
        var cursor = 0
        var resolvedBySpot: [UUID: [String]] = [:]
        for sid in spotIdOrder {
            let n = (imagesBySpot[sid] ?? []).count
            resolvedBySpot[sid] = Array(flatResolved[cursor..<cursor + n])
            cursor += n
        }

        return rows.map { row in
            let urls = resolvedBySpot[row.id] ?? []
            let primary = urls.first
            let fallback = row.vibe_tag_id.flatMap { vibeNames[$0] } ?? ""
            let labels: [String]
            if let junction = labelsBySpot[row.id], !junction.isEmpty {
                labels = junction
            } else if !fallback.isEmpty {
                labels = [fallback]
            } else {
                labels = []
            }
            let vibe = labels.first ?? ""
            let vibeTagsOut: [String]? = labels.isEmpty ? nil : labels
            let created = parseTimestamptz(row.created_at)
            return Spot(
                id: row.id.uuidString,
                userId: row.user_id.uuidString,
                username: defaultUsername,
                userProfileImageURL: defaultProfileURL,
                imageURL: primary,
                thumbnailURL: primary,
                vibeTag: vibe,
                vibeTags: vibeTagsOut,
                latitude: row.latitude,
                longitude: row.longitude,
                locationName: row.location_name,
                likes: Int(row.likes_count ?? 0),
                isLiked: nil,
                isSaved: nil,
                createdAt: created,
                authorIsPrivate: row.author_is_private_snapshot,
                imageURLs: urls.isEmpty ? nil : urls,
                mediaDisplayAspectRatio: row.media_display_aspect_ratio,
                mediaCount: row.media_count.map { Int($0) },
                authorIsPro: authorIsPro
            )
        }
    }

    private static let spotRowSelectColumns =
        "id,user_id,vibe_tag_id,caption,latitude,longitude,location_name,likes_count,author_is_private_snapshot,created_at,media_display_aspect_ratio,media_count,media_layout_version"

    private struct UserBriefRow: Decodable {
        let id: UUID
        let username: String
        let profile_image_url: String?
        let is_pro: Bool?
        let pro_until: String?
    }

    /// Map spot rows to `Spot` with per-author username / avatar from `public.users`.
    private static func mapRowsToSpotsPerAuthor(_ rows: [SpotRow]) async throws -> [Spot] {
        guard !rows.isEmpty else { return [] }

        let userIds = Array(Set(rows.map(\.user_id)))
        let users: [UserBriefRow] = try await supabase
            .from(SupabaseTableName.usersPublic)
            .select("id,username,profile_image_url,is_pro,pro_until")
            .in("id", values: userIds)
            .execute()
            .value
        var byUser: [UUID: UserBriefRow] = [:]
        for u in users { byUser[u.id] = u }

        let vibeIds = Set(rows.compactMap(\.vibe_tag_id))
        var vibeNames: [UUID: String] = [:]
        if !vibeIds.isEmpty {
            let vibes: [VibeRow] = try await supabase
                .from("vibe_tags")
                .select("id,name")
                .in("id", values: Array(vibeIds))
                .execute()
                .value
            for v in vibes { vibeNames[v.id] = v.name }
        }

        let spotIds = rows.map(\.id)
        let labelsBySpot = try await fetchVibeLabelListsBySpotId(spotIds: spotIds)
        let images: [SpotImageRow] = try await supabase
            .from("spot_images")
            .select("spot_id,storage_path,public_url,sort_index,storage_bucket")
            .in("spot_id", values: spotIds)
            .execute()
            .value

        var imagesBySpot: [UUID: [SpotImageRow]] = [:]
        for img in images {
            imagesBySpot[img.spot_id, default: []].append(img)
        }
        for sid in imagesBySpot.keys {
            imagesBySpot[sid]?.sort { $0.sort_index < $1.sort_index }
        }

        let spotIdOrder = rows.map(\.id)
        var flatPaths: [String] = []
        var flatBuckets: [String?] = []
        for sid in spotIdOrder {
            for img in imagesBySpot[sid] ?? [] {
                let ref = img.imageReference
                flatPaths.append(ref)
                flatBuckets.append(isStoredAbsoluteURL(ref) ? nil : (img.storage_bucket ?? spotsStorageBucketId))
            }
        }
        let flatResolved = try await resolveStoredImageURLs(paths: flatPaths, buckets: flatBuckets)
        var cursor = 0
        var resolvedBySpot: [UUID: [String]] = [:]
        for sid in spotIdOrder {
            let n = (imagesBySpot[sid] ?? []).count
            resolvedBySpot[sid] = Array(flatResolved[cursor..<cursor + n])
            cursor += n
        }

        return rows.map { row in
            let u = byUser[row.user_id]
            let urls = resolvedBySpot[row.id] ?? []
            let primary = urls.first
            let fallback = row.vibe_tag_id.flatMap { vibeNames[$0] } ?? ""
            let labels: [String]
            if let junction = labelsBySpot[row.id], !junction.isEmpty {
                labels = junction
            } else if !fallback.isEmpty {
                labels = [fallback]
            } else {
                labels = []
            }
            let vibe = labels.first ?? ""
            let vibeTagsOut: [String]? = labels.isEmpty ? nil : labels
            let created = parseTimestamptz(row.created_at)
            let authorPro = u.map { EffectiveProResolver.effectiveIsPro(isPro: $0.is_pro ?? false, proUntilRaw: $0.pro_until) } ?? false
            return Spot(
                id: row.id.uuidString,
                userId: row.user_id.uuidString,
                username: u?.username ?? "User",
                userProfileImageURL: u?.profile_image_url,
                imageURL: primary,
                thumbnailURL: primary,
                vibeTag: vibe,
                vibeTags: vibeTagsOut,
                latitude: row.latitude,
                longitude: row.longitude,
                locationName: row.location_name,
                likes: Int(row.likes_count ?? 0),
                isLiked: nil,
                isSaved: nil,
                createdAt: created,
                authorIsPrivate: row.author_is_private_snapshot,
                imageURLs: urls.isEmpty ? nil : urls,
                mediaDisplayAspectRatio: row.media_display_aspect_ratio,
                mediaCount: row.media_count.map { Int($0) },
                authorIsPro: authorPro
            )
        }
    }

    // MARK: - Home feed candidates (offset pagination)

    static func fetchGlobalFeedSpots(limit: Int, offset: Int) async throws -> [Spot] {
        let rows: [SpotRow] = try await supabase
            .from("spots")
            .select(spotRowSelectColumns)
            .order("created_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value
        return try await mapRowsToSpotsPerAuthor(rows)
    }

    // MARK: - Search grids (server-side filter + offset pagination)

    /// Escapes `%`, `_`, and `\` for use inside a Postgres `ILIKE` pattern (default backslash escape).
    static func postgresILikeEscaped(_ s: String) -> String {
        s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
    }

    /// Resolves `vibe_tags.id` rows for the given `name_lower` values.
    static func fetchVibeTagIds(nameLowers: [String]) async throws -> [UUID] {
        let unique = Array(Set(nameLowers.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }.filter { !$0.isEmpty }))
        guard !unique.isEmpty else { return [] }
        struct IdRow: Decodable { let id: UUID }
        let rows: [IdRow] = try await supabase
            .from("vibe_tags")
            .select("id")
            .in("name_lower", values: unique)
            .execute()
            .value
        return rows.map(\.id)
    }

    /// Spots whose `location_name` matches `locationNameLower` exactly (case-insensitive), newest first.
    static func fetchSpotsForSearchGridByLocation(
        locationNameLower: String,
        limit: Int,
        offset: Int
    ) async throws -> [Spot] {
        let q = locationNameLower.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty, limit > 0 else { return [] }
        let pattern = postgresILikeEscaped(q)
        let rows: [SpotRow] = try await supabase
            .from("spots")
            .select(spotRowSelectColumns)
            .ilike("location_name", pattern: pattern)
            .order("created_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value
        return try await mapRowsToSpotsPerAuthor(rows)
    }

    /// Spots tagged with any of the given vibe tag ids (primary or junction), newest first.
    static func fetchSpotsForSearchGridByVibeTagIds(
        vibeTagIds: [UUID],
        limit: Int,
        offset: Int
    ) async throws -> [Spot] {
        guard !vibeTagIds.isEmpty, limit > 0 else { return [] }

        struct SpotIdRow: Decodable {
            let spot_id: UUID
            let created_at: String?
        }

        struct VibeSearchRpcParams: Encodable {
            let p_vibe_tag_ids: [UUID]
            let p_limit: Int
            let p_offset: Int
        }

        let idRows: [SpotIdRow] = try await supabase.rpc(
            "list_spot_ids_for_vibe_search_v1",
            params: VibeSearchRpcParams(p_vibe_tag_ids: vibeTagIds, p_limit: limit, p_offset: offset)
        )
        .execute()
        .value

        let orderedIds = idRows.map(\.spot_id)
        guard !orderedIds.isEmpty else { return [] }

        let rows: [SpotRow] = try await supabase
            .from("spots")
            .select(spotRowSelectColumns)
            .in("id", values: orderedIds)
            .execute()
            .value

        let order = Dictionary(uniqueKeysWithValues: orderedIds.enumerated().map { ($0.element, $0.offset) })
        let sortedRows = rows.sorted { (order[$0.id] ?? 999_999) < (order[$1.id] ?? 999_999) }
        return try await mapRowsToSpotsPerAuthor(sortedRows)
    }

    /// Spots matching location (exact, case-insensitive) and any of the vibe tag ids (primary or junction).
    static func fetchSpotsForSearchGridByLocationAndVibeTagIds(
        locationNameLower: String,
        vibeTagIds: [UUID],
        limit: Int,
        offset: Int
    ) async throws -> [Spot] {
        let q = locationNameLower.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty, !vibeTagIds.isEmpty, limit > 0 else { return [] }
        let pattern = postgresILikeEscaped(q)

        struct SpotIdRow: Decodable {
            let spot_id: UUID
            let created_at: String?
        }

        struct LocVibeRpcParams: Encodable {
            let p_location_pattern: String
            let p_vibe_tag_ids: [UUID]
            let p_limit: Int
            let p_offset: Int
        }

        let idRows: [SpotIdRow] = try await supabase.rpc(
            "list_spot_ids_for_location_and_vibe_search_v1",
            params: LocVibeRpcParams(
                p_location_pattern: pattern,
                p_vibe_tag_ids: vibeTagIds,
                p_limit: limit,
                p_offset: offset
            )
        )
        .execute()
        .value

        let orderedIds = idRows.map(\.spot_id)
        guard !orderedIds.isEmpty else { return [] }

        let rows: [SpotRow] = try await supabase
            .from("spots")
            .select(spotRowSelectColumns)
            .in("id", values: orderedIds)
            .execute()
            .value

        let order = Dictionary(uniqueKeysWithValues: orderedIds.enumerated().map { ($0.element, $0.offset) })
        let sortedRows = rows.sorted { (order[$0.id] ?? 999_999) < (order[$1.id] ?? 999_999) }
        return try await mapRowsToSpotsPerAuthor(sortedRows)
    }

    /// Lightweight map dataset: one image per spot (for preview cards), bounded count.
    /// Avoids loading all image variants and keeps memory stable when opening the map.
    static func fetchMapSpots(limit: Int) async throws -> [Spot] {
        let rows: [SpotRow] = try await supabase
            .from("spots")
            .select(spotRowSelectColumns)
            .order("created_at", ascending: false)
            .range(from: 0, to: max(0, limit - 1))
            .execute()
            .value
        guard !rows.isEmpty else { return [] }

        let userIds = Array(Set(rows.map(\.user_id)))
        let users: [UserBriefRow] = try await supabase
            .from(SupabaseTableName.usersPublic)
            .select("id,username,profile_image_url,is_pro,pro_until")
            .in("id", values: userIds)
            .execute()
            .value
        var byUser: [UUID: UserBriefRow] = [:]
        for u in users { byUser[u.id] = u }

        let vibeIds = Set(rows.compactMap(\.vibe_tag_id))
        var vibeNames: [UUID: String] = [:]
        if !vibeIds.isEmpty {
            let vibes: [VibeRow] = try await supabase
                .from("vibe_tags")
                .select("id,name")
                .in("id", values: Array(vibeIds))
                .execute()
                .value
            for v in vibes { vibeNames[v.id] = v.name }
        }

        let mapSpotIds = rows.map(\.id)
        let labelsBySpot = try await fetchVibeLabelListsBySpotId(spotIds: mapSpotIds)

        let orderedSpotIds = rows.map(\.id.uuidString)
        let previewURLs = await fetchPreviewImageURLs(spotIds: orderedSpotIds)
        var previewById: [String: String] = [:]
        for (sid, url) in zip(orderedSpotIds, previewURLs) {
            previewById[sid] = url
        }

        return rows.map { row in
            let sid = row.id.uuidString
            let u = byUser[row.user_id]
            let fallback = row.vibe_tag_id.flatMap { vibeNames[$0] } ?? ""
            let labels: [String]
            if let junction = labelsBySpot[row.id], !junction.isEmpty {
                labels = junction
            } else if !fallback.isEmpty {
                labels = [fallback]
            } else {
                labels = []
            }
            let vibe = labels.first ?? ""
            let vibeTagsOut: [String]? = labels.isEmpty ? nil : labels
            let preview = previewById[sid]
            let authorPro = u.map { EffectiveProResolver.effectiveIsPro(isPro: $0.is_pro ?? false, proUntilRaw: $0.pro_until) } ?? false
            return Spot(
                id: sid,
                userId: row.user_id.uuidString,
                username: u?.username ?? "User",
                userProfileImageURL: u?.profile_image_url,
                imageURL: preview,
                thumbnailURL: preview,
                vibeTag: vibe,
                vibeTags: vibeTagsOut,
                latitude: row.latitude,
                longitude: row.longitude,
                locationName: row.location_name,
                likes: Int(row.likes_count ?? 0),
                isLiked: nil,
                isSaved: nil,
                createdAt: parseTimestamptz(row.created_at),
                authorIsPrivate: row.author_is_private_snapshot,
                imageURLs: nil,
                mediaDisplayAspectRatio: row.media_display_aspect_ratio,
                mediaCount: row.media_count.map { Int($0) },
                authorIsPro: authorPro
            )
        }
    }

    static func fetchFeedSpotsForAuthors(userIds: [UUID], limit: Int, offset: Int) async throws -> [Spot] {
        guard !userIds.isEmpty else { return [] }
        let rows: [SpotRow] = try await supabase
            .from("spots")
            .select(spotRowSelectColumns)
            .in("user_id", values: userIds)
            .order("created_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value
        return try await mapRowsToSpotsPerAuthor(rows)
    }

    /// Home feed rows only include a single `vibe_name` — load full ordered junction list + author Pro for card display.
    static func enrichSpotsForCardPresentation(_ spots: [Spot]) async throws -> [Spot] {
        let spotUUIDs = spots.compactMap { $0.id }.compactMap(UUID.init)
        guard !spotUUIDs.isEmpty else { return spots }

        async let labelTask = fetchVibeLabelListsBySpotId(spotIds: spotUUIDs)
        let userUUIDs = Array(Set(spots.compactMap { $0.userId }.compactMap(UUID.init)))
        async let proTask = fetchAuthorProFlags(userIds: userUUIDs)

        let (labelMap, proMap) = try await (labelTask, proTask)

        return spots.map { s in
            var m = s
            if let sid = s.id, let u = UUID(uuidString: sid), let labs = labelMap[u], !labs.isEmpty {
                m.vibeTags = labs
                m.vibeTag = labs.first
            }
            if let uid = s.userId {
                m.authorIsPro = proMap[uid]
            }
            return m
        }
    }

    private static func fetchAuthorProFlags(userIds: [UUID]) async throws -> [String: Bool] {
        guard !userIds.isEmpty else { return [:] }
        let users: [UserBriefRow] = try await supabase
            .from(SupabaseTableName.usersPublic)
            .select("id,is_pro,pro_until")
            .in("id", values: userIds)
            .execute()
            .value
        var out: [String: Bool] = [:]
        for u in users {
            out[u.id.uuidString] = EffectiveProResolver.effectiveIsPro(isPro: u.is_pro ?? false, proUntilRaw: u.pro_until)
        }
        return out
    }

    // MARK: - Publish (storage + inserts)

    private struct SpotIdRow: Decodable { let id: UUID }

    private struct UserPrivateRow: Decodable { let is_private: Bool }

    /// Resolve or create a row in `vibe_tags` and return its id.
    static func resolveOrCreateVibeTagId(displayName: String) async throws -> UUID {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            throw NSError(domain: "SpotSupabaseRepository", code: 0, userInfo: [NSLocalizedDescriptionKey: "Empty vibe name"])
        }
        let lower = name.lowercased()
        struct IdOnly: Decodable { let id: UUID }
        let existing: [IdOnly] = try await supabase
            .from("vibe_tags")
            .select("id")
            .eq("name_lower", value: lower)
            .limit(1)
            .execute()
            .value
        if let id = existing.first?.id { return id }

        struct VibeInsert: Encodable {
            let name: String
            let name_lower: String
        }
        do {
            let inserted: IdOnly = try await supabase
                .from("vibe_tags")
                .insert(VibeInsert(name: name, name_lower: lower))
                .select("id")
                .single()
                .execute()
                .value
            return inserted.id
        } catch {
            let again: [IdOnly] = try await supabase
                .from("vibe_tags")
                .select("id")
                .eq("name_lower", value: lower)
                .limit(1)
                .execute()
                .value
            guard let id = again.first?.id else { throw error }
            return id
        }
    }

    private struct VibeTagPickerRow: Decodable {
        let id: UUID
        let name: String
        let name_lower: String?
    }

    /// Canonical rows from `vibe_tags` for search and post composer (ordered by `name_lower`).
    static func fetchVibeTagsForPicker(limit: Int = 1000) async throws -> [VibeTag] {
        let rows: [VibeTagPickerRow] = try await supabase
            .from("vibe_tags")
            .select("id,name,name_lower")
            .order("name_lower", ascending: true)
            .limit(limit)
            .execute()
            .value
        return rows.map { r in
            VibeTag(
                id: r.id.uuidString,
                name: r.name,
                name_lower: r.name_lower ?? r.name.lowercased(),
                createdAt: nil
            )
        }
    }

    /// Pending upload → Edge Function `moderate-image` → RPC `publish_spot_with_approved_media_assets_v1`.
    static func publishSpotFromDraft(
        userId: UUID,
        imageJPEGs: [Data],
        vibeTags: [String],
        latitude: Double,
        longitude: Double,
        locationName: String,
        progress: (@MainActor @Sendable (SpotPublishProgress) -> Void)? = nil
    ) async throws -> UUID {
        guard !imageJPEGs.isEmpty else {
            throw NSError(domain: "SpotSupabaseRepository", code: 0, userInfo: [NSLocalizedDescriptionKey: "No images"])
        }

        guard !vibeTags.isEmpty else {
            throw NSError(domain: "SpotSupabaseRepository", code: 0, userInfo: [NSLocalizedDescriptionKey: "At least one vibe is required"])
        }
        
        // Validate coordinates
        if let coordError = InputValidation.validateCoordinates(latitude: latitude, longitude: longitude) {
            throw NSError(domain: "SpotSupabaseRepository", code: 400, userInfo: [NSLocalizedDescriptionKey: coordError])
        }
        
        // Validate location name
        if let locationError = InputValidation.validateLocationName(locationName) {
            throw NSError(domain: "SpotSupabaseRepository", code: 400, userInfo: [NSLocalizedDescriptionKey: locationError])
        }
        await progress?(.resolvingVibes)
        var vibeIds: [UUID] = []
        vibeIds.reserveCapacity(vibeTags.count)
        for tag in vibeTags {
            vibeIds.append(try await resolveOrCreateVibeTagId(displayName: tag))
        }

        struct MediaAssetInsert: Encodable {
            let id: UUID
            let owner_id: UUID
            let kind: String
            let status: String
            let pending_bucket: String
            let pending_path: String
            let mime_type: String
            let byte_size: Int
            let width: Int?
            let height: Int?
        }

        struct PublishSpotRpcParams: Encodable {
            let p_vibe_tag_ids: [UUID]
            let p_latitude: Double
            let p_longitude: Double
            let p_location_name: String
            let p_media_asset_ids: [UUID]
        }

        var approvedAssetIds: [UUID] = []
        for (index, data) in imageJPEGs.enumerated() {
            await progress?(.uploadingPhoto(index: index, total: imageJPEGs.count))
            let assetId = UUID()
            let path = "\(userId.uuidString.lowercased())/\(assetId.uuidString.lowercased()).jpg"
            let pixelSize = SpotJPEGImageDimensions.pixelSize(jpeg: data)
            if let pixelSize {
                SpotLogger.log(SpotMediaLayoutLogs.jpegDimensionsRead, details: [
                    "assetId": assetId.uuidString,
                    "width": pixelSize.width,
                    "height": pixelSize.height,
                ])
                let displayRatio = SpotMediaAspectRatio.display(width: pixelSize.width, height: pixelSize.height)
                SpotLogger.log(SpotMediaLayoutLogs.displayRatioCalculated, details: [
                    "assetId": assetId.uuidString,
                    "displayRatio": String(describing: Double(displayRatio)),
                ])
            }
            try await supabase
                .from("media_assets")
                .insert(MediaAssetInsert(
                    id: assetId,
                    owner_id: userId,
                    kind: "spot_image",
                    status: "pending",
                    pending_bucket: pendingImagesBucketId,
                    pending_path: path,
                    mime_type: "image/jpeg",
                    byte_size: data.count,
                    width: pixelSize?.width,
                    height: pixelSize?.height
                ))
                .execute()
            if pixelSize != nil {
                SpotLogger.log(SpotMediaLayoutLogs.mediaAssetDimensionsAttached, details: ["assetId": assetId.uuidString])
            }

            try await supabase.storage
                .from(pendingImagesBucketId)
                .upload(path, data: data, options: FileOptions(contentType: "image/jpeg", upsert: true))

            await progress?(.checkingPhoto(index: index, total: imageJPEGs.count))
            let moderate = try await invokeModerateImageFunction(mediaAssetId: assetId)
            guard moderate.approved else {
                if moderate.reason == "image_policy_rejected" {
                    throw NSError(
                        domain: "SpotImageModeration",
                        code: 422,
                        userInfo: [NSLocalizedDescriptionKey: "One of your photos can't be posted. Please replace it and try again."]
                    )
                }
                    throw NSError(
                        domain: "SpotImageModeration",
                        code: 503,
                        userInfo: [NSLocalizedDescriptionKey: "We couldn't check one of your photos. Please try again."]
                    )
            }
            approvedAssetIds.append(assetId)
        }

        await progress?(.publishing)
        let trimmedPlace = locationName.trimmingCharacters(in: .whitespacesAndNewlines)
        let spotIdString: String = try await supabase.rpc(
            "publish_spot_with_approved_media_assets_v1",
            params: PublishSpotRpcParams(
                p_vibe_tag_ids: vibeIds,
                p_latitude: latitude,
                p_longitude: longitude,
                p_location_name: trimmedPlace,
                p_media_asset_ids: approvedAssetIds
            )
        )
        .execute()
        .value

        guard let spotId = UUID(uuidString: spotIdString) else {
            throw NSError(domain: "SpotSupabaseRepository", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid spot id from server"])
        }
        return spotId
    }

    /// Signed URL for the first image on a newly published spot (any approved storage bucket).
    static func signFirstImageURLForSpot(spotId: UUID) async throws -> String? {
        struct Row: Decodable {
            let storage_path: String?
            let storage_bucket: String?
            let sort_index: Int
        }
        let rows: [Row] = try await supabase
            .from("spot_images")
            .select("storage_path,storage_bucket,sort_index")
            .eq("spot_id", value: spotId)
            .order("sort_index", ascending: true)
            .limit(1)
            .execute()
            .value
        guard let row = rows.first else { return nil }
        let ref = row.storage_path?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if ref.isEmpty { return nil }
        if isStoredAbsoluteURL(ref) { return ref }
        let bucket = row.storage_bucket ?? spotsStorageBucketId
        return try await supabase.storage
            .from(bucket)
            .createSignedURL(path: ref, expiresIn: spotImageSignedURLExpirySeconds)
            .absoluteString
    }

    /// Parses Edge Function JSON. **Contract:** body must include boolean `approved` (see `supabase/functions/moderate-image/index.ts`).
    /// A placeholder that returns only `{ "ok": true }` will parse as not approved and trigger the generic 503 user message.
    static func parseModerateImageJSON(_ data: Data) -> (approved: Bool, reason: String?, jsonKeys: String) {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (false, "moderation_unavailable", "")
        }
        let keys = obj.keys.sorted().joined(separator: ",")
        let approved = obj["approved"] as? Bool ?? false
        let reason =
            (obj["reason"] as? String)
            ?? (obj["error"] as? String)
        return (approved, reason, keys)
    }

    private static func invokeModerateImageFunction(mediaAssetId: UUID) async throws -> (approved: Bool, reason: String?) {
        let session = try await supabase.auth.session
        supabase.functions.setAuth(token: session.accessToken)
        let url = SupabasePlist.baseURL
            .appendingPathComponent("functions")
            .appendingPathComponent("v1")
            .appendingPathComponent("moderate-image")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(SupabasePlist.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["mediaAssetId": mediaAssetId.uuidString])
        let (data, resp) = try await URLSession.shared.data(for: req)
        let parsed = parseModerateImageJSON(data)
        guard let http = resp as? HTTPURLResponse else {
            SpotLogger.log(SpotImageModerationLogs.moderateInvokeUnexpectedResponse, details: [
                "mediaAssetId": mediaAssetId.uuidString,
                "reason": "non_http_response",
            ])
            return (false, "moderation_unavailable")
        }

        let bodyPrefix = String(String(data: data, encoding: .utf8) ?? "").prefix(500)
        let outcome: (Bool, String?)
        if http.statusCode >= 500 {
            outcome = (false, parsed.reason ?? "moderation_unavailable")
        } else if http.statusCode == 422 {
            outcome = (parsed.approved, parsed.reason)
        } else if http.statusCode >= 400 {
            outcome = (false, parsed.reason ?? "moderation_unavailable")
        } else {
            outcome = (parsed.approved, parsed.reason)
        }

        if !outcome.0 {
            let isExpectedPolicy =
                http.statusCode == 422 && outcome.1 == "image_policy_rejected"
            if isExpectedPolicy {
                SpotLogger.log(SpotImageModerationLogs.policyRejectedByEdgeFunction, details: [
                    "mediaAssetId": mediaAssetId.uuidString,
                ])
            } else {
                SpotLogger.log(SpotImageModerationLogs.moderateInvokeUnexpectedResponse, details: [
                    "mediaAssetId": mediaAssetId.uuidString,
                    "httpStatus": String(http.statusCode),
                    "reason": outcome.1 ?? "",
                    "jsonKeys": parsed.jsonKeys,
                    "bodyPrefix": String(bodyPrefix),
                ])
            }
        }

        return outcome
    }
}

//
//  FeedAPI.swift
//  Spot
//
//  Supabase RPC client for the v2 home feed pipeline (`get_home_feed_v1`,
//  `get_home_feed_status_v1`, `get_map_spots_v1`). The server returns final,
//  filtered, ranked feed rows; the iOS app only signs the primary image for
//  each returned row, leaving full image arrays for the detail view.
//

import Foundation
import Supabase

// MARK: - Server contract

/// One row returned by `public.get_home_feed_v1`. Mirrors the Postgres function
/// return signature 1:1; treat it as a transport DTO only — convert to `Spot`
/// for UI rendering.
struct HomeFeedRow: Decodable, Identifiable, Hashable {
    let spotId: UUID
    let userId: UUID
    let vibeTagId: UUID?
    let caption: String?
    let latitude: Double?
    let longitude: Double?
    let locationName: String?
    let likesCount: Int64?
    let savesCount: Int64?
    let createdAt: Date?
    let updatedAt: Date?
    let authorUsername: String?
    let authorProfileImageUrl: String?
    let authorIsPrivate: Bool?
    let vibeName: String?
    let primaryStoragePath: String?
    let primaryPublicUrl: String?
    /// Supabase Storage bucket for `primaryStoragePath` (e.g. `spots` or
    /// `approved_spot_images`). Nil/empty → client falls back to legacy `spots`.
    let primaryStorageBucket: String?
    let sourceBucket: String
    let rankPosition: Int
    let rankingScore: Double
    let seenBefore: Bool
    let lastSeenAt: Date?
    /// When present (requires RPC update server-side), drives feed card media height before image load.
    let mediaDisplayAspectRatio: Double?

    var id: UUID { spotId }

    private enum CodingKeys: String, CodingKey {
        case spotId = "spot_id"
        case userId = "user_id"
        case vibeTagId = "vibe_tag_id"
        case caption
        case latitude
        case longitude
        case locationName = "location_name"
        case likesCount = "likes_count"
        case savesCount = "saves_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case authorUsername = "author_username"
        case authorProfileImageUrl = "author_profile_image_url"
        case authorIsPrivate = "author_is_private"
        case vibeName = "vibe_name"
        case primaryStoragePath = "primary_storage_path"
        case primaryPublicUrl = "primary_public_url"
        case primaryStorageBucket = "primary_storage_bucket"
        case sourceBucket = "source_bucket"
        case rankPosition = "rank_position"
        case rankingScore = "ranking_score"
        case seenBefore = "seen_before"
        case lastSeenAt = "last_seen_at"
        case mediaDisplayAspectRatio = "media_display_aspect_ratio"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        spotId = try c.decode(UUID.self, forKey: .spotId)
        userId = try c.decode(UUID.self, forKey: .userId)
        vibeTagId = try c.decodeIfPresent(UUID.self, forKey: .vibeTagId)
        caption = try c.decodeIfPresent(String.self, forKey: .caption)
        latitude = try c.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try c.decodeIfPresent(Double.self, forKey: .longitude)
        locationName = try c.decodeIfPresent(String.self, forKey: .locationName)
        likesCount = try c.decodeIfPresent(Int64.self, forKey: .likesCount)
        savesCount = try c.decodeIfPresent(Int64.self, forKey: .savesCount)
        createdAt = SpotSupabaseRepository.parseTimestamptz(try c.decodeIfPresent(String.self, forKey: .createdAt))
        updatedAt = SpotSupabaseRepository.parseTimestamptz(try c.decodeIfPresent(String.self, forKey: .updatedAt))
        authorUsername = try c.decodeIfPresent(String.self, forKey: .authorUsername)
        authorProfileImageUrl = try c.decodeIfPresent(String.self, forKey: .authorProfileImageUrl)
        authorIsPrivate = try c.decodeIfPresent(Bool.self, forKey: .authorIsPrivate)
        vibeName = try c.decodeIfPresent(String.self, forKey: .vibeName)
        primaryStoragePath = try c.decodeIfPresent(String.self, forKey: .primaryStoragePath)
        primaryPublicUrl = try c.decodeIfPresent(String.self, forKey: .primaryPublicUrl)
        primaryStorageBucket = try c.decodeIfPresent(String.self, forKey: .primaryStorageBucket)
        sourceBucket = try c.decodeIfPresent(String.self, forKey: .sourceBucket) ?? "personalized_unseen"
        rankPosition = try c.decodeIfPresent(Int.self, forKey: .rankPosition) ?? 0
        rankingScore = try c.decodeIfPresent(Double.self, forKey: .rankingScore) ?? 0
        seenBefore = try c.decodeIfPresent(Bool.self, forKey: .seenBefore) ?? false
        lastSeenAt = SpotSupabaseRepository.parseTimestamptz(try c.decodeIfPresent(String.self, forKey: .lastSeenAt))
        mediaDisplayAspectRatio = try c.decodeIfPresent(Double.self, forKey: .mediaDisplayAspectRatio)
    }
}

/// Diagnostics returned by `public.get_home_feed_status_v1`, used when the feed
/// returns zero rows so the UI can show the right empty/error state.
struct HomeFeedStatus: Decodable, Hashable {
    let totalSpots: Int
    let eligibleSpots: Int
    let unseenEligibleSpots: Int
    let seenEligibleSpots: Int
    /// Raw status string from Postgres: `has_unseen` | `caught_up` |
    /// `no_eligible_spots` | `no_spots_global`.
    let status: String

    private enum CodingKeys: String, CodingKey {
        case totalSpots = "total_spots"
        case eligibleSpots = "eligible_spots"
        case unseenEligibleSpots = "unseen_eligible_spots"
        case seenEligibleSpots = "seen_eligible_spots"
        case status
    }
}

// MARK: - User feed profile snapshot (jsonb)

/// Row shape for `public.user_feed_profiles`. The heavy data lives inside
/// `profile` (jsonb). The row is RLS-protected: each authenticated user can
/// only `select` their own row.
struct FeedProfileRow: Decodable {
    let userId: UUID
    let profileVersion: Int
    let profile: FeedProfile
    let lastComputedAt: Date?
    let createdAt: Date?
    let updatedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case profileVersion = "profile_version"
        case profile
        case lastComputedAt = "last_computed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        userId = try c.decode(UUID.self, forKey: .userId)
        profileVersion = try c.decodeIfPresent(Int.self, forKey: .profileVersion) ?? 1
        profile = try c.decode(FeedProfile.self, forKey: .profile)
        lastComputedAt = SpotSupabaseRepository.parseTimestamptz(try c.decodeIfPresent(String.self, forKey: .lastComputedAt))
        createdAt = SpotSupabaseRepository.parseTimestamptz(try c.decodeIfPresent(String.self, forKey: .createdAt))
        updatedAt = SpotSupabaseRepository.parseTimestamptz(try c.decodeIfPresent(String.self, forKey: .updatedAt))
    }
}

/// JSON snapshot of a user's personalization state, computed by
/// `public.recompute_user_feed_profile_v1` and refreshed every ~3h by cron.
/// Mirrors the jsonb shape 1:1.
struct FeedProfile: Decodable, Hashable {
    let version: Int
    let computedAt: Date?
    let stats: Stats
    let topVibes: [TopVibe]
    let topCreators: [TopCreator]
    let rankerConstants: RankerConstants
    let eventSummary30d: EventSummary
    let eventSummary90d: EventSummary

    private enum CodingKeys: String, CodingKey {
        case version
        case computedAt = "computed_at"
        case stats
        case topVibes = "top_vibes"
        case topCreators = "top_creators"
        case rankerConstants = "ranker_constants"
        case eventSummary30d = "event_summary_30d"
        case eventSummary90d = "event_summary_90d"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        computedAt = SpotSupabaseRepository.parseTimestamptz(try c.decodeIfPresent(String.self, forKey: .computedAt))
        stats = try c.decodeIfPresent(Stats.self, forKey: .stats) ?? .zero
        topVibes = try c.decodeIfPresent([TopVibe].self, forKey: .topVibes) ?? []
        topCreators = try c.decodeIfPresent([TopCreator].self, forKey: .topCreators) ?? []
        rankerConstants = try c.decodeIfPresent(RankerConstants.self, forKey: .rankerConstants) ?? .empty
        eventSummary30d = try c.decodeIfPresent(EventSummary.self, forKey: .eventSummary30d) ?? .empty(windowDays: 30)
        eventSummary90d = try c.decodeIfPresent(EventSummary.self, forKey: .eventSummary90d) ?? .empty(windowDays: 90)
    }

    struct Stats: Decodable, Hashable {
        let likesCount: Int
        let savesCount: Int
        let spotsCount: Int
        let blocksCount: Int
        let hiddenCount: Int
        let followsCount: Int
        let followersCount: Int
        let distinctVibesEngaged: Int
        let distinctCreatorsEngaged: Int

        static let zero = Stats(
            likesCount: 0, savesCount: 0, spotsCount: 0,
            blocksCount: 0, hiddenCount: 0,
            followsCount: 0, followersCount: 0,
            distinctVibesEngaged: 0, distinctCreatorsEngaged: 0
        )

        private enum CodingKeys: String, CodingKey {
            case likesCount = "likes_count"
            case savesCount = "saves_count"
            case spotsCount = "spots_count"
            case blocksCount = "blocks_count"
            case hiddenCount = "hidden_count"
            case followsCount = "follows_count"
            case followersCount = "followers_count"
            case distinctVibesEngaged = "distinct_vibes_engaged"
            case distinctCreatorsEngaged = "distinct_creators_engaged"
        }

        init(
            likesCount: Int, savesCount: Int, spotsCount: Int,
            blocksCount: Int, hiddenCount: Int,
            followsCount: Int, followersCount: Int,
            distinctVibesEngaged: Int, distinctCreatorsEngaged: Int
        ) {
            self.likesCount = likesCount
            self.savesCount = savesCount
            self.spotsCount = spotsCount
            self.blocksCount = blocksCount
            self.hiddenCount = hiddenCount
            self.followsCount = followsCount
            self.followersCount = followersCount
            self.distinctVibesEngaged = distinctVibesEngaged
            self.distinctCreatorsEngaged = distinctCreatorsEngaged
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            likesCount = try c.decodeIfPresent(Int.self, forKey: .likesCount) ?? 0
            savesCount = try c.decodeIfPresent(Int.self, forKey: .savesCount) ?? 0
            spotsCount = try c.decodeIfPresent(Int.self, forKey: .spotsCount) ?? 0
            blocksCount = try c.decodeIfPresent(Int.self, forKey: .blocksCount) ?? 0
            hiddenCount = try c.decodeIfPresent(Int.self, forKey: .hiddenCount) ?? 0
            followsCount = try c.decodeIfPresent(Int.self, forKey: .followsCount) ?? 0
            followersCount = try c.decodeIfPresent(Int.self, forKey: .followersCount) ?? 0
            distinctVibesEngaged = try c.decodeIfPresent(Int.self, forKey: .distinctVibesEngaged) ?? 0
            distinctCreatorsEngaged = try c.decodeIfPresent(Int.self, forKey: .distinctCreatorsEngaged) ?? 0
        }
    }

    struct TopVibe: Decodable, Hashable, Identifiable {
        let vibeTagId: UUID?
        let name: String
        let score: Double
        let positiveEvents: Int
        let negativeEvents: Int
        let totalEvents: Int
        let lastEventAt: Date?

        var id: String { vibeTagId?.uuidString ?? name }

        private enum CodingKeys: String, CodingKey {
            case vibeTagId = "vibe_tag_id"
            case name
            case score
            case positiveEvents = "positive_events"
            case negativeEvents = "negative_events"
            case totalEvents = "total_events"
            case lastEventAt = "last_event_at"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            vibeTagId = try c.decodeIfPresent(UUID.self, forKey: .vibeTagId)
            name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
            score = try c.decodeIfPresent(Double.self, forKey: .score) ?? 0
            positiveEvents = try c.decodeIfPresent(Int.self, forKey: .positiveEvents) ?? 0
            negativeEvents = try c.decodeIfPresent(Int.self, forKey: .negativeEvents) ?? 0
            totalEvents = try c.decodeIfPresent(Int.self, forKey: .totalEvents) ?? 0
            lastEventAt = SpotSupabaseRepository.parseTimestamptz(try c.decodeIfPresent(String.self, forKey: .lastEventAt))
        }
    }

    struct TopCreator: Decodable, Hashable, Identifiable {
        let creatorId: UUID
        let username: String?
        let profileImageURL: String?
        let isPrivate: Bool
        let isPro: Bool
        let score: Double
        let positiveEvents: Int
        let negativeEvents: Int
        let totalEvents: Int
        let lastEventAt: Date?

        var id: UUID { creatorId }

        private enum CodingKeys: String, CodingKey {
            case creatorId = "creator_id"
            case username
            case profileImageURL = "profile_image_url"
            case isPrivate = "is_private"
            case isPro = "is_pro"
            case score
            case positiveEvents = "positive_events"
            case negativeEvents = "negative_events"
            case totalEvents = "total_events"
            case lastEventAt = "last_event_at"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            creatorId = try c.decode(UUID.self, forKey: .creatorId)
            username = try c.decodeIfPresent(String.self, forKey: .username)
            profileImageURL = try c.decodeIfPresent(String.self, forKey: .profileImageURL)
            isPrivate = try c.decodeIfPresent(Bool.self, forKey: .isPrivate) ?? false
            isPro = try c.decodeIfPresent(Bool.self, forKey: .isPro) ?? false
            score = try c.decodeIfPresent(Double.self, forKey: .score) ?? 0
            positiveEvents = try c.decodeIfPresent(Int.self, forKey: .positiveEvents) ?? 0
            negativeEvents = try c.decodeIfPresent(Int.self, forKey: .negativeEvents) ?? 0
            totalEvents = try c.decodeIfPresent(Int.self, forKey: .totalEvents) ?? 0
            lastEventAt = SpotSupabaseRepository.parseTimestamptz(try c.decodeIfPresent(String.self, forKey: .lastEventAt))
        }
    }

    /// Snapshot of the server-side ranker config used to produce this profile.
    /// Kept loose (`[String: Double]`) so server config changes don't break decoding.
    struct RankerConstants: Decodable, Hashable {
        let affinitySigmoidK: Double?
        let affinityClamp: [Double]
        let weightsPersonalized: [String: Double]
        let weightsSeenFallback: [String: Double]
        let freshnessHalfLifeHours: Double?
        let distanceFullScoreMeters: Double?

        static let empty = RankerConstants(
            affinitySigmoidK: nil,
            affinityClamp: [],
            weightsPersonalized: [:],
            weightsSeenFallback: [:],
            freshnessHalfLifeHours: nil,
            distanceFullScoreMeters: nil
        )

        private enum CodingKeys: String, CodingKey {
            case affinitySigmoidK = "affinity_sigmoid_k"
            case affinityClamp = "affinity_clamp"
            case weightsPersonalized = "weights_personalized"
            case weightsSeenFallback = "weights_seen_fallback"
            case freshnessHalfLifeHours = "freshness_half_life_hours"
            case distanceFullScoreMeters = "distance_full_score_meters"
        }

        init(
            affinitySigmoidK: Double?,
            affinityClamp: [Double],
            weightsPersonalized: [String: Double],
            weightsSeenFallback: [String: Double],
            freshnessHalfLifeHours: Double?,
            distanceFullScoreMeters: Double?
        ) {
            self.affinitySigmoidK = affinitySigmoidK
            self.affinityClamp = affinityClamp
            self.weightsPersonalized = weightsPersonalized
            self.weightsSeenFallback = weightsSeenFallback
            self.freshnessHalfLifeHours = freshnessHalfLifeHours
            self.distanceFullScoreMeters = distanceFullScoreMeters
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            affinitySigmoidK = try c.decodeIfPresent(Double.self, forKey: .affinitySigmoidK)
            affinityClamp = try c.decodeIfPresent([Double].self, forKey: .affinityClamp) ?? []
            weightsPersonalized = try c.decodeIfPresent([String: Double].self, forKey: .weightsPersonalized) ?? [:]
            weightsSeenFallback = try c.decodeIfPresent([String: Double].self, forKey: .weightsSeenFallback) ?? [:]
            freshnessHalfLifeHours = try c.decodeIfPresent(Double.self, forKey: .freshnessHalfLifeHours)
            distanceFullScoreMeters = try c.decodeIfPresent(Double.self, forKey: .distanceFullScoreMeters)
        }
    }

    struct EventSummary: Decodable, Hashable {
        let windowDays: Int
        let total: Int
        let positiveTotalStrength: Double
        let negativeTotalStrength: Double
        let byType: [Bucket]

        static func empty(windowDays: Int) -> EventSummary {
            EventSummary(windowDays: windowDays, total: 0, positiveTotalStrength: 0, negativeTotalStrength: 0, byType: [])
        }

        private enum CodingKeys: String, CodingKey {
            case windowDays = "window_days"
            case total
            case positiveTotalStrength = "positive_total_strength"
            case negativeTotalStrength = "negative_total_strength"
            case byType = "by_type"
        }

        init(windowDays: Int, total: Int, positiveTotalStrength: Double, negativeTotalStrength: Double, byType: [Bucket]) {
            self.windowDays = windowDays
            self.total = total
            self.positiveTotalStrength = positiveTotalStrength
            self.negativeTotalStrength = negativeTotalStrength
            self.byType = byType
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            windowDays = try c.decodeIfPresent(Int.self, forKey: .windowDays) ?? 0
            total = try c.decodeIfPresent(Int.self, forKey: .total) ?? 0
            positiveTotalStrength = try c.decodeIfPresent(Double.self, forKey: .positiveTotalStrength) ?? 0
            negativeTotalStrength = try c.decodeIfPresent(Double.self, forKey: .negativeTotalStrength) ?? 0
            byType = try c.decodeIfPresent([Bucket].self, forKey: .byType) ?? []
        }

        struct Bucket: Decodable, Hashable, Identifiable {
            let eventType: String
            let count: Int
            let totalStrength: Double

            var id: String { eventType }

            private enum CodingKeys: String, CodingKey {
                case eventType = "event_type"
                case count = "n"
                case totalStrength = "total_strength"
            }

            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                eventType = try c.decodeIfPresent(String.self, forKey: .eventType) ?? ""
                count = try c.decodeIfPresent(Int.self, forKey: .count) ?? 0
                totalStrength = try c.decodeIfPresent(Double.self, forKey: .totalStrength) ?? 0
            }
        }
    }
}

/// One row returned by `public.get_map_spots_v1`. Lightweight: no full image
/// array, just the primary image reference + distance from viewport center.
struct MapSpotRow: Decodable, Identifiable, Hashable {
    let spotId: UUID
    let userId: UUID
    let vibeTagId: UUID?
    let caption: String?
    let latitude: Double?
    let longitude: Double?
    let locationName: String?
    let createdAt: Date?
    let authorUsername: String?
    let authorProfileImageUrl: String?
    let vibeName: String?
    let primaryStoragePath: String?
    let primaryPublicUrl: String?
    /// Supabase Storage bucket for `primaryStoragePath`. Nil/empty → legacy `spots`.
    let primaryStorageBucket: String?
    let distanceMeters: Double?
    let mediaDisplayAspectRatio: Double?

    var id: UUID { spotId }

    private enum CodingKeys: String, CodingKey {
        case spotId = "spot_id"
        case userId = "user_id"
        case vibeTagId = "vibe_tag_id"
        case caption
        case latitude
        case longitude
        case locationName = "location_name"
        case createdAt = "created_at"
        case authorUsername = "author_username"
        case authorProfileImageUrl = "author_profile_image_url"
        case vibeName = "vibe_name"
        case primaryStoragePath = "primary_storage_path"
        case primaryPublicUrl = "primary_public_url"
        case primaryStorageBucket = "primary_storage_bucket"
        case distanceMeters = "distance_meters"
        case mediaDisplayAspectRatio = "media_display_aspect_ratio"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        spotId = try c.decode(UUID.self, forKey: .spotId)
        userId = try c.decode(UUID.self, forKey: .userId)
        vibeTagId = try c.decodeIfPresent(UUID.self, forKey: .vibeTagId)
        caption = try c.decodeIfPresent(String.self, forKey: .caption)
        latitude = try c.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try c.decodeIfPresent(Double.self, forKey: .longitude)
        locationName = try c.decodeIfPresent(String.self, forKey: .locationName)
        createdAt = SpotSupabaseRepository.parseTimestamptz(try c.decodeIfPresent(String.self, forKey: .createdAt))
        authorUsername = try c.decodeIfPresent(String.self, forKey: .authorUsername)
        authorProfileImageUrl = try c.decodeIfPresent(String.self, forKey: .authorProfileImageUrl)
        vibeName = try c.decodeIfPresent(String.self, forKey: .vibeName)
        primaryStoragePath = try c.decodeIfPresent(String.self, forKey: .primaryStoragePath)
        primaryPublicUrl = try c.decodeIfPresent(String.self, forKey: .primaryPublicUrl)
        primaryStorageBucket = try c.decodeIfPresent(String.self, forKey: .primaryStorageBucket)
        distanceMeters = try c.decodeIfPresent(Double.self, forKey: .distanceMeters)
        mediaDisplayAspectRatio = try c.decodeIfPresent(Double.self, forKey: .mediaDisplayAspectRatio)
    }
}

// MARK: - Client

/// Supabase RPC client for the v2 home feed + map pipeline.
///
/// All filtering, ranking, dedupe, and impression bookkeeping happens
/// server-side. The client only:
///  1. Calls the RPC,
///  2. Signs primary image URLs for the (small) returned page,
///  3. Maps `HomeFeedRow` → `Spot` for UI rendering.
enum FeedAPI {
    /// Legacy default when `spot_images.storage_bucket` / RPC column is absent.
    private static let spotsStorageBucketId = "spots"
    /// Signed-URL lifetime; matches existing feed image expiry (7 days).
    private static let spotImageSignedURLExpirySeconds = 604_800

    /// Resolves the Storage bucket id for a primary image path.
    static func resolvedPrimaryStorageBucket(_ raw: String?) -> String {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? spotsStorageBucketId : trimmed
    }

    // MARK: get_home_feed_v1

    /// Calls `public.get_home_feed_v1`. Server marks returned rows as seen
    /// (durable `feed_impressions`) before returning, so a subsequent call
    /// will surface unseen rows next.
    static func fetchHomeFeed(
        limit: Int = FeedFlags.pageSize,
        viewerLatitude: Double?,
        viewerLongitude: Double?,
        forceSeenFallback: Bool = false
    ) async throws -> [HomeFeedRow] {
        struct Params: Encodable {
            let p_limit: Int
            let p_viewer_lat: Double?
            let p_viewer_lng: Double?
            let p_batch_id: String
            let p_force_seen_fallback: Bool
        }

        let params = Params(
            p_limit: limit,
            p_viewer_lat: viewerLatitude,
            p_viewer_lng: viewerLongitude,
            p_batch_id: UUID().uuidString.lowercased(),
            p_force_seen_fallback: forceSeenFallback
        )

        let started = Date()
        do {
            let rows: [HomeFeedRow] = try await supabase
                .rpc("get_home_feed_v1", params: params)
                .execute()
                .value
            let durationMs = Int(Date().timeIntervalSince(started) * 1000)
            SpotLogger.log(FeedSupabaseLogs.rpcSucceeded, details: [
                "returned": rows.count,
                "limit": limit,
                "forceSeenFallback": forceSeenFallback,
                "hasViewerLocation": viewerLatitude != nil && viewerLongitude != nil,
                "durationMs": durationMs
            ])
            return rows
        } catch {
            let durationMs = Int(Date().timeIntervalSince(started) * 1000)
            SpotLogger.log(FeedSupabaseLogs.rpcFailed, details: [
                "durationMs": durationMs,
                "limit": limit,
                "forceSeenFallback": forceSeenFallback,
                "error": error.localizedDescription
            ])
            throw error
        }
    }

    // MARK: get_home_feed_status_v1

    /// Calls `public.get_home_feed_status_v1` to disambiguate empty feed
    /// responses (true zero content vs. caught-up vs. all-blocked, etc.).
    static func fetchHomeFeedStatus() async throws -> HomeFeedStatus {
        let started = Date()
        do {
            let rows: [HomeFeedStatus] = try await supabase
                .rpc("get_home_feed_status_v1")
                .execute()
                .value
            guard let status = rows.first else {
                throw NSError(
                    domain: "FeedAPI",
                    code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "get_home_feed_status_v1 returned no rows"]
                )
            }
            let durationMs = Int(Date().timeIntervalSince(started) * 1000)
            SpotLogger.log(FeedSupabaseLogs.statusFetched, details: [
                "status": status.status,
                "total": status.totalSpots,
                "eligible": status.eligibleSpots,
                "unseen": status.unseenEligibleSpots,
                "seen": status.seenEligibleSpots,
                "durationMs": durationMs
            ])
            return status
        } catch {
            let durationMs = Int(Date().timeIntervalSince(started) * 1000)
            SpotLogger.log(FeedSupabaseLogs.statusFailed, details: [
                "durationMs": durationMs,
                "error": error.localizedDescription
            ])
            throw error
        }
    }

    // MARK: get_map_spots_v1

    /// Calls `public.get_map_spots_v1` for a viewport. Visibility/block rules
    /// match the home feed; primary image is included; full image arrays are
    /// not fetched here (lazy in detail).
    static func fetchMapSpots(
        minLat: Double,
        minLng: Double,
        maxLat: Double,
        maxLng: Double,
        centerLat: Double,
        centerLng: Double,
        limit: Int = 250
    ) async throws -> [MapSpotRow] {
        struct Params: Encodable {
            let p_min_lat: Double
            let p_min_lng: Double
            let p_max_lat: Double
            let p_max_lng: Double
            let p_center_lat: Double
            let p_center_lng: Double
            let p_limit: Int
        }

        let params = Params(
            p_min_lat: minLat,
            p_min_lng: minLng,
            p_max_lat: maxLat,
            p_max_lng: maxLng,
            p_center_lat: centerLat,
            p_center_lng: centerLng,
            p_limit: limit
        )

        let started = Date()
        do {
            let rows: [MapSpotRow] = try await supabase
                .rpc("get_map_spots_v1", params: params)
                .execute()
                .value
            let durationMs = Int(Date().timeIntervalSince(started) * 1000)
            SpotLogger.log(FeedSupabaseLogs.mapRPCSucceeded, details: [
                "returned": rows.count,
                "limit": limit,
                "durationMs": durationMs
            ])
            return rows
        } catch {
            let durationMs = Int(Date().timeIntervalSince(started) * 1000)
            // URLSession cancellations from rapid pan/zoom are expected,
            // not real failures — log them as cancelled (debug-level via
            // the dedicated log key) instead of as RPC errors.
            if Self.isCancellationError(error) {
                SpotLogger.log(FeedSupabaseLogs.mapRPCCancelled, details: [
                    "durationMs": durationMs,
                    "limit": limit
                ])
            } else {
                SpotLogger.log(FeedSupabaseLogs.mapRPCFailed, details: [
                    "durationMs": durationMs,
                    "limit": limit,
                    "error": error.localizedDescription
                ])
            }
            throw error
        }
    }

    /// Detect URLSession / Swift task cancellation. These bubble up as
    /// `URLError(.cancelled)`, `CancellationError`, or simply a localized
    /// string of "cancelled".
    private static func isCancellationError(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if (error as NSError).code == NSURLErrorCancelled { return true }
        if let urlErr = error as? URLError, urlErr.code == .cancelled { return true }
        let msg = error.localizedDescription.lowercased()
        return msg == "cancelled" || msg.contains("cancelled")
    }

    // MARK: - User feed profile (algorithm snapshot)

    /// Fetches the signed-in user's cached algorithm snapshot from
    /// `public.user_feed_profiles`. RLS guarantees the row belongs to the
    /// caller. Returns `nil` when no row exists yet (the cron will fill one
    /// in on its next pass; clients can also call `recomputeMyFeedProfile()`).
    static func getMyFeedProfile() async throws -> FeedProfileRow? {
        let started = Date()
        do {
            let rows: [FeedProfileRow] = try await supabase
                .from("user_feed_profiles")
                .select("user_id,profile_version,profile,last_computed_at,created_at,updated_at")
                .limit(1)
                .execute()
                .value
            let durationMs = Int(Date().timeIntervalSince(started) * 1000)
            SpotLogger.log(FeedSupabaseLogs.feedProfileFetched, details: [
                "found": rows.first != nil,
                "durationMs": durationMs
            ])
            return rows.first
        } catch {
            let durationMs = Int(Date().timeIntervalSince(started) * 1000)
            SpotLogger.log(FeedSupabaseLogs.feedProfileFetchFailed, details: [
                "durationMs": durationMs,
                "error": error.localizedDescription
            ])
            throw error
        }
    }

    /// Returns the raw bytes of the caller's `user_feed_profiles` row, used
    /// only by the debug screen to render a faithful pretty-printed snapshot.
    /// We intentionally decode through an empty placeholder type so the
    /// PostgREST response body is exposed verbatim via `response.data`.
    static func getMyFeedProfileRawData() async throws -> Data {
        struct _EmptyRow: Decodable {}
        let response: PostgrestResponse<[_EmptyRow]> = try await supabase
            .from("user_feed_profiles")
            .select("user_id,profile_version,profile,last_computed_at,created_at,updated_at")
            .limit(1)
            .execute()
        return response.data
    }

    /// Forces a server-side recompute of the caller's profile (self-only).
    /// Useful for the debug screen and after a burst of fresh interactions
    /// when you want the "Your Algorithm" surface to feel live.
    /// Returns the freshly recomputed `FeedProfile`.
    static func recomputeMyFeedProfile() async throws -> FeedProfile {
        let started = Date()
        do {
            let profile: FeedProfile = try await supabase
                .rpc("recompute_my_feed_profile_v1")
                .execute()
                .value
            let durationMs = Int(Date().timeIntervalSince(started) * 1000)
            SpotLogger.log(FeedSupabaseLogs.feedProfileRecomputed, details: [
                "durationMs": durationMs,
                "topVibes": profile.topVibes.count,
                "topCreators": profile.topCreators.count
            ])
            return profile
        } catch {
            let durationMs = Int(Date().timeIntervalSince(started) * 1000)
            SpotLogger.log(FeedSupabaseLogs.feedProfileRecomputeFailed, details: [
                "durationMs": durationMs,
                "error": error.localizedDescription
            ])
            throw error
        }
    }

    // MARK: - Full image gallery (lazy)

    /// Fetches the full ordered image array for a single spot. Use this only
    /// when the user opens the spot detail / image gallery — the home feed
    /// lists deliberately carry just the primary image.
    static func fetchAllImageURLs(for spotId: UUID) async -> [String] {
        struct Row: Decodable {
            let storage_path: String?
            let public_url: String?
            let storage_bucket: String?
            let sort_index: Int
        }

        do {
            let rows: [Row] = try await supabase
                .from("spot_images")
                .select("storage_path,public_url,storage_bucket,sort_index")
                .eq("spot_id", value: spotId)
                .order("sort_index", ascending: true)
                .execute()
                .value

            var paths: [String] = []
            var buckets: [String?] = []
            for r in rows {
                let path = r.storage_path?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let publicUrl = r.public_url?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !path.isEmpty {
                    paths.append(path)
                    buckets.append(r.storage_bucket)
                } else if !publicUrl.isEmpty {
                    paths.append(publicUrl)
                    buckets.append(nil)
                }
            }
            return try await SpotSupabaseRepository.resolveStoredImageURLs(paths: paths, buckets: buckets)
        } catch {
            SpotLogger.log(FeedSupabaseLogs.primaryImageSignFailed, details: [
                "phase": "fullGallery",
                "spotId": spotId.uuidString,
                "error": error.localizedDescription
            ])
            return []
        }
    }

    // MARK: - Primary image resolution

    /// Resolves a single primary image URL for a row. Prefers an absolute
    /// HTTPS URL when present; otherwise signs the storage path. Only one
    /// network call per row, max — much cheaper than the legacy
    /// `mapRowsToSpotsPerAuthor` path which signed every candidate's images.
    static func resolvePrimaryImageURL(
        storagePath: String?,
        publicUrl: String?,
        storageBucket: String? = nil
    ) async -> String? {
        let trimmedPublic = publicUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmedPublic.lowercased().hasPrefix("https://") || trimmedPublic.lowercased().hasPrefix("http://") {
            return trimmedPublic
        }

        let path: String? = {
            let trimmedPath = storagePath?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !trimmedPath.isEmpty { return trimmedPath }
            // Legacy rows store path in `public_url` when not absolute.
            if !trimmedPublic.isEmpty { return trimmedPublic }
            return nil
        }()

        guard let path else { return nil }
        let bucket = resolvedPrimaryStorageBucket(storageBucket)

        do {
            let url = try await supabase.storage
                .from(bucket)
                .createSignedURL(path: path, expiresIn: spotImageSignedURLExpirySeconds)
            return url.absoluteString
        } catch {
            SpotLogger.log(FeedSupabaseLogs.primaryImageSignFailed, details: [
                "path": path,
                "bucket": bucket,
                "error": error.localizedDescription
            ])
            return nil
        }
    }

    /// Signs primary image URLs in a single batched call when possible.
    /// Falls back to per-row signing for absolute URLs or rows without a
    /// resolvable path. Returns a `[spot_id: signed_url]` map.
    static func resolvePrimaryImageURLs(
        for rows: [HomeFeedRow]
    ) async -> [UUID: String] {
        return await batchResolvePrimaryURLs(rows.map {
            ($0.spotId, $0.primaryStoragePath, $0.primaryPublicUrl, $0.primaryStorageBucket)
        }, phase: "feed")
    }

    /// Batched primary-image signing for `MapSpotRow`. Mirrors the feed path,
    /// keeping per-row signing off the hot map render loop.
    static func resolvePrimaryImageURLs(
        for rows: [MapSpotRow]
    ) async -> [UUID: String] {
        return await batchResolvePrimaryURLs(rows.map {
            ($0.spotId, $0.primaryStoragePath, $0.primaryPublicUrl, $0.primaryStorageBucket)
        }, phase: "map")
    }

    private static func batchResolvePrimaryURLs(
        _ entries: [(UUID, String?, String?, String?)],
        phase: String
    ) async -> [UUID: String] {
        guard !entries.isEmpty else { return [:] }

        struct BucketPath: Hashable {
            let bucket: String
            let path: String
        }

        var result: [UUID: String] = [:]
        var pathRowIndex: [BucketPath: [UUID]] = [:]
        var pathsByBucket: [String: [String]] = [:]

        for (spotId, storagePath, publicUrl, storageBucket) in entries {
            let trimmedPublic = publicUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if trimmedPublic.lowercased().hasPrefix("https://") || trimmedPublic.lowercased().hasPrefix("http://") {
                result[spotId] = trimmedPublic
                continue
            }
            let trimmedPath = storagePath?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let path = trimmedPath.isEmpty ? trimmedPublic : trimmedPath
            guard !path.isEmpty else { continue }
            let bucket = resolvedPrimaryStorageBucket(storageBucket)
            let key = BucketPath(bucket: bucket, path: path)
            pathRowIndex[key, default: []].append(spotId)
            if pathsByBucket[bucket]?.contains(path) != true {
                pathsByBucket[bucket, default: []].append(path)
            }
        }

        if pathsByBucket.isEmpty {
            return result
        }

        var signedCount = 0
        for (bucket, pathsToSign) in pathsByBucket {
            do {
                let signedResults = try await supabase.storage
                    .from(bucket)
                    .createSignedURLs(paths: pathsToSign, expiresIn: spotImageSignedURLExpirySeconds)
                for item in signedResults {
                    if case let .success(path, url) = item {
                        let key = BucketPath(bucket: bucket, path: path)
                        guard let spotIds = pathRowIndex[key] else { continue }
                        for sid in spotIds {
                            result[sid] = url.absoluteString
                        }
                        signedCount += spotIds.count
                    }
                }
            } catch {
                SpotLogger.log(FeedSupabaseLogs.primaryImageSignFailed, details: [
                    "phase": "batch_\(phase)",
                    "bucket": bucket,
                    "count": pathsToSign.count,
                    "error": error.localizedDescription
                ])
            }
        }

        SpotLogger.log(FeedSupabaseLogs.primaryImageSigned, details: [
            "phase": phase,
            "rows": entries.count,
            "signed": signedCount,
            "batchBuckets": pathsByBucket.count,
            "batchPaths": pathsByBucket.values.reduce(0) { $0 + $1.count }
        ])
        return result
    }
}

// MARK: - HomeFeedRow → Spot

extension HomeFeedRow {
    /// Convert a feed row to the existing `Spot` UI model. The home feed cell
    /// only needs the primary image URL — full image arrays are loaded lazily
    /// in detail.
    func toSpot(primaryURL: String?) -> Spot {
        Spot(
            id: spotId.uuidString,
            userId: userId.uuidString,
            username: authorUsername,
            userProfileImageURL: authorProfileImageUrl,
            imageURL: primaryURL,
            thumbnailURL: primaryURL,
            vibeTag: vibeName,
            vibeTags: vibeName.map { [$0] },
            latitude: latitude,
            longitude: longitude,
            locationName: locationName,
            likes: likesCount.map { Int($0) },
            isLiked: nil,
            isSaved: nil,
            createdAt: createdAt,
            authorIsPrivate: authorIsPrivate,
            imageURLs: primaryURL.map { [$0] },
            mediaDisplayAspectRatio: mediaDisplayAspectRatio,
            mediaCount: nil
        )
    }
}

extension MapSpotRow {
    /// Convert a map row to the existing `Spot` UI model.
    func toSpot(primaryURL: String?) -> Spot {
        Spot(
            id: spotId.uuidString,
            userId: userId.uuidString,
            username: authorUsername,
            userProfileImageURL: authorProfileImageUrl,
            imageURL: primaryURL,
            thumbnailURL: primaryURL,
            vibeTag: vibeName,
            vibeTags: vibeName.map { [$0] },
            latitude: latitude,
            longitude: longitude,
            locationName: locationName,
            likes: nil,
            isLiked: nil,
            isSaved: nil,
            createdAt: createdAt,
            authorIsPrivate: nil,
            imageURLs: nil,
            mediaDisplayAspectRatio: mediaDisplayAspectRatio,
            mediaCount: nil
        )
    }
}

//
//  FeedSupabaseLogs.swift
//  Spot
//
//  Log definitions for the Supabase-backed home feed pipeline (v2).
//

import Foundation

enum FeedSupabaseLogs: SpotLog {
    case rpcSucceeded
    case rpcFailed
    case statusFetched
    case statusFailed
    case primaryImageSigned
    case primaryImageSignFailed
    case mapRPCSucceeded
    case mapRPCFailed
    case mapRPCCancelled
    case loadInitialPreserveOldContent
    case loadInitialUsedSeenFallback
    case loadInitialAutoFallback
    case loadMoreNoNewRows
    case feedProfileFetched
    case feedProfileFetchFailed
    case feedProfileRecomputed
    case feedProfileRecomputeFailed

    var tag: String { "FeedSupabase" }

    var level: LogLevel {
        switch self {
        case .rpcSucceeded, .statusFetched,
             .loadInitialPreserveOldContent, .loadInitialUsedSeenFallback,
             .loadInitialAutoFallback, .loadMoreNoNewRows,
             .feedProfileFetched, .feedProfileRecomputed:
            return .info
        case .primaryImageSigned, .mapRPCSucceeded, .mapRPCCancelled:
            // Image hydration and map viewport calls can happen many times.
            return .debug
        case .rpcFailed, .statusFailed, .primaryImageSignFailed, .mapRPCFailed,
             .feedProfileFetchFailed, .feedProfileRecomputeFailed:
            return .error
        }
    }

    var message: String {
        switch self {
        case .rpcSucceeded: return "get_home_feed_v1 RPC returned rows"
        case .rpcFailed: return "get_home_feed_v1 RPC failed"
        case .statusFetched: return "get_home_feed_status_v1 returned status"
        case .statusFailed: return "get_home_feed_status_v1 failed"
        case .primaryImageSigned: return "Signed primary image URL for feed row"
        case .primaryImageSignFailed: return "Failed to sign primary image URL"
        case .mapRPCSucceeded: return "get_map_spots_v1 RPC returned rows"
        case .mapRPCFailed: return "get_map_spots_v1 RPC failed"
        case .mapRPCCancelled: return "get_map_spots_v1 RPC cancelled (pan/zoom)"
        case .loadInitialPreserveOldContent: return "Refresh failed; preserved existing feed content"
        case .loadInitialUsedSeenFallback: return "Feed RPC returned seen fallback rows (caught up)"
        case .loadInitialAutoFallback: return "Empty unseen result; auto-retrying with seen fallback"
        case .loadMoreNoNewRows: return "Load-more returned 0 new rows; preserved existing content"
        case .feedProfileFetched: return "Loaded user_feed_profiles row for caller"
        case .feedProfileFetchFailed: return "Failed to load user_feed_profiles row"
        case .feedProfileRecomputed: return "recompute_my_feed_profile_v1 returned snapshot"
        case .feedProfileRecomputeFailed: return "recompute_my_feed_profile_v1 failed"
        }
    }
}

enum FeedEventServiceLogs: SpotLog {
    case eventRecorded
    case eventFailed
    case visibilityDebounced

    var tag: String { "FeedEventService" }

    var level: LogLevel {
        switch self {
        case .eventRecorded, .visibilityDebounced: return .debug
        case .eventFailed: return .error
        }
    }

    var message: String {
        switch self {
        case .eventRecorded: return "Recorded feed event"
        case .eventFailed: return "record_feed_event_v1 failed"
        case .visibilityDebounced: return "Visibility event debounced"
        }
    }
}

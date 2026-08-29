//
//  SupabaseUserServiceLogs.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum SupabaseUserServiceLogs: SpotLog {
    case syncStarted
    case syncSucceeded
    /// No session yet — normal briefly during startup or after sign-out; not a server failure.
    case syncSkippedNoSession
    /// Upsert rejected by Postgres (missing GRANT / RLS on `public.users`).
    case syncFailedPermissionDenied
    /// Other upsert failure (network, constraint, etc.).
    case syncFailedUpsert

    var tag: String { "SupabaseUserService" }
    var level: LogLevel {
        switch self {
        case .syncStarted: return .debug
        case .syncSucceeded: return .info
        case .syncSkippedNoSession: return .debug
        case .syncFailedPermissionDenied, .syncFailedUpsert: return .error
        }
    }
    var message: String {
        switch self {
        case .syncStarted: return "Supabase user sync started"
        case .syncSucceeded: return "Supabase user sync succeeded"
        case .syncSkippedNoSession:
            return "Supabase user sync skipped (no session)"
        case .syncFailedPermissionDenied:
            return "Supabase user sync failed: database denied write to public.users (check GRANT INSERT/UPDATE and RLS for authenticated)"
        case .syncFailedUpsert:
            return "Supabase user sync failed: could not upsert public.users"
        }
    }
}

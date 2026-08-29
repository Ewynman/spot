//
//  SupabaseUserService.swift
//  Spot
//
//  Created by Edward Wynman on 4/19/26.
//

import Foundation
import Supabase

/// Syncs the signed-in Supabase Auth user into `public.users` (id = auth user id).
final class SupabaseUserService {
    static let shared = SupabaseUserService()
    private init() {}

    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// Uploads a JPEG to the `avatars` bucket; returns public URL string.
    func uploadProfileAvatarJPEG(_ data: Data, userId: UUID) async throws -> String {
        let path = "\(userId.uuidString.lowercased())/profile.jpg"
        try await supabase.storage
            .from("avatars")
            .upload(
                path,
                data: data,
                options: FileOptions(contentType: "image/jpeg", upsert: true)
            )
        let url = try supabase.storage.from("avatars").getPublicURL(path: path)
        return url.absoluteString
    }

    /// Upserts `public.users` for the current session user.
    func syncCurrentUser() async {
        let session: Session
        do {
            session = try await supabase.auth.session
        } catch {
            SpotLogger.log(SupabaseUserServiceLogs.syncSkippedNoSession, details: [
                "phase": "session",
                "error": error.localizedDescription
            ])
            return
        }

        let user = session.user
        SpotLogger.log(SupabaseUserServiceLogs.syncStarted, details: ["uid": user.id.uuidString])

        let meta = user.userMetadata
        var username = (meta["username"]?.stringValue)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if username.isEmpty {
            if let email = user.email, let local = email.split(separator: "@").first, !local.isEmpty {
                username = String(local)
            } else {
                username = "user_\(user.id.uuidString.prefix(8))"
            }
        }
        let usernameLower = username.lowercased()
        let isPrivate = meta["is_private"]?.boolValue ?? false

        let nowString = Self.iso8601.string(from: Date())
        let localeId = Locale.current.identifier
        let emailVerified = user.emailConfirmedAt != nil

        // Write via the `sync_current_user_v1` SECURITY DEFINER RPC rather than a
        // direct PostgREST upsert. The `authenticated` role only has
        // column-scoped UPDATE on public.users (everything except `id`), so an
        // `INSERT ... ON CONFLICT (id) DO UPDATE SET id = excluded.id, ...`
        // upsert is denied for existing rows (SQLSTATE 42501). The RPC derives
        // the id from auth.uid() server-side and only ever writes the caller's
        // own row. See migration 20260702120000_sync_current_user_security_definer_v1.
        struct SyncParams: Encodable {
            let p_username: String
            let p_username_lower: String
            let p_email: String?
            let p_email_verified: Bool
            let p_is_private: Bool
            let p_locale: String
            let p_last_active_at: String
        }

        let params = SyncParams(
            p_username: username,
            p_username_lower: usernameLower,
            p_email: user.email,
            p_email_verified: emailVerified,
            p_is_private: isPrivate,
            p_locale: localeId,
            p_last_active_at: nowString
        )

        do {
            try await supabase
                .rpc("sync_current_user_v1", params: params)
                .execute()
            SpotLogger.log(SupabaseUserServiceLogs.syncSucceeded, details: ["uid": user.id.uuidString])
        } catch {
            let message = error.localizedDescription
            let lower = message.lowercased()
            let isPermissionDenied = lower.contains("permission denied")
                || lower.contains("42501")
                || lower.contains("insufficient privilege")
            if isPermissionDenied {
                SpotLogger.log(SupabaseUserServiceLogs.syncFailedPermissionDenied, details: [
                    "uid": user.id.uuidString,
                    "error": message,
                    "hint": "Grant authenticated INSERT, SELECT, DELETE on public.users; column-scoped UPDATE as in security migration."
                ])
            } else {
                SpotLogger.log(SupabaseUserServiceLogs.syncFailedUpsert, details: [
                    "uid": user.id.uuidString,
                    "error": message
                ])
            }
        }
    }
}

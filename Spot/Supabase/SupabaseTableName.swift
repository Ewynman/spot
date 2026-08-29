//
//  SupabaseTableName.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

/// Public schema relation names for Supabase `.from(...)`.
enum SupabaseTableName {
    /// Full `public.users` row (RLS: own user id only). Includes `email` and server fields.
    static let users = "users"
    /// Safe profile projection for discovery and other users (no `email`). See `users_public` view.
    static let usersPublic = "users_public"
}

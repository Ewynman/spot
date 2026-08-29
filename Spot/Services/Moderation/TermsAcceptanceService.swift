//
//  TermsAcceptanceService.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation
import UIKit
import Supabase

/// Snapshot of the currently active Terms / Privacy release.
struct ActiveTermsVersion: Decodable, Equatable, Sendable {
    let id: UUID
    let version: String
    let title: String
    let termsURL: URL
    let privacyURL: URL

    enum CodingKeys: String, CodingKey {
        case id
        case version
        case title
        case termsURL = "terms_url"
        case privacyURL = "privacy_url"
    }
}

protocol TermsAcceptanceServicing: AnyObject {
    func loadActiveVersion() async throws -> ActiveTermsVersion
    func recordAcceptance() async throws
    func hasAcceptedActiveTerms() async throws -> Bool
}

final class TermsAcceptanceService: TermsAcceptanceServicing {
    static let shared = TermsAcceptanceService()

    private let client: SupabaseClient

    init(client: SupabaseClient = supabase) {
        self.client = client
    }

    /// Fetches the single `is_active = true` row from `terms_versions`. The
    /// table has a unique partial index ensuring at most one active version.
    func loadActiveVersion() async throws -> ActiveTermsVersion {
        struct Row: Decodable {
            let id: UUID
            let version: String
            let title: String
            let terms_url: String
            let privacy_url: String
        }
        do {
            let row: Row = try await client
                .from("terms_versions")
                .select("id,version,title,terms_url,privacy_url")
                .eq("is_active", value: true)
                .order("effective_at", ascending: false)
                .limit(1)
                .single()
                .execute()
                .value

            guard let termsURL = URL(string: row.terms_url),
                  let privacyURL = URL(string: row.privacy_url) else {
                throw NSError(
                    domain: "TermsAcceptanceService",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid Terms or Privacy URL on active terms_versions row."]
                )
            }

            return ActiveTermsVersion(
                id: row.id,
                version: row.version,
                title: row.title,
                termsURL: termsURL,
                privacyURL: privacyURL
            )
        } catch {
            SpotLogger.log(TermsAcceptanceLogs.loadActiveVersionFailed, details: [
                "error": error.localizedDescription
            ])
            throw error
        }
    }

    /// Records `record_terms_acceptance_v1` so `user_terms_acceptances` now
    /// contains a row for the active version + current authenticated user.
    func recordAcceptance() async throws {
        struct Params: Encodable {
            let p_app_version: String?
            let p_build_number: String?
            let p_device_info: String?
        }
        let info = Bundle.main.infoDictionary
        let appVersion = info?["CFBundleShortVersionString"] as? String
        let buildNumber = info?["CFBundleVersion"] as? String
        let device = await Self.collectDeviceInfo()

        do {
            _ = try await client
                .rpc("record_terms_acceptance_v1", params: Params(
                    p_app_version: appVersion,
                    p_build_number: buildNumber,
                    p_device_info: device
                ))
                .execute()
            SpotLogger.log(TermsAcceptanceLogs.acceptanceRecorded, details: [
                "appVersion": appVersion ?? "nil",
                "buildNumber": buildNumber ?? "nil"
            ])
        } catch {
            SpotLogger.log(TermsAcceptanceLogs.acceptanceRecordFailed, details: [
                "error": error.localizedDescription
            ])
            throw error
        }
    }

    /// Captures human-readable device info on the main actor (UIDevice is
    /// `@MainActor`-isolated under Swift 6 concurrency).
    @MainActor
    private static func collectDeviceInfo() -> String {
        "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion) | \(UIDevice.current.model)"
    }

    /// Read-only check: has the calling user already accepted the active
    /// terms version? Returns `false` when no session exists.
    func hasAcceptedActiveTerms() async throws -> Bool {
        do {
            let result: Bool = try await client
                .rpc("has_accepted_active_terms")
                .execute()
                .value
            return result
        } catch {
            SpotLogger.log(TermsAcceptanceLogs.acceptanceCheckFailed, details: [
                "error": error.localizedDescription
            ])
            throw error
        }
    }
}

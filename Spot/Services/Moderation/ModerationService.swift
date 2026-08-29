//
//  ModerationService.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation
import Supabase

/// Stable string codes accepted by the backend `reports.target_type` column
/// and the `submit_content_report` RPC's `p_target_type` argument.
enum ModerationTargetType: String, Sendable {
    case spot = "spot"
    case profile = "profile"
    case spotImage = "spot_image"
    case comment = "comment"
    case collection = "collection"
    case other = "other"
}

/// Canonical reason codes accepted by the backend `reports.reason` column.
///
/// Both legacy reasons (used by the existing `ReportSheet` for spot reports)
/// and the richer App Review-aligned set are accepted; the `priority_for_report_reason`
/// SQL helper maps them all to the right moderation queue priority.
enum ModerationReportReason: String, CaseIterable, Sendable, Codable {
    // Legacy spot-report reasons (kept so existing `ReportSheet` stays compatible).
    case inappropriate
    case harassment
    case violence
    case spam
    case misinformation
    case privacy
    case other

    // App Review-aligned reasons used by profile/user-level reports.
    case harassmentOrAbuse = "harassment_or_abuse"
    case hateSpeechOrDiscrimination = "hate_speech_or_discrimination"
    case sexualOrNudeContent = "sexual_or_nude_content"
    case violenceOrThreats = "violence_or_threats"
    case spamOrScam = "spam_or_scam"
    case illegalContent = "illegal_content"
    case privateInformation = "private_information"
}

protocol ModerationServicing: AnyObject {
    func submitSpotReport(spotId: UUID,
                          ownerId: UUID,
                          reason: ModerationReportReason,
                          details: String,
                          blockRequested: Bool) async throws -> UUID

    func submitProfileReport(reportedUserId: UUID,
                             reason: ModerationReportReason,
                             details: String,
                             blockRequested: Bool) async throws -> UUID

    func blockUser(blockedUserId: UUID,
                   sourceTargetType: ModerationTargetType?,
                   sourceTargetId: UUID?,
                   reason: String?) async throws -> UUID
}

/// Default Supabase-backed implementation. Inject a different conformer in
/// tests via `ModerationServiceFactory`.
final class ModerationService: ModerationServicing {
    static let shared = ModerationService()

    private let client: SupabaseClient

    init(client: SupabaseClient = supabase) {
        self.client = client
    }

    // MARK: - Reports

    func submitSpotReport(spotId: UUID,
                          ownerId: UUID,
                          reason: ModerationReportReason,
                          details: String,
                          blockRequested: Bool) async throws -> UUID {
        do {
            let id = try await invokeSubmitContentReport(
                targetType: .spot,
                targetId: spotId,
                reportedUserId: ownerId,
                reason: reason,
                details: details,
                blockRequested: blockRequested
            )
            SpotLogger.log(ModerationServiceLogs.spotReportSubmitted, details: [
                "spotId": spotId.uuidString,
                "reason": reason.rawValue,
                "blockRequested": blockRequested
            ])
            return id
        } catch {
            SpotLogger.log(ModerationServiceLogs.spotReportFailed, details: [
                "spotId": spotId.uuidString,
                "reason": reason.rawValue,
                "error": error.localizedDescription
            ])
            throw error
        }
    }

    func submitProfileReport(reportedUserId: UUID,
                             reason: ModerationReportReason,
                             details: String,
                             blockRequested: Bool) async throws -> UUID {
        do {
            let id = try await invokeSubmitContentReport(
                targetType: .profile,
                targetId: reportedUserId,
                reportedUserId: reportedUserId,
                reason: reason,
                details: details,
                blockRequested: blockRequested
            )
            SpotLogger.log(ModerationServiceLogs.profileReportSubmitted, details: [
                "reportedUserId": reportedUserId.uuidString,
                "reason": reason.rawValue,
                "blockRequested": blockRequested
            ])
            return id
        } catch {
            SpotLogger.log(ModerationServiceLogs.profileReportFailed, details: [
                "reportedUserId": reportedUserId.uuidString,
                "reason": reason.rawValue,
                "error": error.localizedDescription
            ])
            throw error
        }
    }

    // MARK: - Blocks

    func blockUser(blockedUserId: UUID,
                   sourceTargetType: ModerationTargetType? = nil,
                   sourceTargetId: UUID? = nil,
                   reason: String? = nil) async throws -> UUID {
        struct Params: Encodable {
            let p_blocked_user_id: UUID
            let p_source_target_type: String?
            let p_source_target_id: UUID?
            let p_reason: String?
        }
        do {
            let id: UUID = try await client
                .rpc("block_user_v1", params: Params(
                    p_blocked_user_id: blockedUserId,
                    p_source_target_type: sourceTargetType?.rawValue,
                    p_source_target_id: sourceTargetId,
                    p_reason: reason
                ))
                .execute()
                .value
            SpotLogger.log(ModerationServiceLogs.userBlocked, details: [
                "blockedUserId": blockedUserId.uuidString,
                "source": sourceTargetType?.rawValue ?? "nil"
            ])
            return id
        } catch {
            SpotLogger.log(ModerationServiceLogs.userBlockFailed, details: [
                "blockedUserId": blockedUserId.uuidString,
                "error": error.localizedDescription
            ])
            throw error
        }
    }

    // MARK: - Internal

    private func invokeSubmitContentReport(targetType: ModerationTargetType,
                                           targetId: UUID,
                                           reportedUserId: UUID?,
                                           reason: ModerationReportReason,
                                           details: String,
                                           blockRequested: Bool) async throws -> UUID {
        struct Params: Encodable {
            let p_target_type: String
            let p_target_id: UUID
            let p_reported_user_id: UUID?
            let p_reason: String
            let p_details: String
            let p_block_requested: Bool
        }
        let params = Params(
            p_target_type: targetType.rawValue,
            p_target_id: targetId,
            p_reported_user_id: reportedUserId,
            p_reason: reason.rawValue,
            p_details: details.trimmingCharacters(in: .whitespacesAndNewlines),
            p_block_requested: blockRequested
        )
        let id: UUID = try await client
            .rpc("submit_content_report", params: params)
            .execute()
            .value
        return id
    }
}

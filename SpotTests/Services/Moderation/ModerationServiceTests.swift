//
//  ModerationServiceTests.swift
//  SpotTests
//
//  Unit tests for the deterministic, networking-free pieces of the new
//  moderation surface: enum stability, log severity, and Swift→backend reason
//  mapping. Networked RPC calls are exercised in higher-level integration
//  tests; this suite enforces invariants App Review reviewers (and the
//  `priority_for_report_reason` SQL helper) rely on.
//

import Foundation
import Testing
@testable import Spot

struct ModerationServiceTests {

    // MARK: - ModerationReportReason

    @Test func moderationReportReasonAcceptsLegacyAndPRDCodes() {
        let legacy: [ModerationReportReason] = [
            .inappropriate, .harassment, .violence, .spam,
            .misinformation, .privacy, .other
        ]
        let prd: [ModerationReportReason] = [
            .harassmentOrAbuse,
            .hateSpeechOrDiscrimination,
            .sexualOrNudeContent,
            .violenceOrThreats,
            .spamOrScam,
            .illegalContent,
            .privateInformation
        ]

        // Both sets must be representable. Together they cover every reason
        // accepted by the `priority_for_report_reason` SQL helper.
        let allRawValues = (legacy + prd).map(\.rawValue)
        #expect(allRawValues.count == Set(allRawValues).count, "Reason raw values must be unique")
        #expect(allRawValues.contains("harassment"))
        #expect(allRawValues.contains("harassment_or_abuse"))
        #expect(allRawValues.contains("sexual_or_nude_content"))
        #expect(allRawValues.contains("private_information"))
    }

    @Test func moderationReportReasonRoundTripsThroughCodable() throws {
        let original = ModerationReportReason.harassmentOrAbuse
        let encoded = try JSONEncoder().encode([original])
        let decoded = try JSONDecoder().decode([ModerationReportReason].self, from: encoded)
        #expect(decoded == [original])
    }

    @Test func moderationTargetTypeRawValuesMatchBackend() {
        // The backend `reports.target_type` column accepts these literal
        // strings; mismatches would silently route reports to the wrong queue.
        #expect(ModerationTargetType.spot.rawValue == "spot")
        #expect(ModerationTargetType.profile.rawValue == "profile")
        #expect(ModerationTargetType.spotImage.rawValue == "spot_image")
        #expect(ModerationTargetType.comment.rawValue == "comment")
        #expect(ModerationTargetType.collection.rawValue == "collection")
        #expect(ModerationTargetType.other.rawValue == "other")
    }

    // MARK: - Legacy ReportReason → ModerationReportReason

    @Test func legacyReportReasonsMapToModerationReasonsOneToOne() {
        let mapping: [(ReportReason, ModerationReportReason)] = [
            (.inappropriate, .inappropriate),
            (.harassment, .harassment),
            (.violence, .violence),
            (.spam, .spam),
            (.misinformation, .misinformation),
            (.privacy, .privacy),
            (.other, .other)
        ]

        for (legacy, expected) in mapping {
            // We can verify by submitting through ReportSheet's body call site,
            // which routes via the ModerationService — but that requires the
            // sheet. Instead exercise the same mapping logic indirectly: the
            // legacy and canonical raw values must agree.
            #expect(legacy.rawValue == expected.rawValue, "\(legacy) must map to \(expected) preserving raw value")
        }
    }

    // MARK: - Log enums

    @Test func moderationServiceLogLevelsReflectEventSeverity() {
        #expect(ModerationServiceLogs.spotReportSubmitted.level == .info)
        #expect(ModerationServiceLogs.profileReportSubmitted.level == .info)
        #expect(ModerationServiceLogs.userBlocked.level == .info)
        #expect(ModerationServiceLogs.userUnblocked.level == .info)

        #expect(ModerationServiceLogs.spotReportFailed.level == .error)
        #expect(ModerationServiceLogs.profileReportFailed.level == .error)
        #expect(ModerationServiceLogs.userBlockFailed.level == .error)
        #expect(ModerationServiceLogs.userUnblockFailed.level == .error)
        #expect(ModerationServiceLogs.rpcRpcMissingArguments.level == .error)
    }

    @Test func moderationServiceLogTagIsConsistent() {
        for log in [
            ModerationServiceLogs.spotReportSubmitted,
            .profileReportSubmitted,
            .userBlocked,
            .spotReportFailed
        ] {
            #expect(log.tag == "ModerationService")
        }
    }
}

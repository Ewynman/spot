//
//  TermsAcceptanceLogs.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum TermsAcceptanceLogs: SpotLog {
    case loadActiveVersionFailed
    case acceptanceCheckFailed
    case acceptanceRecorded
    case acceptanceRecordFailed
    case preAuthAgreementToggled
    case preAuthAgreementGated
    case postAuthGatePresented
    case postAuthGateAccepted

    var tag: String { "TermsAcceptance" }
    var level: LogLevel {
        switch self {
        case .acceptanceRecorded, .preAuthAgreementToggled, .postAuthGatePresented, .postAuthGateAccepted:
            return .info
        case .preAuthAgreementGated:
            return .info
        case .loadActiveVersionFailed, .acceptanceCheckFailed, .acceptanceRecordFailed:
            return .error
        }
    }
    var message: String {
        switch self {
        case .loadActiveVersionFailed: return "Failed to load active terms version"
        case .acceptanceCheckFailed: return "Failed to check active terms acceptance"
        case .acceptanceRecorded: return "Terms acceptance recorded for active version"
        case .acceptanceRecordFailed: return "Failed to record terms acceptance"
        case .preAuthAgreementToggled: return "Pre-auth Terms checkbox toggled"
        case .preAuthAgreementGated: return "Pre-auth action gated until Terms accepted"
        case .postAuthGatePresented: return "Post-auth Terms update gate presented"
        case .postAuthGateAccepted: return "Post-auth Terms update accepted"
        }
    }
}

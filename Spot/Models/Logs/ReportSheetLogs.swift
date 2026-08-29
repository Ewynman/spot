//
//  ReportSheetLogs.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum ReportSheetLogs: SpotLog {
    case submissionMissingRequiredData
    case userBlockedDuringReport
    case reportSubmitted
    case submitFailed

    var tag: String { "ReportSheet" }
    var level: LogLevel {
        switch self {
        case .submissionMissingRequiredData: return .error
        case .userBlockedDuringReport: return .info
        case .reportSubmitted: return .info
        case .submitFailed: return .error
        }
    }
    var message: String {
        switch self {
        case .submissionMissingRequiredData: return "Report submission missing required data"
        case .userBlockedDuringReport: return "User blocked during report"
        case .reportSubmitted: return "Report submitted"
        case .submitFailed: return "Failed to submit report"
        }
    }
}

//
//  SpotImageModerationLogs.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum SpotImageModerationLogs: SpotLog {
    /// Expected path when Azure/policy rejects the image (422 + image_policy_rejected).
    case policyRejectedByEdgeFunction
    /// Anything else: wrong JSON shape, 401, 5xx, placeholder deploy, Azure missing, etc.
    case moderateInvokeUnexpectedResponse

    var tag: String { "SpotImageModeration" }

    var level: LogLevel {
        switch self {
        case .policyRejectedByEdgeFunction: return .debug
        case .moderateInvokeUnexpectedResponse: return .error
        }
    }

    var message: String {
        switch self {
        case .policyRejectedByEdgeFunction:
            return "Edge moderate-image: policy rejection (expected)"
        case .moderateInvokeUnexpectedResponse:
            return "Edge moderate-image: unexpected response (check deploy + secrets + logs)"
        }
    }
}

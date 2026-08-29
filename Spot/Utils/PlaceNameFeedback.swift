//
//  PlaceNameFeedback.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

/// Maps place-name validation results to user-facing rename alert copy.
enum PlaceNameFeedback {
    static func message(for result: PlaceNameValidationResult) -> String? {
        switch result {
        case .ok:
            return nil
        case .tooShort:
            return "Please use at least 3 characters."
        case .tooLong:
            return "Please keep it shorter."
        case .blocked:
            return "That name isn’t allowed."
        }
    }
}

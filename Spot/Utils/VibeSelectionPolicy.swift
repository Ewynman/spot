//
//  VibeSelectionPolicy.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

/// Pure toggle policy for vibe chip selection (free vs Pro caps).
enum VibeSelectionPolicy {
    struct Outcome: Equatable {
        var selectedVibes: [String]
        var validationMessage: String?
        var didChange: Bool
    }

    static func toggle(
        current: [String],
        vibe: String,
        isPro: Bool,
        maxVibes: Int
    ) -> Outcome {
        if current.contains(vibe) {
            return Outcome(
                selectedVibes: current.filter { $0 != vibe },
                validationMessage: nil,
                didChange: true
            )
        }

        if !isPro {
            let message = current.isEmpty ? nil : Constants.PostLimits.freeMultipleVibesMessage
            return Outcome(
                selectedVibes: [vibe],
                validationMessage: message,
                didChange: true
            )
        }

        if current.count >= maxVibes {
            return Outcome(
                selectedVibes: current,
                validationMessage: Constants.PostLimits.proTooManyVibesMessage,
                didChange: false
            )
        }

        return Outcome(
            selectedVibes: current + [vibe],
            validationMessage: nil,
            didChange: true
        )
    }
}

import Foundation

/// Maps username validation results to signup/settings toast copy.
enum UsernameFeedback {
    static func message(for result: UsernameValidationResult) -> String? {
        switch result {
        case .ok:
            return nil
        case .tooShort:
            return "Username is too short"
        case .tooLong:
            return "Username is too long"
        case .invalidChars:
            return "Username has invalid characters"
        case .reserved:
            return "That username is reserved"
        case .blocked:
            return "That username isn’t allowed"
        }
    }
}

/// Maps username availability RPC outcomes to toast copy.
enum UsernameAvailabilityFeedback {
    static func message(for outcome: UsernameAvailabilityOutcome) -> String? {
        switch outcome {
        case .available:
            return nil
        case .taken:
            return "That username is taken. Try another."
        case .unavailable:
            return "We couldn’t check that username. Try again."
        }
    }
}

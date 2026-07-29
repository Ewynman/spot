import Foundation

enum DebugKeychainResetLogs: SpotLog {
    case cleared
    case nothingToClear
    case failed

    var tag: String { "DebugKeychainReset" }

    var level: LogLevel {
        switch self {
        case .cleared, .nothingToClear: return .info
        case .failed: return .error
        }
    }

    var message: String {
        switch self {
        case .cleared: return "Cleared Spot Keychain items on launch"
        case .nothingToClear: return "Keychain reset requested; no Spot items found"
        case .failed: return "Failed to clear Spot Keychain items"
        }
    }
}

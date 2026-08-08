import Foundation

/// Holds the active Supabase user id for call sites that are not yet async/session-aware.
/// Thread-safe implementation using a serial queue for synchronization.
enum SpotAuthBridge {
    private static let queue = DispatchQueue(label: "com.spotapp.spot.authbridge", qos: .userInitiated)
    private static var _currentUserId: String?
    private static var _currentUserEmail: String?
    private static var _isEmailVerifiedForSession: Bool = false

    static var currentUserId: String? {
        queue.sync { _currentUserId }
    }

    static var currentUserEmail: String? {
        queue.sync { _currentUserEmail }
    }

    static var isEmailVerifiedForSession: Bool {
        queue.sync { _isEmailVerifiedForSession }
    }

    static func setSessionUser(id: String?, email: String?, emailVerified: Bool = false) {
        queue.sync {
            _currentUserId = id
            _currentUserEmail = email
            _isEmailVerifiedForSession = emailVerified
        }
    }
}

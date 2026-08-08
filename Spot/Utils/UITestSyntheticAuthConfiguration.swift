import Foundation

/// Pure UI-test auth bootstrap values applied by `AuthViewModel` in DEBUG.
enum UITestSyntheticAuthConfiguration: Equatable {
    case loggedOut
    case loggedIn(userId: String, isPro: Bool)

    var userId: String? {
        switch self {
        case .loggedOut: return nil
        case let .loggedIn(userId, _): return userId
        }
    }

    var isAuthenticated: Bool {
        if case .loggedIn = self { return true }
        return false
    }

    var isEmailVerified: Bool { isAuthenticated }

    var isPro: Bool {
        switch self {
        case .loggedOut: return false
        case let .loggedIn(_, isPro): return isPro
        }
    }

    static func make(
        bootstrap: SpotLaunchConfiguration.UITestAuthBootstrap,
        syntheticUserId: String = SpotLaunchConfiguration.uiTestSyntheticUserId,
        isPro: Bool = SpotLaunchConfiguration.uiTestUserIsPro
    ) -> UITestSyntheticAuthConfiguration {
        switch bootstrap {
        case .loggedIn:
            return .loggedIn(userId: syntheticUserId, isPro: isPro)
        case .loggedOut:
            return .loggedOut
        }
    }
}

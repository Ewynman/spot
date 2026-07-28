import Foundation
import Security
import Testing
@testable import Spot

struct DebugKeychainResetTests {
    @Test func disabledRequestDoesNothing() {
        let defaults = makeDefaults()
        defer { clear(defaults) }
        var deleteCallCount = 0

        let outcome = DebugKeychainReset.performIfRequested(
            defaults: defaults,
            deleteItems: {
                deleteCallCount += 1
                return errSecSuccess
            }
        )

        #expect(outcome == nil)
        #expect(deleteCallCount == 0)
    }

    @Test func enabledRequestClearsOnceAndResetsToggle() {
        let defaults = makeDefaults()
        defer { clear(defaults) }
        defaults.set(true, forKey: Constants.UserDefaultsKeys.clearKeychainOnNextLaunch)
        var deleteCallCount = 0

        let firstOutcome = DebugKeychainReset.performIfRequested(
            defaults: defaults,
            deleteItems: {
                deleteCallCount += 1
                return errSecSuccess
            }
        )
        let secondOutcome = DebugKeychainReset.performIfRequested(
            defaults: defaults,
            deleteItems: {
                deleteCallCount += 1
                return errSecSuccess
            }
        )

        #expect(firstOutcome == .cleared)
        #expect(secondOutcome == nil)
        #expect(deleteCallCount == 1)
        #expect(!defaults.bool(forKey: Constants.UserDefaultsKeys.clearKeychainOnNextLaunch))
    }

    @Test(arguments: [
        (errSecItemNotFound, DebugKeychainReset.Outcome.nothingToClear),
        (errSecInteractionNotAllowed, DebugKeychainReset.Outcome.failed(errSecInteractionNotAllowed))
    ])
    func reportsDeleteOutcome(status: OSStatus, expected: DebugKeychainReset.Outcome) {
        let defaults = makeDefaults()
        defer { clear(defaults) }
        defaults.set(true, forKey: Constants.UserDefaultsKeys.clearKeychainOnNextLaunch)

        let outcome = DebugKeychainReset.performIfRequested(
            defaults: defaults,
            deleteItems: { status }
        )

        #expect(outcome == expected)
        #expect(!defaults.bool(forKey: Constants.UserDefaultsKeys.clearKeychainOnNextLaunch))
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "DebugKeychainResetTests.\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }

    private func clear(_ defaults: UserDefaults) {
        defaults.removeObject(forKey: Constants.UserDefaultsKeys.clearKeychainOnNextLaunch)
    }
}

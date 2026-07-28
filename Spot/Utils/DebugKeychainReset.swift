import Foundation
import Security

enum DebugKeychainReset {
    enum Outcome: Equatable {
        case cleared
        case nothingToClear
        case failed(OSStatus)
    }

    /// Runs before the Supabase client is constructed so no persisted session
    /// can be restored first. The preference is always reset for one-shot use.
    @discardableResult
    static func performIfRequested() -> Outcome? {
        performIfRequested(
            defaults: .standard,
            deleteItems: deleteAllSpotGenericPasswordItems
        )
    }

    @discardableResult
    static func performIfRequested(
        defaults: UserDefaults,
        deleteItems: () -> OSStatus
    ) -> Outcome? {
        let key = Constants.UserDefaultsKeys.clearKeychainOnNextLaunch
        guard defaults.bool(forKey: key) else { return nil }

        defaults.set(false, forKey: key)
        let status = deleteItems()

        switch status {
        case errSecSuccess:
            SpotLogger.log(DebugKeychainResetLogs.cleared)
            return .cleared
        case errSecItemNotFound:
            SpotLogger.log(DebugKeychainResetLogs.nothingToClear)
            return .nothingToClear
        default:
            SpotLogger.log(
                DebugKeychainResetLogs.failed,
                details: ["status": status]
            )
            return .failed(status)
        }
    }

    private static func deleteAllSpotGenericPasswordItems() -> OSStatus {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
        ]
        return SecItemDelete(query as CFDictionary)
    }
}

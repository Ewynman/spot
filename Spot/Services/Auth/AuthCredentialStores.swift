import Foundation
import Security

enum AuthAccountProvider: String, Codable, Equatable {
    case apple
    case email
}

struct AuthAccountHint: Codable, Equatable {
    let email: String?
    let displayLabel: String
    let provider: AuthAccountProvider
    let lastSignedInAt: Date

    var maskedEmail: String? {
        guard let email, let at = email.firstIndex(of: "@") else { return email }
        let name = email[..<at]
        let domain = email[at...]
        return String(name.prefix(min(2, name.count))) + "••••" + String(domain)
    }
}

struct AuthVerificationRecovery: Codable, Equatable {
    let email: String
    let startedAt: Date
}

protocol AuthDataStoring {
    func save(_ data: Data)
    func load() -> Data?
    func delete()
}

/// Stores only an account hint in device-local Keychain storage.
/// Passwords, OTPs, Supabase tokens, and Apple identity tokens must never be stored here.
final class AuthAccountHintStore {
    static let shared = AuthAccountHintStore()

    private let keychain: AuthDataStoring

    init(keychain: AuthDataStoring = AuthKeychainDataStore.accountHint) {
        self.keychain = keychain
    }

    func save(_ hint: AuthAccountHint) {
        guard let data = try? JSONEncoder().encode(hint) else { return }
        keychain.save(data)
    }

    func load() -> AuthAccountHint? {
        guard let data = keychain.load() else { return nil }
        return try? JSONDecoder().decode(AuthAccountHint.self, from: data)
    }

    func clear() {
        keychain.delete()
    }
}

/// Persists the minimum state needed to resume signup verification after relaunch.
/// This item is device-local and expires automatically; the OTP and password are never persisted.
final class AuthVerificationRecoveryStore {
    static let shared = AuthVerificationRecoveryStore()

    private let keychain: AuthDataStoring
    private let lifetime: TimeInterval
    private let now: () -> Date

    init(
        keychain: AuthDataStoring = AuthKeychainDataStore.verificationRecovery,
        lifetime: TimeInterval = 72 * 60 * 60,
        now: @escaping () -> Date = Date.init
    ) {
        self.keychain = keychain
        self.lifetime = lifetime
        self.now = now
    }

    func save(email: String) {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty,
              let data = try? JSONEncoder().encode(
                AuthVerificationRecovery(email: normalized, startedAt: now())
              )
        else { return }
        keychain.save(data)
    }

    func load() -> AuthVerificationRecovery? {
        guard let data = keychain.load(),
              let recovery = try? JSONDecoder().decode(AuthVerificationRecovery.self, from: data)
        else { return nil }
        guard now().timeIntervalSince(recovery.startedAt) <= lifetime else {
            clear()
            return nil
        }
        return recovery
    }

    func clear() {
        keychain.delete()
    }
}

final class AuthKeychainDataStore: AuthDataStoring {
    static let accountHint = AuthKeychainDataStore(
        service: "com.edwardwynman.Spot.account-hint",
        account: "last-account",
        synchronizable: false
    )
    static let verificationRecovery = AuthKeychainDataStore(
        service: "com.edwardwynman.Spot.verification-recovery",
        account: "pending-signup",
        synchronizable: false
    )

    private let service: String
    private let account: String
    private let synchronizable: Bool

    init(service: String, account: String, synchronizable: Bool) {
        self.service = service
        self.account = account
        self.synchronizable = synchronizable
    }

    func save(_ data: Data) {
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: synchronizable
            ? kSecAttrAccessibleAfterFirstUnlock
            : kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        guard updateStatus == errSecItemNotFound else {
            if updateStatus != errSecSuccess {
                log(.saveFailed, status: updateStatus)
            }
            return
        }

        var addQuery = baseQuery
        attributes.forEach { addQuery[$0.key] = $0.value }
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus != errSecSuccess {
            log(.saveFailed, status: addStatus)
        }
    }

    func load() -> Data? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else {
            if status != errSecItemNotFound {
                log(.loadFailed, status: status)
            }
            return nil
        }
        return result as? Data
    }

    func delete() {
        let status = SecItemDelete(baseQuery as CFDictionary)
        if status != errSecSuccess, status != errSecItemNotFound {
            log(.deleteFailed, status: status)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: synchronizable
        ]
    }

    private func log(_ event: AuthCredentialStoreLogs, status: OSStatus) {
        SpotLogger.log(event, details: ["status": status])
    }
}

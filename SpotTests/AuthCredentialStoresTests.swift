import Foundation
import Testing
@testable import Spot

struct AuthCredentialStoresTests {
    @Test func appleNonceHashMatchesSHA256Reference() {
        #expect(
            AppleSignInNonce.sha256("test")
                == "9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08"
        )
        #expect(AppleSignInNonce.make().count == 64)
    }

    @Test func accountHintMasksEmailAndContainsNoCredentialFields() throws {
        let hint = AuthAccountHint(
            email: "maya@example.com",
            displayLabel: "@maya",
            provider: .email,
            lastSignedInAt: Date(timeIntervalSince1970: 100)
        )

        #expect(hint.maskedEmail == "ma••••@example.com")

        let json = try #require(String(data: JSONEncoder().encode(hint), encoding: .utf8))
        #expect(!json.localizedCaseInsensitiveContains("password"))
        #expect(!json.localizedCaseInsensitiveContains("token"))
        #expect(!json.localizedCaseInsensitiveContains("otp"))
    }

    @Test func accountHintStoreRoundTripsAndClears() {
        let storage = InMemoryAuthDataStore()
        let store = AuthAccountHintStore(keychain: storage)
        let hint = AuthAccountHint(
            email: "hello@example.com",
            displayLabel: "@hello",
            provider: .apple,
            lastSignedInAt: Date(timeIntervalSince1970: 200)
        )

        store.save(hint)
        #expect(store.load() == hint)

        store.clear()
        #expect(store.load() == nil)
    }

    @Test func verificationRecoveryNormalizesEmailAndExpires() {
        let storage = InMemoryAuthDataStore()
        var now = Date(timeIntervalSince1970: 1_000)
        let store = AuthVerificationRecoveryStore(
            keychain: storage,
            lifetime: 60,
            now: { now }
        )

        store.save(email: "  Maya@Example.COM ")
        #expect(store.load()?.email == "maya@example.com")

        now = now.addingTimeInterval(61)
        #expect(store.load() == nil)
        #expect(storage.data == nil)
    }
}

private final class InMemoryAuthDataStore: AuthDataStoring {
    var data: Data?

    func save(_ data: Data) {
        self.data = data
    }

    func load() -> Data? {
        data
    }

    func delete() {
        data = nil
    }
}

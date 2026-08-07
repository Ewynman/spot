import Foundation
import Testing
import Supabase
@testable import Spot

#if DEBUG || INTERNAL_TESTING

struct StagingTestEmailVerificationTests {
    @Test func codeFormatAcceptsUTPrefixAndFourDigits() {
        #expect(StagingTestEmailVerification.isValidCodeFormat("UT1234"))
        #expect(StagingTestEmailVerification.isValidCodeFormat(" ut9999 "))
        #expect(!StagingTestEmailVerification.isValidCodeFormat("123456"))
        #expect(!StagingTestEmailVerification.isValidCodeFormat("UT12"))
        #expect(!StagingTestEmailVerification.isValidCodeFormat("UTABCD"))
        #expect(!StagingTestEmailVerification.isValidCodeFormat(""))
    }

    @Test func recoveryStorePersistsOptionalUserIdAndLegacyEmailOnly() throws {
        let storage = InMemoryAuthDataStore()
        let store = AuthVerificationRecoveryStore(
            keychain: storage,
            lifetime: 60,
            now: { Date(timeIntervalSince1970: 1_000) }
        )
        let userId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

        store.save(email: "  Tester@Example.COM ", userId: userId)
        let loaded = try #require(store.load())
        #expect(loaded.email == "tester@example.com")
        #expect(loaded.userId == userId)

        let legacyJSON = #"{"email":"legacy@example.com","startedAt":1000}"#
        storage.data = Data(legacyJSON.utf8)
        let legacy = try #require(store.load())
        #expect(legacy.email == "legacy@example.com")
        #expect(legacy.userId == nil)
    }

    @Test func verifyInternalDeniedKeepsPendingState() async throws {
        let auth = AuthViewModel()
        let userId = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        auth.beginEmailVerificationPending(email: "qa@example.com", avatar: nil, userId: userId)
        auth.stagingTestEmailVerifier = FailingStagingVerifier(error: .serverDenied)

        do {
            try await auth.verifyInternalTestEmailCode("UT1234")
            Issue.record("Expected server denial")
        } catch let error as StagingTestEmailVerificationError {
            #expect(error == .serverDenied)
        }

        #expect(auth.awaitingEmailVerification)
        #expect(auth.isAuthenticated == false)
        #expect(auth.isEmailVerified == false)
    }

    @Test func verifyInternalInvalidFormatDoesNotClearPending() async throws {
        let auth = AuthViewModel()
        let userId = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        auth.beginEmailVerificationPending(email: "qa@example.com", avatar: nil, userId: userId)
        auth.stagingTestEmailVerifier = FailingStagingVerifier(error: .serverDenied)

        do {
            try await auth.verifyInternalTestEmailCode("nope")
            Issue.record("Expected invalid format")
        } catch let error as StagingTestEmailVerificationError {
            #expect(error == .invalidFormat)
        }

        #expect(auth.awaitingEmailVerification)
        #expect(auth.isEmailVerified == false)
    }

    @Test func verifyInternalRequiresPendingUserId() async throws {
        let auth = AuthViewModel()
        auth.beginEmailVerificationPending(email: "qa@example.com", avatar: nil, userId: nil)

        do {
            try await auth.verifyInternalTestEmailCode("UT1234")
            Issue.record("Expected missing pending user")
        } catch let error as StagingTestEmailVerificationError {
            #expect(error == .missingPendingUser)
        }
    }
}

private struct FailingStagingVerifier: StagingTestEmailVerifying {
    let error: StagingTestEmailVerificationError

    func exchange(
        userId: UUID,
        email: String,
        code: String
    ) async throws -> (tokenHash: String, type: EmailOTPType) {
        throw error
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

#endif

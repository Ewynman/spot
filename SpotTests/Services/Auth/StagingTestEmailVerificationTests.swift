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

    @Test func errorDescriptionsAreUserFacing() {
        let errors: [StagingTestEmailVerificationError] = [
            .unavailable,
            .invalidFormat,
            .missingPendingUser,
            .serverDenied,
            .rateLimited,
            .alreadyConfirmed,
            .malformedResponse,
            .tokenExchangeFailed
        ]

        for error in errors {
            #expect(error.errorDescription?.isEmpty == false)
        }
    }

    @Test func internalVerificationAvailabilityReflectsPendingUserId() {
        let auth = AuthViewModel()
        #expect(auth.isInternalTestEmailVerificationAvailable == false)

        let userId = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        auth.beginEmailVerificationPending(email: "qa@example.com", avatar: nil, userId: userId)
        #expect(auth.isInternalTestEmailVerificationAvailable == StagingTestEmailVerification.isAvailable)
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

    @Test func verifyInternalUnavailableWhenFeatureDisabled() async throws {
        StagingTestEmailVerification.isAvailableOverride = false
        defer { StagingTestEmailVerification.isAvailableOverride = nil }

        let auth = AuthViewModel()
        let userId = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
        auth.beginEmailVerificationPending(email: "qa@example.com", avatar: nil, userId: userId)

        do {
            try await auth.verifyInternalTestEmailCode("UT1234")
            Issue.record("Expected unavailable error")
        } catch let error as StagingTestEmailVerificationError {
            #expect(error == .unavailable)
        }
    }

    @Test func verifyInternalTokenExchangeFailureSurfacesError() async throws {
        let auth = AuthViewModel()
        let userId = UUID(uuidString: "66666666-6666-6666-6666-666666666666")!
        auth.beginEmailVerificationPending(email: "qa@example.com", avatar: nil, userId: userId)
        auth.stagingTestEmailVerifier = SucceedingStagingVerifier(
            tokenHash: "staging-test-token-hash",
            type: .signup
        )

        do {
            try await auth.verifyInternalTestEmailCode("UT1234")
            Issue.record("Expected token exchange failure")
        } catch let error as StagingTestEmailVerificationError {
            #expect(error == .tokenExchangeFailed)
        }
    }

    @Test func serviceRejectsInvalidCodeBeforeNetwork() async throws {
        let service = StagingTestEmailVerificationService(
            urlSession: MockURLSessionFactory.make { request in
                Issue.record("Unexpected network request: \(request.url?.absoluteString ?? "nil")")
                return MockURLSessionFactory.httpResponse(for: request, statusCode: 500)
            }
        )

        do {
            _ = try await service.exchange(
                userId: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
                email: "qa@example.com",
                code: "bad"
            )
            Issue.record("Expected invalid format")
        } catch let error as StagingTestEmailVerificationError {
            #expect(error == .invalidFormat)
        }
    }

    @Test func serviceUnavailableWhenFeatureDisabled() async throws {
        StagingTestEmailVerification.isAvailableOverride = false
        defer { StagingTestEmailVerification.isAvailableOverride = nil }

        let service = StagingTestEmailVerificationService()

        do {
            _ = try await service.exchange(
                userId: UUID(uuidString: "88888888-8888-8888-8888-888888888888")!,
                email: "qa@example.com",
                code: "UT1234"
            )
            Issue.record("Expected unavailable error")
        } catch let error as StagingTestEmailVerificationError {
            #expect(error == .unavailable)
        }
    }

    @Test func serviceExchangeSuccessReturnsTokenHash() async throws {
        let userId = UUID(uuidString: "99999999-9999-9999-9999-999999999999")!
        let service = StagingTestEmailVerificationService(
            urlSession: MockURLSessionFactory.make { request in
                #expect(request.httpMethod == "POST")
                #expect(request.url?.lastPathComponent == "staging-verify-email")

                let responseBody = #"{"tokenHash":"hash-from-edge","type":"signup"}"#.data(using: .utf8)!
                return MockURLSessionFactory.httpResponse(for: request, statusCode: 200, body: responseBody)
            }
        )

        let exchange = try await service.exchange(
            userId: userId,
            email: "  QA@Example.com ",
            code: " ut1234 "
        )
        #expect(exchange.tokenHash == "hash-from-edge")
        #expect(exchange.type == .signup)
    }

    @Test func serviceNormalizesEmailAndCodeInRequestBody() async throws {
        let userId = UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!
        let service = StagingTestEmailVerificationService(
            urlSession: MockURLSessionFactory.make { request in
                let body = try #require(httpBody(from: request))
                let payload = try #require(JSONSerialization.jsonObject(with: body) as? [String: String])
                #expect(payload["userId"] == userId.uuidString)
                #expect(payload["email"] == "qa@example.com")
                #expect(payload["code"] == "UT1234")
                return MockURLSessionFactory.httpResponse(for: request, statusCode: 200, body: Data("{}".utf8))
            }
        )

        do {
            _ = try await service.exchange(userId: userId, email: "  QA@Example.com ", code: " ut1234 ")
        } catch StagingTestEmailVerificationError.malformedResponse {
            // Expected once the mocked 200 body is intentionally empty.
        }
    }

    @Test func serviceMapsRateLimitResponse() async throws {
        try await expectServiceError(.rateLimited, statusCode: 429)
    }

    @Test func serviceMapsAlreadyConfirmedResponse() async throws {
        try await expectServiceError(.alreadyConfirmed, statusCode: 409)
    }

    @Test func serviceMapsServerDeniedForUnexpectedStatus() async throws {
        try await expectServiceError(.serverDenied, statusCode: 500)
    }

    @Test func serviceMapsMalformedSuccessPayload() async throws {
        let service = StagingTestEmailVerificationService(
            urlSession: MockURLSessionFactory.make { request in
                MockURLSessionFactory.httpResponse(for: request, statusCode: 200, body: Data("{}".utf8))
            }
        )

        do {
            _ = try await service.exchange(
                userId: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
                email: "qa@example.com",
                code: "UT1234"
            )
            Issue.record("Expected malformed response")
        } catch let error as StagingTestEmailVerificationError {
            #expect(error == .malformedResponse)
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

private struct SucceedingStagingVerifier: StagingTestEmailVerifying {
    let tokenHash: String
    let type: EmailOTPType

    func exchange(
        userId: UUID,
        email: String,
        code: String
    ) async throws -> (tokenHash: String, type: EmailOTPType) {
        (tokenHash, type)
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

private func expectServiceError(
    _ expected: StagingTestEmailVerificationError,
    statusCode: Int
) async throws {
    let service = StagingTestEmailVerificationService(
        urlSession: MockURLSessionFactory.make { request in
            MockURLSessionFactory.httpResponse(for: request, statusCode: statusCode)
        }
    )

    do {
        _ = try await service.exchange(
            userId: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
            email: "qa@example.com",
            code: "UT1234"
        )
        Issue.record("Expected \(expected)")
    } catch let error as StagingTestEmailVerificationError {
        #expect(error == expected)
    }
}

private func httpBody(from request: URLRequest) -> Data? {
    if let body = request.httpBody {
        return body
    }
    guard let stream = request.httpBodyStream else { return nil }
    stream.open()
    defer { stream.close() }

    var data = Data()
    let bufferSize = 1024
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { buffer.deallocate() }

    while stream.hasBytesAvailable {
        let read = stream.read(buffer, maxLength: bufferSize)
        if read <= 0 { break }
        data.append(buffer, count: read)
    }
    return data
}

#endif

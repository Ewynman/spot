import Foundation

#if DEBUG || INTERNAL_TESTING

import Supabase

/// Client gate for staging-only internal email verification (`UT####` exchange).
enum StagingTestEmailVerification {
    /// True only for DEBUG / INTERNAL_TESTING builds pointed at staging Supabase.
    static var isAvailable: Bool {
        SupabaseEnvironment.current == .staging
    }

    /// `UT` followed by four digits (e.g. `UT1234`). Actual accepted value is a server secret.
    static func isValidCodeFormat(_ code: String) -> Bool {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard trimmed.count == 6 else { return false }
        guard trimmed.hasPrefix("UT") else { return false }
        return trimmed.dropFirst(2).allSatisfy(\.isNumber)
    }
}

enum StagingTestEmailVerificationError: LocalizedError, Equatable {
    case unavailable
    case invalidFormat
    case missingPendingUser
    case serverDenied
    case rateLimited
    case alreadyConfirmed
    case malformedResponse
    case tokenExchangeFailed

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Internal verification is not available in this build."
        case .invalidFormat:
            return "Enter a valid internal test code."
        case .missingPendingUser:
            return "Missing pending signup. Use the emailed code or sign up again."
        case .serverDenied:
            return "Internal verification failed. Check the code or use the emailed code."
        case .rateLimited:
            return "Too many attempts. Try again later."
        case .alreadyConfirmed:
            return "This account is already verified. Log in instead."
        case .malformedResponse:
            return "Internal verification failed. Try the emailed code."
        case .tokenExchangeFailed:
            return "Could not finish verification. Try the emailed code."
        }
    }
}

protocol StagingTestEmailVerifying {
    func exchange(userId: UUID, email: String, code: String) async throws -> (tokenHash: String, type: EmailOTPType)
}

struct StagingTestEmailVerificationService: StagingTestEmailVerifying {
    func exchange(
        userId: UUID,
        email: String,
        code: String
    ) async throws -> (tokenHash: String, type: EmailOTPType) {
        guard StagingTestEmailVerification.isAvailable else {
            throw StagingTestEmailVerificationError.unavailable
        }
        guard StagingTestEmailVerification.isValidCodeFormat(code) else {
            throw StagingTestEmailVerificationError.invalidFormat
        }

        let config = SupabaseConfiguration.load()
        let url = config.url
            .appendingPathComponent("functions")
            .appendingPathComponent("v1")
            .appendingPathComponent("staging-verify-email")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "userId": userId.uuidString,
            "email": email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            "code": code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw StagingTestEmailVerificationError.serverDenied
        }

        switch http.statusCode {
        case 200:
            break
        case 429:
            throw StagingTestEmailVerificationError.rateLimited
        case 409:
            throw StagingTestEmailVerificationError.alreadyConfirmed
        default:
            throw StagingTestEmailVerificationError.serverDenied
        }

        guard
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let tokenHash = obj["tokenHash"] as? String,
            !tokenHash.isEmpty,
            let typeRaw = obj["type"] as? String,
            let otpType = EmailOTPType(rawValue: typeRaw)
        else {
            throw StagingTestEmailVerificationError.malformedResponse
        }

        return (tokenHash, otpType)
    }
}

#else

/// Production builds omit internal test email verification.
enum StagingTestEmailVerificationUnavailableMarker {}

#endif

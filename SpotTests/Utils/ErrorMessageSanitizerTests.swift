import Foundation
import Testing
@testable import Spot

struct ErrorMessageSanitizerTests {
    @Test func passesThroughSafeShortMessages() {
        #expect(ErrorMessageSanitizer.sanitize("Something went wrong.") == "Something went wrong.")
    }

    @Test func sanitizesDatabaseLeakage() {
        let message = ErrorMessageSanitizer.sanitize("SQLSTATE 23505 postgres constraint violation")
        #expect(message == "A database error occurred. Please try again.")
    }

    @Test func sanitizesNetworkLeakage() {
        let message = ErrorMessageSanitizer.sanitize("Connection timeout talking to localhost")
        #expect(message == "Network error. Please check your connection and try again.")
    }

    @Test func sanitizesAuthTokenLeakage() {
        let message = ErrorMessageSanitizer.sanitize("Invalid jwt refresh_token for session")
        #expect(message == "Authentication error. Please sign in again.")
    }

    @Test func sanitizesLongTechnicalBlobs() {
        let long = String(repeating: "x", count: 201)
        #expect(ErrorMessageSanitizer.sanitize(long) == "A server error occurred. Please try again later.")
    }

    @Test func sanitizesSQLShapeWithoutExplicitDatabaseWord() {
        let message = ErrorMessageSanitizer.sanitize("select * from users where id = 1")
        #expect(message == "A database error occurred. Please try again.")
    }

    @Test func sanitizedErrorPreservesDomainAndCode() {
        let original = NSError(domain: "Auth", code: 42, userInfo: [
            NSLocalizedDescriptionKey: "SQLSTATE boom"
        ])
        let sanitized = ErrorMessageSanitizer.sanitizedError(from: original, domain: "Spot")
        #expect(sanitized.domain == "Spot")
        #expect(sanitized.code == 42)
        #expect(sanitized.localizedDescription == "A database error occurred. Please try again.")
    }
}

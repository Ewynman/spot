//
//  SpotLoggerTests.swift
//  SpotTests
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation
import Testing
@testable import Spot

struct SpotLoggerTests {
    private enum TestLog: SpotLog {
        case sessionRefreshFailed

        var tag: String { "AuthService" }
        var level: LogLevel { .error }
        var message: String { "Session refresh failed" }
    }

    // MARK: - SpotLog protocol conformance

    @Test func spotServiceLogsConformsToSpotLog() {
        let entry: any SpotLog = SpotServiceLogs.spotFetched
        #expect(entry.tag == "SpotService")
        #expect(entry.level == .info)
        #expect(!entry.message.isEmpty)
    }

    @Test func loggingProfilesHaveStableUserFacingCopy() {
        #expect(LoggingProfile.allCases.map(\.title) == [
            "0 — Errors only",
            "1 — Info + errors",
            "2 — Debug + info + errors",
            "3 — UI only",
            "4 — All logs"
        ])
        #expect(LoggingProfile.allCases.map(\.summary) == [
            "Failures that require investigation.",
            "Important app activity and failures.",
            "Development detail without high-frequency debug events.",
            "Events emitted directly by SwiftUI views.",
            "Every event, including noisy diagnostics."
        ])
    }

    // MARK: - SpotServiceLogs cases

    @Test func spotServiceLogsLevels() {
        #expect(SpotServiceLogs.cachedSpotsReturned.level == .info)
        #expect(SpotServiceLogs.fetchSpotsStarted.level == .debug)
        #expect(SpotServiceLogs.fetchSpotsError.level == .error)
        #expect(SpotServiceLogs.spotDocSkipped.level == .debug)
        #expect(SpotServiceLogs.spotsCachedForMap.level == .info)
        #expect(SpotServiceLogs.storageDeleteFailed.level == .error)
        #expect(SpotServiceLogs.storageDeleted.level == .info)
    }

    @Test func spotServiceLogsMessages() {
        #expect(SpotServiceLogs.cachedSpotsReturned.message == "Returning cached spots")
        #expect(SpotServiceLogs.spotFetched.message == "Fetched spot")
        #expect(SpotServiceLogs.spotNotFound.message == "Spot not found")
        #expect(SpotServiceLogs.fetchSpotsError.message == "fetchSpotsForMap error")
    }

    @Test func spotServiceLogsTags() {
        for logCase in [
            SpotServiceLogs.spotFetched,
            SpotServiceLogs.fetchSpotsError,
            SpotServiceLogs.storageDeleted
        ] {
            #expect(logCase.tag == "SpotService")
        }
    }

    // MARK: - Formatted output

    @Test func logFormattedOutputWithoutDetails() {
        let output = SpotLogger.body(for: SpotServiceLogs.spotFetched, details: [:])
        #expect(output == "SpotService Fetched spot")
    }

    @Test func logFormattedOutputWithDetails() {
        let output = SpotLogger.body(
            for: TestLog.sessionRefreshFailed,
            details: [
                "responseCode": 401,
                "errorMessage": "Session expired",
                "retrying": true
            ]
        )
        #expect(
            output == """
            AuthService Session refresh failed
            [
                errorMessage: "Session expired"
                responseCode: 401
                retrying: true
            ]
            """
        )
    }

    @Test func sensitiveDetailsAreRedactedOrShortened() {
        let output = SpotLogger.body(
            for: TestLog.sessionRefreshFailed,
            details: [
                "email": "person@example.com",
                "latitude": 37.1234,
                "signedURL": "https://example.com/private/file?token=secret",
                "assetURL": URL(string: "https://example.com/private/typed")!,
                "userId": "12345678-1234-1234-1234-123456789abc",
                "authorId": "abcdefab-cdef-cdef-cdef-abcdefabcdef",
                "errorMessage": "Failed for person@example.com at https://example.com/private",
                "prefix": "private search",
                "bodyPreview": Optional("private response") as Any,
                "mimeType": Optional<String>.none as Any
            ]
        )

        #expect(!output.contains("person@example.com"))
        #expect(!output.contains("37.1234"))
        #expect(!output.contains("token=secret"))
        #expect(!output.contains("/private/typed"))
        #expect(!output.contains("12345678-1234-1234-1234"))
        #expect(!output.contains("abcdefab-cdef-cdef-cdef"))
        #expect(!output.contains("private search"))
        #expect(!output.contains("private response"))
        #expect(output.contains("userId: \"…56789abc\""))
        #expect(output.contains("mimeType: nil"))
    }

    @Test func profilesApplyExpectedFilters() {
        let serviceFile = "/app/Services/AuthService.swift"
        let viewFile = "/app/Views/LoginView.swift"

        #expect(SpotLogger.shouldEmit(level: .error, tag: "AuthService", file: serviceFile, profile: .errorsOnly))
        #expect(!SpotLogger.shouldEmit(level: .info, tag: "AuthService", file: serviceFile, profile: .errorsOnly))
        #expect(SpotLogger.shouldEmit(level: .info, tag: "AuthService", file: serviceFile, profile: .information))
        #expect(!SpotLogger.shouldEmit(level: .debug, tag: "AuthService", file: serviceFile, profile: .information))
        #expect(SpotLogger.shouldEmit(level: .debug, tag: "AuthService", file: serviceFile, profile: .debugging))
        #expect(!SpotLogger.shouldEmit(level: .debug, tag: "LocationManager", file: serviceFile, profile: .debugging))
        #expect(!SpotLogger.shouldEmit(level: .debug, tag: "SpotSearchDataSource", file: serviceFile, profile: .debugging))
        #expect(SpotLogger.shouldEmit(level: .debug, tag: "LoginView", file: viewFile, profile: .uiOnly))
        #expect(!SpotLogger.shouldEmit(level: .error, tag: "AuthService", file: serviceFile, profile: .uiOnly))
        #expect(SpotLogger.shouldEmit(level: .debug, tag: "LocationManager", file: serviceFile, profile: .all))
    }

    #if DEBUG
    @Test func debugLogFileIsSeededWithSessionHeader() throws {
        SpotLogger.ensureDebugLogFile()

        let url = try #require(SpotLogger.debugLogFileURL)
        #expect(url.lastPathComponent == "spot-debug.txt")
        #expect(FileManager.default.fileExists(atPath: url.path))

        let contents = try String(contentsOf: url, encoding: .utf8)
        #expect(contents.contains("--- Spot DEBUG session "))
    }
    #endif
}

//
//  SpotLoggerTests.swift
//  SpotTests
//
//  Tests for the structured SpotLog protocol and SpotLogger.log() method.
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
                "userId": "12345678-1234-1234-1234-123456789abc",
                "errorMessage": "Failed for person@example.com at https://example.com/private"
            ]
        )

        #expect(!output.contains("person@example.com"))
        #expect(!output.contains("37.1234"))
        #expect(!output.contains("token=secret"))
        #expect(!output.contains("12345678-1234-1234-1234"))
        #expect(output.contains("userId: \"…56789abc\""))
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
        #expect(SpotLogger.shouldEmit(level: .debug, tag: "LoginView", file: viewFile, profile: .uiOnly))
        #expect(!SpotLogger.shouldEmit(level: .error, tag: "AuthService", file: serviceFile, profile: .uiOnly))
        #expect(SpotLogger.shouldEmit(level: .debug, tag: "LocationManager", file: serviceFile, profile: .all))
    }
}

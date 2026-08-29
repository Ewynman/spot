//
//  TokenServiceProjectIsolationTests.swift
//  SpotTests
//
//  Created by Edward Wynman on 8/28/26.
//

import XCTest
@testable import Spot

final class TokenServiceProjectIsolationTests: XCTestCase {
    func testShouldResetSessionWhenProjectChangesFromStagingToProduction() {
        XCTAssertTrue(
            TokenService.shared.shouldResetSession(
                previousProjectRef: SupabaseEnvironment.stagingProjectRef,
                currentProjectRef: SupabaseEnvironment.productionProjectRef
            )
        )
    }

    func testShouldResetSessionWhenProjectChangesFromProductionToStaging() {
        XCTAssertTrue(
            TokenService.shared.shouldResetSession(
                previousProjectRef: SupabaseEnvironment.productionProjectRef,
                currentProjectRef: SupabaseEnvironment.stagingProjectRef
            )
        )
    }

    func testDoesNotResetSessionForSameProjectUpdate() {
        XCTAssertFalse(
            TokenService.shared.shouldResetSession(
                previousProjectRef: SupabaseEnvironment.stagingProjectRef,
                currentProjectRef: SupabaseEnvironment.stagingProjectRef
            )
        )
    }

    func testDoesNotResetSessionOnFreshInstallWithoutStoredProjectRef() {
        XCTAssertFalse(
            TokenService.shared.shouldResetSession(
                previousProjectRef: nil,
                currentProjectRef: SupabaseEnvironment.stagingProjectRef
            )
        )
    }

    func testScopedTokenKeyIncludesProjectReference() {
        let key = TokenService.shared.scopedKey(
            baseKey: "com.spotapp.spot.supabaseAccessToken",
            projectRef: SupabaseEnvironment.stagingProjectRef
        )
        XCTAssertEqual(
            key,
            "com.spotapp.spot.supabaseAccessToken.\(SupabaseEnvironment.stagingProjectRef)"
        )
    }

    func testExpiredTokenStillRequiresResetAfterEnvironmentSwitch() {
        XCTAssertTrue(
            TokenService.shared.shouldResetSession(
                previousProjectRef: SupabaseEnvironment.stagingProjectRef,
                currentProjectRef: SupabaseEnvironment.productionProjectRef
            )
        )
    }
}

//
//  SupabaseEnvironmentConfigurationTests.swift
//  SpotTests
//
//  Created by Cloud Agent on 7/6/2026.
//

import XCTest
@testable import Spot

final class SupabaseEnvironmentConfigurationTests: XCTestCase {
    
    // MARK: - SupabaseEnvironment Tests
    
    func testStagingEnvironmentProperties() {
        let env = SupabaseEnvironment.staging
        
        // Verify staging URL
        XCTAssertEqual(env.url, "https://aeurigbbohyxvtsfiyul.supabase.co")
        
        // Verify staging anon key is not empty and not a placeholder
        XCTAssertFalse(env.anonKey.isEmpty)
        XCTAssertFalse(env.anonKey.contains("PLACEHOLDER"))
        XCTAssertTrue(env.anonKey.hasPrefix("sb_publishable_"))
        
        // Verify display name
        XCTAssertEqual(env.displayName, "staging")
        XCTAssertEqual(env.projectRef, SupabaseEnvironment.stagingProjectRef)
    }
    
    func testProductionEnvironmentProperties() {
        let env = SupabaseEnvironment.production
        
        // Verify production URL format (may be placeholder until production project is created)
        XCTAssertTrue(env.url.contains("supabase.co"))
        
        // Verify anon key exists (may be placeholder)
        XCTAssertFalse(env.anonKey.isEmpty)
        
        // Verify display name
        XCTAssertEqual(env.displayName, "production")
        XCTAssertEqual(env.projectRef, SupabaseEnvironment.productionProjectRef)
    }
    
    func testCurrentEnvironmentInDebugBuild() {
        // In DEBUG builds (test target), current should be staging
        #if DEBUG
        XCTAssertEqual(SupabaseEnvironment.current, .staging)
        #else
        XCTAssertEqual(SupabaseEnvironment.current, .production)
        #endif
    }
    
    func testEnvironmentURLsAreDifferent() {
        // Staging and production should have different URLs
        XCTAssertNotEqual(
            SupabaseEnvironment.staging.url,
            SupabaseEnvironment.production.url
        )
    }
    
    func testEnvironmentAnonKeysAreDifferent() {
        // Staging and production should have different anon keys
        XCTAssertNotEqual(
            SupabaseEnvironment.staging.anonKey,
            SupabaseEnvironment.production.anonKey
        )
    }
    
    func testStagingURLIsValidFormat() {
        let urlString = SupabaseEnvironment.staging.url
        XCTAssertTrue(urlString.hasPrefix("https://"))
        XCTAssertTrue(urlString.contains(".supabase.co"))
    }
    
    func testProductionURLIsValidFormat() {
        let urlString = SupabaseEnvironment.production.url
        XCTAssertTrue(urlString.hasPrefix("https://"))
        XCTAssertTrue(urlString.contains(".supabase.co"))
    }
    
    // MARK: - SupabaseConfiguration Tests
    
    func testConfigurationLoadInDebugReturnsValidURL() {
        let config = SupabaseConfiguration.load()
        
        // Should return a valid URL
        XCTAssertNotNil(config.url)
        XCTAssertTrue(config.url.absoluteString.contains("supabase.co"))
    }
    
    func testConfigurationLoadInDebugReturnsNonEmptyAnonKey() {
        let config = SupabaseConfiguration.load()
        
        // Should return a non-empty anon key
        XCTAssertFalse(config.anonKey.isEmpty)
    }
    
    func testConfigurationLoadReturnsCorrectEnvironment() {
        let config = SupabaseConfiguration.load()
        
        // In DEBUG builds, should return staging
        #if DEBUG
        XCTAssertEqual(config.environment, .staging)
        #else
        XCTAssertEqual(config.environment, .production)
        #endif
    }
    
    func testConfigurationURLMatchesEnvironmentURL() {
        let config = SupabaseConfiguration.load()
        let expectedURLString = SupabaseEnvironment.current.url
        
        // URL should match the current environment's URL
        // (unless overridden by Info.plist in RELEASE builds)
        #if DEBUG
        XCTAssertEqual(config.url.absoluteString, expectedURLString)
        #endif
    }
    
    func testConfigurationAnonKeyMatchesEnvironmentKey() {
        let config = SupabaseConfiguration.load()
        let expectedKey = SupabaseEnvironment.current.anonKey
        
        // Anon key should match the current environment's key
        // (unless overridden by Info.plist in RELEASE builds)
        #if DEBUG
        XCTAssertEqual(config.anonKey, expectedKey)
        #endif
    }
    
    func testStagingConfigurationDoesNotContainPlaceholder() {
        // Staging environment should have real values, not placeholders
        let stagingEnv = SupabaseEnvironment.staging
        
        XCTAssertFalse(stagingEnv.url.contains("PLACEHOLDER"))
        XCTAssertFalse(stagingEnv.anonKey.contains("PLACEHOLDER"))
    }
    
    func testConfigurationLoadSucceedsMultipleTimes() {
        // Loading configuration multiple times should succeed
        let config1 = SupabaseConfiguration.load()
        let config2 = SupabaseConfiguration.load()
        
        XCTAssertEqual(config1.url, config2.url)
        XCTAssertEqual(config1.anonKey, config2.anonKey)
        XCTAssertEqual(config1.environment, config2.environment)
    }
    
    func testEnvironmentDisplayNamesAreUserFriendly() {
        // Display names should be human-readable
        XCTAssertEqual(SupabaseEnvironment.staging.displayName, "staging")
        XCTAssertEqual(SupabaseEnvironment.production.displayName, "production")
        
        // Should not be empty
        XCTAssertFalse(SupabaseEnvironment.staging.displayName.isEmpty)
        XCTAssertFalse(SupabaseEnvironment.production.displayName.isEmpty)
    }
    
    func testStagingAnonKeyHasCorrectFormat() {
        let anonKey = SupabaseEnvironment.staging.anonKey
        
        // Supabase anon keys should start with specific prefix
        XCTAssertTrue(
            anonKey.hasPrefix("sb_publishable_") || anonKey.hasPrefix("eyJ"),
            "Anon key should have Supabase format"
        )
    }
    
    // MARK: - Integration Tests
    
    func testGlobalSupabaseClientIsInitialized() {
        // The global supabase client should be accessible and functional
        XCTAssertNotNil(supabase)
        // Client should have auth property
        XCTAssertNotNil(supabase.auth)
    }
    
    func testEnvironmentEquality() {
        // Test that enum cases compare correctly
        XCTAssertEqual(SupabaseEnvironment.staging, SupabaseEnvironment.staging)
        XCTAssertEqual(SupabaseEnvironment.production, SupabaseEnvironment.production)
        XCTAssertNotEqual(SupabaseEnvironment.staging, SupabaseEnvironment.production)
    }

    func testProjectRefExtractedFromKnownURL() throws {
        let url = try XCTUnwrap(URL(string: SupabaseEnvironment.staging.url))
        XCTAssertEqual(SupabaseEnvironment.projectRef(from: url), SupabaseEnvironment.stagingProjectRef)
    }

    func testEnvironmentResolvedFromProjectRef() {
        XCTAssertEqual(SupabaseEnvironment.from(projectRef: SupabaseEnvironment.stagingProjectRef), .staging)
        XCTAssertEqual(SupabaseEnvironment.from(projectRef: SupabaseEnvironment.productionProjectRef), .production)
        XCTAssertNil(SupabaseEnvironment.from(projectRef: "unknown-ref"))
    }
}

//
//  Supabase.swift
//  Spot
//
//  Created by Edward Wynman on 4/19/26.
//

import Foundation
import Supabase

// MARK: - Environment Configuration

enum SupabaseEnvironment: Equatable {
    case staging
    case production

    static let stagingProjectRef = "aeurigbbohyxvtsfiyul"
    static let productionProjectRef = "gomdoguewaawdlvijahg"

    static var current: SupabaseEnvironment {
        #if DEBUG || INTERNAL_TESTING
        return .staging
        #else
        return .production
        #endif
    }

    var url: String {
        switch self {
        case .staging:
            return "https://\(Self.stagingProjectRef).supabase.co"
        case .production:
            return "https://\(Self.productionProjectRef).supabase.co"
        }
    }

    var anonKey: String {
        switch self {
        case .staging:
            return "sb_publishable_5IKZU3dDw6C0-V9lRPc7vw_z_v8a08G"
        case .production:
            return "PLACEHOLDER_PRODUCTION_KEY_MUST_BE_INJECTED"
        }
    }

    var displayName: String {
        switch self {
        case .staging:
            return "staging"
        case .production:
            return "production"
        }
    }

    var projectRef: String {
        switch self {
        case .staging:
            return Self.stagingProjectRef
        case .production:
            return Self.productionProjectRef
        }
    }

    static func projectRef(from url: URL) -> String? {
        guard let host = url.host?.lowercased(),
              host.hasSuffix(".supabase.co") else {
            return nil
        }
        return host.replacingOccurrences(of: ".supabase.co", with: "")
    }

    static func from(projectRef: String) -> SupabaseEnvironment? {
        switch projectRef.lowercased() {
        case stagingProjectRef:
            return .staging
        case productionProjectRef:
            return .production
        default:
            return nil
        }
    }
}

enum SupabaseConfiguration {
    static func load() -> (url: URL, anonKey: String, environment: SupabaseEnvironment, projectRef: String) {
        let expectedEnvironment = SupabaseEnvironment.current

        #if DEBUG
        guard let url = URL(string: expectedEnvironment.url),
              !expectedEnvironment.anonKey.isEmpty else {
            fatalError("Supabase staging configuration is invalid for DEBUG builds.")
        }
        return (
            url: url,
            anonKey: expectedEnvironment.anonKey,
            environment: expectedEnvironment,
            projectRef: expectedEnvironment.projectRef
        )
        #else
        guard let plistConfig = loadFromPlist() else {
            fatalError("Supabase configuration missing from Info.plist for non-debug build.")
        }

        guard !plistConfig.anonKey.isEmpty,
              !plistConfig.anonKey.contains("PLACEHOLDER") else {
            fatalError("Supabase anon key is missing or placeholder in Info.plist.")
        }

        guard let resolvedProjectRef = SupabaseEnvironment.projectRef(from: plistConfig.url),
              let resolvedEnvironment = SupabaseEnvironment.from(projectRef: resolvedProjectRef) else {
            fatalError("Supabase URL must target a known Spot Supabase project.")
        }

        guard resolvedEnvironment == expectedEnvironment else {
            fatalError("""
                Supabase environment mismatch.
                Expected: \(expectedEnvironment.displayName) (\(expectedEnvironment.projectRef))
                Actual: \(resolvedEnvironment.displayName) (\(resolvedProjectRef))
                """)
        }

        return (
            url: plistConfig.url,
            anonKey: plistConfig.anonKey,
            environment: resolvedEnvironment,
            projectRef: resolvedProjectRef
        )
        #endif
    }

    private static func loadFromPlist() -> (url: URL, anonKey: String)? {
        guard let path = Bundle.main.path(forResource: "Info", ofType: "plist"),
              let root = NSDictionary(contentsOfFile: path) as? [String: Any],
              let supabase = root["Supabase"] as? [String: Any],
              let urlString = supabase["url"] as? String,
              let anonKey = supabase["anonKey"] as? String,
              let url = URL(string: urlString) else {
            return nil
        }
        return (url, anonKey)
    }
}

let supabase: SupabaseClient = {
    let config = SupabaseConfiguration.load()

    #if DEBUG || INTERNAL_TESTING
    SpotLogger.log(
        SupabaseConfigurationLogs.configurationLoaded,
        details: [
            "environment": config.environment.displayName,
            "urlHost": config.url.host ?? "unknown"
        ]
    )
    #endif

    return SupabaseClient(
        supabaseURL: config.url,
        supabaseKey: config.anonKey,
        options: SupabaseClientOptions(
            auth: .init(emitLocalSessionAsInitialSession: true)
        )
    )
}()

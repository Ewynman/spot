//
//  Supabase.swift
//  Spot
//
//  Created By Edward Wynman on 4/19/2026.
//

import Foundation
import Supabase

// MARK: - Environment Configuration

/// Environment configuration for Supabase connections.
/// - In DEBUG builds: uses staging environment (current project: aeurigbbohyxvtsfiyul)
/// - In RELEASE builds: uses production environment (to be created)
enum SupabaseEnvironment {
    case staging
    case production
    
    /// Current environment based on build configuration.
    /// DEBUG builds use staging; RELEASE builds use production.
    static var current: SupabaseEnvironment {
        #if DEBUG
        return .staging
        #else
        return .production
        #endif
    }
    
    /// Supabase project URL for the current environment.
    var url: String {
        switch self {
        case .staging:
            // Current project (will be used for Firebase App Distribution testing builds)
            return "https://aeurigbbohyxvtsfiyul.supabase.co"
        case .production:
            // Production project (created: 2026-07-08, ID: gomdoguewaawdlvijahg)
            // This will be injected by CI/CD from GitHub secrets for release builds
            return "https://gomdoguewaawdlvijahg.supabase.co"
        }
    }
    
    /// Supabase anon/publishable key for the current environment.
    var anonKey: String {
        switch self {
        case .staging:
            // Current project anon key (testing/development)
            return "sb_publishable_5IKZU3dDw6C0-V9lRPc7vw_z_v8a08G"
        case .production:
            // Production anon key (will be injected by CI/CD from GitHub secrets)
            return "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdvbWRvZ3Vld2Fhd2RsdmlqYWhnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM1MTY4MjIsImV4cCI6MjA5OTA5MjgyMn0.pNezI--Bxni589iGsW33ni8VxlE9tFq_oKmiXnGURxE"
        }
    }
    
    /// Human-readable environment name for logging.
    var displayName: String {
        switch self {
        case .staging:
            return "Staging"
        case .production:
            return "Production"
        }
    }
}

/// Configuration loader that supports both environment-based and Info.plist-based configuration.
/// - In DEBUG: uses SupabaseEnvironment enum directly
/// - In RELEASE: attempts to load from Info.plist first (for CI/CD injection), falls back to enum
enum SupabaseConfiguration {
    /// Load Supabase configuration from Info.plist or environment defaults.
    static func load() -> (url: URL, anonKey: String, environment: SupabaseEnvironment) {
        let environment = SupabaseEnvironment.current
        
        // For RELEASE builds, try to load from Info.plist first (CI/CD may inject values)
        #if !DEBUG
        if let plistConfig = loadFromPlist(), 
           !plistConfig.url.absoluteString.contains("PLACEHOLDER"),
           !plistConfig.anonKey.contains("PLACEHOLDER") {
            return (plistConfig.url, plistConfig.anonKey, environment)
        }
        #endif
        
        // Fall back to environment-based configuration
        let urlString = environment.url
        let anonKey = environment.anonKey
        
        guard let url = URL(string: urlString),
              !anonKey.contains("PLACEHOLDER") else {
            fatalError("""
                Supabase configuration error:
                Environment: \(environment.displayName)
                
                Production builds require a valid Supabase project.
                Either:
                1. Create a new production Supabase project and update SupabaseEnvironment
                2. Configure CI/CD to inject credentials into Info.plist
                
                See docs/engineering/supabase-environment-strategy.md for setup instructions.
                """)
        }
        
        return (url, anonKey, environment)
    }
    
    /// Attempt to load configuration from Info.plist (used by CI/CD injection).
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

// MARK: - Global Supabase Client

let supabase: SupabaseClient = {
    let config = SupabaseConfiguration.load()
    
    #if DEBUG
    // Log environment in DEBUG builds only (never log in production)
    print("🔧 Supabase Environment: \(config.environment.displayName)")
    print("🔧 Supabase URL: \(config.url.absoluteString)")
    #endif
    
    return SupabaseClient(
        supabaseURL: config.url,
        supabaseKey: config.anonKey,
        options: SupabaseClientOptions(
            auth: .init(emitLocalSessionAsInitialSession: true)
        )
    )
}()

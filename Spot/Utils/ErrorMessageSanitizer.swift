//
//  ErrorMessageSanitizer.swift
//  Spot
//
//  Sanitizes error messages to prevent information leakage.
//

import Foundation

enum ErrorMessageSanitizer {
    /// Patterns that may expose sensitive system information
    private static let sensitivePatterns = [
        // Database errors
        "SQLSTATE", "postgres", "pg_", "relation", "schema", "constraint",
        // Network errors with internal details
        "localhost", "127.0.0.1", "internal", "stack trace",
        // Auth internals
        "jwt", "token", "session_id", "refresh_token",
        // Paths
        "/var/", "/usr/", "/opt/", "/home/", "/Users/",
        // UUIDs in error messages (may reveal internal IDs)
        #"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"#,
    ]
    
    /// User-friendly messages for common error categories
    private static let genericMessages: [String: String] = [
        "database": "A database error occurred. Please try again.",
        "network": "Network error. Please check your connection and try again.",
        "auth": "Authentication error. Please sign in again.",
        "validation": "Invalid input. Please check your information and try again.",
        "permission": "You don't have permission to perform this action.",
        "notfound": "The requested resource was not found.",
        "server": "A server error occurred. Please try again later.",
    ]
    
    /// Sanitizes an error message for display to the user.
    /// Returns a user-friendly message that doesn't expose system internals.
    static func sanitize(_ message: String) -> String {
        let lower = message.lowercased()
        
        // Check if message contains sensitive patterns
        for pattern in sensitivePatterns {
            if lower.contains(pattern.lowercased()) {
                return categorizeAndSanitize(lower)
            }
        }
        
        // Check for long technical messages (likely internal errors)
        if message.count > 200 {
            return categorizeAndSanitize(lower)
        }
        
        // Message seems safe, but still check for specific categories
        if containsSensitiveInfo(lower) {
            return categorizeAndSanitize(lower)
        }
        
        // Message appears safe to show
        return message
    }
    
    /// Sanitizes an Error object for display.
    static func sanitize(_ error: Error) -> String {
        sanitize(error.localizedDescription)
    }
    
    /// Checks if message contains patterns indicating sensitive information.
    private static func containsSensitiveInfo(_ lower: String) -> Bool {
        // Check for SQL-like patterns
        if lower.contains("select ") || lower.contains("insert ") || lower.contains("update ") || lower.contains("delete ") {
            return true
        }
        
        // Check for stack trace indicators
        if lower.contains("at line ") || lower.contains("error code:") || lower.contains("exception:") {
            return true
        }
        
        // Check for internal server paths or technical jargon
        if lower.contains("function") && lower.contains("()") {
            return true
        }
        
        return false
    }
    
    /// Categorizes the error and returns appropriate generic message.
    private static func categorizeAndSanitize(_ lower: String) -> String {
        if lower.contains("database")
            || lower.contains("sql")
            || lower.contains("postgres")
            || lower.contains("select ")
            || lower.contains("insert ")
            || lower.contains("update ")
            || lower.contains("delete ") {
            return genericMessages["database"]!
        }

        if lower.contains("network") || lower.contains("connection") || lower.contains("timeout") {
            return genericMessages["network"]!
        }

        // Prefer auth over generic "invalid …" when credentials/tokens are present.
        if lower.contains("auth")
            || lower.contains("unauthorized")
            || lower.contains("jwt")
            || lower.contains("token")
            || lower.contains("session") {
            return genericMessages["auth"]!
        }

        if lower.contains("denied") || lower.contains("forbidden") || lower.contains("403") {
            return genericMessages["permission"]!
        }

        if lower.contains("validation") || lower.contains("invalid") || lower.contains("required") {
            return genericMessages["validation"]!
        }

        if lower.contains("not found") || lower.contains("404") {
            return genericMessages["notfound"]!
        }

        // Default to generic server error
        return genericMessages["server"]!
    }
    
    /// Creates a user-friendly NSError with sanitized message.
    static func sanitizedError(from error: Error, domain: String = "Spot") -> NSError {
        let sanitizedMessage = sanitize(error)
        return NSError(
            domain: domain,
            code: (error as NSError).code,
            userInfo: [NSLocalizedDescriptionKey: sanitizedMessage]
        )
    }
}

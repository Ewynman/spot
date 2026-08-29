//
//  InputValidation.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum InputValidation {
    // MARK: - Username Validation

    static let usernameMinLength = 2
    static let usernameMaxLength = 30

    /// Validates username length and character requirements.
    /// Returns nil if valid, or an error message if invalid.
    static func validateUsername(_ username: String) -> String? {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            return "Username cannot be empty"
        }

        if trimmed.count < usernameMinLength {
            return "Username must be at least \(usernameMinLength) characters"
        }

        if trimmed.count > usernameMaxLength {
            return "Username cannot exceed \(usernameMaxLength) characters"
        }

        // Check for valid characters (alphanumeric, underscore, hyphen)
        let allowedCharacterSet = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-")
        if trimmed.rangeOfCharacter(from: allowedCharacterSet.inverted) != nil {
            return "Username can only contain letters, numbers, underscores, and hyphens"
        }

        return nil
    }

    // MARK: - Email Validation

    static let emailMaxLength = 254 // RFC 5321

    /// Validates email format and length.
    /// Returns nil if valid, or an error message if invalid.
    static func validateEmail(_ email: String) -> String? {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            return "Email cannot be empty"
        }

        if trimmed.count > emailMaxLength {
            return "Email exceeds maximum length"
        }

        // Basic email regex pattern
        let emailPattern = #"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"#
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailPattern)
        if !emailPredicate.evaluate(with: trimmed) {
            return "Invalid email format"
        }

        return nil
    }

    // MARK: - Coordinate Validation

    /// Validates latitude is within valid range [-90, 90].
    /// Returns nil if valid, or an error message if invalid.
    static func validateLatitude(_ latitude: Double) -> String? {
        if latitude.isNaN || latitude.isInfinite {
            return "Invalid latitude value"
        }

        if latitude < -90.0 || latitude > 90.0 {
            return "Latitude must be between -90 and 90 degrees"
        }

        return nil
    }

    /// Validates longitude is within valid range [-180, 180].
    /// Returns nil if valid, or an error message if invalid.
    static func validateLongitude(_ longitude: Double) -> String? {
        if longitude.isNaN || longitude.isInfinite {
            return "Invalid longitude value"
        }

        if longitude < -180.0 || longitude > 180.0 {
            return "Longitude must be between -180 and 180 degrees"
        }

        return nil
    }

    /// Validates both latitude and longitude coordinates.
    /// Returns nil if valid, or an error message if invalid.
    static func validateCoordinates(latitude: Double, longitude: Double) -> String? {
        if let latError = validateLatitude(latitude) {
            return latError
        }

        if let lonError = validateLongitude(longitude) {
            return lonError
        }

        return nil
    }

    // MARK: - Text Length Validation

    static let locationNameMaxLength = 255
    static let captionMaxLength = 1000
    static let reportDetailsMaxLength = 2000

    /// Validates location name length.
    /// Returns nil if valid, or an error message if invalid.
    static func validateLocationName(_ locationName: String) -> String? {
        let trimmed = locationName.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            return "Location name cannot be empty"
        }

        if trimmed.count > locationNameMaxLength {
            return "Location name exceeds maximum length of \(locationNameMaxLength) characters"
        }

        return nil
    }

    /// Validates caption length (optional field).
    /// Returns nil if valid, or an error message if invalid.
    static func validateCaption(_ caption: String?) -> String? {
        guard let caption = caption else {
            return nil // Caption is optional
        }

        let trimmed = caption.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.count > captionMaxLength {
            return "Caption exceeds maximum length of \(captionMaxLength) characters"
        }

        return nil
    }

    /// Validates report details length.
    /// Returns nil if valid, or an error message if invalid.
    static func validateReportDetails(_ details: String) -> String? {
        let trimmed = details.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.count > reportDetailsMaxLength {
            return "Details exceed maximum length of \(reportDetailsMaxLength) characters"
        }

        return nil
    }

    // MARK: - UUID Validation

    /// Safely parses a UUID string, returning nil if invalid.
    /// Logs validation failures for debugging.
    static func parseUUID(_ uuidString: String?, context: String = "unknown") -> UUID? {
        guard let uuidString = uuidString?.trimmingCharacters(in: .whitespacesAndNewlines),
              !uuidString.isEmpty else {
            SpotLogger.log(InputValidationLogs.uuidParseFailedEmpty, details: ["context": context])
            return nil
        }

        guard let uuid = UUID(uuidString: uuidString) else {
            SpotLogger.log(InputValidationLogs.uuidParseFailedInvalid, details: [
                "context": context,
                "input": String(uuidString.prefix(20)) // Log prefix only for privacy
            ])
            return nil
        }

        return uuid
    }

    // MARK: - Collection Size Validation

    /// Validates array is not empty and within reasonable limits.
    static func validateArraySize<T>(_ array: [T], minSize: Int = 1, maxSize: Int = 100, fieldName: String = "array") -> String? {
        if array.count < minSize {
            return "\(fieldName) must contain at least \(minSize) item(s)"
        }

        if array.count > maxSize {
            return "\(fieldName) cannot contain more than \(maxSize) items"
        }

        return nil
    }
}

// MARK: - Logging

enum InputValidationLogs: SpotLog {
    case uuidParseFailedEmpty
    case uuidParseFailedInvalid
    case validationFailed

    var tag: String { "InputValidation" }

    var message: String {
        switch self {
        case .uuidParseFailedEmpty:
            return "UUID parse failed: empty or nil string"
        case .uuidParseFailedInvalid:
            return "UUID parse failed: invalid format"
        case .validationFailed:
            return "Input validation failed"
        }
    }

    var level: LogLevel {
        switch self {
        case .uuidParseFailedEmpty, .uuidParseFailedInvalid, .validationFailed:
            return .info
        }
    }
}

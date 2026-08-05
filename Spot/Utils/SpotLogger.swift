import Foundation
import os
#if DEBUG
import Darwin
#endif

// MARK: - Structured log definitions

protocol SpotLog {
    var tag: String { get }
    var level: LogLevel { get }
    var message: String { get }
}

enum LogLevel: String, CaseIterable, Comparable {
    case debug = "DEBUG"
    case info = "INFO"
    case error = "ERROR"

    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        let order: [LogLevel] = [.debug, .info, .error]
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
}

/// Root logging profiles exposed by the DEBUG settings screen.
///
/// Profile 2 intentionally omits known high-frequency debug diagnostics.
/// Profile 4 is the explicit opt-in for those noisy events.
enum LoggingProfile: Int, CaseIterable, Identifiable {
    case errorsOnly = 0
    case information = 1
    case debugging = 2
    case uiOnly = 3
    case all = 4

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .errorsOnly: return "0 — Errors only"
        case .information: return "1 — Info + errors"
        case .debugging: return "2 — Debug + info + errors"
        case .uiOnly: return "3 — UI only"
        case .all: return "4 — All logs"
        }
    }

    var summary: String {
        switch self {
        case .errorsOnly: return "Failures that require investigation."
        case .information: return "Important app activity and failures."
        case .debugging: return "Development detail without high-frequency debug events."
        case .uiOnly: return "Events emitted directly by SwiftUI views."
        case .all: return "Every event, including noisy diagnostics."
        }
    }
}

final class SpotLogger {
    static let shared = SpotLogger()
    private init() {}

    private static let profileLock = NSLock()
    private static var activeProfile: LoggingProfile = .errorsOnly
    private static let detailsIndentation = "    "
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.spotapp.spot",
        category: "SpotLogger"
    )
    private static let noisyTags: Set<String> = [
        "AnalyticsService",
        "DeepLinkRouter",
        "FeedEventService",
        "FeedSupabase",
        "ImageService",
        "LocationManager",
        "LocationSelectionView",
        "MapMarker",
        "MapView",
        "MapViewModel",
        "SearchViewModel",
        "SpotSearchDataSource",
        "SpotCard"
    ]

    static var profile: LoggingProfile {
        profileLock.lock()
        defer { profileLock.unlock() }
        return activeProfile
    }

    static func setProfile(_ newProfile: LoggingProfile) {
        profileLock.lock()
        activeProfile = newProfile
        profileLock.unlock()
    }

    /// Emits one log through the shared logger.
    ///
    /// Output format:
    /// ```
    /// <tag> <message>
    /// [
    ///     key: value
    /// ]
    /// ```
    static func log(
        _ entry: some SpotLog,
        details: [String: Any] = [:],
        file: String = #file
    ) {
        guard shouldEmit(entry: entry, file: file) else { return }
        emit(entry.level, message: body(for: entry, details: details))
    }

    /// Exposed internally so formatting and privacy behavior can be unit tested.
    static func body(for entry: some SpotLog, details: [String: Any]) -> String {
        let header = "\(entry.tag) \(entry.message)"
        guard !details.isEmpty else { return header }

        let lines = details
            .map { key, value in
                "\(detailsIndentation)\(key): \(formatted(value, forKey: key))"
            }
            .sorted()
            .joined(separator: "\n")
        return "\(header)\n[\n\(lines)\n]"
    }

    // MARK: - Filtering

    static func shouldEmit(
        level: LogLevel,
        tag: String,
        file: String,
        profile: LoggingProfile
    ) -> Bool {
        let isUI = file.contains("/Views/")
        switch profile {
        case .errorsOnly:
            return level == .error
        case .information:
            return level == .info || level == .error
        case .debugging:
            if level != .debug { return true }
            return !noisyTags.contains(tag)
        case .uiOnly:
            return isUI
        case .all:
            return true
        }
    }

    private static func shouldEmit(entry: some SpotLog, file: String) -> Bool {
        shouldEmit(level: entry.level, tag: entry.tag, file: file, profile: profile)
    }

    // MARK: - Output

    private static func emit(_ level: LogLevel, message: String) {
        switch level {
        case .debug:
            logger.debug("\(message, privacy: .public)")
        case .info:
            logger.info("\(message, privacy: .public)")
        case .error:
            logger.error("\(message, privacy: .public)")
        }

        #if DEBUG
        DebugFileLogWriter.shared.write(message)
        #endif
    }

    // MARK: - Privacy-safe detail formatting

    private static func formatted(_ value: Any, forKey key: String) -> String {
        guard let value = unwrapped(value) else { return "nil" }
        let normalizedKey = key.lowercased()

        if ["password", "token", "secret", "authorization", "query", "prefix",
            "searchtext", "searchterm", "body", "payload", "responsepreview"]
            .contains(where: normalizedKey.contains) ||
            (normalizedKey.contains("email") && value is String) ||
            normalizedKey.contains("path") {
            return "\"<redacted>\""
        }
        if normalizedKey.contains("latitude") || normalizedKey.contains("longitude") ||
            normalizedKey.hasSuffix("lat") || normalizedKey.hasSuffix("lon") ||
            normalizedKey.contains("coordinate") {
            return "\"<redacted>\""
        }
        if normalizedKey.contains("url") {
            let urlValue = (value as? URL)?.absoluteString ?? (value as? String)
            if normalizedKey.contains("host") {
                return quoted(urlValue ?? "<redacted-url>")
            }
            return quoted(urlValue.map(redactedURL) ?? "<redacted-url>")
        }
        if normalizedKey == "uid" ||
            (normalizedKey.hasSuffix("id") && (value is String || value is UUID)) {
            return quoted(shortIdentifier(String(describing: value)))
        }

        switch value {
        case let string as String:
            return quoted(redactedText(string))
        case let date as Date:
            return quoted(ISO8601DateFormatter().string(from: date))
        case let array as [Any]:
            return "[" + array.map { formatted($0, forKey: key) }.joined(separator: ", ") + "]"
        case let dictionary as [String: Any]:
            let contents = dictionary.keys.sorted().map { nestedKey in
                "\(nestedKey): \(formatted(dictionary[nestedKey]!, forKey: nestedKey))"
            }.joined(separator: ", ")
            return "[\(contents)]"
        default:
            return String(describing: value)
        }
    }

    private static func unwrapped(_ value: Any) -> Any? {
        let mirror = Mirror(reflecting: value)
        guard mirror.displayStyle == .optional else { return value }
        guard let wrapped = mirror.children.first?.value else { return nil }
        return unwrapped(wrapped)
    }

    private static func quoted(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(escaped)\""
    }

    private static func redactedURL(_ value: String) -> String {
        guard let components = URLComponents(string: value),
              let scheme = components.scheme,
              let host = components.host else {
            return "<redacted-url>"
        }
        return "\(scheme)://\(host)/…"
    }

    private static func shortIdentifier(_ value: String) -> String {
        guard value.count > 8 else { return value }
        return "…\(value.suffix(8))"
    }

    private static func redactedText(_ value: String) -> String {
        let patterns = [
            (#"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#, "<redacted-email>"),
            (#"https?://\S+"#, "<redacted-url>")
        ]
        return patterns.reduce(value) { result, replacement in
            result.replacingOccurrences(
                of: replacement.0,
                with: replacement.1,
                options: [.regularExpression, .caseInsensitive]
            )
        }
    }
}

#if DEBUG
private enum DebuggerDetector {
    static var isAttached: Bool {
        var processInfo = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var name = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        let nameCount = name.count
        let result = name.withUnsafeMutableBufferPointer {
            sysctl($0.baseAddress, u_int(nameCount), &processInfo, &size, nil, 0)
        }
        return result == 0 && (processInfo.kp_proc.p_flag & P_TRACED) != 0
    }
}

/// Writes DEBUG logs only when the process is not attached to Xcode.
private final class DebugFileLogWriter {
    static let shared = DebugFileLogWriter()

    private let queue = DispatchQueue(label: "com.spotapp.debug-file-logger", qos: .utility)
    private let fileManager = FileManager.default
    private let maximumBytes: UInt64 = 1_000_000
    private let retainedFiles = 3
    private var cachedFileURL: URL?
    private var backupExclusionApplied = false

    private init() {}

    func write(_ message: String) {
        guard !DebuggerDetector.isAttached else { return }
        queue.async {
            self.append(message)
        }
    }

    private func append(_ message: String) {
        guard let fileURL = currentFileURL() else { return }
        rotateIfNeeded(fileURL, adding: message.utf8.count + 2)
        let data = Data("\(message)\n\n".utf8)

        if !fileManager.fileExists(atPath: fileURL.path) {
            fileManager.createFile(
                atPath: fileURL.path,
                contents: data,
                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
            )
            excludeFromBackupIfNeeded(fileURL)
            return
        }

        excludeFromBackupIfNeeded(fileURL)
        guard let handle = try? FileHandle(forWritingTo: fileURL) else { return }
        handle.seekToEndOfFile()
        handle.write(data)
        handle.closeFile()
    }

    private func currentFileURL() -> URL? {
        if let cachedFileURL {
            return cachedFileURL
        }

        guard let documents = fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            return nil
        }

        let fileURL = documents.appendingPathComponent("spot-debug.txt")
        cachedFileURL = fileURL
        return fileURL
    }

    private func excludeFromBackupIfNeeded(_ fileURL: URL) {
        guard !backupExclusionApplied else { return }

        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var mutableFileURL = fileURL
        do {
            try mutableFileURL.setResourceValues(resourceValues)
            backupExclusionApplied = true
        } catch {
            // Logging must never fail because backup metadata could not be set.
        }
    }

    private func rotateIfNeeded(_ fileURL: URL, adding byteCount: Int) {
        let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path)
        let currentSize = (attributes?[.size] as? NSNumber)?.uint64Value ?? 0
        guard currentSize + UInt64(byteCount) > maximumBytes else { return }

        let directory = fileURL.deletingLastPathComponent()
        let oldest = directory.appendingPathComponent("spot-debug-\(retainedFiles).txt")
        try? fileManager.removeItem(at: oldest)

        for index in stride(from: retainedFiles - 1, through: 1, by: -1) {
            let source = directory.appendingPathComponent("spot-debug-\(index).txt")
            let destination = directory.appendingPathComponent("spot-debug-\(index + 1).txt")
            if fileManager.fileExists(atPath: source.path) {
                try? fileManager.moveItem(at: source, to: destination)
            }
        }

        let firstArchive = directory.appendingPathComponent("spot-debug-1.txt")
        try? fileManager.moveItem(at: fileURL, to: firstArchive)
    }
}
#endif

//
//  DataPlaneGuardTests.swift
//  SpotTests
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation
import Testing

struct DataPlaneGuardTests {

    private static let repoRoot: URL = {
        var url = URL(fileURLWithPath: #filePath)
        while !url.pathComponents.isEmpty {
            let spotRoot = url.appendingPathComponent("Spot", isDirectory: true)
            if FileManager.default.fileExists(atPath: spotRoot.path) {
                return url
            }
            url.deleteLastPathComponent()
        }
        fatalError("Could not locate repo root from \(#filePath)")
    }()

    private static let spotSourcesRoot = repoRoot.appendingPathComponent("Spot", isDirectory: true)

    /// Files allowed to import Firebase observability SDKs only.
    private static let firebaseObservabilityAllowlist: Set<String> = [
        "AppDelegate.swift",
        "AnalyticsService.swift",
        "SpotApp.swift"
    ]

  private static let forbiddenSubstrings: [(name: String, pattern: String)] = [
        ("SpotUploader type", "SpotUploader"),
        ("Firebase Firestore import", "import FirebaseFirestore"),
        ("Firebase Storage import", "import FirebaseStorage"),
        ("Firebase Auth import", "import FirebaseAuth"),
        ("Firebase Database import", "import FirebaseDatabase"),
        ("Firestore.firestore()", "Firestore.firestore()"),
        ("Storage.storage()", "Storage.storage()"),
        ("Firebase upload adapters", "SpotUploadFirebaseAdapters"),
        ("Firebase multi-image coordinator", "SpotMultiImageUploadCoordinator"),
    ]

    @Test func spotSources_doNotContainLegacyFirebaseDataPlane() throws {
        let swiftFiles = try Self.enumerateSwiftFiles(under: Self.spotSourcesRoot)
        #expect(!swiftFiles.isEmpty, "Expected Swift sources under Spot/")

        var violations: [String] = []

        for fileURL in swiftFiles {
            let relative = fileURL.path.replacingOccurrences(of: Self.repoRoot.path + "/", with: "")
            let filename = fileURL.lastPathComponent
            let contents = try String(contentsOf: fileURL, encoding: .utf8)

            for rule in Self.forbiddenSubstrings {
                if contents.contains(rule.pattern) {
                    violations.append("\(relative): contains forbidden `\(rule.pattern)` (\(rule.name))")
                }
            }

            // Firebase imports outside observability allowlist
            if contents.contains("import Firebase"),
               !Self.firebaseObservabilityAllowlist.contains(filename) {
                let firebaseImports = contents
                    .components(separatedBy: CharacterSet.newlines)
                    .filter { $0.contains("import Firebase") }
                for line in firebaseImports {
                    let trimmed = line.trimmingCharacters(in: CharacterSet.whitespaces)
                    let allowed = trimmed == "import FirebaseCore"
                        || trimmed == "import FirebaseAnalytics"
                        || trimmed == "import FirebaseCrashlytics"
                        || trimmed == "import FirebaseAppCheck"
                    if !allowed {
                        violations.append("\(relative): disallowed \(trimmed)")
                    }
                }
            }
        }

        if !violations.isEmpty {
            let message = """
            Spot data plane must remain Supabase-only. Forbidden legacy Firebase patterns found:
            \(violations.sorted().joined(separator: "\n"))

            See docs/engineering/data-plane.md
            """
            Issue.record(Comment(rawValue: message))
        }
    }

    @Test func legacyFirebaseRules_areArchivedNotAtRepoRoot() {
        let rootFirestore = Self.repoRoot.appendingPathComponent("firestore.rules")
        let rootStorage = Self.repoRoot.appendingPathComponent("firestoreStorage.rules")
        #expect(!FileManager.default.fileExists(atPath: rootFirestore.path))
        #expect(!FileManager.default.fileExists(atPath: rootStorage.path))

        let archivedFirestore = Self.repoRoot.appendingPathComponent("legacy/firebase/firestore.rules")
        let archivedStorage = Self.repoRoot.appendingPathComponent("legacy/firebase/firestoreStorage.rules")
        #expect(FileManager.default.fileExists(atPath: archivedFirestore.path))
        #expect(FileManager.default.fileExists(atPath: archivedStorage.path))
    }

    @Test func canonicalPublishCoordinator_exists() {
        let path = Self.spotSourcesRoot.appendingPathComponent("Services/Spots/SpotPublishCoordinator.swift")
        #expect(FileManager.default.fileExists(atPath: path.path))
    }

    @Test func legacySpotUploader_doesNotExist() {
        let path = Self.spotSourcesRoot.appendingPathComponent("Services/Spots/SpotUploader.swift")
        #expect(!FileManager.default.fileExists(atPath: path.path))
    }

    // MARK: - Private

    private static func enumerateSwiftFiles(under directory: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var files: [URL] = []
        for case let url as URL in enumerator {
            if url.pathExtension == "swift" {
                files.append(url)
            }
        }
        return files
    }
}

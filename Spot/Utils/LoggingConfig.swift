//
//  LoggingConfig.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum LoggingConfig {
    private static let bundledDefaultsFileName = "LoggingDefaults"

    static func configure() {
        registerDefaultKeys()

        #if DEBUG
        applyFromUserDefaults()
        SpotLogger.ensureDebugLogFile()
        #else
        SpotLogger.setProfile(.errorsOnly)
        #endif
    }

    static func applyFromUserDefaults() {
        #if DEBUG
        let rawValue = UserDefaults.standard.integer(
            forKey: Constants.UserDefaultsKeys.loggingProfile
        )
        SpotLogger.setProfile(LoggingProfile(rawValue: rawValue) ?? .errorsOnly)
        #endif
    }

    private static func registerDefaultKeys() {
        var defaults: [String: Any] = [
            Constants.UserDefaultsKeys.loggingProfile: LoggingProfile.information.rawValue
        ]

        if let bundledDefaults = loadBundledLoggingDefaultsPlist() {
            defaults.merge(bundledDefaults) { _, bundledValue in bundledValue }
        }
        UserDefaults.standard.register(defaults: defaults)
    }

    private static func loadBundledLoggingDefaultsPlist() -> [String: Any]? {
        guard let url = Bundle.main.url(
            forResource: bundledDefaultsFileName,
            withExtension: "plist"
        ),
        let data = try? Data(contentsOf: url),
        let root = try? PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        ) else {
            return nil
        }
        return root as? [String: Any]
    }
}

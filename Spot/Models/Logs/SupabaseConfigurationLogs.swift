//
//  SupabaseConfigurationLogs.swift
//  Spot
//

import Foundation

enum SupabaseConfigurationLogs: SpotLog {
    case configurationLoaded

    var tag: String { "SupabaseConfiguration" }
    var level: LogLevel { .info }
    var message: String { "Configuration loaded" }
}

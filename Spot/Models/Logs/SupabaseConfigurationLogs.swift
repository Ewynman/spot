//
//  SupabaseConfigurationLogs.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum SupabaseConfigurationLogs: SpotLog {
    case configurationLoaded

    var tag: String { "SupabaseConfiguration" }
    var level: LogLevel { .info }
    var message: String { "Configuration loaded" }
}

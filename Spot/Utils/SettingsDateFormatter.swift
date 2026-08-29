//
//  SettingsDateFormatter.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum SettingsDateFormatter {
    static func mediumDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

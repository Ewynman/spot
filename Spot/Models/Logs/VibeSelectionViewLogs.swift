//
//  VibeSelectionViewLogs.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum VibeSelectionViewLogs: SpotLog {
    case vibeSelected

    var tag: String { "VibeSelectionView" }
    var level: LogLevel {
        switch self {
        case .vibeSelected: return .info
        }
    }
    var message: String {
        switch self {
        case .vibeSelected: return "User selected vibe"
        }
    }
}

//
//  MapSpotDrawerDetent.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum MapSpotDrawerDetent: String, Equatable, Sendable {
    /// Shorter panel (viewport clamp); map stays visible.
    case peek
    /// Raised toward full height so details are visible with minimal scroll.
    case expanded
}

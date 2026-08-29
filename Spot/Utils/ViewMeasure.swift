//
//  ViewMeasure.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import SwiftUI

enum CoachTarget: Hashable {
    case username
    case location
    case vibeTag
    case likeSave
    case plusButton
    case spotCard
    case spotDetails
    case likeButton
    case bookmarkButton
    case mapFlip
    case creator
    case mapTab
    case mapUserLocation
    case mapMarkers
    case mapMarkerPreview
}

struct CoachFramesPrefKey: PreferenceKey {
    static var defaultValue: [CoachTarget: CGRect] = [:]
    static func reduce(value: inout [CoachTarget: CGRect], nextValue: () -> [CoachTarget: CGRect]) {
        // Keep the first reported frame for a target to avoid later cards overriding
        let incoming = nextValue()
        for (k, v) in incoming where value[k] == nil {
            value[k] = v
        }
    }
}

extension View {
    func measure(target: CoachTarget) -> some View {
        background(
            GeometryReader { geo in
                Color.clear.preference(key: CoachFramesPrefKey.self, value: [target: geo.frame(in: .global)])
            }
        )
    }
}

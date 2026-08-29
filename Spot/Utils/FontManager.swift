//
//  FontManager.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import SwiftUI

struct FontManager {
    static func customFont(name: String, size: CGFloat, fallback: Font) -> Font {       // Check if custom font is available
        if let _ = UIFont(name: name, size: size) {
            return .custom(name, size: size)
        } else {
            return fallback
        }
    }

    // SF Pro Rounded font names
    static let sfProRoundedBlack = "SFProRounded-Black"
    static let sfProRoundedBold = "SFProRounded-Bold"
    static let sfProRoundedRegular = "SFProRounded-Regular"
    static let sfProRoundedSemibold = "SFProRounded-Semibold" // Font functions with fallbacks
    static func logoTitle() -> Font {
        return customFont(
            name: sfProRoundedBlack,
            size: 24,
            fallback: .system(size: 24, weight: .black, design: .rounded)
        )
    }

    static func sectionHeader() -> Font {
        return customFont(
            name: sfProRoundedBold,
            size: 24,
            fallback: .system(size: 24, weight: .bold, design: .rounded)
        )
    }

    static func primaryText() -> Font {
        return customFont(
            name: sfProRoundedRegular,
            size: 12,
            fallback: .system(size: 12, weight: .regular, design: .rounded)
        )
    }

    static func buttonText() -> Font {
        return customFont(
            name: sfProRoundedSemibold,
            size: 12,
            fallback: .system(size: 12, weight: .semibold, design: .rounded)
        )
    }
}

import Foundation

enum HomeSpotCardFace: Equatable {
    case photo
    case map
}

enum HomeSpotCardTransitionStyle: Equatable {
    case flip3D
    case crossfade
}

/// Pure presentation state for a Home card. Persistent Spot state remains in
/// AuthViewModel/UserSpotService; this model only controls the visible face.
struct HomeSpotCardModel: Equatable {
    private(set) var spotId: String
    private(set) var face: HomeSpotCardFace = .photo
    private(set) var isTransitioning = false

    init(spotId: String) {
        self.spotId = spotId
    }

    mutating func beginToggle() -> Bool {
        guard !isTransitioning else { return false }
        isTransitioning = true
        face = face == .photo ? .map : .photo
        return true
    }

    mutating func completeToggle() {
        guard isTransitioning else { return }
        isTransitioning = false
    }

    mutating func reset(for spotId: String) {
        self.spotId = spotId
        face = .photo
        isTransitioning = false
    }

    static func transitionStyle(reduceMotion: Bool) -> HomeSpotCardTransitionStyle {
        reduceMotion ? .crossfade : .flip3D
    }
}

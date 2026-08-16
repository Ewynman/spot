import SwiftUI

final class HomeTourManager: ObservableObject {
    enum Step: Int, CaseIterable {
        case username, location, vibe, likeSave
    }

    private let storage: UserDefaults
    private let storageKey: String = Constants.UserDefaultsKeys.homeTourAccepted
    @Published var hasSeenHomeTour: Bool = false
    @Published var isWelcomePresented: Bool = false
    @Published var isCoachPresented: Bool = false
    @Published var currentStep: Step = .username

    init(userId: String? = nil, storage: UserDefaults = .standard) {
        self.storage = storage
        configure(userId: userId)
    }

    func configure(userId: String?) {
        hasSeenHomeTour = storage.bool(forKey: storageKey)
        // Migrate old per-user keys so users who already completed tour
        // remain completed after moving to a single global key.
        if !hasSeenHomeTour {
            let legacyKey = "hasSeenHomeTour." + (userId ?? "guest")
            if storage.bool(forKey: legacyKey) {
                storage.set(true, forKey: storageKey)
                hasSeenHomeTour = true
            }
        }
    }

    func startIfNeeded(isFirstSessionAfterSignup: Bool) {
        guard isFirstSessionAfterSignup, !hasSeenHomeTour else { return }
        isWelcomePresented = true
    }

    func startCoach() {
        isWelcomePresented = false
        currentStep = .username
        isCoachPresented = true
    }

    func next() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if let next = Step(rawValue: currentStep.rawValue + 1) {
            currentStep = next
        } else {
            complete()
        }
    }

    func skip() {
        complete()
    }

    private func complete() {
        hasSeenHomeTour = true
        storage.set(true, forKey: storageKey)
        isWelcomePresented = false
        isCoachPresented = false
    }
}

final class SpotFirstRunOnboardingManager: ObservableObject {
    enum Step: Int, CaseIterable {
        case welcome
        case spotCard
        case spotDetails
        case vibeTag
        case like
        case bookmark
        case mapFlip
        case creator
        case mapTab
        case userLocation
        case mapMarkers
        case markerPreview
        case finale

        var target: CoachTarget? {
            switch self {
            case .welcome, .finale:
                return nil
            case .spotCard:
                return .spotCard
            case .spotDetails:
                return .spotDetails
            case .vibeTag:
                return .vibeTag
            case .like:
                return .likeButton
            case .bookmark:
                return .bookmarkButton
            case .mapFlip:
                return .mapFlip
            case .creator:
                return .creator
            case .mapTab:
                return .mapTab
            case .userLocation:
                return .mapUserLocation
            case .mapMarkers:
                return .mapMarkers
            case .markerPreview:
                return .mapMarkerPreview
            }
        }

        var title: String {
            switch self {
            case .welcome:
                return "Welcome to Spot"
            case .spotCard:
                return "This is a Spot"
            case .spotDetails:
                return "Place first"
            case .vibeTag:
                return "Vibe Tags are the magic"
            case .like:
                return "Like what fits your taste"
            case .bookmark:
                return "Save places for later"
            case .mapFlip:
                return "Flip to see where it is"
            case .creator:
                return "Follow people with great taste"
            case .mapTab:
                return "Now explore by location"
            case .userLocation:
                return "Start from where you are"
            case .mapMarkers:
                return "Markers show nearby Spots"
            case .markerPreview:
                return "Open what catches your eye"
            case .finale:
                return "You are ready to explore"
            }
        }

        var body: String {
            switch self {
            case .welcome:
                return "Discover saved place recommendations from real people, organized by vibe."
            case .spotCard:
                return "A saved place recommendation from someone, centered around vibe and discovery."
            case .spotDetails:
                return "The place name, location, vibe, and photo come first so you know what this Spot is about."
            case .vibeTag:
                return "They describe how a place feels, not just what category it fits into."
            case .like:
                return "Likes help you react to Spots that feel right."
            case .bookmark:
                return "Bookmark Spots you want to remember or visit."
            case .mapFlip:
                return "Tap the green marker to flip the card and see the location. From the map side, Open in Map takes you to the Map tab focused on this Spot."
            case .creator:
                return "Shared-by shows who recommended the place. Follow people whose taste matches yours."
            case .mapTab:
                return "Tap Map to see Spots around you."
            case .userLocation:
                return "Your location helps you discover nearby recommendations."
            case .mapMarkers:
                return "Tap a marker to preview the recommendation behind it."
            case .markerPreview:
                return "Move from a marker to the full Spot when a place looks interesting."
            case .finale:
                return "Find places by vibe, save what you love, and follow people with great taste."
            }
        }

        var fallbackBody: String? {
            switch self {
            case .userLocation:
                return "Explore the map to discover Spots by area."
            case .mapMarkers:
                return "Map turns recommendations into places around you."
            case .markerPreview:
                return "Open a marker when a place catches your eye."
            default:
                return nil
            }
        }
    }

    private enum Keys {
        static let completed = "spotFirstRunOnboarding.completed.v1"
        static let completedAt = "spotFirstRunOnboarding.completedAt.v1"
        static let skipped = "spotFirstRunOnboarding.skipped.v1"
        static let lastStep = "spotFirstRunOnboarding.lastStep.v1"
    }

    private let storage: UserDefaults
    @Published private(set) var isPresented = false
    @Published var currentStep: Step = .welcome
    @Published private(set) var hasCompletedOrSkipped = false

    init(storage: UserDefaults = .standard) {
        self.storage = storage
        hasCompletedOrSkipped = storage.bool(forKey: Keys.completed) || storage.bool(forKey: Keys.skipped)
        // Avoid leaving `currentStep` on `.welcome` for finished accounts; that default collided with
        // tab-shell logic keyed off "welcome" (e.g. after `likedSpots` updates).
        if hasCompletedOrSkipped {
            currentStep = .finale
        }
    }

    var progress: CGFloat {
        let denominator = max(CGFloat(Step.allCases.count - 1), 1)
        return CGFloat(currentStep.rawValue) / denominator
    }

    var canGoBack: Bool {
        currentStep != .welcome && currentStep != .userLocation
    }

    var isFinale: Bool {
        currentStep == .finale
    }

    var prefersFullScreenCard: Bool {
        currentStep == .welcome || currentStep == .finale
    }

    func configure(userId: String?) {
        if storage.bool(forKey: Constants.UserDefaultsKeys.homeTourAccepted) {
            markCompletedWithoutPresenting()
            return
        }

        let legacyKey = "hasSeenHomeTour." + (userId ?? "guest")
        if storage.bool(forKey: legacyKey) {
            storage.set(true, forKey: Constants.UserDefaultsKeys.homeTourAccepted)
            markCompletedWithoutPresenting()
            return
        }

        hasCompletedOrSkipped = storage.bool(forKey: Keys.completed) || storage.bool(forKey: Keys.skipped)
    }

    func startIfNeeded(isAuthenticated: Bool, isFirstSessionCandidate: Bool, userId: String?) {
        #if DEBUG
        if SpotLaunchConfiguration.isUITestMode { return }
        #endif
        configure(userId: userId)
        guard isAuthenticated, isFirstSessionCandidate, !hasCompletedOrSkipped, !isPresented else { return }
        currentStep = .welcome
        isPresented = true
        storage.set(currentStep.rawValue, forKey: Keys.lastStep)
    }

    func startTour() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        currentStep = .spotCard
        storage.set(currentStep.rawValue, forKey: Keys.lastStep)
    }

    func next() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        guard let nextStep = Step(rawValue: currentStep.rawValue + 1) else {
            complete(skipped: false)
            return
        }
        currentStep = nextStep
        storage.set(nextStep.rawValue, forKey: Keys.lastStep)
    }

    func back() {
        guard canGoBack, let previous = Step(rawValue: currentStep.rawValue - 1) else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        currentStep = previous
        storage.set(previous.rawValue, forKey: Keys.lastStep)
    }

    func skip() {
        complete(skipped: true)
    }

    func finish() {
        complete(skipped: false)
    }

    func mapTabSelected() {
        guard isPresented, currentStep == .mapTab else { return }
        next()
    }

    private func complete(skipped: Bool) {
        hasCompletedOrSkipped = true
        storage.set(true, forKey: Keys.completed)
        storage.set(Date().timeIntervalSince1970, forKey: Keys.completedAt)
        storage.set(skipped, forKey: Keys.skipped)
        storage.set(currentStep.rawValue, forKey: Keys.lastStep)
        isPresented = false
    }

    private func markCompletedWithoutPresenting() {
        hasCompletedOrSkipped = true
        storage.set(true, forKey: Keys.completed)
        isPresented = false
        currentStep = .finale
    }
}

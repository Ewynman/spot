//
//  Constants.swift
//  Spot
//
//  Created by Edward Wynman on 7/10/25.
//
    
import SwiftUI

enum Constants {

    enum Colors {
        static let background = Color(hex: "#F5F3EF")      // Main background color
        /// Cream label for on-primary (and other dark) fills—same hex as `background`, so never use as body text on cream.
        static let buttonText = Color(hex: "#F5F3EF")
        static let primary = Color(hex: "#1D2C24")         // Button color, icon, and main text color
        static let textPrimary = Color(hex: "#1D2C24")     // Main text color (all text except button text)
        static let accent = Color(hex: "#DEE6D8")          // Accent color for vibe tags only

        // MARK: - Map redesign

        /// Branded green for spot map markers (refined silhouette of `primary`).
        static let mapMarkerGreen = Color(hex: "#1D2C24")
        /// Cream-ish dot inside the spot pin to improve readability over green map tiles.
        static let mapMarkerDot = Color(hex: "#F5F3EF")
        /// Subtle stroke on the marker outline.
        static let mapMarkerStroke = Color(hex: "#0F1A14")
        /// Soft-cluster background fill (organic dot-cloud, no numeric bubbles).
        static let mapDensityFill = Color(hex: "#1D2C24").opacity(0.85)
        /// Filter-match highlight (accent ring/badge); subtle so it doesn't clash with green.
        static let mapFilterMatch = Color(hex: "#7AA382")
        /// Selected pin glow ring.
        static let mapSelectedGlow = Color(hex: "#1D2C24").opacity(0.20)
        /// Pro gold ring for the user-location avatar marker.
        static let proGold = Color(hex: "#C9A24A")
        /// Regular green ring for the user-location avatar marker.
        static let mapAvatarRing = Color(hex: "#1D2C24")
        /// Halo shown when location is updating.
        static let mapAvatarHalo = Color(hex: "#1D2C24").opacity(0.18)

        // MARK: - Welcome screen

        static let welcomeGlow = Color(hex: "#7AA382")
        static let welcomeSurface = Color(hex: "#F9F7F1")
        static let welcomeMutedText = Color(hex: "#607064")
        static let welcomeLine = Color(hex: "#AEB9AD")
        static let welcomeChipFill = Color(hex: "#EEF3EA")
        static let welcomeCardShadow = Color(hex: "#1D2C24").opacity(0.12)
    }

    enum UserDefaultsKeys {
        static let firstRun = "firstRun"
        static let notificationsRequested = "notificationsRequested"
        static let locationPermissionRequested = "locationPermissionRequested"
        static let photoPermissionRequested = "photoPermissionRequested"
        static let cameraPermissionRequested = "cameraPermissionRequested"
        static let lastKnownLocationStatus = "lastKnownLocationStatus"
        static let lastKnownNotificationStatus = "lastKnownNotificationStatus"
        static let promptPermsOnNextLogin = "promptPermsOnNextLogin"
        static let homeTourAccepted = "homeTourAccepted"
        static let loggingProfile = "loggingProfile"
        static let clearKeychainOnNextLaunch = "debugClearKeychainOnNextLaunch"
        static let lastSupabaseProjectReference = "lastSupabaseProjectReference"
        static let supabaseSessionResetReason = "supabaseSessionResetReason"
    }

    enum Legal {
        static let termsURLString = "https://spotapp.online/terms"
        static let privacyURLString = "https://spotapp.online/privacy"
        static let supportEmail = "support@spotapp.online"

        static var termsURL: URL {
            guard let url = URL(string: termsURLString) else {
                preconditionFailure("Invalid terms URL")
            }
            return url
        }

        static var privacyURL: URL {
            guard let url = URL(string: privacyURLString) else {
                preconditionFailure("Invalid privacy URL")
            }
            return url
        }
    }

    enum Analytics {
        static let authReinstall = "AuthReinstall"
        static let permissionsRequested = "Perms.Requested"
        static let feedDropPrivate = "Feed.DropPrivate"
        static let imageLoadFailed = "Image.LoadFailed"
        static let authEmailInUse = "Auth.EmailInUse"
        static let authDeleteByEmail = "Auth.DeleteByEmail"
    }

    enum VibeTags {
        static let defaultTags: [String] = [
            "Chill Spot",
            "Hidden Gem",
            "Scenic View",
            "Romantic",
            "Great For Photos",
            "Family Friendly",
            "Nature Escape",
            "Foodie Heaven",
            "Beach Day",
            "Late Night",
            "Historical",
            "People Watching",
            "Quiet Moment",
            "Cozy Corner",
            "Pet Friendly",
            "Adventure",
            "Waterfront",
            "Study Spot"
        ]
    }

    enum Layout {
        enum Padding {
            static let horizontal: CGFloat = 32
            static let verticalSmall: CGFloat = 8
            static let verticalMedium: CGFloat = 12
            static let verticalLarge: CGFloat = 16
            static let verticalExtraLarge: CGFloat = 24
        }

        enum Spacing {
            static let small: CGFloat = 8
            static let medium: CGFloat = 12
            static let large: CGFloat = 16
            static let extraLarge: CGFloat = 24
        }

        enum CornerRadius {
            static let small: CGFloat = 10
            static let medium: CGFloat = 12
            static let large: CGFloat = 20
        }
    }

    enum ValidationMessages {
        static let vibeTooShort = "Please use at least 2 characters."
        static let vibeTooLong = "Please keep it under 30 characters."
        static let vibeBlocked = "That tag isn't allowed."
    }

    enum Limits {
        static let vibeTagMaxLength = 30
        static let vibeTagMinLength = 2
    }

    /// Composer / API alignment with server `publish_spot_with_approved_media_assets_v1` limits.
    enum PostLimits {
        static let maxFreePostImages = 1
        static let maxProPostImages = 5
        static let maxFreePostVibes = 1
        static let maxProPostVibes = 5

        static let freeMultipleImagesMessage = "Multiple images are available with Pro."
        static let proTooManyImagesMessage = "You can add up to 5 images per post."
        static let freeMultipleVibesMessage = "Multiple vibes are available with Pro."
        static let proTooManyVibesMessage = "You can select up to 5 vibes."
    }

    enum HTTPErrorCode {
        static let unauthorized = 401
        static let badRequest = 400
        static let internalServerError = 500
    }

    enum Pagination {
        static let defaultPageSize = 24
        static let largePageSize = 100
        static let extraLargePageSize = 200
        static let maxPageSize = 500
    }

    /// Map-redesign tuning. All numeric thresholds, animation timings, and
    /// memory caps used by the discovery and profile maps live here so they
    /// can be unit-tested and adjusted without touching view code.
    enum MapDesign {
        /// Default visible radius (meters) when the map opens around the user.
        /// Used for denied-location fallback and other non-GPS fallbacks.
        static let initialRadiusMeters: Double = 4_000

        /// Tighter radius for the first camera center on a real user fix —
        /// keeps the map at neighborhood zoom instead of a wide metro ring.
        static let initialNeighborhoodRadiusMeters: Double = 3_200

        /// Span thresholds (degrees) used to choose a density mode. Anything
        /// at or below `localSpan` shows individual pins; below
        /// `citySpan` shows individuals + slight overlap offsets; above that
        /// drops to soft clusters.
        static let localSpan: Double = 0.04
        static let citySpan: Double = 0.30

        /// Maximum pins kept in `MapViewModel.visibleSpots` after merging
        /// fresh viewport results with pre-existing pins. Keeps memory in
        /// check across long pan sessions.
        static let visibleSpotsCap: Int = 250

        /// Maximum pins rendered at far zooms (cluster mode) — anything over
        /// this is reduced to soft cluster blobs.
        static let farZoomPinCap: Int = 60

        /// Spot pin point size on the map (the inner rounded dot, in points).
        static let pinSize: CGFloat = 22
        /// Selected pin scale.
        static let pinSelectedScale: CGFloat = 1.28
        /// Pressed pin scale.
        static let pinPressedScale: CGFloat = 0.92

        /// User-location avatar marker diameter.
        static let avatarMarkerSize: CGFloat = 38
        /// Avatar ring stroke width.
        static let avatarRingWidth: CGFloat = 3

        /// Pin entry animation min/max stagger and per-pin delay.
        static let pinEntryDuration: Double = 0.28
        static let pinStaggerStep: Double = 0.012
        static let pinStaggerCap: Double = 0.25

        /// Selection spring response/damping.
        static let selectSpringResponse: Double = 0.32
        static let selectSpringDamping: Double = 0.82

        /// Region debounce range — small pans use the lower bound, fast
        /// gestures use the upper bound (see `SharedSpotMap`).
        static let regionDebounceFastNs: UInt64 = 180_000_000   // 180 ms
        static let regionDebounceSlowNs: UInt64 = 380_000_000   // 380 ms

        /// Camera offset (in points) used to keep a selected pin visually
        /// above the bottom preview panel.
        static let selectedPinCameraLift: CGFloat = 90

        /// Quantization grid (degrees) used to detect overlapping pins for
        /// radial offset. ~5e-5 ≈ 5 m at the equator, matching what users
        /// perceive as "the same place".
        static let overlapBucketSize: Double = 0.00005
        /// Radial offset distance (meters) applied to overlapping pins.
        static let overlapOffsetMeters: Double = 12

        /// Maximum proportion of the screen the map preview panel may consume
        /// before its inner content scrolls. Prevents the panel from pushing
        /// controls off-screen on small devices.
        static let panelMaxScreenFraction: CGFloat = 0.65
        /// Minimum panel height so the SpotCard header stays usable.
        static let panelMinHeight: CGFloat = 280

        /// Top corners for the discovery map spot drawer (bottom sheet style).
        static let mapDrawerTopCornerRadius: CGFloat = 22
        /// Vertical gap between the bottom of the filter pill row and the top of the spot drawer.
        static let mapDrawerGapBelowFilterPills: CGFloat = 5
    }
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        _ = scanner.scanString("#")
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)

        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8) & 0xFF) / 255
        let b = Double(rgb & 0xFF) / 255

        self.init(red: r, green: g, blue: b)
    }
}

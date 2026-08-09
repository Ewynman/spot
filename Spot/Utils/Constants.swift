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
        /// Cluster / density fill (branded circular cluster markers).
        static let mapDensityFill = Color(hex: "#1D2C24").opacity(0.92)
        /// Filter-match highlight (accent ring/badge); subtle so it doesn't clash with green.
        static let mapFilterMatch = Color(hex: "#7AA382")
        /// Selected pin contrasting ring (not a soft glow).
        static let mapSelectedGlow = Color(hex: "#F5F3EF")
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
        static let vibePhotoSyncEnabled = "vibe_photo_sync_enabled"
        static let vibePhotoSyncDisabled = "vibe_photo_sync_disabled"
        static let vibePhotoMappingChanged = "vibe_photo_mapping_changed"
        static let vibeSheetOpened = "vibe_sheet_opened"
        static let vibeSheetClosed = "vibe_sheet_closed"
        static let syncedPhotoChanged = "synced_photo_changed"
        static let syncedVibeChanged = "synced_vibe_changed"
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

        /// Span thresholds retained for tests / overlap helpers. Density at
        /// far zoom is handled by MapKit clustering rather than soft blobs.
        static let localSpan: Double = 0.04
        static let citySpan: Double = 0.30

        /// Maximum pins kept in `MapViewModel.visibleSpots` after merging
        /// fresh viewport results with pre-existing pins. Keeps memory in
        /// check across long pan sessions.
        static let visibleSpotsCap: Int = 250

        /// Legacy far-zoom pin cap (unused by MapKit clustering path).
        static let farZoomPinCap: Int = 60

        /// Spot pin visual width (teardrop body), in points.
        static let pinWidth: CGFloat = 30
        /// Spot pin visual height (tip to top), in points.
        static let pinHeight: CGFloat = 38
        /// Invisible hit target for spot pins.
        static let pinHitSize: CGFloat = 44
        /// Alias used by older call sites / tests.
        static let pinSize: CGFloat = pinWidth
        /// Selected pin scale.
        static let pinSelectedScale: CGFloat = 1.15
        /// Pressed pin scale.
        static let pinPressedScale: CGFloat = 0.92
        /// MapKit clustering identifier shared by all spot annotations.
        static let spotClusteringIdentifier = "spot"

        /// Cluster marker discrete sizes (not proportional to count).
        static let clusterSizeSmall: CGFloat = 36
        static let clusterSizeMedium: CGFloat = 40
        static let clusterSizeLarge: CGFloat = 44

        /// Compact floating preview card height (standard Dynamic Type).
        static let compactPreviewHeight: CGFloat = 132
        /// Compact preview thumbnail edge length.
        static let compactPreviewThumbnail: CGFloat = 84
        /// Side inset for the floating preview card.
        static let compactPreviewHorizontalInset: CGFloat = 16
        /// Gap between compact preview and tab bar / home indicator.
        static let compactPreviewBottomGap: CGFloat = 12
        /// Corner radius for the floating preview card.
        static let compactPreviewCornerRadius: CGFloat = 18

        /// User-location avatar marker diameter.
        static let avatarMarkerSize: CGFloat = 38
        /// Avatar ring stroke width.
        static let avatarRingWidth: CGFloat = 3

        /// Pin entry animation min/max stagger and per-pin delay.
        static let pinEntryDuration: Double = 0.28
        static let pinStaggerStep: Double = 0.012
        static let pinStaggerCap: Double = 0.25

        /// Selection spring response/damping.
        static let selectSpringResponse: Double = 0.18
        static let selectSpringDamping: Double = 0.86

        /// Region debounce range — small pans use the lower bound, fast
        /// gestures use the upper bound (see `SharedSpotMap`).
        static let regionDebounceFastNs: UInt64 = 180_000_000   // 180 ms
        static let regionDebounceSlowNs: UInt64 = 380_000_000   // 380 ms

        /// Camera offset (in points) used to keep a selected pin visually
        /// above the compact preview card.
        static let selectedPinCameraLift: CGFloat = 72

        /// Quantization grid (degrees) used to detect overlapping pins for
        /// radial offset. ~5e-5 ≈ 5 m at the equator, matching what users
        /// perceive as "the same place".
        static let overlapBucketSize: Double = 0.00005
        /// Radial offset distance (meters) applied to overlapping pins.
        static let overlapOffsetMeters: Double = 12
        /// When a cluster's member span is at/below this (degrees), treat as
        /// coincident and show the carousel instead of further zooming.
        static let coincidentClusterSpan: Double = 0.00008

        /// Maximum proportion of the screen the expanded detail sheet may use.
        static let panelMaxScreenFraction: CGFloat = 0.88
        /// Minimum panel height for legacy clamp helpers / tests.
        static let panelMinHeight: CGFloat = 280

        /// Top corners for floating preview / detail chrome.
        static let mapDrawerTopCornerRadius: CGFloat = 22
        /// Vertical gap between the bottom of the filter pill row and sheets.
        static let mapDrawerGapBelowFilterPills: CGFloat = 5

        /// Profile map floating context capsule height.
        static let profileMapChromeHeight: CGFloat = 48
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

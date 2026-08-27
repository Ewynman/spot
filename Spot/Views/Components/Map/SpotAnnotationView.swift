//
//  SpotAnnotationView.swift
//  Spot
//
//  Custom UIKit annotation view for spot pins. Concept 3 photo preview
//  marker: a circular thumbnail of the spot's primary image inside a
//  pin-shaped silhouette with a white border and subtle shadow. Falls back
//  to the branded teardrop when there is no image URL or the thumbnail
//  fails to load, so no spot is ever left without a marker.
//
//  Geometry:
//   * Frame is `pinFrameSize` (44 × 56) so both photo and teardrop modes
//     share the same layout envelope and the pin's tip always sits at the
//     annotation's coordinate via `centerOffset`.
//   * `SpotMarkerGeometry.photoPinPath(_:)` produces a compound shell path
//     (bubble + tail); the image content is drawn in a masked `CALayer`
//     centered on the bubble.
//   * Selected state applies `pinSelectedScale` via a view transform and
//     lifts z / display priority so the selected pin renders above nearby
//     markers, as required by the PRD.
//

import UIKit
import MapKit
import SwiftUI

// MARK: - Annotation model

/// Internal annotation type used by the map. Carries the spot and the
/// visual state the diffing pass last assigned. `spot` is mutable so a
/// fresh viewport payload (e.g. re-signed image URL) can update the
/// annotation in place without a remove + re-add cycle, which would drop
/// the marker's animation state and cause a visible pop.
final class SpotMapAnnotation: NSObject, MKAnnotation {
    var spot: Spot
    @objc dynamic var coordinate: CLLocationCoordinate2D
    var visualState: SpotMarkerVisualState

    init(spot: Spot, coordinate: CLLocationCoordinate2D, visualState: SpotMarkerVisualState = .default) {
        self.spot = spot
        self.coordinate = coordinate
        self.visualState = visualState
        super.init()
    }

    var spotId: String? { spot.id }
}

// MARK: - Photo pin URL helper

/// Extracts the primary image URL for a photo pin marker from a `Spot`.
/// The map RPC populates `thumbnailURL` and `imageURL` with the same
/// signed URL, so either is a valid source; `thumbnailURL` wins when both
/// are set. Whitespace-only strings are treated as absent, matching how
/// the compact preview card resolves the same value.
enum SpotPhotoPinSource {
    static func imageURL(for spot: Spot) -> URL? {
        let raw = (spot.thumbnailURL ?? spot.imageURL)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let raw, !raw.isEmpty, let url = URL(string: raw) else { return nil }
        return url
    }
}

// MARK: - View

/// Reusable annotation view for a `SpotMapAnnotation`.
final class SpotAnnotationView: MKAnnotationView {

    static let reuseIdentifier = "SpotMarkerDefault"

    // Photo pin layers
    private let photoShellLayer = CAShapeLayer()
    private let photoImageLayer = CALayer()
    private let photoPlaceholderLayer = CALayer()
    private let photoRingLayer = CAShapeLayer()
    // Teardrop (fallback) layers
    private let teardropBodyLayer = CAShapeLayer()
    private let teardropDotLayer = CAShapeLayer()
    private let teardropRingLayer = CAShapeLayer()

    private(set) var renderedState: SpotMarkerVisualState = .default
    private var hasAnimatedIn: Bool = false

    /// Current rendering mode. `.photo` when a URL is available (regardless
    /// of load state); `.teardrop` when no image URL exists or the flag is
    /// off. Failed loads keep `.photo` and show the placeholder background.
    private enum Mode { case photo, teardrop }
    /// Starts nil so the first `setMode(_:)` call in `commonInit` always
    /// applies visibility — otherwise the initial equality guard would
    /// leave both layer stacks visible on first paint.
    private var mode: Mode?

    /// Pending image fetch, tracked so `prepareForReuse` can cancel work
    /// bound for a recycled view.
    private var currentImageURL: URL?
    private var pendingHandle: MapMarkerImageCache.Handle?

    /// Delivered on the main queue when a photo pin's image load finishes
    /// (success or failure), so the host coordinator can emit the optional
    /// `map_marker_image_load` diagnostic event.
    var onImageLoadCompleted: ((SpotPhotoImageLoadEvent) -> Void)?

    // MARK: - Init

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        commonInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }

    // MARK: - Layout constants

    /// Full pin frame (width × height). Bumped to the photo pin envelope so
    /// switching modes never changes hit-testing or geographic anchor.
    private static var pinFrameSize: CGSize {
        CGSize(
            width: max(
                Constants.MapDesign.pinHitSize,
                Constants.MapDesign.photoPinImageDiameter
            ),
            height: Constants.MapDesign.photoPinTotalHeight
        )
    }

    /// Rect for the photo pin shell (image diameter × total height) centered
    /// horizontally in the annotation view frame, top-aligned so the tail
    /// tip lands at the bottom.
    private static var photoShellRect: CGRect {
        let size = pinFrameSize
        let d = Constants.MapDesign.photoPinImageDiameter
        let h = Constants.MapDesign.photoPinTotalHeight
        return CGRect(x: (size.width - d) / 2, y: 0, width: d, height: h)
    }

    /// Rect for the legacy teardrop pin, positioned so its tip lands at the
    /// bottom of the annotation view frame (same as the photo pin's tip).
    private static var teardropRect: CGRect {
        let size = pinFrameSize
        let w = Constants.MapDesign.pinWidth
        let h = Constants.MapDesign.pinHeight
        return CGRect(x: (size.width - w) / 2, y: size.height - h, width: w, height: h)
    }

    // MARK: - commonInit

    private func commonInit() {
        let size = Self.pinFrameSize
        let frame = CGRect(origin: .zero, size: size)
        self.frame = frame
        self.backgroundColor = .clear
        self.canShowCallout = false
        self.isOpaque = false
        self.clusteringIdentifier = Constants.MapDesign.spotClusteringIdentifier
        self.displayPriority = .defaultHigh
        self.collisionMode = .circle
        // Tip of the pin sits on the coordinate (view center is mid-frame).
        self.centerOffset = CGPoint(x: 0, y: -(size.height / 2))

        configurePhotoLayers()
        configureTeardropLayers()

        // Default to hidden photo layers; switch on when `configure` runs
        // with a URL. Keeps first paint after dequeue looking like the
        // legacy pin instead of an empty shell.
        setMode(.teardrop)
    }

    private func configurePhotoLayers() {
        let shell = Self.photoShellRect
        let layout = SpotMarkerGeometry.photoPinLayout(in: shell)
        let shellPath = SpotMarkerGeometry.photoPinPath(layout)

        photoShellLayer.frame = bounds
        photoShellLayer.path = shellPath
        photoShellLayer.fillColor = UIColor(Constants.Colors.mapMarkerDot).cgColor
        photoShellLayer.strokeColor = UIColor(Constants.Colors.mapMarkerStroke)
            .withAlphaComponent(0.10).cgColor
        photoShellLayer.lineWidth = 0.5
        photoShellLayer.shadowColor = UIColor.black.cgColor
        photoShellLayer.shadowOpacity = 0.22
        photoShellLayer.shadowOffset = CGSize(width: 0, height: 1.5)
        photoShellLayer.shadowRadius = 2.8
        photoShellLayer.shouldRasterize = false
        layer.addSublayer(photoShellLayer)

        // Selected-state emphasis ring: an inset copy of the shell path.
        let ringInset = -1.5
        let ringLayoutRect = shell.insetBy(dx: ringInset, dy: ringInset)
        let ringLayout = SpotMarkerGeometry.photoPinLayout(in: ringLayoutRect)
        photoRingLayer.frame = bounds
        photoRingLayer.path = SpotMarkerGeometry.photoPinPath(ringLayout)
        photoRingLayer.fillColor = UIColor.clear.cgColor
        photoRingLayer.strokeColor = UIColor(Constants.Colors.mapSelectedGlow).cgColor
        photoRingLayer.lineWidth = 2
        photoRingLayer.opacity = 0
        layer.addSublayer(photoRingLayer)

        // Placeholder (accent color) sits UNDER the image so the pin never
        // shows an empty white circle while loading.
        photoPlaceholderLayer.frame = layout.imageContent
        photoPlaceholderLayer.cornerRadius = layout.imageContent.width / 2
        photoPlaceholderLayer.masksToBounds = true
        photoPlaceholderLayer.backgroundColor = UIColor(Constants.Colors.accent).cgColor
        layer.addSublayer(photoPlaceholderLayer)

        photoImageLayer.frame = layout.imageContent
        photoImageLayer.cornerRadius = layout.imageContent.width / 2
        photoImageLayer.masksToBounds = true
        photoImageLayer.contentsGravity = .resizeAspectFill
        photoImageLayer.backgroundColor = UIColor.clear.cgColor
        photoImageLayer.opacity = 0
        layer.addSublayer(photoImageLayer)
    }

    private func configureTeardropLayers() {
        let rect = Self.teardropRect
        teardropBodyLayer.frame = bounds
        teardropBodyLayer.path = SpotMarkerGeometry.path(in: rect)
        teardropBodyLayer.fillColor = UIColor(Constants.Colors.mapMarkerGreen).cgColor
        teardropBodyLayer.strokeColor = UIColor(Constants.Colors.mapMarkerStroke).cgColor
        teardropBodyLayer.lineWidth = 1
        teardropBodyLayer.shadowColor = UIColor.black.cgColor
        teardropBodyLayer.shadowOpacity = 0.22
        teardropBodyLayer.shadowOffset = CGSize(width: 0, height: 1.5)
        teardropBodyLayer.shadowRadius = 2.5
        layer.addSublayer(teardropBodyLayer)

        teardropRingLayer.frame = bounds
        teardropRingLayer.path = SpotMarkerGeometry.path(in: rect.insetBy(dx: -2, dy: -2))
        teardropRingLayer.fillColor = UIColor.clear.cgColor
        teardropRingLayer.strokeColor = UIColor(Constants.Colors.mapSelectedGlow).cgColor
        teardropRingLayer.lineWidth = 2
        teardropRingLayer.opacity = 0
        layer.addSublayer(teardropRingLayer)

        let dotSize = Constants.MapDesign.pinWidth * 0.34
        let dotCenter = CGPoint(x: rect.midX, y: rect.minY + Constants.MapDesign.pinWidth * 0.42)
        teardropDotLayer.frame = CGRect(
            x: dotCenter.x - dotSize / 2,
            y: dotCenter.y - dotSize / 2,
            width: dotSize,
            height: dotSize
        )
        teardropDotLayer.path = UIBezierPath(ovalIn: teardropDotLayer.bounds).cgPath
        teardropDotLayer.fillColor = UIColor(Constants.Colors.mapMarkerDot).cgColor
        layer.addSublayer(teardropDotLayer)
    }

    // MARK: - Lifecycle

    override func prepareForReuse() {
        super.prepareForReuse()
        cancelPendingImageLoad()
        currentImageURL = nil
        photoImageLayer.contents = nil
        photoImageLayer.opacity = 0
        photoRingLayer.opacity = 0
        teardropRingLayer.opacity = 0
        photoShellLayer.shadowOpacity = 0.22
        teardropBodyLayer.shadowOpacity = 0.22
        transform = .identity
        alpha = 1
        renderedState = .default
        hasAnimatedIn = false
        clusteringIdentifier = Constants.MapDesign.spotClusteringIdentifier
        displayPriority = .defaultHigh
        zPriority = .defaultUnselected
        onImageLoadCompleted = nil
        setMode(.teardrop)
    }

    // MARK: - Configuration

    /// Configure this view for a given spot. Idempotent: repeat calls with
    /// the same URL never re-fetch the image, matching how
    /// `UserLocationAnnotationView` avoids re-decoding avatars every render.
    ///
    /// - Parameters:
    ///   - spot: The spot backing this annotation.
    ///   - imageCache: Overridable for tests; defaults to the shared cache.
    func configure(
        with spot: Spot,
        imageCache: MapMarkerImageCache = .shared
    ) {
        let shouldUsePhoto = MapMarkerFeatureFlags.photoPinMarkersEnabled
        let url = shouldUsePhoto ? SpotPhotoPinSource.imageURL(for: spot) : nil

        guard let url else {
            cancelPendingImageLoad()
            currentImageURL = nil
            photoImageLayer.contents = nil
            photoImageLayer.opacity = 0
            setMode(.teardrop)
            if shouldUsePhoto {
                SpotLogger.log(MapMarkerLogs.photoMarkerFallbackToTeardrop, details: [
                    "spotId": spot.id ?? "nil",
                    "reason": "no_image_url"
                ])
            }
            return
        }

        setMode(.photo)

        if currentImageURL == url, photoImageLayer.contents != nil {
            return
        }

        cancelPendingImageLoad()
        currentImageURL = url

        // Show placeholder immediately; fade the image in on completion.
        photoImageLayer.contents = nil
        photoImageLayer.opacity = 0

        let scale = UIScreen.main.scale
        let targetPixels = Constants.MapDesign.photoPinImageDiameter
            * Constants.MapDesign.pinSelectedScale
            * scale

        let handle = imageCache.fetch(url, targetPixelSize: targetPixels) { [weak self] result in
            guard let self else { return }
            guard self.currentImageURL == url else { return }
            self.pendingHandle = nil
            let event = SpotPhotoImageLoadEvent(
                spotId: spot.id,
                source: result.source,
                success: result.image != nil,
                loadTimeMs: Int((result.elapsed * 1000).rounded())
            )
            if let image = result.image {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                self.photoImageLayer.contents = image.cgImage
                CATransaction.commit()
                if !UIAccessibility.isReduceMotionEnabled {
                    let fade = CABasicAnimation(keyPath: "opacity")
                    fade.fromValue = 0
                    fade.toValue = 1
                    fade.duration = 0.18
                    self.photoImageLayer.add(fade, forKey: "photoFade")
                }
                self.photoImageLayer.opacity = 1
                SpotLogger.log(MapMarkerLogs.photoMarkerImageLoaded, details: [
                    "spotId": spot.id ?? "nil",
                    "source": result.source.rawValue,
                    "ms": event.loadTimeMs
                ])
            } else {
                self.photoImageLayer.contents = nil
                self.photoImageLayer.opacity = 0
                SpotLogger.log(MapMarkerLogs.photoMarkerImageFailed, details: [
                    "spotId": spot.id ?? "nil",
                    "source": result.source.rawValue
                ])
            }
            self.onImageLoadCompleted?(event)
        }
        pendingHandle = handle
    }

    private func cancelPendingImageLoad() {
        if let pendingHandle {
            MapMarkerImageCache.shared.cancel(pendingHandle)
        }
        pendingHandle = nil
    }

    private func setMode(_ newMode: Mode) {
        if let mode, mode == newMode { return }
        mode = newMode
        let showPhoto = (newMode == .photo)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        photoShellLayer.isHidden = !showPhoto
        photoPlaceholderLayer.isHidden = !showPhoto
        photoImageLayer.isHidden = !showPhoto
        photoRingLayer.isHidden = !showPhoto
        teardropBodyLayer.isHidden = showPhoto
        teardropDotLayer.isHidden = showPhoto
        teardropRingLayer.isHidden = showPhoto
        CATransaction.commit()
    }

    // MARK: - Visual state

    func apply(state: SpotMarkerVisualState, animated: Bool) {
        guard state != renderedState else { return }
        renderedState = state

        let scale: CGFloat
        switch state {
        case .default, .filterMatch, .filterNonMatch:
            scale = 1.0
        case .selected:
            scale = Constants.MapDesign.pinSelectedScale
        case .pressed:
            scale = Constants.MapDesign.pinPressedScale
        }

        let teardropColor: UIColor = {
            switch state {
            case .default, .selected, .pressed:
                return UIColor(Constants.Colors.mapMarkerGreen)
            case .filterMatch:
                return UIColor(Constants.Colors.mapFilterMatch)
            case .filterNonMatch:
                return UIColor(Constants.Colors.mapMarkerGreen).withAlphaComponent(0.30)
            }
        }()

        // Photo pins never dim to filter-non-match today (filter path removes
        // the pin instead), but keep alpha in sync so future filter styles
        // apply consistently.
        let photoAlpha: CGFloat = {
            switch state {
            case .filterNonMatch: return 0.45
            default: return 1.0
            }
        }()

        let ringOpacity: Float = state == .selected ? 1 : 0
        let shadowOpacity: Float = state == .selected ? 0.35 : 0.22
        let reduceMotion = UIAccessibility.isReduceMotionEnabled

        let actions = {
            self.transform = CGAffineTransform(scaleX: scale, y: scale)
            self.teardropBodyLayer.fillColor = teardropColor.cgColor
            self.teardropRingLayer.opacity = ringOpacity
            self.teardropBodyLayer.shadowOpacity = shadowOpacity
            self.photoRingLayer.opacity = ringOpacity
            self.photoShellLayer.shadowOpacity = shadowOpacity
            self.photoShellLayer.opacity = Float(photoAlpha)
            self.photoImageLayer.opacity = self.photoImageLayer.contents == nil
                ? 0
                : Float(photoAlpha)
            self.photoPlaceholderLayer.opacity = Float(photoAlpha)
        }

        if animated && !reduceMotion {
            UIView.animate(
                withDuration: Constants.MapDesign.selectSpringResponse,
                delay: 0,
                usingSpringWithDamping: Constants.MapDesign.selectSpringDamping,
                initialSpringVelocity: 0,
                options: [.allowUserInteraction, .beginFromCurrentState],
                animations: actions
            )
        } else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            actions()
            CATransaction.commit()
        }

        if state == .selected {
            displayPriority = .required
            zPriority = .max
        } else {
            displayPriority = .defaultHigh
            zPriority = .defaultUnselected
        }
    }

    // MARK: - Entry / exit animations

    func animateInIfNeeded(delay: Double) {
        guard !hasAnimatedIn else { return }
        hasAnimatedIn = true
        if UIAccessibility.isReduceMotionEnabled {
            alpha = 1
            return
        }
        let endTransform = transform
        alpha = 0
        transform = endTransform.translatedBy(x: 0, y: -10).scaledBy(x: 0.6, y: 0.6)
        UIView.animate(
            withDuration: Constants.MapDesign.pinEntryDuration,
            delay: delay,
            usingSpringWithDamping: 0.78,
            initialSpringVelocity: 0.5,
            options: [.curveEaseOut, .allowUserInteraction],
            animations: {
                self.alpha = 1
                self.transform = endTransform
            }
        )
    }

    func animateOut(completion: @escaping () -> Void) {
        if UIAccessibility.isReduceMotionEnabled {
            alpha = 0
            completion()
            return
        }
        UIView.animate(
            withDuration: 0.18,
            delay: 0,
            options: [.curveEaseIn],
            animations: {
                self.alpha = 0
                self.transform = self.transform.scaledBy(x: 0.6, y: 0.6)
            },
            completion: { _ in completion() }
        )
    }
}

// MARK: - Test hooks

#if DEBUG
extension SpotAnnotationView {
    /// Returns the currently rendered marker style (photo vs teardrop). For
    /// unit tests only — production code should never inspect this.
    var debugCurrentMarkerKind: MapMarkerAnalyticsType {
        mode == .photo ? .photoPin : .teardrop
    }

    /// Whether the fetched image has landed in the photo image layer.
    var debugHasPhotoImage: Bool {
        photoImageLayer.contents != nil
    }
}
#endif

// MARK: - Image load event

/// Payload delivered when a photo pin's image fetch resolves. Wraps the
/// values the coordinator needs to emit `map_marker_image_load`.
struct SpotPhotoImageLoadEvent {
    let spotId: String?
    let source: MapMarkerImageLoadSource
    let success: Bool
    let loadTimeMs: Int
}

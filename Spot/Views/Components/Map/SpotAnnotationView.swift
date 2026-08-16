//
//  SpotAnnotationView.swift
//  Spot
//
//  Custom UIKit annotation view for spot pins. Renders a branded teardrop
//  pin (vector CAShapeLayer, no network thumbnails) with tip-aligned
//  geography, MapKit clustering, and restrained selected-state animation.
//

import UIKit
import MapKit
import SwiftUI

// MARK: - Annotation model

/// Internal annotation type used by the map. Carries the spot and the
/// visual state the diffing pass last assigned.
final class SpotMapAnnotation: NSObject, MKAnnotation {
    let spot: Spot
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

// MARK: - View

/// Reusable annotation view for a `SpotMapAnnotation`.
///
/// Layout: a classic teardrop pin with an off-white center. Shadows are
/// native layer shadows (not baked into artwork). The geographic point is
/// the bottom tip via `centerOffset`.
final class SpotAnnotationView: MKAnnotationView {

    static let reuseIdentifier = "SpotMarkerDefault"

    private let bodyLayer = CAShapeLayer()
    private let ringLayer = CAShapeLayer()
    private let dotLayer = CAShapeLayer()

    private(set) var renderedState: SpotMarkerVisualState = .default
    private var hasAnimatedIn: Bool = false

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        commonInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }

    private func commonInit() {
        let hit = Constants.MapDesign.pinHitSize
        let pinW = Constants.MapDesign.pinWidth
        let pinH = Constants.MapDesign.pinHeight
        let frame = CGRect(x: 0, y: 0, width: hit, height: hit)
        self.frame = frame
        self.backgroundColor = .clear
        self.canShowCallout = false
        self.isOpaque = false
        self.clusteringIdentifier = Constants.MapDesign.spotClusteringIdentifier
        self.displayPriority = .defaultHigh
        self.collisionMode = .circle
        // Tip of the pin sits on the coordinate (view center is mid-frame).
        self.centerOffset = CGPoint(x: 0, y: -(hit / 2))

        let pinOrigin = CGPoint(x: (hit - pinW) / 2, y: (hit - pinH) / 2 - 2)
        let pinRect = CGRect(origin: pinOrigin, size: CGSize(width: pinW, height: pinH))

        bodyLayer.frame = frame
        bodyLayer.path = SpotMarkerGeometry.path(in: pinRect)
        bodyLayer.fillColor = UIColor(Constants.Colors.mapMarkerGreen).cgColor
        bodyLayer.strokeColor = UIColor(Constants.Colors.mapMarkerStroke).cgColor
        bodyLayer.lineWidth = 1
        bodyLayer.shadowColor = UIColor.black.cgColor
        bodyLayer.shadowOpacity = 0.22
        bodyLayer.shadowOffset = CGSize(width: 0, height: 1.5)
        bodyLayer.shadowRadius = 2.5
        layer.addSublayer(bodyLayer)

        ringLayer.frame = frame
        ringLayer.path = SpotMarkerGeometry.path(in: pinRect.insetBy(dx: -2, dy: -2))
        ringLayer.fillColor = UIColor.clear.cgColor
        ringLayer.strokeColor = UIColor(Constants.Colors.mapSelectedGlow).cgColor
        ringLayer.lineWidth = 2
        ringLayer.opacity = 0
        layer.addSublayer(ringLayer)

        let dotSize = pinW * 0.34
        let dotCenter = CGPoint(x: pinRect.midX, y: pinRect.minY + pinW * 0.42)
        dotLayer.frame = CGRect(
            x: dotCenter.x - dotSize / 2,
            y: dotCenter.y - dotSize / 2,
            width: dotSize,
            height: dotSize
        )
        dotLayer.path = UIBezierPath(ovalIn: dotLayer.bounds).cgPath
        dotLayer.fillColor = UIColor(Constants.Colors.mapMarkerDot).cgColor
        layer.addSublayer(dotLayer)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        transform = .identity
        alpha = 1
        ringLayer.opacity = 0
        bodyLayer.shadowOpacity = 0.22
        renderedState = .default
        hasAnimatedIn = false
        clusteringIdentifier = Constants.MapDesign.spotClusteringIdentifier
        displayPriority = .defaultHigh
        zPriority = .defaultUnselected
    }

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

        let bodyColor: UIColor = {
            switch state {
            case .default, .selected, .pressed:
                return UIColor(Constants.Colors.mapMarkerGreen)
            case .filterMatch:
                return UIColor(Constants.Colors.mapFilterMatch)
            case .filterNonMatch:
                return UIColor(Constants.Colors.mapMarkerGreen).withAlphaComponent(0.30)
            }
        }()

        let ringOpacity: Float = state == .selected ? 1 : 0
        let shadowOpacity: Float = state == .selected ? 0.35 : 0.22
        let reduceMotion = UIAccessibility.isReduceMotionEnabled

        let actions = {
            self.transform = CGAffineTransform(scaleX: scale, y: scale)
            self.bodyLayer.fillColor = bodyColor.cgColor
            self.ringLayer.opacity = ringOpacity
            self.bodyLayer.shadowOpacity = shadowOpacity
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

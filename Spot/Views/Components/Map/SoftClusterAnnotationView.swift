//
//  SoftClusterAnnotationView.swift
//  Spot
//
//  Legacy soft-cluster annotation (pre–MapKit clustering). Kept for unit
//  tests / `MapSoftClusterBuilder` helpers. Runtime maps use
//  `SpotClusterAnnotationView` + `MKClusterAnnotation` instead.
//

import UIKit
import MapKit

/// Custom cluster used by `SharedSpotMap`. We never use
/// `MKClusterAnnotation` directly because we want to control the visual
/// completely (no count text, organic blob).
final class SpotSoftClusterAnnotation: NSObject, MKAnnotation {
    @objc dynamic var coordinate: CLLocationCoordinate2D
    let memberCount: Int
    let memberSpotIds: [String]

    init(coordinate: CLLocationCoordinate2D, memberCount: Int, memberSpotIds: [String]) {
        self.coordinate = coordinate
        self.memberCount = memberCount
        self.memberSpotIds = memberSpotIds
        super.init()
    }
}

final class SoftClusterAnnotationView: MKAnnotationView {

    static let reuseIdentifier = "SpotMarkerDensity"

    private let blobLayer = CAShapeLayer()
    private let dotsLayer = CALayer()

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        commonInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }

    private func commonInit() {
        let size: CGFloat = 32
        let frame = CGRect(x: 0, y: 0, width: size, height: size)
        self.frame = frame
        self.canShowCallout = false
        self.backgroundColor = .clear

        // Soft blob background
        blobLayer.frame = frame
        blobLayer.path = UIBezierPath(ovalIn: frame.insetBy(dx: 1, dy: 1)).cgPath
        blobLayer.fillColor = UIColor(Constants.Colors.mapDensityFill).cgColor
        blobLayer.shadowColor = UIColor.black.cgColor
        blobLayer.shadowOpacity = 0.18
        blobLayer.shadowOffset = CGSize(width: 0, height: 1.5)
        blobLayer.shadowRadius = 3
        layer.addSublayer(blobLayer)

        dotsLayer.frame = frame
        layer.addSublayer(dotsLayer)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        dotsLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        transform = .identity
        alpha = 1
    }

    /// Render a small cluster of mini-pins (no number) sized to the rough
    /// member count: 1–3 dots → small triangle layout, more → 4-dot grid.
    func configure(with annotation: SpotSoftClusterAnnotation) {
        dotsLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        let bounds = blobLayer.bounds
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let dotSize: CGFloat = 5
        let count = min(annotation.memberCount, 4)
        let radius: CGFloat = 5.5

        let placements: [CGPoint]
        switch count {
        case 0, 1:
            placements = [center]
        case 2:
            placements = [
                CGPoint(x: center.x - radius, y: center.y),
                CGPoint(x: center.x + radius, y: center.y)
            ]
        case 3:
            placements = [
                CGPoint(x: center.x, y: center.y - radius),
                CGPoint(x: center.x - radius, y: center.y + radius * 0.6),
                CGPoint(x: center.x + radius, y: center.y + radius * 0.6)
            ]
        default:
            placements = [
                CGPoint(x: center.x - radius, y: center.y - radius),
                CGPoint(x: center.x + radius, y: center.y - radius),
                CGPoint(x: center.x - radius, y: center.y + radius),
                CGPoint(x: center.x + radius, y: center.y + radius)
            ]
        }

        for p in placements {
            let dot = CAShapeLayer()
            dot.frame = CGRect(x: p.x - dotSize / 2, y: p.y - dotSize / 2, width: dotSize, height: dotSize)
            dot.path = UIBezierPath(ovalIn: dot.bounds).cgPath
            dot.fillColor = UIColor(Constants.Colors.mapMarkerDot).cgColor
            dotsLayer.addSublayer(dot)
        }
    }

    /// Subtle press feedback when the user taps a soft cluster.
    func animatePressIn() {
        UIView.animate(withDuration: 0.12) {
            self.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
        }
    }

    func animatePressOut() {
        UIView.animate(
            withDuration: 0.22,
            delay: 0,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0,
            options: [.allowUserInteraction],
            animations: { self.transform = .identity }
        )
    }
}

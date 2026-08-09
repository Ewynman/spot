//
//  SpotClusterAnnotationView.swift
//  Spot
//
//  Branded MapKit cluster annotation: circular marker with a count label.
//  Discrete sizes for 1–9 / 10–99 / 100+ (not proportional scaling).
//

import UIKit
import MapKit
import SwiftUI

final class SpotClusterAnnotationView: MKAnnotationView {

    static let reuseIdentifier = "SpotClusterMarker"

    private let bodyLayer = CAShapeLayer()
    private let countLabel = UILabel()

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        commonInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }

    private func commonInit() {
        backgroundColor = .clear
        canShowCallout = false
        displayPriority = .defaultHigh
        collisionMode = .circle
        clusteringIdentifier = nil

        bodyLayer.fillColor = UIColor(Constants.Colors.mapMarkerGreen).cgColor
        bodyLayer.strokeColor = UIColor(Constants.Colors.mapMarkerDot).cgColor
        bodyLayer.lineWidth = 1.5
        bodyLayer.shadowColor = UIColor.black.cgColor
        bodyLayer.shadowOpacity = 0.22
        bodyLayer.shadowOffset = CGSize(width: 0, height: 1.5)
        bodyLayer.shadowRadius = 2.5
        layer.addSublayer(bodyLayer)

        countLabel.textAlignment = .center
        countLabel.textColor = UIColor(Constants.Colors.mapMarkerDot)
        countLabel.font = .systemFont(ofSize: 13, weight: .bold)
        countLabel.adjustsFontSizeToFitWidth = true
        countLabel.minimumScaleFactor = 0.7
        addSubview(countLabel)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        countLabel.text = nil
        transform = .identity
        alpha = 1
    }

    func configure(with cluster: MKClusterAnnotation) {
        let count = cluster.memberAnnotations.count
        let size = MapClusterStyle.pointSize(forCount: count)
        let frame = CGRect(x: 0, y: 0, width: size, height: size)
        self.frame = frame
        centerOffset = .zero

        bodyLayer.frame = bounds
        bodyLayer.path = UIBezierPath(ovalIn: bounds.insetBy(dx: 1, dy: 1)).cgPath

        countLabel.frame = bounds.insetBy(dx: 4, dy: 4)
        countLabel.text = MapClusterStyle.countLabel(forCount: count)
        countLabel.font = .systemFont(ofSize: size <= 36 ? 12 : 14, weight: .bold)

        accessibilityLabel = "\(count) spots. Double-tap to zoom in."
        accessibilityTraits = .button
    }
}

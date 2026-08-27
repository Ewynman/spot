import SwiftUI
import UIKit

/// Canonical teardrop geometry shared by SwiftUI map-preview overlays.
enum SpotMarkerGeometry {
    static func path(in rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        let width = rect.width
        let height = rect.height
        let centerX = rect.midX
        let top = rect.minY
        let tipY = rect.maxY
        let bulbBottom = top + width * 0.92

        path.move(to: CGPoint(x: centerX, y: tipY))
        path.addCurve(
            to: CGPoint(x: rect.minX, y: top + width * 0.45),
            control1: CGPoint(x: centerX - width * 0.08, y: tipY - height * 0.18),
            control2: CGPoint(x: rect.minX, y: bulbBottom)
        )
        path.addArc(
            center: CGPoint(x: centerX, y: top + width * 0.45),
            radius: width * 0.5,
            startAngle: .pi,
            endAngle: 0,
            clockwise: false
        )
        path.addCurve(
            to: CGPoint(x: centerX, y: tipY),
            control1: CGPoint(x: rect.maxX, y: bulbBottom),
            control2: CGPoint(x: centerX + width * 0.08, y: tipY - height * 0.18)
        )
        path.closeSubpath()
        return path
    }
}

/// Precomputed layout for the photo preview pin (Concept 3): a circular
/// image bubble on top of a short downward tail, with the tail's tip
/// aligned to the annotation's geographic coordinate.
///
/// All values are in `rect`-local points. `rect` should have
/// `width == imageDiameter` and `height == totalHeight`; the caller is
/// responsible for centering `rect` inside the annotation view's frame.
struct PhotoPinLayout: Equatable {
    /// The circular image bubble, top-anchored in `rect`.
    let imageCircle: CGRect
    /// The geographic anchor point (`rect.midX`, `rect.maxY`).
    let tip: CGPoint
    /// Center of the image bubble.
    let bubbleCenter: CGPoint
    /// Image bubble radius.
    let radius: CGFloat
    /// Rect for the image content (bubble inset by `borderWidth`).
    let imageContent: CGRect
    /// Angle (radians, from downward vertical) at which the tail meets the
    /// bubble. Callers use this to render a matching tail curve.
    let tailHalfAngle: CGFloat
}

extension SpotMarkerGeometry {

    /// Returns the layout for a photo preview pin in `rect`.
    static func photoPinLayout(
        in rect: CGRect,
        borderWidth: CGFloat = Constants.MapDesign.photoPinBorderWidth,
        tailHalfAngle: CGFloat = Constants.MapDesign.photoPinTailHalfAngle
    ) -> PhotoPinLayout {
        let diameter = rect.width
        let radius = diameter / 2
        let circle = CGRect(x: rect.minX, y: rect.minY, width: diameter, height: diameter)
        let center = CGPoint(x: rect.midX, y: rect.minY + radius)
        let tip = CGPoint(x: rect.midX, y: rect.maxY)
        let clampedBorder = max(0, min(borderWidth, radius - 1))
        let contentInset = clampedBorder
        let content = circle.insetBy(dx: contentInset, dy: contentInset)
        return PhotoPinLayout(
            imageCircle: circle,
            tip: tip,
            bubbleCenter: center,
            radius: radius,
            imageContent: content,
            tailHalfAngle: tailHalfAngle
        )
    }

    /// Returns the outer shell path (circle + downward tail) for a photo
    /// preview pin sized by `layout`. Used as both the fill/stroke shape
    /// for the pin body and (inset) as the selected-state ring.
    static func photoPinPath(_ layout: PhotoPinLayout) -> CGPath {
        let path = UIBezierPath()
        let center = layout.bubbleCenter
        let radius = layout.radius
        let tip = layout.tip
        let angle = layout.tailHalfAngle

        // Tangent points where the tail curves meet the bubble.
        let sinA = sin(angle)
        let cosA = cos(angle)
        let rightAnchor = CGPoint(
            x: center.x + sinA * radius,
            y: center.y + cosA * radius
        )
        let leftAnchor = CGPoint(
            x: center.x - sinA * radius,
            y: center.y + cosA * radius
        )

        // Move to the tip and sweep clockwise around the bubble to build
        // a closed shell shape:
        //   tip → curve → rightAnchor → arc over top → leftAnchor → curve → tip
        path.move(to: tip)
        path.addQuadCurve(
            to: rightAnchor,
            controlPoint: CGPoint(x: rightAnchor.x + sinA * radius * 0.20, y: tip.y)
        )
        // Angles measured from +X in the y-down space. The right anchor sits
        // in the lower-right (angle > 0, < π/2); the left anchor in the
        // lower-left. `clockwise: false` here (increasing angle counter to
        // screen-clockwise) walks over the TOP of the bubble.
        let startAngle = atan2(rightAnchor.y - center.y, rightAnchor.x - center.x)
        let endAngle = atan2(leftAnchor.y - center.y, leftAnchor.x - center.x)
        path.addArc(
            withCenter: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        path.addQuadCurve(
            to: tip,
            controlPoint: CGPoint(x: leftAnchor.x - sinA * radius * 0.20, y: tip.y)
        )
        path.close()
        return path.cgPath
    }
}

struct SpotMarkerShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path(SpotMarkerGeometry.path(in: rect))
    }
}

/// Branded marker intended to be centered over a map snapshot.
struct SpotMarkerView: View {
    var width: CGFloat = Constants.MapDesign.pinWidth
    var height: CGFloat = Constants.MapDesign.pinHeight

    var body: some View {
        ZStack(alignment: .topLeading) {
            SpotMarkerShape()
                .fill(Constants.Colors.mapMarkerGreen)
                .overlay {
                    SpotMarkerShape()
                        .stroke(Constants.Colors.mapMarkerStroke, lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.22), radius: 2.5, y: 1.5)

            Circle()
                .fill(Constants.Colors.mapMarkerDot)
                .frame(width: width * 0.34, height: width * 0.34)
                .position(x: width / 2, y: width * 0.42)
        }
        .frame(width: width, height: height)
        .accessibilityHidden(true)
    }
}

#Preview {
    SpotMarkerView()
        .padding()
        .background(Constants.Colors.background)
}

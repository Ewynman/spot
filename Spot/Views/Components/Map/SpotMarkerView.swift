import SwiftUI

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

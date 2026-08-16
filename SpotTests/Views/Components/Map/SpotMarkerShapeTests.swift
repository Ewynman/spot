import CoreGraphics
import Testing
@testable import Spot

struct SpotMarkerShapeTests {
    @Test func canonicalPathUsesCenteredBottomTip() {
        let rect = CGRect(x: 0, y: 0, width: 30, height: 38)

        let path = SpotMarkerGeometry.path(in: rect)

        #expect(path.currentPoint.x == rect.midX)
        #expect(path.currentPoint.y == rect.maxY)
        #expect(path.boundingBoxOfPath.maxY == rect.maxY)
    }

    @Test func canonicalPathContainsBulbCenter() {
        let rect = CGRect(x: 0, y: 0, width: 30, height: 38)
        let bulbCenter = CGPoint(x: rect.midX, y: rect.minY + rect.width * 0.45)

        #expect(SpotMarkerGeometry.path(in: rect).contains(bulbCenter))
    }
}

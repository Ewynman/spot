import Foundation
import CoreGraphics

/// Shared square-tile width math for spot grids and skeleton placeholders.
enum SpotGridLayout {
    static func itemWidth(
        columns: Int,
        containerWidth: CGFloat,
        horizontalPadding: CGFloat = 24,
        spacing: CGFloat = 12
    ) -> CGFloat {
        let gaps = spacing * CGFloat(max(columns - 1, 0))
        return (containerWidth - horizontalPadding - gaps) / CGFloat(max(columns, 1))
    }
}

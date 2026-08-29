//
//  SpotJPEGImageDimensions.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import CoreGraphics
import Foundation
import ImageIO

enum SpotJPEGImageDimensions {
    /// Pixel size after orientation transform (matches typical UIImage behavior).
    static func pixelSize(jpeg data: Data) -> (width: Int, height: Int)? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, options) else {
            return nil
        }
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return nil
        }
        guard let w = props[kCGImagePropertyPixelWidth] as? NSNumber,
              let h = props[kCGImagePropertyPixelHeight] as? NSNumber,
              w.intValue > 0, h.intValue > 0 else {
            return nil
        }
        var width = w.intValue
        var height = h.intValue
        if let orientation = props[kCGImagePropertyOrientation] as? NSNumber {
            let o = CGImagePropertyOrientation(rawValue: orientation.uint32Value) ?? .up
            switch o {
            case .left, .leftMirrored, .right, .rightMirrored:
                swap(&width, &height)
            default:
                break
            }
        }
        return (width, height)
    }
}

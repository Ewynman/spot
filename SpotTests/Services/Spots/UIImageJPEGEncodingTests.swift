//
//  UIImageJPEGEncodingTests.swift
//  SpotTests
//

import Testing
import UIKit
@testable import Spot

struct UIImageJPEGEncodingTests {

    @Test func spot_jpegDataOpaqueProducesData() {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10), format: format)
        let image = renderer.image { ctx in
            UIColor.red.withAlphaComponent(0.5).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }
        let data = image.spot_jpegDataOpaque(compressionQuality: 0.8)
        #expect(data != nil)
        #expect(data!.isEmpty == false)
    }
}

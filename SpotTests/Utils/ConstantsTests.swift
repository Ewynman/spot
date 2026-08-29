//
//  ConstantsTests.swift
//  SpotTests
//
//  Created by Edward Wynman on 3/2/25.
//

import SwiftUI
import Testing
@testable import Spot

struct ConstantsTests {

    @Test func colorHexParsing() {
        let color = Color(hex: "#FF0000")
        #expect(color != nil)
    }

    @Test func colorHexWithoutHash() {
        let color = Color(hex: "00FF00")
        #expect(color != nil)
    }

    @Test func colorHexBlack() {
        let color = Color(hex: "#000000")
        #expect(color != nil)
    }

    @Test func colorHexWhite() {
        let color = Color(hex: "#FFFFFF")
        #expect(color != nil)
    }
}

//
//  OTPDigitField.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

/// Applies pasted OTP text into a fixed-length digit array.
enum OTPDigitField {
    static func applyPaste(
        _ raw: String,
        into digits: [String],
        at index: Int
    ) -> [String] {
        var next = digits
        let filtered = Array(raw.filter(\.isNumber))

        if filtered.count <= 1 {
            if index >= 0, index < next.count {
                next[index] = filtered.isEmpty ? "" : String(filtered[0])
            }
            return next
        }

        let chars = Array(filtered.prefix(next.count))
        for i in 0..<chars.count {
            next[i] = String(chars[i])
        }
        return next
    }
}

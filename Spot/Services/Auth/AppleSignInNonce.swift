//
//  AppleSignInNonce.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import CryptoKit
import Foundation
import Security

enum AppleSignInNonce {
    static func make() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        precondition(status == errSecSuccess, "Unable to generate a secure Apple sign-in nonce.")
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    static func sha256(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

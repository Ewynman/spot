import Foundation
import Testing
@testable import Spot

struct LoginErrorMapperTests {
    @Test func mapsNetworkErrors() {
        #expect(LoginErrorMapper.message(forDescription: "Network connection lost") == "Network error. Please check your connection.")
        #expect(LoginErrorMapper.message(forDescription: "No internet") == "Network error. Please check your connection.")
    }

    @Test func mapsUnconfirmedEmail() {
        #expect(
            LoginErrorMapper.message(forDescription: "Email not confirmed")
                == "Verify your email to finish creating your account."
        )
    }

    @Test func mapsUsernameMiss() {
        #expect(
            LoginErrorMapper.message(forDescription: "No account found for username")
                == "No account found for that username."
        )
    }

    @Test func defaultsToGenericCredentialMessage() {
        #expect(LoginErrorMapper.message(forDescription: "Invalid login credentials") == "Incorrect email or password.")
    }
}

struct VerificationEmailMaskTests {
    @Test func masksLocalPartKeepingTwoCharacters() {
        #expect(VerificationEmailMask.mask("eddie@example.com") == "ed****@example.com")
    }

    @Test func returnsUnchangedWhenMissingAtSign() {
        #expect(VerificationEmailMask.mask("not-an-email") == "not-an-email")
    }

    @Test func shortLocalPartKeepsAvailableCharacters() {
        #expect(VerificationEmailMask.mask("a@b.co") == "a****@b.co")
    }
}

struct PasswordRequirementChecksTests {
    @Test func evaluatesWeakPassword() {
        let checks = PasswordRequirementChecks.evaluate("abc")
        #expect(checks.map(\.isMet) == [false, false, false])
    }

    @Test func evaluatesStrongPassword() {
        let checks = PasswordRequirementChecks.evaluate("Abcdef1!")
        #expect(checks.allSatisfy { $0.isMet })
    }
}

struct OTPDigitFieldTests {
    @Test func singleDigitReplacesAtIndex() {
        let digits = Array(repeating: "", count: 6)
        let next = OTPDigitField.applyPaste("5", into: digits, at: 2)
        #expect(next == ["", "", "5", "", "", ""])
    }

    @Test func pasteFillsFromIndex() {
        let digits = Array(repeating: "", count: 6)
        let next = OTPDigitField.applyPaste("123456", into: digits, at: 0)
        #expect(next == ["1", "2", "3", "4", "5", "6"])
    }

    @Test func nonDigitsAreIgnored() {
        let digits = Array(repeating: "", count: 6)
        let next = OTPDigitField.applyPaste("12ab34", into: digits, at: 0)
        #expect(next == ["1", "2", "3", "4", "", ""])
    }
}

import Foundation

/// Signup password checklist rows shown under the password field.
enum PasswordRequirementChecks {
    struct Requirement: Equatable {
        let label: String
        let isMet: Bool
    }

    static func evaluate(_ password: String) -> [Requirement] {
        [
            Requirement(label: "At least 8 characters", isMet: password.count >= 8),
            Requirement(
                label: "A letter and a number",
                isMet: password.rangeOfCharacter(from: .letters) != nil
                    && password.rangeOfCharacter(from: .decimalDigits) != nil
            ),
            Requirement(
                label: "One symbol",
                isMet: password.rangeOfCharacter(from: CharacterSet.alphanumerics.inverted) != nil
            )
        ]
    }
}

import Foundation

/// Copy for the branded block-user confirmation used on profiles and Spot cards.
struct BlockUserConfirmationCopy: Equatable {
    let title: String
    let message: String
    let confirmTitle: String
    let cancelTitle: String

    static let fallbackTitle = "Block this user?"
    static let defaultMessage =
        "You won’t see their Spots or profile. You can unblock them later in Settings."
    static let defaultConfirmTitle = "Block"
    static let defaultCancelTitle = "Cancel"

    static func make(username: String?) -> BlockUserConfirmationCopy {
        BlockUserConfirmationCopy(
            title: title(for: username),
            message: defaultMessage,
            confirmTitle: defaultConfirmTitle,
            cancelTitle: defaultCancelTitle
        )
    }

    static func title(for username: String?) -> String {
        if let handle = displayHandle(from: username) {
            return "Block \(handle)?"
        }
        return fallbackTitle
    }

    /// `@username` when a usable handle exists; otherwise `nil`.
    static func displayHandle(from username: String?) -> String? {
        guard let raw = username?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        let withoutAt = raw.hasPrefix("@")
            ? String(raw.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
            : raw
        guard !withoutAt.isEmpty else { return nil }
        return "@\(withoutAt)"
    }
}

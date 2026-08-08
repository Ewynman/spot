import Foundation

/// Owns the “custom vibe” list for the **signed-in** user and global `vibe_tags` registration.
///
/// **Privacy / visibility**
/// - **Device-local list:** `UserDefaults` keys `spot.userCustomVibeTagNames.<userId>` are only read for
///   the current account on this device. Other users’ apps never load your key; this is not a server “private list.”
/// - **Pro-gated UI:** Only Pro users can add new custom tags in the composer (`VibeSelectionView` + `AuthViewModel.isPro`).
/// - **Global catalog:** When a custom label is first used, `ensureTagExists` upserts into Supabase `vibe_tags`,
///   which is the shared catalog — so **that label string can appear for everyone** (search, picker, other posts).
final class VibeTagService {
    static let shared = VibeTagService()
    private init() {}

    private static func customTagsKey(userId: String) -> String {
        "spot.userCustomVibeTagNames.\(userId)"
    }

    /// Saved custom vibe names for this account on **this device** (used for “Your Vibes” chips).
    static func savedCustomTagNames(forUserId userId: String) -> [String] {
        UserDefaults.standard.stringArray(forKey: customTagsKey(userId: userId)) ?? []
    }

    /// Ensures a global vibe tag exists in `vibe_tags` and returns its id string.
    @discardableResult
    func ensureTagExists(name rawName: String) async throws -> String {
        let id = try await SpotSupabaseRepository.resolveOrCreateVibeTagId(displayName: rawName)
        return id.uuidString
    }

    /// Ensures the tag exists in Postgres and records it locally for this user (picker / search).
    func ensureExistsAndAttachToUser(name: String, userId: String?) async {
        guard let userId else { return }
        do {
            _ = try await ensureTagExists(name: name)
            appendCustomTagName(name, userId: userId)
            SpotLogger.log(VibeTagServiceLogs.vibeTagSaved, details: ["name": name])
        } catch {
            SpotLogger.log(VibeTagServiceLogs.savingVibeTagFailed, details: ["error": error.localizedDescription])
        }
    }

    func fetchAll(limit: Int = 1000) async -> [VibeTag] {
        do {
            var tags = try await SpotSupabaseRepository.fetchVibeTagsForPicker(limit: limit)
            if let uid = SpotAuthBridge.currentUserId {
                let custom = UserDefaults.standard.stringArray(forKey: Self.customTagsKey(userId: uid)) ?? []
                let existingLower = Set(tags.map { ($0.name_lower ?? $0.name.lowercased()) })
                for name in custom {
                    let lower = name.lowercased()
                    guard !existingLower.contains(lower) else { continue }
                    tags.append(VibeTag(id: nil, name: name, name_lower: lower, createdAt: nil))
                }
            }
            tags.sort { ($0.name_lower ?? $0.name.lowercased()) < ($1.name_lower ?? $1.name.lowercased()) }
            return tags
        } catch {
            SpotLogger.log(VibeTagServiceLogs.fetchVibeTagsFailed, details: ["error": error.localizedDescription])
            return []
        }
    }

    private func appendCustomTagName(_ rawName: String, userId: String) {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let key = Self.customTagsKey(userId: userId)
        var arr = UserDefaults.standard.stringArray(forKey: key) ?? []
        if !arr.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            arr.append(trimmed)
            UserDefaults.standard.set(arr, forKey: key)
        }
    }
}

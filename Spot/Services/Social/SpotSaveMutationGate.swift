import Foundation

/// Coalesces identical in-flight bookmark mutations across every visible copy of a Spot.
actor SpotSaveMutationGate {
    static let shared = SpotSaveMutationGate()

    private struct MutationKey: Hashable {
        let spotId: String
        let isSaved: Bool
    }

    private var inFlight: [MutationKey: Task<Void, Error>] = [:]

    func perform(
        spotId: String,
        isSaved: Bool,
        operation: @escaping @Sendable () async throws -> Void
    ) async throws {
        let key = MutationKey(spotId: spotId, isSaved: isSaved)
        if let existing = inFlight[key] {
            try await existing.value
            return
        }

        let task = Task {
            try await operation()
        }
        inFlight[key] = task

        do {
            try await task.value
            inFlight[key] = nil
        } catch {
            inFlight[key] = nil
            throw error
        }
    }
}

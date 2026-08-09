import Foundation
import Testing
@testable import Spot

private actor SaveCallCounter {
    private(set) var value = 0

    func increment() {
        value += 1
    }
}

struct SpotSaveMutationGateTests {
    @Test func rapidIdenticalSavesAreCoalesced() async throws {
        let gate = SpotSaveMutationGate()
        let counter = SaveCallCounter()

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<20 {
                group.addTask {
                    try await gate.perform(spotId: "spot-1", isSaved: true) {
                        await counter.increment()
                        try await Task.sleep(nanoseconds: 50_000_000)
                    }
                }
            }
            try await group.waitForAll()
        }

        #expect(await counter.value == 1)
    }

    @Test func differentSpotsDoNotBlockEachOther() async throws {
        let gate = SpotSaveMutationGate()
        let counter = SaveCallCounter()

        async let first: Void = gate.perform(spotId: "spot-1", isSaved: true) {
            await counter.increment()
        }
        async let second: Void = gate.perform(spotId: "spot-2", isSaved: true) {
            await counter.increment()
        }
        _ = try await (first, second)

        #expect(await counter.value == 2)
    }

    @Test func failedSaveCanBeRetried() async {
        struct ExpectedFailure: Error {}
        let gate = SpotSaveMutationGate()
        let counter = SaveCallCounter()

        await #expect(throws: ExpectedFailure.self) {
            try await gate.perform(spotId: "spot-1", isSaved: true) {
                await counter.increment()
                throw ExpectedFailure()
            }
        }

        try? await gate.perform(spotId: "spot-1", isSaved: true) {
            await counter.increment()
        }
        #expect(await counter.value == 2)
    }
}

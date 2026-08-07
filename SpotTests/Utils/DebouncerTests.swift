//
//  DebouncerTests.swift
//  SpotTests
//
//  Created By: Wynman, Edward
//  Date: 03/02/2025
//

import Foundation
import Testing
@testable import Spot

struct DebouncerTests {

    /// Lock-backed flag: debouncer fire writes from `DispatchQueue.main` while the test polls from the async harness.
    // `NSLock` isn't `Sendable` under Swift concurrency checking, but all access to `_value`
    // is guarded by the lock; this helper is only used as a cross-executor synchronization primitive in tests.
    private final class LockedBool: @unchecked Sendable {
        private let lock = NSLock()
        private var _value = false

        func get() -> Bool {
            lock.lock()
            defer { lock.unlock() }
            return _value
        }

        func set(_ newValue: Bool) {
            lock.lock()
            defer { lock.unlock() }
            _value = newValue
        }
    }

    /// Runs the main run loop for the given duration so DispatchQueue.main work can execute.
    private func runMainLoop(for duration: TimeInterval) async {
        await MainActor.run {
            RunLoop.main.run(until: Date().addingTimeInterval(duration))
        }
    }

    private func pumpMainRunLoop(until deadline: Date, while shouldContinue: @escaping @Sendable () -> Bool) async {
        while Date() < deadline, shouldContinue() {
            await runMainLoop(for: 0.05)
        }
    }

    @Test func scheduleRunsBlock() async throws {
        let debouncer = Debouncer(interval: 0.15)
        let ran = LockedBool()
        await MainActor.run {
            debouncer.schedule { ran.set(true) }
        }
        let deadline = Date().addingTimeInterval(3)
        await pumpMainRunLoop(until: deadline) { !ran.get() }
        #expect(ran.get())
    }

    @Test func cancelPreventsExecution() async throws {
        let debouncer = Debouncer(interval: 10.0)
        let ran = LockedBool()
        await MainActor.run {
            debouncer.schedule { ran.set(true) }
            debouncer.cancel()
        }
        await runMainLoop(for: 0.25)
        #expect(!ran.get())
    }

    @Test func scheduleReplacesPrevious() async throws {
        let debouncer = Debouncer(interval: 0.1)
        let first = LockedBool()
        let second = LockedBool()
        await MainActor.run {
            debouncer.schedule { first.set(true) }
            debouncer.schedule { second.set(true) }
        }
        let deadline = Date().addingTimeInterval(3)
        await pumpMainRunLoop(until: deadline) { !second.get() }
        #expect(!first.get())
        #expect(second.get())
    }
}

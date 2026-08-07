import Foundation

final class PerfMetrics {
    static let shared = PerfMetrics()
    private init() {}

    private var marks: [String: Date] = [:]
    private var values: [String: Double] = [:]

    func mark(_ key: String) { marks[key] = Date() }
    func measure(_ key: String) -> TimeInterval? {
        guard let t = marks[key] else { return nil }
        return Date().timeIntervalSince(t)
    }

    func set(_ key: String, value: Double) { values[key] = value }
    func value(_ key: String) -> Double? { values[key] }
    func recordOnce(_ key: String, value: Double) {
        if values[key] == nil { values[key] = value }
    }
}

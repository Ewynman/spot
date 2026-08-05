//
//  EWMapDebugLog.swift
//  Spot
//
//  DEBUG-only tracing for the map / user-location pipeline. Every line is
//  prefixed with `EW-MAP:` so it can be filtered in the Xcode console while
//  diagnosing a missing user-location fix. Compiled out of release builds.
//

import Foundation

@inline(__always)
func ewMapLog(_ message: @autoclosure () -> String) {
    #if DEBUG
    let thread = Thread.isMainThread ? "main" : "bg"
    print("EW-MAP: [\(thread)] \(message())")
    #endif
}

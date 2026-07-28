//
//  LikesViewModelLogs.swift
//  Spot
//
//  Log definitions for LikesViewModel.
//

import Foundation

enum LikesViewModelLogs: SpotLog {
    case alreadyLoading
    case startingLoadInitial
    case fetchedSpotsFromService
    case spotWithoutIdFound
    case loadedSpots
    case loadInitialFailed
    case loadInitialCompleted

    var tag: String { "LikesViewModel" }
    var level: LogLevel {
        switch self {
        case .alreadyLoading: return .debug
        case .startingLoadInitial: return .debug
        case .fetchedSpotsFromService: return .debug
        case .spotWithoutIdFound: return .debug
        case .loadedSpots: return .debug
        case .loadInitialFailed: return .error
        case .loadInitialCompleted: return .info
        }
    }
    var message: String {
        switch self {
        case .alreadyLoading: return "Already loading, skipping"
        case .startingLoadInitial: return "Starting loadInitial"
        case .fetchedSpotsFromService: return "Fetched spots from service"
        case .spotWithoutIdFound: return "Spot without ID found in likes"
        case .loadedSpots: return "Loaded spots for likes"
        case .loadInitialFailed: return "LikesViewModel loadInitial failed"
        case .loadInitialCompleted: return "loadInitial completed"
        }
    }
}

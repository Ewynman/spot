//
//  SearchViewModelLogs.swift
//  Spot
//
//  Log definitions for SearchViewModel.
//

import Foundation

enum SearchViewModelLogs: SpotLog {
    case searchQueryChanged
    case searchSegmentSwitched
    case searchUsersResults
    case searchLocationsSuggestions
    case searchVibesSuggestions
    case openLocationGrid
    case openVibeGrid
    case openMultiVibeGrid
    case gridLoadedPage
    case gridLoadFailed
    case loadedAllVibeTags
    case applyVibeFiltersToLocation
    case clearVibeFilters
    case clearFiltersReloadingVibe
    case searchHistoryLoaded
    case searchHistoryCleared

    var tag: String { "SearchViewModel" }
    var level: LogLevel {
        switch self {
        case .searchQueryChanged: return .debug
        case .searchSegmentSwitched: return .info
        case .searchUsersResults: return .debug
        case .searchLocationsSuggestions: return .debug
        case .searchVibesSuggestions: return .debug
        case .openLocationGrid: return .debug
        case .openVibeGrid: return .debug
        case .openMultiVibeGrid: return .debug
        case .gridLoadedPage: return .debug
        case .gridLoadFailed: return .error
        case .loadedAllVibeTags: return .info
        case .applyVibeFiltersToLocation: return .debug
        case .clearVibeFilters: return .debug
        case .clearFiltersReloadingVibe: return .debug
        case .searchHistoryLoaded: return .debug
        case .searchHistoryCleared: return .info
        }
    }
    var message: String {
        switch self {
        case .searchQueryChanged: return "Search query changed"
        case .searchSegmentSwitched: return "Search segment switched"
        case .searchUsersResults: return "Search users results"
        case .searchLocationsSuggestions: return "Search locations suggestions"
        case .searchVibesSuggestions: return "Search vibes suggestions"
        case .openLocationGrid: return "Open location grid"
        case .openVibeGrid: return "Open vibe grid"
        case .openMultiVibeGrid: return "Open multi-vibe grid"
        case .gridLoadedPage: return "Grid loaded page"
        case .gridLoadFailed: return "Grid load failed"
        case .loadedAllVibeTags: return "Loaded all vibe tags for filters"
        case .applyVibeFiltersToLocation: return "Apply vibe filters to location"
        case .clearVibeFilters: return "Clear vibe filters, reloading location"
        case .clearFiltersReloadingVibe: return "Clear filters, reloading vibe"
        case .searchHistoryLoaded: return "Search history loaded"
        case .searchHistoryCleared: return "Search history cleared"
        }
    }
}

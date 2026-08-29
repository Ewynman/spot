//
//  SpotServiceLogs.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

enum SpotServiceLogs: SpotLog {
    // MARK: - Fetch spots for map
    case cachedSpotsReturned
    case fetchSpotsStarted
    case fetchSpotsError
    case fetchSpotsEmpty
    case spotDocParsed
    case spotDocSkipped
    case spotsCachedForMap

    // MARK: - Fetch single spot
    case fetchSpotByIdStarted
    case spotNotFound
    case spotOwnerBlocked
    case invalidSpotData
    case spotFetched

    // MARK: - Blocked users
    case blockedUsersCheckFailed

    // MARK: - Storage delete
    case storageDeleteFailed
    case storageDeleted

    // MARK: - SpotLog conformance

    var tag: String { "SpotService" }

    var level: LogLevel {
        switch self {
        case .cachedSpotsReturned, .spotsCachedForMap, .spotOwnerBlocked, .spotFetched, .storageDeleted:
            return .info
        case .fetchSpotsStarted, .fetchSpotsEmpty, .spotDocParsed, .spotDocSkipped, .fetchSpotByIdStarted, .spotNotFound:
            return .debug
        case .fetchSpotsError, .invalidSpotData, .blockedUsersCheckFailed, .storageDeleteFailed:
            return .error
        }
    }

    var message: String {
        switch self {
        case .cachedSpotsReturned:
            return "Returning cached spots"
        case .fetchSpotsStarted:
            return "Fetch spots for map"
        case .fetchSpotsError:
            return "fetchSpotsForMap error"
        case .fetchSpotsEmpty:
            return "fetchSpotsForMap returned no documents"
        case .spotDocParsed:
            return "Parsing spot doc"
        case .spotDocSkipped:
            return "Skipping doc due to missing fields"
        case .spotsCachedForMap:
            return "Parsed and cached spots (map)"
        case .fetchSpotByIdStarted:
            return "Fetch spot by ID"
        case .spotNotFound:
            return "Spot not found"
        case .spotOwnerBlocked:
            return "Spot owner blocked (returning nil)"
        case .invalidSpotData:
            return "Invalid spot data"
        case .spotFetched:
            return "Fetched spot"
        case .blockedUsersCheckFailed:
            return "Failed to check blocked users"
        case .storageDeleteFailed:
            return "Storage delete failed"
        case .storageDeleted:
            return "Storage deleted"
        }
    }
}
